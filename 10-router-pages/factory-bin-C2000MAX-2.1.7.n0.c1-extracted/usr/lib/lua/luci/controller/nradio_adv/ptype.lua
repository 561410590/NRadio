-- Copyright 2018 NRadio
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.nradio_adv.ptype", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/oem") then
		return
	end

	if not nixio.fs.access("/usr/sbin/iptables") then
		return
	end

	if not pcall(require, "luci.nradio") then
		return
	end

	if not luci.nradio.has_ptype("ap", "rt") then
		return
	end

	page = entry({"nradioadv", "system", "ptype"}, cbi("nradio_adv/ptype", {hideapplybtn = true, hidesavebtn = true, hideresetbtn = true}), _("Product Type"), 99, true)
	page.icon = "map-signs"
	page.show = true
end