-- Copyright 2017-2019 NRadio

m = Map("logservice", translate("System Log"))

local fs = require "nixio.fs"

local en

s = m:section(NamedSection, "root", "rule")

en = s:option(Flag, "sync", translate("Local Flash Store"))
en.rmempty = false

function m.on_after_commit(map)
    if fs.access("/etc/init.d/rsyslog") then
        os.execute("/etc/init.d/rsyslog restart")
    end
    if fs.access("/etc/init.d/logservice") then
        os.execute("/etc/init.d/logservice restart")
    end
end

submit = Template("nradio_adv/logread")
function submit.render(self)
    luci.template.render(self.template, {local_support = true})
end
m:append(submit)

return m
