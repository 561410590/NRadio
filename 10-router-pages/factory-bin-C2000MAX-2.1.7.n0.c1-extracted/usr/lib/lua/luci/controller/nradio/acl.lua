-- Copyright 2017 NRadio
module("luci.controller.nradio.acl", package.seeall)

local uci = require "luci.model.uci".cursor()
local dsp = require "luci.dispatcher"
local lng = require "luci.i18n"
local utl = require "luci.util"
local fs = require "nixio.fs"
local nr = require "luci.nradio"

function index()
    local nradio = require "luci.nradio"
    if not nradio.has_ptype("ac") and not nradio.has_wlan() then
        return
    end

    entry({"nradio", "acl"}, template("nradio_acl/index"), _("Wi-Fi ACL"), 20, true).index = true
    entry({"nradio", "acl", "edit"}, cbi("nradio_acl/config", {action = 1, hideapplybtn = true, hidesavebtn = true, hideresetbtn = true}), _("Edit"), nil, true).leaf = true
    entry({"nradio", "acl", "add"}, cbi("nradio_acl/config", {action = 0, hideapplybtn = true, hidesavebtn = true, hideresetbtn = true}), _("Add"), nil, true).leaf = true
    entry({"nradio", "acl", "list"}, call("action_list_acl"), nil, nil, true).leaf = true
    entry({"nradio", "acl", "get"}, call("action_get_acl"), nil, nil, true).leaf = true
    entry({"nradio", "acl", "del"}, post("delete_acl"), nil, nil, true).leaf = true

    local page
    page = entry({"nradioadv", "wireless", "acl"}, alias("nradio", "acl"), _("Wi-Fi ACL"), 10, true)
    page.icon = 'list-ul'
    page.show = luci.nradio.has_ptype("ac") or luci.nradio.has_own_wlan()
end

local function list_acl()
    local result = {count = 0, acl = {}}

    uci:foreach("cloudd_acl", "acl",
                function(s)
                    local acl = {
                        id = "",
                        name = "",
                        count = 0,
                        url = "",
                        ref = false
                    }
                    local cmd
                    local ref

                    acl.id = s[".name"]
                    acl.name = s.name
                    acl.url = dsp.build_url("nradio", "acl", "edit", s[".name"])
                    if s.nicid and type(s.nicid) == "table" then
                        acl.count = #s.nicid
                    end

                    -- TODO: calculate the references
                    -- Temporary return whether acl is referred
                    cmd = 'grep "'..acl.id..'\'" /etc/config/cloudd | grep "acllist" | wc -l | xargs printf'
                    ref = tonumber(utl.exec(cmd) or 0)
                    if ref > 0 then
                        acl.ref = true
                    end

                    result.acl[#result.acl + 1] = acl
                    result.count = result.count + 1
                end
    )

    return result
end

local function get_acl(id)
    local result = {
        count = 0,
        id = "",
        name = "",
        nicid = {},
    }

    local acl = uci:get_all("cloudd_acl", id)

    if not acl then
        return result
    end

    result.id = id
    result.name = acl.name
    result.nicid = acl.nicid
    result.count = #result.nicid

    return result
end

function delete_acl()
    local acl_value = luci.http.formvalue("acls") or ""
    local acl_list = luci.util.split(acl_value, ",")
    local commit = false

    for _, acl in pairs(acl_list) do
        if acl:match("^a[%d]+$") and acl ~= "a0" then
            if uci:get("cloudd_acl", acl) then
                uci:delete("cloudd_acl", acl)
                commit = true
            end
        end
    end

    if commit then
        uci:commit("cloudd_acl")
    end
end

-- List all acls
-- @return acls list result
-- {
--   "result": {
--     "count": 2,
--     "acl": [
--       {
--         "id": "a0",
--         "ref": true,
--         "name": "acl list 1",
--         "count": 2
--         "url": "/nradio/acl/edit/a0"
--       },
--       {
--         "id": "a1",
--         "ref": false,
--         "name": "acl list 2",
--         "count": 2
--         "url": "/nradio/acl/edit/a1"
--       }
--     ]
--   }
-- }
function action_list_acl()
    nr.luci_call_result(list_acl())
end

-- Get ACL
-- @return ACL list result
-- {
--   "result": {
--     "id": "a0",
--     "name": "acl list 1",
--     "count": 2,
--     "nicid": [
--       "00:11:22:33:44:55",
--       "00:11:22:33:44:66"
--     ]
--   }
-- }
function action_get_acl()
    local id = luci.http.formvalue("id")

    if not id then
        return false
    end

    nr.luci_call_result(get_acl(id))
end
