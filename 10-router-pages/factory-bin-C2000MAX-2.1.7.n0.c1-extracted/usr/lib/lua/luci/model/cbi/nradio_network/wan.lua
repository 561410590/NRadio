-- Copyright 2017-2018 NRadio

local util = require "luci.util"
local sys = require "luci.sys"
local nr = require "luci.nradio"
local fs = require "nixio.fs"
local mwan3_exist = false
m = Map("network", translate("WAN Setting"))

if fs.access("/usr/sbin/mwan3") then
	m:chain("mwan3")
	mwan3_exist = true
end
if fs.access("/etc/config/auto_adapt") then
	m:chain("auto_adapt")
end
if fs.access("/etc/config/cloudd") then
	m:chain("cloudd")
end
local overlap_dividing = m.uci:get("luci","main", "overlap_dividing")
local cur_active_wan = m.uci:get("network","globals", "active_wan")
local proto, username, password, ipaddr, netmask, gateway, peerdns, dns, mtu, mac, protov
local mwan3_change = false
local net_type_change = 0
local auto_adapt_change = 0
local net_type = nr.get_network_type()
local count_cpe = nr.count_cpe()
local exsit_cellular = false
local exsit_nbcpe = false
local cellular_count = 0
local nbcpe_count = 0
local wired_data = nr.get_nettype_data("Wired")
local cellular_prefix,cellular_default = nr.get_cellular_prefix()

local nbcpe_only_lng = ""

s = m:section(NamedSection, "wan", "interface")

function depends_wired(obj)
	if nr.has_cpe() then
		for i = 1,#wired_data do
			obj:depends({backup=wired_data[i]})
		end
	end
end

for i = 0, count_cpe - 1 do
	local iface = (i == 0 and cellular_default or cellular_prefix..i)
	local iface_odu_mode = m.uci:get("network",iface, "mode") or ""
	if iface_odu_mode == "odu" then
		exsit_nbcpe = true
		nbcpe_count = nbcpe_count + 1
	else
		exsit_cellular = true
		cellular_count = cellular_count + 1
	end
end

if exsit_nbcpe and not exsit_cellular then
	nbcpe_only_lng = translate("NBCPEOnly")
	nbcpe_only_notice_lng = translate("NBCPEOnlyNotice1")
	wired_nbcpe_priority_lng = translate("WiredNBCPEPriority1")	
	wired_nbcpe_cellular_priority_lng = translate("WiredNBCPECellularPriority1")
	wired_cellular_nbcpe_priority_lng = translate("WiredCellularNBCPEPriority1")
	nbcpe_cellular_priority_lng = translate("NBCPECellularPriority1")
	cellular_nbcpe_priority_lng = translate("CellularNBCPEPriority1")
	wired_nbcpe_cellular_dividing_lng = translate("WiredNBCPECellularDividing1")	
	nbcpe_cellular_dividing_lng = translate("NBCPECellularDividing1")
	wired_nbcpe_dividing_lng = translate("WiredNBCPEDividing1")
	wired_nbcpe_overlap_notice_lng = translate("WiredNBCPEOverlapNotice1")
	nbcpe_cellular_overlap_notice_lng = translate("NBCPECellularOverlapNotice1")
	wired_nbcpe_cellular_overlap_notice_lng = translate("WiredNBCPECellularOverlapNotice1")
	wired_nbcpe_priority_notice_lng = translate("WiredNBCPEPriorityNotice1")
	wired_nbcpe_cellular_priority_notice_lng = translate("WiredNBCPECellularPriorityNotice1")
	wired_cellular_nbcpe_priority_notice_lng = translate("WiredCellularNBCPEPriorityNotice1")
	nbcpe_cellular_priority_notice_lng = translate("NBCPECellularPriorityNotice1")
	cellular_nbcpe_priority_notice_lng = translate("CellularNBCPEPriorityNotice1")
	wired_nbcpe_cellular_dividing_notice_lng = translate("WiredNBCPECellularDividingNotice1")
	nbcpe_cellular_dividing_notice_lng = translate("NBCPECellularDividingNotice1")
	dividing_nbcpe_lng = translate("DividingNBCPE1")
	dividing_nbcpe_help_lng = translate("DividingClientHelp1")
	dividing_nbcpe_protocol_help_lng = translate("DividingProtocolHelp1")
else
	nbcpe_only_lng = translate("CellularNBCPEOnly")
	nbcpe_only_notice_lng = translate("NBCPEOnlyNotice")
	wired_nbcpe_priority_lng = translate("WiredNBCPEPriority")
	wired_nbcpe_cellular_priority_lng = translate("WiredNBCPECellularPriority")	
	wired_cellular_nbcpe_priority_lng = translate("WiredCellularNBCPEPriority")	
	nbcpe_cellular_priority_lng = translate("NBCPECellularPriority")
	cellular_nbcpe_priority_lng = translate("CellularNBCPEPriority")
	wired_nbcpe_cellular_dividing_lng = translate("WiredNBCPECellularDividing")
	nbcpe_cellular_dividing_lng = translate("NBCPECellularDividing")
	wired_nbcpe_dividing_lng = translate("WiredNBCPEDividing")
	wired_nbcpe_overlap_notice_lng = translate("WiredNBCPEOverlapNotice")
	nbcpe_cellular_overlap_notice_lng = translate("NBCPECellularOverlapNotice")
	wired_nbcpe_cellular_overlap_notice_lng = translate("WiredNBCPECellularOverlapNotice")
	wired_nbcpe_priority_notice_lng = translate("WiredNBCPEPriorityNotice")
	wired_nbcpe_cellular_priority_notice_lng = translate("WiredNBCPECellularPriorityNotice")
	wired_cellular_nbcpe_priority_notice_lng = translate("WiredCellularNBCPEPriorityNotice")
	wired_nbcpe_cellular_dividing_notice_lng = translate("WiredNBCPECellularDividingNotice")
	nbcpe_cellular_dividing_notice_lng = translate("NBCPECellularDividingNotice")
	nbcpe_cellular_priority_notice_lng = translate("NBCPECellularPriorityNotice")
	cellular_nbcpe_priority_notice_lng = translate("CellularNBCPEPriorityNotice")
	dividing_nbcpe_lng = translate("DividingNBCPE")
	dividing_nbcpe_help_lng = translate("DividingClientHelp")
	dividing_nbcpe_protocol_help_lng = translate("DividingProtocolHelp")
end
local function extrrw(object, option)
    function object.cfgvalue(self, section)
        return m.uci:get("network","globals", option)
    end

    function object.write(self, section, value)
		local cur_data = m.uci:get("network","globals", option)
		if  cur_data ~= value then
			m.uci:set("network","globals",option,value)
			if option == "dividing_default" or option == "dividing" then
				nixio.syslog("err","mwan3_change 1")
				mwan3_change = true
			end
		end		
    end

	function object.parse(self, section, novld)
		local fvalue = self:formvalue(section)
		local cvalue = self:cfgvalue(section)
		if option == "dividing_default" or option == "dividing" then
			local cur_data = m.uci:get("network","globals", option)
			if not fvalue or (#fvalue == 0) then
				if cur_data and #cur_data > 0 then
					m.uci:delete("network","globals",option)
					nixio.syslog("err","mwan3_change 2")
					mwan3_change = true
				end
				return
			end
		elseif option == "nbcpe" or option == "active_wan" then
			local cur_data = m.uci:get("network","globals", option)
			if not fvalue or (#fvalue == 0) then
				if cur_data and #cur_data > 0 then
					m.uci:delete("network","globals",option)
				end
				return
			end
		end
		return Value.parse(self, section, novld)
	end
end
if nr.has_cpe() then
	if exsit_nbcpe and exsit_cellular then
		nbcpe = s:option(Flag, "nbcpe",translate("UsedNBCPE"),translate("NBCPEHelpCtl"))
		nbcpe.default = "0"
		extrrw(nbcpe,"nbcpe")
	end

	active_wan = s:option(Flag, "active_wan",translate("WANLabel"),translate("WANHelpCtl"))
	active_wan.default = "0"
	extrrw(active_wan,"active_wan")

	backup = s:option(ListValue,
		"backup",
		translate("NetPriority"))
	backup.default = "0"


	for i = 0, cellular_count - 1 do
		local suffix = ""
		if cellular_count ~= 1 then
			suffix=tostring(i+1)
		end
		backup:value(net_type["CellularOnly"..suffix], translate("CellularOnly")..suffix,{nbcpe="0",active_wan="0"},{nbcpe="0",active_wan=(not "1")},{nbcpe=(not "1"),active_wan="0"},{nbcpe=(not "1"),active_wan=(not "1")})
	end

	for i = 0, nbcpe_count - 1 do
		local suffix = ""
		if nbcpe_count ~= 1 then
			suffix=tostring(i+1)
		end
		if not exsit_cellular then
			backup:value(net_type["NBCPEOnly"], nbcpe_only_lng..suffix,{active_wan=(not "1")})
		else
			backup:value(net_type["NBCPEOnly"], nbcpe_only_lng..suffix,{nbcpe="1",active_wan=(not "1")})
		end
	end
	
	backup:value(net_type["WiredOnly"], translate("WiredOnly"),{nbcpe="0",active_wan="1"},{nbcpe=(not "1"),active_wan="1"})
	if exsit_cellular then
		backup:value(net_type["WiredCellularPriority"], translate("WiredCellularPriority"),{nbcpe="0",active_wan="1"},{nbcpe=(not "1"),active_wan="1"})
		
		if mwan3_exist and overlap_dividing ~= "0" then
			backup:value(net_type["WiredCellularDividing"], translate("WiredCellularDividing"),{nbcpe="0",active_wan="1"},{nbcpe=(not "1"),active_wan="1"})
			backup:value(net_type["WiredCellularOverlap"], translate("WiredCellularOverlap"),{nbcpe="0",active_wan="1"},{nbcpe=(not "1"),active_wan="1"})
		end
	end

	if exsit_nbcpe then		
		if exsit_cellular then			
			backup:value(net_type["NBCPECellularPriority"], nbcpe_cellular_priority_lng,{nbcpe="1",active_wan="0"},{nbcpe="1",active_wan=(not "1")})
			backup:value(net_type["CellularNBCPEPriority"], cellular_nbcpe_priority_lng,{nbcpe="1",active_wan="0"},{nbcpe="1",active_wan=(not "1")})
			backup:value(net_type["WiredNBCPECellularPriority"], wired_nbcpe_cellular_priority_lng,{nbcpe="1",active_wan="1"})
			backup:value(net_type["WiredCellularNBCPEPriority"], wired_cellular_nbcpe_priority_lng,{nbcpe="1",active_wan="1"})
			if mwan3_exist and overlap_dividing ~= "0" then
				backup:value(net_type["WiredNBCPECellularDividing"], wired_nbcpe_cellular_dividing_lng,{nbcpe="1",active_wan="1"})
				backup:value(net_type["WiredNBCPECellularOverlap"], translate("WiredNBCPECellularOverlap"),{nbcpe="1",active_wan="1"})
				backup:value(net_type["NBCPECellularDividing"], nbcpe_cellular_dividing_lng,{nbcpe="1",active_wan="0"},{nbcpe="1",active_wan=(not "1")})
				backup:value(net_type["NBCPECellularOverlap"], translate("NBCPECellularOverlap"),{nbcpe="1",active_wan="0"},{nbcpe="1",active_wan=(not "1")})
			end
		else			
			backup:value(net_type["WiredNBCPEPriority"], wired_nbcpe_priority_lng,{active_wan="1"})
			if mwan3_exist and overlap_dividing ~= "0" then
				backup:value(net_type["WiredNBCPEDividing"], wired_nbcpe_dividing_lng,{active_wan="1"})
				backup:value(net_type["WiredNBCPEOverlap"], translate("WiredNBCPEOverlap"),{active_wan="1"})
			end
		end
	end

	function backup.cfgvalue(self, section)
		local net_prefer_cfg = self.map:get("globals", "net_prefer")
		local cellular_only = self.map:get("nrswitch", "disable_wan") or "0"
		local net_prefer
		
		if cellular_only == "1" then
			if count_cpe > 1 then
				net_prefer = net_type["CellularPriority1"]
			else
				net_prefer = net_type["CellularOnly"]
			end
		else
			if count_cpe > 1 then
				net_prefer = net_type["WiredCellularPriority1"]
			else
				net_prefer = net_type["WiredCellularPriority"]
			end
		end

		net_prefer_cfg = self.map:get("globals", "net_prefer")
		if net_prefer_cfg and #net_prefer_cfg > 0 then
			net_prefer = net_prefer_cfg
		end
		return net_prefer
	end
	function backup.write(self, section, value)
		local old_prefer=self.map:get("globals", "net_prefer") or ""
		local tmp_cellular_count = 0
		self.map:set("globals", "net_prefer",value)
		
		if not nr.match_wired_nettype(value) then
			self.map:set("nrswitch", "disable_wan", "1")
		else
			self.map:set("nrswitch", "disable_wan", "0")
		end
		local nbcpe_form_data = luci.http.formvalue("cbid.network.wan.nbcpe")

		local cellular_flag,nettype_name = nr.match_cellular_nettype(value)
		local overlap = nr.match_overlap(value)
		local priority = nr.match_cellular_priority(value)
		local metric_max = count_cpe + 1
		for i = 0, count_cpe - 1 do
			local iface = (i == 0 and cellular_default or cellular_prefix..i)
			local iface_odu_mode = m.uci:get("network",iface, "mode") or ""
			local cur_metric = metric_max-i
			if mwan3_exist then
				local old_metric = m.uci:get("mwan3", iface.."_4_policy", "metric")
				if overlap then
					if old_metric ~= "1" then
						m.uci:set("mwan3", iface.."_4_policy", "metric","1")
						nixio.syslog("err","mwan3_change 3")
						mwan3_change = true
					end
				else
					if priority then

						if nettype_name == "WiredCellularNBCPEPriority" or nettype_name == "CellularNBCPEPriority" then
							if iface_odu_mode == "odu" then
								cur_metric = cur_metric + 10
							end
						end
					end
					if old_metric ~= tostring(cur_metric) then
						m.uci:set("mwan3", iface.."_4_policy", "metric",tostring(cur_metric))
						nixio.syslog("err","mwan3_change 4")
						mwan3_change = true
					end
				end
				local old_metric = m.uci:get("mwan3", iface.."_6_policy", "metric")
				if overlap then
					if old_metric ~= "1" then
						m.uci:set("mwan3", iface.."_6_policy", "metric","1")
						nixio.syslog("err","mwan3_change 3")
						mwan3_change = true
					end
				else
					if priority then
						if nettype_name == "WiredCellularNBCPEPriority" or nettype_name == "CellularNBCPEPriority" then
							if iface_odu_mode == "odu" then
								cur_metric = cur_metric + 10
							end
						end
					end
					if old_metric ~= tostring(cur_metric) then
						m.uci:set("mwan3", iface.."_6_policy", "metric",tostring(cur_metric))
						nixio.syslog("err","mwan3_change 4")
						mwan3_change = true
					end
				end
			end

			if cellular_flag then
				if (nettype_name == "CellularOnly1" or nettype_name == "CellularOnly2") and iface_odu_mode ~= "odu" then
					tmp_cellular_count = tmp_cellular_count+1
					if (tmp_cellular_count == 1 and nettype_name == "CellularOnly1") or (tmp_cellular_count == 2 and nettype_name == "CellularOnly2") then
						self.map:del(iface, "disabled")
					else
						self.map:set(iface, "disabled", "1")
					end
				else
					if (nettype_name:match("Cellular") and iface_odu_mode ~= "odu") 
						or (nettype_name:match("NBCPE") and iface_odu_mode == "odu") then						
						self.map:del(iface, "disabled")
					else
						self.map:set(iface, "disabled", "1")
					end
				end
			else
				self.map:set(iface, "disabled", "1")
			end
		end

		local autowan = m.uci:get("luci", "module", "auto") or 1
		if tonumber(autowan) ~= 0 then
			if fs.access("/etc/config/auto_adapt") then
				if value == "1" then
					m.uci:set("auto_adapt", "mode","en", "0")
				else
					m.uci:set("auto_adapt", "mode","en", "1")
				end
				auto_adapt_change=1
			end
		end
		if old_prefer ~= value then
			net_type_change=1
		end
	end

	wired_des = s:option(DummyValue,"wired_des"," ",translate("WiredNotice"))
	wired_des:depends("backup",net_type["WiredOnly"]) 
	
	if exsit_cellular then
		cellular_des = s:option(DummyValue,"cellular_des"," ",translate("CellularNotice"))
		cellular_des:depends("backup",net_type["CellularOnly"])
	
		wiredcellular_des = s:option(DummyValue,"wiredcellular_des"," ",translate("WiredCellularPriorityNotice"))
		wiredcellular_des:depends("backup",net_type["WiredCellularPriority"]) 
	
		wiredcellular_dividing_des = s:option(DummyValue,"wiredcellular_dividing_des"," ",translate("WiredCellularDividingNotice"))
		wiredcellular_dividing_des:depends("backup",net_type["WiredCellularDividing"]) 
	
		wiredcellular_overlap_des = s:option(DummyValue,"wiredcellular_overlap_des"," ",translate("WiredCellularOverlapNotice"))
		wiredcellular_overlap_des:depends("backup",net_type["WiredCellularOverlap"]) 
	end
	
	if exsit_nbcpe then
		nbcpe_des = s:option(DummyValue,"nbcpe_des"," ",nbcpe_only_notice_lng)
		nbcpe_des:depends("backup",net_type["NBCPEOnly"]) 
	
		wired_nbcpe_des = s:option(DummyValue,"wired_nbcpe_des"," ",wired_nbcpe_priority_notice_lng)
		wired_nbcpe_des:depends("backup",net_type["WiredNBCPEPriority"]) 
	
		wired_nbcpecellular_des = s:option(DummyValue,"wired_nbcpecellular_des"," ",wired_nbcpe_cellular_priority_notice_lng)
		wired_nbcpecellular_des:depends("backup",net_type["WiredNBCPECellularPriority"]) 

		wired_cellularnbcpe_des = s:option(DummyValue,"wired_cellularnbcpe_des"," ",wired_cellular_nbcpe_priority_notice_lng)
		wired_cellularnbcpe_des:depends("backup",net_type["WiredCellularNBCPEPriority"]) 

		wired_nbcpecellular_dividing_des = s:option(DummyValue,"wired_nbcpecellular_dividing_des"," ",wired_nbcpe_cellular_dividing_notice_lng)
		wired_nbcpecellular_dividing_des:depends("backup",net_type["WiredNBCPECellularDividing"]) 
		wired_nbcpe_overlap_des = s:option(DummyValue,"wired_nbcpe_overlap_des"," ",wired_nbcpe_overlap_notice_lng)
		wired_nbcpe_overlap_des:depends("backup",net_type["WiredNBCPEOverlap"]) 

		wired_nbcpecellular_overlap_des = s:option(DummyValue,"wired_nbcpecellular_overlap_des"," ",translate("WiredNBCPECellularOverlapNotice"))
		wired_nbcpecellular_overlap_des:depends("backup",net_type["WiredNBCPECellularOverlap"]) 

		nbcpecellular_dividing_des = s:option(DummyValue,"nbcpecellular_dividing_des"," ",nbcpe_cellular_dividing_notice_lng)
		nbcpecellular_dividing_des:depends("backup",net_type["NBCPECellularDividing"]) 
		nbcpecellular_overlap_des = s:option(DummyValue,"nbcpecellular_overlap_des"," ",nbcpe_cellular_overlap_notice_lng)
		nbcpecellular_overlap_des:depends("backup",net_type["NBCPECellularOverlap"]) 
		nbcpecellular_des = s:option(DummyValue,"nbcpecellular_des"," ",nbcpe_cellular_priority_notice_lng)
		nbcpecellular_des:depends("backup",net_type["NBCPECellularPriority"])

		cellularnbcpe_des = s:option(DummyValue,"cellularnbcpe_des"," ",cellular_nbcpe_priority_notice_lng)
		cellularnbcpe_des:depends("backup",net_type["CellularNBCPEPriority"]) 
	end

	
	des_tmpt=Template("nradio_network/wan")
	function des_tmpt.render(self)
		luci.template.render(self.template)
	end
	s:append(des_tmpt)
	
	if nr.has_cpe() then
		if mwan3_exist and overlap_dividing ~= "0" then
			overlap_balance = s:option(Value, "overlap_balance", translate("OverlapBalance"), translate("OverlapBalanceHelp"))
			overlap_balance.template = "nradio_network/balance_value"
			overlap_balance:depends("backup",net_type["WiredCellularOverlap"]) 
			overlap_balance:depends("backup",net_type["WiredNBCPECellularOverlap"]) 
			overlap_balance:depends("backup",net_type["WiredNBCPEOverlap"]) 
			overlap_balance:depends("backup",net_type["NBCPECellularOverlap"])
			function overlap_balance.cfgvalue(self, section)
				local weight_policy = ""
				local wan_policy = m.uci:get("mwan3","wan_policy", "weight") or "1"
				weight_policy = "wan:"..wan_policy
				for i = 0, count_cpe - 1 do
					local iface = (i == 0 and cellular_default or cellular_prefix..i)
					local cpe_policy = m.uci:get("mwan3",iface.."_4_policy", "weight") or "1"
					weight_policy = weight_policy.."-"..iface..":"..cpe_policy
				end

				return weight_policy
			end

			function overlap_balance.write(self, section, value)
				local balance_array = util.split(value, "-")
				for i=1,#balance_array do
					local balance_item = util.split(balance_array[i], ":")
					local balance_iface = balance_item[1]
					local balance_weight = balance_item[2]
					if not balance_weight or #balance_weight == 0 then
						balance_weight="1"
					end
					
					if balance_iface == "wan" then
						local weight_policy = m.uci:get("mwan3",balance_iface.."_policy", "weight") or "0"
						local weight1_policy = m.uci:get("mwan3",balance_iface.."6_policy", "weight") or "0"
						if weight_policy ~= balance_weight then
							m.uci:set("mwan3",balance_iface.."_policy", "weight",balance_weight)
							mwan3_change = true
						end
						if weight1_policy ~= balance_weight then
							m.uci:set("mwan3",balance_iface.."6_policy", "weight",balance_weight)
							mwan3_change = true
						end
					else
						local weight_policy = m.uci:get("mwan3",balance_iface.."_4_policy", "weight") or "0"
						local weight1_policy = m.uci:get("mwan3",balance_iface.."6_policy", "weight") or "0"
						if weight_policy ~= balance_weight then
							m.uci:set("mwan3",balance_iface.."_4_policy", "weight",balance_weight)
							mwan3_change = true
						end
						if weight1_policy ~= balance_weight then
							m.uci:set("mwan3",balance_iface.."_6_policy", "weight",balance_weight)
							mwan3_change = true
						end
					end
				end
			end
		end
		dividing = s:option(ListValue, "dividing", translate("DividingMode"))
		dividing.default = "client"
		dividing.rmempty = true
		dividing:value("client", translate("ClientDividing"))
		dividing:value("protocol", translate("ProtocolDividing"))
		dividing:depends("backup",net_type["WiredNBCPEDividing"])
		dividing:depends("backup",net_type["WiredNBCPECellularDividing"])
		dividing:depends("backup",net_type["WiredCellularDividing"])
		dividing:depends("backup",net_type["NBCPECellularDividing"])
		extrrw(dividing,"dividing")
		dividing_default = s:option(ListValue, "dividing_default",translate("DividingDefault"))
		dividing_default.widget = "radio"
		dividing_default.direction = "horizontal"
		dividing_default.default = "wan"
		dividing_default.rmempty = true
		dividing_default:depends("backup",net_type["WiredNBCPEDividing"])
		dividing_default:depends("backup",net_type["WiredNBCPECellularDividing"])
		dividing_default:depends("backup",net_type["NBCPECellularDividing"])
		dividing_default:depends("backup",net_type["WiredCellularDividing"])

		dividing_default:value("wan", translate("DividingWired"),{active_wan="1"})
		local tmp_nbcpe_count = 0
		local tmp_cellular_count = 0
		for i = 0, count_cpe - 1 do
			local iface = (i == 0 and cellular_default or cellular_prefix..i)
			local iface_odu_mode = m.uci:get("network",iface, "mode") or ""
			local suffix = ""
			if iface_odu_mode == "odu" then
				suffix = (tmp_nbcpe_count == 0 and "" or tostring(i+1))
				tmp_nbcpe_count = tmp_nbcpe_count + 1
				dividing_default:value(iface, dividing_nbcpe_lng..suffix,{nbcpe="1"})
				if cur_active_wan ~= "1" then
					dividing_default.default = iface
				end
			else
				suffix = (tmp_cellular_count == 0 and "" or tostring(i+1))
				tmp_cellular_count = tmp_cellular_count + 1
				dividing_default:value(iface, translate("DividingCellular")..suffix)
			end
		end		

		extrrw(dividing_default,"dividing_default")
		dividing_client_des = s:option(DummyValue,"dividing_client_des"," ",dividing_nbcpe_help_lng)
		dividing_client_des:depends("dividing","client") 
	
		dividing_protocol_des = s:option(DummyValue,"dividing_protocol_des"," ",dividing_nbcpe_protocol_help_lng)
		dividing_protocol_des:depends("dividing","protocol")
	end
	
end
function tplparse(object, depend)
	object.rmempty = false
	object:depends("proto", depend)
	function object.parse(self, section, novld)
		local fvalue = self:formvalue(section)
		local cvalue = self:cfgvalue(section)
		if not fvalue and protov ~= depend then
			self:remove(section)
			return
		end
		return Value.parse(self, section, novld)
	end
end

proto = s:option(ListValue, "proto", translate("WiredType"))
depends_wired(proto)
proto.default = "dhcp"
proto:value("pppoe", translate("PPPoE"))
proto:value("dhcp", translate("DHCP Client"))
proto:value("static", translate("Static IP"))

function proto.write(self, section, value)
	protov = value
	return Value.write(self, section, value)
end

username = s:option(Value, "username", translate("Username"))
username.datatype = "minlength(1)"
tplparse(username, "pppoe")

password = s:option(Value, "password", translate("Password"))
password.password = true
password.datatype = "minlength(1)"
tplparse(password, "pppoe")

ipaddr = s:option(Value, "ipaddr", translate("IPv4 Address"))
ipaddr.datatype = "ip4addr"
tplparse(ipaddr, "static")

netmask = s:option(Value, "netmask",translate("IPv4 Netmask"))
netmask.default = "255.255.255.0"
netmask.datatype = "netmask"
netmask:value("255.255.255.0")
netmask:value("255.255.0.0")
netmask:value("255.0.0.0")
netmask:depends({proto="static"})
tplparse(netmask, "static")

gateway = s:option(Value, "gateway", translate("IPv4 Gateway"))
gateway.datatype = "ip4addr"
tplparse(gateway, "static")

mtu = s:option(Value, "mtu", translate("MTU Size"))
depends_wired(mtu)
mtu.placeholder = "1500"
mtu.datatype    = "range(576,1500)"

mac = s:option(Value, "macaddr", translate("MAC Clone"))
depends_wired(mac)
mac.placeholder = "00:11:22:33:44:55"
mac.datatype = "macaddr"

peerdns = s:option(Flag, "peerdns",
	translate("Use Default DNS"))

peerdns.default = peerdns.enabled
peerdns:depends("proto","dhcp")
peerdns:depends("proto","pppoe")

dns = s:option(DynamicList, "dns", translate("DNS Server"))

dns:depends({proto="pppoe", peerdns=""})
dns:depends({proto="dhcp", peerdns=""})
dns:depends({proto="static", peerdns=""})
dns.datatype = "ip4addr"
dns.cast     = "string"

function m.on_after_commit(map)
	local ipv6_open = m.uci:get("network","globals", "ipv6")
	local support_nat = nr.support_ipv6_nat()
	local support_relay = nr.support_ipv6_relay()
	local relay_on = m.uci:get("firewall","@defaults[0]", "ipv6_nat")
	if ipv6_open == "1" then
		ipv6_open = true
	else
		ipv6_open = false
	end

	if not support_nat or (relay_on == "0" and ipv6_open) then
		nr.ip6class_set(false,true)				
	else
		nr.ip6class_set(true,true)	
	end	
	
	if fs.access("/etc/config/mtkhnat") then
		sys.exec("/etc/init.d/mtkhnat restart")
	end
	if mwan3_change then
		if mwan3_exist then
			nixio.syslog("err","mwan3_change restart")
			sys.exec("access_ctl.sh -r 2 >/dev/null 2>&1")
			sys.exec("mwan3 restart >/dev/null 2>&1")
		end
	end

	if auto_adapt_change == 1 then
		if fs.access("/etc/init.d/auto_adapt") then
			sys.exec("/etc/init.d/auto_adapt restart >/dev/null 2>&1")
		end
	end

	if net_type_change == 1 then
		nr.kpcpectl_sync()
		util.exec("/etc/init.d/wanswd restart >/dev/null 2>&1")
		util.exec("/etc/init.d/atserver-sniffer restart >/dev/null 2>&1")
		util.exec("/etc/init.d/atsd restart >/dev/null 2>&1")
		util.exec("killall -9 cellular_init >/dev/null 2>&1")
		util.exec("/etc/init.d/cellular_init restart >/dev/null 2>&1")
		util.exec("/etc/init.d/cpesel restart >/dev/null 2>&1")
		sys.exec("/etc/init.d/odhcpd restart >/dev/null 2>&1")
		util.exec("/etc/init.d/terminal_trackd restart >/dev/null 2>&1")
	end
end

return m
