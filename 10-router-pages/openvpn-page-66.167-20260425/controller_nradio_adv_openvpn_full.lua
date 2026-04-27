module("luci.controller.nradio_adv.openvpn_full", package.seeall)

local dispatcher = require "luci.dispatcher"
local util = require "luci.util"
local http = require "luci.http"
local fs = require "nixio.fs"
local uci = require "luci.model.uci".cursor()

local function cmd(c)
    return util.trim(util.exec(c) or "")
end

local function split_lines(s)
    local out = {}
    for line in (s or ""):gmatch("[^\r\n]+") do
        if line ~= "" then
            out[#out + 1] = line
        end
    end
    return out
end

local function contains(text, needle)
    return needle ~= "" and (text or ""):find(needle, 1, true) ~= nil
end

local function contains_proxy_target(peer_dump, target)
    if not target or target == "" then
        return false
    end
    for _, line in ipairs(split_lines(peer_dump)) do
        local ip = line:match("^([^%s]+)%s+proxy")
        if ip == target then
            return true
        end
    end
    return false
end

local function bool_text(ok)
    return ok and "已就绪" or "缺失"
end

local function badge_state(ok)
    return ok and "ok" or "bad"
end

local function ratio_text(ok_count, total_count)
    if total_count <= 0 then
        return "-"
    end
    return tostring(ok_count) .. "/" .. tostring(total_count)
end

local function shell_quote(s)
    return "'" .. tostring(s or ""):gsub("'", "'\\''") .. "'"
end

local function ensure_custom_config()
    local profile_path = "/etc/openvpn/client.ovpn"
    local auth_path = "/etc/openvpn/auth.txt"

    if not fs.access(profile_path) then
        return false, "missing profile"
    end

    if not uci:get("openvpn", "custom_config") then
        uci:section("openvpn", "openvpn", "custom_config")
    end

    uci:set("openvpn", "custom_config", "enabled", "1")
    uci:set("openvpn", "custom_config", "config", profile_path)

    if fs.access(auth_path) then
        uci:set("openvpn", "custom_config", "auth_user_pass", auth_path)
    else
        uci:delete("openvpn", "custom_config", "auth_user_pass")
    end

    uci:save("openvpn")
    uci:commit("openvpn")
    return true
end

local function probe_ping(ip)
    if not ip or ip == "" then
        return false
    end
    return cmd("ping -c 1 -W 1 " .. shell_quote(ip) .. " >/dev/null 2>&1 && echo ok || echo fail") == "ok"
end

local function network_plus_one(network_ip)
    if not network_ip or network_ip == "" then
        return nil
    end
    local a, b, c, d = network_ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    d = tonumber(d)
    if a and b and c and d then
        if d < 255 then
            return string.format("%s.%s.%s.%d", a, b, c, d + 1)
        end
        return string.format("%s.%s.%s.%d", a, b, c, d)
    end
    return nil
end

local function ipcalc_field(cidr, field)
    if not cidr or cidr == "" then
        return ""
    end
    return cmd("ipcalc.sh " .. shell_quote(cidr) .. " 2>/dev/null | grep '^" .. tostring(field or "") .. "=' | cut -d= -f2")
end

local function probe_ip_for_target(target)
    if not target or target == "" then
        return nil
    end
    if target:find("/") then
        local ip, mask = target:match("^([%d%.]+)/(%d+)$")
        if not ip then
            return nil
        end
        if mask == "32" then
            return ip
        end
        local network_ip = ipcalc_field(target, "NETWORK")
        local prefix = ipcalc_field(target, "PREFIX")
        if not network_ip or network_ip == "" then
            return nil
        end
        if tonumber(prefix or mask) <= 30 then
            return network_plus_one(network_ip)
        end
        return network_ip
    end
    return target
end

local function detect_primary_lan_cidr(lan_addr_dump)
    for _, line in ipairs(split_lines(lan_addr_dump)) do
        local cidr = line:match("inet%s+([%d%.]+/%d+)")
        if cidr and not cidr:match("/32$") then
            local network_ip = ipcalc_field(cidr, "NETWORK")
            local prefix = ipcalc_field(cidr, "PREFIX")
            return (network_ip ~= "" and prefix ~= "") and (network_ip .. "/" .. prefix) or cidr
        end
    end
    return nil
end

local function collect_status()
    local svc = cmd("/etc/init.d/openvpn status 2>/dev/null || true")
    local ps_std = cmd("ps | grep 'openvpn(custom_config)' | grep -v grep")
    local ps_legacy = cmd("ps | grep 'openvpn --config' | grep -v grep")
    local ps = ps_std ~= "" and ps_std or ps_legacy
    local tun = cmd("ip addr show tun0 2>/dev/null || echo tun0-down")
    local route_dump = cmd("ip route | grep ' dev tun0' 2>/dev/null")
    local peer_dump = cmd("ip neigh show proxy dev br-lan 2>/dev/null")
    local rule_dump = cmd("ip rule | grep 'lookup main' 2>/dev/null")
    local nat_dump = cmd("iptables -t nat -S 2>/dev/null")
    local lan_addr_dump = cmd("ip -4 addr show br-lan 2>/dev/null")
    local log = cmd("tail -40 /tmp/openvpn-client.log 2>/dev/null || logread 2>/dev/null | grep -i openvpn | tail -40")
    local log_focus = cmd("(tail -120 /tmp/openvpn-client.log 2>/dev/null; logread 2>/dev/null) | grep -i -E 'openvpn|tun0|tls|auth|route|error|fail|warn' | tail -30")
    local cfg = cmd("sed -n '1,180p' /etc/openvpn/client.ovpn 2>/dev/null")
    local tun_ip = tun:match("inet%s+([%d%.]+/%d+)") or "-"
    local remote = cmd("awk '$1==\"remote\"{print $2\" \"$3; exit}' /etc/openvpn/client.ovpn 2>/dev/null")
    local proto = cmd("awk '$1==\"proto\"{print $2; exit}' /etc/openvpn/client.ovpn 2>/dev/null")
    local cipher = cmd("awk '$1==\"cipher\"{print $2; exit}' /etc/openvpn/client.ovpn 2>/dev/null")
    local auth_digest = cmd("awk '$1==\"auth\"{print $2; exit}' /etc/openvpn/client.ovpn 2>/dev/null")

    local has_ca = cfg:find("<ca>") ~= nil
    local has_cert = cfg:find("<cert>") ~= nil
    local has_tls_auth = cfg:find("<tls%-auth>") ~= nil
    local has_tls_crypt = cfg:find("<tls%-crypt>") ~= nil
    local has_auth_file = cmd("sed -n '1,40p' /etc/openvpn/auth.txt 2>/dev/null") ~= ""
    local profile_ready = fs.access("/etc/openvpn/client.ovpn")
    local auth_required = contains(cfg, "auth-user-pass")
    local activation_ready = profile_ready and ((not auth_required) or has_auth_file)
    local managed_cfg = uci:get("openvpn", "custom_config", "config")
    local managed_enabled = uci:get("openvpn", "custom_config", "enabled") == "1"
    local uci_managed = managed_cfg == "/etc/openvpn/client.ovpn"
    local connected = (((svc:match("running")) or ps ~= "") and tun:match("inet ")) and true or false
    local mode = ps_std ~= "" and "UCI custom_config" or (ps_legacy ~= "" and "Legacy ovpn" or "Stopped")

    local route_checks = {}
    local peer_lines = split_lines(peer_dump)
    local route_targets = {}
    local route_count = 0
    local route_health_ok = 0
    local route_health_total = 0
    local remote_online_count = 0

    for _, line in ipairs(split_lines(route_dump)) do
        if line:find(" via ", 1, true) and not line:match("^default%s+via%s+") then
            local target, via = line:match("^([^%s]+) via ([^%s]+)")
            target = target or line:match("^([^%s]+)") or line
            via = via or "-"
            local is_host = target:find("/") == nil
            local to_rule_ok = contains(rule_dump, "to " .. target .. " lookup main")
            local iif_rule_ok = contains(rule_dump, "to " .. target .. " iif br-lan lookup main")
            local proxy_ok = is_host and contains_proxy_target(peer_dump, target) or false
            local probe_ip = probe_ip_for_target(target)
            local probe_ok = probe_ping(probe_ip)
            route_checks[#route_checks + 1] = {
                line = line,
                target = target,
                via = via,
                kind = is_host and "host" or "subnet",
                to_rule_ok = to_rule_ok,
                iif_rule_ok = iif_rule_ok,
                proxy_ok = proxy_ok,
                probe_ip = probe_ip or "-",
                probe_ok = probe_ok
            }
            route_targets[#route_targets + 1] = target
            route_count = route_count + 1
            if probe_ok then
                remote_online_count = remote_online_count + 1
            end
            route_health_total = route_health_total + 2 + (is_host and 1 or 0)
            if to_rule_ok then route_health_ok = route_health_ok + 1 end
            if iif_rule_ok then route_health_ok = route_health_ok + 1 end
            if is_host and proxy_ok then route_health_ok = route_health_ok + 1 end
        end
    end

    table.sort(route_checks, function(a, b)
        if a.kind ~= b.kind then
            return a.kind < b.kind
        end
        if a.probe_ok ~= b.probe_ok then
            return (not a.probe_ok) and b.probe_ok
        end
        return tostring(a.target) < tostring(b.target)
    end)

    local peer_count = #peer_lines
    local map_ip = lan_addr_dump:match("inet%s+([%d%.]+/32)")
    local primary_lan_cidr = detect_primary_lan_cidr(lan_addr_dump)
    local map_ip_ok = map_ip ~= nil
    local dnat_pre_ok = map_ip_ok and contains(nat_dump, "-A PREROUTING -d " .. map_ip .. " -i tun0 -j DNAT --to-destination") or false
    local dnat_out_ok = map_ip_ok and contains(nat_dump, "-A OUTPUT -d " .. map_ip .. " -j DNAT --to-destination") or false
    local local_map_online = map_ip_ok and dnat_pre_ok and dnat_out_ok
    local masquerade_hits = 0
    for _, item in ipairs(route_checks) do
        if primary_lan_cidr and contains(nat_dump, "-A POSTROUTING -s " .. primary_lan_cidr .. " -d " .. item.target)
            and contains(nat_dump, " -o tun0 -j MASQUERADE")
        then
            masquerade_hits = masquerade_hits + 1
        end
    end

    local auth_mode = "未知"
    if has_auth_file and has_cert then
        auth_mode = "账号 + 证书"
    elseif has_auth_file then
        auth_mode = "账号密码"
    elseif has_cert then
        auth_mode = "证书"
    end

    local tls_label = "无"
    if has_tls_crypt then
        tls_label = "tls-crypt"
    elseif has_tls_auth then
        tls_label = "tls-auth"
    end

    local log_has_init_marker = log:match("Initialization Sequence Completed") ~= nil or log_focus:match("Initialization Sequence Completed") ~= nil
    local log_error = log_focus:match("AUTH_FAILED") ~= nil
        or log_focus:match("TLS Error") ~= nil
        or log_focus:match("fatal") ~= nil
        or log_focus:match("ERROR") ~= nil
    local log_state_ok = connected and not log_error
    local log_state_label = "未确认"
    if log_error then
        log_state_label = "近期异常"
    elseif connected then
        log_state_label = log_has_init_marker and "运行稳定" or "运行中"
    elseif log_has_init_marker then
        log_state_label = "已完成初始化"
    end

    local health_ok = 0
    local health_total = 0
    local function add_health(ok)
        health_total = health_total + 1
        if ok then
            health_ok = health_ok + 1
        end
    end

    add_health(connected)
    add_health(log_state_ok)
    if route_count > 0 then
        add_health(route_health_ok == route_health_total)
    end
    if map_ip_ok or dnat_pre_ok or dnat_out_ok then
        add_health(map_ip_ok)
        add_health(dnat_pre_ok)
        add_health(dnat_out_ok)
    end

    local health_label = "离线"
    local health_class = "bad"
    if connected then
        if health_ok == health_total then
            health_label = "健康"
            health_class = "ok"
        else
            health_label = "告警"
            health_class = "warn"
        end
    end

    local action_kind = "need_profile"
    local action_label = "先写入配置"
    local action_hint = "尚未检测到可用的 client.ovpn，需先写入配置。"
    local runtime_note = "先完成配置写入，当前页面才会切换成启动或接管并启动。"
    local auth_note = "还没有可启动的配置文件。"

    if connected then
        if health_class == "ok" then
            action_kind = "stable"
            action_label = "OpenVPN 运行中"
            action_hint = "当前连接状态正常，如无必要无需重连；如需断开可直接停止。"
            runtime_note = "当前实例运行正常，建议保持当前连接；只有在切换配置或排障时再执行重连。"
            auth_note = "当前配置已在运行，认证材料按现有实例生效。"
        else
            action_kind = "restart"
            action_label = "重连 OpenVPN"
            action_hint = "当前已在线但存在告警，可优先尝试重连或查看下方实时校验。"
            runtime_note = "当前实例已由 LuCI 接管；如果状态异常，可直接重连当前 custom_config。"
            auth_note = "当前配置已在运行，但存在待确认项，可优先检查认证材料和下方日志。"
        end
    elseif activation_ready and uci_managed then
        action_kind = "start"
        action_label = "启动 OpenVPN"
        action_hint = "配置已就绪，可直接从当前页面启动 OpenVPN。"
        runtime_note = "当前实例已在 LuCI 中登记，断开时可直接启动。"
        auth_note = "配置文件和所需认证材料已经齐全，可直接由当前页面启动。"
    elseif activation_ready then
        action_kind = "takeover"
        action_label = "接管并启动"
        action_hint = "检测到现有 client.ovpn，可由当前页面接管并启动。"
        runtime_note = "当前页会把现有 client.ovpn 接入 custom_config 后再启动。"
        auth_note = "配置文件和所需认证材料已经齐全，接管后可以直接启动。"
    elseif profile_ready then
        action_kind = "need_auth"
        action_label = "补齐认证文件"
        action_hint = "已检测到配置文件，但认证材料还不完整，暂时不能直接启动。"
        runtime_note = "补齐必需的认证文件后，当前页面才能直接启动。"
        auth_note = "配置文件已存在，但认证材料未齐全。"
    end

    local managed_label = "未配置"
    if uci_managed and managed_enabled then
        managed_label = "已接管"
    elseif uci_managed then
        managed_label = "已接管未启用"
    elseif profile_ready then
        managed_label = "可接管"
    end

    local startup_label = activation_ready and "可启动" or (profile_ready and "待认证文件" or "待配置")
    local online_breakdown = "远端 " .. ratio_text(remote_online_count, route_count) .. " · 映射 " .. (map_ip_ok and ratio_text(local_map_online and 1 or 0, 1) or "-")
    local online_device_ratio = ratio_text(remote_online_count, route_count)
    local mode_label = "未启动"
    if ps_std ~= "" then
        mode_label = "LuCI 管理实例"
    elseif ps_legacy ~= "" then
        mode_label = "外部配置直连"
    elseif profile_ready then
        mode_label = "待接管"
    end
    local service_label = connected and "运行中" or ((svc:match("enabled=yes") and profile_ready) and "已启用未连接" or "已停止")
    local process_summary = ps ~= "" and ((ps_std ~= "" and "custom_config 正在运行") or "外部配置进程正在运行") or "未检测到进程"
    local auth_badge_label = activation_ready and "可启动" or "待补齐"
    local route_badge_label = (route_count > 0 and route_health_ok == route_health_total) and "完整" or "待检查"
    local auth_requirement_label = "无需额外文件"
    if auth_required and has_auth_file then
        auth_requirement_label = "需要账号文件 · 已就绪"
    elseif auth_required then
        auth_requirement_label = "需要账号文件"
    elseif has_cert then
        auth_requirement_label = "证书模式"
    end
    local cert_material_label = "无需证书"
    if has_ca and has_cert then
        cert_material_label = "CA + 客户端证书"
    elseif has_ca then
        cert_material_label = "仅 CA 证书"
    elseif has_cert then
        cert_material_label = "仅客户端证书"
    end

    return {
        connected = connected,
        health_label = health_label,
        health_class = health_class,
        status_summary_label = connected and ((health_class == "ok") and "已连接 · 健康" or "已连接 · 告警") or "未连接",
        status_label = connected and "已连接" or "已停止",
        health_ratio = ratio_text(health_ok, health_total),
        online_device_ratio = online_device_ratio,
        online_ratio = ratio_text(remote_online_count + (local_map_online and 1 or 0), route_count + (map_ip_ok and 1 or 0)),
        remote_online_ratio = ratio_text(remote_online_count, route_count),
        local_map_online_ratio = map_ip_ok and ratio_text(local_map_online and 1 or 0, 1) or "-",
        route_rule_ratio = ratio_text(route_health_ok, route_health_total),
        tun_ip = tun_ip,
        remote = remote ~= "" and remote or "-",
        proto = proto ~= "" and proto or "-",
        auth_mode = auth_mode,
        tls_label = tls_label,
        cipher = cipher ~= "" and cipher or "-",
        auth_digest = auth_digest ~= "" and auth_digest or "-",
        service_status = svc ~= "" and svc or "stopped",
        mode = mode,
        profile_ready = profile_ready,
        activation_ready = activation_ready,
        auth_required = auth_required,
        action_kind = action_kind,
        action_label = action_label,
        action_hint = action_hint,
        runtime_note = runtime_note,
        auth_note = auth_note,
        managed_label = managed_label,
        startup_label = startup_label,
        online_breakdown = online_breakdown,
        mode_label = mode_label,
        service_label = service_label,
        process_summary = process_summary,
        auth_badge_label = auth_badge_label,
        auth_requirement_label = auth_requirement_label,
        cert_material_label = cert_material_label,
        route_badge_label = route_badge_label,
        copy_ready = profile_ready,
        uci_managed = uci_managed,
        uci_enabled = managed_enabled,
        process_line = ps ~= "" and ps or "no process",
        log_state = log_state_label,
        log_state_ok = log_state_ok,
        auth_ready = bool_text(has_auth_file),
        ca_ready = bool_text(has_ca),
        cert_ready = bool_text(has_cert),
        route_count = route_count,
        peer_count = peer_count,
        remote_online_count = remote_online_count,
        route_badge_ok = route_count > 0 and route_health_ok == route_health_total,
        dnat_status = map_ip_ok and ((dnat_pre_ok and dnat_out_ok) and "已同步" or "待修复") or "未启用",
        dnat_ok = (not map_ip_ok) or (dnat_pre_ok and dnat_out_ok),
        dnat_pre_ok = dnat_pre_ok,
        dnat_out_ok = dnat_out_ok,
        map_ip = map_ip or "-",
        primary_lan_cidr = primary_lan_cidr or "-",
        local_map_online = local_map_online,
        masquerade_hits = masquerade_hits,
        route_targets = route_targets,
        route_checks = route_checks,
        peer_lines = peer_lines,
        log_focus = log_focus ~= "" and log_focus or "no focus log",
        log = log ~= "" and log or "no log",
        tun = tun ~= "" and tun or "tun0-down",
        lan_addr_dump = lan_addr_dump ~= "" and lan_addr_dump or "no br-lan data",
        ts = os.date("%Y-%m-%d %H:%M:%S")
    }
end

function index()
    local page = entry({"nradioadv", "system", "openvpnfull"}, template("nradio_adv/openvpn_full"), _("OpenVPN"), 94)
    page.show = true
    entry({"nradioadv", "system", "openvpnfull", "restart"}, call("restart"), nil).leaf = true
    entry({"nradioadv", "system", "openvpnfull", "applycurrent"}, call("applycurrent"), nil).leaf = true
    entry({"nradioadv", "system", "openvpnfull", "stop"}, call("stop"), nil).leaf = true
    entry({"nradioadv", "system", "openvpnfull", "status"}, call("status"), nil).leaf = true
end

function restart()
    os.execute("( /etc/init.d/openvpn restart >/dev/null 2>&1 || /etc/init.d/openvpn_client restart >/dev/null 2>&1 ) &")
    http.redirect(dispatcher.build_url("nradioadv", "system", "openvpnfull"))
end

function applycurrent()
    local ok = ensure_custom_config()
    if ok then
        os.execute("( /etc/init.d/openvpn enable >/dev/null 2>&1; /etc/init.d/openvpn restart >/dev/null 2>&1 || /etc/init.d/openvpn start custom_config >/dev/null 2>&1 ) &")
    end
    http.redirect(dispatcher.build_url("nradioadv", "system", "openvpnfull"))
end

function stop()
    os.execute("( /etc/init.d/openvpn stop custom_config >/dev/null 2>&1 || /etc/init.d/openvpn stop >/dev/null 2>&1 ) &")
    http.redirect(dispatcher.build_url("nradioadv", "system", "openvpnfull"))
end

function status()
    local ok, data = xpcall(collect_status, debug.traceback)
    if not ok then
        http.status(200, "OK")
        http.prepare_content("application/json")
        http.write_json({
            ok = false,
            error = tostring(data or "unknown error"),
            ts = os.date("%Y-%m-%d %H:%M:%S")
        })
        return
    end

    data.ok = true
    http.status(200, "OK")
    http.prepare_content("application/json")
    http.write_json(data)
end
