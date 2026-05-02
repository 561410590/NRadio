
--
-- Copyright (C) spyder
--


require '_std'

local string, table = string, table
local ipairs, pairs, next, rawset, rawget = ipairs, pairs, next, rawset, rawget
local type, tostring, tonumber = type, tostring, tonumber

local tmpbuf = buffer.new()

-------------------------------------------------------------------------------
-- io
-------------------------------------------------------------------------------
function io.plines(cmd)
	local file = io.popen(cmd, 'r')
	if file then
		return function ()
				local line = file:read('*line')
				if not line then
					file:close()
				end
				return line
			end
	end
end

-------------------------------------------------------------------------------
-- string
-------------------------------------------------------------------------------
function string.is_ipv4(str)
	local a, b, c, d = string.match(str, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
	a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
	return a and b and c and d 
		and a >= 0 and a <= 255 
		and b >= 0 and b <= 255 
		and c >= 0 and c <= 255 
		and d >= 0 and d <= 255 
end

function string.is_mac(str)
	return str:match('^%s*(%x%x:%x%x:%x%x:%x%x:%x%x:%x%x)%s*$')
end

function string.is_port(str)
	local value = tonumber(str)
	return value and value > 0 and value <= 65535
end

-------------------------------------------------------------------------------
-- table
-------------------------------------------------------------------------------

function table.clone(src)
	local dst = {}
	for k, v in pairs(src) do 
		rawset(dst, k, v)
	end
	local mt = getmetatable(src)
	if mt then
		setmetatable(dst, mt)
	end
	return dst
end

function table.merge(...)
	local argv = {...}
	local argc = #argv
	local ret = {}
	for i = 1, argc do 
		local arg = argv[i]
		for k, v in pairs(arg) do 
			rawset(ret, k, v)
		end
	end
	return ret
end

function table.find(t, val)
	local len = #t
	for i = 1, len do 
		if rawget(t, i) == val then
			return i
		end
	end
	return -1
end

-------------------------------------------------------------------------------
-- fs
-------------------------------------------------------------------------------
local stat = stat
local fs = fs
function fs.isreg(path)
	local mode = fs.ustat(path, fs.ST_MODE)
	return mode and stat.isreg(mode)
end
function fs.isdir(path)
	local mode = fs.ustat(path, fs.ST_MODE)
	return mode and stat.isdir(mode)
end
function fs.isblk(path)
	local mode = fs.ustat(path, fs.ST_MODE)
	return mode and stat.isblk(mode)
end
function fs.ischr(path)
	local mode = fs.ustat(path, fs.ST_MODE)
	return mode and stat.ischr(mode)
end
function fs.isfifo(path)
	local mode = fs.ustat(path, fs.ST_MODE)
	return mode and stat.isfifo(mode)
end
function fs.issock(path)
	local mode = fs.ustat(path, fs.ST_MODE)
	return mode and stat.issock(mode)
end
function fs.islnk(path)
	local mode = fs.ustat(path, fs.ST_MODE)
	return mode and stat.islnk(mode)
end
function fs.exists(path)
	return fs.ustat(path, fs.ST_MODE) and true
end

-------------------------------------------------------------------------------
-- buffer
-------------------------------------------------------------------------------
local str_format, str_rep = string.format, string.rep
local buf_putstr = buffer.putstr

function buffer.loadfile(self, filepath)
	local fd, err = os.open(filepath, os.O_RDONLY)
	if fd >= 0 then
		os.readb(fd, self)
		os.close(fd)
	end
	return err
end

local function buf_dump(self, x, level, prefix, indent, trace)
	local xtype = type(x)
	
	if prefix then
		buf_putstr(self, prefix)
	end
	if xtype == 'nil' then
		buf_putstr(self, "nil")
	elseif xtype == "table" then
		trace = trace or {}
		
		if trace[x] then
			buf_putstr(self, 'expanded* ', tostring(x))
		else
			local tabspace = indent > 0 and str_rep('  ', indent) or '' 
			trace[x] = true
			buf_putstr(self, tostring(x))
			
			if level > 0 then
				local nextval = next(x)
				if not nextval then
					buf_putstr(self, ' {}')
				elseif type(nextval) == 'number' then
					buf_putstr(self, ' {')
					for k, v in ipairs(x) do
						buf_dump(self, v, 0, nil, indent + 1, trace)  -- arrays don't expand
						if next(x, k) then
							buf_putstr(self, ', ')
						end
					end
					buf_putstr(self, ' }')
				else
					buf_putstr(self, ' {\n')
					for k, v in pairs(x) do
						buf_putstr(self, tabspace, '  ', tostring(k), ' = ')
						buf_dump(self, v, level - 1, nil, indent + 1, trace)
						if next(x, k) then
							buf_putstr(self, ', ')
						end
						buf_putstr(self, '\n')
					end
					buf_putstr(self, tabspace, '}')
				end
			end
		end
	elseif xtype == 'string' then
		buf_putstr(self, '"', tostring(x), '"')
	else
		buf_putstr(self, tostring(x))
	end
	return self	
end

buffer.dump = function (self, data, level)
	buf_dump(self, data, level or 100, nil, 0) 
end

function dump(data, level)
	buf_dump(tmpbuf:rewind(), data, level or 100, nil, 0)
	buf_putstr(tmpbuf, '\n')
	os.writeb(1, tmpbuf)
end

function socket.tcpserver(ip, port, backlog)
	ip = ip or '0.0.0.0'
	
	local family = ip:find(':') and socket.AF_INET6 or socket.AF_INET
	local fd, err = socket.socket(family, socket.SOCK_STREAM)
	if fd < 0 then
		return -1, err
	end
	
	socket.setsocketopt(fd, socket.SO_REUSEADDR, true)
	err = socket.bind(fd, ip, port)
	if err ~= 0 then
		return -1, err
	end
	
	socket.listen(fd, backlog)
	return fd, 0
end

function socket.unserver(path)
	local fd, err = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
	if fd < 0 then
		return -1, err
	end
	
	fs.unlink(path)
	err = socket.bind(fd, path)
	if err ~= 0 then
		os.close(fd)
		return -1, err
	end
	
	socket.listen(fd)
	return fd
end

function socket.async_connect(addr, port, family, localip)
	family = family or socket.AF_INET
	local fd, err = socket.socket(family, socket.SOCK_STREAM)
	if fd < 0 then
		return -1, err
	end
	
	if localip then
		err = socket.bind(fd, localip, 0)
		if err ~= 0 then
			os.close(fd)
			return -1, err
		end
	end
	
	os.setnonblock(fd)
	err = socket.connect(fd, addr, port)
	if err ~= 0 and err ~= errno.EINPROGRESS then
		os.close(fd)
		fd = -1
	end
	return fd, err
end

-------------------------------------------------------------------------------
-- global
-------------------------------------------------------------------------------
local COLON = string.byte(':')
local MINUS = string.byte('-')
local EQUAL = string.byte('=')

function getopt(args, short, long)
	local rd
	local short_opts = {}
	local long_opts = {}
	local opts = {}
	local prev_opt
	
	for _, ch in ipairs({string.byte(short or '', 1, short and #short)}) do
		if ch ~= COLON then
			prev_opt = string.char(ch)
			short_opts[prev_opt] = false
		elseif prev_opt then
			short_opts[prev_opt] = true
		end
	end
	
	for _, opt in ipairs(long or {}) do
		local name = opt:match('^(.+)%=$')
		local with_value = true
		if not name then
			name = opt
			with_value = false
		end
		long_opts[name] = with_value
	end

	local follow = false
	
	local function eat_shortarg(arg)
		rd = arg:reader(rd)
		local name = string.char(rd:getc())
		local with_value = short_opts[name]
		if with_value == nil then
			return
		elseif with_value then
			if #rd > 0 then
				opts[name] = rd:str()
			else
				opts[name] = true
				follow = true
			end
		else
			opts[name] = true
		end
		return name
	end
	
	local function eat_longarg(arg)
		local name, value = arg:match('^([^%=]+)=([^%=]*)$')
		if not name then
			name = arg
			value = nil
		end
		local with_value = long_opts[name]
		if with_value == nil then
			return
		elseif with_value then
			if value then
				opts[name] = value
			else
				opts[name] = true
				follow = true
			end
		else
			opts[name] = true
		end
		return name
	end
	
	for _, arg in ipairs(args) do
		rd = arg:reader(rd)
		local ch = rd:getc()
		if follow then
			if ch == MINUS then
				break
			end
			if prev_opt then
				opts[prev_opt] = arg
				prev_opt = false
			end
			follow = false
		else
			if ch ~= MINUS or #rd == 0 then
				break
			end
			prev_opt = rd:getc() == MINUS and eat_longarg(rd:str()) or eat_shortarg(arg:sub(2))
		end
	end
	return opts
end

function daemonize(openmax)
	local pid = os.fork()
	if pid < 0 then return false end
	if pid > 0 then
		os.exit(0)
	end
	
	os.setsid()
	pid = os.fork()
	if pid > 0 then
		os.exit(0)
	end
	
	os.closerange(0, openmax or 64)
	fs.umask(0)
	fs.chdir('/')
	
	if os.open('/dev/null', os.O_RDONLY) < 0 then return false end
	os.dup(0)
	os.dup(0)
	return true
end

function file_get_content(filepath)
	local fd, err = os.open(filepath, os.O_RDONLY)
	local data
	if fd >= 0 then
		data, err = os.read(fd)
		os.close(fd)
	end
	return data, err
end

function file_put_content(filepath, data)
	local fd, err = os.creat(filepath, 420)
	if fd >= 0 then
		_, err = os.write(fd, data)
		os.close(fd)
	end
	return err
end

_G.tmpbuf = tmpbuf
_G.dummy = function () end
_G.NULL = setmetatable({}, {__newindex = function () error("can't modify NULL, it's constant") end})

