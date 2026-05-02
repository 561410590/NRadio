-- Copyright 2017
local type, next, pairs, ipairs, loadfile, table, select, string, tonumber, math, os
    = type, next, pairs, ipairs, loadfile, table, select, string, tonumber, math, os

local util = require "luci.util"
local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local ntm = require "luci.model.network".init()
local dsp = require "luci.dispatcher"
local lng = require "luci.i18n"
local fs = require "nixio.fs"
local capi = require "cloudd.api"
local cjson = require "cjson.safe"
local nixio = require "nixio"
local nr = require "luci.nradio"
local redis

if pcall(require, "redis") then
    redis = require "redis"
end

local redis_cli = nil

local cl = capi.cloudd_ubus_cloudd_client()
local ci = util.ubus("cloudd", "info") or {}

module "luci.model.cloudd"

local function split_val(value)
    if value then
        local array = util.split(value, "=", 2)
        return array[2]
    end

    return nil
end

local function fork_call(func)
    local pid = nixio.fork()
    if pid > 0 then
        return
    elseif pid == 0 then
        -- change to root dir
        nixio.chdir("/")

        -- patch stdin, out, err to /dev/null
        local null = nixio.open("/dev/null", "w+")
        if null then
            nixio.dup(null, nixio.stderr)
            nixio.dup(null, nixio.stdout)
            nixio.dup(null, nixio.stdin)
            if null:fileno() > 2 then
                null:close()
            end
        end

        util.exec("echo cloudd > /var/run/luci-reload-status")

        if type(func) == "function" then
            func()
        end

        util.exec("rm -f /var/run/luci-reload-status")

        nixio.exec("/bin/echo", "done")
    end
end

function connect_redis(host, port)
    if not redis then
        return redis_cli
    end

    local client = redis.connect(host and host or '127.0.0.1', port and port or 6379)
    local response = client:ping()

    if response then
        redis_cli = client
    end

    return redis_cli
end

function get(ifname, section, option)
    local t = uci:get("cloudd", section, option .. "_" .. ifname)
    return split_val(t)
end

function set(ifname, section, option, value, config)
    if not config then
        config = "wireless"
    end

    local v = config .. "." .. ifname .. "." .. option .. "=" .. value
    uci:set("cloudd", section, option .. "_" .. ifname, v)
end

function cloudd_update()
    local proto = "mqtt"
    capi.cloudd_send_status_all_group(proto)
end

function convert_uptime(uptime)
    local uptime_str
    local _day = 0
    local _hour = 0
    local _min = 0
    local _sec = 0

    uptime = uptime and tonumber(uptime)

    if uptime then
        _day = math.floor(uptime / (3600 * 24))
        uptime = uptime - _day * (3600 * 24)

        _hour = math.floor(uptime / 3600)
        uptime = uptime - _hour * 3600

        _min = math.floor(uptime / 60)
        uptime = uptime - _min * 60

        _sec = uptime

        uptime_str = string.format("%dm", _min)

        if _day > 0 or _hour > 0 then
            uptime_str = string.format("%dh %s", _hour, uptime_str)
        end

        if _day > 0 then
            uptime_str = string.format("%dd %s", _day, uptime_str)
        end
    end

    return uptime_str
end

function convert_bytes(bytes)
    local result = tonumber(bytes)
    local units = { "B", "KB", "MB", "GB", "TB" }
    local i = 1

    while result > 1024 and i < #units do
        result = result / 1024.0
        i = i + 1
    end

    return string.format("%0.1f %s", result, units[i])
end

function convert_rate(rate)
    local result = tonumber(rate or 0)
    local units = { "Kbps", "Mbps", "Gbps" }
    local i = 1

    while result > 1000 and i < #units do
        result = result / 1000.0
        i = i + 1
    end

    return string.format("%0.1f %s", result, units[i])
end

function create_group(sid, gid)
    local _proto = "mqtt"
    local _section = capi.cloudd_create_group_config(sid, gid)

    if not _section then
        return nil
    end


    -- update group id
    capi.cloudd_update_config(sid, proto)

    -- mosquitto config reload
    capi.cloudd_reload_mosq_safe()

    return _section
end

function lookup_master(sid)
    local _master

    uci:foreach("cloudd", "device",
                function(s)
                    if s.id == sid then
                        _master = s[".name"]
                        return false
                    end
                end
    )

    return _master
end

function lookup_slave(sid, oid, pos)
    local _master
    local _slave
    local _rcnt

    uci:foreach("cloudd", "cboard",
                function(s)
                    if s.id == sid then
                        _section = s[".name"]:match("d%d+")
                        _oid = uci:get("cloudd", _section, "id")

                        if _oid == oid then
                            _slave = s[".name"]
                            return false
                        end
                    end
                end
    )

    return _slave
end

function init()
    return _M
end

-- Base Device
device = util.class()
function device.__init__(self, dev, ...)
    if dev then
        self.sid        = dev.id
        self.oid        = self.sid
        self.section    = dev['.name']
        self.name       = dev.name
        self.status     = capi.cloudd_enum_device_status("status_offline")
        self.radio      = {}
        self.radiocnt   = {}
        self.pos        = tonumber(dev.pos or 0)
    end
end

function device:id()
    return self.sid
end

function device:mac()
    return self.sid:sub(1,2) .. ":" ..
        self.sid:sub(3,4) .. ":" ..
        self.sid:sub(5,6) .. ":" ..
        self.sid:sub(7,8) .. ":" ..
        self.sid:sub(9,10) .. ":" ..
        self.sid:sub(11,12)
end

function device:get_oid()
    return self.oid
end

function device:get_radio()
    return self.radio
end

function device:get_radiocnt()
    return self.radiocnt
end

function device:get_status()
    return self.status
end

function device:get_name()
    return self.name
end

function device:get_uptime()
    return self.uptime
end

function device:get_uptime_format()
    return self.uptime and convert_uptime(self.uptime) or nil
end

function device:get_version()
    return self.sversion
end

function device:get_wired()
    return self.wired_client or {}
end

function device:get_ifinfo()
    return self.ifinfo or {}
end

function device:get_model()
    return self.model
end

function device:get_board()
    return self.board
end

function device:get_vendor()
    return self.vendor
end

function device:get_ptype()
    return self.ptype
end

function device:get_ipaddr()
    return self.ipaddr
end

function device:get_i18n()
    return self.name
end

function device:dname()
    return self.section
end

function device:group()
    local group = nil
    uci:foreach("cloudd", "group",
                function(s)
                    if s.device and type(s.device) == "table" then
                        for _, _id in ipairs(s.device) do
                            if _id == self.sid then
                                group = s[".name"]
                                return false
                            end
                        end
                    end
                end
    )

    if group == nil then
        local gid
        if self.oid and self.oid == ci.mac then
            gid = "g"..(tonumber(self.pos)+2)
        end
        group = create_group(self.sid, gid)
    end

    return group or "g0"
end

function device:gradio()
    local group = self:group()
    local gradio = group .. "radio"

    return gradio
end

function device:gwlan()
    local group = self:group()
    local gwlan = group .. "wlan"

    return gwlan
end

function device:send_config()
    local sid = uci:get("oem", "board", "id"):gsub(":", "")

    if sid == self.sid then
        capi.cloudd_send_config(self.sid)
    else
        fork_call(
            function()
                capi.cloudd_send_config(self.sid)
            end
        )
    end
end

-- Master Device
master = util.class(device)
function master:__init__(nidx, ...)
    device.__init__(self, ...)
    self.nidx           = tonumber(nidx and nidx or 0)
    self.slave          = {}
    self.slave_count    = 0
    self.status         = capi.cloudd_enum_device_status("status_offline")
    local lan_section = uci:get("network", "globals", "default_lan") or "lan"
    if ci and ( self.sid == ci.mac ) then
        if nr.support_mesh() then
            self.ipaddr = uci:get("network", lan_section, "ipaddr")
        else
            local wan = ntm:get_wannet()
            if wan ~= nil then
                self.ipaddr = wan:ipaddr()
            else
                self.ipaddr = uci:get("network", lan_section, "ipaddr")
            end
        end

        self.model = uci:get("oem", "board", "pname") or uci:get("oem", "board", "name")
        self.board = uci:get("oem", "board", "name")
        self.vendor = uci:get("oem", "board", "vendor")
        self.ptype = uci:get("oem", "board", "ptype")
        self.uptime = sys.uptime()
        self.sversion = sys.exec("cat /etc/openwrt_version|xargs printf")
    else
        for i = 1, cl.count do
            local _client = cl.client[i]
            if _client.id == self.sid then
                if _client.radio then
                    self.uptime = _client.uptime
                    self.sversion = _client.sversion
                    self.model = _client.name
                    self.board = _client.board
                    self.vendor = _client.vendor
                    self.ptype = _client.ptype
                    self.ipaddr = _client.ipaddr
                end
            end
        end
    end
end

function master:add_slave(slave_device)
    self.slave_count                = self.slave_count + 1
    self.slave[self.slave_count]    = slave_device
    if slave_device:get_status() < capi.cloudd_enum_device_status("status_connected") then
        if self.status == capi.cloudd_enum_device_status("status_connected") then
            self.status = capi.cloudd_enum_device_status("status_connecting")
        end
    else
        if self.status == capi.cloudd_enum_device_status("status_offline") then
            self.status = slave_device:get_status()
        end
    end
end

function master:update_status()
    self.status = 1

    for _,_slave in ipairs(self.slave) do
        if _slave:get_status() ~= 1 then
            self.status = 0
            break
        end
    end

    return self.status
end

function master:station_count()
    local _cnt = 0

    for _, _slave in ipairs(self.slave) do
        _cnt = _cnt + _slave:station_count()
    end

    return _cnt
end

function master:get_slave_count()
    return self.slave_count
end

function master:get_slaves()
    return self.slave
end

function master:slaves_sort()
    table.sort(self.slave, function(s1, s2) return s1.pos < s2.pos end)
    return self.slave
end

function master:adminlink()
    return dsp.build_url("nradio", "ac", "device", self.sid, "master")
end

function master:device_info()
    local info = {}

    for _, _slave in ipairs(self.slave) do
        local _info = _slave:device_info()
        for i = 1, #_info do
            info[#info + 1] = _info[i]
        end
    end

    return info
end

-- Slave Device
slave = util.class(device)
function slave:__init__(oid, ...)
    device.__init__(self, ...)
    self.oid = oid
    if self.sid ~= self.oid then
        self.pos = self.pos + 1
    end

    -- if it's not a local wireless
    if self.sid ~= ci.mac then
        self.radio      = {}
        self.radiocnt   = {}
        for i = 1, cl.count do
            local _client = cl.client[i]
            if _client.id == self.sid then
                if _client.radio then
                    self.radio = cjson.decode(_client.radio)
                    self.status = _client.state and tonumber(_client.state) or capi.cloudd_enum_device_status("status_connected")
                    self.uptime = _client.uptime
                    self.sversion = _client.sversion
                    self.model = _client.name
                    self.board = _client.board
                    self.vendor = _client.vendor
                    self.ptype = _client.ptype
                    self.ipaddr = _client.ipaddr
                else
                    self.status = capi.cloudd_enum_device_status("status_connecting")
                end
                if _client.wired_client then
                    self.wired_client = cjson.decode(_client.wired_client)
                end
                if _client.ifinfo then
                    self.ifinfo = cjson.decode(_client.ifinfo)
                end
                if _client.radiocnt then
                    self.radiocnt = cjson.decode(_client.radiocnt)
                end
                break
            end
        end
    else
        local lan_section = uci:get("network", "globals", "default_lan") or "lan"
        local wan = ntm:get_wannet()
        if wan ~= nil then
            self.ipaddr = wan:ipaddr()
        else
            self.ipaddr = uci:get("network", lan_section, "ipaddr")
        end
        self.model = uci:get("oem", "board", "pname") or uci:get("oem", "board", "name")
        self.board = uci:get("oem", "board", "name")
        self.vendor = uci:get("oem", "board", "vendor")
        self.ptype = uci:get("oem", "board", "ptype")
        self.uptime = sys.uptime()
        self.sversion = sys.exec("cat /etc/openwrt_version|xargs printf")
        self.status = capi.cloudd_enum_device_status("status_connected")
        self.radio, self.radiocnt = capi.cloudd_generate_local_radio()
        self.wired_client = nr.list_wired_clients()
        self.ifinfo = nr.get_local_device()
    end
end

function slave:station_count()
    local _cnt = 0

    if self.sid == ci.mac then

    else
        for _,_radio in ipairs(self.radio or {}) do
            if _radio.mode == "Master" then
                for k,v in pairs(_radio.assoclist) do
                    _cnt = _cnt + 1
                end
            end
        end
    end

    return _cnt
end

function slave:update_status()
    for i = 1, cl.count do
        _client = cl.client[i]
        if self.sid == _client.id then
            if _client.radio then
                self.status = _client.state and tonumber(_client.state) or capi.cloudd_enum_device_status("status_connected")
            else
                self.status = capi.cloudd_enum_device_status("status_connecting")
            end
            break
        end
    end

    return self.status
end

function slave:adminlink()
    if self.sid == ci.mac then
        return dsp.build_url("admin", "network", "wireless")
    else
        return dsp.build_url("nradio", "ac", "device", self.sid, "slave")
    end
end

function slave:device_info()
    local info = {}

    for _,_radio in ipairs(self.radio or {}) do
        if _radio.name and string.match(_radio.name, "^wlan") then
            local _cnt = 0
            local rinfo = {
                channel = _radio.channel,
                ssid = _radio.ssid,
                txbytes = tonumber(_radio.txbytes or 0),
                txbytes2 = 0,
                txbytes5 = 0,
                rxbytes = tonumber(_radio.rxbytes or 0),
                rxbytes2 = 0,
                rxbytes5 = 0,
                name = _radio.name,
                sta = 0,
                sta2 = 0,
                sta5 = 0
            }

            for _,_ in pairs(_radio.assoclist) do
                _cnt = _cnt + 1
            end

            if string.match(_radio.frequency, "^2") then
                rinfo.sta2 = _cnt
                rinfo.txbytes2 = tonumber(_radio.txbytes or 0)
                rinfo.rxbytes2 = tonumber(_radio.rxbytes or 0)
            else
                rinfo.sta5 = _cnt
                rinfo.txbytes5 = tonumber(_radio.txbytes or 0)
                rinfo.rxbytes5 = tonumber(_radio.rxbytes or 0)
            end

            rinfo.sta = _cnt
            rinfo.id = self.sid

            info[#info + 1] = rinfo
        end
    end

    return info
end

function get_device(id, role)
    local _device

    if id == nil then
        id = ci.mac
    end

    if role == "master" then
        uci:foreach("cloudd", "device",
                    function(s)
                        if s.id == id then
                            _device = master(s.next_cb_idx, s)
                            return false
                        end
                    end
        )
    end

    if role == "master" and _device or role == "slave" then
        if role == "master" then
            for i = 0, _device.nidx - 1 do
                section = _device.section.."cboard"..i
                cbcfg = uci:get_all("cloudd", section)
                if cbcfg then
                    local _slave = slave(_device:id(), cbcfg)
                    _device:add_slave(_slave)
                end
            end
        elseif role == "slave" then
            uci:foreach("cloudd", "cboard",
                        function(s)
                            if s.id == id then
                                _section = s['.name']:match("d%d+")
                                _oid = uci:get("cloudd", _section, "id")
                                _device = slave(_oid, s)
                                return false
                            end
                        end
            )
        end
    end

    return _device
end

function get_devices()
    local devices = {}

    uci:foreach("cloudd", "device",
                function(s)
                    local _master = master(s.next_cb_idx, s)
                    devices[#devices + 1] = _master
                end
    )

    for _,_master in ipairs(devices) do
        for i = 0, _master.nidx - 1 do
            section = _master.section.."cboard"..i
            cbcfg = uci:get_all("cloudd", section)
            if cbcfg then
                local _slave = slave(_master:id(), cbcfg)
                _master:add_slave(_slave)
            end
        end
    end

    return devices
end

function send_conf()
    local sid = uci:get("oem", "board", "id"):gsub(":", "")
    uci:foreach("cloudd", "group",
                function(s)
                    if s[".name"] == "g0" then
                        capi.cloudd_send_config_group(s[".name"])
                    elseif s.device then
                        for i = 1, #s.device do
                            if sid ~= s.device[i] then
                                capi.cloudd_send_config(s.device[i], "mqtt")
                            end
                        end
                    end
                end
    )
    capi.cloudd_send_config(sid, "mqtt")
end

function new_tpl()
    local _next_tid = uci:get("cloudd", "config", "next_tpl_idx") or 0
    local _section = "t" .. _next_tid

    while uci:get("cloudd", _section) do
        _next_tid = _next_tid + 1
        _section = "t" .. _next_tid
    end

    uci:set("cloudd", _section, "template")
    uci:set("cloudd", _section, "name", _section)
    -- uci:set("cloudd", _section .. "radio", "tplradio")
    -- uci:set("cloudd", _section .. "wlan", "tplwlan")
    uci:set("cloudd", "config", "next_tpl_idx", _next_tid + 1)
    uci:commit("cloudd")

    return _section
end

function apply_tpl(tpl)
    fork_call(
        function()
            local need_restart_apbd2 = false
            uci:foreach("cloudd", "group",
                        function(s)
                            local notify = false
                            local sid = uci:get("oem", "board", "id"):gsub(":", "")
                            local need_self_apply = false
                            if s.template then
                                if type(s.template) == "string" and s.template == tpl then
                                    notify = true
                                elseif type(s.template) == "table" then
                                    for i = 1, #s.template do
                                        if s.template[i] == tpl then
                                            notify = true
                                            break
                                        end
                                    end
                                end
                                if notify then
                                    if s[".name"] == "g0" then
                                        capi.cloudd_send_config_group(s[".name"])
                                    elseif s.device then
                                        for i = 1, #s.device do
                                            if sid ~= s.device[i] then
                                                capi.cloudd_send_config(s.device[i], "mqtt")
                                            else
                                                need_self_apply = true
                                            end
                                        end
                                    end
                                    need_restart_apbd2 = true
                                end
                            end
                        end
            )
            if need_self_apply then
                capi.cloudd_send_config(sid, "mqtt")
            end
            if not fs.access("/etc/config/wireless") and need_restart_apbd2 then
                os.execute("/etc/init.d/apbd2 restart")
            end
        end
    )
end

function add_radio_tpl(tpl, freq)
    local r2cnt = uci:get("cloudd", tpl, "r2cnt") or 1
    local r5cnt = uci:get("cloudd", tpl, "r5cnt") or 1
    local index = 0

    r2cnt = tonumber(r2cnt)
    r5cnt = tonumber(r5cnt)

    if freq == 0 then
        if r2cnt == 0 then
            index = 0
        else
            if r5cnt <= 1 then
                index = r2cnt + 1
            end
        end
    elseif freq == 1 then
        if r5cnt == 0 then
            index = 1
        else
            if r2cnt == 0 then
                index = 1 + r5cnt
            else
                index = r2cnt + r5cnt
            end
        end
    end

    if index ~= 0 then
        if freq == 1 then
            uci:set("cloudd", tpl, "r5cnt", r5cnt + 1)
        else
            uci:set("cloudd", tpl, "r2cnt", r2cnt + 1)
        end
        uci:commit("cloudd")
    end
end

function del_radio_tpl(tpl, radio)
    local config = uci:get_all("cloudd", tpl.."radio") or {}
    local commit = false

    for option, _ in pairs(config) do
        if string:match(option, radio) then
            commit = true
            uci:delete("cloudd", tpl.."radio", option)
        end
    end

    if commit then
        uci:commit("cloudd")
    end
end

function get_client_info(mac)
    local info = {}
    local hostanme
    local ipaddr

    if not redis_cli then
        return info
    end

    hostname = redis_cli:get('hn:'..mac)
    info.hostname = hostname and hostname:match("(%C+)")

    ipaddr = redis_cli:get('ip:'..mac)
    info.ipaddr = ipaddr and ipaddr:match("(%C+)")

    return info
end

function get_clients_cache_info(items)
    local clinfo = {}
    local count = 0
    local hostname
    local ipaddr

    local keys = {}

    if not redis_cli then
        return clinfo
    end

    for mac,_ in pairs(items) do
        keys[#keys + 1] = 'hn:'..mac
        keys[#keys + 1] = 'ip:'..mac
    end

    local res = redis_cli:mget(keys)

    for mac,_ in pairs(items) do
        local index = count * 2 + 1
        hostname = res[index] and res[index]:match("(%C+)")
        ipaddr = res[index + 1] and res[index + 1]:match("(%C+)")
        clinfo[mac] = {hostname = hostname, ipaddr = ipaddr}

        count = count + 1
    end

    return clinfo
end

function get_traffic_rate(ids, from)
    local txrate = 0
    local rxrate = 0
    local tmp
    local txdelta, rxdelta, tsdelta
    local rates = {}
    local keys = {}
    local items = {}

    from = from or "ui"

    if not redis_cli then
        return rates
    end

    -- read and generate result
    for i = 1, #ids do
        keys[#keys + 1] = "tc:tx2:loc:"..from..":old:" .. ids[i]
        keys[#keys + 1] = "tc:rx2:loc:"..from..":old:" .. ids[i]
        keys[#keys + 1] = "tc:tx5:loc:"..from..":old:" .. ids[i]
        keys[#keys + 1] = "tc:rx5:loc:"..from..":old:" .. ids[i]
        keys[#keys + 1] = "tc:ts:loc:"..from..":old:" .. ids[i]
        keys[#keys + 1] = "tc:tx2:loc:" .. ids[i]
        keys[#keys + 1] = "tc:rx2:loc:" .. ids[i]
        keys[#keys + 1] = "tc:tx5:loc:" .. ids[i]
        keys[#keys + 1] = "tc:rx5:loc:" .. ids[i]
        keys[#keys + 1] = "tc:ts:loc:" .. ids[i]
    end
    tmp = redis_cli:mget(keys)

    for i = 1, #ids do
        local start = (i - 1) * 10
        local tx_2g_delta = 0
        local tx_5g_delta = 0
        local rx_2g_delta = 0
        local rx_5g_delta = 0
        local txdelta = 0
        local rxdelta = 0

        for j = 1, 10 do
            tmp[j + start] = tonumber(tmp[j + start] or 0) or 0
        end

        if tmp[6 + start] >= tmp[1 + start] then
            tx_2g_delta = tmp[6 + start] - tmp[1 + start]
        else
            tx_2g_delta = tmp[6 + start]
        end

        if tmp[8 + start] >= tmp[3 + start] then
            tx_5g_delta = tmp[8 + start] - tmp[3 + start]
        else
            tx_5g_delta = tmp[8 + start]
        end

        txdelta = tx_5g_delta + tx_2g_delta

        if tmp[7 + start] >= tmp[2 + start] then
            rx_2g_delta = tmp[7 + start] - tmp[2 + start]
        else
            rx_2g_delta = tmp[7 + start]
        end

        if tmp[9 + start] >= tmp[4 + start] then
            rx_5g_delta = tmp[9 + start] - tmp[4 + start]
        else
            rx_5g_delta = tmp[9 + start]
        end

        rxdelta = rx_5g_delta + rx_2g_delta

        tsdelta = tmp[10 + start] - tmp[5 + start]

        if tsdelta == 0 then
            tsdelta = 1
        end

        txrate = txdelta / tsdelta
        rxrate = rxdelta / tsdelta

        rates[#rates + 1] = {
            id = ids[i],
            txrate = txrate,
            rxrate = rxrate,
            tx_2g_delta = tx_2g_delta,
            tx_5g_delta = tx_5g_delta,
            rx_2g_delta = rx_2g_delta,
            rx_5g_delta = rx_5g_delta
        }

        -- update old record in redis
        items["tc:tx2:loc:"..from..":old:" .. ids[i]] = tmp[6 + start]
        items["tc:rx2:loc:"..from..":old:" .. ids[i]] = tmp[7 + start]
        items["tc:tx5:loc:"..from..":old:" .. ids[i]] = tmp[8 + start]
        items["tc:rx5:loc:"..from..":old:" .. ids[i]] = tmp[9 + start]
        items["tc:ts:loc:"..from..":old:" .. ids[i]] = tmp[10 + start]
    end

    redis_cli:mset(items)

    return rates
end

function new_acl()
    local _next_aid = uci:get("cloudd_acl", "config", "next_acl_idx") or 0
    local _section = "a" .. _next_aid

    while uci:get("cloudd_acl", _section) do
        _next_aid = _next_aid + 1
        _section = "a" .. _next_aid
    end

    uci:set("cloudd_acl", _section, "acl")
    uci:set("cloudd_acl", _section, "name", _section)
    uci:set("cloudd_acl", "config", "next_acl_idx", _next_aid + 1)
    uci:commit("cloudd_acl")

    return _section
end

function apply_acl(acl)
    send_conf()
end
