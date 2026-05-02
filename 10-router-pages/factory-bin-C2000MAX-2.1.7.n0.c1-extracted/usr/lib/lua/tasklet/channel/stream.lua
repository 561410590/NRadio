
--
-- Copyright (C) spyder
--


local tasklet = require 'tasklet.channel._stream'
local os, errno, socket = os, errno, socket

local ETIMEDOUT, EBADF = errno.ETIMEDOUT, errno.EBADF

local block_task, resume_task, current_task = tasklet._block_task, tasklet._resume_task, tasklet.current_task
local add_handler, mod_handler, del_handler = tasklet.add_handler, tasklet.mod_handler, tasklet.del_handler
local READ, WRITE, EDGE = tasklet.EVT_READ, tasklet.EVT_WRITE, tasklet.EVT_EDGE
local HUP = poll.HUP

-- still use bit32 functions so this code runs on lua version < 5.3
local btest = bit32.btest

local CONF_RBUFSIZ = 4096

-------------------------------------------------------------------------------
-- channel states {

-- Channel is closed (ch:error() is called, and the internal file descriptor is closed).
-- In this state, no more I/O operations are allowed, although reduplicated close is not
-- regarded as an error(but will be ignored)
local CH_CLOSED = -2

-- I/O error occured
local CH_ERRORED = -1

-- The other side has stopped reading.
local CH_HALFCLOSED = 0

-- Connecting
local CH_CONNECTING = 1

-- Connection established
local CH_ESTABLISHED = 2

-- On read events, if we still have unread data in the underlayer
-- after filling channel's rbuf, then we change the channel's state into CH_READABLE.
-- if a channel is in CH_READABLE state, we always try to read the underlayer until
-- data is exhausted, then we change the state back.
local CH_READABLE  = 3


-- Generally, values > 0 means that the connection is GOOD, <= 0 means BAD or at
-- least not something unnormal happened and you have a good reason to close it.

-- }
------------------------------------------------------------------------------

-- {[state] = handler}
local ch_evthandlers = {}

local function ch_addwrite(self)
	local events = self.ch_events
	if not btest(events, WRITE) then
		events = events + WRITE
		mod_handler(self.ch_fd, events)
		self.ch_events = events
	end
end

local function ch_delwrite(self)
	local events = self.ch_events
	if btest(events, WRITE) then
		events = events - WRITE
		mod_handler(self.ch_fd, events)
		self.ch_events = events
	end
end

local function ch_onevents(self, fd, revents)
	local state = self.ch_state
	local handler = ch_evthandlers[state]

	if handler then
		local r, w = handler(self, fd, revents)
		if r and self.ch_rtask then
			resume_task(self.ch_rtask)
		end
		if w and self.ch_wtask then
			resume_task(self.ch_wtask)
		end
	elseif btest(revents, WRITE) then
		ch_delwrite(self)
	end
end


local stream_channel = tasklet._stream_channel_prototype()
local stream_channel_meta = {
	__index = stream_channel,
	__call = ch_onevents,
}
tasklet.stream_channel = stream_channel

local function new_stream_channel(fd, rbufsiz)
	local state = fd >= 0 and CH_ESTABLISHED or CH_CLOSED
	local ch = setmetatable({
		ch_fd = fd,
		ch_state = state,
		ch_err = 0,
		ch_rbufsiz = rbufsiz or CONF_RBUFSIZ ,
		ch_rbuf = false,
		ch_rreqsiz = 0,
		ch_nshift = 0,
		ch_rtask = false,
		ch_wtask = false,
		ch_events = READ + EDGE,
		ch_line = false,
	}, stream_channel_meta)
	return ch
end

-- Create a stream channel piping from the output of a new process
--
-- 'cmd' is a system command or a callback function executed in the new process
local function create_execl_channel(cmd, rbufsiz)
	local pid
	local rfd, wfd, err = os.pipe()
	if err ~= 0 then
		return nil, err
	end

	pid, err = os.fork()
	if pid < 0 then
		os.close(rfd)
		os.close(wfd)
		return nil, err
	elseif pid == 0 then
		os.dup2(wfd, 1)
		os.close(wfd)

		local null_fd = os.open('/dev/null', os.O_WRONLY)
		if null_fd >= 0 then
			os.dup2(null_fd, 2)
			os.close(null_fd)
		end

		if type(cmd) == 'string' then
			os.execl('/bin/sh', 'sh', '-c', cmd)
		else
			cmd()
		end
		os.exit(0)
	else
		os.close(wfd)
		os.setnonblock(rfd)
		local ch = new_stream_channel(rfd, rbufsiz)
		add_handler(rfd, ch.ch_events, ch)
		return ch, 0
	end
end

-- DEPRECATED
tasklet.create_execl_channel = create_execl_channel

-- Create a new stream channel
--
-- depending on whether fd is a valid file descriptor, the channel
-- may be in established or closed state
--
-- the only usage for closed channel is 'connect'
local function create_stream_channel(fd, rbufsiz)
	fd = fd or -1
	local ch = new_stream_channel(fd, rbufsiz)
	if fd >= 0 then
		os.setnonblock(fd)
		add_handler(fd, ch.ch_events, ch)
	end
	return ch
end

-- DEPRECATED
tasklet.create_stream_channel = create_stream_channel

function stream_channel.new(value, rbufsiz)
	local tvalue = type(value)
	local func = (tvalue == 'nil' or tvalue == 'number') and create_stream_channel or create_execl_channel
	return func(value, rbufsiz)
end


-- Start connecting with a remote peer.
--
-- Return 0 if succeed, otherwise a standard errno code.
--
-- 'addr' must be a legal IPv4/IPv6 address, instead of an unresolved host name
--
-- The channel must be in closed state before connecting, and if not succeed,
-- it will fall back to CH_CLOSED state.
function stream_channel:connect(addr, port, sec, localip)
	local fd = self.ch_fd

	if fd >= 0 then
		os.close(fd)
		fd = -1
		self.ch_fd = -1
	end

	local err
	local family = port and (addr:find(':') and socket.AF_INET6 or socket.AF_INET) or socket.AF_UNIX
	fd, err = socket.async_connect(addr, port, family, localip)
	if fd < 0 then
		return err
	end

	-- if err == 0, then connected, otherwise still in progress

	self.ch_fd = fd
	if err == 0 then
		self.ch_events = READ + EDGE
		self.ch_state = CH_ESTABLISHED
		add_handler(fd, self.ch_events, self)
		return 0
	else
		self.ch_state = CH_CONNECTING
		self.ch_events = READ + WRITE + EDGE
		add_handler(fd, self.ch_events, self)

		local task = current_task()
		task.t_blockedby = self
		self.ch_rtask = task
		err = block_task(sec or -1)
		self.ch_rtask = false

		-- if err is not ETIMEDOUT, then we check the real connectd result
		if err == 0 then
			err = self.ch_err
		end

		if err == 0 then
			self.ch_state = CH_ESTABLISHED
			self.ch_events = READ + EDGE
			mod_handler(fd, self.ch_events)
		else
			self:close()
		end
		return err
	end
end

-- Return (updated, left)
--   updated: true if successfully read some data or ch_state is changed
--   left: bytes left unread in the kernel/underlayer
local function stream_channel_read(self, siz)
	local rbuf = self.ch_rbuf
	if not rbuf then
		rbuf = buffer.new(self.ch_rbufsiz)
		self.ch_rbuf = rbuf
	end

	local left = 0
	local fd = self.ch_fd
	siz = siz or (self.ch_rbufsiz - #rbuf)
	if siz > 0 then
		local nread, err = os.readb(fd, rbuf, siz)
		if nread > 0 then
			--os.writeb(1, rbuf, #rbuf - nread, nread)
			if nread < siz then
				self.ch_state = CH_ESTABLISHED
			else
				left = os.getnread(fd)
				if left > 0 then
					self.ch_state = CH_READABLE
				else
					self.ch_state = CH_ESTABLISHED
				end
			end
		elseif err == 0 then
			self.ch_state = CH_HALFCLOSED
		else
			self.ch_rreqsiz = 0
			self.ch_nshift = 0
			self.ch_state = CH_ERRORED
			self.ch_err = err

			-- wake up the write-waiting task
			if self.ch_wtask then
				resume_task(self.ch_wtask, err)
			end
		end
		return true, left
	else
		return false, left
	end
end

-- Return (data, err)
-- data can be a userdata<reader> (if bytes is specified) or a string (delimited by \r\n or \n)
--
-- Task will get blocked until received exactly specified bytes(or a line, or errored/half-closed)
--
-- If 'bytes' < 0, always get all when available_length >= (-bytes)
--
-- 'bytes' will automatically reduce to rbufsiz if larger than rbufsiz
--
-- On half-closed, return (nil, 0) if reading a line, or whatever already received(even if
-- not enough), and the channel state is changed into CH_HALFCLOSED
--
-- On errored, return (nil, sockerr), and the channel state is changed into CH_ERRORED
--
-- On sec >= 0 and timed-out, return (nil, errno.ETIMEDOUT)
--
-- SAMPLES(errored/half-closed is not taken into consideration):
-- ch:read() 			read a line or infinitely wait
-- ch:read(nil, 1)	 	read a line in 1 second or return the ETIMEDOUT error
-- ch:read(100) 		read 100 bytes or infinitely wait
-- ch:read(9999999, 1)  read 'rbufsiz' bytes in 1 second or return the ETIMEDOUT error
function stream_channel:read(bytes, sec)
	local state = self.ch_state
	local neg = false

	if state == CH_CLOSED then
		return nil, EBADF
	end

	if self.ch_rtask then
		error('another task is reading-blocked on this stream channel')
	end

	if state == CH_ERRORED then
		return nil, self.ch_err
	end

	local rbufsiz = self.ch_rbufsiz
	if bytes then
		if bytes < 0 then
			bytes = -bytes
			neg = true
		elseif bytes > rbufsiz then
			bytes = rbufsiz
		end
	end

	local rbuf = self.ch_rbuf
	if not rbuf then
		rbuf = buffer.new(rbufsiz)
		self.ch_rbuf = rbuf
	end
	if self.ch_nshift > 0 then
		rbuf:shift(self.ch_nshift)
		self.ch_nshift = 0
	end

	sec = sec or -1
	local task = current_task()
	local tm_start = tasklet.now
	while true do
		if bytes then
			local siz = #rbuf
			if siz >= bytes then
				if not neg then
					self.ch_nshift = bytes
					return rbuf:reader(nil, 0, bytes), 0
				else
					self.ch_nshift = siz
					return rbuf:reader(), 0
				end
			elseif state == CH_HALFCLOSED then
				if siz > 0 then
					self.ch_nshift = siz
					return rbuf:reader(), 0
				else
					return nil, 0
				end
			end
		else
			local line = self.ch_line
			if line then
				self.ch_line = false
				return line, 0
			else
				local line = rbuf:getline()
				if line or state == CH_HALFCLOSED then
					return line, 0
				end
			end
		end

		local err = 0
		if state ~= CH_READABLE or not stream_channel_read(self) then
			if sec == 0 then
				return nil, ETIMEDOUT
			end

			local wait_sec = -1
			if sec > 0 then
				local elapsed = tasklet.now - tm_start
				if elapsed >= sec then
					return nil, ETIMEDOUT
				end
				wait_sec = sec - elapsed
			end

			self.ch_rreqsiz = bytes or -1
			self.ch_rtask = task
			task.t_blockedby = self
			err = block_task(wait_sec)
			self.ch_rtask = false
			self.ch_rreqsiz = 0
		end

		state = self.ch_state -- ch_state may have changed
		if err ~= 0 or state < 0 then
			return nil, err ~= 0 and err or self.ch_err
		end
	end
end

-- Write data through the channel
--
-- 'data' is of binary format(userdata<buffer> or userdata<reader>)
--
-- Return err(0 or the posix errno)
function stream_channel:write(data, sec)
	local state = self.ch_state

	if state == CH_CLOSED then
		return EBADF
	end

	if self.ch_wtask then
		error('another task is writing-blocked on this stream channel')
	end

	if state == CH_ERRORED then
		return self.ch_err
	end

	sec = sec or -1
	local task = current_task()
	local tm_start = tasklet.now
	local datasiz = #data
	local offset = 0
	while datasiz > 0 do
		local nwritten, err = os.writeb(self.ch_fd, data, offset, datasiz)
		if err ~= 0 then
			self.ch_state = CH_ERRORED
			self.ch_err = err

			-- wake up the read-waiting task
			if self.ch_rtask then
				resume_task(self.ch_rtask, err)
			end

			return err
		else
			datasiz = datasiz - nwritten
			offset = offset + nwritten
			if datasiz > 0 then
				if sec == 0 then
					return ETIMEDOUT
				end

				--
				ch_addwrite(self)

				local wait_sec = -1
				if sec > 0 then
					local elapsed = tasklet.now - tm_start
					if elapsed >= sec then
						return ETIMEDOUT
					end
					wait_sec = sec - elapsed
				end
				self.ch_wtask = task
				task.t_blockedby = self
				err = block_task(wait_sec)
				self.ch_wtask = false

				if err ~= 0 then
					return err
				end
				if self.ch_state < 0 then
					return self.ch_err
				end
			end
		end
	end
	return 0
end

-- Close the channel(release the internal resource and close related file descriptor)
function stream_channel:close()
	local fd = self.ch_fd
	if fd >= 0 then
		del_handler(fd)
		os.close(fd)
		self.ch_fd = -1
		self.ch_err = EBADF
		if self.ch_rbuf then
			self.ch_rbuf:reset()
		end
		self.ch_nshift = 0
		self.ch_rreqsiz = 0
		self.ch_state = CH_CLOSED

		if self.ch_rtask then
			resume_task(self.ch_rtask)
		end
		if self.ch_wtask then
			resume_task(self.ch_wtask)
		end
	end
end

ch_evthandlers[CH_ESTABLISHED] = function (self, fd, revents)
	local r, w = false, false

	if btest(revents, READ) then
		local updated, left = stream_channel_read(self)
		local state = self.ch_state

		if btest(revents, HUP) and state > 0 then
			state = CH_HALFCLOSED
			self.ch_state = state
			updated = true
		end

		if updated and self.ch_rtask then
			if state ~= CH_ERRORED and state ~= CH_HALFCLOSED then
				local rbuf = self.ch_rbuf
				if self.ch_rreqsiz > 0 then
					if #rbuf >= self.ch_rreqsiz then
						-- enough bytes
						r = true
					end
				else
					local line = rbuf:getline()
					if line then
						-- got a line
						self.ch_line = line
						r = true
					end
				end
			else
				-- must tell the task the channel is errored or half-closed
				r = true
				if state == CH_ERRORED then
					w = true
				end
			end
		elseif left > 0 then
			-- no task is watching and rbuf is full, make the received data stay in
			-- the kernel/underlayer, make a mark and next time we directly read from the kernel/underlayer
			self.ch_state = CH_READABLE
		end
	elseif btest(revents, WRITE) then
		if self.ch_wtask then
			w = true
		else
			-- the EVT_WRITE flag stays turned-on until the task finishes all the writing.
			-- then we'll have a write-triggered channel which is not watched, now it's time
			-- to remove the EVT_WRITE flag
			local events = self.ch_events - WRITE
			self.ch_events = events
			mod_handler(self.ch_fd, events)
		end
	end
	return r, w
end
ch_evthandlers[CH_READABLE] = ch_evthandlers[CH_ESTABLISHED]
ch_evthandlers[CH_HALFCLOSED] = ch_evthandlers[CH_ESTABLISHED]

ch_evthandlers[CH_CONNECTING] = function (self, fd, revents)
	self.ch_err = socket.getsocketopt(fd, socket.SO_ERROR)
	return true
end

return tasklet
