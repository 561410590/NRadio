-- Copyright 2017-2018 NRadio

local sys = require "luci.sys"
local nr = require "luci.nradio"
local fs = require "nixio.fs"

m = Map("network", "")
local lan_section = m.uci:get("network", "globals", "default_lan") or "lan"
ipv6_tmpt=Template("nradio_ipv6/template")
function ipv6_tmpt.render(self)
	luci.template.render(self.template,{model="lan"})
end
m:append(ipv6_tmpt)
m:chain("luci")
m:chain("dhcp")
s = m:section(NamedSection, lan_section, "interface")

if nr.support_ipv6() then	
	--ip6addr = s:option(Value, "ip6addr", translate("IPv6 address"))
	--ip6addr.datatype = "ip6addr"
	ipv6_ctl = m.uci:get("network","globals", "ipv6") or "0"
	ipv6_relay = m.uci:get("firewall","@defaults[0]", "ipv6_nat") or "1"
	if ipv6_ctl == "1" and ipv6_relay == "1" then
		dhcp_o = s:option(ListValue, "ra_management", translate("DHCPv6Setting"),"")
		dhcp_o:value("0", translate("SLAAC"))
		dhcp_o:value("1", translate("DHCPv6SLAAC"))
		dhcp_o:value("2", translate("DHCPV6"))
		dhcp_o.default = "1"
		function dhcp_o.write(self, section, value)
			m.uci:set("dhcp",lan_section,"dhcpv6","server")
			m.uci:set("dhcp",lan_section,"ra","server")
			m.uci:set("dhcp",lan_section,"ra_default","1")
			m.uci:set("dhcp",lan_section,"ra_management",value)
		end
		function dhcp_o.cfgvalue(self, section)
			return m.uci:get("dhcp",lan_section, "ra_management")
		end

		local ip6prefix = s:option(Value, "ip6prefix", translate("IPv6 routed prefix"),"")
		ip6prefix.datatype = "ip6addr"
		
		local ltime = s:option(Value, "leasetime", translate("DHCPv6lease"),translate("DHCPv6leaseHelp"))
		ltime.rmempty = true
		ltime.datatype = "and(uinteger,range(1, 2880))"
		
		function ltime.cfgvalue(self, section)
			local second = m.uci:get("dhcp",section, "leasetime") or 86400
			return tonumber(second) / 60
		end
		function ltime.write(self, section,value)
			local minu = value and tonumber(value) or 1440
			m.uci:set("dhcp",lan_section,"leasetime",tostring(minu*60))
		end
	end
	mtu6 = s:option(Value, "mtu6", translate("MTU Size"))
	mtu6.default = "1500"
	mtu6.placeholder = "1500"
	mtu6.datatype    = "range(1280,1500)"

	function mtu_deal(value)
		local uci  = require "luci.model.uci"
		local cur = uci.cursor()
		if not value or #value == 0 then			
			return
		end
		cur:foreach("network", "device",
			function(s)
				if s.name == "br-lan"  then
					m.uci:set("network",s[".name"],"mtu6",value)
				end
			end
		)
		m.uci:set("network",lan_section,"mtu6",value)
		os.execute("ip6tables -t mangle -N tcpmss_rule")
		os.execute("ip6tables -t mangle -F tcpmss_rule")
		os.execute("ip6tables -t mangle -D FORWARD -j tcpmss_rule")
		os.execute("ip6tables -t mangle -I FORWARD -j tcpmss_rule")
		os.execute("ip6tables -I tcpmss_rule -t mangle -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "..(value - 60));
		
		os.execute("sed -i '/ip6tables .*-j TCPMSS/d' /etc/firewall.user");		
		os.execute("echo \"ip6tables -I tcpmss_rule -t mangle -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "..(value - 60).."\" >> /etc/firewall.user");
		os.execute("sed -i '/net.ipv6.conf.all.mtu/d' /etc/sysctl.conf");
		os.execute("sed -i '$a net.ipv6.conf.all.mtu='"..value.." /etc/sysctl.conf");
		os.execute("sysctl -w -p /etc/sysctl.conf");
	end
    function mtu6.parse(self, section, novld)
        local fvalue = self:formvalue(section)
        local cvalue = self:cfgvalue(section)
        if cvalue and (not fvalue or #fvalue==0) then
            mtu_deal("1280")
			return
        end
        return Value.parse(self, section, novld)
    end
	function mtu6.write(self, section, value)
		mtu_deal(value)
		Value.write(self, section, value)
	end

	dns = s:option(DynamicList, "dns", translate("Announced DNS servers"))
	function dns.write(self, section, value)
		local t = { }

		if type(value) == "table" then
			local x
			for _, x in ipairs(value) do
				if x and #x > 0 then
					t[#t+1] = x
				end
			end
		else
			t = { value }
		end
	
		if self.cast == "string" then
			value = table.concat(t, " ")
		else
			value = t
		end
		if value and #value > 0 then
			return m.uci:set("dhcp",lan_section,"dns", value)
		else
			return m.uci:delete("dhcp",lan_section,"dns")
		end
	end
	function dns.cfgvalue(self, section)
		local value = m.uci:get("dhcp",lan_section,"dns")
			
		if type(value) == "string" then
			local x
			local t = { }
			for x in value:gmatch("%S+") and value:gmatch(":") do
				if #x > 0 then
					t[#t+1] = x
				end
			end
			value = t
		end
	
		return value
	end
end


function m.on_after_commit(map)
	if fs.access("/etc/config/mtkhnat") then
		sys.exec("/etc/init.d/mtkhnat restart")
	end
	if mwan3_change == 1 then
		if fs.access("/usr/sbin/mwan3") then
			sys.exec("mwan3 restart >/dev/null 2>&1")
		end
	end

	if auto_adapt_change == 1 then
		if fs.access("/etc/init.d/auto_adapt") then
			sys.exec("/etc/init.d/auto_adapt restart >/dev/null 2>&1")
		end
	end	
end

return m
