-- Copyright 2017 NRadio
require 'std'
module("luci.controller.auth", package.seeall)

local util = require "luci.util"
local http = require "luci.http"
local sys  = require "luci.sys"
function index()
	entry({ "auth"}, call("wifidog_auth_servcer"), nil, nil, true).leaf = true
	entry({ "login"}, call("wifidog_auth_login"), nil, nil, true).leaf = true
	entry({ "message"}, call("wifidog_auth_message"), nil, nil, true).leaf = true
	entry({ "portal"}, call("wifidog_auth_portal"), nil, nil, true).leaf = true
end

function wifidog_auth_servcer()
    local ccontent = luci.http.content() or nil
    local localip = iface.getip("br-lan") or "192.168.88.1"
    if ccontent and (#ccontent > 0) then
		local cjson = require("cjson.safe");
		local data = cjson.decode(ccontent);
		if(data and data.id) then
			local response_data={skip=0}
			if data.firststart then
				local curdata = util.ubus("terminal", "list") or {}
				if curdata and curdata.list then
					response_data.clients = curdata.list
				end
				if curdata and curdata.skip then
					response_data.skip = curdata.skip
				end
			elseif not data.clients or #data.clients == 0 then				
				response_data.key = "pong"
		
			else
				response_data.clients={}
				local cur_req_info = {mac="",auth=0}
				
				nixio.syslog("err","req info:"..ccontent)
				for i,req_client in pairs(data.clients) do
					local curdata = util.ubus("terminal", "match",{mac=req_client.mac}) or { code = -1}					
					nixio.syslog("err","trackd return:"..cjson.encode(curdata))
					if curdata and curdata.code == 0 then
						cur_req_info.mac = req_client.mac
						cur_req_info.auth = 1
					end
					break
				end
				response_data.clients[#response_data.clients+1] = cur_req_info
			end
			luci.http.prepare_content("application/json")
			luci.http.write_json(response_data)		
		end
	end
end
function wifidog_auth_login()
end
function wifidog_auth_message()
end
function wifidog_auth_portal()
end