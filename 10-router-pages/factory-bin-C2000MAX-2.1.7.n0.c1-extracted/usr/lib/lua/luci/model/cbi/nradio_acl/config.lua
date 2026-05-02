-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Licensed to the public under the Apache License 2.0.
local pairs = pairs

local nw = require "luci.model.network"
local ut = require "luci.util"
local cl = require "luci.model.cloudd".init()
local uci = require "luci.model.uci".cursor()

local NEW_ACL = "NEW"
local new_acl = NEW_ACL

local ACTION_ADD = 0
local ACTION_EDIT = 1

local action = ACTION_ADD

local acl = arg[1] or new_acl

m = Map("cloudd_acl", "",
        translate(""))

m.redirect = luci.dispatcher.build_url("nradio/acl")

nw.init(m.uci)

local function acl_cfgvalue(self, section)
    return self.map:get(acl, self.option)
end

local function acl_write(self, section, value)
    return self.map:set(acl, self.option, value)
end

function m.on_parse(self)
    if m:submitstate() and acl == new_acl then
        acl = cl.new_acl()
        -- reassign the uci handler to fix set failure
        m.uci = uci
    end
end

function m.on_after_commit(map)
    cl.apply_acl(acl)
end

-- wireless toggle was requested, commit and reload page
function m.parse(map)
    action = m.flow.action or ACTION_ADD

    if action == ACTION_ADD then
        if arg[1] then
            luci.http.redirect(luci.dispatcher.build_url("nradio/acl"))
        end

        m.title = translate("New Wireless ACL")
    end

    if action == ACTION_EDIT then
        if not uci:get("cloudd_acl", acl, "name") then
            luci.http.redirect(luci.dispatcher.build_url("nradio/acl"))
            return
        end
    end

    state = Map.parse(map)

    if m:submitstate() then
        luci.http.redirect(luci.dispatcher.build_url("nradio/acl"))
        return
    end

    return state
end

m.title = translate("Wi-Fi ACL")

m.uci = require("luci.model.uci").cursor()

m:append(Template("nradio_acl/import"))

-- General Section
s = m:section(NamedSection, acl, "acl", translate(""))
s.addremove = false
s.anoymous = true
function s.cfgvalue(self, section)
    if section == new_acl then
        return {}
    else
        return self.map:get(section)
    end
end

name = s:option(Value, "name", translate("Name"))

name.cfgvalue = acl_cfgvalue
name.write = acl_write

macs = s:option(TextValue, "nicid", translate("MAC List"),translate("mac list such as:<br>2C:61:F6:CC:6E:22<br>2C:61:F6:CC:6E:23"))
macs.size = 1
macs.rows = 10
macs.datatype = "multimacaddr"

function macs.cfgvalue(self, section)
    if section == new_acl then
        return ""
    end

    local res = self.map:get(acl, self.option)
    if type(res) == "table" then
        return table.concat(res, '\n')
    else
        return res
    end
end

function macs.write(self, section, value)
    local res = {}
    for k,v in string.gmatch(value, "(%x+:%x+:%x+:%x+:%x+:%x+)") do
        res[#res + 1] = k
    end

    self.map:set(acl, self.option, res)
end

actions = Template("nradio_acl/actions")
function actions.render(self)
    luci.template.render(self.template, {acl=acl})
end
m:append(actions)

return m
