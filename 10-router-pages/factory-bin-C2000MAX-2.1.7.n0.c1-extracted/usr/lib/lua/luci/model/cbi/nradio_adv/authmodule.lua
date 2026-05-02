-- Copyright 2017-2018 NRadio

m = Map("authmodule", translate("Auth Module"))

s = m:section(NamedSection, "config", "rule")
enable = s:option(Flag, "cellular_dial", translate("Active Cellular Dial"))
enable.default = "0"
enable.rmempty = false

function ctrl_cellular(ctrl)
    local uci  = require "luci.model.uci"
	local uci = uci.cursor()
    local cellular_prefix,cellular_default = luci.nradio.get_cellular_prefix()
    uci:foreach("network", "interface",
        function(s)            
            if s.proto == "wwan" or s.proto == "tdmi" then
                if s['mode'] == "odu" and s[".name"] ~= cellular_default and ctrl == 0 then
                    return
                end
                uci:set("network",s[".name"],"disabled",ctrl)
            end
        end
    )
    uci:commit("network")    
end
function enable.write(self, section, value)
	if value == "1" then
		ctrl_cellular(0)
	else
		ctrl_cellular(1)
	end
    return Value.write(self, section, value)
end

function m.on_after_commit(map)
    os.execute("/etc/init.d/network reload >/dev/null 2>&1")
end

return m
