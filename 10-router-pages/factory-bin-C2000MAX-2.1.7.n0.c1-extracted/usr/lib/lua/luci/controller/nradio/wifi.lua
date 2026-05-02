-- Copyright 2017 NRadio

module("luci.controller.nradio.wifi", package.seeall)

local uci = require "luci.model.uci".cursor()
local lng = require "luci.i18n"
local jsn = require "luci.jsonc"
local utl = require "luci.util"
local fs = require "nixio.fs"
local nr = require "luci.nradio"

function index()
    local nradio = require "luci.nradio"
    if nradio.has_ptype("ac") or not nradio.has_own_wlan() then
        return
    end

    entry({"nradio", "basic", "wifi"}, cbi("nradio_wifi/devcfg", {action = 1, hideapplybtn = true, hidesavebtn = true, hideresetbtn = true}), _("Wireless Setting"), 20, true).index = true
    entry({"nradio", "basic", "wifi", "advanced"}, call("action_device_radio"), _("Wireless Setting"), 20, true).leaf = true
    entry({"nradio", "basic", "wifi", "set"}, post("action_device_set"), nil, nil, true).leaf = true
end

local function sync_nrmesh(cld, gradio, section, freq, key, value, oids)
    local tmp = uci:get("cloudd", gradio, "nrctrl_mode_"..section) or ""
    local nrctrl_mode = tmp:match("^wireless.radio%d+.nrctrl_mode=(%d+)$") or "0"
    local device

    if nrctrl_mode == "1" then
        uci:foreach("nrmesh", "nrdev",
                    function(s)
                        if s.band then
                            if s.band == freq then
                                device = cld.get_device(s.mac, "slave")
                                if device then
                                    group = device:group()
                                    uci:set("cloudd", group.."radio", key, value)
                                    oids[device:get_oid()] = true
                                end
                            end
                        end
                    end
        )
        uci:set("cloudd", "g0radio", key, value)
    end

    return oids
end

local function calc_mac(mac, index)
    local oui = mac:sub(1, 6)
    local tmp = mac:sub(7, 12)
    return string.format("%s%06X", oui, tonumber(tmp,16) + index)
end

local function lookup_radio_index(info, name)
    local index_all = {}

    if type(info) ~= "table" then
        return index_all
    end

    for i = 1, #info do
        if info[i].name:gsub("_%d+$", ""):match("^"..name.."$") then
            index_all[#index_all + 1] = i
        end
    end

    return index_all
end

local function list_radios(id)
    local result = {count = 0, radio = {}}
    local cld = require "luci.model.cloudd".init()
    local device = cld.get_device(id, "master")
    local total_radio2 = 0
    local total_radio5 = 0
    local index_radio2 = 0
    local index_radio5 = 0
    local platform = nr.get_platform()

    if not device then
        return result
    end

    local slaves = device:slaves_sort()

    for i = 1, #slaves do
        local slave = slaves[i]
        local radiocnt = slave:get_radiocnt()
        total_radio2 = total_radio2 + (radiocnt.band2 or 1)
        total_radio5 = total_radio5 + (radiocnt.band5 or 1)
    end

    for j = 1, #slaves do
        local slave = slaves[j]
        local radio2_cnt = tonumber(uci:get("cloudd", slave:dname(), "r2cnt") or 1)
        local radio5_cnt = tonumber(uci:get("cloudd", slave:dname(), "r5cnt") or 1)
        local phy2_cnt = tonumber(uci:get("cloudd", slave:dname(), "p2cnt") or 1)
        local phy5_cnt = tonumber(uci:get("cloudd", slave:dname(), "p5cnt") or 1)
        local group = slave:group()
        local template_list = uci:get("cloudd", group, "template") or {"t0"}
        local device_info = slave:device_info()
        local id = slave:id()
        local sniff2_cnt = phy2_cnt - radio2_cnt
        local sniff5_cnt = phy5_cnt - radio5_cnt
        local radiocnt = slave:get_radiocnt()

        for i = 1, (phy2_cnt + phy5_cnt) do
            local radio = {}
            local radidx = i - 1
            local is_5g = false

            radio.mode = "normal"
            if i > phy2_cnt then
                is_5g = true
                radio.freq = 5
                radio.radio = "5G"
                index_radio5 = index_radio5 + 1
                if total_radio5 > 1 then
                    radio.radio = "5G-"..index_radio5
                end
                if i > radio5_cnt + phy2_cnt then
                    radio.mode = "sniffer"
                end
            else
                radio.freq = 2
                radio.radio = "2.4G"
                index_radio2 = index_radio2 + 1
                if total_radio2 > 1 then
                    radio.radio = "2.4G-"..index_radio2
                end
                if i > radio2_cnt then
                    radio.mode = "sniffer"
                end
            end

            if phy2_cnt == 0 then
                radidx = radidx + 1
            end

            radio.mac = calc_mac(id, radidx)
            radio.did = id

            if radio.mode == "normal" then
                local gradio = group .. "radio"
                local gwlan = group .. "wlan"
                local template = template_list[i] or template_list[1] or template_list
                local radname
                local index_all
                local ifname
                local htmode

                radname = "radio" .. radidx
                if platform == "tdtech" then
                    local band = cld.get(radname, gradio, "band") or "" -- for dbdc

                    if band == "5g" then
                        radio.freq = 5
                        radio.radio = "5G"
                    end
                end
                radio.phyname = uci:get("wireless", radname, "phyname") or ""
                radio.idx = radidx
                radio.template = template
                radio.channel = cld.get(radname, gradio, "channel") or "auto"
                if radio.channel == "-1" then
                    radio.disall = "1"
                    radio.channel = "auto"
                else
                    if radio.channel == "0" then
                        radio.channel = "auto"
                    end
                    radio.disall = cld.get(radname, gradio, "disall") or "0"
                end
                radio.txp = tonumber(cld.get(radname, gradio, "txpower") or "100")

                if radio.txp >= 80 and radio.txp < 100 then
                    radio.txp = 80
                elseif radio.txp < 80 then
                    radio.txp = 50
                end

                radio.stacnt = 0

                htmode = cld.get(radname, gradio, "htmode") or "VHT20"
                
                if htmode:match("40") then
                    radio.width = "40"
                elseif htmode:match("80") then
                    radio.width = "80"
                elseif htmode:match("160") then
                    radio.width = "160"
                else
                    radio.width = "20"
                end
                radio.hwmode = cld.get(radname, gradio, "hwmode") or ""
                ifname = "wlan" .. radidx
                index_all = lookup_radio_index(device_info, ifname)

                for j = 1, #index_all do
                    radio.stacnt = radio.stacnt + device_info[index_all[j]].sta
                end
                radio.rssi = cld.get(ifname, gwlan, "lowrssi") or ""
                radio.maxsta = cld.get(ifname, gwlan, "maxstanum") or ""
                radio.url = luci.dispatcher.build_url("nradio", "device", "config", id, radname)
                if radiocnt and radiocnt.chlist and radiocnt.chlist["radio"..radidx] then
                    radio.chlist = radiocnt.chlist["radio"..radidx].chlist
                    radio.skip_channels = radiocnt.chlist["radio"..radidx].skip_channels
                    if radio.channel == "auto" and radiocnt.chlist["radio"..radidx].channel ~= "0" then
                        radio.channel = radiocnt.chlist["radio"..radidx].channel
                    end
                else
                    radio.chlist = {}
                    radio.skip_channels = {}
                end
                if radiocnt and radiocnt.bwlist and radiocnt.bwlist["radio"..radidx] then
                    for i = 1, #radiocnt.bwlist["radio"..radidx].bwlist do
                        radiocnt.bwlist["radio"..radidx].bwlist[i] = radiocnt.bwlist["radio"..radidx].bwlist[i]:match("%d+$")
                    end
                    radio.bwlist = radiocnt.bwlist["radio"..radidx].bwlist
                else
                    radio.bwlist = {}
                end
            end

            result.radio[#result.radio + 1] = radio
        end
    end

    result.count = #result.radio

    return result
end

-- config data
-- {
--  type: 'radio',
--  info: [
--      {
--          did: 'FC83C6XXXXXX',
--          idx: X,
--          channel_radioX: 10,
--          htmode_radioX: 'HT20',
--          tpl: 'tY'
--      },
--      {
--          did: 'FC83C6XXXXXX',
--          idx: Z,
--          channel_radioX: 149,
--          htmode_radioX: 'HT20',
--          tpl: 'tA'
--      },
--  ]
-- }
local function set_device_radio()
    local cld = require "luci.model.cloudd".init()
    local capi = require "cloudd.api"
    local info = jsn.parse(luci.http.formvalue("info") or "{}")
    local device
    local oids = {}
    local dname = {}
    local acmode = nr.has_ptype("ac") or false
    local platform = nr.get_platform()
    local vendor = nr.get_wifi_vendor()

    for i = 1, #info do
        local config = info[i]
        local modified = false

        if config.did then
            local group

            device = dname[config.did]
            if not device then
                device = cld.get_device(config.did, "slave")
                dname[config.did] = device
            end

            group = device:group()
            for k, v in pairs(config) do
                local option
                local section
                local stype

                if k:match("radio") then
                    option = (k:gsub("_radio%C*", ""))
                    section = k:match("radio%C*")
                    stype = "radio"
                elseif k:match("wlan") then
                    option = (k:gsub("_wlan%C*", ""))
                    section = k:match("wlan%C*")
                    stype = "wlan"
                end
                if option and section then
                    if option == "channel" and v == "auto" and (not acmode) and platform ~= "tdtech" and vendor ~= "seekwave" then
                        if not uci:get("wireless", section, "chlist") then
                            v = "0"
                        end
                    end
                    if option == "maxstanum" and (platform == "tdtech" or platform == "quectel") then
                        option = "maxassoc"
                    end
                    if option == "htmode" then                     
                        if section == "radio0" then
                            v = "HT"..v
                        else
                            v = "VHT"..v
                        end
                    end
                    value = "wireless."..section.."."..option.."="..v
                    uci:set("cloudd", group..stype, k, value)
                    if option == "htmode" then
                        local band = uci:get("wireless", section, "band") or "2g"
                        if band:match("2") then
                            oids = sync_nrmesh(cld, group..stype, section, "1", k, value, oids)
                        else
                            oids = sync_nrmesh(cld, group..stype, section, "2", k, value, oids)
                        end
                    end
                    modified = true
                end
            end

            if config.tpl then
                local template_list = uci:get("cloudd", group, "template") or {"t0"}

                if template_list[config.idx] then
                    if template_list[config.idx] ~= config.tpl then
                        template_list[config.idx] = config.tpl
                        modified = true
                    end
                else
                    if type(template_list) == "string" then
                        template_list = {template_list}
                    end

                    for j = 1, config.idx - 1 do
                        template_list[j] = template_list[j] or "t0"
                    end

                    template_list[config.idx] = config.tpl
                    modified = true
                end

                uci:set("cloudd", group, "template", template_list)
            end

            if modified then
                local oid = device:get_oid()
                oids[oid] = true
            end
        end
    end

    local changes = uci:changes("cloudd")
    if changes and changes.cloudd then
        uci:commit("cloudd")
        for oid,_ in pairs(oids) do
            device = cld.get_device(oid, "master")
            device:send_config()
        end
    end
end

function action_device_set()
    local set_type = luci.http.formvalue("type") or nil

    if not set_type then
        return false
    end

    return set_device_radio()
end

-- Get specifid device's radio info
-- @param device's id
-- @return device's radio info result
-- {
--   "result": {
--     "count": 4,
--     "radio": [
--       {
--         "mac": "FC83C600449C",
--         "template": "Default",
--         "channel": "auto",
--         "rssi": "N\/A",
--         "stacnt": 0,
--         "width": "HT20"
--       },
--       {
--         "mac": "FC83C600449D",
--         "template": "Default",
--         "channel": "auto",
--         "rssi": "N\/A",
--         "stacnt": 0,
--         "width": "VHT20"
--       },
--       {
--         "mac": "FC83C600449E",
--         "template": "Default",
--         "stacnt": 0,
--         "channel": "auto",
--         "rssi": "N\/A",
--         "width": "HT20"
--       },
--       {
--         "mac": "FC83C600449F",
--         "template": "Default",
--         "channel": "auto",
--         "rssi": "N\/A",
--         "stacnt": 0,
--         "width": "VHT20"
--       }
--     ]
--   }
-- }
function action_device_radio()
    local id = utl.ubus("cloudd", "info").mac or nil
    local radiolist = list_radios(id)
    local sniffer = uci:get("sniffer", "config", "enable") or "0"

    luci.template.render("nradio_wifi/config", {id=id, radiolist=radiolist, sniffer=sniffer})
end
