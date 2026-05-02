#!/usr/bin/lua

local uci = require "luci.model.uci".cursor()
local ip = require "luci.ip"
local util = require "luci.util"
local EBTABLES_COMMAND = "/usr/sbin/ebtables"

local function reset_ebtables()
    util.exec(EBTABLES_COMMAND.." -F")
    util.exec(EBTABLES_COMMAND.." -X")
end

local function add_rules(s)
    local chain_name = "GUEST_"..s["ifname"]:upper()
    local range = ip.new(s["hostip"])
    local network = range:network()
    local prefix = range:prefix()
    local host = s["hostip"]:match("(%C+)/%C+")

    -- Create a new chain
    util.exec(EBTABLES_COMMAND.." -N "..chain_name)

    -- Filter interface packets
    util.exec(EBTABLES_COMMAND.." -I FORWARD -i "..s["ifname"].." -j "..chain_name)
    util.exec(EBTABLES_COMMAND.." -I INPUT -i "..s["ifname"].." -j "..chain_name)

    -- Drop forward packets
    util.exec(EBTABLES_COMMAND.." -I "..chain_name.." 1 -p ipv4 --ip-proto tcp --ip-dport 80 --ip-dst "..host.." -j DROP")
    util.exec(EBTABLES_COMMAND.." -I "..chain_name.." 2 -p ipv4 --ip-proto tcp --ip-dport 22 --ip-dst "..host.." -j DROP")
    util.exec(EBTABLES_COMMAND.." -I "..chain_name.." 3 -p ipv4 --ip-dst "..host.." -j ACCEPT")
    util.exec(EBTABLES_COMMAND.." -I "..chain_name.." 4 -p ipv4 --ip-dst "..tostring(network).."/"..prefix.." -j DROP")
end

reset_ebtables()

uci:foreach("wireless", "wifi-iface",
            function(s)
                if not s["guest"] or s["guest"] ~= "1" then
                    return true
                end

                if s["disabled"] and s["disabled"] == "1" then
                    return true
                end

                if not s["ifname"] then
                    return true
                end

                if not s["hostip"] then
                    return true
                end
                add_rules(s)
            end
)
