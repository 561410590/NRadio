
--
-- Copyright (C) spyder
--


local tasklet = require 'tasklet.channel._stream'
local ssl = require 'ssl2'
local os, errno, socket = os, errno, socket

local ETIMEDOUT, EBADF  = errno.ETIMEDOUT, errno.EBADF

local block_task, resume_task, current_task = tasklet._block_task, tasklet._resume_task, tasklet.current_task
local add_handler, mod_handler, del_handler = tasklet.add_handler, tasklet.mod_handler, tasklet.del_handler
local READ, WRITE, EDGE = tasklet.EVT_READ, tasklet.EVT_WRITE, tasklet.EVT_EDGE

local EWANTR, EWANTW, EZERORET = ssl.ERROR_WANT_READ, ssl.ERROR_WANT_WRITE, ssl.ERROR_ZEROR_RETURN

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
-- Note that sslstream channel
local CH_HALFCLOSED = 0

-- TCP connection is in progress
local CH_CONNECTING = 1

-- TCP connection established
local CH_TCP = 2

-- SSL handshake is in progress
local CH_HANDSHAKING = 3

-- SSL connection established
local CH_SSL = 4

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
	local handler = ch_evthandlers[self.ch_state]
	if handler then
		local r, w = handler(self, fd, revents)
		if r and self.ch_rtask then
			resume_task(self.ch_rtask)
		end
		if w and self.ch_wtask then
			resume_task(self.ch_wtask)
		end
	end
end

local sslstream_channel = tasklet._stream_channel_prototype()
local sslstream_channel_meta = {
	__index = sslstream_channel,
	__call = ch_onevents,
}
tasklet.sslstream_channel = sslstream_channel

-- Create an sslstream channel
--
-- If 'fd' is valid, then the channel runs in accept-mode, otherwise in connect-mode.
--
-- 'conf.ctx' is used as the SSL context, if absent, fall back to the default SSL context
-- specified in sslstream_channel.ctx which you have to init by yourself.
function sslstream_channel.new(fd, rbufsiz, ctx)
	fd = fd or -1

	local state = fd >= 0 and CH_TCP or CH_CLOSED
	local ctx = ctx or sslstream_channel.ctx
	if not ctx then
		error('either specified ctx in argument #3 or set sslstream_channel.ctx to the default global one')
	end

	local ch = setmetatable({
		ch_fd = fd,
		ch_state = state,
		ch_err = 0,
		ch_rbufsiz = rbufsiz or CONF_RBUFSIZ,
		ch_rbuf = buffer.new(),
		ch_rlasterr = 0,
		ch_nreq = 0,
		ch_nshift = 0,
		ch_rtask = false,
		ch_wtask = false,
		ch_wlasterr = 0,
		ch_stask = false,
		ch_events = READ + EDGE,
		ch_line = false,
		ch_ctx = ctx,
	}, sslstream_channel_meta)

	if fd >= 0 then
		os.setnonblock(fd)
		add_handler(fd, ch.ch_events, ch)
		ssl.attach(fd, ctx)
		ssl.set_accept_state(fd)
	end
	return ch
end

-- DEPRECATED
tasklet.create_sslstream_channel = sslstream_channel.new

ch_evthandlers[CH_HANDSHAKING] = function (self, fd, revents)
	local err = ssl.do_handshake(fd)

	if err == EWANTW then
		ch_addwrite(self)
	else
		ch_delwrite(self)
		if err ~= EWANTR then
			self.ch_err = err
			return true
		end
	end
end

-- Make a SSL handshake
--
-- Return 0 if succeed, ETIMEDOUT if timed out.
-- Otherwise return a negative value if an SSL error occured. In this case (-err) is the SSL error code
function sslstream_channel:handshake(sec)
	local state = self.ch_state
	if state ~= CH_TCP then
		error('required to be in established raw tcp state')
	end

	local fd = self.ch_fd
	local err = ssl.do_handshake(fd)
	if err == EWANTR or err == EWANTW then
		if err == EWANTW then
			ch_addwrite(self)
		end
		local task = current_task()
		self.ch_state = CH_HANDSHAKING
		self.ch_rtask = task
		task.t_blockedby = self
		err = block_task(sec or -1)
		self.ch_rtask = false
		if err == 0 then
			err = -self.ch_err
		end
	else
		err = -err
	end

	if err == 0 then
		self.ch_state = CH_SSL
	else
		ssl.detach(self.ch_fd)
		if err ~= EBADF then
			os.close(self.ch_fd)
			self.ch_fd = -1
		end
		self.ch_state = CH_ERRORED
	end
	return err
end

ch_evthandlers[CH_CONNECTING] = function (self, fd, revents)
	self.ch_err = socket.getsocketopt(fd, socket.SO_ERROR)
	return true
end

function sslstream_channel:connect(addr, port, sec, localip)
	local fd = self.ch_fd
	if fd >= 0 then
		-- we can't just invoke os.close(fd), better to throw an error
		error('unable to connect a new address when still in connection')
	end

	local ctx = self.ch_ctx
	local family = addr:find(':') and socket.AF_INET6 or socket.AF_INET
	local tm_start = tasklet.now
	fd, err = socket.async_connect(addr, port, family, localip)
	if fd < 0 then
		return err
	end

	sec = sec or -1

	-- still in progress
	if err ~= 0 then
		self.ch_state = CH_CONNECTING
		self.ch_events = READ + WRITE + EDGE
		add_handler(fd, self.ch_events, self)

		local task = current_task()
		task.t_blockedby = self
		self.ch_rtask = task
		err = block_task(sec)
		self.ch_rtask = false
		if err == 0 then
			err = self.ch_err
		end
		if err ~= 0 then
			tasklet.del_handler(fd)
			os.close(fd)
			self.ch_state = CH_CLOSED
			return err
		end
	end

	if sec > 0 then
		local elapsed = tasklet.now - tm_start
		if elapsed >= sec then
			tasklet.del_handler(fd)
			os.close(fd)
			self.ch_state = CH_CLOSED
			return ETIMEDOUT
		end
		sec = sec - elapsed
	end

	self.ch_fd = fd
	self.ch_state = CH_TCP
	ssl.attach(fd, ctx)
	ssl.set_connect_state(fd)
	return self:handshake(sec)
end

-- return (r, w, err)
local function ch_read(self, fd, siz)
	local rbuf = self.ch_rbuf
	local r, w = false, false

	siz = siz or (self.ch_rbufsiz - #rbuf)
	local nread, err = ssl.readb(fd, rbuf, siz)
	if err == 0 then
		-- if some task is reading-blocked, we have to check that we have received
		-- enough data to make the task happy.
		if self.ch_rtask then
			local nreq = self.ch_nreq
			if nreq > 0 then
				if #rbuf >= nreq then -- enough bytes
					r = true
				end
			else
				local line = rbuf:getline()
				if line then -- got a line
					self.ch_line = line
					r = true
				end
			end
		else
			r = true
		end
	elseif err == EWANTR or err == EWANTW then
		-- nothing to do
	elseif err == EZERORET then
		self.ch_state = CH_HALFCLOSED
		r = true
	else
		err = -err
		self.ch_state = CH_ERRORED
		self.ch_err = err
		r = true
		w = true
	end
	return r, w, err
end

-- Refer to stream_channel:read() for more details. They are twins.
function sslstream_channel:read(bytes, sec)
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

		local updated, w, err = ch_read(self, self.ch_fd)
		if w then
			resume_task(self.ch_wtask)
		end
		if err == EWANTW then
			ch_addwrite(self)
		end

		if not updated then
			if sec >= 0 then
				sec = sec - (tasklet.now - tm_start)
				if sec <= 0 then
					return nil, ETIMEDOUT
				end
			end

			self.ch_state = CH_SSL
			self.ch_nreq = bytes or -1
			self.ch_rtask = task
			self.ch_rlasterr = err
			task.t_blockedby = self
			err = block_task(sec)
			self.ch_rtask = false
			self.ch_rlasterr = 0

			if err ~= 0 then
				return nil, err
			end
		end

		state = self.ch_state
		if state < 0 then
			return nil, self.ch_err
		end
	end
end

-- Refer to stream_channel:write() for more details. They are twins.
function sslstream_channel:write(data, sec)
	local state = self.ch_state

	if state == CH_CLOSED then
		return EBADF
	end

	if self.ch_wtask then
		error('another task is writing-blocked on this sslstream channel')
	end

	if state == CH_ERRORED then
		return self.ch_err
	end

	local datasiz = #data
	if datasiz == 0 then
		return 0
	end

	sec = sec or -1
	local task = current_task()
	local tm_start = tasklet.now
	local offset = 0
	local fd = self.ch_fd

	while datasiz > 0 do
		local nwritten, err = ssl.writeb(fd, data, offset, datasiz)
		if err == 0 then
			datasiz = datasiz - nwritten
			offset = offset + nwritten
		else
			if err == EZERORET then
				self.ch_state = CH_HALFCLOSED
				if self.ch_rtask then
					resume_task(self.ch_rtask)
				end
			elseif err ~= EWANTR and err ~= EWANTW then  -- unacceptable error
				self.ch_state = CH_ERRORED
				err = -err
				self.ch_err = err
				if self.ch_rtask then
					resume_task(self.ch_rtask, err)
				end
				return err
			end

			-- check if already timed out
			if sec >= 0 then
				sec = sec - (tasklet.now - tm_start)
				if sec <= 0 then
					return ETIMEDOUT
				end
			end

			local wevt = btest(self.ch_events, WRITE)
			if err == EWANTR then
				-- lack of input data, so cancel watching write event
				if wevt then
					ch_delwrite(self)
				end
			else
				if not wevt then
					ch_addwrite(self)
				end
			end

			task.t_blockedby = self
			self.ch_wlasterr = err
			self.ch_wtask = task
			err = block_task(sec, task)
			self.ch_wtask = false
			self.ch_wlasterr = 0

			if err ~= 0 then
				return err
			end

			if self.ch_state < 0 then
				return self.ch_err
			end
		end  -- ssl.writeb() ~= 0
	end -- while datasiz > 0
	return 0
end

ch_evthandlers[CH_SSL] = function (self, fd, revents)
	local stask = self.ch_stask
	if stask then
		local err = ssl.shutdown(fd)
		if err ~= EWANTR and err ~= EWANTW then
			resume_task(stask)
		end
		return  -- XXX
	end

	local rtask, wtask, stask = self.ch_rtask, self.ch_wtask, self.ch_stask
	local rerr, werr = self.ch_rlasterr, self.ch_wlasterr
	local r, w =  false, false

	if btest(revents, READ) then
		if wtask and werr == EWANTR then
			w = true
		end

		if rtask and rerr == EWANTR then
			local _r, _w, err = ch_read(self, fd)
			r = _r
			w = w or _w

			if err == EWANTW and (not wtask or werr == EWANTR) then
				ch_addwrite(self)
			end
		end
	end

	if btest(revents, WRITE) then
		if wtask and werr == EWANTW then
			w = true
		end

		if rtask and rerr == EWANTW then
			local _r, _w, err = ch_read(self, fd)
			r = r or _r
			w = w or _w
		elseif not w then
			ch_delwrite(self)
		end
	end
	return r, w
end

ch_evthandlers[CH_HALFCLOSED] = ch_evthandlers[CH_SSL]

function sslstream_channel:close(sec, cb_post_shutdown)
	local fd = self.ch_fd
	if fd >= 0 then
		if ssl.isattached(fd) then
			if self.ch_stask then
				error('another task is shutting down the ssl socket')
			end

			local _, err = ssl.shutdown(fd)
			if err == EWANTR or err == EWANTW then
				if err == EWANTW then
					ch_addwrite(self)
				end

				local task = current_task()
				self.ch_stask = task
				task.t_blockedby = self
				block_task(sec or 3)
				self.ch_stask = false
			end
			ssl.detach(fd)
		end

		if cb_post_shutdown then
			cb_post_shutdown(self)
		end

		os.close(fd)
		self.ch_fd = -1
		if self.ch_rbuf then
			self.ch_rbuf:reset()
		end
		self.ch_nshift = 0
		self.ch_nreq = 0
		self.ch_state = CH_CLOSED
		self.ch_err = EBADF

		if self.ch_rtask then
			resume_task(self.ch_rtask, EBADF)
		end
		if self.ch_wtask then
			resume_task(self.ch_wtask, EBADF)
		end
	end
end

return tasklet
