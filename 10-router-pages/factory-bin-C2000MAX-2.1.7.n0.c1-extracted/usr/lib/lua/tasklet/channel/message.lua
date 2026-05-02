
--
-- Copyright (C) spyder
--

local tasklet = require 'tasklet'
local block_task = tasklet._block_task
local resume_task = tasklet._resume_task
local current_task = tasklet.current_task

local EPIPE = errno.EPIPE

--[[
tasks are links as:

                 t_svcnext
	+-------+   ------------>          +-------+ -----> false
    | task1 |                   ....   | taskN |
    +-------+   <------------          +-------+
      |             t_svcprev               A
      |                                     |
	  +-------------------------------------+
	            t_svcprev
]]


local function push_task(ch, head_field, task)
	local head = ch[head_field]
	if head then
		local tail = head.t_svcprev
		task.t_svcprev = tail
		tail.t_svcnext = task
		head.t_svcprev = task
	else
		task.t_svcprev = task
		ch[head_field] = task
	end
	task.t_svcnext = false
end

local function unlink_task(ch, head_field, task)
	local prev, next = task.t_svcprev, task.t_svcnext
	if task == ch[head_field] then	-- the head
		ch[head_field] = next
		if next then next.t_svcprev = prev end
	elseif next then		-- in the middle
		if next then next.t_svcprev = prev end
		if prev then prev.t_svcnext = next end
	else	-- the tail
		prev.t_svcnext = false
		ch[head_field].t_svcprev = prev
	end
end


local message_channel = {}
message_channel.__index = message_channel


function message_channel.new(cap)
	cap = cap or 0
	return setmetatable({
		ch_cap = cap,
		ch_num = 0,
		ch_rcursor = 1,
		ch_wcursor = 1,
		ch_msgring = cap > 0 and table.array(cap) or false,
		ch_wtaskq = false,
		ch_rtaskq = false,
	}, message_channel)
end

function message_channel:read(sec)
	local num = self.ch_num
	if num < 0 then
		return nil, EPIPE
	elseif num > 0 then
		-- remove from the message ring and increment ch_rcursor.
		local rcursor = self.ch_rcursor
		local msg = self.ch_msgring[rcursor]
		self.ch_msgring[rcursor] = false  -- unreference the message
		if rcursor == self.ch_cap then
			rcursor = 1
		else
			rcursor = rcursor + 1
		end
		self.ch_rcursor = rcursor

		-- if any wtask pending, append the head task's message into the message ring,
		-- and wake it up; otherwise decrement ch_num.
		local head = self.ch_wtaskq
		if head then
			local wcursor = self.ch_wcursor
			self.ch_msgring[wcursor] = head.t_svcreq
			if wcursor == self.ch_cap then
				wcursor = 1
			else
				wcursor = wcursor + 1
			end
			self.ch_wcursor = wcursor
			resume_task(head)

			local next = head.t_svcnext
			self.ch_wtaskq = next
			if next then
				next.t_svcprev = head.t_svcprev
			end
		else
			self.ch_num = num - 1
		end

		return msg, 0
	else
		local head = self.ch_wtaskq
		if head then
			local msg = head.t_svcreq
			local next = head.t_svcnext
			self.ch_wtaskq = next
			if next then
				next.t_svcprev = head.t_svcprev
			end
			resume_task(head)
			head.t_svcreq = false
			return msg
		else
			local current = current_task()
			push_task(self, 'ch_rtaskq', current)
			current.t_blockedby = self
			local err = block_task(sec or -1)
			if err ~= 0 then
				if self.ch_rtaskq ~= -1 then
					unlink_task(self, 'ch_rtaskq', current)
				end
				return nil, err
			end

			local msg = current.t_svcreq
			current.t_svcreq = false
			return msg, 0
		end
	end
end
message_channel.recv = message_channel.read

function message_channel:write(msg, sec)
	local head = self.ch_rtaskq
	if head == -1 then
		return EPIPE
	elseif head then
		local next = head.t_svcnext
		self.ch_rtaskq = next
		if next then
			next.t_svcprev = head.t_svcprev
		end

		head.t_svcreq = msg
		resume_task(head)
		return 0
	else
		local cap = self.ch_cap
		if cap > 0 then
			local num = self.ch_num
			if num < cap then
				local wcursor = self.ch_wcursor
				self.ch_msgring[wcursor] = msg
				if wcursor == cap then
					wcursor = 1
				else
					wcursor = wcursor + 1
				end
				self.ch_wcursor = wcursor
				self.ch_num = num + 1
				return 0
			end
		end

		local current = tasklet.current_task()
		push_task(self, 'ch_wtaskq', current)
		current.t_svcreq = msg
		current.t_blockedby = self
		local err = block_task(sec or -1)
		if err ~= 0 then
			if self.ch_wtaskq ~= -1 then
				unlink_task(self, 'ch_wtaskq', current)
			end
		end
		return err
	end
end

message_channel.send = message_channel.write

function message_channel:post(msg)
	local head = self.ch_rtaskq
	if head then
		assert(not self.ch_wtaskq)

		local next = head.t_svcnext
		self.ch_rtaskq = next
		if next then
			next.t_svcprev = head.t_svcprev
		end

		head.t_svcreq = msg
		resume_task(head)
		return true
	else
		local cap = self.ch_cap
		if cap > 0 then
			local num = self.ch_num
			if num < cap then
				local wcursor = self.ch_wcursor
				self.ch_msgring[wcursor] = msg
				if wcursor == cap then
					wcursor = 1
				else
					wcursor = wcursor + 1
				end
				self.ch_wcursor = wcursor
				self.ch_num = num + 1
				return true
			end
		end
	end
	return false
end

function message_channel:close()
	local num = self.ch_num
	if num == -1 then
		return
	end

	local rhead, whead = self.ch_rtaskq, self.ch_wtaskq
	self.ch_num = -1
	self.ch_rtaskq = -1
	self.ch_wtaskq = -1

	while rhead do
		resume_task(rhead, EPIPE)
		rhead = rhead.t_svcnext
	end
	while whead do
		resume_task(whead, EPIPE)
		whead = whead.t_svcnext
	end

	if num > 0 then
		local cursor = self.ch_rcursor
		local cap = self.ch_cap
		local ring = self.ch_msgring
		while num > 0 do
			ring[cursor] = false
			cursor = cursor + 1
			if cursor == cap then
				cursor = 1
			end
			num = num - 1
		end
	end
end

tasklet.message_channel = message_channel
return tasklet
