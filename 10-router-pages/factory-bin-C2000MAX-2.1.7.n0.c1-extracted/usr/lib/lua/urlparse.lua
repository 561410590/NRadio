
--
-- Copyright (C) spyder
--


require 'std'

local string, table = string, table
local type, pairs, tostring = type, pairs, tostring

local encode = codec.urlencode
local decode = codec.urldecode
local urlbuf = buffer.new(1024)

local urlparse = {
	encode = encode,
	decode = decode,
	split = codec.urlsplit,
}

function urlparse.build_path(segments, buf)
	local buf_valid = (buf ~= nil)
	if not buf_valid then
		buf = urlbuf
		buf:rewind()
	end
	
	buf:putstr('/')
	local num = 0
	for _, v in ipairs(segments) do
		if num > 0 then
			buf:putstr('/')
		end
		if type(v) == 'string' then
			encode(v, buf)
		else
			encode(v[1], buf)
			buf:putstr(';')
			encode(v[2], buf)
		end
		num = num + 1
	end
	return buf_valid and buf or buf:str()
end

function urlparse.split_path(path, segments)
	segments = segments or {}
	for segment in path:gmatch('([^/]+)') do
		if segment:find(';') then
			local a, b = segment:match('^([^;]*);(.*)$')
			table.insert(segments, {a, b})
		else
			table.insert(segments, decode(segment))
		end
	end
	return segments
end

function urlparse.build_query(params, buf)
	local buf_valid = (buf ~= nil)
	if not buf_valid then
		buf = urlbuf
		buf:rewind()
	end

	local num = 0
	for k, v in pairs(params) do
		print(k, v)
		if num > 0 then
			buf:putstr('&')
		end
		encode(k, buf)
		buf:putstr('=')
		encode(v, buf)
		num = num + 1
	end
	
	return buf_valid and buf or buf:str()
end

function urlparse.split_query(query, params)
	params = params or { }
	for pair in query:gmatch( "[^&;]+" ) do
		local key, value = pair:match("^([^=]+)=(.+)$")
		if key and value then
			params[decode(key)] = decode(value)
		end
	end
	return params
end
	
function urlparse.build(url, buf)
	local buf_valid = buf
	if not buf_valid then
		buf = urlbuf
		buf:rewind()
	end
	
	if url.scheme then
		buf:putstr(url.scheme, '://')
	end
	if url.user then
		buf:putstr(url.user)
		if url.password then
			buf:putstr(':', url.password)
		end
		buf:putstr('@')
	end
	if url.host then
		buf:putstr(encode(url.host))
		if url.port then
			buf:putstr(':', tostring(url.port))
		end
	end
	buf:putstr(url.path or '/')
	if url.query then
		buf:putstr('?', url.query)
	end
	if url.fragment then
		buf:putstr('?', url.fragment)
	end
	
	return buf_valid and buf or buf:str()
end

return urlparse
