-- Copyright 2018 NRadio
-- Licensed to the public under the Apache License 2.0.

local ut = require "luci.util"
local nr = require "luci.nradio"
local nixio = require "nixio"
local http = require "luci.http"
local disp = require "luci.dispatcher"

m = Map("cpecfg")

local ICCID = ""
local model = arg[1] or ""

local model_index, model_str, cpe_section = 1, "", ""
model_str,cpe_section,model_index = nr.get_cellular_last(model)

local sim_section="sim"..model_str
local sim_index = m.uci:get("cpesel", sim_section, "cur") or "1"
local cpesim_section= cpe_section.."sim"..sim_index
local max = tonumber(m.uci:get("cpesel", sim_section, "max") or 1)

local cmd_result, cmd_error_code = 0, nil
local cmd_pin = "cpetools.sh -c cpin -i " .. model
local exit, buffer = pcall(ut.exec, cmd_pin)

if exit and buffer and #buffer > 0 then
	if buffer:match(" ") then
		cmd_result, cmd_error_code = buffer:match("(%d) (%d+)")
	else
		cmd_result=buffer:match("%d+")
	end
end

local mode_redirect = m.uci:get("cpesel", sim_section, "mode") or "0"

if mode_redirect ~= "1" or cmd_result ~= "1" then
	http.redirect(disp.build_url("nradio/system/overview"))
	return m
end

cellular_header = Template("nradio_adv/cellular_header")
function cellular_header.render(self)
	luci.template.render(self.template)
end
m:append(cellular_header)

cellular_submenu = Template("nradio_adv/cellular_submenu")
function cellular_submenu.render(self)
	luci.template.render(self.template)
end
m:append(cellular_submenu)


s = m:section(NamedSection, cpesim_section, "cpecfg")
cellular_simmenu = Template("nradio_cpecfg/cellular_simmenu")
function cellular_simmenu.render(self)
	luci.template.render(self.template)
end
s:append(cellular_simmenu)

cur_status = s:option(DummyValue, "status", translate("SIM Status"))

pin_code = s:option(Value, "pin_code", translate("PIN"), translate("*When enabled, the correct PIN must be entered to use the SIM card."))
pin_code.placeholder = '1234'
pin_code.datatype = "and(minlength(4), maxlength(8), range(0, 99999999))"
pin_code.rmempty = false

pin_code.write = function(self, section, value)
	return
end

local function set_simple_at(cmd)
	local result = -1
	local error_code = -1

	local fd = io.popen(cmd, "r")
	if fd then
		while true do
			local ln = fd:read("*l")
			if not ln or #ln == 0 then
				break
			else
				luci.nradio.syslog("err","Cpepin set_simple_at callback:" .. ln)
				result = 2
				if ln:match("ERROR") then
					error_code =  ln:match("%d+")
					if error_code then
						luci.nradio.syslog("err","Cpepin set_simple_at callback error code:" .. error_code)
					end
					result = 1
					break
				elseif ln:match("OK") then
					result = 0
					break
				end
			end
		end
		fd:close()
	end

	os.execute("sleep 2")
	return result, error_code
end

local function set_pin(pin)
	local cmd = "cpetools.sh -i "..model.." -t 0 -c 'AT+CPIN=\""..pin.."\"'"
	return set_simple_at(cmd)
end

local function get_sim_iccid()
	local cmd = "cpetools.sh -c iccid -i " .. model
	local iccid = ut.exec(cmd)
	return iccid:match("%S+")
end


pin_code.validate = function(self, value)
	ICCID = get_sim_iccid()

	if ICCID and #ICCID > 0 then
		m.uci:set("cpecfg", ICCID, "iccid")
		m.uci:set("cpecfg", ICCID, "pin", value)
	end

	return value
end

cur_status_template = Template("nradio_cpecfg/cellular_pin")
function cur_status_template.render(self)
	luci.template.render(self.template, { model = cpe_section, section = cpesim_section, simid = sim_index })
end
m:append(cur_status_template)


function m.on_after_commit()
	if ICCID and #ICCID > 0 then
		local pin_code = m.uci:get("cpecfg", ICCID, "pin") or ""
		local mode = m.uci:get("cpesel", sim_section, "mode") or "0"

		if mode == "1" and pin_code and #pin_code >= 4 and #pin_code <= 8 then
			local result, errcode = set_pin(pin_code)
		end
	end
end

return m
