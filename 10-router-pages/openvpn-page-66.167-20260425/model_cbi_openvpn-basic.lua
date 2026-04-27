-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Licensed to the public under the Apache License 2.0.

local fs = require("nixio.fs")

local _translate = translate
local zh = {
	["Allow client-to-client traffic"] = "允许客户端之间互访",
	["Certificate authority"] = "CA 证书",
	["Change process priority"] = "调整进程优先级",
	["Configure client mode"] = "配置客户端模式",
	["Configure server bridge"] = "配置服务端桥接",
	["Configure server mode"] = "配置服务端模式",
	["Diffie-Hellman parameters"] = "Diffie-Hellman 参数",
	["Do not bind to local address and port"] = "不绑定本地地址和端口",
	["Enable Static Key encryption mode (non-TLS)"] = "启用静态密钥加密模式（非 TLS）",
	["Helper directive to simplify the expression of --ping and --ping-restart in server mode configurations"] = "用于简化服务端模式下 --ping 与 --ping-restart 的辅助指令",
	["Local certificate"] = "本地证书",
	["Local private key"] = "本地私钥",
	["PKCS#12 file containing keys"] = "包含密钥的 PKCS#12 文件",
	["Remote host name or IP address"] = "远端主机名或 IP 地址",
	["Set output verbosity"] = "设置输出详细级别",
	["Set tun/tap adapter parameters"] = "设置 tun/tap 适配器参数",
	["TCP/UDP port # for both local and remote"] = "本地与远端共用的 TCP/UDP 端口",
	["The key direction for 'tls-auth' and 'secret' options"] = "tls-auth 与 secret 选项的密钥方向",
	["Type of used device"] = "设备类型",
	["Use fast LZO compression"] = "使用快速 LZO 压缩",
	["Use protocol"] = "使用协议"
}

local function translate(text)
	return zh[text] or _translate(text)
end

local value_labels = {
	[""] = "-- 更多选项 --",
	["-- remove --"] = "-- 移除此项 --",
	["yes"] = "是",
	["no"] = "否",
	["adaptive"] = "自适应",
	["udp"] = "UDP",
	["udp6"] = "UDP IPv6",
	["tcp-client"] = "TCP 客户端",
	["tcp-server"] = "TCP 服务端",
	["tcp6-client"] = "TCP IPv6 客户端",
	["tcp6-server"] = "TCP IPv6 服务端",
	["tun"] = "TUN 三层隧道",
	["tap"] = "TAP 二层桥接",
	["0"] = "0",
	["1"] = "1"
}

local function option_title(option)
	return option[4] or option[2]
end

local function option_desc(option)
	return "OpenVPN 指令: " .. tostring(option[2])
end

local function option_value_label(v)
	v = tostring(v)
	return value_labels[v] or v
end

local basicParams = {
	--
	-- Widget, Name, Default(s), Description
	--
	{ ListValue,
		"verb",
		{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
		translate("Set output verbosity") },
	{ Value,
		"nice",
		0,
		translate("Change process priority") },
	{ Value,
		"port",
		1194,
		translate("TCP/UDP port # for both local and remote") },
	{ ListValue,
		"dev_type",
		{ "tun", "tap" },
		translate("Type of used device") },
	{ Value,
		"ifconfig",
		"10.200.200.3 10.200.200.1",
		translate("Set tun/tap adapter parameters") },
	{ Value,
		"server",
		"10.200.200.0 255.255.255.0",
		translate("Configure server mode") },
	{ Value,
		"server_bridge",
		"192.168.1.1 255.255.255.0 192.168.1.128 192.168.1.254",
		translate("Configure server bridge") },
	{ Flag,
		"nobind",
		0,
		translate("Do not bind to local address and port") },
	{ ListValue,
		"comp_lzo",
		{"yes","no","adaptive"},
		translate("Use fast LZO compression") },
	{ Value,
		"keepalive",
		"10 60",
		translate("Helper directive to simplify the expression of --ping and --ping-restart in server mode configurations") },
	{ Flag,
		"client",
		0,
		translate("Configure client mode") },
	{ Flag,
		"client_to_client",
		0,
		translate("Allow client-to-client traffic") },
	{ DynamicList,
		"remote",
		"vpnserver.example.org",
		translate("Remote host name or IP address") },
	{ FileUpload,
		"secret",
		"/etc/openvpn/secret.key",
		translate("Enable Static Key encryption mode (non-TLS)") },
	{ ListValue,
		"key_direction",
		{ 0, 1 },
		translate("The key direction for 'tls-auth' and 'secret' options") },
	{ FileUpload,
		"pkcs12",
		"/etc/easy-rsa/keys/some-client.pk12",
		translate("PKCS#12 file containing keys") },
	{ FileUpload,
		"ca",
		"/etc/easy-rsa/keys/ca.crt",
		translate("Certificate authority") },
	{ FileUpload,
		"dh",
		"/etc/easy-rsa/keys/dh1024.pem",
		translate("Diffie-Hellman parameters") },
	{ FileUpload,
		"cert",
		"/etc/easy-rsa/keys/some-client.crt",
		translate("Local certificate") },
	{ FileUpload,
		"key",
		"/etc/easy-rsa/keys/some-client.key",
		translate("Local private key") },
}

local has_ipv6 = fs.access("/proc/net/ipv6_route")
if has_ipv6 then
	table.insert( basicParams, { ListValue,
		"proto",
		{ "udp", "tcp-client", "tcp-server", "udp6", "tcp6-client", "tcp6-server" },
		translate("Use protocol")
	})
else
	table.insert( basicParams, { ListValue,
		"proto",
		{ "udp", "tcp-client", "tcp-server" },
		translate("Use protocol")
	})
end

local m = Map("openvpn")
m.redirect = luci.dispatcher.build_url("admin", "services", "openvpn")
m.apply_on_parse = true

local p = m:section( SimpleSection )
p.template = "openvpn/pageswitch"
p.mode     = "basic"
p.instance = arg[1]


local s = m:section( NamedSection, arg[1], "openvpn" )
s.template = "openvpn/nsection"

for _, option in ipairs(basicParams) do
	local o = s:option(
		option[1], option[2],
		option_title(option), option_desc(option)
	)
	o.title = option_title(option)
	o.description = option_desc(option)

	o.optional = true

	if option[1] == DummyValue then
		o.value = option[3]
	elseif option[1] == FileUpload then

		o.initial_directory = "/etc/openvpn"

		function o.cfgvalue(self, section)
			local cfg_val = AbstractValue.cfgvalue(self, section)

			if cfg_val then
				return cfg_val
			end
		end

		function o.formvalue(self, section)
			local sel_val = AbstractValue.formvalue(self, section)
			local txt_val = luci.http.formvalue("cbid."..self.map.config.."."..section.."."..self.option..".textbox")

			if sel_val and sel_val ~= "" then
				return sel_val
			end

			if txt_val and txt_val ~= "" then
				return txt_val
			end
		end

		function o.remove(self, section)
			local cfg_val = AbstractValue.cfgvalue(self, section)
			local txt_val = luci.http.formvalue("cbid."..self.map.config.."."..section.."."..self.option..".textbox")
			
			if cfg_val and fs.access(cfg_val) and txt_val == "" then
				fs.unlink(cfg_val)
			end
			return AbstractValue.remove(self, section)
		end
	elseif option[1] == Flag then
		o.default = nil
	else
		if option[1] == DynamicList then
			function o.cfgvalue(...)
				local val = AbstractValue.cfgvalue(...)
				return ( val and type(val) ~= "table" ) and { val } or val
			end
		end

		if type(option[3]) == "table" then
			if o.optional then o:value("", option_value_label("-- remove --")) end
			for _, v in ipairs(option[3]) do
				v = tostring(v)
				o:value(v, option_value_label(v))
			end
			o.default = tostring(option[3][1])
		else
			o.default = tostring(option[3])
		end
	end

	for i=5,#option do
		if type(option[i]) == "table" then
			o:depends(option[i])
		end
	end
end

return m
