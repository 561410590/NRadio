local io = io
local type = type
local string = string
local os = os

local http = require "socket.http"
local https = require "ssl.https"
local ltn12 = require "ltn12"
local util = require "luci.util"

module ("cloudd.httpfile")

local function unused()
    -- for avoiding unused warning...
end

local function is_ssl(url)
	if string.sub(url, 1, 5) == "https" then
		return true
	else
		return false
	end
end

local function download(param, sink)
	if type(param) == "string" then
		param = {
			url = param
		}
	end
	param['sink'] = sink

	if is_ssl(param['url']) then
		param['verify'] = param['verify'] or 'peer'
		param['capath'] = param['capath'] or '/etc/crts'
		return https.request(param)
	else
		return http.request(param)
	end
end

function download_file(param, file)
	local sink = ltn12.sink.file(io.open(file, 'w'))
	local r, c = download(param, sink)
	if r ~= 1 then
		sink = ltn12.sink.file(io.open(file, 'w'))
		if type(param) == "string" then
			param = { url = param }
		end
		local headers = param['headers']
		if headers == nil then
			headers = { ['connection'] = "Keep-Alive" }
		else
			headers['connection'] = "Keep-Alive"
		end
		param['headers'] = headers
		r, c = download(param, sink)
        unused(r)
	end
	return c
end

function download_file2(param, file)
	os.execute("curl -kg "..param.." -o "..file)
	return 200
end
