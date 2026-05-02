-- Copyright 2018 NRadio
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.nradio_adv.security", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/firewall") then
		return
	end

	page = entry({"admin", "system", "security"}, cbi("nradio_adv/security"), _("Security"), 3, true)
	page.leaf = true
	page.icon = "lock"
end
