-- Copyright 2018 NRadio
-- Licensed to the public under the Apache License 2.0.

local ut = require "luci.util"
local fs = require "nixio.fs"
local sp = false
local adb = false
local DEVICE = "WT9146"
local support_agreement = luci.nradio.support_agreement()
m = Map("firewall", translate("Security"))

local flag = m.uci:get("oem", "board", "name") ~= DEVICE

if fs.access("/usr/bin/supass") then
    sp = true
end

local authmode = ut.exec("bdinfo -g authmode")
if authmode and #authmode > 0 then
    sp = false
    support_agreement = false
end

if fs.access("/etc/config/adbd") then
    adb = true
    m:chain("adbd")
end

local key = luci.util.exec("bdinfo -g fac_key|cut -c 1-8|xargs -r printf")
if sp then
    if not key or #key < 8 then
        key = "12345678"
    end
end

if sp then
    if not arg[1] or arg[1] ~= key then
        luci.http.redirect(luci.dispatcher.build_url("nradio/advanced"))
    end
end
s = m:section(NamedSection, "ssh", "rule", translate("Security Configuration"))

ssh = s:option(ListValue, "target", translate("Enable SSH"))
ssh:value("ACCEPT", translate("Enable"))
ssh:value("REJECT", translate("Disable"))

if adb then
    adbd = s:option(ListValue, "adbd", translate("Enable adbd"))
    adbd:value("1", translate("Enable"))
    adbd:value("0", translate("Disable"))
    function adbd.write(self, section, value)
        if sp then
            local pwd = pass:formvalue(section)
            if pwd == "" then
                return false
            end
        end

        return m.uci:set("adbd", "service", "enable", value)
    end
    function adbd.cfgvalue(self, section)
        return m.uci:get("adbd", "service", "enable") or "0"
    end
end

if support_agreement and flag then
    s:option(DummyValue, "_agreement", "").template = "nradio_adv/agreement"
end

function ssh.write(self, section, value)
    if sp then
        local pwd = pass:formvalue(section)
        if pwd == "" then
            return false
        end
    end

    return Value.write(self, section, value)
end

if sp then
    ccode = s:option(Value, "_ccode", translate("Check Code"))
    ccode.readonly = true
    function ccode.cfgvalue(self, section)
        local uptime = ut.exec("cat /proc/uptime|cut -d. -f1|xargs -r printf")
        local value = ""
        if fs.access("/tmp/run/ccode") then
            gen_uptime = ut.exec("cat /tmp/run/ccode|cut -d, -f1|xargs -r printf")
            value = ut.exec("cat /tmp/run/ccode|cut -d, -f2|xargs -r printf")
            if tonumber(uptime) > tonumber(gen_uptime) + 900 then
                value = ut.exec("tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32 | xargs -r printf")
            else
                uptime = gen_uptime
            end
        else
            value = ut.exec("tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32 | xargs -r printf")
        end
        ut.exec("echo '"..uptime..","..value.."' > /tmp/run/ccode")
        return value
    end

    pass = s:option(Value, "_pass", translate("Password"))
    pass.password = true
    pass.datatype ="and(minlength(1),maxlength(512))"
    pass.rmempty = false
    function pass.cfgvalue(self, section)
        return ""
    end

    function pass.validate(self, value, section)
        local ccode = ut.exec("cat /tmp/run/ccode|cut -d, -f2|xargs -r printf")
        local cur = require "luci.model.uci".cursor()
        local mac = cur:get("oem", "board", "id") or "00:66:88:00:00:00"

        if os.execute("supass -t %q -s %q -m %q" % {ccode, value, mac}) == 0 then
            return Value.validate(self, value, section)
        else
            return nil, translate("Password is incorrect!")
        end
    end

    function pass.write(self, section, value)
        return true
    end
end

function m.on_after_commit(map)
    ut.exec("fw3 reload")
    if adb then
        luci.nradio.fork_exec(function ()
                nixio.nanosleep(5)
                ut.exec("attools -u 0")
        end)

        ut.exec("/etc/init.d/adbd.init restart")
    end
end

return m
