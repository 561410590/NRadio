-- Copyright 2018 NRadio
-- Licensed to the public under the Apache License 2.0.

local ut = require "luci.util"
local iface = "cpe"

local function bytes_convert(tx, rx)
    local unit = {"B", "KB", "MB", "GB", "TB"}
    local _tx = tonumber(tx) or 0
    local _rx = tonumber(rx) or 0
    local _tot = _tx + _rx
    local i = 1

    while _tot > 1024 or i > #unit do
        _tot = _tot / 1024
        i = i + 1
    end

    return (string.format("%.2f", _tot)..unit[i])
end

m = Map("tcsd", translate("Cellular Traffic"))

stat = Template("nradio_cpestat/stat")
function stat.render(self)
    luci.template.render(self.template, {iface = iface})
end
m:append(stat)

s = m:section(NamedSection, iface, "interface")

en = s:option(Flag, "reset", translate("Reset Monthly"))

function m.parse(map)
    Map.parse(map)
    if m:submitstate() then
        os.execute("/etc/init.d/tcsd restart")
    end
end

return m
