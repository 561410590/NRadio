
--
-- Copyright (C) spyder
--


require 'std'
local urlparse = require 'urlparse'
local tasklet = require 'tasklet'

local os, string, table = os, string, table
local tostring, tonumber, type = tostring, tonumber, type
local pairs, setmetatable = pairs, setmetatable

local co_resume, co_yield = coroutine.resume, coroutine.yield

local http = {}
local types = {
	["txt"] = 	"text/plain",
	["log"] = 	"text/plain",
	["js"] = 	"text/javascript",
	["css"] = 	"text/css",
	["htm"] = 	"text/html",
	["html"] = 	"text/html",
	["diff"] = 	"text/x-patch",
	["patch"] = "text/x-patch",
	["c"] = 	"text/x-csrc",
	["h"] = 	"text/x-chdr",
	["o"] = 	"text/x-object",
	["ko"] = 	"text/x-object",

	["bmp"] =     "image/bmp",
	["gif"] =     "image/gif",
	["png"] =     "image/png",
	["jpg"] =     "image/jpeg",
	["jpeg"] =    "image/jpeg",
	["svg"] =     "image/svg+xml",

	["zip"] =     "application/zip",
	["pdf"] =     "application/pdf",
	["xml"] =     "application/xml",
	["xsl"] =     "application/xml",
	["doc"] =     "application/msword",
	["ppt"] =     "application/vnd.ms-powerpoint",
	["xls"] =     "application/vnd.ms-excel",
	["odt"] =     "application/vnd.oasis.opendocument.text",
	["odp"] =     "application/vnd.oasis.opendocument.presentation",
	["pl"] =      "application/x-perl",
	["sh"] =      "application/x-shellscript",
	["php"] =     "application/x-php",
	["deb"] =     "application/x-deb",
	["iso"] =     "application/x-cd-image",
	["tar.gz"] =  "application/x-compressed-tar",
	["tgz"] =     "application/x-compressed-tar",
	["gz"] =      "application/x-gzip",
	["tar.bz2"] = "application/x-bzip-compressed-tar",
	["tbz"] =     "application/x-bzip-compressed-tar",
	["bz2"] =     "application/x-bzip",
	["tar"] =     "application/x-tar",
	["rar"] =     "application/x-rar-compressed",

	["mp3"] =     "audio/mpeg",
	["ogg"] =     "audio/x-vorbis+ogg",
	["wav"] =     "audio/x-wav",

	["mpg"] =     "video/mpeg",
	["mpeg"] =    "video/mpeg",
	["avi"] =     "video/x-msvideo",

	["README"] =  "text/plain",
	["log"] =     "text/plain",
	["cfg"] =     "text/plain",
	["conf"] =    "text/plain",

	["pac"] =		"application/x-ns-proxy-autoconfig",
	["wpad.dat"] =	"application/x-ns-proxy-autoconfig",
}

function http.get_content_type(path)
	local suffix = path:match('([^%.]+)$')
	local content_type
	if suffix then
		content_type = types[suffix]
		if content_type then
			suffix = path:match('([^%/\\%.]+%.[^%.]+)$')
			if suffix and types[suffix] then
				content_type = types[suffix]
			end
		end
	end
	return content_type or 'application/octet-stream'
end

-------------------------------------------------------------------------------
-- multipart/formdata
-------------------------------------------------------------------------------

local FILE_FIELD_PREFIX = '$FILE$_'
local FILE_FIELD_PREFIX_RE = '^%$FILE%$_'
local FILE_FIELD_MATCH_RE = FILE_FIELD_PREFIX_RE .. '(.+)'

http.FILE_FIELD_PREFIX = FILE_FIELD_PREFIX

--[[
	--boundary \r\n
	Content-Disposition: ... \r\n
	Content-Type: ... \r\n
	Content-Transfer-Encoding: ... \r\n \r\n
	... file content ... \r\n
	--boundary \r\n
	Content-Disposition: ... \r\n
	Content-Type: ... \r\n
	Content-Transfer-Encoding: ... \r\n \r\n
	... file content ... \r\n
]]
local function multipart_encode_filelist(files, boundary, buf)
	local err
	local filename
	
	for _, path in ipairs(files) do 
		buf:putstr(boundary, '\r\n')
		
		filename = fs.basename(path)
		buf:putstr('Content-Disposition: attachment; filename="', filename, '"\r\n',
			'Content-Type: ', http.get_content_type(filename), '\r\n',
			'Content-Transfer-Encoding: binary', '\r\n\r\n')
		
		err = buf:loadfile(path)
		if err ~= 0 then
			return err
		end
		buf:putstr('\r\n')
	end
	return 0
end

local function multipart_encode(params, boundary, buf)
	local err

	for field, value in pairs(params) do 
		buf:putstr(boundary, '\r\n')
		
		local name = field:match(FILE_FIELD_MATCH_RE)
		if name then
			if type(value) == 'table' then  -- file list
				local sub_boundary = math.randstr(32)
				buf:putstr('Content-Disposition: form-data; name="', name, '"\r\n')
				buf:putstr('Content-Type: multipart/mixed, boundary=', sub_boundary, '\r\n\r\n')
				err = multipart_encode_filelist(value, '--' .. sub_boundary, buf)
				if err ~= 0 then
					return err
				end
				buf:putstr('--', sub_boundary, '--\r\n')
			else
				local path = value
				local filename = fs.basename(path)
				buf:putstr('Content-Disposition: form-data; name="', name, '"; filename="', filename, '"\r\n')
				buf:putstr('Content-Type: ', http.get_content_type(filename), '\r\n')
				buf:putstr('Content-Tranfer-Encoding: binary\r\n\r\n')
				err = buf:loadfile(path)
				if err ~= 0 then
					return err
				end
				buf:putstr('\r\n')
			end
		else
			buf:putstr('Content-Disposition: form-data; name="', field, '"\r\n\r\n')
			buf:putstr(value, '\r\n')
		end
	end
	buf:putstr(boundary, '--\r\n')
	return 0 
end


-- If the User-Agent close the connection normally (but in advance) before sending or halfway sending
-- a request, we return EPIPE to mark the error.
-- FIXME: EPIPE may not be accurate, but usually we only care about whether error occurs.
local EPIPE = errno.EPIPE

-------------------------------------------------------------------------------
-- request
-------------------------------------------------------------------------------

local function read_headers(obj, use_headers, ch, sec)
	local line, err
	local count = 0
	local cd_read = ch:make_countdown_read(sec)
	
	while true do 
		if count > 30 then  -- suspicious request, reject it 
			return -1
		end
		
		line, err = cd_read()
		if not line then
			return err ~= 0 and err or EPIPE
		end
		
		if #line > 0 then
			local name, value = line:match("^([A-Za-z][A-Za-z0-9%-_]+): *(.+)$")
			if not name or not value then
				return -1
			end
			obj.headers[string.lower(name)] = value
			count = count + 1
		else
			return use_headers(obj) and 0 or -1
		end
	end
	return 0
end

local request = {}
local req_meta = {
	__index = request,
}
http.request = request

local FORMDATA_ENCODED = 1
local URL_ENCODED = 2


function request.new()
	return setmetatable({
		method = false,
		urlpath = false,
		http_ver = false,
		headers = {},
		params = {},		
		urlinfo = false,
		content = false,
		
		host = false,		
		content_length = 0, 
		chunked = false,   
		boundary = false,  
		chunk_len = 0,		
		content_type = 0,
		expect_content = false,
		conn_close = false,
	}, req_meta)
end

function request:reset()
	self.host = false
	self.state = START_LINE
	self.chunk_len = 0
	self.content_length = 0
	self.chunked = false
	self.boundary = false
	self.content_type = 0
	if self.content then
		self.content:reset()
	end
	self.params = {}
	self.headers = {}
end

local function request_read_startline(req, ch, sec)
	local line, err = ch:read(nil, sec)
	if not line then
		return err ~= 0 and err or EPIPE
	end
				
	local method, urlpath, ver = line:match("^([A-Z]+) ([^ ]+) HTTP/([01]%.[019])$")
	if not method or not urlpath or not ver then
		return -1
	end
	
	local urlinfo = urlparse.split(urlpath)
	if not urlinfo then
		return -1
	end
	
	urlpath = urlinfo.path
	req.method = method
	req.urlinfo = urlinfo
	if urlinfo.query then
		urlparse.split_query(urlinfo.query, req.params)
		urlpath = urlpath .. '?' .. urlinfo.query
	end

	req.http_ver = ver
	req.urlpath = urlpath
	
	return 0
end

local function request_use_headers(req)
	local headers = req.headers
	req.host = headers['host'] or req.urlinfo.host or ''
	req.content_length = tonumber(headers['content-length']) or 0
	req.chunked = string.lower(headers['transfer-encoding'] or "") == 'chunked'
	req.conn_close = string.lower(headers['connection'] or "") == 'close'
	req.expect_content = string.lower(headers['expect'] or "") == '100-continue'
	
	if req.method == 'POST' then
		local content_type = headers['content-type']
		if content_type then
			local boundary = content_type:match('^multipart/form%-data; bound1ary=(.+)')
			if boundary then
				req.boundary = '--' .. boundary
				req.content_type = FORMDATA_ENCODED
			elseif content_type:match('^application/x%-www%-form%-urlencoded') then
				req.content_type = URL_ENCODED
			end
		end
	end
	return #req.host > 0
end

local function request_read_headers(req, ch, sec)
	return read_headers(req, request_use_headers, ch, sec)
end
	
function request:read_header(ch, sec)
	local tm_anchor, tm_total, tm_elapsed = tasklet.now, sec or 30, 0
	
	for _, func in ipairs({
		request_read_startline, 
		request_read_headers,
	}) do 
		if tm_total > 0 then
			tm_elapsed = tasklet.now - tm_anchor
			if tm_elapsed >= tm_total then
				return errno.ETIMEDOUT
			end
			sec = tm_total - tm_elapsed
		end
		err = func(self, ch, sec)
		if err ~= 0 then
			return err
		end
	end
	return 0
end

local dfl_headers = {
	['Connection'] = 'Keep-Alive',
	['Cache-Control'] = 'no-cache',
	['Pragma'] = 'no-cache',
	['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
	['Accept-Encoding'] = 'identity,gzip',
	['Accept-Language'] = 'zh-CN,zh;q=0.8,en;q=0.6,ja;q=0.4',
	['User-Agent'] = 'lua-httpclient',
}

function request:serialize(data, buf)
	local method = self.method or 'GET'
	local headers = self.headers or {}
	local err
	
	buf:putstr(method, ' ', self.urlpath, ' HTTP/1.1\r\n')
	for k, v in pairs(headers) do 
		buf:putstr(k, ':', v, '\r\n')
	end
	for k, v in pairs(dfl_headers) do 
		if not headers[k] then
			buf:putstr(k, ':', v, '\r\n')
		end
	end
	if not headers['Host'] and self.host then
		buf:putstr('Host:', self.host, '\r\n')
	end
	
	if method == 'POST' and data then
		local boundary = false
		local tdata = type(data)
		
		if tdata == 'table' then
			for k, v in pairs(data) do
				if k:match('^%$FILE%$') then
					boundary = math.randstr(32)
					break
				end
			end
		end
		
		if boundary then
			buf:putstr('Content-Type: multipart/form-data; boundary=', boundary, '\r\n')
		else
			if not headers['Content-Type'] then
				buf:putstr('Content-Type: ', (tdata == 'userdata') and 'application/octet-stream'  or 'application/x-www-form-urlencoded', '\r\n')
			end
		end
		
		buf:putstr('Content-Length:')
		local wr = buf:writer(14)
		local len = #buf
		
		if boundary then
			local err = multipart_encode(data, '--' .. boundary, buf)
			if err ~= 0 then
				return err
			end
		else
			if tdata == 'table' then
				buf:putstr(urlparse.build_query(data))
			else
				buf:putreader(data) -- opaque binary data
			end
		end
		
		wr:putstr(string.format('%-10d\r\n\r\n', #buf - len))
	else
		buf:putstr('\r\n')
	end
	return 0
end

function request:write(ch, data, sec)
	local buf = self.content
	if not buf then
		buf = buffer.new()
		self.content = buf
	else
		buf:rewind()
	end

	local err = self:serialize(data, buf)
	if err ~= 0 then
		return err
	end
	return ch:write(buf, sec)
end

-------------------------------------------------------------------------------
-- response
-------------------------------------------------------------------------------

local response = {}
local resp_meta = {
	__index = response
}
http.response = response

function response.new()
	return setmetatable({
		http_ver = false,
		status = false,
		reason = false,
		headers = {},
		content = false,
		
		content_length = 0,
		chunked = false,
		content_encoding = false,
		close = false,
	}, resp_meta)
end

local function response_rewind(resp)
	resp.http_ver = false
	resp.reason = false
	resp.headers = {}
	if resp.content then
		resp.content:reset()
	end
	resp.chunked = false
	resp.conn_close = false
	resp.content_length = 0
end

local function response_read_startline(resp, ch, sec)
	local line, err = ch:read(nil, sec)
	if not line then
		return err ~= 0 and err or EPIPE
	end
	
	local http_ver, status, reason = line:match("^HTTP/([%d%.]+)%s+(%d+)%s+(.*)$")
	if http_ver and tonumber(status) and reason then
		resp.http_ver = http_ver
		resp.status = tonumber(status)
		resp.reason = reason
		return 0
	else
		return -1
	end
end

local function response_use_headers(resp)
	local headers = resp.headers
	resp.content_length = tonumber(headers['content-length']) or 0
	resp.content_encoding = string.lower(headers['content-encoding'] or 'identity')
	resp.chunked = string.lower(headers['transfer-encoding'] or "") == 'chunked'
	resp.conn_close = string.lower(headers['connection'] or "") == 'close'
	return resp.content_encoding == "identity" or resp.content_encoding == 'gzip'
end

local function response_read_headers(resp, ch, sec)
	return read_headers(resp, response_use_headers, ch, sec)
end

local function response_read_content(resp, ch, sec)
	local status = tonumber(resp.status)
	
	-- not allowed to have content
	if status < 200 or status == 204 or status == 304 then
		return 0
	end
	
	-- no content
	local chunked = resp.chunked
	local content_length = resp.content_length
	if not chunked and content_length == 0 then
		return 0
	end
	
	local buf = resp.content
	if not buf then
		buf = buffer.new()
		resp.content = buf
	end

	local cd_read = ch:make_countdown_read(sec)
	if chunked then
		local chunksiz 
		while true do
			local ret, err = cd_read(chunksiz)
			if not ret then
				return err
			end
			
			if chunksiz then
				buf:putreader(ret)
				chunksiz = chunksiz - #ret
				if chunksiz == 0 then
					cd_read() -- skip the ending '\r\n'
					chunksiz = nil  -- next time we read a line
				end
			elseif #ret > 0 then
				chunksiz = tonumber("0x" .. ret)
				if not chunksiz then
					return -1
				elseif chunksiz == 0 then
					cd_read()
					break
				end
			end
		end
	elseif content_length > 0 then
		local left = content_length
		while left > 0 do 
			local rd, err = cd_read(left)
			if err ~= 0 then
				return err
			end
			buf:putreader(rd)
			left = left - #rd
		end
	end
	return 0
end

function response:read(ch, sec)
	response_rewind(self)

	local tm_total, tm_anchor, tm_elapsed = sec, tasklet.now, 0
	local err = 0

	for _, func in ipairs({
		response_read_startline, 
		response_read_headers,
		response_read_content,
	}) do 
		if tm_total > 0 then
			tm_elapsed = tasklet.now - tm_anchor
			if tm_elapsed >= tm_total then
				return errno.ETIMEDOUT
			end
			sec = tm_total - tm_elapsed
		end
		err = func(self, ch, sec)
		if err ~= 0 then
			return err
		end
	end
	
	if self.content_encoding == 'gzip' and #self.content > 0 then
		err = require('zlib').uncompress(self.content)
	end
	return err 
end

-------------------------------------------------------------------------------
-- http
-------------------------------------------------------------------------------

http.reasons = {
	[200] = "OK",
	[206] = "Partial Content",
	[301] = "Moved Permanently",
	[302] = "Found",
	[304] = "Not Modified",
	[400] = "Bad Request",
	[403] = "Forbidden",
	[404] = "Not Found",
	[405] = "Method Not Allowed",
	[408] = "Request Time-out",
	[411] = "Length Required",
	[412] = "Precondition Failed",
	[416] = "Requested range not satisfiable",
	[500] = "Internal Server Error",
	[503] = "Server Unavailable",
}

return http
