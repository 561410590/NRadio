
--
-- Copyright (C) spyder
--


local tasklet = require 'tasklet'
local block_task, resume_task, current_task = tasklet._block_task, tasklet._resume_task, tasklet.current_task

local error = error
local ETIMEDOUT, EAGAIN = errno.ETIMEDOUT, errno.EAGAIN

-- XXX: maybe a light user data is better
local MARK_NOT_IN_CHAIN = 0xf0403023

local svc_reqing, svc_resping = false, false

local svc_byname = {}


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

local function push_task(obj, head_field, task)
	local head = obj[head_field]
	if head then
		local tail = head.t_svcprev
		task.t_svcprev = tail
		tail.t_svcnext = task
		head.t_svcprev = task
	else
		task.t_svcprev = task
		obj[head_field] = task
	end
	task.t_svcnext = false
end

-- obj is the object holding the task list
local function unlink_task(obj, head_field, task)
	local prev, next = task.t_svcprev, task.t_svcnext
	if task == obj[head_field] then	-- in the head
		obj[head_field] = next
		if next then next.t_svcprev = prev end
	elseif next then		-- in the middle
		if next then next.t_svcprev = prev end
		if prev then prev.t_svcnext = next end
	else	-- in the tail
		prev.t_svcnext = false
		obj[head_field].t_svcprev = prev
	end
end

local function serve(owner, svc)
	while not svc.svc_taskq or svc.svc_inresping do
		owner.t_blockedby = svc
		block_task(-1)
	end

	local task = svc.svc_taskq
	svc.svc_tmhandle = tasklet.now
	local resp, err = svc.svc_handler(svc, task.t_svcreq)

	-- the requesting task may have timed out (removed from task queue)
	-- so we need to check it first.
	if task == svc.svc_taskq then
		svc.svc_resp = resp
		svc.svc_task = task
		task.t_err = err
		task.t_svcreq = MARK_NOT_IN_CHAIN
		unlink_task(svc, 'svc_taskq', task)
		svc.svc_inresping = true
		svc.svc_next = svc_resping
		svc_resping = svc
	end
end

local function multi_serve(owner, svc, num, sec)
	if svc.svc_nreq < num or svc.svc_inresping then
		owner.t_blockedby = svc
		svc.svc_nwait = num
		block_task(sec)
		svc.svc_nwait = 0x7fffffff
	end

	if svc.svc_inresping then
		return
	end

	local nhandle = svc.svc_nreq
	if nhandle > num then
		nhandle = num
	end

	if nhandle > 0 then
		local task = svc.svc_taskq
		local reqarr = svc.svc_reqarr
		local resparr = svc.svc_resparr
		local taskarr = svc.svc_taskarr
		local errarr = svc.svc_errarr

		for i = 1, nhandle do
			reqarr[i] = task.t_svcreq
			resparr[i] = nil
			errarr[i] = 0
			task.t_svcreq = MARK_NOT_IN_CHAIN
			taskarr[i] = task
			task = task.t_svcnext
		end

		svc.svc_nreq = svc.svc_nreq - nhandle
		if task then
			task.t_svcprev = svc.svc_taskq.t_svcprev
			svc.svc_taskq = task
		else
			svc.svc_taskq = false
		end

		svc.svc_tmhandle = tasklet.now
		svc.svc_nhandle = nhandle
		svc.svc_handler(reqarr, svc.svc_resparr, errarr, nhandle)

		svc.svc_inresping = true
		svc.svc_next = svc_resping
		svc_resping = svc
	end
end

-- cb is running in a separate task
function tasklet.create_service(name, cb)
	if svc_byname[name] then
		error('service ' .. name .. ' already exists')
	end

	local svc = {
		svc_name = name,
		svc_owner = false,
		svc_taskq = false,  -- queued tasks that are requesting
		svc_resp = false,
		svc_next = false,
		svc_task = false,
		svc_tmhandle = false,
		svc_inreqing = false,
		svc_inresping = false,
		svc_handler = cb,
	}
	svc.svc_owner = tasklet.start_task(function ()
		local owner = tasklet.current_task()
		while true do
			serve(owner, svc)
		end
	end)
	svc_byname[name] = svc
	return svc
end

function tasklet.create_multi_service(name, cb, max_concurrent, interval)
	if svc_byname[name] then
		error('service ' .. name .. ' already exists')
	end

	local svc = {
		svc_name = name,
		svc_owner = false,
		svc_inreqing = false,
		svc_inresping = false,
		svc_reqarr = table.array(max_concurrent),
		svc_resparr = table.array(max_concurrent),
		svc_errarr = table.array(max_concurrent),
		svc_taskarr = table.array(max_concurrent),
		svc_tmhandle = false,
		svc_nhandle = false,
		svc_nwait = 0x7fffffff,
		svc_taskq = false, -- requesting task list
		svc_nreq = 0,   -- number of elements of requesting task list
		svc_next = false,
		svc_handler = cb,
	}
	svc_byname[name] = svc
	svc.svc_owner = tasklet.start_task(function ()
		local owner = tasklet.current_task()
		interval = interval or 1
		while true do
			multi_serve(owner, svc, max_concurrent, interval)
		end
	end)
	return svc
end

local function service_request(svc, req, sec)
	local task = current_task()

	-- if owner is serving-blocked, put svc in the svc_reqing chain to resume the owner later
	if not svc.svc_next and not svc.svc_inreqing and svc.svc_owner.t_blockedby == svc then
		svc.svc_next = svc_reqing
		svc_reqing = svc
		svc.svc_inreqing = true
	end

	-- push the current task in the waiting task queue
	task.t_svcreq = req
	task.t_svcreqtime = tasklet.now
	task.t_blockedby = svc
	push_task(svc, 'svc_taskq', task)

	local err = block_task(sec or -1)
	if err == 0 then
		return task.t_svcresp, task.t_err
	else
		if task.t_svcreq ~= MARK_NOT_IN_CHAIN then
			unlink_task(svc, 'svc_taskq', task)
		end
		task.t_svcreqtime = false
		return nil, err
	end
end

-- return the response from the service-provider or nil if timed out
local function multi_service_request(svc, req, sec)
	local task = current_task()

	task.t_svcreq = req
	task.t_svcreqtime = tasklet.now
	push_task(svc, 'svc_taskq', task)
	task.t_blockedby = svc

	svc.svc_nreq = svc.svc_nreq + 1
	if not svc.svc_next and not svc.svc_inreqing
		and svc.svc_nreq >= svc.svc_nwait and svc.svc_owner.t_blockedby == svc then
		svc.svc_inreqing = true
		svc.svc_next = svc_reqing
		svc_reqing = svc
	end

	local err = block_task(sec or -1)
	if err == 0 then
		return task.t_svcresp, task.t_err
	else
		if task.t_svcreq ~= MARK_NOT_IN_CHAIN then
			unlink_task(svc, 'svc_taskq', task)
			svc.svc_nreq = svc.svc_nreq - 1
		end
		task.t_svcreqtime = false
		return nil, err
	end
end

function tasklet.request(svc, req, sec)
	if type(svc) == 'string' then
		svc = svc_byname[svc]
		if not svc then
			error('')
		end
	end
	return (svc.svc_nwait and multi_service_request or service_request)(svc, req, sec)
end

function tasklet.find_service(name)
	return svc_byname[name]
end

local function service_schedule()
	local svc = svc_reqing
	local busy_list = false
	local task, next
	while svc do
		next = svc.svc_next
		task = svc.svc_owner
		if task.t_blockedby == svc then  -- owner task is available
			svc.svc_next = false
			svc.svc_inreqing = false
			resume_task(task)
		else  -- owner task is busy (blocked by something else, usually a channel)
			svc.svc_next = busy_list
			busy_list = svc
		end
		svc = next
	end
	svc_reqing = busy_list

	svc = svc_resping
	while svc do
		next = svc.svc_next

		if svc.svc_nwait then   -- a multi service
			if not svc.svc_inreqing and svc.svc_nreq >= svc.svc_nwait then
				svc.svc_next = svc_reqing
				svc_reqing = svc
				svc.svc_inreqing = true
			else
				svc.svc_next = false
			end

			local taskarr = svc.svc_taskarr
			local resparr = svc.svc_resparr
			local errarr = svc.svc_errarr
			local n = svc.svc_nhandle
			local tm = svc.svc_tmhandle
			for i = 1, n do
				task = taskarr[i]
				if task.t_blockedby == svc then
					local reqtime = task.t_svcreqtime
					if reqtime and reqtime <= tm then
						task.t_svcresp = resparr[i]
						task.t_err= errarr[i]
						resume_task(task)
					end
				end
			end
		else
			if not svc.svc_inreqing and svc.svc_taskq then
				svc.svc_next = svc_reqing
				svc_reqing = svc
				svc.svc_inreqing = true
			else
				svc.svc_next = false
			end

			local task = svc.svc_task
			if task.t_blockedby == svc then
				local reqtime = task.t_svcreqtime
				if reqtime and reqtime <= svc.svc_tmhandle then
					task.t_svcresp = svc.svc_resp
					resume_task(task)
				end
			end
		end

		svc.svc_inresping = false
		svc = next
	end
	svc_resping = false
end

table.insert(tasklet._nonevent_modules, service_schedule)

return tasklet
