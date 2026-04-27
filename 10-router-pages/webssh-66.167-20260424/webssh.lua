module("luci.controller.nradio_adv.webssh", package.seeall)

local http = require "luci.http"
local util = require "luci.util"
local fs = require "nixio.fs"
local uci_cursor = require("luci.model.uci").cursor

local function trim(value)
    return util.trim(value or "")
end

local function escape_lua_pattern(text)
    return (text:gsub("([^%w])", "%%%1"))
end

local function replace_plain(text, old, new)
    return (text:gsub(escape_lua_pattern(old), new))
end

local function skip_js_block(lines, start_index)
    local depth = 0
    local idx = start_index
    while idx <= #lines do
        local line = lines[idx]
        local _, open_count = line:gsub("{", "")
        local _, close_count = line:gsub("}", "")
        depth = depth + open_count - close_count
        idx = idx + 1
        if depth <= 0 then
            break
        end
    end
    return idx
end

local function cleanup_appcenter_template()
    local template = "/usr/lib/lua/luci/view/nradio_appcenter/appcenter.htm"
    if not fs.access(template) then
        return
    end

    local input = io.open(template, "r")
    if not input then
        return
    end

    local lines = {}
    for line in input:lines() do
        table.insert(lines, line)
    end
    input:close()

    local cleaned = {}
    local idx = 1
    while idx <= #lines do
        local line = lines[idx]
        if line:find('app_list.result.applist.unshift({name:"Web SSH"', 1, true) then
            idx = idx + 1
        elseif line:find('function normalize_app_route(app_name, route){', 1, true) then
            idx = skip_js_block(lines, idx)
        elseif line:find('function is_webssh_route(route){', 1, true) then
            idx = skip_js_block(lines, idx)
        elseif line:find('function enable_webssh_iframe_input(){', 1, true) then
            idx = skip_js_block(lines, idx)
        elseif line:find("if (app_name == 'Web SSH' && action == 'open' && route) {", 1, true) then
            idx = skip_js_block(lines, idx)
        elseif line:find("if (app_name == 'Web SSH' && action == 'uninstall') {", 1, true) then
            idx = skip_js_block(lines, idx)
        elseif line:find('open_route = normalize_app_route(db.name, open_route);', 1, true) then
            idx = idx + 1
        else
            line = replace_plain(line, " && frame.src.indexOf('/nradioadv/system/webssh') === -1", "")
            line = replace_plain(line, " tabindex='0' allow='clipboard-read; clipboard-write'", "")
            table.insert(cleaned, line)
            idx = idx + 1
        end
    end

    fs.writefile(template, table.concat(cleaned, "\n") .. "\n")
end

function collect_status()
    local uci = uci_cursor()
    local installed = fs.access("/usr/bin/ttyd") and fs.access("/etc/init.d/ttyd")
    local service_status = installed and trim(util.exec("/etc/init.d/ttyd status 2>/dev/null || true")) or ""
    local ttyd_ps = installed and trim(util.exec("ps w 2>/dev/null | grep '[u]sr/bin/ttyd' || true")) or ""
    local running = ttyd_ps ~= "" or service_status == "1" or service_status:lower():find("running", 1, true) ~= nil

    local ttyd_proc_count = installed and trim(util.exec("ps w 2>/dev/null | grep '[u]sr/bin/ttyd' | wc -l | tr -d ' ' || true")) or "0"
    if ttyd_proc_count == "" then
        ttyd_proc_count = "0"
    end

    local lan_ip = uci:get("network", "lan", "ipaddr")
        or trim(util.exec("ip -4 addr show br-lan 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1"))
        or "192.168.1.1"

    local host = http.getenv("HTTP_HOST") or http.getenv("SERVER_NAME") or lan_ip
    host = host:gsub(":%d+$", "")
    if host == "" or host == "0.0.0.0" or host == "::" or host == "localhost" then
        host = lan_ip
    end

    local bind_iface = uci:get("ttyd", "default", "interface") or ""
    if bind_iface ~= "" and not bind_iface:match("^[%w%._:%-]+$") then
        bind_iface = ""
    end

    local bind_port = uci:get("ttyd", "default", "port") or "7681"
    if not bind_port:match("^%d+$") then
        bind_port = "7681"
    end
    local client_limit = uci:get("ttyd", "default", "max_clients") or "0"
    local ssl_enabled = (uci:get("ttyd", "default", "ssl") == "1")
    local bind_iface_label = bind_iface ~= "" and bind_iface or "全部接口"
    local client_limit_label = client_limit == "0" and "无限制" or client_limit
    local ttyd_scheme = ssl_enabled and "https" or "http"
    local ttyd_url = ttyd_scheme .. "://" .. host .. ":" .. bind_port .. "/"
    local ssh_cmd = "ssh root@" .. lan_ip
    local listen_line = installed and trim(util.exec("netstat -lnt 2>/dev/null | grep -m1 ':" .. bind_port .. " ' || true")) or ""
    local iface_line = bind_iface ~= "" and installed and trim(util.exec("ip link show " .. bind_iface .. " 2>/dev/null || true")) or ""

    local runtime_label = installed and (running and "运行中" or "已停止") or "未安装"
    local runtime_tone = not installed and "off" or (running and "ok" or "off")
    local proc_check_label = installed and ttyd_ps ~= "" and "正常" or "缺失"
    local port_check_label = installed and listen_line ~= "" and "监听中" or "未监听"
    local iface_check_label = bind_iface == "" and "全部接口" or (installed and iface_line ~= "" and "存在" or "缺失")

    local self_check_ok = installed
        and proc_check_label == "正常"
        and port_check_label == "监听中"
        and (bind_iface == "" or iface_check_label == "存在")

    local self_check_label = self_check_ok and "通过" or "异常"
    local self_check_tone = self_check_ok and "ok" or (running and "warn" or "off")

    return {
        installed = installed,
        running = running,
        runtime_label = runtime_label,
        runtime_tone = runtime_tone,
        ttyd_proc_count = ttyd_proc_count,
        bind_iface = bind_iface,
        bind_iface_label = bind_iface_label,
        bind_port = bind_port,
        client_limit = client_limit,
        client_limit_label = client_limit_label,
        ssl_enabled = ssl_enabled,
        transport_label = ssl_enabled and "HTTPS / WSS" or "HTTP / WS",
        ttyd_url = ttyd_url,
        ssh_cmd = ssh_cmd,
        listen_line = listen_line,
        proc_check_label = proc_check_label,
        port_check_label = port_check_label,
        iface_check_label = iface_check_label,
        self_check_label = self_check_label,
        self_check_tone = self_check_tone,
        updated_at = os.date("%H:%M:%S")
    }
end

function index()
    entry({"nradioadv", "system", "webssh"}, template("nradio_adv/webssh"), nil, 91)
    entry({"nradioadv", "system", "webssh", "restart"}, call("restart"), nil, 92).leaf = true
    entry({"nradioadv", "system", "webssh", "uninstall"}, call("uninstall"), nil, 93).leaf = true
    entry({"nradioadv", "system", "webssh", "status"}, call("status"), nil, 94).leaf = true
    entry({"nradioadv", "system", "appcenter", "webssh"}, alias("nradioadv", "system", "webssh"), nil, nil, true).leaf = true
end

function restart()
    local dsp = require "luci.dispatcher"

    os.execute("/etc/init.d/ttyd restart >/dev/null 2>&1")
    http.redirect(dsp.build_url("nradioadv", "system", "webssh"))
end

function uninstall()
    local dsp = require "luci.dispatcher"

    os.execute("/etc/init.d/ttyd stop >/dev/null 2>&1")
    os.execute("/etc/init.d/ttyd disable >/dev/null 2>&1")
    cleanup_appcenter_template()
    os.execute("rm -f /www/luci-static/nradio/images/icon/webssh.svg /usr/bin/ttyd /etc/init.d/ttyd /etc/config/ttyd /usr/lib/lua/luci/controller/ttyd.lua /usr/lib/lua/luci/model/cbi/ttyd.lua /usr/lib/lua/luci/view/ttyd/overview.htm /usr/lib/lua/luci/controller/nradio_adv/webssh.lua /usr/lib/lua/luci/view/nradio_adv/webssh.htm")
    os.execute("rm -f /tmp/luci-indexcache /tmp/infocd/cache/appcenter /tmp/luci-modulecache/* >/dev/null 2>&1")
    os.execute("/etc/init.d/infocd restart >/dev/null 2>&1")
    os.execute("/etc/init.d/appcenter restart >/dev/null 2>&1")
    os.execute("/etc/init.d/uhttpd reload >/dev/null 2>&1")
    http.redirect(dsp.build_url("nradioadv", "system", "appcenter"))
end

function status()
    http.prepare_content("application/json")
    http.write_json(collect_status())
end
