-- Copyright 2018 NRadio
-- Licensed to the public under the Apache License 2.0.

local ut = require "luci.util"
local uci = require "luci.model.uci"
local nr = require "luci.nradio"

local support_nr = false
local support_lock_freq = false
local support_earfcn4 = false
local support_earfcn5 = false
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
local band_data = 0
local earfreq_work_mode = uci:get("network",cpe_section,"earfreq_mode")
local nettype = uci:get("network",cpe_section,"nettype")

support_earfcn5 = uci:get("network",cpe_section,"earfcn5")
support_earfcn4 = uci:get("network",cpe_section,"earfcn4")
support_nr = nr.support_nr(cpe_section)
support_lock_freq = nr.support_lock_freq(cpe_section)

freq_val = uci:get("network",cpe_section,"freq_val")

m:chain("cpesel")
m:chain("wanchk")

cellular_scan_init=Template("nradio_cpecfg/cellular_scan_init")
function cellular_scan_init.render(self)
    luci.template.render(self.template,{cpe_section=cpe_section,sim_id=sim_index})
end
m:append(cellular_scan_init)

local function get_band_data(band_buffer)
    local band_result = {band5={},band4={}}
    local band5_buffer = ""
    local band4_buffer = ""
    if not band_buffer or #band_buffer == 0 then
        return band_result
    end
    local band_kind = ut.split(band_buffer, ",")
    for i=1,#band_kind do
        local band_item = ut.split(band_kind[i], "-")
        local band_kind = band_item[1]
        local band_value = band_item[2]

        if band_kind == "sa" or band_kind == "nsa" or band_kind == "nr" then
            if #band5_buffer > 0 then
                band5_buffer = band5_buffer..":"..band_value
            else
                band5_buffer = band_value
            end
        end
        if band_kind == "lte" then
            if #band4_buffer > 0 then
                band4_buffer = band4_buffer..":"..band_value
            else
                band4_buffer = band_value
            end
        end
    end
    local band5_array = ut.split(band5_buffer, ":")
    local band4_array = ut.split(band4_buffer, ":")

    local band5_tmp={}
    for key,val in pairs(band5_array) do
        band5_tmp[tostring(val)]=true
    end

    for key,val in pairs(band5_tmp) do
       table.insert(band_result.band5,key)
    end

    if #band_result.band5 > 0 then
        table.sort(band_result.band5, function(a, b) return tonumber(a) < tonumber(b) end)
    end

    local band4_tmp={}
    for key,val in pairs(band4_array) do
        band4_tmp[tostring(val)]=true
    end
    for key,val in pairs(band4_tmp) do
        table.insert(band_result.band4,key)
     end

     if #band_result.band4 > 0 then
        table.sort(band_result.band4, function(a, b) return tonumber(a) < tonumber(b) end)
     end

     return band_result
end
band_data = get_band_data(freq_val)
local function initrw(object,option,depends_extra_buffer,depends_reverse)
    local depends_table = {}
    local form_cur_sim = sim_index

    if option == "custom_earfcn5" then
        depends_table["earfreq_mode"] = "earfcn5"
        if earfreq_work_mode ~= "one" then
            depends_table["earfreq_mode"] = ""
        end
    elseif option == "custom_earfcn4"then
        depends_table["earfreq_mode"] = "earfcn4"
        if earfreq_work_mode ~= "one" then
            depends_table["earfreq_mode"] = ""
        end
    elseif option == "custom_freq" then
        depends_table["earfreq_mode"] = "band"
    end

    depends_extra = ut.split(depends_extra_buffer or "", " ")
    depends_max = #depends_extra
    for i = 1, depends_max do
        if depends_extra[i] and #depends_extra[i] > 0 then
            depends_table[depends_extra[i]] = "1"            
        end
    end
    depends_extra = ut.split(depends_reverse or "", " ")
    depends_max = #depends_extra
    for i = 1, depends_max do
        if depends_extra[i] and #depends_extra[i] > 0 then            
            depends_table[depends_extra[i]] = not "1"            
        end
    end

    object:depends(depends_table)
    function object.parse(self, section, novld)
        local fvalue = self:formvalue(section)
        local cvalue = self:cfgvalue(section)

        local custom_earfcn5_key = "cbid."..self.map.config.."."..section..".".."custom_earfcn5"
        local custom_earfcn5_data = luci.http.formvalue(custom_earfcn5_key)
        local custom_earfcn4_key = "cbid."..self.map.config.."."..section..".".."custom_earfcn4"
        local custom_earfcn4_data = luci.http.formvalue(custom_earfcn4_key)
        local earfreq_mode_key = "cbid."..self.map.config.."."..section..".".."earfreq_mode"
        local earfreq_mode_data = luci.http.formvalue(earfreq_mode_key)
        if cvalue and (not fvalue or #fvalue == 0 ) then
            if self.option == option then
                if (option == "custom_freq" or option == "freq") and (earfreq_mode_data ~= "band") then
                    m:del(cpesim_section,option)
                end
                if option == "earfreq_mode" then
                    m:del(cpesim_section,option)
                    return
                end
                if custom_earfcn5_data ~= "1" then
                    if option == "custom_earfcn5" or option == "band5" or option == "earfcn5" or option == "pci5" or option == "earfcn5_mode" then
                        m:del(cpesim_section,option)
                        return
                    end
                end
                if custom_earfcn4_data ~= "1" then
                    if option == "custom_earfcn4" or option == "band4" or option == "earfcn4" or option == "pci4" or option == "earfcn4_mode" then
                        m:del(cpesim_section,option)
                        return
                    end
                end
            end
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

local band_support=0
local pci_support=0
local work_mode=0
local earfreq_mode_default=""
local support_mobility = uci:get("network",cpe_section,"mobility")
local mobile_lock = uci:get("luci","main","mobile_lock")

if support_mobility == "1" and mobile_lock ~="1" then
    mobility = s:option(ListValue, "mobility", translate("Band Lock Policy"),translate("*If the device is moved after frequency lock, changes in the local base station environment may cause the lock to become ineffective. If \"Reselection & Handover Allowed\" is enabled, the device will automatically release the lock to maintain connectivity."))
    mobility.default = "1"
    mobility:value("1",translate("Reselection & Handover Allowed"))
    mobility:value("0",translate("Reselection & Handover Forbidden"))        
end

earfreq_mode = s:option(ListValue, "earfreq_mode", translate("LockType"))
if support_lock_freq then 
    earfreq_mode:value("band", translate("LockBandType"))
end

if earfreq_work_mode == "one" then
    if support_lock_freq then
        earfreq_mode_default="band"
    end
    if support_earfcn4 then
        earfreq_mode_default="earfcn4"
        earfreq_mode:value("earfcn4", translate("LTELockCellType"))
    end

    if support_earfcn5 then
        earfreq_mode_default="earfcn5"
        earfreq_mode:value("earfcn5", translate("NRLockCellType"))
    end
else
    if support_earfcn5 or support_earfcn4 then
        earfreq_mode:value("", translate("LockCellType"))
    end
end
earfreq_mode.widget = "radio"
earfreq_mode.direction = "horizontal"
earfreq_mode.default = earfreq_mode_default
initrw(earfreq_mode,'earfreq_mode')

if support_lock_freq then
    freq_cus = s:option(ListValue, "custom_freq", translate("Band Mode"))
    freq_cus:value("0", translate("Auto"))
    freq_cus:value("1", translate("Manual"))
    freq_cus.default = "0"
    initrw(freq_cus,"custom_freq")

    freq = s:option(Value, "freq", translate("Band Select"),translate("*Manual band selection may prevent network registration. Use with caution."))
    freq.template = "cbi/dlvalue"
    freq.cpe_section= cpe_section
    initrw(freq,"freq","custom_freq")
end
if support_earfcn5 then
    custom_earfcn5 = s:option(Flag, "custom_earfcn5", translate("NRLockCellType"),
    translate("*Manual lock may prevent network registration. Use with caution"))
    custom_earfcn5.default = "0"
    initrw(custom_earfcn5,'custom_earfcn5')

    earfcn5_mode = s:option(ListValue, "earfcn5_mode", translate("FreqLockType"))
    earfcn5_mode:value("0", translate("FreqLockScan"))
    earfcn5_mode:value("1", translate("FreqLockManual"))
    earfcn5_mode.template = "nradio_cpecfg/earfcn_scan_value"
    earfcn5_mode.scan_type = 5    
    earfcn5_mode.cpe_section = cpe_section
    earfcn5_mode.default = "0"
    initrw(earfcn5_mode,"earfcn5_mode","custom_earfcn5")

    earfcn5_scan = s:option(DummyValue,"earfcn5_scan",translate(""))
    earfcn5_scan.template = "nradio_cpecfg/earfcn_value"
    earfcn5_scan.scan_type = 5
    earfcn5_scan.sort_index = 7
    earfcn5_scan.cpe_section = cpe_section
    initrw(earfcn5_scan,"earfcn5_scan","custom_earfcn5","earfcn5_mode")

    earfcn5_setting_array = ut.split(support_earfcn5, ",")
    band_support = earfcn5_setting_array[1] or 0
    pci_support = earfcn5_setting_array[2] or 0
    work_mode = earfcn5_setting_array[3] or 0
    work_mode = tonumber(work_mode) or 0
    band_support = tonumber(band_support)
    pci_support = tonumber(pci_support)

    earfcn5 = s:option(Value, "earfcn5", translate("5G Earfcn"),translate("Please enter an integer between [0-875000]"))
    earfcn5.datatype = "range(0,875000)"
    earfcn5.rmempty = false
    initrw(earfcn5,"earfcn5","custom_earfcn5 earfcn5_mode")

    if pci_support == 1 then
        pci5 = s:option(Value, "pci5", translate("5G PCI"),translate("Please enter an integer between [0-1007]"))
        pci5.datatype = "range(0,1007)"
        if work_mode == 0 or work_mode == 1 then
            pci5.rmempty = false
        end
        initrw(pci5,"pci5","custom_earfcn5 earfcn5_mode")
    end
    local band5
    if band_support == 1 then
        if band_data.band5 and #band_data.band5 > 0 then
            band5 = s:option( ListValue, "band5", translate("5G BAND"))
            if work_mode == 5 then
                band5:value("", translate("(empty)"))
            end
            for x=1,#band_data.band5 do
                band5:value(band_data.band5[x], translate(band_data.band5[x]))
            end
        else
            band5 = s:option(Value, "band5", translate("5G BAND"),translate("Please enter an integer between [0-100]"))
            band5.datatype = "range(0,261)"
            if work_mode == 0 or work_mode == 1 or work_mode == 2 then
                band5.rmempty = false
            end
        end
        initrw(band5,"band5","custom_earfcn5 earfcn5_mode")
    end
end

if support_earfcn4 then
    custom_earfcn4 = s:option(Flag, "custom_earfcn4", translate("LTELockCellType"),
    translate("*Manual lock may prevent network registration. Use with caution"))
    custom_earfcn4.default = "0"
    initrw(custom_earfcn4,'custom_earfcn4')
    earfcn4_setting_array = ut.split(support_earfcn4, ",")
    band_support = earfcn4_setting_array[1] or 0
    pci_support = earfcn4_setting_array[2] or 0
    work_mode = earfcn4_setting_array[3] or 0
    work_mode = tonumber(work_mode) or 0
    band_support = tonumber(band_support)
    pci_support = tonumber(pci_support)

    earfcn4_mode = s:option(ListValue, "earfcn4_mode", translate("FreqLockType"))
    earfcn4_mode:value("0", translate("FreqLockScan"))
    earfcn4_mode:value("1", translate("FreqLockManual"))
    earfcn4_mode.template = "nradio_cpecfg/earfcn_scan_value"
    earfcn4_mode.scan_type = 4
    earfcn4_mode.cpe_section = cpe_section
    earfcn4_mode.default = "0"
    initrw(earfcn4_mode,"earfcn4_mode","custom_earfcn4")

    earfcn4_scan = s:option(DummyValue,"earfcn4_scan",translate(""))
    earfcn4_scan.template = "nradio_cpecfg/earfcn_value"
    earfcn4_scan.scan_type = 4
    earfcn4_scan.cpe_section = cpe_section
    initrw(earfcn4_scan,"earfcn4_scan","custom_earfcn4","earfcn4_mode")

    earfcn4 = s:option(Value, "earfcn4", translate("4G Earfcn"),translate("Please enter an integer between [0-875000]"))
    earfcn4.datatype = "range(0,875000)"
    earfcn4.rmempty = false
    initrw(earfcn4,"earfcn4","custom_earfcn4 earfcn4_mode")

    if pci_support == 1 then
        pci4 = s:option(Value, "pci4", translate("4G PCI"),translate("Please enter an integer between [0-503]"))
        pci4.datatype = "range(0,503)"
        if work_mode == 0 or work_mode == 1 then
            pci4.rmempty = false
        end
        initrw(pci4,"pci4","custom_earfcn4 earfcn4_mode")
    end

    local band4
    if band_support == 1 then
        if band_data.band4 and #band_data.band4 > 0 then
            band4 = s:option( ListValue, "band4", translate("4G BAND"))
            for x=1,#band_data.band4 do
                band4:value(band_data.band4[x], translate(band_data.band4[x]))
            end
        else
            band4 = s:option(Value, "band4", translate("4G BAND"),translate("Please enter an integer between [0-100]"))
            band4.datatype = "range(0,261)"
            if work_mode == 0 or work_mode == 1 or work_mode == 2 then
                band4.rmempty = false
            end
        end
        initrw(band4,"band4","custom_earfcn4 earfcn4_mode")
    end
end

function m.on_after_commit()
    if m:submitstate() then
        local cur_sim = m.uci:get("cpesel", "sim"..model_str, "cur") or "1"
        if support_nr then
        end
        if sim_index == cur_sim then
            local simcfg_section = cpe_section.."sim"..cur_sim
            nr.app_write_earfcn(cpe_section,cur_sim,simcfg_section)
            nr.app_write_cpecfg(cpe_section,cur_sim,simcfg_section)
            nr.set_n79_relate(cpe_section)
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
    end
end

return m
