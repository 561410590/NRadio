-- Copyright 2018 NRadio
-- Licensed to the public under the Apache License 2.0.

local ut = require "luci.util"
local uci = require "luci.model.uci"
local max
local nr = require "luci.nradio"
local count_cpe = nr.count_cpe()

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

local model_str,cpe_section,model_index = nr.get_cellular_last(arg[1])

local sim_section="sim"..model_str
local hidden_profile = luci.http.formvalue("profile") or nil
local profile_show = false
local max
local sim_change = 0
local threshold_change = 0
local vsim_change = 0
local mode_change = 0

local vsim_ignorecfg = tonumber(m.uci:get("cpesel", sim_section, "vsim_ignorecfg") or 0)
local nettype = uci:get("network",cpe_section,"nettype")
local disable_simauto = uci:get("luci","main","disable_simauto")
max = tonumber(m.uci:get("cpesel", sim_section, "max") or 1)

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

local function initcpeselrw(object,option)
    function object.cfgvalue(self, section)
        if option == "cur" then
            local vsim=m.uci:get("cpesel",sim_section, "vsim")
            if vsim == "1" then
                return "0"
            elseif vsim == "2" then
                return "00"
            end
        end
        return m.uci:get("cpesel",sim_section, option)
    end

    function object.write(self, section, value)
        if option == "cur" then
            old_cur = m.uci:get("cpesel",sim_section, option)
            old_vsim = m.uci:get("cpesel",sim_section, "vsim")
            if value == "0" then
                if old_vsim ~= "1" then
                    m.uci:set("cpesel",sim_section,"vsim","1")
                    vsim_change=1
                end
                return
            elseif value == "00" then
                if old_vsim ~= "2" then
                    m.uci:set("cpesel",sim_section,"vsim","2")
                    vsim_change=1
                end
                return
            else
                if old_vsim == "1" or old_vsim == "2" then
                    m.uci:delete("cpesel",sim_section,"vsim")
                    vsim_change=1
                end
            end
            if value ~= old_cur then
                sim_change = 1
            end
        elseif option == "mode" then
            old_mode = m.uci:get("cpesel",sim_section, option)

            if value ~= old_mode then
                mode_change = 1
            end
        elseif option == "signal" then
            old_mode = m.uci:get("cpesel",sim_section, option)

            if value ~= old_mode then
                mode_change = 1
            end
        end

        m.uci:set("cpesel",sim_section,option,value)
    end
end
local function initcpecfgrw(object,sim_index,option)
    function object.parse(self, section, novld)
        local fvalue = self:formvalue(section)
        local cvalue = self:cfgvalue(section)
        local cur_key = "cbid."..self.map.config.."."..section..".".."cur"
        local cur_data = luci.http.formvalue(cur_key) or "1"
        local cpesim_section= cpe_section.."sim"..cur_data

        if cvalue and (not fvalue or #fvalue == 0 ) then
            if self.option == option..cur_data then
                if option == "threshold_enabled" then
                    m:set(cpesim_section,option,"0")
                    threshold_change = 1
                end
            end
            return
        end
        
        return Value.parse(self, section, novld)
    end  
    function object.cfgvalue(self, section)
        local cpesim_section= cpe_section.."sim"..sim_index
        if option == "threshold_date_total" then
            local date_info = m.uci:get("cpecfg",cpesim_section, "threshold_date") or ""
            if not date_info:match(":") then
                return ""
            end
            return date_info
        end
        return m.uci:get("cpecfg",cpesim_section, option)
    end

    function object.write(self, section, value)
        local cur_key = "cbid."..self.map.config.."."..section..".".."cur"
        local cur_data = luci.http.formvalue(cur_key) or "1"
        local cpesim_section= cpe_section.."sim"..cur_data
        m:set(cpesim_section,nil,"cpesim")        
        local old_data = m.uci:get("cpecfg",cpesim_section, option)
        if option == "threshold_date_total" then
            old_data = m.uci:get("cpecfg",cpesim_section, "threshold_date")
            local threshold_type_key = "cbid."..self.map.config.."."..section..".".."threshold_type"..cur_data
            local threshold_type_data = luci.http.formvalue(threshold_type_key)
            if threshold_type_data == "1" then
                if old_data ~= value then
                    m.uci:set("cpecfg",cpesim_section,"threshold_date",value)
                    threshold_change = 1
                end
                return
            end
        elseif option == "threshold_cds" or option == "threshold_smds" then
            return
        end
        if old_data ~= value then
            threshold_change = 1
            m:set(cpesim_section,option,value)
        end        
    end
end
s = m:section(NamedSection, "config", "cpecfg")

local sims_alias = nr.get_sim_alias()

if max > 1 then
    if sims_alias then
        sims_alias=sims_alias[model_index]
    end

    if disable_simauto ~= "1" then
        local switch_help = translate("SwitchHelp")
        if not luci.nradio.support_self_speedlimit() then
            switch_help = translate("SwitchHelp2")
        end
        dail_mode = s:option(ListValue,"dail_mode", translate("Switch Mode"),switch_help)
        dail_mode:value(0, translate("Auto"))
        dail_mode:value(1, translate("Manual"))
        initcpeselrw(dail_mode,"mode")

    end

    cur = s:option(ListValue,
                   "cur",
                   translate("Slot Selection"))
    if nr.support_vsim(cpe_section) then
        cur:value("0",translate("vSIM Only"))
        if nettype == "cpe" then
            cur:value("00",translate("Physical SIM Piority"))
        end
    end

    for i = 1, max do
        cur:value(i,sims_alias[i])
    end
    if disable_simauto ~= "1" then
        cur:depends("dail_mode","1")
    end
    initcpeselrw(cur,"cur")

    if disable_simauto ~= "1" then
        cellular_simmenu=Template("nradio_cpecfg/cellular_simmenu")
        function cellular_simmenu.render(self)
            luci.template.render(self.template,{sim_position="hidden",sort_index=3})
        end
        s:append(cellular_simmenu)
    end

    if nr.support_sim_two_sided(sim_section) then
        two_sided_tmpt=Template("nradio_cpecfg/two_sided")
        function two_sided_tmpt.render(self)
            luci.template.render(self.template)
        end
        s:append(two_sided_tmpt)
    end
    cur_status = s:option(DummyValue,"cur_status",translate("SIM Status"),translate(" "))

    if disable_simauto ~= "1" then        
        adv = s:option(Flag, "adv_sim", translate("DefineFSIM"),"")
        adv.default = "0"
        adv:depends("dail_mode","0")

        initcpeselrw(adv,"adv_sim")
        function adv.remove(self, section)
            m.uci:delete("cpesel",sim_section, "adv_sim")
        end
    
        local sim_mode_depends_table = {}

        default_sim = s:option(ListValue,"default", translate("PreferredSIM"),translate("SIMDefaultHelp"))
        for i = 1, max do
            default_sim:value(i,sims_alias[i])
        end
        sim_mode_depends_table["adv_sim"] = "1"
        sim_mode_depends_table["dail_mode"] = "0"
        default_sim:depends(sim_mode_depends_table)
        initcpeselrw(default_sim,"default")
        if luci.nradio.support_self_speedlimit() then
            for i = 1, max do
                local sim_index = i
                local threshold_enabled_depends_table = {}
                threshold_enabled = s:option(Flag, "threshold_enabled"..sim_index, translate("Data Monitoring"),translate("*Auto-disconnect when data reaches monthly/total threshold or expiry to prevent overage charges."))
                threshold_enabled.default = "0"
                threshold_enabled_depends_table["dail_mode"] = "1"
                threshold_enabled_depends_table["cur"] = tostring(sim_index)
                threshold_enabled:depends(threshold_enabled_depends_table)
                initcpecfgrw(threshold_enabled,sim_index,"threshold_enabled")

                local threshold_type_depends_table = {}
                threshold_type = s:option(ListValue, "threshold_type"..sim_index, translate("Monitor Type"))        
                threshold_type:value("0", translate("Monthly"))
                threshold_type:value("1", translate("Total"))
                threshold_type.widget = "radio"
                threshold_type.direction = "horizontal"
                threshold_type.default = "0"
                threshold_type_depends_table["threshold_enabled"..sim_index] = "1"
                threshold_type_depends_table["dail_mode"] = "1"
                threshold_type_depends_table["cur"] = tostring(sim_index)
                threshold_type:depends(threshold_type_depends_table)
                initcpecfgrw(threshold_type,sim_index,"threshold_type")

                local threshold_date_depends_table = {}
                threshold_date_depends_table["threshold_type"..sim_index] = "0"
                threshold_date_depends_table["dail_mode"] = "1"
                threshold_date_depends_table["threshold_enabled"..sim_index] = "1"
                threshold_date_depends_table["cur"] = tostring(sim_index)
                threshold_date = s:option(ListValue,"threshold_date"..sim_index, translate("Start Date"))
                for i = 1, 28 do
                    threshold_date:value(i,i..translate("th"))
                end
                threshold_date:depends(threshold_date_depends_table)
                initcpecfgrw(threshold_date,sim_index,"threshold_date")

                local threshold_date_depends_table2 = {}
                threshold_date_depends_table2["threshold_type"..sim_index] = "1"
                threshold_date_depends_table2["dail_mode"] = "1"
                threshold_date_depends_table2["threshold_enabled"..sim_index] = "1"
                threshold_date_depends_table2["cur"] = tostring(sim_index)
                threshold_date_total = s:option(Value,"threshold_date_total"..sim_index, translate("End Date"))
                threshold_date_total.template = "nradio_cpecfg/pick_date"
                threshold_date_total:depends(threshold_date_depends_table2)
                initcpecfgrw(threshold_date_total,sim_index,"threshold_date_total")


                local threshold_data_depends_table = {}
                threshold_data_depends_table["threshold_enabled"..sim_index] = "1"
                threshold_data_depends_table["dail_mode"] = "1"
                threshold_data_depends_table["cur"] = tostring(sim_index)
                threshold_data = s:option(Value, "threshold_data"..sim_index, translate("Data Thresh.(GB)"))
                threshold_data.datatype = "uinteger"
                threshold_data.default = "0"
                threshold_data:depends(threshold_data_depends_table)
                initcpecfgrw(threshold_data,sim_index,"threshold_data")

                local threshold_percent_depends_table = {}
                threshold_percent_depends_table["threshold_enabled"..sim_index] = "1"
                threshold_percent_depends_table["dail_mode"] = "1"
                threshold_percent_depends_table["cur"] = tostring(sim_index)
                threshold_percent = s:option(Value, "threshold_percent"..sim_index, translate("Monitor(%)"))
                threshold_percent.datatype = "range(1,100)"
                threshold_percent.default = "100"
                threshold_percent:depends(threshold_percent_depends_table)
                initcpecfgrw(threshold_percent,sim_index,"threshold_percent")

                threshold_smds = s:option(DummyValue,"threshold_smds"..sim_index,translate("ThresholdMDataTitle"))
                local threshold_smds_depends_table = {}
                threshold_smds_depends_table["threshold_type"..sim_index] = "0"
                threshold_smds_depends_table["dail_mode"] = "1"
                threshold_smds_depends_table["threshold_enabled"..sim_index] = "1"
                threshold_smds_depends_table["cur"] = tostring(sim_index)
                threshold_smds:depends(threshold_smds_depends_table)
                initcpecfgrw(threshold_smds,sim_index,"threshold_smds")

                threshold_cds = s:option(DummyValue,"threshold_cds"..sim_index,translate("ThresholdTDataTitle"))
                local threshold_cds_depends_table = {}
                threshold_cds_depends_table["threshold_type"..sim_index] = "1"
                threshold_cds_depends_table["dail_mode"] = "1"
                threshold_cds_depends_table["threshold_enabled"..sim_index] = "1"
                threshold_cds_depends_table["cur"] = tostring(sim_index)
                threshold_cds:depends(threshold_cds_depends_table)
                initcpecfgrw(threshold_cds,sim_index,"threshold_cds")
            end
        end 

    end
else
    if nr.support_vsim(cpe_section) then
        cur = s:option(ListValue,
                       "cur",
                       translate("SIM Selection"))
        cur:value("0",translate("vSIM Only"))
        if nettype == "cpe" then
            cur:value("00",translate("Physical SIM Piority"))
        end
        cur:value(1,translate("Physical SIM Only"))
        initcpeselrw(cur,"cur")
    end
end

cellular_switch=Template("nradio_adv/cellular_switch")
function cellular_switch.render(self)
    luci.template.render(self.template,{model=cpe_section,sim_max=max})
end
m:append(cellular_switch)

function m.on_after_commit()
    local util = require "luci.util"
    if m:submitstate() then
        if threshold_change == 1 then
            util.exec("/etc/init.d/combo restart")
        end
        nr.switch_sim(sim_change,mode_change,vsim_change,cpe_section,"sim"..model_str)
    end
end

return m
