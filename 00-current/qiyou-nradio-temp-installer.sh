#!/bin/sh

SCRIPT_TITLE="NRadio 奇游联机宝临时接入助手"
SCRIPT_VERSION="temp-20260427"

APP_NAME="奇游联机宝"
PKG_NAME="nradio-qiyou"
APP_VERSION_DEFAULT="1.2.1"
APP_SIZE_DEFAULT="QiYou"
APP_ROUTE="nradioadv/system/qiyou"
APP_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/qiyou.lua"
APP_VIEW="/usr/lib/lua/luci/view/nradiobridge_qiyou/qiyou.htm"
APP_ICON_DIR="/www/luci-static/nradio/images/icon"
APP_ICON_NAME="qiyou.svg"
APP_ICON_PATH="$APP_ICON_DIR/$APP_ICON_NAME"
APPCENTER_CONFIG="/etc/config/appcenter"
APPCENTER_TEMPLATE="/usr/lib/lua/luci/view/nradio_appcenter/appcenter.htm"
UNINSTALL_HELPER="/usr/libexec/nradio-qiyou-uninstall"
PLUGIN_UNINSTALL_HELPER="/usr/libexec/nradio-plugin-uninstall"
PLUGIN_UNINSTALL_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/plugin_uninstall.lua"
QY_INSTALL_URL="http://sd.qiyou.cn"
QY_INSTALLER="/tmp/qiyou-install.sh"

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
        curl -s -k -L -m 120 "$url" -o "$out" 2>/dev/null || true
    fi
    if [ ! -s "$out" ] && command -v wget >/dev/null 2>&1; then
        wget -q -T 120 "$url" -O "$out" --no-check-certificate 2>/dev/null || true
    fi
    [ -s "$out" ]
}

backup_file() {
    file="$1"
    [ -f "$file" ] || return 0
    stamp="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo qiyou)"
    cp "$file" "$file.bak-qiyou-$stamp" 2>/dev/null || true
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

install_dependencies() {
    log "[1/7] 安装奇游所需依赖"
    if ! command -v opkg >/dev/null 2>&1; then
        die "系统没有 opkg，无法按奇游官方方式安装依赖"
    fi
    opkg update || die "opkg update 失败"
    opkg install curl kmod-tun ip-full || die "安装 curl/kmod-tun/ip-full 失败"
}

install_qiyou_core() {
    log "[2/7] 下载并执行奇游官方安装脚本"
    download_url "$QY_INSTALL_URL" "$QY_INSTALLER" || die "下载奇游入口脚本失败：$QY_INSTALL_URL"
    grep -q 'qyplug.sh' "$QY_INSTALLER" 2>/dev/null || die "奇游入口脚本内容异常，已停止执行"
    sh "$QY_INSTALLER" || die "奇游官方安装脚本执行失败"
    sleep 2
    [ -f /etc/qy/qy_acc.sh ] || die "奇游安装后未发现 /etc/qy/qy_acc.sh"
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
                break
                ;;
        esac
    done
}

delete_appcenter_sections() {
    section_type="$1"
    field_name="$2"
    field_value="$3"

    [ -n "$field_value" ] || return 0
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

qiyou_version() {
    version="$(sed -n 's/^VERSION=//p' /tmp/qy/etc/PKG_INFO 2>/dev/null | head -n 1)"
    [ -n "$version" ] || version="$APP_VERSION_DEFAULT"
    printf '%s\n' "$version"
}

qiyou_size() {
    size_kb="$(du -sk /tmp/qy /etc/qy 2>/dev/null | awk '{s+=$1} END{if(s>0) printf "%s KB", s}')"
    [ -n "$size_kb" ] || size_kb="$APP_SIZE_DEFAULT"
    printf '%s\n' "$size_kb"
}

set_appcenter_entry() {
    version="$(qiyou_version)"
    size="$(qiyou_size)"

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

write_qiyou_icon() {
    log "[3/7] 写入应用商店图标"
    mkdir -p "$APP_ICON_DIR"
    cat > "$APP_ICON_PATH" <<'EOF_QIYOU_ICON'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="QiYou"><defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#eef8ff"/><stop offset="100%" stop-color="#cbeaff"/></linearGradient><linearGradient id="speed" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#22c55e"/><stop offset="100%" stop-color="#0ea5e9"/></linearGradient><filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="26" stdDeviation="22" flood-color="#8db7dd" flood-opacity="0.28"/></filter></defs><rect x="84" y="84" width="856" height="856" rx="188" fill="url(#bg)" stroke="#9fd7ff" stroke-width="18" filter="url(#shadow)"/><rect x="162" y="162" width="700" height="700" rx="154" fill="#f8fcff" stroke="#d8eefc" stroke-width="12"/><path d="M268 612a244 244 0 0 1 488 0" fill="none" stroke="#d7ecfb" stroke-width="60" stroke-linecap="round"/><path d="M268 612a244 244 0 0 1 388-197" fill="none" stroke="url(#speed)" stroke-width="60" stroke-linecap="round"/><circle cx="512" cy="612" r="86" fill="url(#speed)"/><path d="M512 612L676 448" stroke="#0f3554" stroke-width="46" stroke-linecap="round"/><circle cx="512" cy="612" r="28" fill="#eef8ff"/><path d="M338 706h348" stroke="#9fd7ff" stroke-width="36" stroke-linecap="round"/></svg>
EOF_QIYOU_ICON
    chmod 644 "$APP_ICON_PATH" 2>/dev/null || true
}

write_uninstall_helper() {
    mkdir -p "$(dirname "$UNINSTALL_HELPER")"
    cat > "$UNINSTALL_HELPER" <<'EOF_QIYOU_UNINSTALL'
#!/bin/sh

APP_NAME="奇游联机宝"
PKG_NAME="nradio-qiyou"
APP_ROUTE="nradioadv/system/qiyou"
APP_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/qiyou.lua"
APP_VIEW="/usr/lib/lua/luci/view/nradiobridge_qiyou/qiyou.htm"
APP_ICON="/www/luci-static/nradio/images/icon/qiyou.svg"

delete_appcenter_sections() {
    section_type="$1"
    field_name="$2"
    field_value="$3"
    [ -n "$field_value" ] || return 0
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

/etc/qy/qy_acc.sh stop >/dev/null 2>&1 || true
[ -x /tmp/qy/init.sh ] && /tmp/qy/init.sh stop >/dev/null 2>&1 || true
killall -9 qy_proxy qy_mosq qy_acc >/dev/null 2>&1 || true
rm -rf /tmp/qy /etc/qy /tmp/qyplug.sh /tmp/qyplug.ret /tmp/qyplug.pid /tmp/qyplug.get /tmp/qiyou-install.sh
rm -f /etc/init.d/qy_acc.boot /etc/rc.d/S99qy_acc.boot
rm -f "$APP_CONTROLLER" "$APP_VIEW" "$APP_ICON"
cleanup_appcenter_entry
rm -f /tmp/luci-indexcache /tmp/infocd/cache/appcenter 2>/dev/null || true
rm -f /tmp/luci-modulecache/* 2>/dev/null || true
/etc/init.d/infocd restart >/dev/null 2>&1 || true
/etc/init.d/appcenter restart >/dev/null 2>&1 || true
/etc/init.d/uhttpd reload >/dev/null 2>&1 || true
exit 0
EOF_QIYOU_UNINSTALL
    chmod 755 "$UNINSTALL_HELPER"
}

patch_global_plugin_uninstall_support() {
    log "[4/7] 接入应用商店原生卸载链"

    if [ -f "$PLUGIN_UNINSTALL_HELPER" ] && ! grep -q 'cleanup_qiyou()' "$PLUGIN_UNINSTALL_HELPER" 2>/dev/null; then
        backup_file "$PLUGIN_UNINSTALL_HELPER"
        tmp_helper="/tmp/nradio-plugin-uninstall.qiyou.$$"
        awk '
            /^case "\$plugin" in$/ && !inserted {
                print "cleanup_qiyou() {"
                print "    /usr/libexec/nradio-qiyou-uninstall"
                print "}"
                print ""
                inserted = 1
            }
            /^    fanctrl\)$/ && !case_inserted {
                print "    qiyou)"
                print "        cleanup_qiyou"
                print "        ;;"
                case_inserted = 1
            }
            { print }
        ' "$PLUGIN_UNINSTALL_HELPER" > "$tmp_helper" && cp "$tmp_helper" "$PLUGIN_UNINSTALL_HELPER"
        rm -f "$tmp_helper"
        chmod 755 "$PLUGIN_UNINSTALL_HELPER" 2>/dev/null || true
    fi

    if [ -f "$PLUGIN_UNINSTALL_CONTROLLER" ]; then
        if ! grep -q 'plugin_uninstall", "qiyou"' "$PLUGIN_UNINSTALL_CONTROLLER" 2>/dev/null; then
            backup_file "$PLUGIN_UNINSTALL_CONTROLLER"
            tmp_controller="/tmp/plugin_uninstall.qiyou.entry.$$"
            awk '
                /plugin_uninstall", "fanctrl"/ && !inserted {
                    print
                    print "    entry({\"nradioadv\", \"system\", \"plugin_uninstall\", \"qiyou\"}, call(\"uninstall_qiyou\"), nil, 105).leaf = true"
                    inserted = 1
                    next
                }
                { print }
            ' "$PLUGIN_UNINSTALL_CONTROLLER" > "$tmp_controller" && cp "$tmp_controller" "$PLUGIN_UNINSTALL_CONTROLLER"
            rm -f "$tmp_controller"
        fi
        if ! grep -q 'name == "奇游联机宝"' "$PLUGIN_UNINSTALL_CONTROLLER" 2>/dev/null; then
            backup_file "$PLUGIN_UNINSTALL_CONTROLLER"
            tmp_controller="/tmp/plugin_uninstall.qiyou.map.$$"
            awk '
                /local function plugin_from_name/ {
                    in_plugin_from_name = 1
                }
                in_plugin_from_name && /^    end$/ && !inserted {
                    print "    elseif name == \"奇游联机宝\" or name == \"QiYou\" or name == \"qiyou\" or name == \"nradio-qiyou\" then"
                    print "        return \"qiyou\""
                    inserted = 1
                }
                { print }
                in_plugin_from_name && /^end$/ {
                    in_plugin_from_name = 0
                }
            ' "$PLUGIN_UNINSTALL_CONTROLLER" > "$tmp_controller" && cp "$tmp_controller" "$PLUGIN_UNINSTALL_CONTROLLER"
            rm -f "$tmp_controller"
        fi
        if ! grep -q 'function uninstall_qiyou()' "$PLUGIN_UNINSTALL_CONTROLLER" 2>/dev/null; then
            backup_file "$PLUGIN_UNINSTALL_CONTROLLER"
            cat >> "$PLUGIN_UNINSTALL_CONTROLLER" <<'EOF_QIYOU_PLUGIN_UNINSTALL_LUA'

function uninstall_qiyou()
    start_plugin("qiyou")
end
EOF_QIYOU_PLUGIN_UNINSTALL_LUA
        fi
    fi

    if [ -f "$APPCENTER_TEMPLATE" ] && grep -q 'function nradio_plugin_uninstall_key' "$APPCENTER_TEMPLATE" 2>/dev/null \
        && ! grep -q 'app_name == "奇游联机宝"' "$APPCENTER_TEMPLATE" 2>/dev/null; then
        backup_file "$APPCENTER_TEMPLATE"
        tmp_tpl="/tmp/appcenter.qiyou-uninstall.$$"
        awk '
            /function nradio_plugin_uninstall_key/ {
                in_key = 1
            }
            in_key && /return "";$/ && !inserted {
                print "        if(app_name == \"奇游联机宝\" || app_name == \"QiYou\" || app_name == \"qiyou\" || app_name == \"nradio-qiyou\")"
                print "            return \"qiyou\";"
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
        && ! grep -q 'db.name == "奇游联机宝"' "$APPCENTER_TEMPLATE" 2>/dev/null; then
        backup_file "$APPCENTER_TEMPLATE"
        tmp_tpl="/tmp/appcenter.qiyou-route.$$"
        awk '
            /open_route = "nradioadv\/system\/fanctrl_plus";/ && !inserted {
                print
                print "            else if (db.name == \"奇游联机宝\" || db.name == \"QiYou\" || db.name == \"qiyou\" || db.name == \"nradio-qiyou\")"
                print "                open_route = \"nradioadv/system/qiyou\";"
                inserted = 1
                next
            }
            { print }
        ' "$APPCENTER_TEMPLATE" > "$tmp_tpl" && cp "$tmp_tpl" "$APPCENTER_TEMPLATE"
        rm -f "$tmp_tpl"
    fi
}

write_luci_controller() {
    log "[5/7] 写入奇游状态页控制器"
    mkdir -p "$(dirname "$APP_CONTROLLER")"
    cat > "$APP_CONTROLLER" <<'EOF_QIYOU_CONTROLLER'
module("luci.controller.nradio_adv.qiyou", package.seeall)

function index()
    local page = entry({"nradioadv", "system", "qiyou"}, template("nradiobridge_qiyou/qiyou"), _("QiYou"), 90)
    page.show = true
    entry({"nradioadv", "system", "qiyou", "status"}, call("action_status"), nil).leaf = true
    entry({"nradioadv", "system", "qiyou", "uninstall"}, call("action_uninstall"), nil).leaf = true
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

local function pkg_info()
    local info = {}
    for line in readfile("/tmp/qy/etc/PKG_INFO"):gmatch("[^\r\n]+") do
        local key, value = line:match("^([A-Z0-9_]+)=(.*)$")
        if key then
            info[key] = value
        end
    end
    return info
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

function action_status()
    local fs = require "nixio.fs"
    local installed = fs.access("/etc/qy/qy_acc.sh") and true or false
    local status = "NOT_INSTALLED"
    local info = pkg_info()
    local qy_acc = exec("pidof qy_acc")
    local qy_mosq = exec("pidof qy_mosq")
    local qy_proxy = exec("pidof qy_proxy")
    local proxy_conn = tonumber(exec("netstat -tunap | grep qy_proxy | grep ESTABLISHED | wc -l")) or 0
    local proxy_listen = exec("netstat -lntup | grep qy_proxy | head -n 1")
    local cloud_conn = tonumber(exec("netstat -tunap | grep qy_acc | grep ESTABLISHED | wc -l")) or 0

    if installed then
        status = exec("/etc/qy/qy_acc.sh status")
        if status == "" then
            status = "UNKNOWN"
        end
    end

    write_json({
        installed = installed,
        status = status,
        ret = trim(readfile("/tmp/qyplug.ret")),
        mode = info.MODE or "",
        version = info.VERSION or "",
        date = info.DATE or "",
        pver = info.PVER or "",
        qy_acc = qy_acc ~= "",
        qy_mosq = qy_mosq ~= "",
        qy_proxy = qy_proxy ~= "",
        qy_acc_pid = qy_acc,
        qy_mosq_pid = qy_mosq,
        qy_proxy_pid = qy_proxy,
        proxy_conn = proxy_conn,
        proxy_listen = proxy_listen,
        cloud_conn = cloud_conn
    })
end

function action_uninstall()
    os.execute("/usr/libexec/nradio-qiyou-uninstall >/tmp/nradio-qiyou-uninstall.log 2>&1 &")
    write_json({ ok = true, msg = "已开始卸载奇游联机宝" })
end
EOF_QIYOU_CONTROLLER
    chmod 644 "$APP_CONTROLLER" 2>/dev/null || true
}

write_luci_view() {
    log "[6/7] 写入奇游状态页"
    mkdir -p "$(dirname "$APP_VIEW")"
    cat > "$APP_VIEW" <<'EOF_QIYOU_VIEW'
<%+header%>
<style>
.qy-wrap{min-height:520px;padding:26px;color:#eef8ff;background:linear-gradient(135deg,#0b1724,#10283a 58%,#0b1724);box-sizing:border-box}
.qy-head{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-bottom:18px}
.qy-title{font-size:28px;font-weight:900;letter-spacing:0}
.qy-sub{margin-top:6px;color:#b8d7ea;font-size:13px}
.qy-pill{display:inline-flex;align-items:center;gap:8px;border:1px solid rgba(125,211,252,.32);border-radius:999px;padding:8px 12px;background:rgba(14,165,233,.12);font-weight:800}
.qy-dot{width:8px;height:8px;border-radius:50%;background:#94a3b8;box-shadow:0 0 10px currentColor}
.qy-dot.boosting{background:#22c55e;color:#22c55e}.qy-dot.running{background:#38bdf8;color:#38bdf8}.qy-dot.off{background:#f97316;color:#f97316}
.qy-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin:18px 0}
.qy-card{border:1px solid rgba(255,255,255,.10);border-radius:14px;padding:16px;background:linear-gradient(145deg,rgba(255,255,255,.08),rgba(255,255,255,.03));box-shadow:inset 0 1px 0 rgba(255,255,255,.08),0 14px 30px rgba(0,0,0,.18)}
.qy-label{color:#9ec6da;font-size:12px;font-weight:800}.qy-value{margin-top:8px;font-size:22px;font-weight:900;color:#fff;word-break:break-all}
.qy-row{display:grid;grid-template-columns:190px 1fr;gap:10px;padding:11px 0;border-bottom:1px solid rgba(255,255,255,.08);color:#cfe7f5}
.qy-row:last-child{border-bottom:0}.qy-k{color:#9ec6da;font-weight:800}.qy-v{font-weight:800;word-break:break-all}
.qy-actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:18px}.qy-btn{border:1px solid rgba(125,211,252,.34);border-radius:10px;background:rgba(14,165,233,.16);color:#eef8ff;font-weight:900;padding:10px 16px;cursor:pointer}.qy-btn.danger{border-color:rgba(248,113,113,.48);background:rgba(239,68,68,.18)}
.qy-note{margin-top:16px;color:#b8d7ea;line-height:1.7;font-size:13px}.qy-note strong{color:#fff}
@media(max-width:900px){.qy-grid{grid-template-columns:1fr}.qy-row{grid-template-columns:1fr}.qy-head{align-items:flex-start;flex-direction:column}}
</style>
<div class="qy-wrap">
  <div class="qy-head">
    <div>
      <div class="qy-title">奇游联机宝</div>
      <div class="qy-sub">只读监听奇游后台状态，绑定和选择游戏仍在奇游联机宝 App 内完成。</div>
    </div>
    <div class="qy-pill"><span id="qy-dot" class="qy-dot"></span><span id="qy-status">读取中</span></div>
  </div>

  <div class="qy-grid">
    <div class="qy-card"><div class="qy-label">插件状态</div><div id="qy-main" class="qy-value">-</div></div>
    <div class="qy-card"><div class="qy-label">实际代理连接</div><div id="qy-proxy-conn" class="qy-value">-</div></div>
    <div class="qy-card"><div class="qy-label">云端连接</div><div id="qy-cloud-conn" class="qy-value">-</div></div>
  </div>

  <div class="qy-card">
    <div class="qy-row"><div class="qy-k">安装返回</div><div id="qy-ret" class="qy-v">-</div></div>
    <div class="qy-row"><div class="qy-k">qy_acc</div><div id="qy-acc" class="qy-v">-</div></div>
    <div class="qy-row"><div class="qy-k">qy_mosq</div><div id="qy-mosq" class="qy-v">-</div></div>
    <div class="qy-row"><div class="qy-k">qy_proxy</div><div id="qy-proxy" class="qy-v">-</div></div>
    <div class="qy-row"><div class="qy-k">包信息</div><div id="qy-pkg" class="qy-v">-</div></div>
    <div class="qy-row"><div class="qy-k">代理监听</div><div id="qy-listen" class="qy-v">-</div></div>
  </div>

  <div class="qy-actions">
    <button class="qy-btn" onclick="qyRefresh()">刷新状态</button>
    <button class="qy-btn danger" onclick="qyUninstall()">卸载奇游联机宝</button>
  </div>

  <div class="qy-note">
    <strong>状态解释：</strong>BOOSTING 表示正在加速；RUNNING 表示插件在线但未开启加速；qy_proxy 存在且有外部连接时，通常代表存在实际加速代理流量。
  </div>
</div>
<script>
var qyBase = '<%=controller%>nradioadv/system/qiyou';
function qyText(id, text){ var el=document.getElementById(id); if(el) el.textContent = text || '-'; }
function qyBool(value, pid){ return value ? ('运行中' + (pid ? ' / ' + pid : '')) : '未运行'; }
function qyApply(data){
  var st = data.status || 'UNKNOWN';
  var dot = document.getElementById('qy-dot');
  qyText('qy-status', st);
  qyText('qy-main', st === 'BOOSTING' ? '正在加速' : (st === 'RUNNING' ? '插件在线' : st));
  qyText('qy-proxy-conn', String(data.proxy_conn || 0));
  qyText('qy-cloud-conn', String(data.cloud_conn || 0));
  qyText('qy-ret', data.ret || '-');
  qyText('qy-acc', qyBool(data.qy_acc, data.qy_acc_pid));
  qyText('qy-mosq', qyBool(data.qy_mosq, data.qy_mosq_pid));
  qyText('qy-proxy', qyBool(data.qy_proxy, data.qy_proxy_pid));
  qyText('qy-pkg', [data.mode, data.version, data.date].filter(Boolean).join(' / ') || '-');
  qyText('qy-listen', data.proxy_listen || '-');
  if(dot){
    dot.className = 'qy-dot ' + (st === 'BOOSTING' ? 'boosting' : (st === 'RUNNING' ? 'running' : 'off'));
  }
}
function qyRefresh(){
  var xhr = new XMLHttpRequest();
  xhr.open('GET', qyBase + '/status?_=' + Date.now(), true);
  xhr.onreadystatechange = function(){
    if(xhr.readyState === 4){
      try { qyApply(JSON.parse(xhr.responseText || '{}')); }
      catch(e){ qyText('qy-status', '读取失败'); }
    }
  };
  xhr.send(null);
}
function qyUninstall(){
  if(!confirm('确认卸载奇游联机宝并移除应用商店入口吗？')) return;
  var xhr = new XMLHttpRequest();
  xhr.open('POST', qyBase + '/uninstall', true);
  xhr.onreadystatechange = function(){
    if(xhr.readyState === 4){
      alert('已开始卸载，稍后刷新应用商店。');
    }
  };
  xhr.send('');
}
qyRefresh();
setInterval(qyRefresh, 5000);
</script>
<%+footer%>
EOF_QIYOU_VIEW
    chmod 644 "$APP_VIEW" 2>/dev/null || true
}

install_appcenter_assets() {
    write_qiyou_icon
    write_uninstall_helper
    patch_global_plugin_uninstall_support
    write_luci_controller
    write_luci_view
    log "[7/7] 写入应用商店卡片并刷新缓存"
    set_appcenter_entry
    refresh_luci_appcenter
}

show_status() {
    log "奇游状态:"
    if [ -x /etc/qy/qy_acc.sh ]; then
        /etc/qy/qy_acc.sh status 2>/dev/null || true
    else
        log "NOT_INSTALLED"
    fi
    log ""
    log "安装返回: $(cat /tmp/qyplug.ret 2>/dev/null || true)"
    log "qy_acc: $(pidof qy_acc 2>/dev/null || printf '-')"
    log "qy_mosq: $(pidof qy_mosq 2>/dev/null || printf '-')"
    log "qy_proxy: $(pidof qy_proxy 2>/dev/null || printf '-')"
    [ -f /tmp/qy/etc/PKG_INFO ] && cat /tmp/qy/etc/PKG_INFO
}

install_all() {
    need_root
    require_nradio_appcenter
    confirm_or_exit "确认安装奇游联机宝官方脚本并接入 NRadio 应用商店吗？"
    install_dependencies
    install_qiyou_core
    install_appcenter_assets
    show_status
    log "完成：应用商店中应出现“奇游联机宝”卡片。"
}

uninstall_all() {
    need_root
    confirm_or_exit "确认卸载奇游联机宝并移除应用商店入口吗？"
    if [ -x "$UNINSTALL_HELPER" ]; then
        "$UNINSTALL_HELPER"
    else
        /etc/qy/qy_acc.sh stop >/dev/null 2>&1 || true
        [ -x /tmp/qy/init.sh ] && /tmp/qy/init.sh stop >/dev/null 2>&1 || true
        killall -9 qy_proxy qy_mosq qy_acc >/dev/null 2>&1 || true
        rm -rf /tmp/qy /etc/qy /tmp/qyplug.sh /tmp/qyplug.ret /tmp/qyplug.pid /tmp/qyplug.get "$QY_INSTALLER"
        rm -f /etc/init.d/qy_acc.boot /etc/rc.d/S99qy_acc.boot "$APP_CONTROLLER" "$APP_VIEW" "$APP_ICON_PATH"
        cleanup_appcenter_entry
        refresh_luci_appcenter
    fi
    log "卸载完成"
}

main_menu() {
    choice="${1:-}"
    log "$SCRIPT_TITLE $SCRIPT_VERSION"
    log "1. 安装依赖、奇游官方脚本，并接入应用商店"
    log "2. 查看奇游状态"
    log "3. 卸载奇游联机宝"
    printf '请输入 1、2 或 3: '
    if [ -z "$choice" ]; then
        read_line || die "input cancelled"
        choice="$READ_RESULT"
    else
        printf '%s\n' "$choice"
    fi
    case "$choice" in
        1) install_all ;;
        2) show_status ;;
        3) uninstall_all ;;
        *) die "invalid choice: $choice" ;;
    esac
}

main_menu "$@"
