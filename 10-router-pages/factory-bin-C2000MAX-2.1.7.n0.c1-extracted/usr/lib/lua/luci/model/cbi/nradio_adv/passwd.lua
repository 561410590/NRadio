-- Copyright 2017-2018 NRadio
-- Licensed to the public under the Apache License 2.0.

local fs = require "nixio.fs"
local nr = require "luci.nradio"

m = Map("luci", translate("Account"),
	translate("Changes the administrator password for accessing the device"))

s = m:section(TypedSection, "_dummy", "")
s.addremove = false
s.anonymous = true

pwd1 = s:option(Value, "pwd1", translate("Password"))
pwd1.password = true
pwd1.datatype ="pwdcheck"
pwd1.placeholder = translate("Password length 5-64 characters")
pwd1.rmempty = false

pwd2 = s:option(Value, "pwd2", translate("Confirmation"))
pwd2.password = true
pwd2.datatype ="pwdcheck"
pwd2.rmempty = false

local function sync_pass()
	local capi = require "cloudd.api"
	if capi.cloudd_sync_action then
		capi.cloudd_sync_action(capi.cloudd_send_pass)
	end
end

function s.cfgsections()
	return { "_pass" }
end

function m.parse(map)
	local v1 = pwd1:formvalue("_pass")
	local v2 = pwd2:formvalue("_pass")

	if v1 and v2 and #v1 > 0 and #v2 > 0 then
		if v1 == v2 then
			if nr.password_init(luci.dispatcher.context.authuser, v1, "") then
				sync_pass()
			else
				m.message = translate("Unknown Error, password not changed!")
			end
		else
			m.message = translate("PasswordEqualHelp")
		end
	end

	Map.parse(map)
end

return m
