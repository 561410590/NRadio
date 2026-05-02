local fs = require "nixio.fs"
local i18n = require "luci.i18n"
local nr = require "luci.nradio"
local util = require "luci.util"
local nixio = require "nixio"
local disp = require "luci.dispatcher"
local luci_channel = disp._CHANNEL

local NR_APN = "app"
local MODEL = arg[1] or nil

local FILENAME = nr.get_apn_filename(MODEL)
if not fs.access("/etc/config/" .. FILENAME) then
	util.exec("touch /etc/config/" .. FILENAME)
end

if luci_channel then
	m = Map(FILENAME)
	m:append(Template("nradio_adv/apn_simple"))
else
	m = Map(FILENAME, translate("APNSettingTemplate"))
end

local exists = m.uci:get_all(FILENAME, NR_APN)
if not exists then
	m.uci:section(FILENAME, "rule", NR_APN, { custom_apn = "0" })
	m.uci:commit(FILENAME)
end

s = m:section(NamedSection, NR_APN, "rule")

custom_apn = s:option(Flag, "custom_apn", translate("Status"))
custom_apn.default = "0"
custom_apn.rmempty = true

auth = s:option(ListValue, "auth", translate("APNAuth"))
auth:value("0", translate("None"))
auth:value("1", translate("PAP"))
auth:value("2", translate("CHAP"))
auth:value("3", translate("PAP or CHAP"))
auth.default = "0"
auth.rmempty = true

apn = s:option(Value, "apn", translate("APN"))
apn.rmempty = true

username = s:option(Value, "username", translate("Username"))
username.rmempty = true

password = s:option(Value, "password", translate("Password"))
password.password = true
password.rmempty = true

pdptype = s:option(ListValue, "pdptype", translate("APNIP"))
pdptype:value("ip", translate("IPv4"))
pdptype:value("ipv6", translate("IPv6"))
pdptype:value("ipv4v6", translate("IPv4&IPv6"))
if fs.access("/usr/lib/lua/luci/controller/nradio_adv/5glan.lua") then
	pdptype:value("ethernet", translate("Ethernet"))
end
pdptype.default = "ipv4v6"
pdptype.rmempty = true

if luci_channel then
	submit = Template("admin_system/submit_simple")
	m:append(submit)
end

function m.on_after_commit(self)
	local modelname = MODEL
	local item = NR_APN
	local targetnames = { "apn_cfg" }

	if nr.support_dualdnn() then
		targetnames[#targetnames + 1] = "apn_cfg2"
	end

	local _, cpe_section = nr.get_cellular_last(MODEL)
	local sim_section = cpe_section:gsub("cpe", "sim")
	local simid = m.uci:get("cpesel", sim_section, "cur") or "1"
	local section_key = (modelname .. "sim" .. simid):gsub("[;'\\\"]", "")

	for _, targetname in ipairs(targetnames) do
		local key = modelname .. "_" .. simid .. "_" .. targetname
		local target_name = nil
		local target_action = nil

		nixio.syslog("err", "key:" .. key .. ",section_key:" .. section_key .. ",targetname:" .. targetname)

		if targetname == "apn_cfg" then
			local apn_cfg = m.uci:get("cpecfg", section_key, "apn_cfg") or ""
			if apn_cfg ~= item then
				if item and #item > 0 then
					target_name = item
					target_action = "add"
					util.exec("rm  /tmp/" .. section_key .. "_remove_apn")
				else
					target_name = apn_cfg
					target_action = "del"
				end
			end
		elseif targetname == "apn_cfg2" then
			local apn_cfg2 = m.uci:get("cpecfg", section_key, "apn_cfg2") or ""
			if apn_cfg2 ~= item then
				if item and #item > 0 then
					target_name = item
					target_action = "add"
					util.exec("rm  /tmp/" .. section_key .. "_remove_apn2")
				else
					target_name = apn_cfg2
					target_action = "del"
				end
			end
		end

		if item and #item > 0 then
			m.uci:set("cpecfg", section_key, "cpesim")
			m.uci:set("cpecfg", section_key, targetname, item)
			m.uci:save("cpecfg")
			m.uci:commit("cpecfg")
		end

		luci.nradio.reload_apn_used(target_name, target_action, section_key)
	end
end

return m
