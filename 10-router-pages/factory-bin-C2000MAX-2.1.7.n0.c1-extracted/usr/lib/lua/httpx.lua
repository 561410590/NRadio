
--
-- Copyright (C) spyder
--


require 'std'

local string = string

local urlparse = require 'urlparse'
local tasklet = require 'tasklet'
local http = require 'http'
local cjson = require 'cjson2'

require 'tasklet.util'

-------------------------------------------------------------------------------
--[[
settings = {
	type = 'get(/post)',
	url = 'http(s)://www.mysite.com/a/b/c',
	data = {x=1, y=2, ['$FILE$_myfile']='/tmp/myfile'},
	data_type = 'json',
	timeout = 15,
	async = true,
	success = function (content_or_json_obj) end,
	error = function (resp, status) end,
}
]]	
-------------------------------------------------------------------------------
function http.ajax(settings)
	local method = string.upper(settings.type or 'GET')
	local data = settings.data
	local urlinfo = urlparse.split(settings.url)
	local urlpath = urlinfo.path
	local port = urlinfo.port 
	local scheme = string.lower(urlinfo.scheme or 'http')
	
	if scheme ~= 'http' and scheme ~= 'https' then
		error('the scheme must be http or https')
	end
	if urlinfo.query then
		urlpath = urlpath .. '?' .. urlinfo.query
	end
	if not port then
		port = scheme == 'http'and 80 or 443
	end
	
	local function do_ajax()
		local tm_total = settings.timeout or 15
		local tm_start = tasklet.now
		local step = 1
		local ch
		local ip 
		local resp 
		
		local funcs = {
			function ()
				local iplist = tasklet.getaddrbyname(urlinfo.host, tm_total)
				if not iplist or #iplist == 0 then
					return errno.EHOSTUNREACH
				end
				ip = iplist[1]
			end,
			
			function ()
				if scheme == 'https' then
					require 'tasklet.channel.sslstream'
					local ssl = require 'ssl2'
					local ctx = tasklet.sslstream_channel.ctx
					if not ctx then
						ctx = ssl.context.new('sslv23')
						if not ctx then
							-- XXX: 
							error('failed to create a ssl context')
						end
						tasklet.sslstream_channel.ctx = ctx
					end
					ch = tasklet.sslstream_channel.new()
				else
					ch = tasklet.stream_channel.new()
				end
				return ch:connect(ip, port, tm_total)
			end,
			
			function ()
				local req = http.request.new()
				req.method = method
				req.urlpath = urlpath
				req.headers['Host'] = urlinfo.host
				if settings['content-type'] then
					req.headers['Content-Type'] = settings['content-type']
				end
				return req:write(ch, data, tm_total)
			end,
			
			function ()
				resp = http.response.new()
				return resp:read(ch, tm_total)
			end,
		}
	
		while tm_total > 0 and step <= #funcs do
			if tasklet.now > tm_start then
				tm_total = tm_total - (tasklet.now - tm_start)
			end
			if tm_total <= 0 then
				if settings.error then
					settings.error(nil, errno.ETIMEDOUT)
				end
				if ch then ch:close() end
				return
			end
			tm_start = tasklet.now
			
			local err = funcs[step]() or 0
			if err ~= 0 then
				if settings.error then
					settings.error(nil, err)
				end
				if ch then ch:close() end
				return
			end
		
			step = step + 1
		end
		ch:close()
	
		local status = resp.status
		local data = resp
		if status == 200 then
			data = resp.content
			if settings.data_type == 'json' then
				local ok = false
				if resp.headers['content-type'] == 'application/json' then
					data:putc(0)
					ok, data = pcall(cjson.decodeb, data)
				end
				
				if not ok then	
					status = 500
				end
			end
		end
		
		if status == 200 then
			settings.success(data)
		else
			if settings.error then
				settings.error(resp)
			end
		end
	end
	
	if settings.async == false and tasklet.current_task() then
		do_ajax()
	else
		tasklet.start_task(do_ajax)
	end
end
	
return http

