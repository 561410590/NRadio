#!/bin/sh

SCRIPT_TITLE="NRadio 雷神加速器临时接入助手"
SCRIPT_VERSION="temp-20260427"

APP_NAME="雷神加速器"
PKG_NAME="nradio-leigod"
APP_VERSION_DEFAULT="LeigodAcc"
APP_ROUTE="nradioadv/system/leigod"
APP_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/leigod.lua"
APP_VIEW="/usr/lib/lua/luci/view/nradiobridge_leigod/leigod.htm"
APP_ICON_DIR="/www/luci-static/nradio/images/icon"
APP_ICON_NAME="leigod.svg"
APP_ICON_PATH="$APP_ICON_DIR/$APP_ICON_NAME"
APPCENTER_CONFIG="/etc/config/appcenter"
APPCENTER_TEMPLATE="/usr/lib/lua/luci/view/nradio_appcenter/appcenter.htm"
UNINSTALL_HELPER="/usr/libexec/nradio-leigod-uninstall"
PLUGIN_UNINSTALL_HELPER="/usr/libexec/nradio-plugin-uninstall"
PLUGIN_UNINSTALL_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/plugin_uninstall.lua"
LEIGOD_DIR="/usr/sbin/leigod"
LEIGOD_INIT="/etc/init.d/acc"
LEIGOD_MANAGER_URL="https://fastly.jsdelivr.net/gh/miaoermua/openwrt-leigodacc-manager@main/leigod.sh"
LEIGOD_OFFICIAL_INSTALL_URL="http://119.3.40.126/router_plugin_new/plugin_install.sh"
LEIGOD_INSTALLER="/tmp/leigod-plugin-install.sh"

log() {
    printf '%s\n' "$*"
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

need_root() {
    [ "$(id -u 2>/dev/null)" = "0" ] || die "请使用 root 用户执行"
}

read_line() {
    read -r READ_RESULT || return 1
    return 0
}

confirm_or_exit() {
    prompt="$1"
    answer=""
    printf '%s [y/N]: ' "$prompt"
    read_line || die "input cancelled"
    answer="$READ_RESULT"
    case "$answer" in
        y|Y|yes|YES)
            return 0
            ;;
        *)
            log "已取消"
            exit 0
            ;;
    esac
}

download_url() {
    url="$1"
    out="$2"

    rm -f "$out"
    if command -v curl >/dev/null 2>&1; then
        curl -s -k -L -m 180 "$url" -o "$out" 2>/dev/null || true
    fi
    if [ ! -s "$out" ] && command -v wget >/dev/null 2>&1; then
        wget -q -T 180 "$url" -O "$out" --no-check-certificate 2>/dev/null || true
    fi
    [ -s "$out" ]
}

backup_file() {
    file="$1"
    [ -f "$file" ] || return 0
    stamp="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo leigod)"
    cp "$file" "$file.bak-leigod-$stamp" 2>/dev/null || true
}

refresh_luci_appcenter() {
    rm -f /tmp/luci-indexcache /tmp/infocd/cache/appcenter 2>/dev/null || true
    rm -f /tmp/luci-modulecache/* 2>/dev/null || true
    /etc/init.d/infocd restart >/dev/null 2>&1 || true
    /etc/init.d/appcenter restart >/dev/null 2>&1 || true
    /etc/init.d/uhttpd reload >/dev/null 2>&1 || true
}

require_nradio_appcenter() {
    [ -f "$APPCENTER_CONFIG" ] || die "未检测到 NRadio 应用商店配置：$APPCENTER_CONFIG"
    [ -f "$APPCENTER_TEMPLATE" ] || die "未检测到 NRadio 应用商店模板：$APPCENTER_TEMPLATE"
}

is_leigod_installed() {
    [ -d "$LEIGOD_DIR" ] && ls "$LEIGOD_DIR"/acc-gw.router.* >/dev/null 2>&1
}

leigod_version() {
    if [ -f "$LEIGOD_DIR/acc_version.ini" ]; then
        awk -F= '/version|VERSION|Ver|VER/ {print $2; exit}' "$LEIGOD_DIR/acc_version.ini" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
        return
    fi
    if [ -f "$LEIGOD_DIR/plugin_common.sh" ]; then
        grep -m 1 '^download_base_url=' "$LEIGOD_DIR/plugin_common.sh" 2>/dev/null | sed 's/^download_base_url=//' | sed 's/"//g'
        return
    fi
    printf '%s\n' "$APP_VERSION_DEFAULT"
}

leigod_size() {
    size="$(du -sk "$LEIGOD_DIR" 2>/dev/null | awk '{print $1}')"
    [ -n "$size" ] || size="0"
    printf '%s\n' "$size"
}

find_uci_section() {
    sec_type="$1"
    name="$2"

    uci show appcenter 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            "appcenter.@${sec_type}"*".name='${name}'"|"appcenter.cfg"*".name='${name}'")
                sec="${line#appcenter.}"
                sec="${sec%%.*}"
                printf '%s\n' "$sec"
                ;;
        esac
    done | head -n 1
}

delete_appcenter_sections() {
    section_type="$1"
    field_name="$2"
    field_value="$3"

    uci show appcenter 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            "appcenter.@${section_type}"*".${field_name}='${field_value}'"|"appcenter.cfg"*".${field_name}='${field_value}'")
                sec="${line#appcenter.}"
                sec="${sec%%.*}"
                printf '%s\n' "$sec"
                ;;
        esac
    done | sort -u | while IFS= read -r sec; do
        [ -n "$sec" ] || continue
        uci -q delete "appcenter.$sec" >/dev/null 2>&1 || true
    done
}

cleanup_appcenter_entry() {
    delete_appcenter_sections package name "$APP_NAME"
    delete_appcenter_sections package name "$PKG_NAME"
    delete_appcenter_sections package_list name "$APP_NAME"
    delete_appcenter_sections package_list pkg_name "$PKG_NAME"
    delete_appcenter_sections package_list parent "$APP_NAME"
    delete_appcenter_sections package_list luci_module_route "$APP_ROUTE"
    uci -q commit appcenter >/dev/null 2>&1 || true
}

set_appcenter_entry() {
    version="$(leigod_version)"
    [ -n "$version" ] || version="$APP_VERSION_DEFAULT"
    size="$(leigod_size)"

    cleanup_appcenter_entry
    pkg_sec="$(uci add appcenter package)"
    list_sec="$(uci add appcenter package_list)"

    uci set "appcenter.$pkg_sec.name=$APP_NAME"
    uci set "appcenter.$pkg_sec.version=$version"
    uci set "appcenter.$pkg_sec.size=$size"
    uci set "appcenter.$pkg_sec.status=1"
    uci set "appcenter.$pkg_sec.has_luci=1"
    uci set "appcenter.$pkg_sec.open=1"
    uci set "appcenter.$pkg_sec.icon=$APP_ICON_NAME"

    uci set "appcenter.$list_sec.name=$APP_NAME"
    uci set "appcenter.$list_sec.pkg_name=$PKG_NAME"
    uci set "appcenter.$list_sec.parent=$APP_NAME"
    uci set "appcenter.$list_sec.size=$size"
    uci set "appcenter.$list_sec.luci_module_file=$APP_CONTROLLER"
    uci set "appcenter.$list_sec.luci_module_route=$APP_ROUTE"
    uci set "appcenter.$list_sec.version=$version"
    uci set "appcenter.$list_sec.has_luci=1"
    uci set "appcenter.$list_sec.type=1"
    uci set "appcenter.$list_sec.icon=$APP_ICON_NAME"
    uci -q commit appcenter >/dev/null 2>&1 || true
}

write_leigod_icon() {
    mkdir -p "$APP_ICON_DIR"
    cat > "$APP_ICON_PATH" <<'EOF_LEIGOD_ICON'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" role="img" aria-label="Leigod">
  <defs>
    <linearGradient id="lg-bg" x1="18" y1="10" x2="110" y2="118" gradientUnits="userSpaceOnUse">
      <stop stop-color="#f7fbff"/>
      <stop offset="1" stop-color="#d7ecff"/>
    </linearGradient>
    <linearGradient id="lg-bolt" x1="48" y1="20" x2="83" y2="108" gradientUnits="userSpaceOnUse">
      <stop stop-color="#f59e0b"/>
      <stop offset=".5" stop-color="#f97316"/>
      <stop offset="1" stop-color="#ef4444"/>
    </linearGradient>
    <filter id="lg-shadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="6" stdDeviation="7" flood-color="#0f172a" flood-opacity=".22"/>
    </filter>
  </defs>
  <rect x="14" y="14" width="100" height="100" rx="24" fill="url(#lg-bg)" filter="url(#lg-shadow)"/>
  <path d="M70 16 32 74h27l-8 38 45-63H68l2-33Z" fill="url(#lg-bolt)"/>
  <path d="M72 28 47 66h22l-4 22 22-31H65l7-29Z" fill="#fff" opacity=".42"/>
  <path d="M31 83c9 9 21 14 34 14 14 0 27-6 36-16" fill="none" stroke="#38bdf8" stroke-width="7" stroke-linecap="round" opacity=".78"/>
</svg>
EOF_LEIGOD_ICON
    chmod 644 "$APP_ICON_PATH" 2>/dev/null || true
}

write_uninstall_helper() {
    cat > "$UNINSTALL_HELPER" <<'EOF_LEIGOD_UNINSTALL'
#!/bin/sh

APP_NAME="雷神加速器"
PKG_NAME="nradio-leigod"
APP_ROUTE="nradioadv/system/leigod"
APP_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/leigod.lua"
APP_VIEW="/usr/lib/lua/luci/view/nradiobridge_leigod/leigod.htm"
APP_ICON="/www/luci-static/nradio/images/icon/leigod.svg"
LEIGOD_DIR="/usr/sbin/leigod"
LEIGOD_INIT="/etc/init.d/acc"

delete_appcenter_sections() {
    section_type="$1"
    field_name="$2"
    field_value="$3"

    uci show appcenter 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            "appcenter.@${section_type}"*".${field_name}='${field_value}'"|"appcenter.cfg"*".${field_name}='${field_value}'")
                sec="${line#appcenter.}"
                sec="${sec%%.*}"
                printf '%s\n' "$sec"
                ;;
        esac
    done | sort -u | while IFS= read -r sec; do
        [ -n "$sec" ] || continue
        uci -q delete "appcenter.$sec" >/dev/null 2>&1 || true
    done
}

cleanup_appcenter_entry() {
    delete_appcenter_sections package name "$APP_NAME"
    delete_appcenter_sections package name "$PKG_NAME"
    delete_appcenter_sections package_list name "$APP_NAME"
    delete_appcenter_sections package_list pkg_name "$PKG_NAME"
    delete_appcenter_sections package_list parent "$APP_NAME"
    delete_appcenter_sections package_list luci_module_route "$APP_ROUTE"
    uci -q commit appcenter >/dev/null 2>&1 || true
}

if [ -x "$LEIGOD_INIT" ]; then
    "$LEIGOD_INIT" disable >/dev/null 2>&1 || true
    "$LEIGOD_INIT" stop >/dev/null 2>&1 || true
fi

if [ -f "$LEIGOD_DIR/leigod_uninstall.sh" ]; then
    ( cd "$LEIGOD_DIR" && sh ./leigod_uninstall.sh ) >/tmp/nradio-leigod-official-uninstall.log 2>&1 || true
else
    killall acc-gw.router.arm64 >/dev/null 2>&1 || true
    killall acc_upgrade_monitor >/dev/null 2>&1 || true
    rm -rf "$LEIGOD_DIR" /tmp/acc
    rm -f "$LEIGOD_INIT" /etc/config/accelerator
fi

cleanup_appcenter_entry
rm -f "$APP_CONTROLLER" "$APP_VIEW" "$APP_ICON"
rm -f /tmp/luci-indexcache /tmp/infocd/cache/appcenter 2>/dev/null || true
rm -f /tmp/luci-modulecache/* 2>/dev/null || true
/etc/init.d/infocd restart >/dev/null 2>&1 || true
/etc/init.d/appcenter restart >/dev/null 2>&1 || true
/etc/init.d/uhttpd reload >/dev/null 2>&1 || true

exit 0
EOF_LEIGOD_UNINSTALL
    chmod 755 "$UNINSTALL_HELPER" 2>/dev/null || true
}

patch_global_plugin_uninstall_support() {
    if [ -f "$PLUGIN_UNINSTALL_HELPER" ] && ! grep -q 'cleanup_leigod()' "$PLUGIN_UNINSTALL_HELPER" 2>/dev/null; then
        backup_file "$PLUGIN_UNINSTALL_HELPER"
        tmp_helper="/tmp/nradio-plugin-uninstall.leigod.$$"
        awk '
            /^case "\$PLUGIN" in/ && !inserted_func {
                print "cleanup_leigod() {"
                print "    /usr/libexec/nradio-leigod-uninstall"
                print "}"
                print ""
                inserted_func = 1
            }
            /fanctrl\)/ && !inserted_case {
                print "    leigod)"
                print "        cleanup_leigod"
                print "        ;;"
                inserted_case = 1
            }
            { print }
        ' "$PLUGIN_UNINSTALL_HELPER" > "$tmp_helper" && cp "$tmp_helper" "$PLUGIN_UNINSTALL_HELPER"
        rm -f "$tmp_helper"
        chmod 755 "$PLUGIN_UNINSTALL_HELPER" 2>/dev/null || true
    fi

    if [ -f "$PLUGIN_UNINSTALL_CONTROLLER" ]; then
        if ! grep -q 'plugin_uninstall", "leigod"' "$PLUGIN_UNINSTALL_CONTROLLER" 2>/dev/null; then
            backup_file "$PLUGIN_UNINSTALL_CONTROLLER"
            tmp_controller="/tmp/plugin_uninstall.leigod.entry.$$"
            awk '
                /plugin_uninstall", "fanctrl"/ && !inserted {
                    print
                    print "    entry({\"nradioadv\", \"system\", \"plugin_uninstall\", \"leigod\"}, call(\"uninstall_leigod\"), nil).leaf = true"
                    inserted = 1
                    next
                }
                { print }
            ' "$PLUGIN_UNINSTALL_CONTROLLER" > "$tmp_controller" && cp "$tmp_controller" "$PLUGIN_UNINSTALL_CONTROLLER"
            rm -f "$tmp_controller"
        fi

        if ! grep -q 'name == "雷神加速器"' "$PLUGIN_UNINSTALL_CONTROLLER" 2>/dev/null; then
            backup_file "$PLUGIN_UNINSTALL_CONTROLLER"
            tmp_controller="/tmp/plugin_uninstall.leigod.map.$$"
            awk '
                /local function plugin_from_name/ { in_plugin_from_name = 1 }
                in_plugin_from_name && /^    end$/ && !inserted {
                    print "    elseif name == \"雷神加速器\" or name == \"Leigod\" or name == \"LeigodAcc\" or name == \"leigod\" or name == \"nradio-leigod\" then"
                    print "        return \"leigod\""
                    inserted = 1
                }
                { print }
                in_plugin_from_name && /^end$/ { in_plugin_from_name = 0 }
            ' "$PLUGIN_UNINSTALL_CONTROLLER" > "$tmp_controller" && cp "$tmp_controller" "$PLUGIN_UNINSTALL_CONTROLLER"
            rm -f "$tmp_controller"
        fi

        if ! grep -q 'function uninstall_leigod()' "$PLUGIN_UNINSTALL_CONTROLLER" 2>/dev/null; then
            backup_file "$PLUGIN_UNINSTALL_CONTROLLER"
            cat >> "$PLUGIN_UNINSTALL_CONTROLLER" <<'EOF_LEIGOD_PLUGIN_UNINSTALL_LUA'

function uninstall_leigod()
    start_plugin("leigod")
end
EOF_LEIGOD_PLUGIN_UNINSTALL_LUA
        fi
    fi

    if [ -f "$APPCENTER_TEMPLATE" ] && grep -q 'function nradio_plugin_uninstall_key' "$APPCENTER_TEMPLATE" 2>/dev/null \
        && ! grep -q 'app_name == "雷神加速器"' "$APPCENTER_TEMPLATE" 2>/dev/null; then
        backup_file "$APPCENTER_TEMPLATE"
        tmp_tpl="/tmp/appcenter.leigod-uninstall.$$"
        awk '
            /function nradio_plugin_uninstall_key/ {
                in_key = 1
            }
            in_key && /return "";$/ && !inserted {
                print "        if(app_name == \"雷神加速器\" || app_name == \"Leigod\" || app_name == \"LeigodAcc\" || app_name == \"leigod\" || app_name == \"nradio-leigod\")"
                print "            return \"leigod\";"
                inserted = 1
            }
            { print }
            in_key && /^    }/ {
                in_key = 0
            }
        ' "$APPCENTER_TEMPLATE" > "$tmp_tpl" && cp "$tmp_tpl" "$APPCENTER_TEMPLATE"
        rm -f "$tmp_tpl"
    fi

    if [ -f "$APPCENTER_TEMPLATE" ] && grep -q 'open_route = "nradioadv/system/fanctrl_plus"' "$APPCENTER_TEMPLATE" 2>/dev/null \
        && ! grep -q 'db.name == "雷神加速器"' "$APPCENTER_TEMPLATE" 2>/dev/null; then
        backup_file "$APPCENTER_TEMPLATE"
        tmp_tpl="/tmp/appcenter.leigod-route.$$"
        awk '
            /open_route = "nradioadv\/system\/fanctrl_plus";/ && !inserted {
                print
                print "            else if (db.name == \"雷神加速器\" || db.name == \"Leigod\" || db.name == \"LeigodAcc\" || db.name == \"leigod\" || db.name == \"nradio-leigod\")"
                print "                open_route = \"nradioadv/system/leigod\";"
                inserted = 1
                next
            }
            { print }
        ' "$APPCENTER_TEMPLATE" > "$tmp_tpl" && cp "$tmp_tpl" "$APPCENTER_TEMPLATE"
        rm -f "$tmp_tpl"
    fi
}

write_luci_controller() {
    log "[3/6] 写入雷神状态页控制器"
    mkdir -p "$(dirname "$APP_CONTROLLER")"
    cat > "$APP_CONTROLLER" <<'EOF_LEIGOD_CONTROLLER'
module("luci.controller.nradio_adv.leigod", package.seeall)

function index()
    local page = entry({"nradioadv", "system", "leigod"}, template("nradiobridge_leigod/leigod"), _("LeigodAcc"), 91)
    page.show = true
    entry({"nradioadv", "system", "leigod", "status"}, call("action_status"), nil).leaf = true
    entry({"nradioadv", "system", "leigod", "uninstall"}, call("action_uninstall"), nil).leaf = true
end

local function trim(value)
    value = tostring(value or "")
    local out = value:gsub("^%s+", ""):gsub("%s+$", "")
    return out
end

local function readfile(path)
    local fp = io.open(path, "r")
    local data
    if not fp then
        return ""
    end
    data = fp:read("*a") or ""
    fp:close()
    return data
end

local function exec(cmd)
    local sys = require "luci.sys"
    return trim(sys.exec(cmd .. " 2>/dev/null"))
end

local function has_file(path)
    local fs = require "nixio.fs"
    return fs.access(path) and true or false
end

local function write_json(data)
    local http = require "luci.http"
    http.prepare_content("application/json")
    if type(http.write_json) == "function" then
        http.write_json(data)
    else
        http.write("{}")
    end
end

local function listen_line(port)
    return exec("netstat -lntup | grep ':" .. port .. " ' | head -n 1")
end

local function conn_count(pattern)
    return tonumber(exec("netstat -tunap | grep " .. pattern .. " | grep ESTABLISHED | wc -l")) or 0
end

local function detect_mode()
    local tun = exec("uci -q get accelerator.base.tun")
    if tun == "1" then
        return "TUN"
    elseif tun == "0" then
        return "Tproxy"
    end

    if exec("grep -q -- '--mode tun' /etc/init.d/acc && echo yes || echo no") == "yes" then
        return "TUN"
    end
    if has_file("/etc/init.d/acc") then
        return "Tproxy"
    end
    return "UNKNOWN"
end

local function tail_log()
    local log = exec("ls -t /tmp/acc/acc-gw.log-* 2>/dev/null | head -n 1")
    if log == "" then
        return ""
    end
    return exec("tail -n 12 " .. log)
end

function action_status()
    local installed = has_file("/usr/sbin/leigod/acc-gw.router.arm64")
        or has_file("/usr/sbin/leigod/acc-gw.router.aarch64")
        or exec("ls /usr/sbin/leigod/acc-gw.router.* 2>/dev/null | head -n 1") ~= ""
    local init_exists = has_file("/etc/init.d/acc")
    local acc_pid = exec("pidof acc-gw.router.arm64")
    if acc_pid == "" then
        acc_pid = exec("pidof acc-gw.router.aarch64")
    end
    if acc_pid == "" then
        acc_pid = exec("ps | grep 'acc-gw.router' | grep -v grep | awk '{print $1}'")
    end
    local acc_runner_pid = exec("ps | grep 'acc-gw.router' | grep ' -r acc ' | grep -v grep | awk '{print $1}'")
    local upgrade_pid = exec("pidof acc_upgrade_monitor")
    local web5588 = listen_line("5588")
    local port10001 = listen_line("10001")
    local udp6066 = exec("netstat -lunp | grep ':6066 ' | head -n 1")
    local service_enabled = false
    local service_running = acc_pid ~= ""
    local accelerating = acc_runner_pid ~= ""

    if init_exists then
        service_enabled = exec("/etc/init.d/acc enabled && echo yes || echo no") == "yes"
    end

    write_json({
        installed = installed,
        service_enabled = service_enabled,
        service_running = service_running,
        accelerating = accelerating,
        init_exists = init_exists,
        acc_pid = acc_pid,
        acc_runner_pid = acc_runner_pid,
        upgrade_pid = upgrade_pid,
        web5588 = web5588 ~= "",
        web5588_line = web5588,
        port10001 = port10001 ~= "",
        port10001_line = port10001,
        udp6066 = udp6066 ~= "",
        udp6066_line = udp6066,
        mode = detect_mode(),
        acc_conn = conn_count("acc-gw.router"),
        log_tail = tail_log()
    })
end

function action_uninstall()
    os.execute("/usr/libexec/nradio-leigod-uninstall >/tmp/nradio-leigod-uninstall.log 2>&1 &")
    write_json({ ok = true, msg = "已开始卸载雷神加速器" })
end
EOF_LEIGOD_CONTROLLER
    chmod 644 "$APP_CONTROLLER" 2>/dev/null || true
}

write_luci_view() {
    log "[4/6] 写入雷神状态页"
    mkdir -p "$(dirname "$APP_VIEW")"
    cat > "$APP_VIEW" <<'EOF_LEIGOD_VIEW'
<%+header%>
<style>
.lg-wrap{min-height:560px;padding:26px;color:#f8fbff;background:linear-gradient(135deg,#121827,#1f273c 58%,#111827);box-sizing:border-box}
.lg-head{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-bottom:18px}
.lg-title{font-size:28px;font-weight:900;letter-spacing:0}.lg-sub{margin-top:6px;color:#c6d3e1;font-size:13px}
.lg-pill{display:inline-flex;align-items:center;gap:8px;border:1px solid rgba(248,181,74,.38);border-radius:999px;padding:8px 12px;background:rgba(245,158,11,.13);font-weight:900}
.lg-dot{width:8px;height:8px;border-radius:50%;background:#94a3b8;box-shadow:0 0 10px currentColor}.lg-dot.ok{background:#22c55e;color:#22c55e}.lg-dot.warn{background:#f59e0b;color:#f59e0b}.lg-dot.bad{background:#ef4444;color:#ef4444}
.lg-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin:18px 0}.lg-card{border:1px solid rgba(255,255,255,.10);border-radius:14px;padding:16px;background:linear-gradient(145deg,rgba(255,255,255,.075),rgba(255,255,255,.032));box-shadow:inset 0 1px 0 rgba(255,255,255,.08),0 14px 30px rgba(0,0,0,.18)}
.lg-label{color:#fcd38a;font-size:12px;font-weight:900}.lg-value{margin-top:8px;font-size:22px;font-weight:900;color:#fff;word-break:break-all}
.lg-row{display:grid;grid-template-columns:180px 1fr;gap:10px;padding:11px 0;border-bottom:1px solid rgba(255,255,255,.08);color:#d8e2f0}.lg-row:last-child{border-bottom:0}.lg-k{color:#fcd38a;font-weight:900}.lg-v{font-weight:800;word-break:break-all}
.lg-actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:18px}.lg-btn{border:1px solid rgba(248,181,74,.42);border-radius:10px;background:rgba(245,158,11,.15);color:#fff7ed;font-weight:900;padding:10px 16px;cursor:pointer}.lg-btn.primary{background:linear-gradient(135deg,#f59e0b,#f97316);color:#111827}.lg-btn.danger{border-color:rgba(248,113,113,.50);background:rgba(239,68,68,.18)}
.lg-log{white-space:pre-wrap;line-height:1.55;font-family:monospace;font-size:12px;max-height:180px;overflow:auto;color:#dbeafe}.lg-note{margin-top:16px;color:#c6d3e1;line-height:1.7;font-size:13px}.lg-note strong{color:#fff}
@media(max-width:900px){.lg-grid{grid-template-columns:1fr}.lg-row{grid-template-columns:1fr}.lg-head{align-items:flex-start;flex-direction:column}}
</style>
<div class="lg-wrap">
  <div class="lg-head">
    <div>
      <div class="lg-title">雷神加速器</div>
      <div class="lg-sub">只读监听雷神后台状态；绑定设备和选择游戏仍在雷神 App 或雷神自带 Web 页面完成。</div>
    </div>
    <div class="lg-pill"><span id="lg-dot" class="lg-dot"></span><span id="lg-status">读取中</span></div>
  </div>

  <div class="lg-grid">
    <div class="lg-card"><div class="lg-label">服务状态</div><div id="lg-main" class="lg-value">-</div></div>
    <div class="lg-card"><div class="lg-label">代理连接</div><div id="lg-conn" class="lg-value">-</div></div>
    <div class="lg-card"><div class="lg-label">运行模式</div><div id="lg-mode" class="lg-value">-</div></div>
  </div>

  <div class="lg-card">
    <div class="lg-row"><div class="lg-k">安装目录</div><div id="lg-installed" class="lg-v">-</div></div>
    <div class="lg-row"><div class="lg-k">acc-gw</div><div id="lg-acc" class="lg-v">-</div></div>
    <div class="lg-row"><div class="lg-k">升级监控</div><div id="lg-upgrade" class="lg-v">-</div></div>
    <div class="lg-row"><div class="lg-k">5588 Web</div><div id="lg-web" class="lg-v">-</div></div>
    <div class="lg-row"><div class="lg-k">10001 服务端口</div><div id="lg-port" class="lg-v">-</div></div>
    <div class="lg-row"><div class="lg-k">6066 UDP</div><div id="lg-udp" class="lg-v">-</div></div>
    <div class="lg-row"><div class="lg-k">启动脚本</div><div id="lg-init" class="lg-v">-</div></div>
    <div class="lg-row"><div class="lg-k">最近日志</div><div id="lg-log" class="lg-v lg-log">-</div></div>
  </div>

  <div class="lg-actions">
    <button class="lg-btn" onclick="lgRefresh()">刷新状态</button>
    <button class="lg-btn primary" onclick="lgOpenWeb()">打开雷神 Web</button>
    <button class="lg-btn danger" onclick="lgUninstall()">卸载雷神加速器</button>
  </div>

  <div class="lg-note">
    <strong>字段说明：</strong>代理连接统计 acc-gw.router 当前 ESTABLISHED 连接数量；5588 是雷神自带 Web 入口；10001/6066 为雷神后台服务端口。
  </div>
</div>
<script>
var lgBase = '<%=controller%>nradioadv/system/leigod';
function lgText(id, text){ var el=document.getElementById(id); if(el) el.textContent = text || '-'; }
function lgBool(value){ return value ? '正常' : '未检测到'; }
function lgApply(data){
  var dot = document.getElementById('lg-dot');
  var running = !!data.service_running;
  var accelerating = !!data.accelerating;
  var installed = !!data.installed;
  var statusText = accelerating ? '加速中' : (running ? '插件在线' : (installed ? '已安装未在线' : '未安装'));
  lgText('lg-status', statusText);
  lgText('lg-main', statusText);
  lgText('lg-conn', String(data.acc_conn || 0));
  lgText('lg-mode', data.mode || 'UNKNOWN');
  lgText('lg-installed', installed ? '已安装' : '未安装');
  lgText('lg-acc', accelerating ? ('加速中 / ' + (data.acc_runner_pid || '-')) : (running ? ('插件在线 / ' + (data.acc_pid || '-')) : '未运行'));
  lgText('lg-upgrade', data.upgrade_pid ? ('运行中 / ' + data.upgrade_pid) : '未运行');
  lgText('lg-web', data.web5588 ? data.web5588_line : '未监听');
  lgText('lg-port', data.port10001 ? data.port10001_line : '未监听');
  lgText('lg-udp', data.udp6066 ? data.udp6066_line : '未监听');
  lgText('lg-init', data.init_exists ? (data.service_enabled ? '已启用' : '未启用') : '缺失');
  lgText('lg-log', data.log_tail || '-');
  if(dot){
    dot.className = 'lg-dot ' + (running ? 'ok' : (installed ? 'warn' : 'bad'));
  }
}
function lgRefresh(){
  var xhr = new XMLHttpRequest();
  xhr.open('GET', lgBase + '/status?_=' + Date.now(), true);
  xhr.onreadystatechange = function(){
    if(xhr.readyState === 4){
      try { lgApply(JSON.parse(xhr.responseText || '{}')); }
      catch(e){ lgText('lg-status', '读取失败'); }
    }
  };
  xhr.send(null);
}
function lgOpenWeb(){
  window.open(window.location.protocol + '//' + window.location.hostname + ':5588/', '_blank');
}
function lgUninstall(){
  if(!confirm('确认卸载雷神加速器并移除应用商店入口吗？')) return;
  var xhr = new XMLHttpRequest();
  xhr.open('POST', lgBase + '/uninstall', true);
  xhr.onreadystatechange = function(){
    if(xhr.readyState === 4){
      alert('已开始卸载，稍后刷新应用商店。');
    }
  };
  xhr.send('');
}
lgRefresh();
setInterval(lgRefresh, 5000);
</script>
<%+footer%>
EOF_LEIGOD_VIEW
    chmod 644 "$APP_VIEW" 2>/dev/null || true
}

install_appcenter_assets() {
    log "[2/6] 写入雷神应用商店接入文件"
    write_leigod_icon
    write_uninstall_helper
    patch_global_plugin_uninstall_support
    write_luci_controller
    write_luci_view
}

attach_installed_leigod() {
    need_root
    require_nradio_appcenter
    is_leigod_installed || die "未检测到 $LEIGOD_DIR/acc-gw.router.*，请先安装雷神加速器"

    log "开始接入已安装的雷神加速器"
    install_appcenter_assets
    log "[5/6] 写入应用商店卡片"
    set_appcenter_entry
    log "[6/6] 刷新 LuCI / 应用商店缓存"
    refresh_luci_appcenter
    log "完成：雷神加速器已接入 NRadio 应用商店"
}

install_dependencies_and_core() {
    need_root
    require_nradio_appcenter

    cat <<'EOF_LEIGOD_RISK'
高风险提示：
雷神管理器安装会执行 opkg update，并可能安装/修改 iptables、tproxy、ipset、tc-full、conntrack、UPnP、/etc/init.d/acc 等组件。
该操作比普通应用商店接入更重，可能影响 OpenClash、UPnP、IPv6 或现有防火墙行为。
已经安装雷神时，建议只使用“检测已安装并接入应用商店”。
EOF_LEIGOD_RISK
    confirm_or_exit "确认仍要安装雷神官方脚本并接入应用商店吗？"

    command -v opkg >/dev/null 2>&1 || die "系统没有 opkg，无法自动安装雷神依赖"
    opkg update || die "opkg update 失败"
    for pkg in curl libpcap iptables kmod-ipt-nat iptables-mod-tproxy kmod-ipt-ipset ipset kmod-tun kmod-ipt-tproxy kmod-netem tc-full conntrack miniupnpd luci-app-upnp; do
        if ! opkg list-installed 2>/dev/null | grep -q "^$pkg "; then
            log "安装依赖：$pkg"
            opkg install "$pkg" || true
        fi
    done

    if [ -f /etc/config/upnpd ]; then
        uci set upnpd.config.enabled='1' >/dev/null 2>&1 || true
        uci commit upnpd >/dev/null 2>&1 || true
        /etc/init.d/miniupnpd start >/dev/null 2>&1 || true
        /etc/init.d/miniupnpd enable >/dev/null 2>&1 || true
    fi

    download_url "$LEIGOD_OFFICIAL_INSTALL_URL" "$LEIGOD_INSTALLER" || die "下载雷神官方安装脚本失败：$LEIGOD_OFFICIAL_INSTALL_URL"
    grep -q 'leigod\|acc-gw\|accelerator' "$LEIGOD_INSTALLER" 2>/dev/null || die "雷神官方安装脚本内容异常，已停止执行"
    sh "$LEIGOD_INSTALLER" || die "雷神官方安装脚本执行失败"
    sleep 2
    is_leigod_installed || die "安装后仍未检测到 $LEIGOD_DIR/acc-gw.router.*"

    attach_installed_leigod
}

show_status() {
    need_root
    log "$SCRIPT_TITLE $SCRIPT_VERSION"
    log "安装目录: $LEIGOD_DIR"
    if is_leigod_installed; then
        log "安装状态: 已安装"
    else
        log "安装状态: 未安装"
    fi
    log "启动脚本: $LEIGOD_INIT"
    if [ -x "$LEIGOD_INIT" ]; then
        "$LEIGOD_INIT" enabled >/dev/null 2>&1 && log "服务启用: 是" || log "服务启用: 否"
    else
        log "服务启用: 启动脚本缺失"
    fi
    log "acc-gw PID: $(pidof acc-gw.router.arm64 2>/dev/null || true)"
    log "升级监控 PID: $(pidof acc_upgrade_monitor 2>/dev/null || true)"
    log "监听端口:"
    netstat -lntup 2>/dev/null | grep -E ':5588 |:10001 ' || true
    netstat -lunp 2>/dev/null | grep ':6066 ' || true
    log "代理连接数: $(netstat -tunap 2>/dev/null | grep acc-gw.router | grep ESTABLISHED | wc -l)"
}

uninstall_leigod() {
    need_root
    confirm_or_exit "确认卸载雷神加速器并移除应用商店入口吗？"
    if [ -x "$UNINSTALL_HELPER" ]; then
        "$UNINSTALL_HELPER"
    else
        write_uninstall_helper
        "$UNINSTALL_HELPER"
    fi
    log "已执行卸载流程"
}

main_menu() {
    log "$SCRIPT_TITLE $SCRIPT_VERSION"
    log "1. 检测已安装雷神并接入应用商店"
    log "2. 安装雷神官方脚本并接入应用商店"
    log "3. 查看雷神状态"
    log "4. 卸载雷神并移除应用商店入口"
    printf '请输入 1、2、3 或 4: '
    read_line || die "input cancelled"

    case "$READ_RESULT" in
        1)
            attach_installed_leigod
            ;;
        2)
            install_dependencies_and_core
            ;;
        3)
            show_status
            ;;
        4)
            uninstall_leigod
            ;;
        *)
            die "无效选择：$READ_RESULT"
            ;;
    esac
}

main_menu "$@"
