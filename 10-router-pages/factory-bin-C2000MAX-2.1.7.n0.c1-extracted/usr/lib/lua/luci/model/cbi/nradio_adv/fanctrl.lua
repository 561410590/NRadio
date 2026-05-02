-- Copyright 2017-2019 NRadio

m = Map("fanctrl", translate("FanSetting"))

s = m:section(NamedSection, "fanctrl", "service")

enabled = s:option(Flag, "enabled", translate("FanSwitch"))
enabled.rmempty = false

tempdes = s:option(DummyValue,"tempdes"," ")
tempdes.template = "nradio_fanctrl/temperature_ajax"

tempdesmodel = s:option(DummyValue,"tempdesmodel",translate("ModelTemperature"))
tempdesmodel.template = "nradio_fanctrl/temperature"

--[[fandesdevice = s:option(DummyValue,"fandesdevice",translate("DeviceFanSpeed"))
fandesdevice.template = "nradio_fanctrl/temperature"
fandesdevice:depends("enabled","1")

mode = s:option( ListValue, "mode", translate("FanMode"))
mode:value("0", translate("TimerSwitch"))
mode:value("1", translate("TemperatureControl"))
mode:value("2", translate("Always-on"))
mode.default = "2"
mode:depends("enabled","1")

des = s:option(DummyValue," "," ",translate("FanModeHelp"))
des:depends("enabled","1")

localtime = s:option(DummyValue, "_systime", translate("Local Time"))
localtime.template = "admin_system/clock_status"
localtime:depends("mode","0")

endtime = s:option(Value, "endtime", translate("FanScheduleEnd"))
endtime.default="3:0"
endtime.template = "nradio_ledctrl/hmvalue"
endtime:depends("mode","0")

starttime = s:option(Value, "starttime", translate("FanScheduleStart"))
starttime.default="9:0"
starttime.template = "nradio_ledctrl/hmvalue"
starttime:depends("mode","0")

fanspeed = s:option(Value,"fanspeed",translate("FanSpeed"))
fanspeed.default="10"
fanspeed.template = "nradio_fanctrl/fanspeed"
--]]
function m.on_after_commit(map)
    os.execute("/etc/init.d/fanctrl restart")
end

return m
