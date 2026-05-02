-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Licensed to the public under the Apache License 2.0.

local wa = require "luci.tools.webadmin"
local fs = require "nixio.fs"

m = Map("network",
	translate("Routes"),
	translate("Routes specify over which interface and gateway a certain host or network " ..
		"can be reached."))
m.pageaction = false
s = m:section(TypedSection, "route", translate("Static IPv4 Routes"))
s.addremove = true
s.anonymous = true

s.template  = "cbi/tblsection_nradio"

iface = s:option(ListValue, "interface", translate("Interface"))
wa.cbi_add_networks(iface)
iface.titleref=nil
t = s:option(Value, "target", translate("Target"), translate("Host-<abbr title=\"Internet Protocol Address\">IP</abbr> or Network"))
t.datatype = "ip4addr"
t.rmempty = false

n = s:option(Value, "netmask", translate("<abbr title=\"Internet Protocol Version 4\">IPv4</abbr>-Netmask"), translate("if target is a network"))
n.placeholder = "255.255.255.255"
n.datatype = "ip4addr"
n.rmempty = true

g = s:option(Value, "gateway", translate("<abbr title=\"Internet Protocol Version 4\">IPv4</abbr>-Gateway"))
g.datatype = "ip4addr"
g.rmempty = true
submit = Template("cbi/nradio_submit")
function submit.render(self)
        luci.template.render(self.template, {left = true})
end
m:append(submit)
return m
