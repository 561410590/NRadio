-- Copyright 2017-2019 NRadio

m = Map("ledctrl", translate("LED Control"))

local en

s = m:section(NamedSection, "ledctrl", "service")

en = s:option(Flag, "disabled", translate("LED Status"))
en.rmempty = false

schedule = s:option(Flag, "schedule", translate("scheduleCtl"))
schedule.rmempty = false
schedule:depends("en",not "1")

localtime = s:option(DummyValue, "_systime", translate("Local Time"))
localtime.template = "admin_system/clock_status"
localtime:depends("schedule","1")

starttime = s:option(Value, "starttime", translate("scheduleStart"))
starttime.template = "nradio_ledctrl/hmvalue"
starttime:depends("schedule","1")
endtime = s:option(Value, "endtime", translate("scheduleEnd"))
endtime.template = "nradio_ledctrl/hmvalue"
endtime:depends("schedule","1")

function en.cfgvalue(self, section)
    local value = m:get(section, "disabled")

    if value == "1" then
        return "0"
    else
        return "1"
    end
end

function en.write(self, section, value)
    if value == "1" then
        m:set(section, "disabled", "0")
    else
        m:set(section, "disabled", "1")
    end
end

function m.on_after_commit(map)
    os.execute("/etc/init.d/ledctrl restart")
end

return m
