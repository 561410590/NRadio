
--
-- Copyright (C) spyder
--

local string, table, os = string, table, os
local tostring, tonumber, type = tostring, tonumber, type
local ipairs, pairs = ipairs, pairs

local log = require 'mylog'
local tasklet = require 'tasklet'

local M = {}

-- 
function M.start_tcpserver_task(addr, port, cb)
	addr = addr or '0.0.0.0'
	require 'tasklet.channel.streamserver'
	local ch_server = tasklet.create_tcpserver_channel(addr, port) 
					or log.fatal('failed to start tcp server on ', addr, ':', port)
	
	os.setcloexec(ch_server.ch_fd)
	return ch_server, tasklet.start_task(function ()
		while true do 
			local fd, addr, port, err = ch_server:accept(1)
			if fd >= 0 then
				os.setcloexec(fd)
				cb(fd, addr, port)
			end
		end
	end, 'tcpserver@' .. addr .. ':' .. port)
end

function M.start_unserver_task(path, cb)
	require 'tasklet.channel.streamserver'
	local ch_server = tasklet.create_unserver_channel(path) 
					or log.fatal('failed to start unix-domain server on ', path)
	
	os.setcloexec(ch_server.ch_fd)
	return ch_server, tasklet.start_task(function ()
		while true do 
			local fd = ch_server:accept(1)
			if fd >= 0 then
				os.setcloexec(fd)
				cb(fd)
			end
		end
	end, 'unserver@' .. path)
end

-- there is a simple text protocol between the ctlserver and the ctltool
-- 
-- REQUEST = 
-- 		command \r\n
-- 		number of parameters \r\n
--		length of parameter1 \r\n
--		parameter1 \r\n
--		length of parameter2 \r\n 
--		...
--		parameterN
--
-- RESPONSE = 
--		errcode \r\n
--		number of return values \r\n
--		length of value1 \r\n
--		value1 \r\n
--		length of value2 \r\n
--		...
--		valueN \r\n
-- 
-- take ADD(1 + 20 + 300) for example 
--	SEND >>>
-- 		add \r\n
--		3 \r\n
--		1 \r\n
--		1 \r\n
--		2 \r\n
--		20 \r\n
--		3 \r\n
--		300 \r\n
--  RECV <<<
--		0 \r\n
--		1 \r\n
--		3 \r\n
--		321 \r\n
function M.start_ctlserver_task(commands, path)
	require 'tasklet.channel.streamserver'
	require 'tasklet.channel.stream'
	
	local fd = -1
	
	-- XXX: there may be some risk to share one write-buffer among all the connections
	local tmpbuf = tmpbuf
	
	local builtin_commands = {
		logreopen = function (argv)
			log.reopen()
			return 0
		end,
		
		logcapture = function (argv)
			local sockpath = argv[1]
			if sockpath then
				return log.capture(sockpath, argv[2] or 'debug') and 0 or errno.EAGAIN
			else
				return errno.EINVAL
			end
		end,
		
		logrelease = function ()
			log.release()
			return 0
		end,
		
		ping = function ()
			return 0, 'pong'
		end,
		
		eval = function (argv)
			local text = argv[1]
			local msg
			if text then
				local func
				func, msg = loadstring(text)
				if func then
					_, msg = pcall(func)
				end
			end
			return 0, msg
		end,
	}
	
	-- {}  					-> logread enabled (defaulted)
	-- {logread=false}  	-> logread disabled
	-- {logread=true/...}	-> logread enabled (defaulted)
	-- {logread=function}	-> logread enabled (customized)
	for k, v in pairs(builtin_commands) do 
		if commands[k] == nil or (commands[k] and type(commands[k]) ~= 'function') then
			commands[k] = v
		end
	end
	
	local function getreq(ch)
		local cmd = ch:read()
		local argc = ch:read()
		argc = tonumber(argc)
		
		if not cmd or not argc then
			return
		end
		
		local argv = {}
		for i = 1, argc do 
			local len = ch:read()
			len = tonumber(len)
			if not len then return end
			
			local rd = ch:read(len)
			if not rd then return end
			
			table.insert(argv, rd:str())
			ch:read()
		end
		return cmd, argv
	end
	
	local function putresp(ch, err, retv)
		tmpbuf:rewind():putstr(tostring(err), '\r\n')
		local rtype = type(retv)
		if rtype == 'nil' then
			tmpbuf:putstr('0\r\n')
		elseif rtype ~= 'table' then
			retv = tostring(retv)
			tmpbuf:putstr('1\r\n', #retv, '\r\n', retv, '\r\n')
		else
			tmpbuf:putstr(#retv, '\r\n')
			for _, v in ipairs(retv) do 
				v = tostring(v)
				tmpbuf:putstr(#v, '\r\n', v, '\r\n')
			end
		end
		
		-- The following is a little bit UGLY.
		-- 'tmpbuf' is used so we can't block the task here(and this is unlike to happen when data is transfered
		-- through unix-domain socket), thus  we use os.writeb instread of ch:write.
		local all = #tmpbuf
		local done = 0
		local count = 0
		while done < all and count < 3 do
			local n, err = os.writeb(ch.ch_fd, tmpbuf, done)
			if err ~= 0 then
				break
			end
			done = done + n
			if err ~= 0 then
				time.sleep(0.1)
				count = count + 1
			end
		end
	end
	
	local function ctl_loop(fd)
		local ch = tasklet.create_stream_channel(fd, 1024)
		local captured = false
		while true do 
			local cmd, argv = getreq(ch)
			if not cmd then
				break
			end
			
			local err, retv = errno.ENOSYS
			if commands[cmd] then
				err, retv = commands[cmd](argv)
			end
			err = err or 0
			if err == 0 then
				if cmd == 'logcapture' then
					captured = true
				elseif cmd == 'logrelease' then
					captured = false
				end
			end
			
			putresp(ch, err, retv)
		end
		ch:close()
		if captured then
			log.release()
		end
	end
	
	path = path or M.APPNAME or log.fatal("specify 'path' in start_ctlserver_task")
	if not path:find('/') then
		path = '/tmp/' .. path .. '.sock'
	end
	return M.start_unserver_task(path, function (fd)
		tasklet.start_task(function ()
			ctl_loop(fd)
		end, 'general-ctlserver-conn')
	end)
end

local function parse_flimit(value)
	local x, unit = value:match('^([%d%.]+)([kKmM]?)$')
	x = tonumber(x)
	if not x then
		return 
	end
	
	if unit == 'k' or unit == 'K' then
		return x * 1024
	elseif unit == 'm' or unit == 'M' then
		return x * 1024 * 1024
	else
		return x
	end
end

function M.run(opts, cb_preloop)
	-- check APPNAME
	local appname = M.APPNAME
	if not appname then
		log.fatal('APPNAME shall never be empty')
	end
	
	-- daemonize
	local DEBUG = false
	if opts.debug or opts.d then
		DEBUG = true
	end
	if not opts.f and not opts.foreground and not DEBUG then
		daemonize()
	end

	-- make pid file
	local pid = os.getpid()
	local pidfile = '/tmp/' .. appname .. '.pid'
	local file = io.open(pidfile, 'w')
	if file then
		file:write(pid)
		file:close()
	end
	
	-- init log
	local deffile = '/tmp/' .. appname .. '.log'
	opts.logpath = opts.logpath or opts.o
	opts.loglevel = opts.loglevel or opts.l
	local logpath = opts.logpath or (DEBUG and 'stdout' or deffile)
	if logpath == deffile then
		if fs.exists(deffile) then
			fs.rename(deffile, deffile .. '.bak')
		end
	end
	log.init({
		path = logpath,
		level = opts.loglevel or (DEBUG and 'debug' or 'info'),
		flimit = opts.logflimit and parse_flimit(opts.logflimit) or 31 * 1024
	})
	M.DEBUG = DEBUG
	log.info('application started with pid ', pid)
	
	-- signals 
	signal.signal(signal.SIGTERM, function ()
		log.info('got SIGTERM, terminating ...')
		tasklet.term() 
	end)
	signal.signal(signal.SIGQUIT, function ()
		log.info('got SIGQUIT, quitting ...')
		tasklet.quit() 
	end)
	signal.signal(signal.SIGINT, function () tasklet.term() end)
	
	-- looping and cleanup
	if cb_preloop then
		cb_preloop()
	end
	log.info('looping start')
	local ok, msg = xpcall(tasklet.loop, debug.traceback)
	local exitcode = 0
	if not ok then
		if DEBUG then
			print(msg)
		else
			local death_file = '/tmp/' .. appname .. '.death'
			local file = io.open(death_file, 'w')
			if file then
				file:write(tasklet.now_4log, '\n', msg)
				file:close()
			end
		end
		exitcode = 1
	end
	fs.unlink(pidfile)
	
	return exitcode
end

return M

