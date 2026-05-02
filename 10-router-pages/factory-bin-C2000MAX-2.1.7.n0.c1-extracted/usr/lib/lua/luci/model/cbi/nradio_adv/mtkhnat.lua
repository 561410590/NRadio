-- Copyright 2017-2019 NRadio

m = Map("mtkhnat", translate("HNAT"))

local en

s = m:section(NamedSection, "global", "global")

en = s:option(Flag, "enable", translate("HNAT"), translate("HNAT Note"))
en.rmempty = false

function m.on_after_commit(map)
    os.execute("/etc/init.d/mtkhnat restart")
end

return m
