-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Licensed to the public under the Apache License 2.0.

local fs  = require "nixio.fs"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()
local testfullps = sys.exec("ps --help 2>&1 | grep BusyBox") --check which ps do we have
local psstring = (string.len(testfullps)>0) and  "ps w" or  "ps axfw" --set command we use to get pid

local function getPID(section)
	local pid = sys.exec("%s | grep -w '[o]penvpn(%s)'" % { psstring, section })
	if pid and #pid > 0 then
		return tonumber(pid:match("^%s*(%d+)"))
	end
	return nil
end

local instance_count = 0
local enabled_count = 0
local running_count = 0
local file_cfg_count = 0

uci:foreach("openvpn", "openvpn", function(section)
	instance_count = instance_count + 1
	if section.enabled == "1" then
		enabled_count = enabled_count + 1
	end
	if section.config then
		file_cfg_count = file_cfg_count + 1
	end
	local pid = getPID(section[".name"])
	if pid ~= nil and sys.process.signal(pid, 0) then
		running_count = running_count + 1
	end
end)

local m = Map("openvpn", translate("标准 OpenVPN"), translate("原生实例管理入口。适合新建模板实例、导入 ovpn 文件，或直接维护现有 OpenVPN 节点。"))
local intro = m:section(SimpleSection)
intro.template = "openvpn/overview_intro"
intro.instance_count = instance_count
intro.enabled_count = enabled_count
intro.running_count = running_count
intro.file_cfg_count = file_cfg_count
local s = m:section( TypedSection, "openvpn", translate("实例列表"), translate("这里展示当前已配置的 OpenVPN 实例及其运行状态。"))
s.template = "cbi/tblsection"
s.template_addremove = "openvpn/cbi-select-input-add"
s.addremove = true
s.add_select_options = { }

local cfg = s:option(DummyValue, "config", "配置来源")
function cfg.cfgvalue(self, section)
	local file_cfg = self.map:get(section, "config")
	if file_cfg then
		s.extedit = luci.dispatcher.build_url("admin", "services", "openvpn", "file", "%s")
	else
		s.extedit = luci.dispatcher.build_url("admin", "services", "openvpn", "basic", "%s")
	end
end

uci:load("openvpn_recipes")
uci:foreach( "openvpn_recipes", "openvpn_recipe",
	function(section)
		s.add_select_options[section['.name']] =
			section['_description'] or section['.name']
	end
)

function s.getPID(section) -- Universal function which returns valid pid # or nil
	return getPID(section)
end

function s.parse(self, section)
	local recipe = luci.http.formvalue(
		luci.cbi.CREATE_PREFIX .. self.config .. "." ..
		self.sectiontype .. ".select"
	)

	if recipe and not s.add_select_options[recipe] then
		self.invalid_cts = true
	else
		TypedSection.parse( self, section )
	end
end

function s.create(self, name)
	local recipe = luci.http.formvalue(
		luci.cbi.CREATE_PREFIX .. self.config .. "." ..
		self.sectiontype .. ".select"
	)
	local name = luci.http.formvalue(
		luci.cbi.CREATE_PREFIX .. self.config .. "." ..
		self.sectiontype .. ".text"
	)
	if #name > 3 and not name:match("[^a-zA-Z0-9_]") then
		local s = uci:section("openvpn", "openvpn", name)
		if s then
			local options = uci:get_all("openvpn_recipes", recipe)
			for k, v in pairs(options) do
				if k ~= "_role" and k ~= "_description" then
					if type(v) == "boolean" then
						v = v and "1" or "0"
					end
					uci:set("openvpn", name, k, v)
				end
			end
			uci:save("openvpn")
			uci:commit("openvpn")
			if extedit then
				luci.http.redirect( self.extedit:format(name) )
			end
		end
	elseif #name > 0 then
		self.invalid_cts = true
	end
	return 0
end

function s.remove(self, name)
	local cfg_file  = "/etc/openvpn/" ..name.. ".ovpn"
	local auth_file = "/etc/openvpn/" ..name.. ".auth"
	if fs.access(cfg_file) then
		fs.unlink(cfg_file)
	end
	if fs.access(auth_file) then
		fs.unlink(auth_file)
	end
	uci:delete("openvpn", name)
	uci:save("openvpn")
	uci:commit("openvpn")
end

s:option( Flag, "enabled", "启用" )

local active = s:option( DummyValue, "_active", "运行中" )
function active.cfgvalue(self, section)
	local pid = s.getPID(section)
	if pid ~= nil then
		return (sys.process.signal(pid, 0))
			and string.format("是 (%i)", pid)
			or  "否"
	end
	return "否"
end

local updown = s:option( Button, "_updown", "操作" )
updown._state = false
updown.redirect = luci.dispatcher.build_url(
	"admin", "services", "openvpn"
)
function updown.cbid(self, section)
	local pid = s.getPID(section)
	self._state = pid ~= nil and sys.process.signal(pid, 0)
	self.option = self._state and "stop" or "start"
	return AbstractValue.cbid(self, section)
end
function updown.cfgvalue(self, section)
	self.title = self._state and "停止" or "启动"
	self.inputstyle = self._state and "reset" or "reload"
end
function updown.write(self, section, value)
	if self.option == "stop" then
		sys.call("/etc/init.d/openvpn stop %s" % section)
	else
		sys.call("/etc/init.d/openvpn start %s" % section)
	end
	luci.http.redirect( self.redirect )
end

local port = s:option( DummyValue, "port", "端口" )
function port.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	if not val then
		local file_cfg = self.map:get(section, "config")
		if file_cfg  and fs.access(file_cfg) then
			val = sys.exec("awk '{if(match(tolower($1),/^port$/)&&match($2,/[0-9]+/)){cnt++;printf $2;exit}}END{if(cnt==0)printf \"-\"}' " ..file_cfg)
			if val == "-" then
				val = sys.exec("awk '{if(match(tolower($1),/^remote$/)&&match($3,/[0-9]+/)){cnt++;printf $3;exit}}END{if(cnt==0)printf \"-\"}' " ..file_cfg)
			end
		end
	end
	return val or "-"
end

local proto = s:option( DummyValue, "proto", "协议" )
function proto.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	if not val then
		local file_cfg = self.map:get(section, "config")
		if file_cfg and fs.access(file_cfg) then
			val = sys.exec("awk '{if(match(tolower($1),/^proto$/)&&match(tolower($2),/^udp[46]*$|^tcp[a-z46-]*$/)){cnt++;print tolower(substr($2,1,3));exit}}END{if(cnt==0)printf \"-\"}' " ..file_cfg)
			if val == "-" then
				val = sys.exec("awk '{if(match(tolower($1),/^remote$/)&&match(tolower($4),/^udp[46]*$|^tcp[a-z46-]*$/)){cnt++;print tolower(substr($4,1,3));exit}}END{if(cnt==0)printf \"-\"}' " ..file_cfg)
			end
		end
	end
	return val or "-"
end

function m.on_after_apply(self,map)
	sys.call('/etc/init.d/openvpn reload')
end

return m
