module("luci.controller.nradio_adv.terminal-limit", package.seeall)

function index()
	if not pcall(require, "luci.nradio") then
		return
	end
	if not luci.nradio.has_nat() then		
		return 
	end
	
	if not luci.nradio.support_self_speedlimit() then		
		return 
	end 
	page = entry({"nradioadv", "network", "terminal-limit"}, cbi("nradio_adv/terminal-limit"), _("QoS"), 45, true)
	page.icon = 'nradio-terminal-limit'
	page.show = true
end
