module("luci.controller.nradio_adv.guest", package.seeall)

function index()
	local MTK = 'ralink'
	local platform = luci.nradio.get_wifi_vendor()

	page = entry({"nradioadv", "wireless", "guest"}, cbi("nradio_adv/guest", {hideapplybtn = true, hidesavebtn = true, hideresetbtn = true}), _("Guest Wi-Fi"), 15, true)
	page.index = true
	if platform == MTK then
		page.show = luci.nradio.has_own_wlan() and luci.nradio.has_ptype("rt")
	end
	page.icon = 'user-friends'
end