
local tasklet = require 'tasklet.channel.streamserver'
local log = require 'mylog'
local urlparse = require 'urlparse'
local http = require 'http'
local cjson = require 'cjson2'
local zlib = require 'zlib'

local type, tostring, tonumber = type, tostring, tonumber
local strfmt = string.format
local current_task = tasklet.current_task
local reasons = http.reasons

local http_close
local current

local HTTP_CLOSE_MAGIC = '@@http_close'
local HTTP_CLOSE_PATTERN = '@@http_close$'
local VERSION_STRING = '1.0.0'

local M = http

local const_headers = {
	['Server'] = 'lask-httpd/' .. VERSION_STRING,
	['Content-Type'] = 'text/html',
	['Content-Encoding'] = 'identity',
	['Connection'] = 'keep-alive',
}

local function send_headers(conn, noclose)
	if conn.sent_headers then
		http_close(conn, -1)
	end

	local status, headers, body = conn.status, conn.headers, conn.body
	local buf = conn.buf
	buf:putstr('HTTP/1.1 ', tostring(status), ' ', reasons[status], '\r\n')

	if not headers['Content-Length'] then
		-- if body is valid, use #body as Content-Length, otherwise choose chunked
		if body then
			headers['Content-Length'] = #body
		else
			headers['Transfer-Encoding'] = 'chunked'
		end
	end
	if conn.zstream and not body then
		headers['Content-Encoding'] = 'gzip'
	end

	for k, v in pairs(headers) do
		if v then
			buf:putstr(k, ": ", v, "\r\n")
		end
	end
	for k, v in pairs(const_headers) do
		if not headers[k] then
			buf:putstr(k, ": ", v, "\r\n")
		end
	end
	buf:putstr("\r\n")
	conn.sent_headers = true
	local err = conn.ch:write(buf)
	buf:rewind()
	if err ~= 0 and not noclose then
		http_close(conn, err)
	end
	return err
end

-- get/set header in response
function M.header(k, v)
	local conn = current_task()
	if v then
		conn.headers[k] = v
	else
		return conn.req.headers[k]
	end
end

function M.set_content_type(v)
	current_task().headers['Content-Type'] = v
end

local function send_body(conn, noclose)
	local body = conn.body
	if not body or body == -1 then
		return 0
	end
	conn.body = -1

	if type(body) == 'string' then
		rd = conn.buf:reader()
		body = body:reader(rd)
	end

	local err = conn.ch:write(body)
	if err ~= 0 and not noclose then
		http_close(conn, err)
	end
	return err
end

local function http_error(conn, status, msg)
	conn.status = status
	conn.headers['Connection'] = 'close'

	if msg then
		conn.body = msg
		conn.headers['Connection-Type'] = msg:find('%<html%>') and 'text/html' or 'text/plain'
	else
		conn.body = false
		conn.headers['Conntent-Length'] = 0
	end

	conn.quit = true
	send_headers(conn)
	send_body(conn)
end

function M.error(status, msg)
	http_error(current_task(), status, msg)
end

local function send_file_content(conn, fd, fsize, zstream)
	local rawbuf = zstream and tmpbuf or conn.buf
	local buf = conn.buf
	local ch = conn.ch
	local last_block
	local nread, err

	while fsize > 0 do
		last_block = fsize <= 4096
		nread = last_block and fsize or 4096

		_, err = os.readb(fd, rawbuf:rewind(), nread)
		if err ~= 0 then
			break
		end
		fsize = fsize - nread

		if zstream then
			buf:rewind():putstr('0000\r\n')
			zlib.deflate(zstream, rawbuf, buf, last_block and 0 or 1)
			buf:putstr('\r\n')
			buf:overwrite(0, strfmt('%04x', #buf - 8))
			if last_block then
				buf:putstr('0\r\n\r\n')
			end
		end

		err = ch:write(buf)
		if err ~= 0 then
			http_close(conn, err)
		end
	end
end

local function reply_file(conn, fd, fsize, mtime, mime_type)
	local headers = conn.headers
	local zstream = fd >= 0 and mime_type:find('^text')

	headers['Content-Type'] = mime_type
	headers['Date'] = time.strftime("%a, %d %b %Y %H:%M:%S GMT", time.time())
	headers['Last-Modified'] = time.strftime("%a, %d %b %Y %H:%M:%S GMT", mtime)

	if zstream then
		zstream = zlib.deflate_init()
		conn.zstream = zstream
	end
	if not zstream then
		headers['Content-Length'] = fsize
	end

	send_headers(conn)
	if fd >= 0 then
		send_file_content(conn, fd, fsize, zstream)
		zlib.deflate_end(zstream)
		conn.zstream = false
		conn.body = -1
	end
end

local function serve_static(conn, doc_root, doc_path, follow_link, if_modified_since)
	local filepath = doc_path and fs.realpath(doc_root .. doc_path)
	local status = 200
	local filest

	if not filepath then
		status = 404
	elseif filepath:sub(1, #doc_root) ~= doc_root then
		status = 403
	else
		filest = fs.stat(filepath)
		if not filest then
			status = 404
		else
			local fmode = filest.mode
			if stat.islnk(fmode) then
				if not follow_link then
					status = 403
				else
					filepath = os.readlink(filepath)
					filest = filepath and fs.stat(filepath)
					if not filest then
						status = 404
					else
						fmode = filest.mode
					end
				end
			end

			if status == 200 and fmode & stat.S_IRUSR == 0 then
				status = 403
			end
		end
	end

	if status == 200 and if_modified_since then
		local tstamp = time.strptime(if_modified_since, '%a, %d %b %Y %H:%M:%S %Z')
		if not tstamp then
			http_error(conn, 400, 'malformed value for If-Modified-Since header: ' .. if_modified_since)
			return
		end
		if tstamp >= filest.mtime then
			status = 304
		end
	end

	if status == 200 or status == 304 then
		local fd = -1
		if status == 200 then
			local err
			fd, err = os.open(filepath, os.O_RDONLY)
			if fd < 0 then
				http_error(conn, 500, 'failed to open file:' .. errno.strerror(err))
				return
			end
			conn.fd = fd
		end

		conn.status = status
		reply_file(conn, fd, filest.size, filest.mtime, http.get_content_type(filepath))
		if fd >= 0 then
			os.close(fd)
			conn.fd = -1
		end
	else
		http_error(conn, status)
	end
end

function M.serve_static(doc_root, doc_path, follow_link)
	local conn = current_task()
	local req = conn.req
	doc_path = doc_path or req.urlinfo.path
	serve_static(conn, doc_root or conn.settings.doc_root, doc_path, follow_link, req.headers['if-modified-since'])
end

function M.redirect(url, params)
	local conn = current_task()
	conn.status = 302
	if params then
		local buf = tmpbuf:rewind():putstr(url)
		local tparams = type(params)
		if tparams == 'table' then
			for k, v in pairs(params) do
				buf:putstr(urlparse.encode(k), '=', urlparse.encode(v), '&')
			end
		elseif tparams == 'string' then
			buf:putstr(params)
		end
		url = buf:str()
	end
	conn.headers['Location'] = url
	conn.headers['Content-Length'] = 0
	conn.quit = true
	send_headers(conn)
end

local function http_write(conn, ...)
	local buf = conn.buf
	buf:putstr(...)
	if #buf > 8000 then
		local zstream = conn.zstream
		if zstream then
			local zbuf = tmpbuf
			zlib.deflate(zstream, buf, zbuf:rewind())
			buf:rewind():putstr(strfmt('%x\r\n', #zbuf)):putreader(zbuf:reader()):putstr('\r\n')
		else
			buf:putstr('\r\n')
			buf:overwrite(0, strfmt('%04x', #buf - 8))
		end
		local err = conn.ch:write(buf)
		buf:rewind()
		if not zstream then
			buf:putstr('0000\r\n')
		end
		if err ~= 0 then
			http_close(conn, err)
		end
	end
end

function M.write(...)
	local conn = current_task()
	if not conn.sent_headers then
		local content_type = conn.headers['Content-Type']
		if not content_type then
			content_type = 'text/html'
			conn.headers['Content-Type'] = content_type
		end
		if content_type:find('^text') then
			conn.zstream = zlib.deflate_init()
		end
		send_headers(conn)
		if not conn.zstream then
			conn.buf:rewind():putstr('0000\r\n')
		end
	end
	http_write(current_task(), ...)
end

M.echo = M.write
function M.echo_json(val)
	local conn = current_task()
	if conn.sent_headers then
		http_close(conn, -1)
	end

	local buf = conn.buf
	conn.headers['Content-Type'] = 'application/json'
	conn.body = cjson.encode(val)
	send_headers(conn)
	send_body(conn)
	http_close(conn, 0)
end

local function flush(conn)
	local status = conn.status
	if status < 200 or (status >= 300 and status < 400) then
		return 0
	end

	local zstream, buf = conn.zstream, conn.buf
	if zstream then
		local zbuf = tmpbuf:rewind()
		zlib.deflate(zstream, conn.buf, zbuf, 0)
		buf:rewind():putstr(strfmt('%x\r\n', #zbuf)):putreader(zbuf:reader()):putstr('\r\n')
		zlib.deflate_end(zstream)
		conn.zstream = false
	else
		if #buf > 0 then
			buf:putstr('\r\n')
			buf:overwrite(0, strfmt('%04x', #buf - 8))
		end
	end
	buf:putstr('0\r\n\r\n')
	return conn.ch:write(buf)
end

http_close = function (conn, err, nothrow)
	if err == 0 then
		if not conn.sent_headers then
			err = send_headers(conn, true) -- nothrow
		end
		if err == 0 then
			local body = conn.body
			if body then
				if body ~= -1 then
					err = send_body(conn, true)
				end
			else
				err = flush(conn)
			end
		end
	end

	if err == 0 then
		conn.buf:reset()
		conn.sent_headers = false
		local headers = conn.headers
		for k, v in pairs(headers) do
			headers[k] = false
		end
	else
		if conn.fd >= 0 then
			os.close(conn.fd)
			conn.fd = -1
		end
		conn.quit = true
	end
	if conn.zstream then
		zlib.deflate_end(conn.zstream)
		conn.zstream = false
	end
	conn.status = false
	conn.body = false

	if not nothrow then
		conn.err = err
		error(HTTP_CLOSE_MAGIC)
	end
end

function M.close()
	http_close(current_task(), 0)
end
http.die = http.close

local function conn_loop()
	local conn = current_task()
	local req, ch, settings = conn.req, conn.ch, conn.settings
	local handler = settings.handler
	local method, ok, errmsg
	local count = 0

	while not conn.quit and req:read_header(ch) == 0 do
		method = req.method
		log.debug('from ', conn.addr, ':  ', method, ' ', req.urlpath)
		if method == 'post' or method == 'put' then
			-- TODO: read the message body
		end

		conn.status = 200
		if count == 0 then
			conn.buf = buffer.new()
		end
		ok, errmsg = xpcall(function ()
			local path = req.urlinfo.path
			if settings.doc_root then
				local doc_path = settings.doc_pattern and path:match(settings.doc_pattern)
				if doc_path then
					serve_static(conn, settings.doc_root, doc_path, settings.follow_link, req.headers['if-modified-since'])
					return
				end
			end

			-- handler returns something if not handled.
			if not handler or handler(req, settings) ~= nil then
				http_error(conn, 404)
			end
		end,
		function (errmsg)
			return errmsg:match(HTTP_CLOSE_PATTERN) and HTTP_CLOSE_MAGIC or errmsg .. debug.traceback()
		end)

		count = count + 1

		if not ok and errmsg ~= HTTP_CLOSE_MAGIC then
			log.error(errmsg)
			conn.quit = true
		end
		if conn.status then
			http_close(conn, 0, true)
		end
	end

	if ch.ch_state > 0 then
		tasklet.sleep(1)
	end
	ch:close()
	log.debug('connection off with ', conn.addr)
end

--[[
settings = {
	https = true,
	[cafile = ,
	certfile = ,
	keyfile = ,
	key = , ]
	addr = ,
	port = ,
	doc_root = '/public/tom/www/files/',
	doc_pattern = '^/static/(.*)',
	auto_index = false,
	follow_link = true,
}
]]
function M.start_server(settings)
	local function new_connection(fd, addr, port, ssl)
		os.setcloexec(fd)
		log.debug('connection established with ', addr)
		local req = http.request.new()
		local conn = {
			ch = false,
			addr = addr,
			port = port,
			req = req,
			settings = settings,
			status = false, -- 1xx-5xx, also used as a 'closed' flag
			headers = {},  -- response headers
			sent_headers = false, -- whether headers are sent
			buf = false, -- buffer holding the message body
			body = false, --
			rd = false, -- cached reader
			fd = -1,  -- descriptor of the served static file
			zstream = false, -- zlib deflate stream
			err = 0,  -- last error
		}
		if settings.https then
			local ch = tasklet.sslstream_channel.new(fd)
			tasklet.start_task(function ()
				if ch:handshake() == 0 then
					conn.ch = ch
					conn_loop()
				else
					ch:close()
				end
			end, conn)
		else
			conn.ch = tasklet.stream_channel.new(fd)
			tasklet.start_task(conn_loop, conn)
		end
	end

	local doc_root = settings.doc_root
	if doc_root and not doc_root:match('/$') then
		settings.doc_root = doc_root .. '/'
	end

	if settings.https then
		require 'tasklet.channel.sslstream'
		local ctx = ssl.context.new('sslv23')
		if ctx:load_verify_locations(settings.cafile) ~= 0 then
			log.fatal('ssl.context.load_verify_locations failed')
		end
		if ctx:use_certfile(settings.certfile) ~= 0 then
			log.fatal('ssl.context.use_certfile failed')
		end
		if ctx:use_keyfile(settings.keyfile, settings.key) ~= 0 then
			log.fatal('ssl.context.use_keyfile failed')
		end
		tasklet.sslstream_channel.ctx = ctx
	else
		require 'tasklet.channel.stream'
	end

	local server = require('app').start_tcpserver_task(settings.addr, settings.port, new_connection)
	server.settings = settings
	return server
end

return M
