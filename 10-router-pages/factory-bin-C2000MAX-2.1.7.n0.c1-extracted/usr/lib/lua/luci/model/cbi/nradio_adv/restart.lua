-- Copyright 2017-2018 NRadio

local nr = require "luci.nradio"
local util = require "luci.util"

fcron = "/etc/crontabs/root"
magic = "# Auto reboot"

m = Map("restart", translate("Reboot"))
m.redirect = luci.dispatcher.build_url(unpack(luci.dispatcher.context.request))

s = m:section(NamedSection, "reboot", "restart")

button_rboot = s:option(DummyValue, "reboot", translate("Reboot"))
button_rboot.template = "nradio_adv/restart_reboot"

s:option(DummyValue, "systime", translate("Local Time")).template = "nradio_adv/restart_clock"

enabled = s:option(Flag, "enabled", translate("Scheduled Restart"))
enabled.default = enabled.disabled
enabled.rmempty = false

mode = s:option(Value, "mode", translate("Rboot Mode"))
mode.template = "nradio_adv/restart_mode"
mode.rmempty = false
mode:depends("enabled", enabled.enabled)

function mode.parse(self, section, novld)
	local key = "cbid."..self.map.config.."."..section.."."..self.option
	local val = luci.http.formvalue(key)

	if val and #val > 0 then
		m.uci:set("restart", section, "mode", val)
	end
end

time = s:option(Value, "time", translate("Time"))
time.template = "nradio_adv/restart_time"
time.default = "1,1,3,30"
time.rmempty = false
time:depends("enabled", enabled.enabled)

function time.parse(self, section, novld)
	local key = "cbid."..self.map.config.."."..section.."."..self.option
	local val = luci.http.formvalue(key)

	if val and #val > 0 then
		m.uci:set("restart", section, "time", val)
	end
end

m:append(Template("cbi/nradio_submit"))

function m.on_commit(map)
	local mode = m.uci:get("restart", "reboot", "mode")
	local time_value = m.uci:get("restart", "reboot", "time") or "1,1,3,30"
	local status = m.uci:get("restart", "reboot", "enabled") == '1' and true or false
	local command = [[ date +%s|awk '{print "@" $1+70}'|xargs date -s && touch /etc/banner && reboot ]]

	if status then
		local time_table = util.split(time_value, ',')

		if #time_table ~= 4 or not time or not mode then
			return
		end

		util.exec("sed -i '/"..magic.."$/d' " .. fcron)

		local cron_line
		if mode == "0" then
			cron_line = time_table[4].." "..time_table[3].." * * * "..command.." "..magic
		elseif mode == "1" then
			cron_line = time_table[4].." "..time_table[3].." * * "..time_table[1].." "..command.." "..magic
		elseif mode == "2" then
			cron_line = time_table[4].." "..time_table[3].." " ..time_table[2].." * * "..command.." "..magic
		end
		if cron_line and #cron_line > 0 then
			local f = io.open(fcron, "a")
			if f then
				f:write(cron_line .. "\n")
				f:close()
			end
		end
	else
		util.exec("sed -i '/"..magic.."$/d' " .. fcron)
	end
	util.exec("/etc/init.d/cron restart")
end


return m
