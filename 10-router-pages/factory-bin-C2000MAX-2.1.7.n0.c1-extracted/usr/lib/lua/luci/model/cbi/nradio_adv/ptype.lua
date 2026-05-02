-- Copyright 2018 NRadio
-- Licensed to the public under the Apache License 2.0.

m = Map("oem", translate("Product Type"))

s = m:section(NamedSection, "board", "system")

ptype = s:option(ListValue, "ptype", translate("Product Type"))
ptype:value("rt", translate("Router"))
ptype:value("ap", translate("AP"))
ptype.default = "ap"

function ptype.write(self, section, value)
	os.execute("/etc/ptype.d/init " .. value .. " reinit >/dev/null 2>&1")
	luci.http.redirect(luci.dispatcher.build_url("nradioadv/system/restart") .. "?auto=1")

	return Value.write(self, section, value)
end

m:append(Template("nradio_adv/ptype"))

return m
