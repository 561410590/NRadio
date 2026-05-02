-- Copyright 2017 NRadio
-- Licensed to the public under the Apache License 2.0.

local ut = require "luci.util"
local cl = require "luci.model.cloudd".init()

m = Map("mcast", translate("Wireless Multicast"))

s = m:section(NamedSection, "config", "mcast")

eh = s:option(ListValue, "enhance", translate("IGMP Snooping"))
eh:value(1, translate("IPv4+IPv6"))
eh:value(2, translate("IPv4 only"))
eh:value(0, translate("Disable"))

mr = s:option(ListValue, "mcsrate", translate("Multicast Rate"))
mr:depends("enhance", 0)
mr:value(-1, translate("Default"))

for i = 0, 7 do
    mr:value(i, i)
end

function m.parse(map)
    Map.parse(map)
end

function m.on_after_commit(map)
    cl.send_conf()
end

submit = Template("nradio_plugin/confirm_submit")
function submit.render(self)
    luci.template.render(self.template, {noppsk = true})
end
m:append(submit)

return m
