-- Copyright 2017-2018 NRadio
local ut = require "luci.util"
m = Map("wanchk", translate("WAN Checker"))

local model = arg[1]
local cellular_prefix,cellular_default = luci.nradio.get_cellular_prefix()
if luci.nradio.has_wan_port() then
	if not model then
		model = "wan"
	end
else
	if luci.nradio.has_cpe() then
		if not model then
			model = cellular_default
		end
	end
end
wanchk_tmpt=Template("nradio_wanchk/template")
function wanchk_tmpt.render(self)
	luci.template.render(self.template, {model=model})
end
m:append(wanchk_tmpt)

s = m:section(NamedSection,model, "checker")
s.addremove = false
s.anonymous = true

dnsopen = s:option(Flag, "dnsopen", translate("DNSCtl"),"")
dnsopen.default = "1"

pingopen = s:option(Flag, "pingopen", translate("PINGCtl"),"")
pingopen.default = "1"

local ipwrite=0
local function initaddr(object,option,index)
	function object.parse(self, section, novld)
		if ipwrite == 0 then
			local fvalue = self:formvalue(section)
			local cvalue = m.uci:get("wanchk", section, "ipaddr") 

			local ipaddr1_key = "cbid."..self.map.config.."."..section..".".."ipaddr1"
			local ipaddr1_data = luci.http.formvalue(ipaddr1_key)
			local ipaddr_key = "cbid."..self.map.config.."."..section..".".."ipaddr"
			local ipaddr_data = luci.http.formvalue(ipaddr_key)

			local checkip=""
			if ipaddr_data and #ipaddr_data > 0 then
				checkip=ipaddr_data
			end
			if ipaddr1_data and #ipaddr1_data > 0 then
				if #checkip == 0 then
					checkip=ipaddr1_data
				else
					checkip=checkip.." "..ipaddr1_data
				end			
			end
			if #checkip == 0 and cvalue and #cvalue > 0 then
				checkip = cvalue
			end
			m:set(section,option,checkip)
			ipwrite=1
			return 
		end
		return Value.parse(self, section, novld)
    end  

    function object.cfgvalue(self, section)
		get_val = m:get(section, option) or ""
		return ut.split(get_val, " ")[index]
	end
end


checkip = s:option(Value, "ipaddr", translate("CheckAddr"),"")
checkip.datatype = "or(hostname,ip4addr)"
checkip:depends("pingopen","1")
initaddr(checkip,"ipaddr",1)

checkip1 = s:option(Value, "ipaddr1", " ","")
checkip1.datatype = "or(hostname,ip4addr)"
checkip1:depends("pingopen","1")
initaddr(checkip1,"ipaddr",2)

pingtimeout = s:option(Value, "timeout", translate("PingTimeout"),"")
pingtimeout.datatype = "uinteger"
pingtimeout:depends("pingopen","1")
pingtimes = s:option(Value, "try", translate("PingTimes"),"")
pingtimes.datatype = "uinteger"
pingtimes:depends("pingopen","1")


checkdns = s:option(Value, "dns", translate("CheckDNS"),"")
checkdns.datatype = "ip4addr"
checkdns:depends("dnsopen","1")

failmax = s:option(Value, "max", translate("FailMax"),"")
failmax.datatype = "uinteger"
failmax:depends("pingopen","1")
failmax:depends("dnsopen","1")

if not model:match("wan") then
	failhmax = s:option(Value, "powermax", translate("FailHMax"),"")
	failhmax.datatype = "uinteger"
	failhmax:depends("pingopen","1")
	failhmax:depends("dnsopen","1")
end

period = s:option(Value, "period", translate("CheckPeriod"),"")
period.datatype = "uinteger"

flowspeed = s:option(Value, "flowlimit", translate("Flowspeed"),"")
flowspeed.datatype = "uinteger"
flowspeed:depends("pingopen","1")
flowspeed:depends("dnsopen","1")

if not model:match("wan") then
	pingtimeout.default="12"
	pingtimes.default="3"
	checkdns.default="1.2.4.8"
	failmax.default="3"
	failhmax.default="6"
	flowspeed.default="10240"
	period.default="10"
else
	pingtimeout.default="5"
	pingtimes.default="3"
	checkdns.default="210.2.4.8"
	failmax.default="3"
	flowspeed.default="204800"
	period.default="10"
end

function m.on_after_commit()
	if m:submitstate() then
		ut.exec("/etc/init.d/wanchk restart")
	end
end
return m




