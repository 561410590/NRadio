-- Copyright 2017-2018 NRadio
-- Licensed to the public under the Apache License 2.0.

local nr = require "luci.nradio"
local util = require "luci.util"
m = Map("firewall", translate("DMZTitle"),translate("DMZDes"))

s = m:section(NamedSection, "dmz", "redirect")
s.addremove = false
s.anonymous = true

e = s:option(Flag, "enabled", translate("DMZenable"), translate("DMZHelp"))
e.rmempty  = false

dest_ip = s:option(Value, "dest_ip", translate("DMZHost"))
dest_ip.datatype = "ip4addr"
dest_ip.optional = false
dest_ip.rmempty = false

return m
