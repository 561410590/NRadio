local cl = require "luci.model.cloudd".init()
local ca = require "cloudd.api"
local uci = require "luci.model.uci".cursor()

local id = ca.cloudd_get_self_id()
local cdev = cl.get_device(id, "master")

local slaves = cdev:slaves_sort()
local total_radio2 = 0
local total_radio5 = 0
local index_radio2 = 0
local index_radio5 = 0
local bandlist = {}
local def_ssid = "@Guest-" .. uci:get("oem", "board", "id"):gsub(":", ""):sub(-4,-1)
local def_bands = ""
local encrv

for i = 1, #slaves do
    local slave = slaves[i]
    local radio_cnt = slave:get_radiocnt()
    total_radio2 = total_radio2 + (radio_cnt.band2 or 1)
    total_radio5 = total_radio5 + (radio_cnt.band5 or 1)
end

for i = 1, #slaves do
    local slave = slaves[i]
    local radio_cnt = slave:get_radiocnt()
    local group = slave:group()
    local radio_band2 = (radio_cnt.band2 or 1)
    local radio_band5 = (radio_cnt.band5 or 1)

    for j = 1, radio_band2 + radio_band5 do
        local index = radio_band2 ~= 0 and j - 1 or j
        local bandname = "5G"
        if index < radio_band2 then
            bandname = "2.4G"
            index_radio2 = index_radio2 + 1
            if total_radio2 > 1 then
                bandname = "2.4G-"..(index_radio2)
            end
        else
            index_radio5 = index_radio5 + 1
            if total_radio5 > 1 then
                bandname = "5G-"..(index_radio5)
            end
        end
        bandlist[#bandlist + 1] = {value = 0, name = bandname, section = group.."wlan"..index}
    end
end

m = Map("guest", translate("Guest Wi-Fi"))

function tplparse(object, key, value)
    object.rmempty = false
    function object.parse(self, section, novld)
        local fvalue = self:formvalue(section)
        local cvalue = self:cfgvalue(section)
        if not fvalue and key ~= value then
            self:remove(section)
            return
        end
        return Value.parse(self, section, novld)
    end
end

-- wireless toggle was requested, commit and reload page
function m.parse(map)
    state = Map.parse(map)

    if m:submitstate() then
        local nradio = require "luci.nradio"
        nradio.apply_guest()
        return state
    end

    return state
end

s = m:section(NamedSection, "config", "guest")

en = s:option(Flag, "enable", translate("Enable"))
en.rmempty = false
en.default = en.disabled

ssid = s:option(Value, "ssid", translate("SSID"))
ssid.datatype = "and(minlength(1),maxlength(32))"
function ssid.cfgvalue(self, section)
    if m:get(section, "enable") then
        return m:get(section, "ssid")
    else
        return def_ssid
    end
end
ssid.rmempty = false

encr = s:option(ListValue, "encryption", translate("Encryption"))
encr:value("none", translate("Open"))
encr:value("psk-mixed", translate("WPA2-PSK"))
encr.default = "none"
function encr.write(self, section, value)
    encrv = value
    return Value.write(self, section, value)
end

key = s:option(Value, "key", translate("Key"))
key:depends("encryption", "psk-mixed")
key.datatype = "wpakey"
tplparse(key, encrv, "psk-mixed")

iso = s:option(Flag, "isolation", translate("Isolation"))
iso.rmempty = false
iso.default = iso.enabled

bands = s:option(MultiValue, "bands", translate("Apply Band"))
for i = 1, #bandlist do
    bands:value(bandlist[i].section, bandlist[i].name)
    def_bands = def_bands .. " " .. bandlist[i].section
end
function bands.cfgvalue(self, section)
    if m:get(section, "enable") then
        return m:get(section, "bands")
    else
        return def_bands
    end
end

submit = Template("nradio_plugin/confirm_submit")
function submit.render(self)
    luci.template.render(self.template, {noppsk = true})
end
m:append(submit)

return m
