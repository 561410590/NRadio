module("luci.controller.nradio_adv.forwarding", package.seeall)

function index()
	if not nixio.fs.access("/usr/sbin/iptables") then
		return
	end

	page = entry({"nradioadv", "network", "forwarding"}, cbi("nradio_adv/forwarding"), _("Port Fwd"), 40, true)
	page.icon = 'nradio-portfwd'
	page.show = true
end
