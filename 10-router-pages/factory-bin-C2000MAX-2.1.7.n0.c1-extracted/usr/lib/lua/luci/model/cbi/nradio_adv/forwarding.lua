-- Copyright 2017-2018 NRadio

local ipc = require "luci.ip"

m = Map("firewall", translate("Port Fwd"))
s = m:section(TypedSection, "redirect")
m.pageaction = false
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection_nradio"
local lan_section = m.uci:get("network", "globals", "default_lan") or "lan"
function s.filter(self, section)
	return section:match("^cfg")
end

function s.create(self, section)
	created = TypedSection.create(self, section)
	self.map:set(created, "src",    lan_section)
	self.map:set(created, "dest",    "wan")
	self.map:set(created, "target",    "DNAT")
	self.map:set(created, "proto",      "tcp udp")
end
o_src = s:option(ListValue, "src", translate("SourceZone"))
o_src:value(lan_section, "LAN")
o_src:value("wan", "WAN")
o_src.default = lan_section

oip = s:option(Value, "src_dip", translate("Externaladdr"))
oip.datatype = "ip4addr"
oip.rmempty  = true

oport = s:option(Value, "src_dport", translate("ExternalPort"))
oport.datatype = "portrange"
oport.rmempty  = false
oport.default = "9999"

o_dest = s:option(ListValue, "dest", translate("Destzone"))
o_dest:value(lan_section, "LAN")
o_dest:value("wan", "WAN")
o_dest.default = "wan"

ip = s:option(Value, "dest_ip", translate("DestAddress"))
ip.datatype = "ip4addr"
ip.rmempty  = true

iport = s:option(Value, "dest_port", translate("DestPort"))
iport.datatype = "portrange"
iport.rmempty  = false
iport.default = "9999"

proto = s:option(ListValue, "proto", translate("Protocol"))
proto:value("tcp udp", "TCP+UDP")
proto:value("tcp", "TCP")
proto:value("udp", "UDP")
proto.default = "tcp udp"
proto.rmempty  = true

flag = s:option(Flag, "enabled", translate("status"))
flag.default = "1"

ipc.neighbors({ family = 4 }, function(n)
	if n.mac and n.dest then
		ip:value(n.dest:string())
	end
end)

submit = Template("cbi/nradio_submit")
function submit.render(self)
        luci.template.render(self.template, {left = true})
end
m:append(submit)
return m
