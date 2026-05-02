module("luci.controller.nradio_adv.mcast", package.seeall)

function index()
	if not pcall(require, "luci.nradio") then
		return
	end

	if luci.nradio.has_ptype("ac") then
		return
	end

	if not luci.nradio.has_own_wlan() then
		return
	end

	page = entry({"nradioadv", "wireless", "mcast"}, cbi("nradio_adv/mcast", {hideapplybtn = true, hidesavebtn = true, hideresetbtn = true}), _("Wireless Multicast"), 55, true)
	page.icon = 'microphone'
	page.show = true
end
