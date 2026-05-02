
--
-- Copyright (C) spyder
--


local tasklet = require 'tasklet'
local os, socket, errno = os, socket, errno

local block_task, resume_task = tasklet._block_task, tasklet._resume_task

local ETIMEDOUT, EBADF, EAGAIN = errno.ETIMEDOUT, errno.EBADF, errno.EAGAIN

local streamserver_channel = {
	__call = function (self, fd, revents)
		self.ch_pending = true
		if self.ch_task then
			resume_task(self.ch_task)
			self.ch_task = false
		end
	end,
}
streamserver_channel.__index = streamserver_channel

function streamserver_channel:accept(sec)
	local fd = self.ch_fd
	local peerfd, peeraddr, peerport, err = -1, nil, nil, EBADF
	while fd >= 0 do
		if self.ch_pending then
			peerfd, peeraddr, peerport, err = socket.accept(fd)
			if err == 0 then
				break
			elseif err == EAGAIN then
				self.ch_pending = false
			else
				require('log').error('unknown accept error: ', err)
			-- for other errors, 'accept' again.
			end
		end

		if not self.ch_pending then
			local task = tasklet.current_task()
			sec = sec or -1
			if sec ~= 0 then
				task.t_blockedby = self
				self.ch_task = task
				err = block_task(sec)
				self.ch_task = false
			elseif sec == 0 then
				err = ETIMEDOUT
			end

			if err ~= 0 then
				break
			end
			fd = self.ch_fd
		end
	end
	peerfd = peerfd or -1
	return peerfd, peeraddr, peerport, err
end

function streamserver_channel:close()
	local fd = self.ch_fd
	if fd >= 0 then
		tasklet.del_handler(fd)
		os.close(fd)
		self.ch_fd = -1
		if self.ch_task then
			resume_task(self.ch_task)
			self.ch_task = false
		end
	end
end

local function create_streamserver_channel(addr, port, backlog)
	local family = socket.AF_INET
	if addr then
		if addr:find('^/') then
			family = socket.AF_UNIX
			fs.unlink(addr)
		elseif addr:find(':') then
			family = socket.AF_INET6
		end
	else
		addr = '0.0.0.0'
	end

	local fd, err = socket.socket(family, socket.SOCK_STREAM)
	if fd < 0 then
		return nil, err
	end

	if family ~= socket.AF_UNIX then
		socket.setsocketopt(fd, socket.SO_REUSEADDR, true)
	end
	err = socket.bind(fd, addr, port or 0)
	if err ~= 0 then
		os.close(fd)
		return nil, err
	end
	socket.listen(fd, backlog)
	os.setnonblock(fd)

	local ch = setmetatable({
		ch_fd = fd,
		ch_family = family,
		ch_events = tasklet.EVT_READ + tasklet.EVT_EDGE,
		ch_task = false,
		ch_pending = false,
	}, streamserver_channel)
	tasklet.add_handler(fd, ch.ch_events, ch)
	return ch, 0
end

function tasklet.create_tcpserver_channel(addr, port, backlog)
	return create_streamserver_channel(addr, port, backlog)
end

function tasklet.create_unserver_channel(path)
	return create_streamserver_channel(path, 0)
end

return tasklet
