
--
-- Copyright (C) spyder
--

local tasklet = require 'tasklet'
local recvfrom, recvfromb = socket.recvfrom, socket.recvfromb

local current_task = tasklet.current_task
local block_task = tasklet._block_task
local resume_task = tasklet._resume_task

function tasklet.set_dgramfd(fd)
	local task = current_task()
	local handler = function (fd)
		task.t_rdgram = true
		if task.t_blockedby == fd then
			resume_task(task)
		end
	end
	task.t_rdgram = false  -- fd may be readable(should at least be reading-tested first)
	task.t_dgramfd = fd
	tasklet.add_handler(fd, tasklet.EVT_READ + tasklet.EVT_EDGE, handler)
end

-- str, addr, port, err = tasklet.recvfrom(sec)
function tasklet.recvfrom(sec)
	local task = current_task()
	local fd = task.t_dgramfd

	local str, addr, port, err
	if task.t_rdgram then
		str, addr, port, err = socket.recvfrom(fd)
		if str and err == 0 then
			return str, addr, port, err
		else
			task.t_rdgram = false
		end
	end

	task.t_blockedby = fd
	err = block_task(sec or -1, task)
	task.t_blockedby = false
	if err == 0 then
		return socket.recvfrom(fd)
	else
		return nil, nil, nil, err
	end
end

-- nread, addr, port, err = tasklet.recvfromb(buf, sec)
function tasklet.recvfromb(buf, sec)
	local task = current_task()
	local fd = task.t_dgramfd

	local nread, addr, port, err
	if task.t_rdgram then
		nread, addr, port, err = socket.recvfromb(fd, buf)
		if nread > 0 and err == 0 then
			return nread, addr, port, err
		else
			task.t_rdgram = false
		end
	end

	task.t_blockedby = fd
	err = block_task(sec or -1, task)
	task.t_blockedby = false
	if err == 0 then
		return socket.recvfromb(fd, buf)
	else
		return nil, nil, nil, err
	end
end

return tasklet
