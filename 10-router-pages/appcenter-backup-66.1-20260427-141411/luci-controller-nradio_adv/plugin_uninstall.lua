module("luci.controller.nradio_adv.plugin_uninstall", package.seeall)

local TASK_DIR = "/tmp/nradio-plugin-uninstall"
local HELPER = "/usr/libexec/nradio-plugin-uninstall"
local CODE_OK = 0
local CODE_RUNNING = 2
local CODE_FAILED = 13

function index()
    local page
    page = entry({"nradioadv", "system", "plugin_uninstall"}, firstchild(), nil, 94)
    page.dependent = false
    entry({"nradioadv", "system", "plugin_uninstall", "start"}, call("start_uninstall"), nil, 95).leaf = true
    entry({"nradioadv", "system", "plugin_uninstall", "check"}, call("check_uninstall"), nil, 96).leaf = true
    entry({"nradioadv", "system", "plugin_uninstall", "openclash"}, call("uninstall_openclash"), nil, 97).leaf = true
    entry({"nradioadv", "system", "plugin_uninstall", "webssh"}, call("uninstall_webssh"), nil, 98).leaf = true
    entry({"nradioadv", "system", "plugin_uninstall", "adguardhome"}, call("uninstall_adguardhome"), nil, 99).leaf = true
    entry({"nradioadv", "system", "plugin_uninstall", "openlist"}, call("uninstall_openlist"), nil, 100).leaf = true
    entry({"nradioadv", "system", "plugin_uninstall", "zerotier"}, call("uninstall_zerotier"), nil, 101).leaf = true
    entry({"nradioadv", "system", "plugin_uninstall", "openvpn"}, call("uninstall_openvpn"), nil, 102).leaf = true
    entry({"nradioadv", "system", "plugin_uninstall", "easytier"}, call("uninstall_easytier"), nil, 103).leaf = true
    entry({"nradioadv", "system", "plugin_uninstall", "fanctrl"}, call("uninstall_fanctrl"), nil, 104).leaf = true
    entry({"nradioadv", "system", "plugin_uninstall", "qiyou"}, call("uninstall_qiyou"), nil, 105).leaf = true
end

local function json_response(code, msg, detail)
    local http = require "luci.http"
    local jsonc = require "luci.jsonc"
    local result = { code = code, msg = msg or "" }

    if detail and #detail > 0 then
        result.errro_detail = detail
        result.error_detail = detail
    end

    http.prepare_content("application/json")
    http.write(jsonc.stringify({ result = result }))
end

local function shell_quote(value)
    value = tostring(value or "")
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function read_file(path, limit)
    local fp = io.open(path, "r")
    local data

    if not fp then
        return ""
    end

    data = fp:read(limit or 4096) or ""
    fp:close()
    return data
end

local function trim(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local function plugin_from_name(name)
    name = trim(name)

    if name == "luci-app-openclash" or name == "openclash" then
        return "openclash"
    elseif name == "Web SSH" or name == "webssh" or name == "ttyd" then
        return "webssh"
    elseif name == "luci-app-adguardhome" or name == "adguardhome" then
        return "adguardhome"
    elseif name == "OpenVPN" or name == "openvpn" or name == "luci-app-openvpn" then
        return "openvpn"
    elseif name == "OpenList" or name == "openlist" or name == "luci-app-openlist" then
        return "openlist"
    elseif name == "ZeroTier" or name == "zerotier" then
        return "zerotier"
    elseif name == "EasyTier" or name == "easytier" or name == "luci-app-easytier" then
        return "easytier"
    elseif name == "FanControl Plus" or name == "fanctrl-plus" or name == "FanControl" or name == "fanctrl" then
        return "fanctrl"
    elseif name == "奇游联机宝" or name == "QiYou" or name == "qiyou" or name == "nradio-qiyou" then
        return "qiyou"
    end

    return nil
end

local function task_paths(plugin)
    return TASK_DIR .. "/" .. plugin .. ".status",
        TASK_DIR .. "/" .. plugin .. ".rc",
        TASK_DIR .. "/" .. plugin .. ".log"
end

local function start_plugin(plugin)
    local status_file, rc_file, log_file = task_paths(plugin)
    local helper_test = io.open(HELPER, "r")

    if not helper_test then
        json_response(CODE_FAILED, "卸载失败", "缺少卸载助手：" .. HELPER)
        return
    end
    helper_test:close()

    os.execute("/bin/mkdir -p " .. shell_quote(TASK_DIR) .. " >/dev/null 2>&1")
    os.execute("/bin/rm -f " .. shell_quote(status_file) .. " " .. shell_quote(rc_file) .. " " .. shell_quote(log_file) .. " >/dev/null 2>&1")

    local cmd = "(" ..
        "/bin/echo running > " .. shell_quote(status_file) .. "; " ..
        shell_quote(HELPER) .. " " .. shell_quote(plugin) .. " > " .. shell_quote(log_file) .. " 2>&1; " ..
        "rc=$?; /bin/echo $rc > " .. shell_quote(rc_file) .. "; " ..
        "if [ $rc -eq 0 ]; then /bin/echo ok > " .. shell_quote(status_file) .. "; else /bin/echo fail > " .. shell_quote(status_file) .. "; fi" ..
        ") >/dev/null 2>&1 &"

    os.execute(cmd)
    json_response(CODE_RUNNING, "正在卸载")
end

local function start_by_name(name)
    local plugin = plugin_from_name(name)

    if not plugin then
        json_response(CODE_FAILED, "卸载失败", "未知插件：" .. trim(name))
        return
    end

    start_plugin(plugin)
end

function start_uninstall()
    local http = require "luci.http"
    start_by_name(http.formvalue("name") or http.formvalue("plugin") or "")
end

function check_uninstall()
    local http = require "luci.http"
    local plugin = plugin_from_name(http.formvalue("name") or http.formvalue("plugin") or "")
    local status_file, rc_file, log_file
    local status, rc, detail

    if not plugin then
        json_response(CODE_FAILED, "卸载失败", "未知插件")
        return
    end

    status_file, rc_file, log_file = task_paths(plugin)
    status = trim(read_file(status_file, 64))

    if status == "ok" then
        json_response(CODE_OK, "卸载完成")
    elseif status == "fail" then
        rc = trim(read_file(rc_file, 64))
        detail = read_file(log_file, 4096)
        if rc ~= "" then
            detail = "退出码：" .. rc .. "\n" .. detail
        end
        json_response(CODE_FAILED, "卸载失败", detail)
    else
        json_response(CODE_RUNNING, "正在卸载")
    end
end

function uninstall_openclash()
    start_plugin("openclash")
end

function uninstall_webssh()
    start_plugin("webssh")
end

function uninstall_adguardhome()
    start_plugin("adguardhome")
end

function uninstall_openlist()
    start_plugin("openlist")
end

function uninstall_zerotier()
    start_plugin("zerotier")
end

function uninstall_openvpn()
    start_plugin("openvpn")
end

function uninstall_easytier()
    start_plugin("easytier")
end

function uninstall_fanctrl()
    start_plugin("fanctrl")
end

function uninstall_qiyou()
    start_plugin("qiyou")
end
