-- Copyright 2017 NRadio

module("luci.controller.nradio.index", package.seeall)

function index()
	local nr = require "luci.nradio"
	local uci = luci.model.uci.cursor()
	local root = node()
	local media = uci:get('luci', 'main', 'mediaurlbase')
	local first = uci:get("luci", "main", "first") or "1"

	if not root.target or media == "/luci-static/nradio" then
		-- Set as default page under theme
		root.target = alias("nradio")
		root.index = true
	end

	local page   = node("nradio")
	page.target  = firstchild()
	page.title   = _("nradio")
	page.order   = 10

	if tonumber(first) == 0 then
		page.sysauth = "root"
		page.sysauth_authenticator = "htmlauth"
	end

	page.ucidata = true
	page.index = true

	local path = uci:get("luci", "custom", "NRadio")
	if path then
		local paths = luci.util.split(path, "/")
		local i = 1
		while paths[i] == "" do
			i = i+1
		end

		-- link to custom url specified by uci
		entry({"nradio", "custom"},
			alias(paths[i], paths[i+1], paths[i+2]),
			node(paths[i], paths[i+1], paths[i+2]).title,
			40, true)
	end

	page = entry({"nradio", "system"}, call("action_skip"), _("System Status"), 10, true)
	page.show = true
	page.icon = 'globe'
	page = entry({"nradio", "basic"}, call("action_skip"), _("Basic"), 20, true)
	page.show = true
	page.icon = 'cog'
	page = entry({"nradio", "logout"}, call("action_logout"), _("Logout"), 99, true)
	page.show = true
	page.icon = 'power-off'
	page = entry({"admin", "ac"}, firstchild(), _("AC Services"), 15, true)
	page.index = true
	page = entry({"nradio", "professional"}, call("action_professional"),nil, 99, true)
	page.show = false
	page = entry({"nradio", "simple"}, call("action_simple"),nil, 99, true)
	page.show = false
end

function action_skip()
	luci.http.redirect(luci.dispatcher.build_url("nradio"))
end

function action_logout()
	local dsp = require "luci.dispatcher"
	local utl = require "luci.util"
	local sid = dsp.context.authsession

	if sid then
		utl.ubus("session", "destroy", { ubus_rpc_session = sid })

		luci.http.header("Set-Cookie", "sysauth=%s; expires=%s; path=%s/" %{
			sid, 'Thu, 01 Jan 1970 01:00:00 GMT', dsp.build_url()
		})
	end

	luci.http.redirect(dsp.build_url())
end

function action_professional()
	local dsp = require "luci.dispatcher"
	local utl = require "luci.util"
	local sid = dsp.context.authsession

	if sid then
		utl.ubus("session", "set", { ubus_rpc_session = sid ,values = {luci_channel=""}})

		luci.http.header("Set-Cookie", "sysauth=%s; expires=%s; path=%s/" %{
			sid, 'Thu, 01 Jan 1970 01:00:00 GMT', dsp.build_url()
		})
	end

	luci.http.redirect(dsp.build_url())
end

function action_simple()
	local dsp = require "luci.dispatcher"
	local utl = require "luci.util"
	local sid = dsp.context.authsession

	if sid then
		utl.ubus("session", "set", { ubus_rpc_session = sid ,values = {luci_channel="simple"}})

		luci.http.header("Set-Cookie", "sysauth=%s; expires=%s; path=%s/" %{
			sid, 'Thu, 01 Jan 1970 01:00:00 GMT', dsp.build_url()
		})
	end

	luci.http.redirect(dsp.build_url())
end
