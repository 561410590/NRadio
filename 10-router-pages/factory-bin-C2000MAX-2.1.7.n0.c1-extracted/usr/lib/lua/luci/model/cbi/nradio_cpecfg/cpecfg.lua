-- Copyright 2018 NRadio
-- Licensed to the public under the Apache License 2.0.

local ut = require "luci.util"
local uci = require "luci.model.uci"
local nr = require "luci.nradio"

local support_nr = false
local cellular_nrrc = false

local support_compatibility = false
uci = uci.cursor()
m = Map("cpecfg")

cellular_header=Template("nradio_adv/cellular_header")
function cellular_header.render(self)
    luci.template.render(self.template)
end
m:append(cellular_header)

cellular_submenu=Template("nradio_adv/cellular_submenu")
function cellular_submenu.render(self)
    luci.template.render(self.template)
end
m:append(cellular_submenu)

cellular_section_redirect=Template("nradio_adv/cellular_section_redirect")
function cellular_section_redirect.render(self)
    luci.template.render(self.template,{model=arg[1]})
end
m:append(cellular_section_redirect)

local model = arg[1] or ""

local model_index = 1
local model_str = ""
local plat = nr.get_platform()
local model_str,cpe_section,model_index = nr.get_cellular_last(model)
local sim_section="sim"..model_str
local sim_bdinfo="cpesel"..model_str
local cellular_prefix,cellular_default = nr.get_cellular_prefix()
local sim_index = m.uci:get("cpesel", sim_section, "cur") or "1"
local cpesim_section= cpe_section.."sim"..sim_index
local hidden_profile = luci.http.formvalue("profile") or nil
local profile_show = false

local vsim_ignorecfg = tonumber(m.uci:get("cpesel", sim_section, "vsim_ignorecfg") or 0)
local nettype = uci:get("network",cpe_section,"nettype")




support_compatibility = uci:get("network",cpe_section,"compatibility")
support_nr = nr.support_nr(cpe_section)
cellular_nrrc = nr.support_cellular_nrrc(cpe_section)
if hidden_profile and hidden_profile == "show" then
    if not nixio.fs.access("/tmp/show_profile") then
        os.execute("touch /tmp/show_profile")
    end
end

if hidden_profile and hidden_profile == "hidden" then
    if nixio.fs.access("/tmp/show_profile") then
        os.execute("rm /tmp/show_profile")
    end
end

if nixio.fs.access("/tmp/show_profile") then
    profile_show = true
end

m:chain("cpesel")
m:chain("wanchk")


local function initrw(object,option,depends_extra_buffer,depends_reverse)
    local depends_table = {}
    local form_cur_sim = sim_index


    depends_extra = ut.split(depends_extra_buffer or "", " ")
    depends_max = #depends_extra
    for i = 1, depends_max do
        if depends_extra[i] and #depends_extra[i] > 0 then
            if depends_extra[i]:find("custom_earfcn") and depends_reverse then
                depends_table[depends_extra[i]] = not "1"
            else
                depends_table[depends_extra[i]] = "1"
            end
        end
    end

    object:depends(depends_table)
    function object.parse(self, section, novld)
        local fvalue = self:formvalue(section)
        local cvalue = self:cfgvalue(section)

        if cvalue and (not fvalue or #fvalue == 0 ) then
            return
        end

        return Value.parse(self, section, novld)
    end

    function object.write(self, section, value)
        if form_cur_sim then
            m:set(cpesim_section,nil,"cpesim")
            m:set(cpesim_section,option,value)
        end
    end
    
end
s = m:section(NamedSection, cpesim_section, "cpecfg")
cellular_simmenu=Template("nradio_cpecfg/cellular_simmenu")
function cellular_simmenu.render(self)
    luci.template.render(self.template)
end
s:append(cellular_simmenu)
if nr.support_cellular_mode(cpe_section) then
    mode = s:option(ListValue, "mode", translate("Cellular Mode"),
                    translate("*Auto mode is recommended. Manually selecting other network technologies may cause registration failure in some scenarios. Use with caution."))
    mode:value("auto", translate("Auto"))

    if support_nr then
        if nr.get_platform() ~= "tdtech" then
            mode:value("nsa", translate("NSA Preferred"))
        end
        mode:value("sa_only", translate("5G Only SA"))
        mode:value("lte", translate("4G Only"))
    else
        mode:value("lte", translate("4G Only"))
        mode:value("wcdma", translate("WCDMA Only"))
    end
    mode.default="auto"
end

if cellular_nrrc then
    nrrc = s:option(Flag, "nrrc", translate("Carrier Aggregation"),translate("*Carrier Aggregation (CA) enhances bandwidth and data rates, and is enabled by default. It can be disabled if needed."))
    nrrc.default = "1"
end

if support_nr then
    freq_time = s:option(Flag, "freq_time", translate("Freq LockTime"),translate("*Some carrier 5G base station shutdowns at night may cause 5G network registration failures. When enabled, the network will use auto mode during specified night hours, and will auto-reboot afterward to restore prior network settings."))
    freq_time.default = "0"
    endtime = s:option(Value, "endtime", translate("Lock End Time"))
    endtime.default="23:30"
    endtime.template = "nradio_cpecfg/freq_lock"
    endtime.rmempty = false
    endtime:depends("freq_time","1")

    starttime = s:option(Value, "starttime", translate("Lock Start Time"))
    starttime.default="7:0"
    starttime.template = "nradio_cpecfg/freq_lock"
    starttime.rmempty = false
    starttime:depends("freq_time","1")

    function starttime.parse(self, section, novld)
        local ft = m.uci:get("cpecfg", section, "freq_time") or "0"
        local key = "cbid."..self.map.config.."."..section.."."..self.option
        local val = luci.http.formvalue(key)
        if ft ~= "1" then
            return
        end
        if val and #val > 0 then
            m.uci:set("cpecfg", section, "starttime", val)
        end
    end

    function endtime.parse(self, section, novld)
        local ft = m.uci:get("cpecfg", section, "freq_time") or "0"
        local key = "cbid."..self.map.config.."."..section.."."..self.option
        local val = luci.http.formvalue(key)
        if ft ~= "1" then
            return
        end
        if val and #val > 0 then
            m.uci:set("cpecfg", section, "endtime", val)
        end
    end
end

if support_nr then
    peak_hour = s:option(Flag, "peak_hour", translate("Peak Hour Assurance"),translate("*During peak hours, high network demand may cause instability. When enabled, the device will temporarily reduce speeds during specified times to maintain a stable connection."))
    peak_hour.default = "0"
    peak_hour.rmempty = false

    local peak_time_value = "5,18,0,20,30"
    peak_time = s:option(Value, "peaktime", translate("Peak Periods"))
    peak_time.template = "nradio_cpecfg/peak_time_entry"
    peak_time:depends("peak_hour","1")

    function peak_time.parse(self, section, novld)
        local ph_key = "cbid."..self.map.config.."."..section..".peak_hour"
        local ph = luci.http.formvalue(ph_key) or m.uci:get("cpecfg", section, "peak_hour") or "0"
        if tostring(ph) ~= "1" then
            return
        end
        local key = "cbid."..self.map.config.."."..section.."."..self.option
        local val = luci.http.formvalue(key)
        if val and #val > 0 then
            local items = {}
            for s in val:gmatch("[^;]+") do
                s = s:gsub("^%s+", ""):gsub("%s+$", "")
                if s:match("^%d+,%d+,%d+,%d+,%d+$") then
                    table.insert(items, s)
                end
            end

            if #items > 0 then
                m.uci:set("cpecfg", section, "peaktime", table.concat(items, ";"))
            else
                m.uci:set("cpecfg", section, "peaktime", peak_time_value)
            end
        else
           m.uci:set("cpecfg", section, "peaktime", peak_time_value)
        end
        return
    end
end

if nr.support_cellular_roam(cpe_section) then
    roaming = s:option(Flag, "roaming", translate("Data Roaming"),translate("*When enabled, the device will automatically search for and switch to other available networks if it cannot connect to its home network."))
    roaming.default = "0"
end
if support_compatibility == "1" then
    compatibility = s:option(Flag, "compatibility", translate("Maximize Compatibility"),translate("*Cellular performance may be reduced when turned on."))
    compatibility.default = "0"
end

if nr.support_cellular_ippass(cpe_section) then
    ippass = s:option(Flag, "ippass", translate("IP Passthrough"),translate("*When enabled, the device will obtain a carrier-assigned public IP directly (actual availability depends on device model and base station support). Designed for professional scenarios requiring public IP addresses or special protocol forwarding."))
    ippass.default = "0"
end

if profile_show then
    profile = s:option( ListValue, "profile", translate("Profile ID"), translate("*Profile ID is the SIM card link channel. The default ID is 1. A few SIM cards require specific channel and parameters. A wrong configuration may fail to access the Internet. Please consult the ISP or refer to the instructions to get the correct configuration."))
    profile:value("1", translate("1"))
    profile:value("2", translate("2"))
    profile:value("3", translate("3"))
    profile.default = "1"

    profile_permanent = s:option(Flag, "permanent", translate("Profile Permanent"),"")
    profile_permanent.default = "0"
end

if nr.support_compatible_nr(cpe_section) then
    compatible_nr = s:option(Flag, "compatible_nr", translate("5G Compatibility"),translate("*In most cases, there is no need to turn it on. If the device cannot register to 5G, you can try again after turning it on."))
    compatible_nr.default = "0"
end

if nr.support_fallbackToR16() then
    fallbackToR16 = s:option(Flag, "fallbackToR16", translate("Fallback R16"), translate("*If cellular base station doesn't support RedCap, modem will try to fallback to R16."))
    fallbackToR16.default = "0"
end

if nr.support_fallbackToLTE() then
    fallbackToLTE = s:option(Flag, "fallbackToLTE", translate("Fallback LTE"), translate("*When enabled, the device will intelligently select between 5G and 4G networks based on real-time signal strength to ensure optimal connectivity experience."))
    fallbackToLTE.default = "1"
    fallbackToLTE.rmempty = false
    fallbackToLTE:depends("mode","auto")    
end

function check_schedule_time(cfg_start_time,cfg_end_time)
    local ymd_s=ut.exec("date +%Y-%m-%d")
    local now_t=tonumber(ut.exec("date +%s"))
    local starttime
    local endtime

    if cfg_start_time and #cfg_start_time > 0 then
        starttime=cfg_start_time..":00"
    else
        starttime="00:00:00"
    end
    local starttime_s=tonumber(ut.exec('date -d "'..ymd_s..' '..starttime..'" +%s'))
    if cfg_end_time and #cfg_end_time > 0 then
        endtime=cfg_end_time..":00"
    else
        endtime="00:00:00"
    end
    local endtime_s=tonumber(ut.exec('date -d "'..ymd_s..' '..endtime..'" +%s'))
    nixio.syslog("err","now_t:"..now_t)
    nixio.syslog("err","starttime_s:"..starttime_s)
    nixio.syslog("err","endtime_s:"..endtime_s)

    if starttime_s > endtime_s then
        if now_t < endtime_s then
            nixio.syslog("err","lock1")
            return true
        end
        endtime_s=endtime_s+86400
    end

    if now_t >= starttime_s and now_t < endtime_s then
        nixio.syslog("err","lock2")
        return true
    end
    nixio.syslog("err","unlock")
    return false
end
function freq_time_action(sim_id)
    local fs = require "nixio.fs"
    local freq_time = m.uci:get("cpecfg", cpe_section.."sim"..sim_id, "freq_time") or "0" 
    local starttime = m.uci:get("cpecfg", cpe_section.."sim"..sim_id, "starttime") or "23:30"
    local endtime = m.uci:get("cpecfg", cpe_section.."sim"..sim_id, "endtime") or "7:0"

    if fs.access("/var/state/cellular_freqtime") then
        if not fs.access("/etc/crontabs/") then
            ut.exec("mkdir -p /etc/crontabs/")
        end
        if not fs.access("/etc/crontabs/root") then
            ut.exec("touch /etc/crontabs/root")
        end
        -- ut.exec("sed -i '/"..cpe_section.." "..sim_id.."$/d' /etc/crontabs/root")
        ut.exec("sed -i '/cpetools.sh -l.*"..cpe_section.." "..sim_id.."$/d' /etc/crontabs/root")
        ut.exec("rm -fr /var/run/cpetools/"..cpe_section.."/"..sim_id)
        if freq_time == "1" then

            if check_schedule_time(starttime,endtime) then
                 ut.exec("cpetools.sh -l 1 -i "..cpe_section.." "..sim_id)
            else
                 ut.exec("cpetools.sh -l 0 -i "..cpe_section.." "..sim_id)
            end
            local starttime_arr = ut.split(starttime, ':')
            local endtime_arr = ut.split(endtime, ':')        
            ut.exec("sed -i '$a "..endtime_arr[2].." "..endtime_arr[1].." * * * cpetools.sh -l 0 -i "..cpe_section.." "..sim_id.."' /etc/crontabs/root")
            ut.exec("sed -i '$a "..starttime_arr[2].." "..starttime_arr[1].." * * * cpetools.sh -l 1 -i "..cpe_section.." "..sim_id.."' /etc/crontabs/root")
        end

        ut.exec("/etc/init.d/cron restart")
    end
end

local function expand_days(day)
    if not day then
        return {}
    end

    if day >= 1 and day <= 7 then
        return { day }
    elseif day == 8 then
        return { 1, 2, 3, 4, 5 }
    elseif day == 9 then
        return { 6, 7 }
    elseif day == 10 then
        return { 1, 2, 3, 4, 5, 6, 7 }
    else
        return {}
    end
end

function merge_peak_time(peak_time)
    local peak_time_arr = ut.split(peak_time, ';')
    local day_runtime = {}
    local day_flag= {}
    local day_list = {}

    local function add_day(d)
        if not day_flag[d] then
            day_flag[d] = true
            table.insert(day_list, d)
        end
    end

    for _, seg in ipairs(peak_time_arr) do
        if seg and #seg > 0 then
            local row = ut.split(seg, ',')
            if #row == 5 then
                local d  = tonumber(row[1])
                local sh = tonumber(row[2])
                local sm = tonumber(row[3])
                local eh = tonumber(row[4])
                local em = tonumber(row[5])
                if d and sh and sm and eh and em then
                    local start_time = sh * 60 + sm
                    local end_time = eh * 60 + em
                    if start_time < end_time then
                        local days = expand_days(d)
                        for _, day in ipairs(days) do
                            day_runtime[day] = day_runtime[day] or {}
                            table.insert(day_runtime[day], { s = start_time, e = end_time })
                            add_day(day)
                        end
                    end
                end
            end
        end
    end

    table.sort(day_list, function(a, b) return a < b end)

    local out = {}
    for _, d in ipairs(day_list) do
        local intervals = day_runtime[d]
        table.sort(intervals, function(x, y) return x.s < y.s end)
        local merged = {}
        for _, day in ipairs(intervals) do
            if #merged == 0 then
                table.insert(merged, { s = day.s, e = day.e })
            else
                local last = merged[#merged]
                if day.s <= last.e then
                    if day.e > last.e then
                        last.e = day.e
                    end
                else
                    table.insert(merged, { s = day.s, e = day.e })
                end
            end
        end

        for _, miv in ipairs(merged) do
            local sh = math.floor(miv.s / 60)
            local sm = miv.s % 60
            local eh = math.floor(miv.e / 60)
            local em = miv.e % 60
            table.insert(out, { d, sh, sm, eh, em })
        end
    end

    return out
end

function generate_cron_peak_time(merge_peaktime_arr, sim_id)
    local status = false
    for _, miv in ipairs(merge_peaktime_arr) do
        local day = miv[1]
        local sh = miv[2]
        local sm = miv[3]
        local eh = miv[4]
        local em = miv[5]

        -- ut.exec("echo " .. sm .. " " .. sh .. " * * " .. day  .. " cpetools.sh -L 1 -i " .. cpe_section .. " " .. sim_id .. "  >> /etc/crontabs/root" )
        -- ut.exec("echo " .. em .. " " .. eh .. " * * " .. day  .. " cpetools.sh -L 0 -i " .. cpe_section .. " " .. sim_id .. "  >> /etc/crontabs/root" )
        ut.exec("sed -i '$a "..sm.." "..sh.." * * " .. day .. " cpetools.sh -L 1 -i "..cpe_section.." "..sim_id.."' /etc/crontabs/root")
        ut.exec("sed -i '$a "..em.." "..eh.." * * " .. day .. " cpetools.sh -L 0 -i "..cpe_section.." "..sim_id.."' /etc/crontabs/root")

        local starttime = sh * 60 + sm
        local endtime = eh * 60 + em

        local ntp_day = tonumber(ut.exec("date +%u"))
        local ntp_time = tonumber(ut.exec("date +%H")) * 60 + tonumber(ut.exec("date +%M"))

        if day == ntp_day then
            if starttime <= ntp_time and ntp_time < endtime then
                status = true
            end
        end
    end

    if status then
        ut.exec("cpetools.sh -L 1 -i "..cpe_section.." "..sim_id)
    else
        ut.exec("cpetools.sh -L 0 -i "..cpe_section.." "..sim_id)
    end
end

function peak_time_action(sim_id)
    local fs = require "nixio.fs"
    local peak_hour = m.uci:get("cpecfg", cpe_section.."sim"..sim_id, "peak_hour") or "0"
    local peak_time = m.uci:get("cpecfg", cpe_section.."sim"..sim_id, "peaktime") or "5,18,0,20,30"

    if fs.access("/var/state/cellular_peaktime") then
        if not fs.access("/etc/crontabs/") then
            ut.exec("mkdir -p /etc/crontabs/")
        end
        if not fs.access("/etc/crontabs/root") then
            ut.exec("touch /etc/crontabs/root")
        end

        ut.exec("sed -i '/cpetools.sh -L.*"..cpe_section.." "..sim_id.."$/d' /etc/crontabs/root")
        ut.exec("rm -fr /var/run/cpetools/"..cpe_section.."/peakhour_"..sim_id)

        if peak_hour == "1" then
            local merge_peaktime_arr = merge_peak_time(peak_time)
            generate_cron_peak_time(merge_peaktime_arr, sim_id)
        end

        ut.exec("/etc/init.d/cron restart")
    end

end

function m.on_after_commit()
    if m:submitstate() then
        local cur_sim = m.uci:get("cpesel", "sim"..model_str, "cur") or "1"
        if sim_index == cur_sim then
            local simcfg_section = cpe_section.."sim"..cur_sim
            nr.app_write_cpecfg(cpe_section,cur_sim,simcfg_section)
            if nr.support_vsim(cpe_section) then
                os.execute("ubus call network.interface notify_proto \"{'interface':'"..cpe_section.."','action':5,'available':true}\"")
            end

            if plat == "quectel" and not nr.is_openwrt() then
                nr.fork_exec("/etc/init.d/network restart")
            else
                ut.exec("ifup "..cpe_section)
                if nr.support_dualdnn() then
                    ut.exec("ifup cpe1")
                end
            end
        end
        if support_nr then
            freq_time_action(sim_index)
            peak_time_action(sim_index)
        end
    end
end

return m
