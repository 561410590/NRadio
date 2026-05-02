-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2008 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.nradio_adv.upnp", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/upnpd") then
		return
	end
	if not luci.nradio.has_nat() then		
		return 
	end
	local page

	page = entry({"nradioadv", "network", "upnp"}, cbi("nradio_adv/upnp"), _("UPnP"), 80, true)
	page.dependent = true
	page.show = true
	page.icon = 'nradio-upnp'
	entry({"nradioadv", "network", "upnp", "status"}, call("act_status"), nil, nil, true).leaf = true
	entry({"nradioadv", "network", "upnp", "delete"}, post("act_delete"), nil, nil, true).leaf = true
end

function act_status()
	local util = require "luci.util"
	local leases = {}	
	local leasefile = io.open(uci.get('upnpd', 'config', 'upnp_lease_file'), 'r')

	if leasefile then
		while true do
			local line = leasefile:read("*l")
			if not line then
				break
			else 
				local record = util.split(line, ':', 6);
				if record and #record == 6 then
					local item = {
							proto   = record[1]:upper(),
							extport = record[2],
							intaddr = record[3],
							intport = record[4],
							expires = record[5],
							description=record[6]
					}
					if item.proto and item.extport and item.intaddr and item.intport then
						item.extport = tonumber(item.extport)
						item.intport = tonumber(item.intport)
						if item.expires then
							item.expires = os.difftime(tonumber(item.expires), os.time())
						end
						leases[#leases+1] = item
					end
				end
			end
		end
		leasefile:close()
	end
	local ipt = io.popen("iptables --line-numbers -t nat -xnvL MINIUPNPD 2>/dev/null")
	if ipt then
		local fwd = { }
		while true do
			local ln = ipt:read("*l")
			if not ln then
				break
			elseif ln:match("^%d+") then
				local num, proto, extport, intaddr, intport =
					ln:match("^(%d+).-([a-z]+).-dpt:(%d+) to:(%S-):(%d+)")
				local rule = {
						num     = num,
						proto   = proto:upper(),
						extport = extport,
						intaddr = intaddr,
						intport = intport
				}
				if rule.num and rule.proto and rule.extport and rule.intaddr and rule.intport then
					rule.num     = tonumber(rule.num)
					rule.extport = tonumber(rule.extport)
					rule.intport = tonumber(rule.intport)
					for _,item in pairs(leases) do
						if rule.proto == item.proto and
						    rule.intaddr == item.intaddr and
						    rule.intport == item.intport and
						    rule.extport == item.extport then
						
							rule.descr = item.description;
							rule.expires = item.expires;
							break
						end
					end
					fwd[#fwd+1] = rule
				end
			end
		end

		ipt:close()

		luci.http.prepare_content("application/json")
		luci.http.write_json(fwd)
	end
end

function act_delete(num)
	local idx = tonumber(num)
	local uci = luci.model.uci.cursor()

	if idx and idx > 0 then
		luci.sys.call("iptables -t filter -D MINIUPNPD %d 2>/dev/null" % idx)
		luci.sys.call("iptables -t nat -D MINIUPNPD %d 2>/dev/null" % idx)

		local lease_file = uci:get("upnpd", "config", "upnp_lease_file")
		if lease_file and nixio.fs.access(lease_file) then
			luci.sys.call("sed -i -e '%dd' %q" %{ idx, lease_file })
		end

		luci.http.status(200, "OK")
		return
	end

	luci.http.status(400, "Bad request")
end
