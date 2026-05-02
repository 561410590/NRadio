-- Copyright 2017-2019 NRadio

m = Map("mtkhnat", translate("ModeSelect"))

s = m:section(NamedSection, "global", "global")
mode = s:option(ListValue, "enable", translate("ModeSelectOP"))
mode:value("1", translate("PerformanceMode"))
mode:value("0", translate("SmoothMode"))
mode.default = "1"

function m.on_after_commit(map)
    os.execute("/etc/init.d/mtkhnat restart")
end

return m
