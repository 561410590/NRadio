

--
-- Copyright (C) spyder
--


require 'std'

local tasklet

local TO_NULL = 0
local TO_STDERR	= 1
local TO_FILE	= 2
local TO_SOCKET	= 3
local TO_SYSLOG = TO_STDERR -- TODO

local LEVEL_DEBUG = 1
local LEVEL_INFO = 2
local LEVEL_WARN = 3
local LEVEL_ERROR = 4
local LEVEL_FATAL = 5

local COLOR_SUFFIX = "\027[0m"
local LEVEL_COLOR_PREFIX = {
	"\027[38m",
	"\027[32m",
	"\027[33m",
	"\027[31m",
	"\027[41;37;1m",
}

local LEVEL_NAME = {
	"debug",
	"info",
	"warn",
	"error",
	"fatal",
}

local LEVEL_NAME_PREFIX = {
	'debug*** ',
	'info *** ',
	'warn *** ',
	'error*** ',
	'fatal*** ',
}

local function parse_level(level)
	if type(level) == "string" then
		if tonumber(level) then
			level = tonumber(level)
		else
			level = string.lower(level)
			for i, v in ipairs(LEVEL_NAME) do
				if v:find(level) == 1 then
					level = i
					break
				end
			end
			if type(level) == "string" then
				level = LEVEL_INFO
			end
		end
	end
	if level < LEVEL_DEBUG or level > LEVEL_FATAL then
		level = LEVEL_INFO
	end
	return level
end


local function create(name)
local M = {}

local log_type = os.isatty(1) and TO_STDERR or TO_SYSLOG
local log_level = LEVEL_DEBUG
local log_path
local log_withcolor = true
local log_withtime = true
local log_fd = -1
local log_flimit = -1
local log_fsize = 0
local log_buf = buffer.new(1024)
local log_inited = false

local bak_fd = -1
local bak_level
local bak_type


M.name = name

-- log system will fallback to the default type if type is not specified or
-- we failed to initialize.
--
-- what the default type is depends how the application is running.
-- if daemonized(os.isatty(1) returns false), we use 'memory', otherwise
-- we use 'stdout'
--
-- thus, M.init must be called AFTER daemonized.
function M.init(conf)
	if log_inited then
		return
	end

	if conf then
		if conf.level ~= nil then
			log_level = parse_level(conf.level)
		end
		if conf.withcolor ~= nil then
			log_withcolor = conf.withcolor
		end
		if conf.withtime ~= nil then
			log_withtime = conf.withtime
		end
		if conf.path ~= nil then
			log_path = string.lower(conf.path)
		end
		if type(conf.flimit) == 'number' and conf.flimit > 0 then
			log_flimit = conf.flimit
		end
		log_fsize = conf.foffset or 0
	end

	if log_path then
		if log_path == 'null' then
			log_type = TO_NULL
		elseif log_path == 'stderr' or log_path == 'stdout' then
			log_type = TO_STDERR
		elseif log_path == 'syslog' then
			log_type = TO_SYSLOG
		else
			log_type = TO_FILE
			log_fd = os.open(log_path, os.O_WRONLY + os.O_TRUNC)
			if log_fd < 0 then
				log_fd = os.creat(log_path, math.oct(644))
			end
		end
	end

	if not log_path or (log_type == TO_FILE and log_fd < 0) then
		if os.isatty(1) then
			log_type = TO_STDERR
		else
			log_type = TO_NULL
		end
	end

	log_inited = true
	tasklet = package.loaded.tasklet
end

-- reopen the logging file (for log-splitting)
function M.reopen()
	if log_type == TO_FILE then
		os.close(log_fd)
		log_fsize = 0
		log_fd = os.open(log_path, os.O_WRONLY + os.O_APPEND)
		if log_fd < 0 then
			log_fd = os.creat(log_path, math.oct(644))
		end
	end
end

function M.capture(sockpath, level)
	if log_type ~= TO_SOCKET then
		local fd = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
		if socket.connect(fd, sockpath) == 0 then
			bak_fd = log_fd
			bak_type = log_type
			bak_level = log_level
			log_fd = fd
			log_level = parse_level(level)
			log_type = TO_SOCKET
			return true
		else
			os.close(fd)
		end
	end
end

function M.release()
	if log_type == TO_SOCKET then
		os.close(log_fd)
		log_fd = bak_fd
		log_level = bak_level
		log_type = bak_type
	end
end

local buf_putstr = buffer.putstr
local time_strftime = time.strftime
local time = time.time
local os = os

local function _log(level, ...)
	if log_type == TO_NULL then
		return
	end

	local withcolor = false
	local buf = log_buf

	if (log_type == TO_STDERR or log_type == TO_SOCKET) and log_withcolor then
		withcolor = true
	end

	if withcolor then
		buf_putstr(buf, LEVEL_COLOR_PREFIX[level])
	end
	if log_withtime then
		buf_putstr(buf, tasklet and tasklet.now_4log or time_strftime('%m-%d %H:%M:%S ', time()))
	end

	buf_putstr(buf, LEVEL_NAME_PREFIX[level])
	buf_putstr(buf, ...)
	if withcolor then
		buf_putstr(buf, COLOR_SUFFIX)
	end
	buf_putstr(buf, '\n')

	if log_type == TO_STDERR then
		os.writeb(2, buf)
	elseif log_fd >= 0 then
		if log_type == TO_FILE and log_flimit > 0 then
			if log_fsize >= log_flimit then
				os.lseek(log_fd, 0, os.SEEK_SET)
				log_fsize = 0
			end
		end
		os.writeb(log_fd, buf)
		log_fsize = log_fsize + #buf
	end
	buf:rewind()
end

function M.debug(...)
	if log_level <= LEVEL_DEBUG and log_type ~= TO_NULL then
		_log(LEVEL_DEBUG, ...)
	end
end

function M.info(...)
	if log_level <= LEVEL_INFO and log_type ~= TO_NULL then
		_log(LEVEL_INFO, ...)
	end
end

function M.warn(...)
	if log_level <= LEVEL_WARN and log_type ~= TO_NULL then
		_log(LEVEL_WARN, ...)
	end
end

function M.error(...)
	if log_level <= LEVEL_ERROR and log_type ~= TO_NULL then
		_log(LEVEL_ERROR, ...)
	end
end

function M.fatal(...)
	if log_type ~= TO_NULL then
		_log(LEVEL_FATAL, ...)
	end
	os.exit(1)
end
return M

end  -- local function create()


return create
