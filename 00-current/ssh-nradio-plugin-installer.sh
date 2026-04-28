#!/bin/sh
set -eu
umask 077

SCRIPT_VERSION="V2.0.3"
SCRIPT_TITLE="NRadio 官方系统插件安装助手 ${SCRIPT_VERSION}"
SCRIPT_RELEASE_DATE="2026-04-29"
SCRIPT_SIGNATURE="Designed by maye ${SCRIPT_RELEASE_DATE}"
SCRIPT_MODEL_NOTICE="适用机型：NRadio_C8-688/NRadio_C5800-688/NRadio_NBCPE/NRadio_C2000MAX官方NROS2.0系统"
SCRIPT_SCOPE_NOTICE="适用于带 NRadio 应用商店的官方固件，并非标准 OpenWrt"
SCRIPT_DISCLAIMER="此脚本为免费分享的非商业项目，禁止任何形式的付费传播或倒卖"
SCRIPT_SUPPORT_NOTICE="自愿支持仅用于脚本维护与后续更新"
SUPPORT_PAGE_URL="https://nradio.mayebano.shop/"
TPL="/usr/lib/lua/luci/view/nradio_appcenter/appcenter.htm"
APPCENTER_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/appcenter.lua"
CFG="/etc/config/appcenter"
FEEDS="/etc/opkg/distfeeds.conf"
BACKUP_DIR="/root/nradio-plugin-fix"
STATE_DIR="/root/.nradio-plugin-menu"
CURRENT_DETECTED_MODEL=""
RUNTIME_STATE_FILE="$STATE_DIR/openvpn_runtime.conf"
ROUTE_STATE_FILE="$STATE_DIR/openvpn_routes.conf"
EASYTIER_ROUTE_STATE_FILE="$STATE_DIR/easytier_routes.conf"
OPENVPN_DNSMASQ_DOMAIN_STATE_FILE="$STATE_DIR/openvpn_dnsmasq_domains.list"
RUNTIME_CA_FILE="$STATE_DIR/openvpn_ca.crt"
RUNTIME_CERT_FILE="$STATE_DIR/openvpn_client.crt"
RUNTIME_KEY_FILE="$STATE_DIR/openvpn_client.key"
RUNTIME_TLS_FILE="$STATE_DIR/openvpn_tls.key"
RUNTIME_EXTRA_FILE="$STATE_DIR/openvpn_extra.conf"
ROUTE_LIST_FILE="$STATE_DIR/openvpn_routes.list"
ROUTE_MAP_LIST_FILE="$STATE_DIR/openvpn_map_peers.list"
DISCLAIMER_ACCEPT_VERSION="20260424-v1501-model-disclaimer-dynamic-full-v2"
DISCLAIMER_ACCEPTED_FLAG_FILE="$STATE_DIR/disclaimer_accepted_${DISCLAIMER_ACCEPT_VERSION}.flag"
EASYTIER_ROUTE_APPLY_SCRIPT="/etc/easytier/route-apply.sh"
EASYTIER_CONFIG_FILE="/etc/easytier/config.toml"
PLUGIN_UNINSTALL_HELPER="/usr/libexec/nradio-plugin-uninstall"
PLUGIN_UNINSTALL_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/plugin_uninstall.lua"
WORKDIR="/tmp/nradio-plugin-fix.$$"
LOCK_DIR="${LOCK_DIR:-/var/run/nradio-plugin-assistant.lock}"
LOCK_OWNER='0'
TS="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo now)"
OPENCLASH_BRANCH="${OPENCLASH_BRANCH:-master}"
OPENCLASH_DISPLAY_NAME="${OPENCLASH_DISPLAY_NAME:-哈基米}"
OPENCLASH_SMART_DISPLAY_NAME="${OPENCLASH_SMART_DISPLAY_NAME:-哈基米 smart}"
OPENCLASH_MIRRORS="${OPENCLASH_MIRRORS:-https://cdn.jsdelivr.net/gh/vernesong/OpenClash@package/${OPENCLASH_BRANCH} https://fastly.jsdelivr.net/gh/vernesong/OpenClash@package/${OPENCLASH_BRANCH} https://testingcf.jsdelivr.net/gh/vernesong/OpenClash@package/${OPENCLASH_BRANCH}}"
OPENCLASH_CORE_VERSION_MIRRORS="${OPENCLASH_CORE_VERSION_MIRRORS:-https://cdn.jsdelivr.net/gh/vernesong/OpenClash@core/dev https://fastly.jsdelivr.net/gh/vernesong/OpenClash@core/dev https://testingcf.jsdelivr.net/gh/vernesong/OpenClash@core/dev}"
OPENCLASH_CORE_SMART_MIRRORS="${OPENCLASH_CORE_SMART_MIRRORS:-https://cdn.jsdelivr.net/gh/vernesong/OpenClash@core/dev/smart https://fastly.jsdelivr.net/gh/vernesong/OpenClash@core/dev/smart https://testingcf.jsdelivr.net/gh/vernesong/OpenClash@core/dev/smart}"
OPENCLASH_GEOASN_MIRRORS="${OPENCLASH_GEOASN_MIRRORS:-https://testingcf.jsdelivr.net/gh/xishang0128/geoip@release https://cdn.jsdelivr.net/gh/xishang0128/geoip@release https://fastly.jsdelivr.net/gh/xishang0128/geoip@release}"
ADGUARDHOME_VERSION="${ADGUARDHOME_VERSION:-1.8-9}"
ADGUARDHOME_IPK_URLS="${ADGUARDHOME_IPK_URLS:-https://ghproxy.net/https://github.com/rufengsuixing/luci-app-adguardhome/releases/download/${ADGUARDHOME_VERSION}/luci-app-adguardhome_${ADGUARDHOME_VERSION}_all.ipk https://mirror.ghproxy.com/https://github.com/rufengsuixing/luci-app-adguardhome/releases/download/${ADGUARDHOME_VERSION}/luci-app-adguardhome_${ADGUARDHOME_VERSION}_all.ipk https://gh-proxy.com/https://github.com/rufengsuixing/luci-app-adguardhome/releases/download/${ADGUARDHOME_VERSION}/luci-app-adguardhome_${ADGUARDHOME_VERSION}_all.ipk}"
ADGUARDHOME_CORE_MIRRORS="${ADGUARDHOME_CORE_MIRRORS:-https://static.adtidy.org/adguardhome/release}"
OPENVPN_VERSION="${OPENVPN_VERSION:-}"
OPENLIST_VERSION="${OPENLIST_VERSION:-latest}"
OPENLIST_ASSET_NAME="${OPENLIST_ASSET_NAME:-openlist-linux-musl-arm64.tar.gz}"
OPENLIST_GITHUB_CDN_BASES="${OPENLIST_GITHUB_CDN_BASES:-}"
OPENLIST_CDN_RANKED="${OPENLIST_CDN_RANKED:-0}"
OPENLIST_STABLE_HOST_ORDER="${OPENLIST_STABLE_HOST_ORDER:-release-assets.githubusercontent.com github.com api.github.com}"
OPENLIST_GITHUB_OFFICIAL_PROBE_URLS="${OPENLIST_GITHUB_OFFICIAL_PROBE_URLS:-https://github.com/OpenListTeam/OpenList/releases/latest/download/${OPENLIST_ASSET_NAME} https://api.github.com/repos/OpenListTeam/OpenList/releases/latest https://release-assets.githubusercontent.com/}"
OPENLIST_FAST_DOWNLOAD_MODE="${OPENLIST_FAST_DOWNLOAD_MODE:-1}"
OPENLIST_ROOT_DIR="${OPENLIST_ROOT_DIR:-/mnt/app_data/openlist}"
OPENLIST_BIN_DIR="${OPENLIST_BIN_DIR:-$OPENLIST_ROOT_DIR/bin}"
OPENLIST_BIN_PATH="${OPENLIST_BIN_PATH:-$OPENLIST_BIN_DIR/openlist}"
OPENLIST_DATA_DIR="${OPENLIST_DATA_DIR:-$OPENLIST_ROOT_DIR/data}"
OPENLIST_TEMP_DIR="${OPENLIST_TEMP_DIR:-$OPENLIST_ROOT_DIR/tmp}"
OPENLIST_LOG_PATH="${OPENLIST_LOG_PATH:-$OPENLIST_ROOT_DIR/openlist.log}"
OPENLIST_DEFAULT_ADMIN_PASSWORD="${OPENLIST_DEFAULT_ADMIN_PASSWORD:-admin}"
OPENLIST_LINK_PATH="${OPENLIST_LINK_PATH:-/usr/bin/openlist}"
OPENLIST_PACKAGE_STALL_TIME="${OPENLIST_PACKAGE_STALL_TIME:-15}"
OPENLIST_PACKAGE_STALL_SPEED="${OPENLIST_PACKAGE_STALL_SPEED:-2048}"
OPENLIST_PACKAGE_MAX_TIME="${OPENLIST_PACKAGE_MAX_TIME:-3600}"
OPENLIST_PACKAGE_RETRY_STALL_TIME="${OPENLIST_PACKAGE_RETRY_STALL_TIME:-25}"
OPENLIST_PACKAGE_RETRY_STALL_SPEED="${OPENLIST_PACKAGE_RETRY_STALL_SPEED:-1024}"
ZEROTIER_PACKAGE_NAME="${ZEROTIER_PACKAGE_NAME:-zerotier}"
ZEROTIER_PACKAGE_STALL_TIME="${ZEROTIER_PACKAGE_STALL_TIME:-25}"
ZEROTIER_PACKAGE_STALL_SPEED="${ZEROTIER_PACKAGE_STALL_SPEED:-4096}"
ZEROTIER_PACKAGE_RETRY_STALL_TIME="${ZEROTIER_PACKAGE_RETRY_STALL_TIME:-45}"
ZEROTIER_PACKAGE_RETRY_STALL_SPEED="${ZEROTIER_PACKAGE_RETRY_STALL_SPEED:-2048}"
ZEROTIER_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/zerotier.lua"
ZEROTIER_CBI="/usr/lib/lua/luci/model/cbi/nradio_adv/zerotier_basic.lua"
ZEROTIER_ROUTE="${ZEROTIER_ROUTE:-nradioadv/system/zerotier/basic}"
EASYTIER_DISPLAY_NAME="${EASYTIER_DISPLAY_NAME:-EasyTier}"
EASYTIER_VERSION="${EASYTIER_VERSION:-2.5.0}"
EASYTIER_PACKAGE_NAME="${EASYTIER_PACKAGE_NAME:-easytier}"
EASYTIER_LUCI_PACKAGE_NAME="${EASYTIER_LUCI_PACKAGE_NAME:-luci-app-easytier}"
EASYTIER_I18N_PACKAGE_NAME="${EASYTIER_I18N_PACKAGE_NAME:-luci-i18n-easytier-zh-cn}"
EASYTIER_PACKAGE_ARCH="${EASYTIER_PACKAGE_ARCH:-aarch64_cortex-a53}"
EASYTIER_PACKAGE_SERIES="${EASYTIER_PACKAGE_SERIES:-22.03.7}"
EASYTIER_ASSET_NAME="${EASYTIER_ASSET_NAME:-EasyTier-v${EASYTIER_VERSION}-${EASYTIER_PACKAGE_ARCH}-${EASYTIER_PACKAGE_SERIES}.zip}"
EASYTIER_GITHUB_CDN_BASES="${EASYTIER_GITHUB_CDN_BASES:-}"
EASYTIER_CDN_RANKED="${EASYTIER_CDN_RANKED:-0}"
EASYTIER_STABLE_HOST_ORDER="${EASYTIER_STABLE_HOST_ORDER:-release-assets.githubusercontent.com github.com api.github.com}"
EASYTIER_GITHUB_RELEASE_URL="${EASYTIER_GITHUB_RELEASE_URL:-https://github.com/EasyTier/luci-app-easytier/releases/download/v${EASYTIER_VERSION}/${EASYTIER_ASSET_NAME}}"
EASYTIER_GITHUB_API_URL="${EASYTIER_GITHUB_API_URL:-https://api.github.com/repos/EasyTier/luci-app-easytier/releases/tags/v${EASYTIER_VERSION}}"
EASYTIER_GITHUB_OFFICIAL_PROBE_URLS="${EASYTIER_GITHUB_OFFICIAL_PROBE_URLS:-${EASYTIER_GITHUB_RELEASE_URL} ${EASYTIER_GITHUB_API_URL} https://release-assets.githubusercontent.com/}"
EASYTIER_PACKAGE_STALL_TIME="${EASYTIER_PACKAGE_STALL_TIME:-20}"
EASYTIER_PACKAGE_STALL_SPEED="${EASYTIER_PACKAGE_STALL_SPEED:-2048}"
EASYTIER_PACKAGE_RETRY_STALL_TIME="${EASYTIER_PACKAGE_RETRY_STALL_TIME:-35}"
EASYTIER_PACKAGE_RETRY_STALL_SPEED="${EASYTIER_PACKAGE_RETRY_STALL_SPEED:-1024}"
EASYTIER_PACKAGE_MAX_TIME="${EASYTIER_PACKAGE_MAX_TIME:-1800}"
EASYTIER_CONTROLLER="${EASYTIER_CONTROLLER:-/usr/lib/lua/luci/controller/easytier.lua}"
EASYTIER_ROUTE="${EASYTIER_ROUTE:-admin/vpn/easytier/easytier}"
FANCTRL_DISPLAY_NAME="${FANCTRL_DISPLAY_NAME:-FanControl}"
FANCTRL_PACKAGE_NAME="${FANCTRL_PACKAGE_NAME:-fanctrl}"
FANCTRL_CONTROLLER="${FANCTRL_CONTROLLER:-/usr/lib/lua/luci/controller/nradio_adv/fanctrl.lua}"
FANCTRL_CBI="${FANCTRL_CBI:-/usr/lib/lua/luci/model/cbi/nradio_adv/fanctrl.lua}"
FANCTRL_ROUTE="${FANCTRL_ROUTE:-nradioadv/system/fanctrl}"
FANCTRL_VIEW_DIR="${FANCTRL_VIEW_DIR:-/usr/lib/lua/luci/view/nradio_fanctrl}"
FANCTRL_TEMP_AJAX_VIEW="${FANCTRL_TEMP_AJAX_VIEW:-$FANCTRL_VIEW_DIR/temperature_ajax.htm}"
FANCTRL_TEMP_VIEW="${FANCTRL_TEMP_VIEW:-$FANCTRL_VIEW_DIR/temperature.htm}"
FANCTRL_SERVICE_NAME="${FANCTRL_SERVICE_NAME:-fanctrl}"
FANCTRL_CONFIG_FILE="${FANCTRL_CONFIG_FILE:-/etc/config/$FANCTRL_SERVICE_NAME}"
FANCTRL_INIT_FILE="${FANCTRL_INIT_FILE:-/etc/init.d/$FANCTRL_SERVICE_NAME}"
FANCTRL_BIN_PATH="${FANCTRL_BIN_PATH:-/usr/bin/${FANCTRL_SERVICE_NAME}.sh}"
FANCTRL_SECTION_NAME="${FANCTRL_SECTION_NAME:-$FANCTRL_SERVICE_NAME}"
FANCTRL_LEGACY_DISPLAY_NAME="${FANCTRL_LEGACY_DISPLAY_NAME:-FanControl}"
FANCTRL_LEGACY_PACKAGE_NAME="${FANCTRL_LEGACY_PACKAGE_NAME:-fanctrl}"
FANCTRL_LEGACY_ROUTE="${FANCTRL_LEGACY_ROUTE:-nradioadv/system/fanctrl}"
APP_ICON_DIR="${APP_ICON_DIR:-/www/luci-static/nradio/images/icon}"
OPENCLASH_ICON_NAME="${OPENCLASH_ICON_NAME:-openclash.svg}"
OPENCLASH_ICON_URLS="${OPENCLASH_ICON_URLS:-https://ghproxy.net/https://raw.githubusercontent.com/vernesong/OpenClash/dev/img/logo.png https://gh-proxy.com/https://raw.githubusercontent.com/vernesong/OpenClash/dev/img/logo.png https://raw.githubusercontent.com/vernesong/OpenClash/dev/img/logo.png}"
ADGUARDHOME_ICON_NAME="${ADGUARDHOME_ICON_NAME:-adguard.svg}"
ADGUARDHOME_ICON_URLS="${ADGUARDHOME_ICON_URLS:-https://fastly.jsdelivr.net/npm/simple-icons@latest/icons/adguard.svg https://testingcf.jsdelivr.net/npm/simple-icons@latest/icons/adguard.svg https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/adguard.svg}"
WEBSSH_ICON_NAME="${WEBSSH_ICON_NAME:-webssh.svg}"
WEBSSH_ICON_URLS="${WEBSSH_ICON_URLS:-https://fastly.jsdelivr.net/npm/@fortawesome/fontawesome-free@6/svgs/solid/terminal.svg https://testingcf.jsdelivr.net/npm/@fortawesome/fontawesome-free@6/svgs/solid/terminal.svg https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6/svgs/solid/terminal.svg}"
OPENVPN_ICON_NAME="${OPENVPN_ICON_NAME:-openvpn.svg}"
OPENVPN_ICON_URLS="${OPENVPN_ICON_URLS:-https://fastly.jsdelivr.net/npm/simple-icons@latest/icons/openvpn.svg https://testingcf.jsdelivr.net/npm/simple-icons@latest/icons/openvpn.svg https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/openvpn.svg}"
OPENLIST_ICON_NAME="${OPENLIST_ICON_NAME:-openlist.svg}"
OPENLIST_ICON_URLS="${OPENLIST_ICON_URLS:-https://res.oplist.org/logo/OpenList.svg https://res.oplist.org/logo/logo.svg}"
ZEROTIER_ICON_NAME="${ZEROTIER_ICON_NAME:-zerotier.svg}"
ZEROTIER_ICON_URLS="${ZEROTIER_ICON_URLS:-https://fastly.jsdelivr.net/npm/simple-icons@latest/icons/zerotier.svg https://testingcf.jsdelivr.net/npm/simple-icons@latest/icons/zerotier.svg https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/zerotier.svg}"
EASYTIER_ICON_NAME="${EASYTIER_ICON_NAME:-easytier.svg}"
FANCTRL_ICON_NAME="${FANCTRL_ICON_NAME:-nradio-fanctrl}"
DOWNLOAD_CONNECT_TIMEOUT="${DOWNLOAD_CONNECT_TIMEOUT:-15}"
DOWNLOAD_MAX_TIME="${DOWNLOAD_MAX_TIME:-900}"
DOWNLOAD_RETRY="${DOWNLOAD_RETRY:-0}"
DOWNLOAD_HEAD_CONNECT_TIMEOUT="${DOWNLOAD_HEAD_CONNECT_TIMEOUT:-4}"
DOWNLOAD_HEAD_MAX_TIME="${DOWNLOAD_HEAD_MAX_TIME:-8}"
DOWNLOAD_SKIP_CONTENT_LENGTH="${DOWNLOAD_SKIP_CONTENT_LENGTH:-0}"
DOWNLOAD_STALL_TIME="${DOWNLOAD_STALL_TIME:-20}"
DOWNLOAD_STALL_SPEED="${DOWNLOAD_STALL_SPEED:-16384}"
DOWNLOAD_PARTIAL_RETRY_MIN_BYTES="${DOWNLOAD_PARTIAL_RETRY_MIN_BYTES:-1048576}"
DOWNLOAD_PARTIAL_RETRY_STALL_TIME="${DOWNLOAD_PARTIAL_RETRY_STALL_TIME:-45}"
DOWNLOAD_PARTIAL_RETRY_STALL_SPEED="${DOWNLOAD_PARTIAL_RETRY_STALL_SPEED:-2048}"
DOWNLOAD_PROGRESS_POLL_USEC="${DOWNLOAD_PROGRESS_POLL_USEC:-250000}"
OPENCLASH_PACKAGE_MAX_TIME="${OPENCLASH_PACKAGE_MAX_TIME:-3600}"
OPENCLASH_PACKAGE_STALL_TIME="${OPENCLASH_PACKAGE_STALL_TIME:-90}"
OPENCLASH_PACKAGE_STALL_SPEED="${OPENCLASH_PACKAGE_STALL_SPEED:-1024}"
OPENCLASH_PACKAGE_RETRY_STALL_TIME="${OPENCLASH_PACKAGE_RETRY_STALL_TIME:-180}"
OPENCLASH_PACKAGE_RETRY_STALL_SPEED="${OPENCLASH_PACKAGE_RETRY_STALL_SPEED:-256}"
OPENCLASH_PACKAGE_PROBE_BYTES="${OPENCLASH_PACKAGE_PROBE_BYTES:-1048575}"
OPENCLASH_CDN_PING_COUNT="${OPENCLASH_CDN_PING_COUNT:-2}"
OPENCLASH_CDN_PING_TIMEOUT="${OPENCLASH_CDN_PING_TIMEOUT:-1}"
CDN_HTTP_PROBE_TOP_HOSTS="${CDN_HTTP_PROBE_TOP_HOSTS:-2}"
CDN_HTTP_PROBE_CONNECT_TIMEOUT="${CDN_HTTP_PROBE_CONNECT_TIMEOUT:-5}"
CDN_HTTP_PROBE_MAX_TIME="${CDN_HTTP_PROBE_MAX_TIME:-12}"
BACKUP_KEEP_COUNT="${BACKUP_KEEP_COUNT:-5}"
ACTIVE_DOWNLOAD_PID=''
ACTIVE_BACKGROUND_PIDS=''
LAST_DOWNLOAD_SOURCE=''
LAST_DOWNLOAD_TOOL=''
LAST_DOWNLOAD_RC='0'
OPENLIST_RESOLVED_DOWNLOAD_URLS=''
EASYTIER_RESOLVED_DOWNLOAD_URLS=''
ABORTING='0'

cleanup() {
    terminate_active_download
    terminate_registered_background_jobs
    release_script_lock
    rm -rf "$WORKDIR"
}

abort_script() {
    [ "${ABORTING:-0}" = '1' ] && exit 130
    ABORTING='1'
    trap - EXIT INT TERM HUP QUIT
    cleanup
    printf '\n已取消\n' >&2
    exit 130
}

trap cleanup EXIT
trap abort_script INT TERM HUP QUIT

log() {
    printf '%s\n' "$*"
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

_STAGE_T0=""

log_stage() {
    stage_index="$1"
    stage_total="$2"
    shift 2

    _bar_len=20
    _filled=$(( stage_index * _bar_len / stage_total ))
    [ "$_filled" -gt "$_bar_len" ] && _filled="$_bar_len"
    _empty=$(( _bar_len - _filled ))
    _pct=$(( stage_index * 100 / stage_total ))

    _bar=""
    _bi=0
    while [ "$_bi" -lt "$_filled" ]; do _bar="${_bar}="; _bi=$((_bi + 1)); done
    if [ "$_empty" -gt 0 ]; then
        _bar="${_bar}>"
        _bi=1
        while [ "$_bi" -lt "$_empty" ]; do _bar="${_bar}."; _bi=$((_bi + 1)); done
    fi

    _elapsed_tag=""
    _now="$(date +%s 2>/dev/null || printf '')"
    if [ -n "$_now" ] && [ -n "$_STAGE_T0" ]; then
        _dt=$((_now - _STAGE_T0))
        if [ "$_dt" -ge 60 ] 2>/dev/null; then
            _dm=$((_dt / 60))
            _ds=$((_dt % 60))
            _elapsed_tag="  (上一步耗时 ${_dm}分${_ds}秒)"
        elif [ "$_dt" -gt 0 ] 2>/dev/null; then
            _elapsed_tag="  (上一步耗时 ${_dt}秒)"
        fi
    fi
    [ -n "$_now" ] && _STAGE_T0="$_now"

    printf '[%s] %3d%%  [%s/%s] %s%s\n' "$_bar" "$_pct" "$stage_index" "$stage_total" "$*" "$_elapsed_tag"
}

stderr_is_tty() {
    [ -t 2 ]
}

get_file_size_bytes() {
    path="$1"
    [ -f "$path" ] || {
        printf '0\n'
        return 0
    }
    wc -c < "$path" 2>/dev/null | tr -d ' ' || printf '0\n'
}

format_bytes_human() {
    size_bytes="${1:-0}"
    case "$size_bytes" in
        ''|*[!0-9]*)
            size_bytes=0
            ;;
    esac
    if [ "$size_bytes" -ge 1073741824 ] 2>/dev/null; then
        awk -v v="$size_bytes" 'BEGIN { printf "%.1f GB", v / 1073741824 }'
    elif [ "$size_bytes" -ge 1048576 ] 2>/dev/null; then
        awk -v v="$size_bytes" 'BEGIN { printf "%.1f MB", v / 1048576 }'
    elif [ "$size_bytes" -ge 1024 ] 2>/dev/null; then
        awk -v v="$size_bytes" 'BEGIN { printf "%.1f KB", v / 1024 }'
    else
        printf '%s B' "$size_bytes"
    fi
}

get_path_free_bytes() {
    target_path="$1"
    [ -n "$target_path" ] || return 1
    df -kP "$target_path" 2>/dev/null | awk 'NR==2 {print $4 * 1024; exit}'
}

ensure_dir_writable() {
    target_dir="$1"
    target_label="${2:-$target_dir}"
    probe_file=""

    [ -d "$target_dir" ] || die "$target_label 不存在"
    probe_file="$target_dir/.nradio-write-test.$$"
    : > "$probe_file" 2>/dev/null || die "$target_label 不可写"
    rm -f "$probe_file" 2>/dev/null || true
}

ensure_free_space_bytes() {
    target_path="$1"
    required_bytes="$2"
    target_label="${3:-$target_path}"

    case "$required_bytes" in
        ''|*[!0-9]*)
            return 0
            ;;
    esac

    free_bytes="$(get_path_free_bytes "$target_path" 2>/dev/null || true)"
    case "$free_bytes" in
        ''|*[!0-9]*)
            die "$target_label 空间检查失败"
            ;;
    esac

    [ "$free_bytes" -ge "$required_bytes" ] 2>/dev/null || die "$target_label 可用空间不足：需要 $(format_bytes_human "$required_bytes")，当前仅剩 $(format_bytes_human "$free_bytes")"
}

estimate_archive_extract_bytes() {
    archive_path="$1"
    archive_size="$(get_file_size_bytes "$archive_path" 2>/dev/null || true)"
    case "$archive_size" in
        ''|*[!0-9]*)
            return 1
            ;;
    esac

    printf '%s\n' $(( archive_size * 2 + 16777216 ))
}

validate_tar_gzip_archive() {
    archive_path="$1"
    archive_label="${2:-压缩包}"
    validate_log="${3:-/tmp/archive-validate.log}"

    [ -s "$archive_path" ] || die "$archive_label 文件为空或不存在"

    if command -v gzip >/dev/null 2>&1; then
        if ! gzip -t "$archive_path" >"$validate_log" 2>&1; then
            sed -n '1,20p' "$validate_log" >&2 || true
            die "$archive_label 完整性校验失败，请查看 $validate_log"
        fi
    fi

    if ! tar -tzf "$archive_path" > /dev/null 2>"$validate_log"; then
        sed -n '1,20p' "$validate_log" >&2 || true
        die "$archive_label 目录校验失败，请查看 $validate_log"
    fi
}

find_archive_first_matching_entry() {
    archive_path="$1"
    entry_pattern="${2:-}"

    [ -n "$archive_path" ] || return 1
    [ -n "$entry_pattern" ] || return 1

    tar -tzf "$archive_path" 2>/dev/null | awk -v pat="$entry_pattern" '
        NF && $0 !~ /\/$/ && $0 ~ pat { print; exit }
    '
}

now_epoch_seconds() {
    date +%s 2>/dev/null || printf '0\n'
}

get_url_content_length() {
    url="$1"
    content_length=""

    if [ "${DOWNLOAD_SKIP_CONTENT_LENGTH:-0}" = '1' ]; then
        printf '\n'
        return 0
    fi

    if command -v curl >/dev/null 2>&1; then
        headers="$(curl -k -L -sSI --connect-timeout "$DOWNLOAD_HEAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_HEAD_MAX_TIME" "$url" 2>/dev/null || true)"
        content_length="$(printf '%s\n' "$headers" | tr -d '\r' | sed -n 's/^[Cc]ontent-[Ll]ength: *//p' | tail -n 1)"
    fi

    case "$content_length" in
        ''|*[!0-9]*)
            content_length=""
            ;;
    esac

    printf '%s\n' "$content_length"
}

render_download_progress() {
    progress_state="$1"
    current_bytes="$2"
    total_bytes="${3:-}"
    speed_bytes="${4:-}"
    current_human="$(format_bytes_human "$current_bytes")"
    line=""

    if [ -n "$total_bytes" ] && [ "$total_bytes" -gt 0 ] 2>/dev/null; then
        total_human="$(format_bytes_human "$total_bytes")"
        progress_percent=$(( current_bytes * 100 / total_bytes ))
        [ "$progress_percent" -le 100 ] 2>/dev/null || progress_percent=100
        _dl_bar_len=15
        _dl_filled=$(( progress_percent * _dl_bar_len / 100 ))
        _dl_empty=$(( _dl_bar_len - _dl_filled ))
        _dl_bar=""
        _dbi=0
        while [ "$_dbi" -lt "$_dl_filled" ]; do _dl_bar="${_dl_bar}="; _dbi=$((_dbi + 1)); done
        if [ "$_dl_empty" -gt 0 ]; then
            _dl_bar="${_dl_bar}>"
            _dbi=1
            while [ "$_dbi" -lt "$_dl_empty" ]; do _dl_bar="${_dl_bar}."; _dbi=$((_dbi + 1)); done
        fi
        line="[${_dl_bar}] ${progress_state} ${current_human} / ${total_human} (${progress_percent}%)"
    else
        line="${progress_state} 已下载 ${current_human}"
    fi

    if [ -n "$speed_bytes" ]; then
        case "$speed_bytes" in
            ''|*[!0-9]*)
                ;;
            *)
                speed_human="$(format_bytes_human "$speed_bytes")"
                line="${line} ${speed_human}/s"
                ;;
        esac
    fi

    if stderr_is_tty; then
        printf '\r%-88s' "$line" >&2
    else
        printf '%s\n' "$line" >&2
    fi
}

finish_download_progress_line() {
    if stderr_is_tty; then
        printf '\n' >&2
    fi
}

sleep_abort_poll() {
    usleep 100000 2>/dev/null || sleep 0.1 2>/dev/null || sleep 1
}

sleep_download_poll() {
    poll_usec="${DOWNLOAD_PROGRESS_POLL_USEC:-250000}"
    case "$poll_usec" in
        ''|*[!0-9]*)
            poll_usec='250000'
            ;;
    esac
    usleep "$poll_usec" 2>/dev/null || sleep_abort_poll
}

terminate_pid_quick() {
    target_pid="$1"
    [ -n "$target_pid" ] || return 0

    if kill -0 "$target_pid" 2>/dev/null; then
        kill -INT "$target_pid" 2>/dev/null || kill "$target_pid" 2>/dev/null || true
        _tp_try=0
        while kill -0 "$target_pid" 2>/dev/null; do
            _tp_try=$((_tp_try + 1))
            [ "$_tp_try" -lt 4 ] || break
            sleep_abort_poll
        done
        if kill -0 "$target_pid" 2>/dev/null; then
            kill -TERM "$target_pid" 2>/dev/null || true
            _tp_try=0
            while kill -0 "$target_pid" 2>/dev/null; do
                _tp_try=$((_tp_try + 1))
                [ "$_tp_try" -lt 4 ] || break
                sleep_abort_poll
            done
        fi
        if kill -0 "$target_pid" 2>/dev/null; then
            kill -9 "$target_pid" 2>/dev/null || true
        fi
    fi

    wait "$target_pid" 2>/dev/null || true
}

wait_for_pid_list() {
    wait_pids="$*"
    [ -n "$wait_pids" ] || return 0

    while :; do
        wait_remaining=''
        for wait_pid in $wait_pids; do
            if kill -0 "$wait_pid" 2>/dev/null; then
                if [ -n "$wait_remaining" ]; then
                    wait_remaining="$wait_remaining $wait_pid"
                else
                    wait_remaining="$wait_pid"
                fi
            fi
        done
        [ -n "$wait_remaining" ] || break
        sleep_abort_poll
    done

    wait_rc=0
    for wait_pid in $wait_pids; do
        if wait "$wait_pid" 2>/dev/null; then
            wait_pid_rc=0
        else
            wait_pid_rc="$?"
        fi
        case "$wait_pid_rc" in
            0|127)
                ;;
            *)
                [ "$wait_rc" -eq 0 ] && wait_rc="$wait_pid_rc"
                ;;
        esac
    done

    return "$wait_rc"
}

terminate_registered_background_jobs() {
    bg_pids="${ACTIVE_BACKGROUND_PIDS:-}"
    [ -n "$bg_pids" ] || return 0

    for bg_pid in $bg_pids; do
        terminate_pid_quick "$bg_pid"
    done

    ACTIVE_BACKGROUND_PIDS=''
}

terminate_active_download() {
    active_pid="${ACTIVE_DOWNLOAD_PID:-}"
    [ -n "$active_pid" ] || return 0

    terminate_pid_quick "$active_pid"
    ACTIVE_DOWNLOAD_PID=''
}

run_download_with_progress() {
    progress_url="$1"
    progress_out="$2"
    shift 2

    progress_total="$(get_url_content_length "$progress_url")"
    progress_last_size='-1'
    progress_last_percent='-1'
    progress_last_print_epoch='0'
    progress_prev_sample_size='0'
    progress_prev_sample_epoch='0'

    "$@" &
    progress_pid="$!"
    ACTIVE_DOWNLOAD_PID="$progress_pid"

    while kill -0 "$progress_pid" 2>/dev/null; do
        progress_size="$(get_file_size_bytes "$progress_out")"
        progress_now_epoch="$(now_epoch_seconds)"
        if [ -n "$progress_total" ] && [ "$progress_total" -gt 0 ] 2>/dev/null; then
            progress_percent=$(( progress_size * 100 / progress_total ))
            [ "$progress_percent" -le 100 ] 2>/dev/null || progress_percent=100
        else
            progress_percent='-1'
        fi

        progress_speed=''
        if [ "$progress_prev_sample_epoch" -gt 0 ] 2>/dev/null; then
            progress_elapsed=$(( progress_now_epoch - progress_prev_sample_epoch ))
            if [ "$progress_elapsed" -ge 1 ] 2>/dev/null; then
                progress_delta=$(( progress_size - progress_prev_sample_size ))
                [ "$progress_delta" -ge 0 ] 2>/dev/null || progress_delta=0
                progress_speed=$(( progress_delta / progress_elapsed ))
                progress_prev_sample_size="$progress_size"
                progress_prev_sample_epoch="$progress_now_epoch"
            fi
        else
            progress_prev_sample_size="$progress_size"
            progress_prev_sample_epoch="$progress_now_epoch"
        fi

        if stderr_is_tty; then
            render_download_progress "下载中" "$progress_size" "$progress_total" "$progress_speed"
        else
            progress_should_print='0'
            if [ "$progress_size" != "$progress_last_size" ] || [ "$progress_percent" != "$progress_last_percent" ]; then
                if [ "$progress_last_print_epoch" -eq 0 ] 2>/dev/null || [ $(( progress_now_epoch - progress_last_print_epoch )) -ge 1 ] 2>/dev/null; then
                    progress_should_print='1'
                fi
            fi
            if [ "$progress_should_print" = '1' ]; then
                render_download_progress "下载中" "$progress_size" "$progress_total" "$progress_speed"
                progress_last_print_epoch="$progress_now_epoch"
            fi
        fi

        progress_last_size="$progress_size"
        progress_last_percent="$progress_percent"
        sleep_download_poll
    done

    if wait "$progress_pid"; then
        progress_rc=0
    else
        progress_rc="$?"
    fi
    ACTIVE_DOWNLOAD_PID=''
    progress_size="$(get_file_size_bytes "$progress_out")"

    if [ "$progress_rc" -eq 0 ]; then
        render_download_progress "下载完成" "$progress_size" "$progress_total"
    else
        render_download_progress "下载失败" "$progress_size" "$progress_total"
    fi
    finish_download_progress_line

    return "$progress_rc"
}

ui_read_line() {
    if [ -t 0 ]; then
        read -r UI_READ_RESULT || return 1
        return 0
    fi
    if read -r UI_READ_RESULT; then
        return 0
    fi
    if can_use_ui_tty; then
        read -r UI_READ_RESULT </dev/tty || return 1
        return 0
    fi
    return 1
}

can_use_ui_tty() {
    [ -r /dev/tty ] || return 1
    ( : </dev/tty ) >/dev/null 2>&1
}

ui_read_secret() {
    if [ -t 0 ]; then
        if command -v stty >/dev/null 2>&1; then
            stty -echo
            read -r UI_READ_RESULT || {
                rc="$?"
                stty echo
                return "$rc"
            }
            stty echo
            printf '\n'
            return 0
        fi
        read -r UI_READ_RESULT || {
            return "$?"
        }
        return 0
    fi
    if read -r UI_READ_RESULT; then
        return 0
    fi
    if can_use_ui_tty; then
        if command -v stty >/dev/null 2>&1; then
            stty -echo </dev/tty
            read -r UI_READ_RESULT </dev/tty || {
                rc="$?"
                stty echo </dev/tty
                return "$rc"
            }
            stty echo </dev/tty
            printf '\n' >/dev/tty
            return 0
        fi
        read -r UI_READ_RESULT </dev/tty || {
            return "$?"
        }
        return 0
    fi
    return 1
}

confirm_or_exit() {
    prompt="$1"
    answer=""
    printf '%s [y/N]: ' "$prompt"
    ui_read_line || die "input cancelled"
    answer="$UI_READ_RESULT"
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

confirm_default_yes() {
    prompt="$1"
    answer=""
    printf '%s [Y/n]: ' "$prompt"
    ui_read_line || die "input cancelled"
    answer="$UI_READ_RESULT"
    case "$answer" in
        n|N|no|NO)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

confirm_appcenter_polish_risk() {
    cat <<'EOF_APPCENTER_POLISH_CONFIRM'
高风险警告：15 号会直接覆盖原厂应用商店页面文件，执行后无法通过本脚本一键还原。

如果美化后页面异常、样式错乱或不兼容当前固件，通常只能通过以下方式恢复：
1. 恢复出厂设置；
2. 等待官方新固件推送并覆盖原厂页面。

不理解以上风险请勿继续。
EOF_APPCENTER_POLISH_CONFIRM
    confirm_or_exit "确认仍要美化应用商店吗？"
}

run_startup_disclaimer_countdown() {
    disclaimer_countdown_remaining="${1:-10}"
    case "$disclaimer_countdown_remaining" in
        ''|*[!0-9]*)
            disclaimer_countdown_remaining='10'
            ;;
    esac

    if [ -t 1 ]; then
        while [ "$disclaimer_countdown_remaining" -gt 0 ]; do
            printf '\r请先完整阅读免责声明，%s 秒后可选择是否同意...' "$disclaimer_countdown_remaining"
            sleep 1
            disclaimer_countdown_remaining=$((disclaimer_countdown_remaining - 1))
        done
        printf '\r请先完整阅读免责声明，10 秒倒计时已结束。              \n'
        return 0
    fi

    while [ "$disclaimer_countdown_remaining" -gt 0 ]; do
        printf '请先完整阅读免责声明，%s 秒后可选择是否同意...\n' "$disclaimer_countdown_remaining"
        sleep 1
        disclaimer_countdown_remaining=$((disclaimer_countdown_remaining - 1))
    done
    printf '请先完整阅读免责声明，10 秒倒计时已结束。\n'
}

clear_startup_screen() {
    printf '\033[H\033[2J\033[3J'
}

prime_startup_disclaimer_model() {
    [ -n "$CURRENT_DETECTED_MODEL" ] && return 0

    raw_model="$(detect_board_model_raw 2>/dev/null || true)"
    raw_board="$(detect_board_name_raw 2>/dev/null || true)"
    raw_compat="$(detect_board_compatible_raw 2>/dev/null || true)"
    normalized_model="$(normalize_nradio_model "$raw_model" "$raw_board" "$raw_compat" 2>/dev/null || true)"

    [ -n "$normalized_model" ] && CURRENT_DETECTED_MODEL="$normalized_model"
}

require_startup_disclaimer_acceptance_once() {
    disclaimer_answer=""

    [ -f "$DISCLAIMER_ACCEPTED_FLAG_FILE" ] && return 0

    mkdir -p "$STATE_DIR" >/dev/null 2>&1 || die "创建免责声明状态目录失败: $STATE_DIR"
    prime_startup_disclaimer_model
    clear_startup_screen
    print_startup_disclaimer_text
    printf '\n'
    run_startup_disclaimer_countdown 10
    printf '是否同意以上免责声明？[y/N]: '
    ui_read_line || die "input cancelled"
    disclaimer_answer="$UI_READ_RESULT"

    case "$disclaimer_answer" in
        y|Y)
            printf '%s\n' "accepted ${SCRIPT_VERSION} ${SCRIPT_RELEASE_DATE}" > "$DISCLAIMER_ACCEPTED_FLAG_FILE" || die "写入免责声明同意标记失败: $DISCLAIMER_ACCEPTED_FLAG_FILE"
            printf '\n'
            clear_startup_screen
            ;;
        *)
            log "未同意免责声明，脚本已退出"
            exit 0
            ;;
    esac
}

has_nradio_oem_appcenter() {
    [ -f "$CFG" ] && [ -f "$TPL" ]
}

collect_missing_nradio_paths() {
    missing=""
    [ -f "$CFG" ] || missing="$missing $CFG"
    [ -f "$TPL" ] || missing="$missing $TPL"
    printf '%s\n' "${missing# }"
}

read_system_board_field() {
    field_name="$1"
    ubus call system board 2>/dev/null | sed -n "s/.*\"$field_name\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | sed -n '1p'
}

detect_board_model_raw() {
    raw="$(read_system_board_field model 2>/dev/null || true)"
    [ -n "$raw" ] || raw="$(sed -n '1p' /tmp/sysinfo/model 2>/dev/null || true)"
    [ -n "$raw" ] || raw="$(tr -d '\000' < /proc/device-tree/model 2>/dev/null | sed -n '1p' || true)"
    printf '%s\n' "$raw"
}

detect_board_name_raw() {
    raw="$(read_system_board_field board_name 2>/dev/null || true)"
    [ -n "$raw" ] || raw="$(sed -n '1p' /tmp/sysinfo/board_name 2>/dev/null || true)"
    printf '%s\n' "$raw"
}

detect_board_compatible_raw() {
    raw="$(tr '\000' '\n' < /proc/device-tree/compatible 2>/dev/null | sed -n '1,8p' | tr '\n' ' ' || true)"
    printf '%s\n' "$raw"
}

detect_nros_revision() {
    rev="$(read_system_board_field revision 2>/dev/null || true)"
    [ -n "$rev" ] || rev="$(sed -n "s/^DISTRIB_REVISION='\\([^']*\\)'/\\1/p" /etc/openwrt_release 2>/dev/null | sed -n '1p' || true)"
    [ -n "$rev" ] || rev="$(sed -n 's/^BUILD_ID=\"\([^\"]*\)\"$/\1/p' /etc/os-release 2>/dev/null | sed -n '1p' || true)"
    rev="$(printf '%s' "$rev" | sed 's/^NROS[[:space:]]*//; s/^NROS//')"
    printf '%s\n' "$rev"
}

normalize_nradio_model() {
    raw_model="$1"
    raw_board="$2"
    raw_compat="$3"
    combined="$(printf '%s %s %s' "$raw_model" "$raw_board" "$raw_compat" | tr '[:lower:]' '[:upper:]')"

    case "$combined" in
        *HC-WT9104*)
            printf '%s\n' 'NRadio_C8-688'
            ;;
        *HC-WT9126*)
            printf '%s\n' 'NRadio_C5800-688'
            ;;
        *HC-WT9111*|*NRADIO-WT9111*)
            printf '%s\n' 'NRadio_NBCPE'
            ;;
        *HC-WT9303*)
            printf '%s\n' 'NRadio_C2000MAX'
            ;;
        *)
            printf '%s\n' ''
            ;;
    esac
}

is_supported_nros_revision() {
    case "$1" in
        2.*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

detect_c2000max_storage_mount() {
    local mount_path

    mount_path="$(awk '$1 ~ /^\/dev\/mmcblk[0-9]+p[0-9]+$/ && $2 ~ /^\/tmp\/storage\// { print $2; exit }' /proc/mounts 2>/dev/null || true)"
    [ -n "$mount_path" ] && {
        printf '%s\n' "$mount_path"
        return 0
    }

    mount_path="$(awk '$1 ~ /^\/dev\/mmcblk[0-9]+p[0-9]+$/ && $2 == "/mnt/app_data" { print $2; exit }' /proc/mounts 2>/dev/null || true)"
    [ -n "$mount_path" ] && {
        printf '%s\n' "$mount_path"
        return 0
    }

    return 1
}

get_mount_available_kib() {
    local mount_path="$1"
    local avail_kib

    [ -n "$mount_path" ] || return 1
    avail_kib="$(df -k "$mount_path" 2>/dev/null | awk 'NR == 2 { print $4 }' | tr -d '\r' || true)"
    case "$avail_kib" in
        ''|*[!0-9]*)
            return 1
            ;;
    esac

    printf '%s\n' "$avail_kib"
}

format_mib_or_gib() {
    local size_mib="${1:-0}"

    case "$size_mib" in
        ''|*[!0-9]*)
            return 1
            ;;
    esac

    if [ "$size_mib" -ge 1024 ] 2>/dev/null; then
        awk -v v="$size_mib" 'BEGIN { printf "%.1fG", v / 1024 }'
    else
        printf '%sM' "$size_mib"
    fi
}

require_c2000max_storage_ready() {
    local normalized_model="$1"
    local storage_mount storage_avail_kib storage_avail_mib storage_avail_display

    [ "$normalized_model" = 'NRadio_C2000MAX' ] || return 0

    storage_mount="$(detect_c2000max_storage_mount 2>/dev/null || true)"
    [ -n "$storage_mount" ] || die "环境检测失败：当前机型为 NRadio_C2000MAX，但未检测到存储卡，已停止继续安装"

    storage_avail_kib="$(get_mount_available_kib "$storage_mount" 2>/dev/null || true)"
    [ -n "$storage_avail_kib" ] || die "环境检测失败：当前机型为 NRadio_C2000MAX，但无法识别存储卡空间大小，已停止继续安装"

    storage_avail_mib="$((storage_avail_kib / 1024))"
    storage_avail_display="$(format_mib_or_gib "$storage_avail_mib" 2>/dev/null || printf '%sM' "$storage_avail_mib")"
    log "检测到 C2000MAX 存储卡：$storage_mount，可用空间约 ${storage_avail_display}"
}

require_supported_nradio_model_environment() {
    raw_model="$(detect_board_model_raw)"
    raw_board="$(detect_board_name_raw)"
    raw_compat="$(detect_board_compatible_raw)"
    nros_revision="$(detect_nros_revision)"
    normalized_model="$(normalize_nradio_model "$raw_model" "$raw_board" "$raw_compat")"

    [ -n "$nros_revision" ] || die "环境检测失败：无法识别当前 NROS 版本"
    is_supported_nros_revision "$nros_revision" || die "环境检测失败：当前系统不是受支持的 NROS2.x (revision=$nros_revision)"
    [ -n "$normalized_model" ] || die "环境检测失败：当前设备不在支持列表内 (model=$raw_model board_name=$raw_board)"

    CURRENT_DETECTED_MODEL="$normalized_model"
    log "检测到机型：$normalized_model NROS$nros_revision"
    require_c2000max_storage_ready "$normalized_model"
}

log_nradio_oem_environment_hint() {
    if has_nradio_oem_appcenter; then
        log "环境检测: 已检测到 NRadio 应用商店"
        return 0
    fi

    missing_paths="$(collect_missing_nradio_paths)"
    log "环境检测: 未检测到 NRadio 应用商店"
    log "提示: 不支持标准 OpenWrt; 请使用 NRadio 官方固件"
    [ -n "$missing_paths" ] && log "missing: $missing_paths"
}


require_nradio_oem_appcenter() {
    has_nradio_oem_appcenter && return 0
    missing_paths="$(collect_missing_nradio_paths)"
    missing_suffix=""
    [ -n "$missing_paths" ] && missing_suffix=" (missing: $missing_paths)"
    die "unsupported firmware: 未检测到 NRadio 应用商店环境；本脚本仅适用于带 NRadio 应用商店的官方固件，并非标准 OpenWrt$missing_suffix"
}

prompt_with_default() {
    prompt="$1"
    default_value="$2"
    if [ -n "$default_value" ]; then
        printf '%s [%s]: ' "$prompt" "$default_value"
    else
        printf '%s: ' "$prompt"
    fi
    ui_read_line || die "input cancelled"
    PROMPT_RESULT="$UI_READ_RESULT"
    [ -n "$PROMPT_RESULT" ] || PROMPT_RESULT="$default_value"
}

require_root() {
    [ "$(id -u)" = "0" ] || die "please run as root"
}

release_script_lock() {
    [ "${LOCK_OWNER:-0}" = '1' ] || return 0
    rm -rf "$LOCK_DIR" >/dev/null 2>&1 || true
    LOCK_OWNER='0'
}

acquire_script_lock() {
    mkdir -p "$(dirname "$LOCK_DIR")" >/dev/null 2>&1 || true

    if mkdir "$LOCK_DIR" 2>/dev/null; then
        printf '%s\n' "$$" > "$LOCK_DIR/pid"
        LOCK_OWNER='1'
        return 0
    fi

    lock_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
        die "已有其他 nradio-plugin-assistant 实例正在运行（pid $lock_pid）"
    fi

    rm -rf "$LOCK_DIR" 2>/dev/null || die "清理过期脚本锁失败: $LOCK_DIR"
    mkdir "$LOCK_DIR" 2>/dev/null || die "获取脚本锁失败: $LOCK_DIR"
    printf '%s\n' "$$" > "$LOCK_DIR/pid"
    LOCK_OWNER='1'
    log "提示: 已清除过期的脚本锁"
}

download_file() {
    url="$1"
    out="$2"
    tmp_out="$out.tmp"
    keep_partial="${DOWNLOAD_KEEP_PARTIAL:-0}"

    [ -n "$url" ] || return 1

    printf '正在下载: %s\n' "$(format_download_source_label "$url")" >&2

    if ! download_file_once "$url" "$tmp_out"; then
        if [ "$keep_partial" = '1' ] && [ -s "$tmp_out" ]; then
            partial_size="$(get_file_size_bytes "$tmp_out")"
            if [ "$partial_size" -ge "$DOWNLOAD_PARTIAL_RETRY_MIN_BYTES" ] 2>/dev/null && should_retry_partial_download; then
                saved_stall_time="$DOWNLOAD_STALL_TIME"
                saved_stall_speed="$DOWNLOAD_STALL_SPEED"
                DOWNLOAD_STALL_TIME="$DOWNLOAD_PARTIAL_RETRY_STALL_TIME"
                DOWNLOAD_STALL_SPEED="$DOWNLOAD_PARTIAL_RETRY_STALL_SPEED"
                log "提示: 当前镜像已下载 $(format_bytes_human "$partial_size")，正在放宽限速后继续续传..."
                if download_file_once "$url" "$tmp_out"; then
                    DOWNLOAD_STALL_TIME="$saved_stall_time"
                    DOWNLOAD_STALL_SPEED="$saved_stall_speed"
                else
                    DOWNLOAD_STALL_TIME="$saved_stall_time"
                    DOWNLOAD_STALL_SPEED="$saved_stall_speed"
                    return 1
                fi
            else
                return 1
            fi
        else
            if [ "$keep_partial" != '1' ] || [ ! -s "$tmp_out" ]; then
                rm -f "$tmp_out"
            fi
            return 1
        fi
    fi

    [ -s "$tmp_out" ] || { rm -f "$tmp_out"; return 1; }
    mv "$tmp_out" "$out"
}

should_retry_partial_download() {
    retry_tool="${LAST_DOWNLOAD_TOOL:-}"
    retry_rc="${LAST_DOWNLOAD_RC:-1}"

    case "$retry_tool:$retry_rc" in
        curl:18|curl:28)
            return 0
            ;;
        curl:*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

download_file_once() {
    url="$1"
    tmp_out="$2"
    keep_partial="${DOWNLOAD_KEEP_PARTIAL:-0}"
    LAST_DOWNLOAD_TOOL=''
    LAST_DOWNLOAD_RC='0'

    if command -v curl >/dev/null 2>&1; then
        LAST_DOWNLOAD_TOOL='curl'
        case "$url" in
            https://api.github.com/repos/*/releases/assets/*)
                if [ -s "$tmp_out" ]; then
                    if run_download_with_progress "$url" "$tmp_out" curl -k -C - -LfS --silent --show-error --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_MAX_TIME" --speed-time "$DOWNLOAD_STALL_TIME" --speed-limit "$DOWNLOAD_STALL_SPEED" --retry "$DOWNLOAD_RETRY" --retry-delay 2 -H 'Accept: application/octet-stream' -H 'X-GitHub-Api-Version: 2022-11-28' -H 'User-Agent: nradio-plugin-assistant' "$url" -o "$tmp_out"; then
                        LAST_DOWNLOAD_RC='0'
                    else
                        LAST_DOWNLOAD_RC="$?"
                        if [ "$keep_partial" != '1' ] || [ ! -s "$tmp_out" ]; then
                            rm -f "$tmp_out"
                        fi
                        return 1
                    fi
                else
                    rm -f "$tmp_out" 2>/dev/null || true
                    if run_download_with_progress "$url" "$tmp_out" curl -k -LfS --silent --show-error --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_MAX_TIME" --speed-time "$DOWNLOAD_STALL_TIME" --speed-limit "$DOWNLOAD_STALL_SPEED" --retry "$DOWNLOAD_RETRY" --retry-delay 2 -H 'Accept: application/octet-stream' -H 'X-GitHub-Api-Version: 2022-11-28' -H 'User-Agent: nradio-plugin-assistant' "$url" -o "$tmp_out"; then
                        LAST_DOWNLOAD_RC='0'
                    else
                        LAST_DOWNLOAD_RC="$?"
                        if [ "$keep_partial" != '1' ] || [ ! -s "$tmp_out" ]; then
                            rm -f "$tmp_out"
                        fi
                        return 1
                    fi
                fi
                ;;
            *)
                if [ -s "$tmp_out" ]; then
                    if run_download_with_progress "$url" "$tmp_out" curl -k -C - -LfS --silent --show-error --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_MAX_TIME" --speed-time "$DOWNLOAD_STALL_TIME" --speed-limit "$DOWNLOAD_STALL_SPEED" --retry "$DOWNLOAD_RETRY" --retry-delay 2 "$url" -o "$tmp_out"; then
                        LAST_DOWNLOAD_RC='0'
                    else
                        LAST_DOWNLOAD_RC="$?"
                        if [ "$keep_partial" != '1' ] || [ ! -s "$tmp_out" ]; then
                            rm -f "$tmp_out"
                        fi
                        return 1
                    fi
                else
                    rm -f "$tmp_out" 2>/dev/null || true
                    if run_download_with_progress "$url" "$tmp_out" curl -k -LfS --silent --show-error --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_MAX_TIME" --speed-time "$DOWNLOAD_STALL_TIME" --speed-limit "$DOWNLOAD_STALL_SPEED" --retry "$DOWNLOAD_RETRY" --retry-delay 2 "$url" -o "$tmp_out"; then
                        LAST_DOWNLOAD_RC='0'
                    else
                        LAST_DOWNLOAD_RC="$?"
                        if [ "$keep_partial" != '1' ] || [ ! -s "$tmp_out" ]; then
                            rm -f "$tmp_out"
                        fi
                        return 1
                    fi
                fi
                ;;
        esac
    elif command -v wget >/dev/null 2>&1; then
        LAST_DOWNLOAD_TOOL='wget'
        if run_download_with_progress "$url" "$tmp_out" wget -q -c --no-check-certificate -T "$DOWNLOAD_STALL_TIME" -t "$DOWNLOAD_RETRY" -O "$tmp_out" "$url"; then
            LAST_DOWNLOAD_RC='0'
        else
            LAST_DOWNLOAD_RC="$?"
            if [ "$keep_partial" != '1' ] || [ ! -s "$tmp_out" ]; then
                rm -f "$tmp_out"
            fi
            return 1
        fi
    elif command -v uclient-fetch >/dev/null 2>&1; then
        LAST_DOWNLOAD_TOOL='uclient-fetch'
        if run_download_with_progress "$url" "$tmp_out" uclient-fetch -T "$DOWNLOAD_MAX_TIME" -q -O "$tmp_out" "$url"; then
            LAST_DOWNLOAD_RC='0'
        else
            LAST_DOWNLOAD_RC="$?"
            if [ "$keep_partial" != '1' ] || [ ! -s "$tmp_out" ]; then
                rm -f "$tmp_out"
            fi
            return 1
        fi
    else
        die "系统缺少 curl、wget 或 uclient-fetch，无法下载文件"
    fi

    return 0
}

download_from_mirrors() {
    rel="$1"
    out="$2"
    base_list="${3:-$OPENCLASH_MIRRORS}"
    mirror_count=0
    mirror_index=0
    LAST_DOWNLOAD_SOURCE=''

    for base in $base_list; do
        mirror_count=$((mirror_count + 1))
    done

    for base in $base_list; do
        mirror_index=$((mirror_index + 1))
        if download_file "$base/$rel" "$out"; then
            LAST_DOWNLOAD_SOURCE="$base"
            return 0
        fi
        if [ "$mirror_index" -lt "$mirror_count" ]; then
            log "提示: 当前镜像下载未完成，准备切换到下一个镜像..."
        fi
    done

    return 1
}

extract_url_host() {
    url="$1"
    host="${url#*://}"
    host="${host%%/*}"
    host="${host%%:*}"
    printf '%s\n' "$host"
}

extract_url_filename() {
    url="$1"
    path_part="${url#*://}"
    path_part="${path_part#*/}"
    path_part="${path_part%%\?*}"
    file_part="${path_part##*/}"

    case "$url" in
        *response-content-disposition=*)
            disposition_name="$(printf '%s\n' "$url" | sed -n 's/.*[?&]response-content-disposition=[^&]*filename%3D\([^&]*\).*/\1/p' | tail -n 1)"
            disposition_name="${disposition_name%%\%*}"
            if [ -n "$disposition_name" ]; then
                file_part="$disposition_name"
            fi
            ;;
    esac

    [ -n "$file_part" ] || file_part="未知文件"
    printf '%s\n' "$file_part"
}

format_download_source_label() {
    url="$1"
    host="$(extract_url_host "$url")"
    filename="$(extract_url_filename "$url")"

    case "$host" in
        release-assets.githubusercontent.com)
            printf 'GitHub 官方 CDN（%s / %s）\n' "$host" "$filename"
            ;;
        raw.githubusercontent.com)
            printf 'GitHub Raw（%s / %s）\n' "$host" "$filename"
            ;;
        github.com|api.github.com)
            printf 'GitHub 官方（%s / %s）\n' "$host" "$filename"
            ;;
        "")
            printf '%s\n' "$filename"
            ;;
        *)
            printf '%s / %s\n' "$host" "$filename"
            ;;
    esac
}

probe_host_ping_stats() {
    host="$1"
    ping_loss="100"
    ping_avg="999999000"

    if command -v ping >/dev/null 2>&1; then
        ping_output="$(ping -c "$OPENCLASH_CDN_PING_COUNT" -W "$OPENCLASH_CDN_PING_TIMEOUT" "$host" 2>/dev/null || true)"
        ping_loss_parsed="$(printf '%s\n' "$ping_output" | sed -n 's/.* \([0-9][0-9]*\)% packet loss.*/\1/p' | tail -n 1)"
        ping_avg_parsed="$(printf '%s\n' "$ping_output" | sed -n 's/^.*= *[^/]*\/\([^/]*\)\/.*$/\1/p' | tail -n 1)"
        [ -n "$ping_loss_parsed" ] && ping_loss="$ping_loss_parsed"
        if [ -n "$ping_avg_parsed" ]; then
            case "$ping_avg_parsed" in
                *.*)
                    ping_avg_int="${ping_avg_parsed%%.*}"
                    ping_avg_frac="${ping_avg_parsed#*.}"
                    ;;
                *)
                    ping_avg_int="$ping_avg_parsed"
                    ping_avg_frac=""
                    ;;
            esac
            case "$ping_avg_int" in
                ''|*[!0-9]*)
                    ping_avg=""
                    ;;
                *)
                    ping_avg_frac="$(printf '%s000' "$ping_avg_frac" | cut -c1-3)"
                    case "$ping_avg_frac" in
                        ''|*[!0-9]*) ping_avg_frac='000' ;;
                    esac
                    ping_avg="${ping_avg_int}${ping_avg_frac}"
                    ;;
            esac
            [ -n "$ping_avg" ] || ping_avg="999999000"
        fi
    fi

    printf '%s|%s|%s\n' "$ping_loss" "$ping_avg" "$host"
}

format_probe_ping_avg_label() {
    ping_avg_raw="$1"

    case "$ping_avg_raw" in
        ''|*[!0-9]*)
            printf '超时\n'
            return 0
            ;;
    esac

    ping_avg_raw="$(printf '%s' "$ping_avg_raw" | sed 's/^0*//')"
    [ -n "$ping_avg_raw" ] || ping_avg_raw='0'

    if [ "$ping_avg_raw" = '999999000' ]; then
        printf '超时\n'
    else
        printf '%sms\n' "$(( (ping_avg_raw + 500) / 1000 ))"
    fi
}

reorder_urls_by_host_rank() {
    url_list="$1"
    ranked_hosts="$2"
    ordered_urls=""

    for ranked_host in $ranked_hosts; do
        for url in $url_list; do
            [ "$(extract_url_host "$url")" = "$ranked_host" ] || continue
            if [ -n "$ordered_urls" ]; then
                ordered_urls="$ordered_urls $url"
            else
                ordered_urls="$url"
            fi
        done
    done

    for url in $url_list; do
        url_host="$(extract_url_host "$url")"
        host_found='0'
        for ranked_host in $ranked_hosts; do
            if [ "$url_host" = "$ranked_host" ]; then
                host_found='1'
                break
            fi
        done
        [ "$host_found" = '1' ] && continue
        if [ -n "$ordered_urls" ]; then
            ordered_urls="$ordered_urls $url"
        else
            ordered_urls="$url"
        fi
    done

    printf '%s\n' "$ordered_urls"
}

build_urls_from_base_list() {
    rel="$1"
    base_list="$2"

    for base in $base_list; do
        printf '%s/%s\n' "$base" "$rel"
    done
}

append_unique_list_item() {
    current_list="$1"
    candidate_item="$2"

    [ -n "$candidate_item" ] || {
        printf '%s\n' "$current_list"
        return 0
    }

    for existing_item in $current_list; do
        [ "$existing_item" = "$candidate_item" ] && {
            printf '%s\n' "$current_list"
            return 0
        }
    done

    if [ -n "$current_list" ]; then
        printf '%s %s\n' "$current_list" "$candidate_item"
    else
        printf '%s\n' "$candidate_item"
    fi
}

summarize_url_hosts() {
    host_list=""

    for url in "$@"; do
        [ -n "$url" ] || continue
        host="$(extract_url_host "$url" 2>/dev/null || true)"
        [ -n "$host" ] || continue
        host_list="$(append_unique_list_item "$host_list" "$host")"
    done

    printf '%s\n' "$host_list"
}

find_probe_url_for_host() {
    lookup_host="$1"
    shift

    for url_list in "$@"; do
        for url in $url_list; do
            [ "$(extract_url_host "$url")" = "$lookup_host" ] || continue
            printf '%s\n' "$url"
            return 0
        done
    done

    return 1
}

probe_url_http_ms() {
    probe_url="$1"
    probe_ms="999999"

    command -v curl >/dev/null 2>&1 || {
        printf '%s\n' "$probe_ms"
        return 0
    }

    probe_out="$(curl -k -L -I -o /dev/null -sS --connect-timeout "$CDN_HTTP_PROBE_CONNECT_TIMEOUT" --max-time "$CDN_HTTP_PROBE_MAX_TIME" -w '%{http_code}|%{time_starttransfer}' "$probe_url" 2>/dev/null || true)"
    probe_code="${probe_out%%|*}"
    probe_time="${probe_out#*|}"

    if [ -n "$probe_time" ] && [ "$probe_code" != "$probe_out" ] && [ "$probe_code" != '000' ]; then
        probe_ms="$(printf '%s\n' "$probe_time" | awk '($1 ~ /^[0-9.]+$/) { printf "%d\n", ($1 * 1000) + 0.5 }')"
        [ -n "$probe_ms" ] || probe_ms="999999"
        printf '%s\n' "$probe_ms"
        return 0
    fi

    probe_out="$(curl -k -L -r 0-0 -o /dev/null -sS --connect-timeout "$CDN_HTTP_PROBE_CONNECT_TIMEOUT" --max-time "$CDN_HTTP_PROBE_MAX_TIME" -w '%{http_code}|%{time_starttransfer}' "$probe_url" 2>/dev/null || true)"
    probe_code="${probe_out%%|*}"
    probe_time="${probe_out#*|}"

    if [ -n "$probe_time" ] && [ "$probe_code" != "$probe_out" ] && [ "$probe_code" != '000' ]; then
        probe_ms="$(printf '%s\n' "$probe_time" | awk '($1 ~ /^[0-9.]+$/) { printf "%d\n", ($1 * 1000) + 0.5 }')"
        [ -n "$probe_ms" ] || probe_ms="999999"
    fi

    printf '%s\n' "$probe_ms"
}

probe_url_partial_download_ms() {
    probe_url="$1"
    probe_ms="999999"
    probe_range_end="${2:-262143}"
    probe_min_bytes="${3:-1}"

    command -v curl >/dev/null 2>&1 || {
        printf '%s\n' "$probe_ms"
        return 0
    }

    probe_out="$(curl -k -L -r "0-$probe_range_end" -o /dev/null -sS --connect-timeout "$CDN_HTTP_PROBE_CONNECT_TIMEOUT" --max-time "$CDN_HTTP_PROBE_MAX_TIME" -w '%{http_code}|%{time_total}|%{size_download}' "$probe_url" 2>/dev/null || true)"
    probe_code="${probe_out%%|*}"
    probe_rest="${probe_out#*|}"
    probe_time="${probe_rest%%|*}"
    probe_size="${probe_rest##*|}"

    if [ -n "$probe_time" ] && [ "$probe_code" != "$probe_out" ] && [ "$probe_code" != '000' ] && [ "${probe_size:-0}" -ge "$probe_min_bytes" ] 2>/dev/null; then
        probe_ms="$(printf '%s\n' "$probe_time" | awk '($1 ~ /^[0-9.]+$/) { printf "%d\n", ($1 * 1000) + 0.5 }')"
        [ -n "$probe_ms" ] || probe_ms="999999"
    fi

    printf '%s\n' "$probe_ms"
}

rank_hosts_by_partial_download_probe() {
    rank_prefix="$1"
    rank_label="$2"
    url_list="$3"
    rank_range_end="${4:-262143}"
    rank_min_bytes="${5:-1}"

    RANKED_URL_HOSTS=""
    command -v curl >/dev/null 2>&1 || return 0
    [ -n "$url_list" ] || return 0

    rank_tmp="$WORKDIR/${rank_prefix}-partial-rank.txt"
    : > "$rank_tmp"

    log "提示: 正在精排 $rank_label 镜像优先级（部分下载探测，并行）..."
    _pdl_dir="$WORKDIR/${rank_prefix}-partial-parallel"
    mkdir -p "$_pdl_dir" 2>/dev/null
    _pdl_pids=''
    rank_index=1
    for url in $url_list; do
        _pdl_i=$rank_index
        _pdl_url="$url"
        (
            _host="$(extract_url_host "$_pdl_url")"
            _ms="$(probe_url_partial_download_ms "$_pdl_url" "$rank_range_end" "$rank_min_bytes")"
            printf '%09d|%09d|%s\n' "$_ms" "$_pdl_i" "$_host"
        ) > "$_pdl_dir/$rank_index" </dev/null &
        _pdl_pid="$!"
        if [ -n "$_pdl_pids" ]; then
            _pdl_pids="$_pdl_pids $_pdl_pid"
        else
            _pdl_pids="$_pdl_pid"
        fi
        ACTIVE_BACKGROUND_PIDS="$_pdl_pids"
        rank_index=$((rank_index + 1))
    done
    wait_for_pid_list $_pdl_pids
    ACTIVE_BACKGROUND_PIDS=''

    _pdl_n=1
    while [ "$_pdl_n" -lt "$rank_index" ]; do
        if [ -f "$_pdl_dir/$_pdl_n" ]; then
            _pdl_line="$(cat "$_pdl_dir/$_pdl_n")"
            if [ -n "$_pdl_line" ]; then
                _pdl_host="${_pdl_line##*|}"
                _pdl_ms="${_pdl_line%%|*}"
                _pdl_ms_clean="$(printf '%s' "$_pdl_ms" | sed 's/^0*//')"
                [ -n "$_pdl_ms_clean" ] || _pdl_ms_clean="0"
                if [ "$_pdl_ms_clean" = '999999' ]; then
                    _pdl_label="超时"
                else
                    _pdl_label="${_pdl_ms_clean}ms"
                fi
                log "探测-包: $_pdl_host 耗时=$_pdl_label"
                printf '%s\n' "$_pdl_line" >> "$rank_tmp"
            fi
        fi
        _pdl_n=$((_pdl_n + 1))
    done
    rm -rf "$_pdl_dir" 2>/dev/null

    RANKED_URL_HOSTS="$(sort -t '|' -k1,1 -k2,2 "$rank_tmp" | cut -d'|' -f3 | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
}

refine_ranked_hosts_by_http_probe() {
    refine_prefix="$1"
    refine_label="$2"
    ranked_hosts="$3"
    shift 3

    command -v curl >/dev/null 2>&1 || return 0
    [ -n "$ranked_hosts" ] || return 0

    refine_probe_candidates="$WORKDIR/${refine_prefix}-cdn-probe-candidates.txt"
    refine_probe_results="$WORKDIR/${refine_prefix}-cdn-probe-results.txt"
    : > "$refine_probe_candidates"
    : > "$refine_probe_results"

    refine_index=1
    refine_candidate_count=0
    for refine_host in $ranked_hosts; do
        refine_url="$(find_probe_url_for_host "$refine_host" "$@" 2>/dev/null || true)"
        [ -n "$refine_url" ] || continue
        printf '%09d|%s|%s\n' "$refine_index" "$refine_host" "$refine_url" >> "$refine_probe_candidates"
        refine_candidate_count=$((refine_candidate_count + 1))
        refine_index=$((refine_index + 1))
        [ "$refine_candidate_count" -ge "$CDN_HTTP_PROBE_TOP_HOSTS" ] && break
    done

    [ "$refine_candidate_count" -ge 2 ] || return 0

    log "提示: 正在精排 $refine_label CDN 优先级（HTTP 探测，并行）..."
    _http_dir="$WORKDIR/${refine_prefix}-http-parallel"
    mkdir -p "$_http_dir" 2>/dev/null
    _http_i=0
    _http_pids=''
    while IFS='|' read -r refine_order refine_host refine_url; do
        [ -n "$refine_host" ] || continue
        _http_i=$((_http_i + 1))
        (
            _ms="$(probe_url_http_ms "$refine_url")"
            printf '%09d|%s|%s\n' "$_ms" "$refine_order" "$refine_host"
        ) > "$_http_dir/$_http_i" </dev/null &
        _http_pid="$!"
        if [ -n "$_http_pids" ]; then
            _http_pids="$_http_pids $_http_pid"
        else
            _http_pids="$_http_pid"
        fi
        ACTIVE_BACKGROUND_PIDS="$_http_pids"
    done < "$refine_probe_candidates"
    wait_for_pid_list $_http_pids
    ACTIVE_BACKGROUND_PIDS=''

    _http_n=1
    while [ "$_http_n" -le "$_http_i" ]; do
        if [ -f "$_http_dir/$_http_n" ]; then
            _http_line="$(cat "$_http_dir/$_http_n")"
            if [ -n "$_http_line" ]; then
                _http_host="${_http_line##*|}"
                _http_ms_raw="${_http_line%%|*}"
                _http_ms_val="$(printf '%s' "$_http_ms_raw" | sed 's/^0*//')"
                [ -n "$_http_ms_val" ] || _http_ms_val="0"
                if [ "$_http_ms_val" = '999999' ]; then
                    _http_label="超时"
                else
                    _http_label="${_http_ms_val}ms"
                fi
                log "探测-HTTP: $_http_host 首字节=$_http_label"
                printf '%s\n' "$_http_line" >> "$refine_probe_results"
            fi
        fi
        _http_n=$((_http_n + 1))
    done
    rm -rf "$_http_dir" 2>/dev/null

    refined_hosts="$(sort -t '|' -k1,1 -k2,2 "$refine_probe_results" | cut -d'|' -f3 | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    [ -n "$refined_hosts" ] || return 0

    merged_hosts="$refined_hosts"
    for refine_host in $ranked_hosts; do
        refine_found='0'
        for refined_host in $refined_hosts; do
            if [ "$refine_host" = "$refined_host" ]; then
                refine_found='1'
                break
            fi
        done
        [ "$refine_found" = '1' ] && continue
        merged_hosts="$merged_hosts $refine_host"
    done

    RANKED_URL_HOSTS="$(printf '%s\n' "$merged_hosts" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g')"
}

rank_url_list_hosts() {
    rank_prefix="$1"
    rank_label="$2"
    shift 2

    RANKED_URL_HOSTS=""
    if ! command -v ping >/dev/null 2>&1; then
        log "备注:     未找到 ping，保持默认 $rank_label CDN 顺序"
        return 0
    fi
    mkdir -p "$WORKDIR" >/dev/null 2>&1 || return 0

    hosts_tmp="$WORKDIR/${rank_prefix}-cdn-hosts.txt"
    rank_tmp="$WORKDIR/${rank_prefix}-cdn-rank.txt"
    ranked_hosts_tmp="$WORKDIR/${rank_prefix}-cdn-ranked-hosts.txt"
    : > "$hosts_tmp"
    : > "$rank_tmp"

    for url_list in "$@"; do
        for url in $url_list; do
            host="$(extract_url_host "$url")"
            [ -n "$host" ] || continue
            grep -Fx -- "$host" "$hosts_tmp" >/dev/null 2>&1 || printf '%s\n' "$host" >> "$hosts_tmp"
        done
    done

    [ -s "$hosts_tmp" ] || return 0

    log "提示: 正在探测 $rank_label CDN 节点（ping 并行）..."
    _ping_dir="$WORKDIR/${rank_prefix}-ping-parallel"
    mkdir -p "$_ping_dir" 2>/dev/null
    _ping_pids=''
    rank_index=1
    while IFS= read -r host; do
        [ -n "$host" ] || continue
        (
            _result="$(probe_host_ping_stats "$host")"
            _loss="${_result%%|*}"
            _rest="${_result#*|}"
            _avg="${_rest%%|*}"
            case "$_avg" in
                ''|*[!0-9]*) _avg_sort='999999000' ;;
                *)
                    _avg_sort="$(printf '%s' "$_avg" | sed 's/^0*//')"
                    [ -n "$_avg_sort" ] || _avg_sort='0'
                    ;;
            esac
            printf '%03d|%09d|%09d|%s\n' "$_loss" "$_avg_sort" "$rank_index" "$host"
        ) > "$_ping_dir/$rank_index" </dev/null &
        _ping_pid="$!"
        if [ -n "$_ping_pids" ]; then
            _ping_pids="$_ping_pids $_ping_pid"
        else
            _ping_pids="$_ping_pid"
        fi
        ACTIVE_BACKGROUND_PIDS="$_ping_pids"
        rank_index=$((rank_index + 1))
    done < "$hosts_tmp"
    wait_for_pid_list $_ping_pids
    ACTIVE_BACKGROUND_PIDS=''

    _pi=1
    while [ "$_pi" -lt "$rank_index" ]; do
        if [ -f "$_ping_dir/$_pi" ]; then
            _pl="$(cat "$_ping_dir/$_pi")"
            if [ -n "$_pl" ]; then
                _ph="${_pl##*|}"
                _ploss="${_pl%%|*}"
                case "$_ploss" in
                    ''|*[!0-9]*) _ploss_val='100' ;;
                    *)
                        _ploss_val="$(printf '%s' "$_ploss" | sed 's/^0*//')"
                        [ -n "$_ploss_val" ] || _ploss_val='0'
                        ;;
                esac
                _ptmp="${_pl#*|}"
                _pavg_raw="${_ptmp%%|*}"
                _pavg_label="$(format_probe_ping_avg_label "$_pavg_raw")"
                log "探测:    $_ph 丢包=${_ploss_val}% 延迟=$_pavg_label"
                printf '%s\n' "$_pl" >> "$rank_tmp"
            fi
        fi
        _pi=$((_pi + 1))
    done
    rm -rf "$_ping_dir" 2>/dev/null

    sort -t '|' -k1,1 -k2,2 -k3,3 "$rank_tmp" | cut -d'|' -f4 > "$ranked_hosts_tmp"
    RANKED_URL_HOSTS="$(tr '\n' ' ' < "$ranked_hosts_tmp" | sed 's/[[:space:]]*$//')"
    [ -n "$RANKED_URL_HOSTS" ] || return 0
}

optimize_openclash_cdn_order() {
    [ "${OPENCLASH_CDN_RANKED:-0}" = '1' ] && return 0

    rank_url_list_hosts \
        "openclash" \
        "$OPENCLASH_DISPLAY_NAME" \
        "$OPENCLASH_MIRRORS" \
        "$OPENCLASH_CORE_VERSION_MIRRORS" \
        "$OPENCLASH_CORE_SMART_MIRRORS" \
        "$OPENCLASH_GEOASN_MIRRORS"
    [ -n "${RANKED_URL_HOSTS:-}" ] || return 0
    openclash_probe_urls="$(build_urls_from_base_list "version" "$OPENCLASH_MIRRORS")"
    refine_ranked_hosts_by_http_probe "openclash" "$OPENCLASH_DISPLAY_NAME" "$RANKED_URL_HOSTS" "$openclash_probe_urls"

    OPENCLASH_MIRRORS="$(reorder_urls_by_host_rank "$OPENCLASH_MIRRORS" "$RANKED_URL_HOSTS")"
    OPENCLASH_CORE_VERSION_MIRRORS="$(reorder_urls_by_host_rank "$OPENCLASH_CORE_VERSION_MIRRORS" "$RANKED_URL_HOSTS")"
    OPENCLASH_CORE_SMART_MIRRORS="$(reorder_urls_by_host_rank "$OPENCLASH_CORE_SMART_MIRRORS" "$RANKED_URL_HOSTS")"
    OPENCLASH_GEOASN_MIRRORS="$(reorder_urls_by_host_rank "$OPENCLASH_GEOASN_MIRRORS" "$RANKED_URL_HOSTS")"
    OPENCLASH_CDN_RANKED='1'

    log "提示: $OPENCLASH_DISPLAY_NAME CDN 优先级: $RANKED_URL_HOSTS"
}

optimize_adguardhome_cdn_order() {
    [ "${ADGUARDHOME_CDN_RANKED:-0}" = '1' ] && return 0

    rank_url_list_hosts \
        "adguardhome" \
        "AdGuardHome" \
        "$ADGUARDHOME_IPK_URLS" \
        "$ADGUARDHOME_CORE_MIRRORS"
    [ -n "${RANKED_URL_HOSTS:-}" ] || return 0
    refine_ranked_hosts_by_http_probe "adguardhome" "AdGuardHome" "$RANKED_URL_HOSTS" "$ADGUARDHOME_IPK_URLS"

    ADGUARDHOME_IPK_URLS="$(reorder_urls_by_host_rank "$ADGUARDHOME_IPK_URLS" "$RANKED_URL_HOSTS")"
    ADGUARDHOME_CORE_MIRRORS="$(reorder_urls_by_host_rank "$ADGUARDHOME_CORE_MIRRORS" "$RANKED_URL_HOSTS")"
    ADGUARDHOME_CDN_RANKED='1'

    log "提示: AdGuardHome CDN 优先级: $RANKED_URL_HOSTS"
}

get_core_arch() {
    machine="$(uname -m 2>/dev/null || true)"

    case "$machine" in
        x86_64) printf '%s\n' amd64 ;;
        i386|i686) printf '%s\n' 386 ;;
        aarch64|arm64) printf '%s\n' arm64 ;;
        armv7l|armv7) printf '%s\n' armv7 ;;
        armv6l|armv6) printf '%s\n' armv6 ;;
        armv5tel|armv5*) printf '%s\n' armv5 ;;
        mips64el|mips64le) printf '%s\n' mips64le ;;
        mips64) printf '%s\n' mips64 ;;
        mipsel|mipsle)
            if opkg print-architecture 2>/dev/null | awk '$1=="arch" && $2 ~ /_sf$/ {found=1} END{exit found?0:1}'; then
                printf '%s\n' mipsle-softfloat
            else
                printf '%s\n' mipsle-hardfloat
            fi
            ;;
        mips)
            if opkg print-architecture 2>/dev/null | awk '$1=="arch" && $2 ~ /_sf$/ {found=1} END{exit found?0:1}'; then
                printf '%s\n' mips-softfloat
            else
                printf '%s\n' mips-hardfloat
            fi
            ;;
        ppc64le) printf '%s\n' ppc64le ;;
        riscv64) printf '%s\n' riscv64 ;;
        *) return 1 ;;
    esac
}

get_openclash_core_arch() { get_core_arch; }

install_openclash_smart_core() {
    optimize_openclash_cdn_order
    core_arch="$(get_openclash_core_arch 2>/dev/null || true)"
    [ -n "$core_arch" ] || die "无法识别 $OPENCLASH_SMART_DISPLAY_NAME 架构"

    mkdir -p "$WORKDIR/openclash/core" /etc/openclash/core
    core_version_file="$WORKDIR/openclash/core_version"
    smart_core_tar="$WORKDIR/openclash/clash-linux-${core_arch}.tar.gz"
    smart_core_dir="/etc/openclash/core"

    log "提示: 正在从 CDN 下载 $OPENCLASH_SMART_DISPLAY_NAME 版本文件..."
    download_from_mirrors "core_version" "$core_version_file" "$OPENCLASH_CORE_VERSION_MIRRORS" || die "无法从全部 CDN 镜像获取 $OPENCLASH_SMART_DISPLAY_NAME 版本文件"
    smart_core_ver="$(sed -n '2p' "$core_version_file" | sed 's/^v//g' | tr -d '\r\n')"
    [ -n "$smart_core_ver" ] || smart_core_ver="$(sed -n '1p' "$core_version_file" | sed 's/^v//g' | tr -d '\r\n')"
    [ -n "$smart_core_ver" ] || die "无法解析 $OPENCLASH_SMART_DISPLAY_NAME 版本"

    log "提示: 正在从 CDN 下载 $OPENCLASH_SMART_DISPLAY_NAME v$smart_core_ver ($core_arch)..."
    download_from_mirrors "clash-linux-${core_arch}.tar.gz" "$smart_core_tar" "$OPENCLASH_CORE_SMART_MIRRORS" || die "无法从全部 CDN 镜像获取 $OPENCLASH_SMART_DISPLAY_NAME"
    [ -s "$smart_core_tar" ] || die "$OPENCLASH_SMART_DISPLAY_NAME 下载失败"

    for existing in "$smart_core_dir"/clash*; do
        [ -f "$existing" ] && backup_file "$existing"
    done

    tar -xzf "$smart_core_tar" -C "$smart_core_dir" >/dev/null 2>&1 || die "$OPENCLASH_SMART_DISPLAY_NAME 解压失败"
    smart_core_entry="$(tar -tzf "$smart_core_tar" 2>/dev/null | awk 'NF && $0 !~ /\/$/ && $0 ~ /(^|\/)clash([._-]|$)/ { print; exit }')"
    [ -n "$smart_core_entry" ] || smart_core_entry="$(tar -tzf "$smart_core_tar" 2>/dev/null | awk 'NF && $0 !~ /\/$/ { print; exit }')"
    smart_core_entry_target="${smart_core_entry#./}"
    smart_core_binary="$(basename "$smart_core_entry_target" 2>/dev/null || true)"
    [ -n "$smart_core_binary" ] || die "无法定位解压后的 $OPENCLASH_SMART_DISPLAY_NAME 二进制"

    case "$smart_core_binary" in
        clash_meta)
            ;;
        *)
            mv -f "$smart_core_dir/$smart_core_binary" "$smart_core_dir/clash_meta" 2>/dev/null || ln -sf "$smart_core_binary" "$smart_core_dir/clash_meta"
            ;;
    esac

    [ -e "$smart_core_dir/clash" ] || ln -sf clash_meta "$smart_core_dir/clash"
    chmod 755 "$smart_core_dir"/clash* 2>/dev/null || true

    mkdir -p /etc/openclash
    printf '%s\n%s\n' "$(sed -n '1p' "$core_version_file")" "$(sed -n '2p' "$core_version_file")" > /etc/openclash/core_version
    chmod 644 /etc/openclash/core_version 2>/dev/null || true

    geoasn_mmdb="$WORKDIR/openclash/GeoLite2-ASN.mmdb"
    log "提示: 正在从 CDN 下载 $OPENCLASH_DISPLAY_NAME ASN.mmdb..."
    if download_from_mirrors "GeoLite2-ASN.mmdb" "$geoasn_mmdb" "$OPENCLASH_GEOASN_MIRRORS"; then
        backup_file /etc/openclash/ASN.mmdb
        cp -f "$geoasn_mmdb" /etc/openclash/ASN.mmdb
        chmod 644 /etc/openclash/ASN.mmdb 2>/dev/null || true
    else
        log "备注:     ASN.mmdb CDN 下载失败，将依赖运行时兜底"
    fi

    log "安装完成"
    log "核心:     $OPENCLASH_SMART_DISPLAY_NAME"
    log "版本:  $smart_core_ver"
    log "arch:     $core_arch"
    log "path:     $smart_core_dir"
}

download_from_urls() {
    out="$1"
    shift
    url_count=0
    url_index=0
    LAST_DOWNLOAD_SOURCE=''

    for url in "$@"; do
        url_count=$((url_count + 1))
    done

    for url in "$@"; do
        url_index=$((url_index + 1))
        if download_file "$url" "$out"; then
            LAST_DOWNLOAD_SOURCE="$url"
            return 0
        fi
        if [ "$url_index" -lt "$url_count" ]; then
            log "提示: 当前下载地址未完成，准备切换到下一个地址..."
        fi
    done

    return 1
}

backup_file() {
    path="$1"
    [ -f "$path" ] || return 0

    backup_path="$BACKUP_DIR$path.$TS.bak"
    backup_dir="$(dirname "$backup_path")"
    backup_name="$(basename "$path")"
    mkdir -p "$backup_dir"
    cp "$path" "$backup_path"

    case "$BACKUP_KEEP_COUNT" in
        ''|*[!0-9]*)
            ;;
        *)
            [ "$BACKUP_KEEP_COUNT" -ge 1 ] || return 0
            backup_pattern="$backup_dir/$backup_name."*.bak
            set -- $backup_pattern
            [ -e "$1" ] || return 0
            keep_index=0
            for old_backup in $(ls -1t $backup_pattern 2>/dev/null || true); do
                keep_index=$((keep_index + 1))
                [ "$keep_index" -le "$BACKUP_KEEP_COUNT" ] && continue
                rm -f "$old_backup" 2>/dev/null || true
            done
            ;;
    esac
}

ensure_state_dir() {
    mkdir -p "$STATE_DIR"
    chmod 700 "$STATE_DIR" 2>/dev/null || true
}

write_plugin_uninstall_assets() {
    helper="$PLUGIN_UNINSTALL_HELPER"
    controller="$PLUGIN_UNINSTALL_CONTROLLER"

    mkdir -p "$(dirname "$helper")" "$(dirname "$controller")"
    [ -f "$helper" ] && backup_file "$helper"
    [ -f "$controller" ] && backup_file "$controller"

cat > "$helper" <<'EOF_PLUGIN_UNINSTALL_HELPER'
#!/bin/sh
set -eu

plugin="${1:-}"
STATE_DIR="/root/.nradio-plugin-menu"
WORKDIR="/tmp/nradio-plugin-uninstall.$$"
APP_ICON_DIR="/www/luci-static/nradio/images/icon"
OPENCLASH_ICON_NAME="openclash.svg"
ADGUARDHOME_ICON_NAME="adguard.svg"
OPENVPN_ICON_NAME="openvpn.svg"
OPENLIST_ICON_NAME="openlist.svg"
ZEROTIER_ICON_NAME="zerotier.svg"
EASYTIER_ICON_NAME="easytier.svg"
WEBSSH_ICON_NAME="webssh.svg"
WEBSSH_ROUTE="nradioadv/system/webssh"
WEBSSH_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/webssh.lua"
WEBSSH_VIEW="/usr/lib/lua/luci/view/nradio_adv/webssh.htm"
ROUTE_STATE_FILE="$STATE_DIR/openvpn_routes.conf"
ROUTE_LIST_FILE="$STATE_DIR/openvpn_routes.list"
ROUTE_MAP_LIST_FILE="$STATE_DIR/openvpn_map_peers.list"
OPENVPN_DNSMASQ_DOMAIN_STATE_FILE="$STATE_DIR/openvpn_dnsmasq_domains.list"
OPENLIST_ROOT_DIR="/mnt/app_data/openlist"
OPENLIST_BIN_DIR="$OPENLIST_ROOT_DIR/bin"
OPENLIST_BIN_PATH="$OPENLIST_BIN_DIR/openlist"
OPENLIST_LINK_PATH="/usr/bin/openlist"
OPENLIST_DEFAULT_DATA_DIR="/mnt/app_data/openlist/data"
OPENLIST_DEFAULT_TEMP_DIR="/mnt/app_data/openlist/tmp"
OPENLIST_DEFAULT_LOG_PATH="/mnt/app_data/openlist/openlist.log"
EASYTIER_PACKAGE_NAME="easytier"
EASYTIER_LUCI_PACKAGE_NAME="luci-app-easytier"
EASYTIER_I18N_PACKAGE_NAME="luci-i18n-easytier-zh-cn"
EASYTIER_CONTROLLER="/usr/lib/lua/luci/controller/easytier.lua"
EASYTIER_ROUTE="admin/vpn/easytier/easytier"
FANCTRL_DISPLAY_NAME="FanControl"
FANCTRL_PACKAGE_NAME="fanctrl"
FANCTRL_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/fanctrl.lua"
FANCTRL_CBI="/usr/lib/lua/luci/model/cbi/nradio_adv/fanctrl.lua"
FANCTRL_ROUTE="nradioadv/system/fanctrl"
FANCTRL_VIEW_DIR="/usr/lib/lua/luci/view/nradio_fanctrl"
FANCTRL_TEMP_AJAX_VIEW="$FANCTRL_VIEW_DIR/temperature_ajax.htm"
FANCTRL_TEMP_VIEW="$FANCTRL_VIEW_DIR/temperature.htm"
FANCTRL_SERVICE_NAME="fanctrl"
FANCTRL_CONFIG_FILE="/etc/config/$FANCTRL_SERVICE_NAME"
FANCTRL_INIT_FILE="/etc/init.d/$FANCTRL_SERVICE_NAME"
FANCTRL_BIN_PATH="/usr/bin/${FANCTRL_SERVICE_NAME}.sh"
FANCTRL_SECTION_NAME="$FANCTRL_SERVICE_NAME"
FANCTRL_LEGACY_DISPLAY_NAME="FanControl"
FANCTRL_LEGACY_PACKAGE_NAME="fanctrl"
FANCTRL_LEGACY_ROUTE="nradioadv/system/fanctrl"
FANCTRL_ICON_NAME="nradio-fanctrl"
QIYOU_APP_NAME="奇游联机宝"
QIYOU_PACKAGE_NAME="nradio-qiyou"
QIYOU_ROUTE="nradioadv/system/qiyou"
QIYOU_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/qiyou.lua"
QIYOU_VIEW="/usr/lib/lua/luci/view/nradiobridge_qiyou/qiyou.htm"
QIYOU_ICON_NAME="qiyou.svg"
LEIGOD_APP_NAME="雷神加速器"
LEIGOD_PACKAGE_NAME="nradio-leigod"
LEIGOD_ROUTE="nradioadv/system/leigod"
LEIGOD_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/leigod.lua"
LEIGOD_VIEW="/usr/lib/lua/luci/view/nradiobridge_leigod/leigod.htm"
LEIGOD_ICON_NAME="leigod.svg"
LEIGOD_DIR="/usr/sbin/leigod"
LEIGOD_INIT="/etc/init.d/acc"
EASYTIER_ROUTE_STATE_FILE="$STATE_DIR/easytier_routes.conf"
EASYTIER_ROUTE_APPLY_SCRIPT="/etc/easytier/route-apply.sh"

stop_disable() {
    init_script="$1"
    [ -f "$init_script" ] || return 0
    "$init_script" stop >/dev/null 2>&1 || true
    "$init_script" disable >/dev/null 2>&1 || true
}

kill_name() {
    proc_name="$1"
    command -v killall >/dev/null 2>&1 || return 0
    killall "$proc_name" >/dev/null 2>&1 || true
}

remove_pkg_if_present() {
    pkg_name="$1"
    pkg_has_record='0'
    opkg status "$pkg_name" >/dev/null 2>&1 && pkg_has_record='1'
    [ "$pkg_has_record" = '1' ] || opkg files "$pkg_name" >/dev/null 2>&1 && pkg_has_record='1'
    [ "$pkg_has_record" = '1' ] || [ -f "/usr/lib/opkg/info/$pkg_name.control" ] && pkg_has_record='1'
    [ "$pkg_has_record" = '1' ] || [ -f "/usr/lib/opkg/info/$pkg_name.list" ] && pkg_has_record='1'
    [ "$pkg_has_record" = '1' ] || return 0
    opkg remove "$pkg_name" >>/tmp/nradio-plugin-uninstall.log 2>&1 || \
        opkg remove "$pkg_name" --force-depends >>/tmp/nradio-plugin-uninstall.log 2>&1 || true
}

remove_app_icon_file() {
    icon_name="$1"
    [ -n "$icon_name" ] || return 0
    rm -f "$APP_ICON_DIR/$icon_name" 2>/dev/null || true
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
    app_name="$1"
    pkg_name="$2"
    route_name="$3"

    delete_appcenter_sections package name "$app_name"
    delete_appcenter_sections package name "$pkg_name"
    delete_appcenter_sections package_list name "$app_name"
    delete_appcenter_sections package_list pkg_name "$pkg_name"
    delete_appcenter_sections package_list parent "$app_name"
    delete_appcenter_sections package_list luci_module_route "$route_name"
    uci -q commit appcenter >/dev/null 2>&1 || true
}

cleanup_webssh_template_entry() {
    template="/usr/lib/lua/luci/view/nradio_appcenter/appcenter.htm"
    tmp_file="$WORKDIR/appcenter.webssh.cleanup"

    [ -f "$template" ] || return 0
    mkdir -p "$WORKDIR" >/dev/null 2>&1 || true
    awk '
        /app_list\.result\.applist\.unshift\(\{name:"Web SSH"/ { next }
        { print }
    ' "$template" > "$tmp_file" && mv "$tmp_file" "$template"
}

refresh_luci() {
    rm -f /tmp/luci-indexcache /tmp/infocd/cache/appcenter 2>/dev/null || true
    rm -f /tmp/luci-modulecache/* 2>/dev/null || true
    /etc/init.d/infocd restart >/dev/null 2>&1 || true
    /etc/init.d/appcenter restart >/dev/null 2>&1 || true
    /etc/init.d/uhttpd reload >/dev/null 2>&1 || true
}

load_easytier_route_state() {
    ET_ROUTE_LOCAL_SUBNET=''
    ET_ROUTE_REMOTE_SUBNET=''
    ET_ROUTE_LAN_IF=''
    ET_ROUTE_TUN_IF=''
    [ -f "$EASYTIER_ROUTE_STATE_FILE" ] || return 0
    . "$EASYTIER_ROUTE_STATE_FILE" 2>/dev/null || true
}

cleanup_easytier_route_runtime_state() {
    local_subnet="$1"
    remote_subnet="$2"
    lan_if="$3"
    tun_if="$4"

    command -v ip >/dev/null 2>&1 || return 0
    [ -n "$remote_subnet" ] && ip route del "$remote_subnet" 2>/dev/null || true
    [ -n "$remote_subnet" ] && ip rule del to "$remote_subnet" lookup main priority 110 2>/dev/null || true
    [ -n "$local_subnet" ] && [ -n "$remote_subnet" ] && [ -n "$tun_if" ] && command -v iptables >/dev/null 2>&1 && {
        while iptables -t nat -C POSTROUTING -s "$local_subnet" -d "$remote_subnet" -o "$tun_if" -j MASQUERADE >/dev/null 2>&1; do
            iptables -t nat -D POSTROUTING -s "$local_subnet" -d "$remote_subnet" -o "$tun_if" -j MASQUERADE >/dev/null 2>&1 || break
        done
    }
    [ -n "$remote_subnet" ] && [ -n "$local_subnet" ] && [ -n "$lan_if" ] && [ -n "$tun_if" ] && command -v iptables >/dev/null 2>&1 && {
        while iptables -t filter -C FORWARD -s "$remote_subnet" -d "$local_subnet" -i "$tun_if" -o "$lan_if" -j ACCEPT >/dev/null 2>&1; do
            iptables -t filter -D FORWARD -s "$remote_subnet" -d "$local_subnet" -i "$tun_if" -o "$lan_if" -j ACCEPT >/dev/null 2>&1 || break
        done
        while iptables -t filter -C FORWARD -d "$remote_subnet" -i "$lan_if" -o "$tun_if" -j ACCEPT >/dev/null 2>&1; do
            iptables -t filter -D FORWARD -d "$remote_subnet" -i "$lan_if" -o "$tun_if" -j ACCEPT >/dev/null 2>&1 || break
        done
    }
}

cleanup_easytier_route_rc_hook() {
    rc_local="/etc/rc.local"
    rc_tmp="$WORKDIR/rc.local.easytier.cleanup"

    [ -f "$rc_local" ] || return 0
    grep -q 'EASYTIER_ROUTE_WIZARD_BEGIN' "$rc_local" 2>/dev/null || return 0
    mkdir -p "$WORKDIR" >/dev/null 2>&1 || true
    awk '
        /^# EASYTIER_ROUTE_WIZARD_BEGIN$/ { skip = 1; next }
        /^# EASYTIER_ROUTE_WIZARD_END$/ { skip = 0; next }
        skip != 1 { print }
    ' "$rc_local" > "$rc_tmp" && mv "$rc_tmp" "$rc_local"
}

remove_dnsmasq_server_rules_for_domain() {
    domain="$1"
    [ -n "$domain" ] || return 0
    command -v uci >/dev/null 2>&1 || return 0
    [ -f /etc/config/dhcp ] || return 0

    uci -q show dhcp 2>/dev/null | awk -F"'" -v domain="$domain" '
        /\.server=/ {
            value = $2
            prefix = "/" domain "/"
            if (index(value, prefix) == 1) {
                print value
            }
        }
    ' | while IFS= read -r server_rule; do
        [ -n "$server_rule" ] || continue
        uci -q del_list "dhcp.@dnsmasq[0].server=$server_rule" >/dev/null 2>&1 || true
    done
}

cleanup_openvpn_dnsmasq_domain_rules() {
    dnsmasq_changed='0'
    dhcp_restore_file=''

    mkdir -p "$WORKDIR" >/dev/null 2>&1 || true
    if [ -f /etc/config/dhcp ]; then
        dhcp_restore_file="$WORKDIR/openvpn-dnsmasq-dhcp.cleanup.restore.$$"
        cp /etc/config/dhcp "$dhcp_restore_file" >/dev/null 2>&1 || dhcp_restore_file=''
    fi

    if [ -s "$OPENVPN_DNSMASQ_DOMAIN_STATE_FILE" ]; then
        while IFS= read -r managed_domain; do
            [ -n "$managed_domain" ] || continue
            remove_dnsmasq_server_rules_for_domain "$managed_domain"
            dnsmasq_changed='1'
        done < "$OPENVPN_DNSMASQ_DOMAIN_STATE_FILE"
    fi

    current_domain="$(awk '$1=="#nradio-remote-host"{print $2; exit}' /etc/openvpn/client.ovpn 2>/dev/null || true)"
    if [ -n "$current_domain" ]; then
        remove_dnsmasq_server_rules_for_domain "$current_domain"
        dnsmasq_changed='1'
    fi

    if [ "$dnsmasq_changed" = '1' ]; then
        if ! uci -q commit dhcp >/dev/null 2>&1 || ! /etc/init.d/dnsmasq restart >/dev/null 2>&1; then
            uci -q revert dhcp >/dev/null 2>&1 || true
            if [ -n "$dhcp_restore_file" ] && [ -f "$dhcp_restore_file" ]; then
                cp "$dhcp_restore_file" /etc/config/dhcp >/dev/null 2>&1 || true
            fi
            /etc/init.d/dnsmasq restart >/dev/null 2>&1 || true
            rm -f "$dhcp_restore_file" >/dev/null 2>&1 || true
            return 1
        fi
    fi

    rm -f "$OPENVPN_DNSMASQ_DOMAIN_STATE_FILE" "$dhcp_restore_file" 2>/dev/null || true
}

get_openlist_config_value() {
    option_name="$1"
    default_value="$2"
    value="$(uci -q get "openlist.main.$option_name" 2>/dev/null || true)"
    [ -n "$value" ] || value="$default_value"
    printf '%s\n' "$value"
}

delete_iptables_rule_loop() {
    table_name="$1"
    chain_name="$2"
    shift 2

    command -v iptables >/dev/null 2>&1 || return 0
    while iptables -t "$table_name" -C "$chain_name" "$@" >/dev/null 2>&1; do
        iptables -t "$table_name" -D "$chain_name" "$@" >/dev/null 2>&1 || break
    done
}

cleanup_openvpn_target_policy_rules() {
    target="$1"
    lan_if="$2"
    pri=60
    while [ "$pri" -le 119 ]; do
        ip rule del to "$target" lookup main priority "$pri" 2>/dev/null || true
        ip rule del iif "$lan_if" to "$target" lookup main priority "$pri" 2>/dev/null || true
        pri=$((pri + 1))
    done
}

cleanup_openvpn_target_runtime_rules() {
    target="$1"
    lan_if="$2"
    tun_if="$3"
    lan_subnet="$4"
    nat_flag="$5"
    forward_flag="$6"

    [ -n "$target" ] || return 0
    cleanup_openvpn_target_policy_rules "$target" "$lan_if"
    ip route del "$target" 2>/dev/null || true

    case "$nat_flag" in
        1|y|Y|yes|YES|true|TRUE)
            [ -n "$lan_subnet" ] && [ -n "$tun_if" ] && delete_iptables_rule_loop nat POSTROUTING -s "$lan_subnet" -d "$target" -o "$tun_if" -j MASQUERADE
            ;;
    esac

    case "$forward_flag" in
        1|y|Y|yes|YES|true|TRUE)
            [ -n "$lan_if" ] && [ -n "$tun_if" ] && delete_iptables_rule_loop filter FORWARD -d "$target" -i "$lan_if" -o "$tun_if" -j ACCEPT
            [ -n "$lan_if" ] && [ -n "$tun_if" ] && [ -n "$lan_subnet" ] && delete_iptables_rule_loop filter FORWARD -s "$lan_subnet" -d "$target" -i "$lan_if" -o "$tun_if" -j ACCEPT
            [ -n "$lan_if" ] && [ -n "$tun_if" ] && [ -n "$lan_subnet" ] && delete_iptables_rule_loop filter FORWARD -s "$target" -d "$lan_subnet" -i "$tun_if" -o "$lan_if" -j ACCEPT
            ;;
    esac
}

clear_openvpn_route_state_vars() {
    unset ROUTE_LAN_IF ROUTE_TUN_IF ROUTE_LAN_SUBNET ROUTE_TUN_SUBNET ROUTE_NAT ROUTE_FORWARD ROUTE_ENHANCED ROUTE_MAP_ENABLE ROUTE_MAP_IP ROUTE_MAP_KIND ROUTE_MAP_HOST ROUTE_MAP_SUBNET ROUTE_LAN_HOST_IP
}

normalize_openvpn_route_state_vars() {
    case "${ROUTE_MAP_ENABLE:-}" in
        1|y|Y|yes|YES|true|TRUE)
            case "${ROUTE_MAP_KIND:-}" in
                host|subnet) ;;
                *)
                    case "${ROUTE_MAP_IP:-}" in
                        */32)
                            ROUTE_MAP_KIND='host'
                            ROUTE_MAP_HOST="${ROUTE_MAP_IP%/*}"
                            ROUTE_MAP_SUBNET=''
                            ;;
                        */*)
                            ROUTE_MAP_KIND='subnet'
                            ROUTE_MAP_SUBNET="$ROUTE_MAP_IP"
                            ROUTE_MAP_HOST=''
                            ;;
                        "")
                            ;;
                        *)
                            ROUTE_MAP_KIND='host'
                            ROUTE_MAP_HOST="$ROUTE_MAP_IP"
                            ROUTE_MAP_IP="${ROUTE_MAP_IP}/32"
                            ROUTE_MAP_SUBNET=''
                            ;;
                    esac
                    ;;
            esac
            ;;
        *)
            ROUTE_MAP_KIND=''
            ROUTE_MAP_HOST=''
            ROUTE_MAP_SUBNET=''
            ROUTE_MAP_IP=''
            ROUTE_LAN_HOST_IP=''
            ;;
    esac
}

load_openvpn_route_state_for_cleanup() {
    clear_openvpn_route_state_vars
    [ -f "$ROUTE_STATE_FILE" ] || return 0
    if ! . "$ROUTE_STATE_FILE" 2>/dev/null; then
        clear_openvpn_route_state_vars
        return 0
    fi
    normalize_openvpn_route_state_vars
}

cleanup_saved_openvpn_runtime_state() {
    load_openvpn_route_state_for_cleanup
    [ -n "${ROUTE_TUN_IF:-}" ] || return 0

    old_lan_if="${ROUTE_LAN_IF:-br-lan}"
    old_tun_if="${ROUTE_TUN_IF:-}"
    old_lan_subnet="${ROUTE_LAN_SUBNET:-}"
    old_route_nat="${ROUTE_NAT:-n}"
    old_route_forward="${ROUTE_FORWARD:-n}"

    if [ -s "$ROUTE_MAP_LIST_FILE" ]; then
        while IFS='|' read -r old_peer_target old_peer_gw old_peer_kind_saved; do
            [ -n "$old_peer_target" ] || continue
            [ -n "$old_peer_kind_saved" ] || old_peer_kind_saved='host'
            if [ "$old_peer_kind_saved" = 'host' ]; then
                old_peer_target="${old_peer_target%/*}"
                ip neigh del proxy "$old_peer_target" dev "$old_lan_if" 2>/dev/null || true
            fi
            cleanup_openvpn_target_runtime_rules "$old_peer_target" "$old_lan_if" "$old_tun_if" "$old_lan_subnet" "$old_route_nat" "$old_route_forward"
        done < "$ROUTE_MAP_LIST_FILE"
    fi

    old_enhanced_pri=196
    if [ -s "$ROUTE_LIST_FILE" ]; then
        while IFS='|' read -r old_subnet old_gw; do
            [ -n "$old_subnet" ] || continue
            cleanup_openvpn_target_runtime_rules "$old_subnet" "$old_lan_if" "$old_tun_if" "$old_lan_subnet" "$old_route_nat" "$old_route_forward"
            case "${ROUTE_ENHANCED:-n}" in
                1|y|Y|yes|YES|true|TRUE)
                    [ -n "$old_lan_subnet" ] && ip rule del from "$old_lan_subnet" to "$old_subnet" lookup main priority "$old_enhanced_pri" 2>/dev/null || true
                    old_enhanced_pri=$((old_enhanced_pri + 1))
                    ;;
            esac
        done < "$ROUTE_LIST_FILE"
    fi

    case "${ROUTE_MAP_ENABLE:-n}" in
        1|y|Y|yes|YES|true|TRUE)
            case "${ROUTE_MAP_KIND:-}" in
                host)
                    if [ -n "${ROUTE_MAP_HOST:-}" ] && [ -n "${ROUTE_LAN_HOST_IP:-}" ]; then
                        delete_iptables_rule_loop nat PREROUTING -i "$old_tun_if" -d "${ROUTE_MAP_HOST}" -j DNAT --to-destination "${ROUTE_LAN_HOST_IP}"
                        delete_iptables_rule_loop nat OUTPUT -d "${ROUTE_MAP_HOST}" -j DNAT --to-destination "${ROUTE_LAN_HOST_IP}"
                    fi
                    [ -n "${ROUTE_MAP_IP:-}" ] && ip addr del "${ROUTE_MAP_IP}" dev "$old_lan_if" 2>/dev/null || true
                    ;;
                subnet)
                    [ -n "${ROUTE_MAP_SUBNET:-}" ] && [ -n "$old_lan_subnet" ] && delete_iptables_rule_loop nat PREROUTING -i "$old_tun_if" -d "${ROUTE_MAP_SUBNET}" -j NETMAP --to "$old_lan_subnet"
                    [ -n "${ROUTE_MAP_SUBNET:-}" ] && [ -n "$old_lan_subnet" ] && delete_iptables_rule_loop nat OUTPUT -d "${ROUTE_MAP_SUBNET}" -j NETMAP --to "$old_lan_subnet"
                    ;;
            esac
            ;;
    esac
}

cleanup_openclash() {
    stop_disable /etc/init.d/openclash
    kill_name clash
    remove_pkg_if_present luci-app-openclash
    rm -rf /etc/openclash/core 2>/dev/null || true
    rm -f /etc/openclash/ASN.mmdb /etc/openclash/core_version 2>/dev/null || true
    remove_app_icon_file "openclash.png"
    remove_app_icon_file "openclash.svg"
    remove_app_icon_file "$OPENCLASH_ICON_NAME"
    cleanup_appcenter_entry "luci-app-openclash" "luci-app-openclash" "admin/services/openclash"
}

cleanup_webssh() {
    stop_disable /etc/init.d/ttyd
    kill_name ttyd
    cleanup_webssh_template_entry
    rm -f \
        /www/luci-static/nradio/images/icon/"$WEBSSH_ICON_NAME" \
        /usr/bin/ttyd \
        /etc/init.d/ttyd \
        /etc/config/ttyd \
        /usr/lib/lua/luci/controller/ttyd.lua \
        /usr/lib/lua/luci/model/cbi/ttyd.lua \
        /usr/lib/lua/luci/view/ttyd/overview.htm \
        "$WEBSSH_CONTROLLER" \
        "$WEBSSH_VIEW" \
        2>/dev/null || true
    rm -rf /usr/lib/lua/luci/view/ttyd 2>/dev/null || true
    remove_app_icon_file "$WEBSSH_ICON_NAME"
    cleanup_appcenter_entry "Web SSH" "Web SSH" "$WEBSSH_ROUTE"
    cleanup_appcenter_entry "Web SSH" "ttyd" "$WEBSSH_ROUTE"
}

cleanup_adguardhome() {
    stop_disable /etc/init.d/AdGuardHome
    kill_name AdGuardHome
    remove_pkg_if_present luci-app-adguardhome
    rm -rf /usr/bin/AdGuardHome 2>/dev/null || true
    rm -f /usr/lib/lua/luci/controller/AdGuardHome.lua /usr/lib/lua/luci/view/AdGuardHome/oem_wrapper.htm 2>/dev/null || true
    remove_app_icon_file "$ADGUARDHOME_ICON_NAME"
    cleanup_appcenter_entry "luci-app-adguardhome" "luci-app-adguardhome" "admin/services/AdGuardHome"
}

cleanup_openvpn() {
    stop_disable /etc/init.d/openvpn
    kill_name openvpn
    cleanup_saved_openvpn_runtime_state
    cleanup_openvpn_dnsmasq_domain_rules || die "OpenVPN 卸载失败：dnsmasq 域名上游规则清理失败"
    uci -q delete openvpn.custom_config >/dev/null 2>&1 || true
    uci -q commit openvpn >/dev/null 2>&1 || true
    remove_pkg_if_present luci-app-openvpn
    remove_pkg_if_present openvpn-openssl
    rm -f \
        /usr/lib/lua/luci/controller/openvpn.lua \
        /usr/lib/lua/luci/model/cbi/openvpn.lua \
        /usr/lib/lua/luci/model/cbi/openvpn-basic.lua \
        /usr/lib/lua/luci/model/cbi/openvpn-advanced.lua \
        /usr/lib/lua/luci/model/cbi/openvpn-file.lua \
        /usr/lib/lua/luci/view/openvpn/ovpn_css.htm \
        /usr/lib/lua/luci/view/openvpn/pageswitch.htm \
        /usr/lib/lua/luci/view/openvpn/cbi-select-input-add.htm \
        /usr/lib/lua/luci/view/openvpn/overview_intro.htm \
        /usr/lib/lua/luci/view/openvpn/nsection.htm \
        /usr/lib/lua/luci/controller/nradio_adv/openvpn_full.lua \
        /usr/lib/lua/luci/view/nradio_adv/openvpn_full.htm \
        /etc/openvpn/client.ovpn \
        /etc/openvpn/auth.txt \
        /etc/hotplug.d/openvpn/99-openvpn-route \
        /tmp/openvpn-client.log \
        /tmp/openvpn-runtime-fix.log \
        /tmp/openvpn-route-apply.log \
        /var/run/openvpn.custom_config.status \
        /var/run/openvpn.custom_config.pid \
        "$STATE_DIR/openvpn_runtime.conf" \
        "$STATE_DIR/openvpn_routes.conf" \
        "$STATE_DIR/openvpn_ca.crt" \
        "$STATE_DIR/openvpn_client.crt" \
        "$STATE_DIR/openvpn_client.key" \
        "$STATE_DIR/openvpn_tls.key" \
        "$STATE_DIR/openvpn_extra.conf" \
        "$STATE_DIR/openvpn_routes.list" \
        "$STATE_DIR/openvpn_map_peers.list" \
        2>/dev/null || true
    remove_app_icon_file "$OPENVPN_ICON_NAME"
    cleanup_appcenter_entry "OpenVPN" "luci-app-openvpn" "nradioadv/system/openvpnfull"
}

cleanup_openlist() {
    openlist_data_dir="$(get_openlist_config_value data_dir "$OPENLIST_DEFAULT_DATA_DIR")"
    openlist_temp_dir="$(get_openlist_config_value temp_dir "$OPENLIST_DEFAULT_TEMP_DIR")"
    openlist_log_path="$(get_openlist_config_value log_path "$OPENLIST_DEFAULT_LOG_PATH")"
    openlist_bin_real=""
    openlist_root_dir="$OPENLIST_ROOT_DIR"

    if [ -L "$OPENLIST_LINK_PATH" ]; then
        openlist_bin_real="$(readlink -f "$OPENLIST_LINK_PATH" 2>/dev/null || true)"
    fi
    [ -n "$openlist_bin_real" ] || openlist_bin_real="$OPENLIST_BIN_PATH"
    case "$openlist_bin_real" in
        */bin/openlist)
            openlist_root_dir="$(dirname "$(dirname "$openlist_bin_real")")"
            ;;
    esac

    stop_disable /etc/init.d/openlist
    kill_name openlist
    remove_pkg_if_present openlist
    remove_pkg_if_present luci-app-openlist
    remove_pkg_if_present luci-i18n-openlist-zh-cn
    uci show firewall 2>/dev/null | awk '
        /^firewall\.@rule\[[0-9]+\]=rule$/ {
            sec=$1
            sub(/^firewall\./, "", sec)
            sub(/=.*/, "", sec)
            current=sec
            next
        }
        current != "" && $0 == ("firewall." current ".name='\''nradio_openlist'\''") {
            print current
            current=""
        }
    ' | while IFS= read -r sec; do
        [ -n "$sec" ] || continue
        uci -q delete "firewall.$sec" >/dev/null 2>&1 || true
    done
    uci -q commit firewall >/dev/null 2>&1 || true
    /etc/init.d/firewall reload >/dev/null 2>&1 || true
    rm -f \
        "$OPENLIST_LINK_PATH" \
        "$OPENLIST_BIN_PATH" \
        "$openlist_bin_real" \
        /etc/init.d/openlist \
        /usr/libexec/openlist-sync-config \
        /etc/config/openlist \
        /usr/lib/lua/luci/controller/openlist.lua \
        /usr/lib/lua/luci/controller/nradio_adv/openlist.lua \
        /usr/lib/lua/luci/model/cbi/nradio_adv/openlist_basic.lua \
        /usr/lib/lua/luci/view/nradio_adv/openlist_logs.htm \
        2>/dev/null || true
    rm -rf "$openlist_root_dir" "$openlist_data_dir" "$openlist_temp_dir" /etc/openlist /tmp/openlist 2>/dev/null || true
    rm -f "$openlist_log_path" /var/log/openlist.log /tmp/openlist-sync.log 2>/dev/null || true
    remove_app_icon_file "$OPENLIST_ICON_NAME"
    remove_app_icon_file "openlist.png"
    remove_app_icon_file "openlist.svg"
    cleanup_appcenter_entry "OpenList" "OpenList" "nradioadv/system/openlist/basic"
    cleanup_appcenter_entry "OpenList" "openlist" "nradioadv/system/openlist/basic"
    cleanup_appcenter_entry "OpenList" "luci-app-openlist" "admin/services/openlist"
}

cleanup_zerotier() {
    stop_disable /etc/init.d/zerotier
    kill_name zerotier-one
    remove_pkg_if_present zerotier
    rm -f \
        /etc/config/zerotier \
        /usr/lib/lua/luci/controller/nradio_adv/zerotier.lua \
        /usr/lib/lua/luci/model/cbi/nradio_adv/zerotier_basic.lua \
        2>/dev/null || true
    rm -rf /var/lib/zerotier-one /etc/zerotier-one 2>/dev/null || true
    remove_app_icon_file "$ZEROTIER_ICON_NAME"
    cleanup_appcenter_entry "ZeroTier" "zerotier" "nradioadv/system/zerotier/basic"
    cleanup_appcenter_entry "ZeroTier" "ZeroTier" "nradioadv/system/zerotier/basic"
}

cleanup_easytier() {
    load_easytier_route_state || true
    cleanup_easytier_route_runtime_state "${ET_ROUTE_LOCAL_SUBNET:-}" "${ET_ROUTE_REMOTE_SUBNET:-}" "${ET_ROUTE_LAN_IF:-}" "${ET_ROUTE_TUN_IF:-}" || true
    cleanup_easytier_route_rc_hook || true
    stop_disable /etc/init.d/easytier
    kill_name easytier-core
    kill_name easytier-web
    remove_pkg_if_present "$EASYTIER_PACKAGE_NAME"
    remove_pkg_if_present "$EASYTIER_LUCI_PACKAGE_NAME"
    remove_pkg_if_present "$EASYTIER_I18N_PACKAGE_NAME"
    rm -f \
        /etc/config/easytier \
        "$EASYTIER_CONTROLLER" \
        /usr/lib/lua/luci/model/cbi/easytier.lua \
        /usr/lib/lua/luci/view/easytier/easytier_status.htm \
        /usr/lib/lua/luci/i18n/easytier.zh-cn.lmo \
        /etc/uci-defaults/luci-i18n-easytier-zh-cn \
        /usr/bin/easytier-cli \
        /usr/bin/easytier-core \
        /usr/bin/easytier-web \
        /usr/lib/opkg/info/easytier.control \
        /usr/lib/opkg/info/easytier.list \
        /usr/lib/opkg/info/easytier.postinst \
        /usr/lib/opkg/info/easytier.postinst-pkg \
        /usr/lib/opkg/info/easytier.prerm \
        /usr/lib/opkg/info/easytier.postrm \
        /usr/lib/opkg/info/luci-app-easytier.control \
        /usr/lib/opkg/info/luci-app-easytier.list \
        /usr/lib/opkg/info/luci-app-easytier.postinst \
        /usr/lib/opkg/info/luci-app-easytier.postinst-pkg \
        /usr/lib/opkg/info/luci-app-easytier.prerm \
        /usr/lib/opkg/info/luci-app-easytier.postrm \
        /usr/lib/opkg/info/luci-i18n-easytier-zh-cn.control \
        /usr/lib/opkg/info/luci-i18n-easytier-zh-cn.list \
        /usr/lib/opkg/info/luci-i18n-easytier-zh-cn.postinst \
        /usr/lib/opkg/info/luci-i18n-easytier-zh-cn.postinst-pkg \
        /usr/lib/opkg/info/luci-i18n-easytier-zh-cn.prerm \
        /usr/lib/opkg/info/luci-i18n-easytier-zh-cn.postrm \
        /tmp/easytier.log \
        /tmp/easytierweb.log \
        /tmp/easytier.tag \
        /tmp/easytiernew.tag \
        /tmp/easytier_time \
        /tmp/easytierweb_time \
        /tmp/command_easytier \
        /tmp/command_easytierweb \
        "$EASYTIER_ROUTE_STATE_FILE" \
        "$EASYTIER_ROUTE_APPLY_SCRIPT" \
        /tmp/easytier-route-apply.log \
        2>/dev/null || true
    rm -rf /etc/easytier /usr/lib/lua/luci/view/easytier 2>/dev/null || true
    remove_app_icon_file "$EASYTIER_ICON_NAME"
    cleanup_appcenter_entry "EasyTier" "$EASYTIER_PACKAGE_NAME" "$EASYTIER_ROUTE"
    cleanup_appcenter_entry "EasyTier" "$EASYTIER_LUCI_PACKAGE_NAME" "$EASYTIER_ROUTE"
    cleanup_appcenter_entry "$EASYTIER_PACKAGE_NAME" "$EASYTIER_PACKAGE_NAME" "$EASYTIER_ROUTE"
    cleanup_appcenter_entry "$EASYTIER_LUCI_PACKAGE_NAME" "$EASYTIER_LUCI_PACKAGE_NAME" "$EASYTIER_ROUTE"
    cleanup_appcenter_entry "$EASYTIER_I18N_PACKAGE_NAME" "$EASYTIER_I18N_PACKAGE_NAME" "$EASYTIER_ROUTE"
}

cleanup_fanctrl() {
    stop_disable "$FANCTRL_INIT_FILE"
    kill_name "$(basename "$FANCTRL_BIN_PATH")"
    remove_pkg_if_present "$FANCTRL_PACKAGE_NAME"
    rm -f \
        "$FANCTRL_CONFIG_FILE" \
        "$FANCTRL_INIT_FILE" \
        "$FANCTRL_BIN_PATH" \
        "$FANCTRL_CONTROLLER" \
        "$FANCTRL_CBI" \
        "$FANCTRL_TEMP_AJAX_VIEW" \
        "$FANCTRL_TEMP_VIEW" \
        2>/dev/null || true
    rm -rf "$FANCTRL_VIEW_DIR" 2>/dev/null || true
    remove_app_icon_file "$FANCTRL_ICON_NAME"
    cleanup_appcenter_entry "$FANCTRL_DISPLAY_NAME" "$FANCTRL_PACKAGE_NAME" "$FANCTRL_ROUTE"
    cleanup_appcenter_entry "$FANCTRL_LEGACY_DISPLAY_NAME" "$FANCTRL_LEGACY_PACKAGE_NAME" "$FANCTRL_LEGACY_ROUTE"
}

cleanup_qiyou() {
    /etc/qy/qy_acc.sh stop >/dev/null 2>&1 || true
    [ -x /tmp/qy/init.sh ] && /tmp/qy/init.sh stop >/dev/null 2>&1 || true
    kill_name qy_proxy
    kill_name qy_mosq
    kill_name qy_acc
    rm -rf /tmp/qy /etc/qy 2>/dev/null || true
    rm -f /tmp/qyplug.sh /tmp/qyplug.ret /tmp/qyplug.pid /tmp/qyplug.get /tmp/qiyou-install.sh 2>/dev/null || true
    rm -f /etc/init.d/qy_acc.boot /etc/rc.d/S99qy_acc.boot 2>/dev/null || true
    rm -f "$QIYOU_CONTROLLER" "$QIYOU_VIEW" 2>/dev/null || true
    remove_app_icon_file "$QIYOU_ICON_NAME"
    cleanup_appcenter_entry "$QIYOU_APP_NAME" "$QIYOU_PACKAGE_NAME" "$QIYOU_ROUTE"
    cleanup_appcenter_entry "$QIYOU_PACKAGE_NAME" "$QIYOU_PACKAGE_NAME" "$QIYOU_ROUTE"
}

cleanup_leigod() {
    if [ -x "$LEIGOD_INIT" ]; then
        "$LEIGOD_INIT" disable >/dev/null 2>&1 || true
        "$LEIGOD_INIT" stop >/dev/null 2>&1 || true
    fi
    if [ -f "$LEIGOD_DIR/leigod_uninstall.sh" ]; then
        ( cd "$LEIGOD_DIR" && sh ./leigod_uninstall.sh ) >>/tmp/nradio-plugin-uninstall.log 2>&1 || true
    else
        kill_name acc-gw.router.arm64
        kill_name acc-gw.router.aarch64
        kill_name acc_upgrade_monitor
        rm -rf "$LEIGOD_DIR" /tmp/acc 2>/dev/null || true
        rm -f "$LEIGOD_INIT" /etc/config/accelerator 2>/dev/null || true
    fi
    rm -f "$LEIGOD_CONTROLLER" "$LEIGOD_VIEW" 2>/dev/null || true
    remove_app_icon_file "$LEIGOD_ICON_NAME"
    cleanup_appcenter_entry "$LEIGOD_APP_NAME" "$LEIGOD_PACKAGE_NAME" "$LEIGOD_ROUTE"
    cleanup_appcenter_entry "$LEIGOD_PACKAGE_NAME" "$LEIGOD_PACKAGE_NAME" "$LEIGOD_ROUTE"
}

case "$plugin" in
    openclash)
        cleanup_openclash
        ;;
    webssh)
        cleanup_webssh
        ;;
    adguardhome)
        cleanup_adguardhome
        ;;
    openvpn)
        cleanup_openvpn
        ;;
    openlist)
        cleanup_openlist
        ;;
    zerotier)
        cleanup_zerotier
        ;;
    easytier)
        cleanup_easytier
        ;;
    fanctrl)
        cleanup_fanctrl
        ;;
    qiyou)
        cleanup_qiyou
        ;;
    leigod)
        cleanup_leigod
        ;;
    *)
        exit 1
        ;;
esac

refresh_luci
exit 0
EOF_PLUGIN_UNINSTALL_HELPER
    chmod 755 "$helper"

    cat > "$controller" <<'EOF_PLUGIN_UNINSTALL_CONTROLLER'
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
    entry({"nradioadv", "system", "plugin_uninstall", "leigod"}, call("uninstall_leigod"), nil, 106).leaf = true
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
    elseif name == "雷神加速器" or name == "Leigod" or name == "LeigodAcc" or name == "leigod" or name == "nradio-leigod" then
        return "leigod"
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

function uninstall_leigod()
    start_plugin("leigod")
end
EOF_PLUGIN_UNINSTALL_CONTROLLER
}

shell_quote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\''/g")"
}

write_openvpn_runtime_state_file() {
    ensure_state_dir
    {
        printf 'OVPN_SERVER=%s\n' "$(shell_quote "${OVPN_SERVER:-}")"
        printf 'OVPN_PORT=%s\n' "$(shell_quote "${OVPN_PORT:-}")"
        printf 'OVPN_TRANSPORT=%s\n' "$(shell_quote "${OVPN_TRANSPORT:-}")"
        printf 'OVPN_FAMILY=%s\n' "$(shell_quote "${OVPN_FAMILY:-}")"
        printf 'OVPN_CIPHER=%s\n' "$(shell_quote "${OVPN_CIPHER:-}")"
        printf 'OVPN_MTU=%s\n' "$(shell_quote "${OVPN_MTU:-}")"
        printf 'OVPN_AUTH_DIGEST=%s\n' "$(shell_quote "${OVPN_AUTH_DIGEST:-}")"
        printf 'OVPN_LZO=%s\n' "$(shell_quote "${OVPN_LZO:-}")"
        printf 'OVPN_AUTH_MODE=%s\n' "$(shell_quote "${OVPN_AUTH_MODE:-}")"
        printf 'OVPN_USER=%s\n' "$(shell_quote "${OVPN_USER:-}")"
        printf 'OVPN_TLS_MODE=%s\n' "$(shell_quote "${OVPN_TLS_MODE:-}")"
        printf 'OVPN_SERVER_VERIFY=%s\n' "$(shell_quote "${OVPN_SERVER_VERIFY:-}")"
        printf 'OVPN_VERIFY_CN=%s\n' "$(shell_quote "${OVPN_VERIFY_CN:-}")"
        printf 'OVPN_SERVER_CN=%s\n' "$(shell_quote "${OVPN_SERVER_CN:-}")"
        printf 'OVPN_KEY_DIRECTION=%s\n' "$(shell_quote "${OVPN_KEY_DIRECTION:-}")"
    } > "$RUNTIME_STATE_FILE"
    chmod 600 "$RUNTIME_STATE_FILE" 2>/dev/null || true
}

clear_openvpn_runtime_state_vars() {
    unset OVPN_SERVER OVPN_PORT OVPN_TRANSPORT OVPN_FAMILY OVPN_CIPHER OVPN_MTU OVPN_AUTH_DIGEST OVPN_LZO OVPN_AUTH_MODE OVPN_USER OVPN_TLS_MODE OVPN_SERVER_VERIFY OVPN_VERIFY_CN OVPN_SERVER_CN OVPN_KEY_DIRECTION
}

clear_openvpn_selfcheck_runtime_view() {
    unset OVPN_SELFCHECK_RUNTIME_SOURCE
}

synthesize_openvpn_runtime_state_from_current_profile() {
    ovpn_file="/etc/openvpn/client.ovpn"
    [ -f "$ovpn_file" ] || return 0

    clear_openvpn_runtime_state_vars
    load_openvpn_runtime_defaults_from_profile
    [ -n "${OVPN_SERVER:-}" ] || return 0
    [ -n "${OVPN_KEY_DIRECTION:-}" ] || OVPN_KEY_DIRECTION="$(awk '$1=="key-direction"{print $2; exit}' "$ovpn_file" 2>/dev/null || true)"

    extract_inline_block_to_file "$ovpn_file" ca "$RUNTIME_CA_FILE"
    if [ "${OVPN_AUTH_MODE:-}" = '2' ] || [ "${OVPN_AUTH_MODE:-}" = '3' ]; then
        extract_inline_block_to_file "$ovpn_file" cert "$RUNTIME_CERT_FILE"
        extract_inline_block_to_file "$ovpn_file" key "$RUNTIME_KEY_FILE"
    else
        rm -f "$RUNTIME_CERT_FILE" "$RUNTIME_KEY_FILE" 2>/dev/null || true
    fi

    case "${OVPN_TLS_MODE:-n}" in
        auth)
            extract_inline_block_to_file "$ovpn_file" tls-auth "$RUNTIME_TLS_FILE"
            [ -n "${OVPN_KEY_DIRECTION:-}" ] || OVPN_KEY_DIRECTION='1'
            ;;
        crypt)
            extract_inline_block_to_file "$ovpn_file" tls-crypt "$RUNTIME_TLS_FILE"
            ;;
        *)
            rm -f "$RUNTIME_TLS_FILE" 2>/dev/null || true
            OVPN_TLS_MODE='n'
            ;;
    esac

    write_openvpn_runtime_state_file
}

save_openvpn_runtime_state() {
    ensure_state_dir
    cp "$ca_tmp" "$RUNTIME_CA_FILE" 2>/dev/null || true
    [ -f "$cert_tmp" ] && cp "$cert_tmp" "$RUNTIME_CERT_FILE" 2>/dev/null || rm -f "$RUNTIME_CERT_FILE" 2>/dev/null || true
    [ -f "$key_tmp" ] && cp "$key_tmp" "$RUNTIME_KEY_FILE" 2>/dev/null || rm -f "$RUNTIME_KEY_FILE" 2>/dev/null || true
    [ -f "$ta_tmp" ] && cp "$ta_tmp" "$RUNTIME_TLS_FILE" 2>/dev/null || rm -f "$RUNTIME_TLS_FILE" 2>/dev/null || true
    [ -f "$extra_tmp" ] && cp "$extra_tmp" "$RUNTIME_EXTRA_FILE" 2>/dev/null || rm -f "$RUNTIME_EXTRA_FILE" 2>/dev/null || true

    OVPN_SERVER="${ovpn_server:-}"
    OVPN_PORT="${ovpn_port:-}"
    OVPN_TRANSPORT="${ovpn_transport:-}"
    OVPN_FAMILY="${ovpn_family:-}"
    OVPN_CIPHER="${ovpn_cipher:-}"
    OVPN_MTU="${ovpn_mtu:-}"
    OVPN_AUTH_DIGEST="${ovpn_auth_digest:-}"
    case "${ovpn_lzo:-0}" in
        1|y|Y|yes|YES) OVPN_LZO='y' ;;
        *) OVPN_LZO='n' ;;
    esac
    OVPN_AUTH_MODE="${ovpn_auth_mode:-}"
    OVPN_USER="${ovpn_user:-}"
    case "${ovpn_tls_mode:-0}" in
        auth|crypt) OVPN_TLS_MODE="$ovpn_tls_mode" ;;
        *) OVPN_TLS_MODE='n' ;;
    esac
    case "${ovpn_server_verify:-compat}" in
        strict|2) OVPN_SERVER_VERIFY='2' ;;
        *) OVPN_SERVER_VERIFY='1' ;;
    esac
    case "${ovpn_verify_cn:-0}" in
        1|y|Y|yes|YES) OVPN_VERIFY_CN='y' ;;
        *) OVPN_VERIFY_CN='n' ;;
    esac
    OVPN_SERVER_CN="${ovpn_server_cn:-}"
    OVPN_KEY_DIRECTION="${ovpn_key_direction:-}"
    write_openvpn_runtime_state_file
}

load_openvpn_runtime_state() {
    ensure_state_dir
    clear_openvpn_runtime_state_vars
    if [ ! -f "$RUNTIME_STATE_FILE" ] && [ "${NRADIO_READONLY_SELFTEST:-0}" != '1' ]; then
        synthesize_openvpn_runtime_state_from_current_profile
    fi
    if [ -f "$RUNTIME_STATE_FILE" ]; then
        if ! . "$RUNTIME_STATE_FILE" 2>/dev/null; then
            rm -f "$RUNTIME_STATE_FILE"
            clear_openvpn_runtime_state_vars
        fi
    fi
}

prepare_openvpn_selfcheck_runtime_view() {
    ovpn_file="$1"

    clear_openvpn_selfcheck_runtime_view
    OVPN_SELFCHECK_RUNTIME_SOURCE='saved'
    [ -f "$RUNTIME_STATE_FILE" ] && return 0
    [ -f "$ovpn_file" ] || return 0

    clear_openvpn_runtime_state_vars
    load_openvpn_runtime_defaults_from_profile
    [ -n "${OVPN_SERVER:-}" ] || return 0
    OVPN_SELFCHECK_RUNTIME_SOURCE='profile'
}

save_openvpn_route_state() {
    ensure_state_dir

    route_nat_save='n'
    [ "$route_nat" = '1' ] && route_nat_save='y'
    route_forward_save='n'
    [ "$route_forward" = '1' ] && route_forward_save='y'
    route_enhanced_save='n'
    [ "${route_enhanced:-0}" = '1' ] && route_enhanced_save='y'
    route_map_enable_save='n'
    [ "${route_map_enable:-0}" = '1' ] && route_map_enable_save='y'
    {
        printf 'ROUTE_LAN_IF=%s\n' "$(shell_quote "$lan_if")"
        printf 'ROUTE_TUN_IF=%s\n' "$(shell_quote "$tun_if")"
        printf 'ROUTE_LAN_SUBNET=%s\n' "$(shell_quote "$lan_subnet")"
        printf 'ROUTE_TUN_SUBNET=%s\n' "$(shell_quote "$tun_subnet")"
        printf 'ROUTE_NAT=%s\n' "$(shell_quote "$route_nat_save")"
        printf 'ROUTE_FORWARD=%s\n' "$(shell_quote "$route_forward_save")"
        printf 'ROUTE_ENHANCED=%s\n' "$(shell_quote "$route_enhanced_save")"
        printf 'ROUTE_MAP_ENABLE=%s\n' "$(shell_quote "$route_map_enable_save")"
        printf 'ROUTE_MAP_IP=%s\n' "$(shell_quote "${map_ip:-}")"
        printf 'ROUTE_MAP_KIND=%s\n' "$(shell_quote "${map_kind:-}")"
        printf 'ROUTE_MAP_HOST=%s\n' "$(shell_quote "${map_host:-}")"
        printf 'ROUTE_MAP_SUBNET=%s\n' "$(shell_quote "${map_subnet:-}")"
        printf 'ROUTE_LAN_HOST_IP=%s\n' "$(shell_quote "${lan_host_ip:-}")"
    } > "$ROUTE_STATE_FILE"
    cp "$route_tmp" "$ROUTE_LIST_FILE" 2>/dev/null || true
    if [ "${route_map_enable:-0}" = '1' ] && [ -n "${map_route_tmp:-}" ] && [ -s "$map_route_tmp" ]; then
        cp "$map_route_tmp" "$ROUTE_MAP_LIST_FILE" 2>/dev/null || true
    else
        rm -f "$ROUTE_MAP_LIST_FILE" 2>/dev/null || true
    fi
}

normalize_openvpn_route_state_vars() {
    case "${ROUTE_MAP_ENABLE:-}" in
        1|y|Y|yes|YES|true|TRUE)
            case "${ROUTE_MAP_KIND:-}" in
                host|subnet) ;;
                *)
                    case "${ROUTE_MAP_IP:-}" in
                        */32)
                            ROUTE_MAP_KIND='host'
                            ROUTE_MAP_HOST="${ROUTE_MAP_IP%/*}"
                            ROUTE_MAP_SUBNET=''
                            ;;
                        */*)
                            ROUTE_MAP_KIND='subnet'
                            ROUTE_MAP_SUBNET="$ROUTE_MAP_IP"
                            ROUTE_MAP_HOST=''
                            ;;
                        "")
                            ;;
                        *)
                            ROUTE_MAP_KIND='host'
                            ROUTE_MAP_HOST="$ROUTE_MAP_IP"
                            ROUTE_MAP_IP="${ROUTE_MAP_IP}/32"
                            ROUTE_MAP_SUBNET=''
                            ;;
                    esac
                    ;;
            esac
            ;;
        *)
            ROUTE_MAP_KIND=''
            ROUTE_MAP_HOST=''
            ROUTE_MAP_SUBNET=''
            ROUTE_MAP_IP=''
            ROUTE_LAN_HOST_IP=''
            ;;
    esac
}

load_openvpn_route_state() {
    ensure_state_dir
    clear_openvpn_route_state_vars
    if [ -f "$ROUTE_STATE_FILE" ]; then
        if ! . "$ROUTE_STATE_FILE" 2>/dev/null; then
            rm -f "$ROUTE_STATE_FILE"
            clear_openvpn_route_state_vars
        else
            normalize_openvpn_route_state_vars
        fi
    fi
}

clear_openvpn_route_state_vars() {
    unset ROUTE_LAN_IF ROUTE_TUN_IF ROUTE_LAN_SUBNET ROUTE_TUN_SUBNET ROUTE_NAT ROUTE_FORWARD ROUTE_ENHANCED ROUTE_MAP_ENABLE ROUTE_MAP_IP ROUTE_MAP_KIND ROUTE_MAP_HOST ROUTE_MAP_SUBNET ROUTE_LAN_HOST_IP
}

clear_openvpn_selfcheck_route_views() {
    unset OVPN_SELFCHECK_ROUTE_STATE_SOURCE OVPN_SELFCHECK_ROUTE_LIST_SOURCE OVPN_SELFCHECK_MAP_LIST_SOURCE OVPN_SELFCHECK_ROUTE_LIST_FILE OVPN_SELFCHECK_MAP_LIST_FILE
}

openvpn_hotplug_get_value() {
    key_name="$1"
    hotplug_file="$2"
    awk -F'"' -v key="$key_name" '$0 ~ ("^" key "=") { print $2; exit }' "$hotplug_file" 2>/dev/null || true
}

synthesize_openvpn_route_state_from_hotplug() {
    hotplug_file="$1"
    [ -f "$hotplug_file" ] || return 1

    route_state_filled='0'
    if [ -z "${ROUTE_LAN_IF:-}" ]; then
        ROUTE_LAN_IF="$(openvpn_hotplug_get_value "LAN_IF" "$hotplug_file")"
        [ -n "${ROUTE_LAN_IF:-}" ] && route_state_filled='1'
    fi
    if [ -z "${ROUTE_TUN_IF:-}" ]; then
        ROUTE_TUN_IF="$(openvpn_hotplug_get_value "TUN_IF" "$hotplug_file")"
        [ -n "${ROUTE_TUN_IF:-}" ] && route_state_filled='1'
    fi
    if [ -z "${ROUTE_LAN_SUBNET:-}" ]; then
        ROUTE_LAN_SUBNET="$(openvpn_hotplug_get_value "LAN_SUBNET" "$hotplug_file")"
        [ -n "${ROUTE_LAN_SUBNET:-}" ] && route_state_filled='1'
    fi
    if [ -z "${ROUTE_TUN_SUBNET:-}" ]; then
        ROUTE_TUN_SUBNET="$(openvpn_hotplug_get_value "TUN_SUBNET" "$hotplug_file")"
        [ -n "${ROUTE_TUN_SUBNET:-}" ] && route_state_filled='1'
    fi
    if [ -z "${ROUTE_MAP_KIND:-}" ]; then
        ROUTE_MAP_KIND="$(openvpn_hotplug_get_value "MAP_KIND" "$hotplug_file")"
        [ -n "${ROUTE_MAP_KIND:-}" ] && route_state_filled='1'
    fi
    if [ -z "${ROUTE_MAP_IP:-}" ]; then
        ROUTE_MAP_IP="$(openvpn_hotplug_get_value "MAP_IP" "$hotplug_file")"
        [ -n "${ROUTE_MAP_IP:-}" ] && route_state_filled='1'
    fi
    if [ -z "${ROUTE_MAP_HOST:-}" ]; then
        ROUTE_MAP_HOST="$(openvpn_hotplug_get_value "MAP_HOST" "$hotplug_file")"
        [ -n "${ROUTE_MAP_HOST:-}" ] && route_state_filled='1'
    fi
    if [ -z "${ROUTE_MAP_SUBNET:-}" ]; then
        ROUTE_MAP_SUBNET="$(openvpn_hotplug_get_value "MAP_SUBNET" "$hotplug_file")"
        [ -n "${ROUTE_MAP_SUBNET:-}" ] && route_state_filled='1'
    fi
    if [ -z "${ROUTE_LAN_HOST_IP:-}" ]; then
        ROUTE_LAN_HOST_IP="$(openvpn_hotplug_get_value "LAN_HOST_IP" "$hotplug_file")"
        [ -n "${ROUTE_LAN_HOST_IP:-}" ] && route_state_filled='1'
    fi

    if grep -q 'ensure_iptables_rule nat POSTROUTING' "$hotplug_file" 2>/dev/null; then
        [ -n "${ROUTE_NAT:-}" ] || ROUTE_NAT='y'
        route_state_filled='1'
    fi
    if grep -q 'ensure_iptables_rule filter FORWARD' "$hotplug_file" 2>/dev/null; then
        [ -n "${ROUTE_FORWARD:-}" ] || ROUTE_FORWARD='y'
        route_state_filled='1'
    fi
    if grep -q 'TUN_SUPERNET=' "$hotplug_file" 2>/dev/null; then
        [ -n "${ROUTE_ENHANCED:-}" ] || ROUTE_ENHANCED='y'
        route_state_filled='1'
    fi
    case "${ROUTE_MAP_KIND:-}" in
        host|subnet)
            ROUTE_MAP_ENABLE='y'
            route_state_filled='1'
            ;;
        *)
            [ -n "${ROUTE_MAP_ENABLE:-}" ] || ROUTE_MAP_ENABLE='n'
            ;;
    esac

    normalize_openvpn_route_state_vars
    [ "$route_state_filled" = '1' ]
}

synthesize_openvpn_map_list_from_runtime() {
    map_list_tmp="$WORKDIR/openvpn-selfcheck-map.list"
    lan_if_name="$1"
    tun_if_name="$2"

    : > "$map_list_tmp"
    [ "${ROUTE_MAP_ENABLE:-n}" = 'y' ] || return 1

    case "${ROUTE_MAP_KIND:-}" in
        host)
            ip neigh show proxy dev "$lan_if_name" 2>/dev/null | awk '$2=="proxy"{print $1}' | while IFS= read -r proxy_target; do
                [ -n "$proxy_target" ] || continue
                proxy_gw="$(ip route 2>/dev/null | awk -v target="$proxy_target" -v tun="$tun_if_name" '$1==target && $2=="via" && $4=="dev" && $5==tun {print $3; exit}')"
                [ -n "$proxy_gw" ] || continue
                grep -q "^$proxy_target|" "$map_list_tmp" 2>/dev/null && continue
                printf '%s|%s|host\n' "$proxy_target" "$proxy_gw" >> "$map_list_tmp"
            done
            ;;
        *)
            return 1
            ;;
    esac

    [ -s "$map_list_tmp" ]
}

synthesize_openvpn_route_list_from_runtime() {
    route_list_tmp="$WORKDIR/openvpn-selfcheck-routes.list"
    map_list_tmp="$1"
    tun_if_name="$2"

    : > "$route_list_tmp"
    ip route 2>/dev/null | while IFS= read -r route_line; do
        route_dst="$(printf '%s\n' "$route_line" | awk '$2=="via" && $4=="dev" {print $1; exit}')"
        route_gw="$(printf '%s\n' "$route_line" | awk '$2=="via" && $4=="dev" {print $3; exit}')"
        route_dev="$(printf '%s\n' "$route_line" | awk '$2=="via" && $4=="dev" {print $5; exit}')"
        [ -n "$route_dst" ] || continue
        [ "$route_dev" = "$tun_if_name" ] || continue

        route_skip='0'
        if [ -n "$map_list_tmp" ] && [ -s "$map_list_tmp" ]; then
            while IFS='|' read -r peer_map_target _ peer_map_kind_saved; do
                [ -n "$peer_map_target" ] || continue
                if [ "$peer_map_kind_saved" = 'host' ]; then
                    peer_map_match="${peer_map_target%/*}"
                else
                    peer_map_match="$peer_map_target"
                fi
                if [ "$route_dst" = "$peer_map_match" ]; then
                    route_skip='1'
                    break
                fi
            done < "$map_list_tmp"
        fi
        [ "$route_skip" = '1' ] && continue
        grep -q "^$route_dst|" "$route_list_tmp" 2>/dev/null && continue
        printf '%s|%s\n' "$route_dst" "$route_gw" >> "$route_list_tmp"
    done

    [ -s "$route_list_tmp" ]
}

prepare_openvpn_selfcheck_route_views() {
    hotplug_file="$1"
    tun_if_name="$2"
    lan_if_name="$3"

    mkdir -p "$WORKDIR" >/dev/null 2>&1 || true
    clear_openvpn_selfcheck_route_views
    OVPN_SELFCHECK_ROUTE_LIST_FILE="$ROUTE_LIST_FILE"
    OVPN_SELFCHECK_MAP_LIST_FILE="$ROUTE_MAP_LIST_FILE"
    OVPN_SELFCHECK_ROUTE_STATE_SOURCE='saved'
    OVPN_SELFCHECK_ROUTE_LIST_SOURCE='saved'
    OVPN_SELFCHECK_MAP_LIST_SOURCE='saved'

    if [ ! -e "$ROUTE_STATE_FILE" ] && synthesize_openvpn_route_state_from_hotplug "$hotplug_file"; then
        OVPN_SELFCHECK_ROUTE_STATE_SOURCE='hotplug'
        [ -n "${ROUTE_TUN_IF:-}" ] && tun_if_name="$ROUTE_TUN_IF"
        [ -n "${ROUTE_LAN_IF:-}" ] && lan_if_name="$ROUTE_LAN_IF"
    fi

    if [ ! -s "$ROUTE_MAP_LIST_FILE" ] && synthesize_openvpn_map_list_from_runtime "$lan_if_name" "$tun_if_name"; then
        OVPN_SELFCHECK_MAP_LIST_FILE="$WORKDIR/openvpn-selfcheck-map.list"
        OVPN_SELFCHECK_MAP_LIST_SOURCE='runtime'
    fi

    if [ ! -s "$ROUTE_LIST_FILE" ] && synthesize_openvpn_route_list_from_runtime "${OVPN_SELFCHECK_MAP_LIST_FILE:-}" "$tun_if_name"; then
        OVPN_SELFCHECK_ROUTE_LIST_FILE="$WORKDIR/openvpn-selfcheck-routes.list"
        OVPN_SELFCHECK_ROUTE_LIST_SOURCE='runtime'
    fi
}

clear_openvpn_route_snapshot_vars() {
    unset OLD_ROUTE_LAN_IF OLD_ROUTE_TUN_IF OLD_ROUTE_LAN_SUBNET OLD_ROUTE_TUN_SUBNET OLD_ROUTE_NAT OLD_ROUTE_FORWARD OLD_ROUTE_ENHANCED OLD_ROUTE_MAP_ENABLE OLD_ROUTE_MAP_IP OLD_ROUTE_MAP_KIND OLD_ROUTE_MAP_HOST OLD_ROUTE_MAP_SUBNET OLD_ROUTE_LAN_HOST_IP
}

load_openvpn_route_state_snapshot() {
    clear_openvpn_route_snapshot_vars
    [ -f "$ROUTE_STATE_FILE" ] || return 0

    clear_openvpn_route_state_vars
    if ! . "$ROUTE_STATE_FILE" 2>/dev/null; then
        rm -f "$ROUTE_STATE_FILE"
        clear_openvpn_route_state_vars
        return 0
    fi
    normalize_openvpn_route_state_vars

    OLD_ROUTE_LAN_IF="${ROUTE_LAN_IF:-}"
    OLD_ROUTE_TUN_IF="${ROUTE_TUN_IF:-}"
    OLD_ROUTE_LAN_SUBNET="${ROUTE_LAN_SUBNET:-}"
    OLD_ROUTE_TUN_SUBNET="${ROUTE_TUN_SUBNET:-}"
    OLD_ROUTE_NAT="${ROUTE_NAT:-}"
    OLD_ROUTE_FORWARD="${ROUTE_FORWARD:-}"
    OLD_ROUTE_ENHANCED="${ROUTE_ENHANCED:-}"
    OLD_ROUTE_MAP_ENABLE="${ROUTE_MAP_ENABLE:-}"
    OLD_ROUTE_MAP_IP="${ROUTE_MAP_IP:-}"
    OLD_ROUTE_MAP_KIND="${ROUTE_MAP_KIND:-}"
    OLD_ROUTE_MAP_HOST="${ROUTE_MAP_HOST:-}"
    OLD_ROUTE_MAP_SUBNET="${ROUTE_MAP_SUBNET:-}"
    OLD_ROUTE_LAN_HOST_IP="${ROUTE_LAN_HOST_IP:-}"

    clear_openvpn_route_state_vars
}

install_ipk_file() {
    ipk_path="$1"
    label="$2"

    [ -s "$ipk_path" ] || die "$label 安装失败，缺少安装包 $ipk_path"

    if ! opkg install "$ipk_path" --force-reinstall >/tmp/nradio-plugin-ipk.install.log 2>&1; then
        sed -n '1,200p' /tmp/nradio-plugin-ipk.install.log >&2
        die "$label 安装失败"
    fi
}

install_optional_ipk_file() {
    ipk_path="$1"
    label="$2"

    [ -s "$ipk_path" ] || return 1

    if opkg install "$ipk_path" --force-reinstall >/tmp/nradio-plugin-ipk.install.log 2>&1; then
        return 0
    fi

    log "Note: $label install failed; continue with installed components"
    return 1
}

install_ipk_file_force_flags_verify() {
    ipk_path="$1"
    label="$2"
    pkg_name="$3"
    verify_path="$4"
    shift 4

    [ -s "$ipk_path" ] || die "$label 安装失败，缺少安装包 $ipk_path"

    if opkg install "$ipk_path" --force-reinstall "$@" >/tmp/nradio-plugin-ipk.install.log 2>&1; then
        return 0
    fi

    sed -n '1,200p' /tmp/nradio-plugin-ipk.install.log >&2
    die "$label 安装失败"
}

extract_ipk_archive() {
    ipk_path="$1"
    dest_dir="$2"

    rm -rf "$dest_dir"
    mkdir -p "$dest_dir"

    if tar -xzf "$ipk_path" -C "$dest_dir" >/dev/null 2>&1 && [ -f "$dest_dir/data.tar.gz" ] && [ -f "$dest_dir/control.tar.gz" ]; then
        return 0
    fi

    rm -rf "$dest_dir"
    mkdir -p "$dest_dir"

    if command -v ar >/dev/null 2>&1; then
        (cd "$dest_dir" && ar x "$ipk_path" >/dev/null 2>&1) || true
    else
        (cd "$dest_dir" && busybox ar x "$ipk_path" >/dev/null 2>&1) || true
    fi

    [ -f "$dest_dir/data.tar.gz" ] && [ -f "$dest_dir/control.tar.gz" ] || die "解包 ipk 失败: $ipk_path"
}

get_primary_arch() {
    opkg print-architecture 2>/dev/null | awk '
        $1 == "arch" && $2 != "all" {
            print $2
            exit
        }
    '
}

repack_ipk_control() {
    src_ipk="$1"
    out_ipk="$2"
    target_arch="$3"
    depends_line="$4"

    repack_dir="$WORKDIR/repack.$(basename "$out_ipk")"
    extract_ipk_archive "$src_ipk" "$repack_dir/pkg"
    mkdir -p "$repack_dir/control"
    tar -xzf "$repack_dir/pkg/control.tar.gz" -C "$repack_dir/control" >/dev/null 2>&1 || die "解包 control 失败: $src_ipk"
    sed -i "s/^Architecture: .*/Architecture: $target_arch/" "$repack_dir/control/control"
    if [ -n "$depends_line" ]; then
        if grep -q '^Depends: ' "$repack_dir/control/control"; then
            sed -i "s/^Depends: .*/Depends: $depends_line/" "$repack_dir/control/control"
        else
            printf 'Depends: %s\n' "$depends_line" >> "$repack_dir/control/control"
        fi
    fi
    tar -czf "$repack_dir/pkg/control.tar.gz" -C "$repack_dir/control" .
    (cd "$repack_dir/pkg" && tar -czf "$out_ipk" ./debian-binary ./data.tar.gz ./control.tar.gz)
    [ -s "$out_ipk" ] || die "重新打包 ipk 失败: $src_ipk"
}

verify_appcenter_route() {
    plugin_name="$1"
    expect_route="$2"
    found_sec=''
    first_actual_route=''

    sec_list="$(uci show appcenter 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            "appcenter.@package_list"*".name='${plugin_name}'"|"appcenter.cfg"*".name='${plugin_name}'")
                sec="${line#appcenter.}"
                sec="${sec%%.*}"
                printf '%s\n' "$sec"
                ;;
        esac
    done)"

    for sec in $sec_list; do
        [ -n "$sec" ] || continue
        found_sec='1'
        actual_route="$(uci -q get appcenter.$sec.luci_module_route 2>/dev/null || true)"
        [ -n "$first_actual_route" ] || first_actual_route="$actual_route"
        if [ "$actual_route" = "$expect_route" ]; then
            return 0
        fi
        actual_controller="$(uci -q get appcenter.$sec.luci_module_file 2>/dev/null || true)"
        case "$plugin_name" in
            luci-app-openclash)
                [ "$actual_controller" = "/usr/lib/lua/luci/controller/openclash.lua" ] && return 0
                ;;
            luci-app-adguardhome)
                [ "$actual_controller" = "/usr/lib/lua/luci/controller/AdGuardHome.lua" ] && return 0
                ;;
            OpenVPN)
                [ "$actual_controller" = "/usr/lib/lua/luci/controller/nradio_adv/openvpn_full.lua" ] && return 0
                ;;
        esac
    done

    if [ -z "$found_sec" ]; then
        die "$plugin_name verify failed: appcenter package_list missing"
    fi
    die "$plugin_name verify failed: appcenter route mismatch ($first_actual_route)"
}

ensure_default_feeds() {
    [ -f "$FEEDS" ] || return 0

    mkdir -p "$WORKDIR"
    feeds_tmp="$WORKDIR/distfeeds.default"

    cat > "$feeds_tmp" <<'EOF'
# Unsupported vendor target feeds disabled
# src/gz openwrt_core https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/21.02.7/targets/mediatek/mt7987/packages
src/gz openwrt_base https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/21.02.7/packages/aarch64_cortex-a53/base
src/gz openwrt_luci https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/21.02.7/packages/aarch64_cortex-a53/luci
# Vendor private feed unavailable on Tsinghua mirror
# src/gz openwrt_mtk_openwrt_feed https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/21.02.7/packages/aarch64_cortex-a53/mtk_openwrt_feed
src/gz openwrt_packages https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/21.02.7/packages/aarch64_cortex-a53/packages
src/gz openwrt_routing https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/21.02.7/packages/aarch64_cortex-a53/routing
src/gz openwrt_telephony https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/21.02.7/packages/aarch64_cortex-a53/telephony
EOF

    if ! cmp -s "$feeds_tmp" "$FEEDS"; then
        backup_file "$FEEDS"
        cp "$feeds_tmp" "$FEEDS"
    fi
}

ensure_opkg_update() {
    [ -f "$FEEDS" ] || return 0
    ensure_default_feeds

    if opkg update >/tmp/nradio-plugin-opkg.update.log 2>&1; then
        return 0
    fi

    log "警告: 当前软件源执行 opkg update 失败，保持现有源配置不变"
}

ensure_packages() {
    missing=""
    for pkg in "$@"; do
        opkg status "$pkg" >/dev/null 2>&1 && continue
        if ! opkg install "$pkg" >/tmp/nradio-plugin-opkg.install.log 2>&1; then
            missing="$missing $pkg"
        fi
    done

    if [ -n "$missing" ]; then
        log "警告: 仍缺少依赖包:$missing"
    fi
}

get_feed_url() {
    feed_name="$1"
    awk -v n="$feed_name" '$1=="src/gz" && $2==n {print $3; exit}' "$FEEDS" 2>/dev/null
}

get_feed_package_field() {
    feed_name="$1"
    package_name="$2"
    field_name="$3"

    feed_url="$(get_feed_url "$feed_name")"
    [ -n "$feed_url" ] || return 1

    mkdir -p "$WORKDIR/feed-index"
    feed_idx="$WORKDIR/feed-index/${feed_name}.Packages.gz"
    download_file "$feed_url/Packages.gz" "$feed_idx" >/dev/null 2>&1 || return 1

    gzip -dc "$feed_idx" 2>/dev/null | awk -v pkg="$package_name" -v fld="$field_name" '
        $0 == ("Package: " pkg) { found = 1; next }
        found && index($0, fld ": ") == 1 {
            sub("^" fld ": ", "")
            print
            exit
        }
        found && $0 == "" { exit }
    '
}

resolve_feed_package_url() {
    feed_name="$1"
    package_name="$2"

    feed_url="$(get_feed_url "$feed_name")"
    [ -n "$feed_url" ] || return 1
    filename="$(get_feed_package_field "$feed_name" "$package_name" Filename)"
    [ -n "$filename" ] || return 1
    printf '%s/%s\n' "$feed_url" "$filename"
}

resolve_package_url_any_feed() {
    package_name="$1"
    feed_names="$(awk '$1=="src/gz" {print $2}' "$FEEDS" 2>/dev/null)"

    for feed_name in $feed_names; do
        [ -n "$feed_name" ] || continue
        url="$(resolve_feed_package_url "$feed_name" "$package_name" 2>/dev/null || true)"
        if [ -n "$url" ]; then
            printf '%s\n' "$url"
            return 0
        fi
    done

    return 1
}

resolve_package_version_any_feed() {
    package_name="$1"
    feed_names="$(awk '$1=="src/gz" {print $2}' "$FEEDS" 2>/dev/null)"

    for feed_name in $feed_names; do
        [ -n "$feed_name" ] || continue
        ver="$(get_feed_package_field "$feed_name" "$package_name" Version 2>/dev/null || true)"
        if [ -n "$ver" ]; then
            printf '%s\n' "$ver"
            return 0
        fi
    done

    return 1
}

resolve_package_meta_any_feed() {
    package_name="$1"
    feed_names="$(awk '$1=="src/gz" {print $2}' "$FEEDS" 2>/dev/null)"

    for feed_name in $feed_names; do
        [ -n "$feed_name" ] || continue
        feed_url="$(get_feed_url "$feed_name")"
        [ -n "$feed_url" ] || continue
        filename="$(get_feed_package_field "$feed_name" "$package_name" Filename 2>/dev/null || true)"
        [ -n "$filename" ] || continue
        version="$(get_feed_package_field "$feed_name" "$package_name" Version 2>/dev/null || true)"
        printf '%s|%s|%s|%s\n' "$feed_name" "$feed_url" "$filename" "$version"
        return 0
    done

    return 1
}

get_openwrt_release_version_from_feed_url() {
    feed_url="$1"
    printf '%s\n' "$feed_url" | sed -n 's#.*releases/\([^/][^/]*\)/.*#\1#p'
}

build_openwrt_release_mirror_bases() {
    release_version="$1"
    [ -n "$release_version" ] || return 1

    printf '%s %s %s\n' \
        "https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/$release_version" \
        "https://downloads.openwrt.org/releases/$release_version" \
        "https://mirrors.aliyun.com/openwrt/releases/$release_version"
}

build_package_download_urls_from_meta() {
    feed_url="$1"
    filename="$2"

    [ -n "$feed_url" ] || return 1
    [ -n "$filename" ] || return 1

    case "$filename" in
        http://*|https://*)
            printf '%s\n' "$filename"
            return 0
            ;;
    esac

    package_url="$feed_url/$filename"
    urls="$package_url"
    release_version="$(get_openwrt_release_version_from_feed_url "$feed_url" 2>/dev/null || true)"
    [ -n "$release_version" ] || {
        printf '%s\n' "$urls"
        return 0
    }

    feed_suffix="$(printf '%s\n' "$feed_url" | sed -n "s#.*releases/$release_version/##p")"
    [ -n "$feed_suffix" ] || {
        printf '%s\n' "$urls"
        return 0
    }

    case "$filename" in
        "$feed_suffix"/*)
            relative_path="$filename"
            ;;
        /*)
            relative_path="${filename#/}"
            ;;
        *)
            relative_path="$feed_suffix/$filename"
            ;;
    esac

    for base in $(build_openwrt_release_mirror_bases "$release_version" 2>/dev/null || true); do
        candidate="$base/$relative_path"
        [ "$candidate" = "$package_url" ] && continue
        urls="$urls $candidate"
    done

    printf '%s\n' "$urls"
}

get_github_release_asset_browser_url() {
    api_url="$1"
    asset_name="$2"

    command -v curl >/dev/null 2>&1 || return 1
    [ -n "$api_url" ] || return 1
    [ -n "$asset_name" ] || return 1

    api_response="$(curl -k -L -sS --connect-timeout "$DOWNLOAD_HEAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_HEAD_MAX_TIME" -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' -H 'User-Agent: nradio-plugin-assistant' "$api_url" 2>/dev/null || true)"
    [ -n "$api_response" ] || return 1

    browser_candidates="$(printf '%s' "$api_response" | tr -d '\r\n' | sed 's/[[:space:]]*,[[:space:]]*"/\n"/g' | sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed 's#\\/#/#g')"
    [ -n "$browser_candidates" ] || return 1

    for browser_url in $browser_candidates; do
        case "$browser_url" in
            */"$asset_name")
                printf '%s\n' "$browser_url"
                return 0
                ;;
        esac
    done

    return 1
}

get_github_release_asset_api_url() {
    api_url="$1"
    asset_name="$2"

    command -v curl >/dev/null 2>&1 || return 1
    [ -n "$api_url" ] || return 1
    [ -n "$asset_name" ] || return 1

    api_response="$(curl -k -L -sS --connect-timeout "$DOWNLOAD_HEAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_HEAD_MAX_TIME" -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' -H 'User-Agent: nradio-plugin-assistant' "$api_url" 2>/dev/null || true)"
    [ -n "$api_response" ] || return 1

    asset_api_url="$(printf '%s' "$api_response" | tr -d '\r\n' | sed 's#\\/#/#g' | sed -n 's#.*"url"[[:space:]]*:[[:space:]]*"\(https://api\.github\.com/repos/[^"]*/releases/assets/[^"]*\)".*"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*/'"$asset_name"'".*#\1#p')"
    [ -n "$asset_api_url" ] || return 1

    printf '%s\n' "$asset_api_url"
}

run_github_release_asset_resolve_curl() {
    resolve_url="$1"
    shift

    case "$resolve_url" in
        https://api.github.com/repos/*/releases/assets/*)
            curl -k "$@" -H 'Accept: application/octet-stream' -H 'X-GitHub-Api-Version: 2022-11-28' -H 'User-Agent: nradio-plugin-assistant' "$resolve_url"
            ;;
        *)
            curl -k "$@" -H 'User-Agent: nradio-plugin-assistant' "$resolve_url"
            ;;
    esac
}

resolve_github_release_asset_cdn_url() {
    source_url="$1"
    redirect_url=""
    redirect_headers=""
    redirect_location=""
    redirect_try=0

    command -v curl >/dev/null 2>&1 || return 1
    [ -n "$source_url" ] || return 1

    resolved_url="$(run_github_release_asset_resolve_curl "$source_url" -L -I -sS -o /dev/null --connect-timeout "$DOWNLOAD_HEAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_HEAD_MAX_TIME" -w '%{url_effective}' 2>/dev/null || true)"
    case "$resolved_url" in
        https://release-assets.githubusercontent.com/*|https://objects.githubusercontent.com/*)
            printf '%s\n' "$resolved_url"
            return 0
            ;;
    esac

    resolved_url="$(run_github_release_asset_resolve_curl "$source_url" -L -r 0-0 -sS -o /dev/null --connect-timeout "$DOWNLOAD_HEAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_HEAD_MAX_TIME" -w '%{url_effective}' 2>/dev/null || true)"
    case "$resolved_url" in
        https://release-assets.githubusercontent.com/*|https://objects.githubusercontent.com/*)
            printf '%s\n' "$resolved_url"
            return 0
            ;;
    esac

    redirect_url="$source_url"
    while [ "$redirect_try" -lt 6 ] 2>/dev/null; do
        redirect_headers="$(run_github_release_asset_resolve_curl "$redirect_url" -sS -D - -o /dev/null --connect-timeout "$DOWNLOAD_HEAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_HEAD_MAX_TIME" 2>/dev/null || true)"
        redirect_location="$(printf '%s\n' "$redirect_headers" | tr -d '\r' | sed -n 's/^[Ll]ocation: *//p' | tail -n 1)"
        [ -n "$redirect_location" ] || break

        case "$redirect_location" in
            https://release-assets.githubusercontent.com/*|https://objects.githubusercontent.com/*)
                printf '%s\n' "$redirect_location"
                return 0
                ;;
            http://*|https://*)
                redirect_url="$redirect_location"
                ;;
            /*)
                redirect_scheme="$(printf '%s\n' "$redirect_url" | sed -n 's#^\(https\{0,1\}://\).*#\1#p')"
                redirect_host="$(extract_url_host "$redirect_url" 2>/dev/null || true)"
                [ -n "$redirect_scheme" ] || break
                [ -n "$redirect_host" ] || break
                redirect_url="${redirect_scheme}${redirect_host}${redirect_location}"
                ;;
            *)
                break
                ;;
        esac

        case "$redirect_url" in
            https://release-assets.githubusercontent.com/*|https://objects.githubusercontent.com/*)
                printf '%s\n' "$redirect_url"
                return 0
                ;;
        esac

        redirect_try=$((redirect_try + 1))
    done

    return 1
}

build_openlist_download_urls() {
    if [ -n "${OPENLIST_RESOLVED_DOWNLOAD_URLS:-}" ]; then
        printf '%s\n' "$OPENLIST_RESOLVED_DOWNLOAD_URLS"
        return 0
    fi

    openlist_official_latest_url="https://github.com/OpenListTeam/OpenList/releases/latest/download/$OPENLIST_ASSET_NAME"
    openlist_api_latest_url="https://api.github.com/repos/OpenListTeam/OpenList/releases/latest"
    openlist_urls=""

    openlist_browser_url="$(get_github_release_asset_browser_url "$openlist_api_latest_url" "$OPENLIST_ASSET_NAME" 2>/dev/null || true)"
    openlist_asset_api_url="$(get_github_release_asset_api_url "$openlist_api_latest_url" "$OPENLIST_ASSET_NAME" 2>/dev/null || true)"
    [ -n "$openlist_browser_url" ] || openlist_browser_url="$openlist_official_latest_url"

    openlist_resolved_api_cdn_url="$(resolve_github_release_asset_cdn_url "$openlist_asset_api_url" 2>/dev/null || true)"
    openlist_resolved_cdn_url="$(resolve_github_release_asset_cdn_url "$openlist_browser_url" 2>/dev/null || true)"
    openlist_resolved_latest_cdn_url="$(resolve_github_release_asset_cdn_url "$openlist_official_latest_url" 2>/dev/null || true)"
    openlist_urls="$(append_unique_list_item "$openlist_urls" "$openlist_resolved_api_cdn_url")"
    openlist_urls="$(append_unique_list_item "$openlist_urls" "$openlist_resolved_cdn_url")"
    openlist_urls="$(append_unique_list_item "$openlist_urls" "$openlist_resolved_latest_cdn_url")"
    openlist_urls="$(append_unique_list_item "$openlist_urls" "$openlist_asset_api_url")"
    openlist_urls="$(append_unique_list_item "$openlist_urls" "$openlist_browser_url")"
    openlist_urls="$(append_unique_list_item "$openlist_urls" "$openlist_official_latest_url")"

    for openlist_extra_url in $(build_urls_from_base_list "$OPENLIST_ASSET_NAME" "$OPENLIST_GITHUB_CDN_BASES" 2>/dev/null || true); do
        openlist_urls="$(append_unique_list_item "$openlist_urls" "$openlist_extra_url")"
    done

    OPENLIST_RESOLVED_DOWNLOAD_URLS="$openlist_urls"
    printf '%s\n' "$OPENLIST_RESOLVED_DOWNLOAD_URLS"
}

build_easytier_download_urls() {
    if [ -n "${EASYTIER_RESOLVED_DOWNLOAD_URLS:-}" ]; then
        printf '%s\n' "$EASYTIER_RESOLVED_DOWNLOAD_URLS"
        return 0
    fi

    easytier_urls=""
    easytier_browser_url="$(get_github_release_asset_browser_url "$EASYTIER_GITHUB_API_URL" "$EASYTIER_ASSET_NAME" 2>/dev/null || true)"
    easytier_asset_api_url="$(get_github_release_asset_api_url "$EASYTIER_GITHUB_API_URL" "$EASYTIER_ASSET_NAME" 2>/dev/null || true)"
    [ -n "$easytier_browser_url" ] || easytier_browser_url="$EASYTIER_GITHUB_RELEASE_URL"

    easytier_resolved_api_cdn_url="$(resolve_github_release_asset_cdn_url "$easytier_asset_api_url" 2>/dev/null || true)"
    easytier_resolved_cdn_url="$(resolve_github_release_asset_cdn_url "$easytier_browser_url" 2>/dev/null || true)"
    easytier_resolved_latest_cdn_url="$(resolve_github_release_asset_cdn_url "$EASYTIER_GITHUB_RELEASE_URL" 2>/dev/null || true)"
    easytier_urls="$(append_unique_list_item "$easytier_urls" "$easytier_resolved_api_cdn_url")"
    easytier_urls="$(append_unique_list_item "$easytier_urls" "$easytier_resolved_cdn_url")"
    easytier_urls="$(append_unique_list_item "$easytier_urls" "$easytier_resolved_latest_cdn_url")"
    easytier_urls="$(append_unique_list_item "$easytier_urls" "$easytier_asset_api_url")"
    easytier_urls="$(append_unique_list_item "$easytier_urls" "$easytier_browser_url")"
    easytier_urls="$(append_unique_list_item "$easytier_urls" "$EASYTIER_GITHUB_RELEASE_URL")"

    for easytier_extra_url in $(build_urls_from_base_list "$EASYTIER_ASSET_NAME" "$EASYTIER_GITHUB_CDN_BASES" 2>/dev/null || true); do
        easytier_urls="$(append_unique_list_item "$easytier_urls" "$easytier_extra_url")"
    done

    EASYTIER_RESOLVED_DOWNLOAD_URLS="$easytier_urls"
    printf '%s\n' "$EASYTIER_RESOLVED_DOWNLOAD_URLS"
}

find_uci_section() {
    sec_type="$1"
    pkg_name="$2"

    uci show appcenter 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            "appcenter.@${sec_type}"*".name='${pkg_name}'"|"appcenter.cfg"*".name='${pkg_name}'")
                sec="${line#appcenter.}"
                sec="${sec%%.*}"
                printf '%s\n' "$sec"
                break
                ;;
        esac
    done
}

cleanup_appcenter_route_entries() {
    target_route="$1"

    uci show appcenter 2>/dev/null | awk -v route="$target_route" '
        /^appcenter\.@package_list\[[0-9]+\]=package_list$/ {
            sec=$1
            sub(/^appcenter\./, "", sec)
            sub(/=.*/, "", sec)
            current=sec
            next
        }
        current != "" && $0 == ("appcenter." current ".luci_module_route='"'"'" route "'"'"'") {
            print current
            current=""
        }
    ' | while IFS= read -r list_sec; do
        [ -n "$list_sec" ] || continue
        old_name="$(uci -q get "appcenter.$list_sec.name" 2>/dev/null || true)"
        if [ -n "$old_name" ]; then
            pkg_sec="$(find_uci_section package "$old_name")"
            [ -n "$pkg_sec" ] && uci delete "appcenter.$pkg_sec" >/dev/null 2>&1 || true
        fi
        uci delete "appcenter.$list_sec" >/dev/null 2>&1 || true
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
    app_name="$1"
    pkg_name="$2"
    route_name="$3"

    delete_appcenter_sections package name "$app_name"
    delete_appcenter_sections package name "$pkg_name"
    delete_appcenter_sections package_list name "$app_name"
    delete_appcenter_sections package_list pkg_name "$pkg_name"
    delete_appcenter_sections package_list parent "$app_name"
    delete_appcenter_sections package_list luci_module_route "$route_name"
    uci -q commit appcenter >/dev/null 2>&1 || true
}

ensure_app_icon_dir() {
    mkdir -p "$APP_ICON_DIR"
}

remove_app_icon_file() {
    icon_name="$1"
    [ -n "$icon_name" ] || return 0
    rm -f "$APP_ICON_DIR/$icon_name" 2>/dev/null || true
}

install_plugin_icon_from_url_list() {
    plugin_name="$1"
    icon_name="$2"
    url_list="$3"

    [ -n "$plugin_name" ] || return 1
    [ -n "$icon_name" ] || return 1
    [ -n "$url_list" ] || return 1

    ensure_app_icon_dir
    mkdir -p "$WORKDIR/icons"
    icon_tmp="$WORKDIR/icons/$icon_name"

    if ! download_from_urls "$icon_tmp" $url_list; then
        log "备注:     $plugin_name 图标下载失败，将继续使用默认图标"
        return 1
    fi
    icon_url="$LAST_DOWNLOAD_SOURCE"

    [ -s "$icon_tmp" ] || {
        log "备注:     $plugin_name 图标文件为空，将继续使用默认图标"
        return 1
    }

    backup_file "$APP_ICON_DIR/$icon_name"
    cp "$icon_tmp" "$APP_ICON_DIR/$icon_name"
    chmod 644 "$APP_ICON_DIR/$icon_name" 2>/dev/null || true
    log "图标:   $icon_url"
    return 0
}

install_embedded_text_icon() {
    icon_name="$1"
    icon_label="$2"
    icon_text="$3"
    icon_color_a="$4"
    icon_color_b="$5"

    [ -n "$icon_name" ] || return 1
    [ -n "$icon_label" ] || return 1
    [ -n "$icon_text" ] || return 1

    ensure_app_icon_dir
    backup_file "$APP_ICON_DIR/$icon_name"
    cat > "$APP_ICON_DIR/$icon_name" <<EOF_EMBEDDED_ICON
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="$icon_label">
  <!-- NRadio appcenter unified plugin icon V2 -->
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="$icon_color_a"/>
      <stop offset="100%" stop-color="$icon_color_b"/>
    </linearGradient>
    <linearGradient id="shine" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.22"/>
      <stop offset="100%" stop-color="#ffffff" stop-opacity="0.02"/>
    </linearGradient>
    <filter id="shadow" x="-24%" y="-24%" width="148%" height="148%">
      <feDropShadow dx="0" dy="30" stdDeviation="28" flood-color="#020617" flood-opacity="0.32"/>
    </filter>
  </defs>
  <rect x="96" y="96" width="832" height="832" rx="220" fill="#243241" opacity="0.36"/>
  <rect x="132" y="132" width="760" height="760" rx="196" fill="url(#g)" filter="url(#shadow)"/>
  <rect x="158" y="158" width="708" height="708" rx="176" fill="url(#shine)"/>
  <path d="M236 260C314 194 413 158 512 158c128 0 246 55 328 142v-10c0-73-59-132-132-132H316c-73 0-132 59-132 132v134c14-54 31-106 52-164Z" fill="#ffffff" opacity="0.12"/>
  <circle cx="640" cy="328" r="64" fill="#ffffff" fill-opacity="0.16"/>
  <text x="512" y="594" text-anchor="middle" dominant-baseline="middle" font-family="Arial, Helvetica, sans-serif" font-size="252" font-weight="900" fill="#ffffff" letter-spacing="0">$icon_text</text>
  <rect x="132" y="132" width="760" height="760" rx="196" fill="none" stroke="#ffffff" stroke-opacity="0.18" stroke-width="18"/>
</svg>
EOF_EMBEDDED_ICON
    chmod 644 "$APP_ICON_DIR/$icon_name" 2>/dev/null || true
    log "图标:   内置 $icon_label SVG"
    return 0
}

get_openclash_official_logo_base64() {
    cat <<'EOF_OPENCLASH_LOGO_B64' | tr -d '\n'
iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAMAAADDpiTIAAAC+lBMVEUAAAD////8/P7////+/v7////////////////////////////////////+/v////////////////////////////////+GkKH+/v7////////////////////////////////////////////////////4+fv7/Pz+/v7///////////////9thKL///8jRXT///////////////+XoK61u8ZNZIRVdJx6jqnL1N4mS3kkUIdxhqH+/v8+Um9Pb5dfc5FmfJmptsckOFfBxs9PZIKMnbMcN12Nl6coUoagqLUqU4kxUn8/WX1he59abYn///9NXXepsbwaM1lDaJaGmLCTo7pib4UtVYpBYIj////M1NwbNVt7iJs5Xo84UXNAZJNJXXstVoooRGzR2uQqSHQcMVIxRWRCU27W2uApUoaquMspSXMjPF8pQ2fi5Oj09vcrVIpDV3UeN1p5jqhRc50kSHoZLk4vQl47S2dVZX4iS4HM0dgySWotUH3///8rU4aap7lWc5q6xtcpTnwiS38iS4BHZ48fOF0vWY5xfZEiOl0dNVhxjbGbrMUuS3IySGrr7e8jTIIkToRXdJpxiqpqeI0lQWpte5K/xtHq7O8+YZAePmkqS3YcNVoYLlDa3uS0vMedqbmJlae+xc94hpzb3+XP1dyQp8QWL1UVLVEgSX4YNF0UKk4WMFceRHcXMVgVLlMbPGkTKEoZNmATKUwcP24cQHAXM1sbPWsgSX8XMloVLFAfSH0eQ3X///8ZN2IXMlkZN2EYNV4aOmYaO2ccPm0aOWUTKUsaO2gfRnkZOGMfSHwdQXEfR3sfRnoeRXgaOWQbPmwVK08dQnMdQXISJkcYNV8gSoASJ0ghTIMhTYUiT4chTYQhS4IUK08hS4EVLlQhToYZOGQdQnQgS4EiTocWMVkWMVggS4IdQ3YeRnv1
9/lSbpLd4+rH0NtogKCTpbzs7/OaqsDl6e+GmbOxvs4uTHd3i6dIY4hfd5c+WoE0Unu/yNXWc3q0AAAAqXRSTlMAAgYICg4LGgQoESImLhbDHRM0dStBvvI6uaqcH9RUtGxNlFujhDM+N0avzsh+cP3f2oxg7+u/rG9OEfmVaNK7qotf/emxYPjw8O7p6NmcnH347NuEfG/2389kQfzx3NrSzbRSNi78+/rmoEtC9Ovk4cG+rYlC/v38+vjw6OGEd3JZVB8e99fHZF/06oghFOno4+LLcjT19NnX0Zv67sXw1bDcqofEuaVCzcN4wQAANGhJREFUeNrswYEAAAAAgKD9qRepAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZt+OWZwKggAAZ9+7xHiKeGBpbWd9ck8QLYQjYBUlVZCgjVYBUwkip80V2qhV/oC/aWfGYoqF/Avfzibvbc7Kp5B5MN9xlyPXDLOzu7P7csYYY4wxxhhjjDHGGGOMMcYYY4wxxhhjjDHGGGNMf519HvTO68vLs4H5D9zZN8RqeekG/eFWdcx4/rlPMWvlygWKSX9KYPwBxaLsTch6FSvcWZ71Ip+uiCUbMAT80YuAVXPDxTaZAXGy6kFCXbHEnfVRDwLWrfhUyeAnlf5twBWLsIOzE/XxKueGjzFg5qPyjLriTSrYtGr9LAbmX7hrLxn3fNBdAcU0YBJC4PBspDtc9cpXGPVmDRhfVNgKYX5Lc7T6xR2gTxXgvpxjjqtXtgf84w6AojkJRGo7QTda4hX3jwamu/JmhQFFVgiV1tNgOc0LVX5/dKw01n4YPcg6amxMvqjM6nhVBZEVwOyaylB7wp2cIiPztggEMiLOvipMq/s6Y2xI3Iz4sxyYrsY35n8WQIjJXejrrVy5bgY+tAVwfzQw3Q+BFSNvtwARBDNPxwNlxitkzoqVE2sCunPD51wLNcxIctU1gvUGgIwcMhzNbisLtEfcrVMAKQDM
pdwqawRdOWWGWK4cGsAA4ZU1AV0VN14CBE7jz+1JIHBggKWqh+3jH1VaqzjkZQrAD6wJ6Kq8V8mUYmTcJ7NrqqgRdMMlcMhjZZTQGU6tCehq+EKSisjZCSBId80cQFMbUHwHFnmxpgKY201AR+7kGQBHGPavg6UCAPTcBrhPE+lWGFMjyA2A6qailapXxnelBUDmkOS3gYEDwBslqXVHaylVwPjSFqkECU/tcUA35Z0JJLu7AA4sAjADA/GFjiWg7gCJU0yMsgo0MQLRs6GOKHtn9JYIgFNzFX80rxjSBks6zoLbDhARkEUqAkjokX0moBN3/A4ozaoEI94CQQsNh+ziAggE51LoAJMbSnaqnnHXTinLanMPkFcAkYLPBrjjWTv+ORBEdhXUSXFz7oEIiAVuMYLMLJK/KdgEXDkl344/sMQnJEZPdhXUydG9alcAwJBfsEDElKbXm0NPL/fpnCCSOMVeARDZVVAnwyfeUy0lFDlrsNIsAyAg7w98EnCjtSfRDL7EJyjyL+0qqAN38tADAZAkE/cKgOU9En5yyOsgOQJKAexWgBQjCI7xgz+3q6AOxrcf+XZi8RXZ/PLrQ6bXDRdZmNDcA0Ae4dtyYP5WcX3uKcobwZRcBo7v7fJLh3wmUKwoLwAW2/2pFsPbbOxTQd16wF++tt0GBEPTZUNEJAn+drh/wXTDpRd0NU5K0Xmqv6wL7NYDkqdUAMD7HTZws7r6+H24B8PFhd/EIkwFwDXY3/89eesCO/aAGx9R1A781RkWbd4f6jLAHc+zKAly1MZnXeBvdq5mxYkgCDv4Ax4U8T18AKMgXgQRPKkIgoiyl7gXwVtgCbIb8Zr15iPMGzTMG+wDFAGbutRh3sKpqp6udOxoeg+jh/52YKTNJEXV119VV8/MpWpAH11rXs062Pv3/ygJXP3eeyPAPgP7/mPdECyvAWVuWRoQhAWAFobqYD/E39OXSW8SNpl67fn3mQDMAbEzZ9+961cq
ynDt7gMafGcEYI9qh210ss7+4W9w8XrSZoAJAJH8vhR7aqORgMcCAWoVeIkakDxDohwIsKWtpv9KAJqyDjQBeCYk1Uo0GKW2WnoS1CrwEnvBOBLAfBuhTt6Yi+ls+vcxNVe/JzZq4A3GAKpV4CX2ggnRo8/GP/WwgCasA+1GQNolqUHVPxCAahVYvBf8jtS3oRCwIivPAJy8DmyuvbD47xLArEOP6KH2AosfCXhKOMCPheBwJBW2jilBkAGT3SNs28A02IfeWBBYGggbtIk/Q7UKLMSN+0Tsu5QAlmM3weFKAP4gTFUHmgCABHcTbTQhCCe/GQlQq8DSGvAlIGOvxurYOMkYMFE/0AQgMVGhaYrJwIjGwbNaBRbWgM/Nu9G3exmAApjk5iATgGz888YBvKk7wmWPhT4CQMGgsdpM0Rwb4VV6tchiH6PDKfaFTQAcBANRi1UxUfP/rm3g6n2Bhc+EvAXQ6UW+7zd9ogBaE/SBGGhJ4NM0r2VUAXAjQU0AxC4lgC0BEWA4ntcqsLAR7BB2FCDFzzDAwQ9OBvdtqqWgVQA8xXvfD4cfeMpkFR4EckZ1+lqrwLJGsANICcDOZbCDx9Cr4zECptkS0ApAQIS8FrTVSoBXGAFe16dDiprsn50DpyJgC21D6mWFaMAkS0EVAMARPlgYFEBNI0/kQQwb4LA+HVLWCHbRwT44sx9cbE5m6DhFBoArXAo2zWx2ejqbNc1lBADRSerxglgI+pSbalfbPqlVYFEjuHVOFQA0yOJWDb6dvZID5HPIogE//jTRTo+Ovy1P5u/PV6v1erE4cwNa1w7H2WKxXq9W55/m85Plh+Oj2V9eXvTMQaAooNpHo02amojhzS73uN4ScDiu3noWUwB4FPR+dLApAZHkYASBY+R2BZujD8v5+WoxBFoCHs95yP/DYnU+P/l2PMsKwHcWdQcCMqViG1WpRnUSAjDa+oxwAW68aUUB1MEyw8aZJfB9cHZwPqExYHtX
sDk9Xs4/rbcD7g5Bu4Wz1fv58sPRrgAMAIH+PlG0Sc/D0GiXY664t3f+uzcb/rdorr/SQAFDHdxvOTii90RAnIcVMrvDruDs+OTTwuZ0FpYC0n8btngwX45ycO27xR/09xFDOqKexEYhBVIkZvv0Zl0GHIrm9sOuZYADiS6BEkBlVc4CVYCYZ8FxAM9vNEfL+UqlPB9gVYPcuJ3T6wPW708+nDa3X7ugUA7GBUi0K5wB1HRO/618Sb0loOSO4E6cr17kA2PQNz7naGRHO/X26mxfcHX88LH89YvXPCCEAwXC7+TUJWwkgOtqM/hgXL35rou6DYow46XjEh0tBaCVgBKUfHG3G2gOTDYfuIOud+F6qfKjeQkBQGB5pKvN4IJG8FNL3AiJxEqqVajDg0IgWBQzyAcdNJB5ZINvdm3ZBlrwUQTG1AT2TbUZXHA3SNsNf0GGpYpWBwOBbL5ogRXGYAwkfz4fvXyRl8v/mfEduCT+SiACsW04zC5LSa2gq83ggkXAhc00k1gjgI6pw1VsVQXyQTbk87yh7Holnlo3Bt6IEGyKdOza2gwuWAR0XauQ2e8QRiDD64wbO4AGk+qMdBv2NoQOvt6USRtChjEtgBMEFem6i4vaDD74DaGPLowAiiivXrfXEmzn89awJw2AM2TrgT9dn2soJYE3bOciJvRFbQYfvAh4myGAAgMgQSLRXT5+f0emDtiDlDmGkPcVyXewBNRm8C92riC3bRgIAkXbW4EW6KFP6A+CAgX6gOYDRYE8I/cegj5GB98L6AMEsct/6BPd1Upcc8KYjGHoxIkM2oonkTnDXS4tqb8IIDBAHp020gTb663DUcSKWJ738fVlE3gOn1dMwM+CgwnQADGOxeDuIoCiYtZSwASBCCA473BBe4EHAca4ll8YUQ/TWp+PqHGmqBFgLAb3FwGz9NfkBvD+9zxrHe2d31rBQ6DQV/HdBR6h/u0ZwA0wRwHR77EY3FkEnEWAFZgC1ATe
8VsLgnWK7UJfw/f/b60em89IVuwRIM40FoN7iwAwAEQAX/kDTK8FUK+j44QQ/maOAJHGYnDvNwEUSQ2w4ryrJx1lEGJfZQHntBZ8mnA+FATFRFRNLA8zwI+xGNxbBMRd/7Kz3QCKWt6+LBaKVs/7PZaq89c0MAE1BwB6GIvBnUUAxd0CWw6dtwlVGfdn+VkxebiVffo6P5fN+fbc39vmI+cif/NA5svm+keip89jMbirCCDBFgJAiPIbvI7lXhQS3ntbfjHyPQCYBZa4LOOckL4igImjJ4F5cmCuNoMIcJTifgP+/qb8HA2K/V4FCsbNwrpOB7pzA0BnT7BaB+JcELPYl3FTfk4FyJ9nUvmZaNwmogNvpAhYKEaSnznOpQkmXKufC6BI9ZEKgt+Kn4+teO8cdfyTbMQ8zgnpujnMTybeDVAK8Dxf9wmHAhYquqk6+XXj5Mkg8OLkBrgfZUAb7788MjMJ4oqi8wUgHIiBQMHakz8D8lt/G8gOMfGeApgfP4wyoOPCYD43gPagbC4flmMN/TO/MpFr4ozvqO1DmiNSXJbIZgD+M8qAjguDswF8HgD9jNgFsRaFaimN4R73N8R/ni7O32tLGrQZYJQBPRcGpwAG8I6v5/sdpUAVkS/wQfS6SWJ0owle4hfHvBuAOYR092nMApsXBv9lDsSCZVEXGOojuT1jB0GP4avwGUS0EDPrI/waZUD7wuCHsEYAps0Ajpcmd+0FHcNR/C1KuAEWFmgEuB93i2vh7denJA6QjZ8ZAEXBcks2fQ152kU9jE+RZCsigBmAxqnhLbz7JvoHFiylAXw+4B3emJ27WPa7w/jR4BFgYVZTpzRODW/fIjSFHAGYDNFLwgLFBDFWW4GPzGP4HgG0ZcEeAUIaZUCzCPi+ZgDmsLAgd6S21TLP4ALUn1t7FH8/ZkVkIl70M40yoO8WoSmsSKzQBLrItnYlADq+ieP4csACO+59AqhI6dc4Nbx5PlgKBjAAWyq4
GhQP5GfTugFSSKd0GmVA83yw+3Q6hW0iqA/KJiiEKFpFJBQKRTuQvx0zi/oUcgRQF4wyoPVVUDiZAdgNIJu23sEGFAfFQLEO5LO1TGaAxCnJZxplQM9XQem0hkvrMTaYCQw4+hC+H/cdyCd2aEWTeE0BgnGFaOurIOmkpLAsYKPIQA20xDyQXxjXgr9AHTDKgMsG+HinBjj5PMDg6aALljJw34F8tlLWYPrLZ1KMMuA/e1evIzUMhCUECDpKCmoorwNKKOigBImeR0D3CjwFz5Au0TW+LgVSpNUqeYNUEf93By32zK4/Z9aevUWnnE6aj7tzSDyy19/nsWdjJ/tuBQkBhPHT//gDhQyFQBwvag8B8Pi/9QAWBuy9FVSxAlY8DyDy6TuUZEJISAgSQD5xvKA915nrT2m1gYUB+24FTRWB5oCx93usBAlAhhDkw/lF7dkDcP2/EHgImCYLA/RbQVPF4HnginsRDwc3Cau0/oSKMVkYoN4KepcTAGOjALpRJI4VIN+i9hDuChPAgMnCAH1XUEWACiAENDgaXjnnIc4vab9KUX2pth7AOQsD1EcDPHPOVRUiAXgANHCJpNw5pAvbpx6MJrXMfzVZGKDuCvrkKpf3ANS4AiCg9H+cW9h+BSQCCPK2MECLAl87JwQQRXCzMBNAhPOwMKCM2w+PxyCAqaJf7jmrkJIAEBHgGMheR7qwfax3Jfh3tihIiwKdBw2VE3sACCDOBVYKYcrxwvZc5xUEMFWOYWGAtiDQuTFIgLzAHLuEIGXkzuN4YXv0/Mg/+4Dx/QMTQPmd4aMjIBIQAigThmt5spa2h/uHAFwQgIUB2oLArQCmaZr7ADS8aHwA55W8i9lXApMLGMfxyLYIl98Z/h4CqOaYNXD1hdyDgErm4vaS/2lyjNG2CCsLAvveuXQekDgCRAUyBZQ8S9tXE+rvKu794YP1o4UB5QWBRxsBTCQADzQielza6OK8IAd5F7SHAFD/4NPcBuML
e1JQcUFg7zHyEOBAfhaSIED2zGuyT+vvogfwH9CeFFRcEPi29+CG8ogNeGORCsB/qAD/Ae3tUeUosB8G11NjxXmAqyi9eZiS+o+OMLoggCN7YGgxCvQCGPtxjJHAZiLlbqQXSOq/6f3h39AP9sDQYhQ4hCHA/44BYeIUyL+hHsAl9WdJb/jvn1sYUIoCh2HoA2gagAZ0qgC+nf34/vXr9x9n36qlgaI1ARB4/O8HD3tvQDEKDAIg/lkBIyaEAnFucHzx+zTi98VxLg+gXDswT6lowKH+EAAp4KmFAYUosBu6rvcSYP6B0ZWI+Hl+OsP5T+Q7SAg41u31otN8s/qHkS0K4I2FAYUocCsAaquZF0iJoJRQ/TrdwS9cF1GEtM+fry5pny86tU/rT+iHQH83fLYwoBAF+sahRuo9HEKn0e2SQvhzmsGfPLnSHsiTr9uXikY+TjAMBFEPAd0w2OvDClEgBOAxJnA5wtAJZUfUAHvlvA6l6NR+TNATiH8Pe31YIQr0bTN4qAIAfp4W8NNdIf6/6DHFTAAv79gsMBsFpgIYxjAV8C0XUpfB8XmJhfNjd/U4vGjUn/54hDlOUMAre4twPgoMAuh4HNgvgIvTIi7c1eLwonUB2OaQfBTYdB6YBxC4EV2cTAG/yyz8rkRe2KtAXtVeLxp5Uf9xM/9jNJ/tLcL5KJCAYQDIkPHtVME3kKWQqQhAtdeLTgUADISORNB0tjkkGwU2TRd+dgUAIpCeaSyclYhECrLZTbve+R9KCYq9XjTsMwIIaJrGNodko0AaAkgBnRQAkcPHPZPxQ2PhhyBQ2DPp+L/M53rVXi8a9n2Kbmg8SOBdY6vCslFg9AA0WfKgyeD2FvE4J+e7xsJ3kBtsdu1xDGLTc6q9XjTsY/0pJQewEcAL2xyyg9uPX9cNw/NP7KMBM/iqsfBVkimRJxrXVHu96GgPAcD7M2p7cUQ2CvQCCEMA/w4JMsTtZUFCJ15Ctb900UMC5p89
QG2bQ3L7AqMDIEgBSOzxw1ePw4uWAmiiB7DNIbl9gXXDEsBEsBka/wMBsDvloUGfiQ2z8VfYi2s4Rqra60Undlz/xAN0tf+QAbYqLPOigCCA0EDJRJD9QJYQPRbLEKwK4iCB6EUn9lx/FnLXpC7AVoVJ3Hr0rK63AuCG4t5Df9CoEfq3MTMic/aSeAHFfn/RQAPyhyb1ALYqLPN0mNqj8QD53UC9JktKr30fix6rkKpBtXd60bDn+ie9nwQe/tqqsMzTYVgA5AXmGBLEoaHT7sh0s7wZe5mK67q9XnRq30jQ52vr9s0jCwPkM0L/1r5lGB1FArH35Ek6Kt+TPRIEKiRLcgmDbq8Xndqj93Pa1IS2/nzfwgAZBbYeNeYACSIJASCkvCpD5KVUOQfgumavF53mbRhM/pZ+EvoHCwPkM0JbeICGEHtPiaDSuqxMXkAn/rLn1KKRl+sfAQG0djtIPiP0IzkAAjkBoCsivzKzWwCXLHo++kf+Pex20Bz3HrzICyAcCyeAMbX7pXRC5C3a69Dt9aIhAA5t5xpYt2u7HbTzpoh1UEDbRgXExkuJkITs7s6I12Cj2MNFy2u6faFoad+Iz8Luv23Xrd0OklHgmzWTT3+EADJEbXE03591lCFNtZfEH2Avi87ZzAXA/JMHeG27g0QU+Hm9XlMgAPCXJipRIcUOTYRdqY1iL68fZi+KztgT8fgsPP6TB7DbQXPcfdK2LAAQv01zKBGVI/P67CEAgPj3sNtBYknwyfrkpMUwkODghlewtH1NkAIIn9VuB4klwesA3zeI/RTNTcac+7qFB3hpt4PmS4JPTk5IA3Vb9AAIqXCsAHmu0T4FD/8B/sPa7iCxJHh94vs/5gGA3tj7SVncXnMBLIDWa/3NI9sdNFsSvPUArVBAroG5Z8nz+evXbF/0ALY7SCwJVgUgSbncOcI12ye9Pzg4CKB9bHHgP/bOJbdtIAbDi656g56gW+96iyLrrnqWnsDLbNJL
zMLA7DUWtMjG57ASJ0HqZ4BSJGXSjDSAqwZWAn5Vq5cJYchf1IOj6UmXYBYAXwbQYR1a6D7b7H7Nhewl7tyWtkFN9BcR+OXlIF0MjsAC/nAWkGtmxrm8Lb/vsvadAiC8HHRSDI4MpknwlTA7g65AXdZ+DrAIJP0jV14O0v9hZGQ4Awiz981cMALwboEnxeAYYoCJBABpADOBfjHEaZSRdTu3+y5tjxkNZ03wRQDhp5eDdDE4MloAiDi23/kWvf3S9tIWyQAo9msfLE4Xg8En6JjYwGc/0jraogNk0TaXttdtiUigZgYfLE6ND/WbYy9pgBzXJ4CM0836Ze27BIBCB3ywOF0MDgQLQDF/a/4sH+ZvyEKjMkAIPlicKgYHPiso/lYAch3tXs6Tt2/69q0ytkOPj3HHlz8iAMLLQaoYHJioQKd1OTyzDecMr+ftN/hNf52xH3p8Cr6+B2B8sDhVDA7MMfAwiQAI6+gztvXa73hUh23GfuDxF1rQWgBTHyVCisEiAIN26L+Qt6+XzRf98Pdxe4b9eYig+fpPVOHGuwUynz7/aJ3Cj0jC4hw4a2RZ14djXDdL/JqjUcByM2P79eq5XgiDjx9fERjvFijF4FSFSgSApwkta6fCTJ9Ndnvnfmu/hq7cd0+r7Xq93dzh1zyzxQQUAFufd9t69dRsXE7EfvDxo4g60HKAxgLJuwW2AvhyHdApgYIfgzgtE9TO4ADZoB2W5mueZt/syYzzMxH7wcePWtQiAPjHR4k4FoNThbAANFEQp9u53a+x9rtH/TVPzb/f6c98Xg5RGHz8ILAQONslfw48FoNToLT42llZ5+YD3vPbyeaFs8D95vZof7uircv7h33UDD/+SXsaKiJ5t8Djl8EFuKNKiRSgs0B8G/b1rt5OouGw36/j/ycIlPpbAUy9W2BbDE4VESzxA/BKACh2mPw5sC0GfysSUaGDYMK5FgDfGNp1O7e/HYM9hz5I26rUTEXhz4HcJ/w7
xB6dEqwA8sEQ+vaPwZ7aoklE4c+BXAyeSgZAWASAfYSyzrf77PIY7Kktul2JBJ+u/DmQ+oTfsACCdRY6sN/Rst73uzHYE9IuyQDeLZBfA5RFUaQCTwuYTpwF5M+wPKOw12c/0grARwvk1wBN7EEBmAeUs2A6Nzh2fRT2lYIiT4Ivpj5aIL8GKEgAfCMohA+BPvvxZhfa2lCGr/4YgK8ByoJIDdXHE4CCkz9Slv55GL0G6BNAMpeBStZlOUM1DntpT9UEnwRQQvxL/zyM+oSXRwXAlEwGyDs7H5Rx2PObP30TQJT+HPiXvXPHjRsGwnBSODBSpUyRi7gLAqTNUXydNDlFoAMQtAQimGqqPQAvknmtZzxYyUlHmPos7EPSFPz5i+SMd7VaBsCVLNDWzQzAgtlgkNNCf2Zc+J3jg8Rr3u8jAHW9cuaB8pnwXzwCmAO2VTvfKoP7ohrHnTNIvHW+EA2A59fDpAyATbFpIPDnUOjEjf2DxG+BlWkKPp55IJcBsCmyMNqiA8Li6fe2f+UZYa41BomXqW19kQAIuJ53jedfiwLsyLADTKZQFzBRtzA1RMEj+dgo8ZvWOZQWDIBnHvju/stXbBinAN6ODJBf7ws/Snw0wCbrnd7Z9A3PPJDLADICkCKNiWJlwTP5WN43Sjy1x2mMtLc3OG8TwmUANBqzBra3wpoN0Lua/swDuQwA0GnrrWFDXIMFfPF0zPW8fP4w8TsGwDMPlDIAdmRBmrLylg3g04JPEf4+EmOGidfSr7AiG733DkQ5bxNCZYACjI8ALta2JuGTuPl43jdMvOa4tIkBGOwI0AtOf5sQKgMUQEDsvg4wsdwAx7jQ+f0w8S2Ago0AZfpfD6MygI0ABHZsgfXN0CLBAFCmzwOpDHA1ACIg9NZvG8DWBpmjc8aJbzq90UM2wPR5IJUBCvBfBzGAiEQuYCPYWsBF9fdRbH+dngeKV7qs/gEQ+LEU2qbPA6kMUKX/bQSwCplcMUls
f1Ze7aCB4sXQZmwfAQrU6fNAKgPoCGB0qwoy7RWy2JmB4ntoFxiFqI+z54FUBqiFAEBgVKS8IPQ59H8YKF5GN+igRgB8NgDM/rnQu4daa6kFGAQXioii547Iz/k4M1B8fwZ6KVgQC3C7a538/4FUBqiFAUYfrwZwAZOoxu3O8f0jxYPVOtgAUBQxfp08D6QvBSyVKYp2Pj0QaHgnsIAtGUPLyP5s+4mR4qVNgjhAMwDu/2XyPJC+FJAM4Ox2hqVT+ApDxYPgBiAqs0yeB1IZ4IYB9Ap5cXUJUfR4LJ8DCLQNFQ+BIpgBJs8D6d4Ai/d/MoBgYkaywEY+PlQ8BEq1+Z9YJv9cKJUBFkYEoU2BArzFzCBlCS68HvO1g583VHxoV6naUDVAnTsP/PD554VVqCqKCmRi5SspiWsg7J03VLy3Sx3ALMRlmTsPvHtYhGqUACgHI8ExQ8UXcHPbaFcXYeo88P3Hb26A1P8msK8J0mvh4KocK/467OvVr+1dhKm/H0hlgKflcllkGiAbRJFkuMzi//u+Mli8tUuMIG2lP+bp+8x54P2nHzQLCnxVLCqQUF3YJHAWeacTBov/S96ZtEwNBGGYHnXc9wU33PeDBzdEUFTQTwQPInpSREQUXA56ExRRD4ILHhSXg7ihDIQQwUMgF2N+xJw9TX6Glapuq6dMWnPrnnkMk3yTFNhvVVe6K8sY5/Por498PzDO7wvtzDxCIyEQAqDBIGcAhEUWiH3yb8/s9cCPcz9mPlg9H+f3hU5adKHooxAmAzA/WlAnvGf21CgOABP4xcQ4vy908qbzhZUB+nRuRPh0wHAarWcozXpmj23C9g1ngKIY5/eFTt7yqihQCOKnhRC1tUM8s/9uB7em6EPro3F+X2h38/eoX4AKBEjEvQT7jBSft+01Ib73zJ6cr9vXp6zXL2ApDo3xPHDK4QJ7gRbkuwbFcohNuB3xwzd7Cm6iT1AAjPHvRqj5p6Oiog/wYJB6SUuk
U7yzN2MdGu1QAqiILozv7wfCUyE6AEgYxhEAPJhy4p09BwAsVeLTERDdGd/fD+zMPBhFBSwgBp0KUCAUymQCswZgJZ0gj+Ft7+w5yHGbBoAFtP76+M4DO9MvgP+HHc8B0NzbWNhmp3hn/52puj6d/zH+x/cB0Umzz1MG0PR5LFCp5oQFrt/nnX3fAtr6vcA4gNZHI/qA6L6HD/f983aQGxEgAoAQYrbGO/u+TUFEyMhdEFaXHt06NZECp25ddJcBJigADJQake+jRnMAjNaNwerSk1OpxalrynE7SIQY9zcFAI0N3NsS/+yxbdhGOvfDJ3FzhC4Iq0fv0mGys49U81MhEYJiwD8WqHCI7PiObTy0p7ZRG7HNJgJG58Zg9ehUKsnSsxdV4+0gkU1h4eiF/+UED+0L60yHAW8YlRuD0f2SDHj8TDU9FdIYAGY6CLCo/HdtL7PXHtoXFpHN2ZG4MVhdege9PYPl7wi432l6KiRFotScCfCjwimwoY9pFadUSIEVNjzGQ/u6AEiRq+HPA9W+J2dTHQC4Bmg7z/J8b1c13A6iZYiGA+BPFBS2qLwNH4gUHj6MjYf2hd0+u+EjcEFYXTtV43wAA+DV1hmq/naQO3YGGBIHxQPVXKLC0vidh/aijQA0HAn+grC6ezYDOAAs8jz90BQAS1+lRPR3ANRBAvNaYDvKR/s/7TONTDWBXxBW+25lzeT5sY1buqq+DhRxAAiKESSSpEQW9gVh9fBdloOjTdo3js8Gg2yQZdHHDevndRpuB4HDyYjSIXwQpqfwGuFtRh5HeGnPbeQAwIwZ9AVhde1xVsHz/jyngMD15TfL9y/qqobbQYxVxJBI/xQb4f3yGC/tTQDg2ibkC8Lq0UQOZARmAXJ+PqiW22837J89RTXdDpJRBmCMQAwLLr9z7fPS3jjfWusxU7gXhKddPKvdzwPAHKAAmNg1d936RVNU40tCdcwAQhymQVz3Pk/tiaEMkCHBXhBW5H/C
pH3D4OT71RvXzuyq5reDsP9lFhhF0hoyJNQLwuD/JE/EqD9L4Dvw/9ljc1esWTp1knK8JDSvAibVWD1jDAIgS02fgc9AnxBW1ybQg0iWcwaACEiuQPdfNX3GNOW4HeQ5KmAXjkY6AOpSAI2XwnxCWF2ayBPb+ZoqA6Tn5m5Ys3nqZOV8O8h1tDHjBxkAcmYgtp34aZ/a0JiJ9DuwMsB5oHp6qkr/A5jv04if5v1VACSXdy/bsWrRjI4zrqdszvLK3pAOIQV3O0R+56d9amGyHuoX4hPCavKtJBnkFhQElf9vv12+cPG8rjutqSmHc7Sv8b+7F/7bMZ7a23ClFAjxCeHO3ThOSuN4zgLg/3NL1u3cNF92f4maczov6wMg414lswHQ2ON47am9fblcF8oy0i+8QoB6OZFUJ3tEDwXAn2WZnD2+DCZ/YvJfXwciexQCA4AFkmIPrwmHgzy1twPATJtJv+AKAWrKO8vxJhDKpIwn3mxbuJgnf87HgsiehLBnA5lDSEYKbx3nqT00jtGDZ9LvUGiFgM69pJ6JNxvWLOD073wsaA+lD01m0cIRtfhqb1dMcyJBQrszXD14HCcxLNjrYWH/r9gpav/NdaADaJ9r7GqiTpOcMgVyn/zeV/uhBFCW1RiI9AvsznA1+S46XxKffbNi/XThf0cdSGYAqiXIABBCusVHUl/t7SAv7QwQ2J3h6sEEOTyJEdjA7eTjivWzxOzPVQdC+5IySEl1BCRnIW0REekIQgjvqz21kdCD5hL1C+vOcNW9y463ObdB+N9dB/pjnyecAbCgJIQTIv9beF/tMQCoeDYoh06dm4IKgDmPK99xz9ecrLn3w1UHIvu8RAYI1RMyB25nEN7aW20cJHoMQPqFVAhQk1/EvVjD6T8++2Xhgimqxeth0N70AlNIkgFgCiau7yTe2udcLxmYATTpF1IhQM2/2eP0zxng3MbF81Wb18MM2Q/KASxlWa2leLzNa+sYxN7nrb3V
xnwwpF9IhYDOzIn4b5LLK1ZN7bR6PYy2JBHyEjMACiRErxWakMLTtr/25Hz4AEwGRQIqBKjui7iOj9sXTVatfi1oSAGcCSQkEAsshZbb9cf5a08Dv0FSBYE+fRIBFQLUnJs9PQToxbClt6/vWNzithasA6G9GUdQryCkiDQ2aN6Wx/trz21MSsp8Wr8D4RQCOjOv244326/3t2vC5AV3YoRnE1xZxJtKpHhuh9g2/tqT4+EDMO2u9AuoEKC6e3va8QAHwtc2CYDqQGSvQUlKWMNWLpCimr8HCYkrj/HXHp3PvZ8J544ANf9Ij+AAgI+T21uGcHdzgvailoABYISED4C3BWIf/+2vfc3gWXemYAoBnZUHjNNtXq+do1q+JpgMZT0BkKJKoQPeL9qK9JBgCgGTZt+oywCftnRVu0RypiczgCFpQZ3YHts3Z4BgHg3obkl6NXye1Wn7mmDOAIJkhIklJgMEUwiYcvRbr+JX7xcsPc319W3msfRcmLaPh+MA/rarjLgtkPvk9z7bxxZDp9JQHg1Q8w9hAAjOr8U5QKs60NhnAPA9Z4BQHg1Q83gSgFkAgNWJxd3WPxeF9j2NXVSyeo+jR3EdXR7nsz21kSMAIBnuBPJoQGcWOQ5h/11YMLn1z0WxvTgFCOFqRQUaU7DP9pz2BaG8I6Az+wI57lvvGywmGC60/e9P3nKD7CXk/1hjCy6/a9zns709czIdgDpTIC8LnLTgBDn/17c/WQCW1gHQ3XwWzcV00g6Apt5WK7C99tmeUz/BA+pAfkV80pbz3wDuvbABHFg0qe3Phn/jxgM9hoVzYJ9XBV7bcyt5AECCBvKywN/snVlrE1EUx50sLtW4x6Vpo1aj1lbRujyIClI3BHEpWFBERGwV3LBIVRRRfBDtgy+KC7jghgPzEELe8gHmPSDkafCbeO6dM57M4WbMuOZEf46d29s52vmf/5x7czNJUotufYGLv8i4lUnG/dhwP1BVEEbcZHBa
O/5THVhBfSGEvFlgatWjooE4Uxh8YaAfiBUgZIC2hrmdKoCQNwtMrbpo20W7SOg2TGHiLgQWQ0NJlAFwbhDdJlo73l9Ao+T7YyhwRcabBaayj1TOyQTY3jM57ueF2UH+/WEAhVEbmxhywc19tG/teDpXmkMp7JMy3iwwlT0QJB6xtQkOpmN+XtgWMA46AAXReyBaUAT7Tce2djxbRNPnX1RaXJwvYiEglT1lIyEDXIERLN4NYXbYAAg0STR2JRkwidza8V+IkAFsIZ8akFr0lM8BNA+7psa8IYz+BT/xVAHaGv9c2QRQD6MybglJzn1vI+F5wN1kvBvCHlJ8sLAEm9p/amtwAQ3P9UugHyDjlpBE5q2NBBNAnxdpK44BsiM0itQJ0v4VAOa8AJmAyqiMW0IS89+FK0DggKGZVqyFwCCewCoQephEbSL6Z19aPV4bnVUAjYxbQhIzjAYA7ibiLAQeJQOQIJq4FYCL3+rxzPA0Bsi4JWRq17ELtpGx6DGAf2BcnY3CMDHZY2bY+P0I7LhWj2fnSzrIWAmypuQP2BW7ApsdZuTx1OZtNHubH18EGEw4ghKAk0ZzCW71+G9zJ2YCKStBHb3vdfJhIyqKsZQVYyHQd5AWI0SRBIaNBAd4H+6Zf1o9HpNv0x4VFLISNHnRG1UBAJvQFaF41YqxEOj/AwYxDGJiG6kX3ZCMVo/XQz6bR9lK0r0yVoKSmXnFCmAoAUMpK8ZCoIonIQgmnJGoY1o9nk+gSUAZK0GJ6dsfVXxwLkAOmEg0vxDI4olim2MzSD8Z9wRZM/NPAwMg/pDgVSrj561mF5QfUrzZADgsxKfl422C9PPgj4x7gqx09k3Vq1Yr1Yrt2R5sVMSqr85YzS4E6vjICsDFjGwTAuIbVAAp9wStLIxWPE+ZAH55NIG/r3hDW63mFgIhXiffmH8UCXYmwaP7Wj8+hD8MeroEHJRxT1Cia/vTahXy7ylU6UJ039A9q6k7Av14HEgI
LpZJYKPIuJcQzx3gA5LKWAmC7C17A1e/U3UcTD7stBF0UofOWM3cEQjxaB6b4IJykQl+vLx4nACjAXRFlfI2Mam5hdGqxquEq4AyhffqdDMfFQDRaB4tBIlCgkUKCpiFlxAfLgC+fiCImFeHdR176miqoQoAezAAXNoT1vdfGuw4gXHoavD3MeHCSoj3F9LQ+Kgf6PZQyKvDrI7ej+Mq0bBRBUAT6KFh6DtFIDFjN4TiPAKFQBP8E8CJEqgf6DYyV8RKEIwBmUNPVaJhwyQieCLA2Bkr+qXB2jzKBKTEv2KAcNWsoH4OcFzEShBU8CnLPww6DhkAr2Yfv7/CLMBXgh0PIAOQKHbbQ8nXoH7qwpGxFKjWglYXFvpDgKPxHA82taeTcaov729t/FkR347zCC0KmyWH9rxKUB8dJyA+ZHgv0A+QsRSoS0B+xaiDUOJh840Q8Grs9NYG7xEYGIeuBoQE48JSO0p4AfHqnGnuhPqpC0rIUqB6s8iVt5/hHAC+EFQNAsZfTpzfalgJhgN1vC8GQQIj9D0R8TMJ8Z4PPXIKELIUqFdyluUeOCHQDCbGh8Ym7qMNcCXYQcLlX30xECcZEuI9Dl4MVRl3BSqs5IztnaNOPF4NjY1NTEzcv3/69M7AMCQAVg71JFNsIAg2vZcQ7ylo4uz4lB3nSpeItWB/Hrio8GykDMAv3hD4IWzUNh0PWa8nJCJvA+bvCQnxaPrg/IkdMu4KxHngstwmp4xJjkg+MwE7loSgChASK0pQ07ES4lnVowpwS8ZdgRorNeNY53BwVUdSJphhWPIVBjFprQHAtv8zr4JtEl1CPDtn0knKWjAOAnPnrTnLElsOpZ1VAGpHYxaci0vw41o43ph40uuVlLVgjTUnW3h+vayhZDsE9rF9bJjARqKO+YvxTjRMK/i7WpIBJiWmLOt5fa0MuGXXZUbAfbiPm+VnqTpVE/g8Be1ZP7Z/Ubzzs6A2LmxSngzwsZJdeXCAC8lX
6TckHDt4339Y7Q/+unekrAX7WKnpy3OvR/0KAJQDeNLN/HeCBjVyFWKeDECsyTOW556fdb9RjoUTA1P1aI94FMNVrO2YJAtr8jRwwA235CI4H0AnYJugPrU3DAuRjxr4+kJbxH/TQ7FTxFsEsBqQ75m10HE1JbekrcANwE2BxzgMvlrIxeLHtEV8GdH6HRTzZED9PGDZwILNgyUEPEBJpuQb+wzzA9Ojh4Z97RDvBpQUcp4NIqzk7N5Da/QwABuaQBNOvKnPJFycPvnxlH+t3+4ueQaYZCVmrl6a6z8CRYBwm6T8j0MG0FyZLtAA8MRQen5+YPHzJ9VSCJoXwBeC9ZUNNDmR1EiOr1MEDTBDzPPBbCIwO7su13/uRolRl2hsc0Ngk88TGglJexJTbHygC7FjmkwDwDDQMT9f6OzbdbhE8EoQeILa9D0JxQU19/M5hbz4+vMnA8wXagBVBKas3jiwpu/mMA4EtVINNp5o1ma4EZgeSXCkxDc6/5pgA0yypqa7Vh0bWNN/aeFoiYFmiIfbRpSaZEdGzi1BpnEgPX3VxkLnrO5dTwZrgE46JR/b8TFPLFmb9wG8H/jd8T8C6STcANoCs1fnb/cs6e/edeJ62AC4/2OwxLJEGpNsTuxvJqSRdAMoC0yeMr93YyEHHrh05MFZt74SMEr/KZXC2pwSbwCwgJXsmL2yd+Ohns7F/d2Xd216cBjGA4IM8d8EJa7JljYwgJ4PpjpmZ7L5pYd6VixZ0N+94fK5zfsXPhi+cfb6tcHBwZGRkf+1ALPPeCt1HcDggWR65vTMqmXLlx4ayHWuWbxgVn9fX3f3BmD9+vWbr9VMlBhxH0kIia814vp2mUvBZiwrkZzcMWVGZnV2WX7j0nmHCgM9PTlgxYrOBX37D49//lz7XIPtM0Lf+3vA/EiCTy4R3t868XhOGjo/dv7Xho+syAt8NvD7LkilO2bOnj4tM3f1olVZRW9+Xc/ivsu79g1fH69xcYBo
sWqEKTlAdLJ+X3wzvz9Bhh88O7xv86Xu/s55c4XdEta8DaYmkslUajKQBmZO6106sGLJrL7uDZc2bzoxfHh0nIsSl8bxtThQUn/B/x/NV3bsXTdtMAzjuAiHcHQ4GcwhmGMAJ7IA2yMTDIgJWJCQWBM84Q2IkNizeeFGehO5gki9mz7vR5qqHchQtVWT93cBXv6PxPfyPNhNj0vTsp3u9V1GzVcntZb0UZ4A7/B4E9FWxUg1qnVNzdAOOo49nJl4KE5X28GXl49pM3hYTefH5WhsDW23072+vbvK5LR8odfQjYoci/uDH+0X4Nz/BeF4KNls43VwaPQK9bym0kNRvBM77no/tMZmdonLYUqnw/3Lf+b5frDdraaP8+PTcmTOrOHeXjtIfn2L6Kiuavl6odqbpMpGqSIrsWg84fd+nvwCfhZ8Ab8Uj6aTitzGO7GvH+ihWBBrwBywB7ocxCQ6jru2sQprNjZH2eXy6TjHNqar1e5hu8VluXn5e75uNveDwfZhh8LTx8c5RV5mR6Y5nlmitOvg0OmiNuUWvXMqilPyaq8xOejlRa1UactKMhaKxKWw3+e9+GTxf34d+DCEsHQZiabpoSjTGmrGoqynaBA4HcThkNc0FbOgXVxhGZgGxkHosCSO47rrtW3v9/shWBgLjMEkI8ieMyImGQszYgE+hm/atr1eu66DuNBFX+EW7lAZmdEZoVVNy6N1vSBqNybUu78wUBzJm0orGUuj+iWyBwI+L5X/pOl/4cG98PpQ9NMa4sVINJSO3ZxOh3a7UimVaphFv0zDOEwmjQaNA+iwhLyggSrkXmXeXL0r80PujSpoJC/UoYC+0OuhMUU+pHS9LELXSpS6LcuidjKG3lEEp+J+ak7RUZ2zn+OBIPZAg/CdLodwOCFd0iywi1A6HcM0kq2WojSbMrShAiWoEcMwFotFv4+9CDpJnacL5Vd9gm/gSzVSggppgwzNpqIoLTS+QeR0CJkjxTiVToRF
a/AhN3qL4Jz893iEYPACvMRHAoL/JIyRJCTMhMShiLkIUSH0ruhJ5LtiEUnRlEiSlEBatBUCgk/wkgsSDHo49T/l+UO4K2OMMcYYY4wxxhhjjDHGGGOMMcYYY4wxxhhj7Bt7cCAAAAAAAOT/2giqqqqqqqqqqqqqqqqqqkp7cEACAAAAIOj/636ECgAAAAAAAAAAAAAAAAAAAAAAfATy0Qx6GNPiEwAAAABJRU5ErkJggg==
EOF_OPENCLASH_LOGO_B64
    return 0
}
install_openclash_embedded_icon() {
    ensure_app_icon_dir
    backup_file "$APP_ICON_DIR/$OPENCLASH_ICON_NAME"
    cat > "$APP_ICON_DIR/$OPENCLASH_ICON_NAME" <<EOF_OPENCLASH_ICON
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1024 1024" role="img" aria-label="$OPENCLASH_DISPLAY_NAME">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#eef8ff"/><stop offset="100%" stop-color="#cbeaff"/></linearGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="26" stdDeviation="22" flood-color="#8db7dd" flood-opacity="0.28"/></filter>
  </defs>
  <rect x="84" y="84" width="856" height="856" rx="188" fill="url(#bg)" stroke="#9fd7ff" stroke-width="18" filter="url(#shadow)"/>
  <rect x="162" y="162" width="700" height="700" rx="154" fill="#f8fcff" stroke="#d8eefc" stroke-width="12"/>
  <rect x="222" y="222" width="580" height="580" rx="132" fill="#ffffff" opacity="0.92"/>
  <image x="252" y="252" width="520" height="520" preserveAspectRatio="xMidYMid meet" href="data:image/png;base64,$(get_openclash_official_logo_base64)" xlink:href="data:image/png;base64,$(get_openclash_official_logo_base64)"/>
  <circle cx="512" cy="292" r="54" fill="#ffffff" fill-opacity="0.24"/>
</svg>
EOF_OPENCLASH_ICON
    chmod 644 "$APP_ICON_DIR/$OPENCLASH_ICON_NAME" 2>/dev/null || true
    log "图标:   内置 $OPENCLASH_DISPLAY_NAME SVG 卡片"
    return 0
}

install_adguardhome_embedded_icon() {
    ensure_app_icon_dir
    backup_file "$APP_ICON_DIR/$ADGUARDHOME_ICON_NAME"
    cat > "$APP_ICON_DIR/$ADGUARDHOME_ICON_NAME" <<'EOF_ADG_ICON'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="AdGuardHome"><defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#eef8ff"/><stop offset="100%" stop-color="#cbeaff"/></linearGradient><linearGradient id="shield" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#2f548f"/><stop offset="100%" stop-color="#3f73ba"/></linearGradient><filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="26" stdDeviation="22" flood-color="#8db7dd" flood-opacity="0.28"/></filter></defs><rect x="84" y="84" width="856" height="856" rx="188" fill="url(#bg)" stroke="#9fd7ff" stroke-width="18" filter="url(#shadow)"/><rect x="162" y="162" width="700" height="700" rx="154" fill="#f8fcff" stroke="#d8eefc" stroke-width="12"/><g transform="translate(262 224)"><path d="M250 20C338 86 425 100 492 108V306C492 440 395 544 250 600C105 544 8 440 8 306V108C75 100 162 86 250 20Z" fill="url(#shield)"/><path d="M250 78C314 124 378 136 428 142V291C428 393 356 474 250 521C144 474 72 393 72 291V142C122 136 186 124 250 78Z" fill="#eaf8ff" opacity="0.18"/><path d="M165 310L232 377L353 236" fill="none" stroke="#edf9ff" stroke-width="48" stroke-linecap="round" stroke-linejoin="round"/><rect x="137" y="428" width="226" height="28" rx="14" fill="#9fd7ff" opacity="0.52"/></g></svg>
EOF_ADG_ICON
    chmod 644 "$APP_ICON_DIR/$ADGUARDHOME_ICON_NAME" 2>/dev/null || true
    log "图标:   内置 AdGuardHome SVG 卡片"
    return 0
}

install_webssh_embedded_icon() {
    ensure_app_icon_dir
    backup_file "$APP_ICON_DIR/$WEBSSH_ICON_NAME"
    cat > "$APP_ICON_DIR/$WEBSSH_ICON_NAME" <<'EOF_WEBSSH_ICON'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="ttyd Web SSH"><defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#eef8ff"/><stop offset="100%" stop-color="#cbeaff"/></linearGradient><linearGradient id="screen" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#2f548f"/><stop offset="100%" stop-color="#3f73ba"/></linearGradient><filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="26" stdDeviation="22" flood-color="#8db7dd" flood-opacity="0.28"/></filter></defs><rect x="84" y="84" width="856" height="856" rx="188" fill="url(#bg)" stroke="#9fd7ff" stroke-width="18" filter="url(#shadow)"/><rect x="162" y="162" width="700" height="700" rx="154" fill="#f8fcff" stroke="#d8eefc" stroke-width="12"/><g transform="translate(260 252)"><rect x="0" y="0" width="504" height="520" rx="104" fill="url(#screen)"/><rect x="32" y="44" width="440" height="56" rx="28" fill="#8ec8ff" opacity="0.28"/><circle cx="78" cy="72" r="10" fill="#dff4ff"/><circle cx="112" cy="72" r="10" fill="#dff4ff" opacity="0.84"/><circle cx="146" cy="72" r="10" fill="#dff4ff" opacity="0.68"/><path d="M125 214 L228 296 L125 378" fill="none" stroke="#edf9ff" stroke-width="42" stroke-linecap="round" stroke-linejoin="round"/><rect x="270" y="347" width="136" height="42" rx="21" fill="#edf9ff"/><rect x="126" y="438" width="252" height="28" rx="14" fill="#9fd7ff" opacity="0.52"/></g></svg>
EOF_WEBSSH_ICON
    chmod 644 "$APP_ICON_DIR/$WEBSSH_ICON_NAME" 2>/dev/null || true
    log "图标:   内置 ttyd Web SSH SVG 卡片"
    return 0
}

install_openvpn_embedded_icon() {
    ensure_app_icon_dir
    backup_file "$APP_ICON_DIR/$OPENVPN_ICON_NAME"
    cat > "$APP_ICON_DIR/$OPENVPN_ICON_NAME" <<'EOF_OPENVPN_ICON'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="OpenVPN"><defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#eef8ff"/><stop offset="100%" stop-color="#cbeaff"/></linearGradient><linearGradient id="core" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#f6a44c"/><stop offset="100%" stop-color="#d96a14"/></linearGradient><filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="26" stdDeviation="22" flood-color="#8db7dd" flood-opacity="0.28"/></filter></defs><rect x="84" y="84" width="856" height="856" rx="188" fill="url(#bg)" stroke="#9fd7ff" stroke-width="18" filter="url(#shadow)"/><rect x="162" y="162" width="700" height="700" rx="154" fill="#f8fcff" stroke="#d8eefc" stroke-width="12"/><g transform="translate(220 202)"><circle cx="292" cy="192" r="110" fill="url(#core)"/><path d="M292 250c-44 0-80 36-80 80v126h160V330c0-44-36-80-80-80Zm0-104c-53 0-96 43-96 96v34h52v-34c0-24 20-44 44-44s44 20 44 44v34h52v-34c0-53-43-96-96-96Z" fill="#fff5ec"/><circle cx="292" cy="372" r="26" fill="#d96a14"/><rect x="266" y="390" width="52" height="78" rx="26" fill="#d96a14"/><path d="M92 476c88-48 140-62 200-62s112 14 200 62" fill="none" stroke="#9fd7ff" stroke-width="28" stroke-linecap="round"/><path d="M132 540c72-34 116-44 160-44s88 10 160 44" fill="none" stroke="#dbefff" stroke-width="20" stroke-linecap="round"/></g></svg>
EOF_OPENVPN_ICON
    chmod 644 "$APP_ICON_DIR/$OPENVPN_ICON_NAME" 2>/dev/null || true
    log "图标:   内置 OpenVPN SVG 卡片"
    return 0
}

install_zerotier_embedded_icon() {
    ensure_app_icon_dir
    backup_file "$APP_ICON_DIR/$ZEROTIER_ICON_NAME"
    cat > "$APP_ICON_DIR/$ZEROTIER_ICON_NAME" <<'EOF_ZEROTIER_ICON'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="ZeroTier"><defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#eef8ff"/><stop offset="100%" stop-color="#cbeaff"/></linearGradient><linearGradient id="node" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#243241"/><stop offset="100%" stop-color="#0f766e"/></linearGradient><filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="26" stdDeviation="22" flood-color="#8db7dd" flood-opacity="0.28"/></filter></defs><rect x="84" y="84" width="856" height="856" rx="188" fill="url(#bg)" stroke="#9fd7ff" stroke-width="18" filter="url(#shadow)"/><rect x="162" y="162" width="700" height="700" rx="154" fill="#f8fcff" stroke="#d8eefc" stroke-width="12"/><g fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M350 344L512 250L674 344V532L512 626L350 532Z" stroke="#8ec8ff" stroke-width="34"/><path d="M350 344L512 438L674 344M512 438V626" stroke="#2f548f" stroke-width="36"/></g><g fill="url(#node)"><circle cx="512" cy="250" r="72"/><circle cx="350" cy="344" r="72"/><circle cx="674" cy="344" r="72"/><circle cx="350" cy="532" r="72"/><circle cx="674" cy="532" r="72"/><circle cx="512" cy="626" r="72"/></g><g fill="#eaf8ff" opacity="0.78"><circle cx="512" cy="250" r="22"/><circle cx="350" cy="344" r="22"/><circle cx="674" cy="344" r="22"/><circle cx="350" cy="532" r="22"/><circle cx="674" cy="532" r="22"/><circle cx="512" cy="626" r="22"/></g></svg>
EOF_ZEROTIER_ICON
    chmod 644 "$APP_ICON_DIR/$ZEROTIER_ICON_NAME" 2>/dev/null || true
    log "图标:   内置 ZeroTier SVG 卡片"
    return 0
}

install_easytier_embedded_icon() {
    ensure_app_icon_dir
    backup_file "$APP_ICON_DIR/$EASYTIER_ICON_NAME"
    cat > "$APP_ICON_DIR/$EASYTIER_ICON_NAME" <<'EOF_EASYTIER_ICON'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="EasyTier"><defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#eef8ff"/><stop offset="100%" stop-color="#cbeaff"/></linearGradient><linearGradient id="core" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#60a5fa"/><stop offset="100%" stop-color="#2563eb"/></linearGradient><filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="26" stdDeviation="22" flood-color="#8db7dd" flood-opacity="0.28"/></filter></defs><rect x="84" y="84" width="856" height="856" rx="188" fill="url(#bg)" stroke="#9fd7ff" stroke-width="18" filter="url(#shadow)"/><rect x="162" y="162" width="700" height="700" rx="154" fill="#f8fcff" stroke="#d8eefc" stroke-width="12"/><g transform="translate(210 238)" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M142 316C142 200 236 106 352 106H470" stroke="#9fd7ff" stroke-width="48"/><path d="M462 52L548 106L462 160" stroke="#2f548f" stroke-width="48"/><path d="M462 212C462 328 368 422 252 422H134" stroke="#2f548f" stroke-width="48"/><path d="M142 476L56 422L142 368" stroke="#9fd7ff" stroke-width="48"/></g><circle cx="512" cy="512" r="116" fill="url(#core)"/><path d="M452 512h120M512 452v120" stroke="#eef8ff" stroke-width="42" stroke-linecap="round"/></svg>
EOF_EASYTIER_ICON
    chmod 644 "$APP_ICON_DIR/$EASYTIER_ICON_NAME" 2>/dev/null || true
    log "图标:   内置 EasyTier SVG 卡片"
    return 0
}

install_fanctrl_embedded_icon() {
    install_embedded_text_icon "$FANCTRL_ICON_NAME" "FanControl Plus" "FP" "#ef4444" "#b91c1c"
}

extract_easytier_release_bundle() {
    archive_path="$1"
    dest_dir="$2"

    [ -s "$archive_path" ] || die "$EASYTIER_DISPLAY_NAME 官方发布包缺失：$archive_path"
    ensure_packages unzip

    rm -rf "$dest_dir"
    mkdir -p "$dest_dir"

    if command -v unzip >/dev/null 2>&1; then
        unzip -tq "$archive_path" >/tmp/easytier-archive-validate.log 2>&1 || {
            sed -n '1,120p' /tmp/easytier-archive-validate.log >&2
            die "$EASYTIER_DISPLAY_NAME 官方发布包校验失败"
        }
        unzip -oq "$archive_path" -d "$dest_dir" >/tmp/easytier-unpack.log 2>&1 || {
            sed -n '1,120p' /tmp/easytier-unpack.log >&2
            die "解压 $EASYTIER_DISPLAY_NAME 官方发布包失败"
        }
        return 0
    fi

    if busybox unzip -oq "$archive_path" -d "$dest_dir" >/tmp/easytier-unpack.log 2>&1; then
        return 0
    fi

    sed -n '1,120p' /tmp/easytier-unpack.log >&2
    die "系统缺少 unzip，无法解压 $EASYTIER_DISPLAY_NAME 官方发布包"
}

ensure_easytier_config_defaults() {
    if [ ! -f /etc/config/easytier ]; then
        cat > /etc/config/easytier <<'EOF_EASYTIER_UCI'
config easytier
	option enabled '0'
	option easytierbin '/usr/bin/easytier-core'

config easytierweb
	option enabled '0'
EOF_EASYTIER_UCI
    fi

    uci -q get easytier.@easytier[0] >/dev/null 2>&1 || uci -q add easytier easytier >/dev/null 2>&1 || true
    uci -q get easytier.@easytierweb[0] >/dev/null 2>&1 || uci -q add easytier easytierweb >/dev/null 2>&1 || true
    [ -n "$(uci -q get easytier.@easytier[0].enabled 2>/dev/null || true)" ] || uci -q set easytier.@easytier[0].enabled='0'
    [ -n "$(uci -q get easytier.@easytier[0].easytierbin 2>/dev/null || true)" ] || uci -q set easytier.@easytier[0].easytierbin='/usr/bin/easytier-core'
    [ -n "$(uci -q get easytier.@easytierweb[0].enabled 2>/dev/null || true)" ] || uci -q set easytier.@easytierweb[0].enabled='0'
    uci -q commit easytier >/dev/null 2>&1 || true
}

write_easytier_controller_file() {
    mkdir -p "$(dirname "$EASYTIER_CONTROLLER")"
    backup_file "$EASYTIER_CONTROLLER"

    cat > "$EASYTIER_CONTROLLER" <<'EOF_EASYTIER_CONTROLLER'
module("luci.controller.easytier", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/easytier") then
		return
	end

	entry({"admin", "vpn"}, firstchild(), _("VPN"), 45).dependent = false
	entry({"admin", "vpn", "easytier"}, alias("admin", "vpn", "easytier", "easytier"), _("EasyTier"), 46).dependent = true
	entry({"admin", "vpn", "easytier", "easytier"}, cbi("easytier"), _("EasyTier"), 47).leaf = true
	entry({"admin", "vpn", "easytier", "easytier_log"}, form("easytier_log"), _("core log"), 48).leaf = true
	entry({"admin", "vpn", "easytier", "get_log"}, call("get_log")).leaf = true
	entry({"admin", "vpn", "easytier", "clear_log"}, call("clear_log")).leaf = true
	entry({"admin", "vpn", "easytier", "easytierweb_log"}, form("easytierweb_log"), _("web log"), 49).leaf = true
	entry({"admin", "vpn", "easytier", "get_wlog"}, call("get_wlog")).leaf = true
	entry({"admin", "vpn", "easytier", "clear_wlog"}, call("clear_wlog")).leaf = true
	entry({"admin", "vpn", "easytier", "status"}, call("act_status")).leaf = true
end

function act_status()
	local e = {}
	local sys = require "luci.sys"
	local uci = require "luci.model.uci".cursor()
	local port = tonumber(uci:get_first("easytier", "easytierweb", "html_port"))
	e.crunning = luci.sys.call("pgrep easytier-core >/dev/null") == 0
	e.wrunning = luci.sys.call("pgrep easytier-web >/dev/null") == 0
	e.port = (port or 0)

	local tagfile = io.open("/tmp/easytier_time", "r")
	if tagfile then
		local tagcontent = tagfile:read("*all")
		tagfile:close()
		if tagcontent and tagcontent ~= "" then
			os.execute("start_time=$(cat /tmp/easytier_time) && time=$(($(date +%s)-start_time)) && day=$((time/86400)) && [ $day -eq 0 ] && day='' || day=${day}天 && time=$(date -u -d @${time} +'%H小时%M分%S秒') && echo $day $time > /tmp/command_easytier 2>&1")
			local command_output_file = io.open("/tmp/command_easytier", "r")
			if command_output_file then
				e.etsta = command_output_file:read("*all")
				command_output_file:close()
			end
		end
	end

	local command2 = io.popen('test ! -z "`pidof easytier-core`" && (top -b -n1 | grep -E "$(pidof easytier-core)" 2>/dev/null | grep -v grep | awk \'{for (i=1;i<=NF;i++) {if ($i ~ /easytier-core/) break; else cpu=i}} END {print $cpu}\')')
	e.etcpu = command2:read("*all")
	command2:close()

	local command3 = io.popen("test ! -z `pidof easytier-core` && (cat /proc/$(pidof easytier-core | awk '{print $NF}')/status | grep -w VmRSS | awk '{printf \"%.2f MB\", $2/1024}')")
	e.etram = command3:read("*all")
	command3:close()

	local wtagfile = io.open("/tmp/easytierweb_time", "r")
	if wtagfile then
		local wtagcontent = wtagfile:read("*all")
		wtagfile:close()
		if wtagcontent and wtagcontent ~= "" then
			os.execute("start_time=$(cat /tmp/easytierweb_time) && time=$(($(date +%s)-start_time)) && day=$((time/86400)) && [ $day -eq 0 ] && day='' || day=${day}天 && time=$(date -u -d @${time} +'%H小时%M分%S秒') && echo $day $time > /tmp/command_easytierweb 2>&1")
			local wcommand_output_file = io.open("/tmp/command_easytierweb", "r")
			if wcommand_output_file then
				e.etwebsta = wcommand_output_file:read("*all")
				wcommand_output_file:close()
			end
		end
	end

	local command4 = io.popen('test ! -z "`pidof easytier-web`" && (top -b -n1 | grep -E "$(pidof easytier-web)" 2>/dev/null | grep -v grep | awk \'{for (i=1;i<=NF;i++) {if ($i ~ /easytier-web/) break; else cpu=i}} END {print $cpu}\')')
	e.etwebcpu = command4:read("*all")
	command4:close()

	local command5 = io.popen("test ! -z `pidof easytier-web` && (cat /proc/$(pidof easytier-web | awk '{print $NF}')/status | grep -w VmRSS | awk '{printf \"%.2f MB\", $2/1024}')")
	e.etwebram = command5:read("*all")
	command5:close()

	local command8 = io.popen("([ -s /tmp/easytiernew.tag ] && cat /tmp/easytiernew.tag ) || ( curl -L -k -s --connect-timeout 3 --user-agent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36' https://api.github.com/repos/EasyTier/EasyTier/releases/latest | grep tag_name | sed 's/[^0-9.]*//g' >/tmp/easytiernew.tag && cat /tmp/easytiernew.tag )")
	e.etnewtag = command8:read("*all")
	command8:close()

	local command9 = io.popen("([ -s /tmp/easytier.tag ] && cat /tmp/easytier.tag ) || ( echo `$(uci -q get easytier.@easytier[0].easytierbin) -V | sed 's/^[^0-9]*//'` > /tmp/easytier.tag && cat /tmp/easytier.tag && [ ! -s /tmp/easytier.tag ] && echo '?' >> /tmp/easytier.tag && cat /tmp/easytier.tag )")
	e.ettag = command9:read("*all")
	command9:close()

	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function get_log()
	local log = ""
	local files = {"/tmp/easytier.log"}

	for _, file in ipairs(files) do
		if luci.sys.call("[ -f '" .. file .. "' ]") == 0 then
			log = log .. luci.sys.exec("sed 's/\\x1b\\[[0-9;]*m//g' " .. file)
		end
	end

	luci.http.write(log)
end

function clear_log()
	luci.sys.call("echo '' >/tmp/easytier.log")
end

function get_wlog()
	local log = ""
	local files = {"/tmp/easytierweb.log"}

	for _, file in ipairs(files) do
		if luci.sys.call("[ -f '" .. file .. "' ]") == 0 then
			log = log .. luci.sys.exec("sed 's/\\x1b\\[[0-9;]*m//g' " .. file)
		end
	end

	luci.http.write(log)
end

function clear_wlog()
	luci.sys.call("echo '' >/tmp/easytierweb.log")
end
EOF_EASYTIER_CONTROLLER

    chmod 644 "$EASYTIER_CONTROLLER" 2>/dev/null || true
}

install_openlist_embedded_icon() {
    ensure_app_icon_dir
    backup_file "$APP_ICON_DIR/$OPENLIST_ICON_NAME"
    cat > "$APP_ICON_DIR/$OPENLIST_ICON_NAME" <<'EOF_OPENLIST_ICON'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="OpenList"><defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#eef8ff"/><stop offset="100%" stop-color="#cbeaff"/></linearGradient><linearGradient id="folder" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#38bdf8"/><stop offset="100%" stop-color="#14b8a6"/></linearGradient><filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="26" stdDeviation="22" flood-color="#8db7dd" flood-opacity="0.28"/></filter></defs><rect x="84" y="84" width="856" height="856" rx="188" fill="url(#bg)" stroke="#9fd7ff" stroke-width="18" filter="url(#shadow)"/><rect x="162" y="162" width="700" height="700" rx="154" fill="#f8fcff" stroke="#d8eefc" stroke-width="12"/><g transform="translate(236 294)"><path d="M0 108c0-42 34-76 76-76h126c27 0 52 14 66 37l34 55h174c42 0 76 34 76 76v248c0 42-34 76-76 76H76c-42 0-76-34-76-76V108Z" fill="url(#folder)"/><path d="M42 218h468" stroke="#eef8ff" stroke-width="34" stroke-linecap="round" opacity="0.62"/><path d="M128 314h302M128 398h224" stroke="#eef8ff" stroke-width="42" stroke-linecap="round"/></g></svg>
EOF_OPENLIST_ICON
    chmod 644 "$APP_ICON_DIR/$OPENLIST_ICON_NAME" 2>/dev/null || true
    log "图标:   内置 OpenList SVG 卡片"
    return 0
}

install_unified_appcenter_icons() {
    install_webssh_embedded_icon || return 1
    install_openclash_embedded_icon || return 1
    install_adguardhome_embedded_icon || return 1
    install_openvpn_embedded_icon || return 1
    install_openlist_embedded_icon || return 1
    install_zerotier_embedded_icon || return 1
    install_easytier_embedded_icon || return 1
    return 0
}

set_appcenter_entry() {
    plugin_name="$1"
    pkg_name="$2"
    version="$3"
    size="$4"
    controller="$5"
    route="$6"
    icon_name="${7:-}"

    cleanup_appcenter_route_entries "$route"

    pkg_sec="$(find_uci_section package "$plugin_name")"
    if [ -z "$pkg_sec" ]; then
        pkg_sec="$(uci add appcenter package)"
    fi

    list_sec="$(find_uci_section package_list "$plugin_name")"
    if [ -z "$list_sec" ]; then
        list_sec="$(uci add appcenter package_list)"
    fi

    uci set "appcenter.$pkg_sec.name=$plugin_name"
    uci set "appcenter.$pkg_sec.version=$version"
    uci set "appcenter.$pkg_sec.size=$size"
    uci set "appcenter.$pkg_sec.status=1"
    uci set "appcenter.$pkg_sec.has_luci=1"
    uci set "appcenter.$pkg_sec.open=0"
    if [ -n "$icon_name" ]; then
        uci set "appcenter.$pkg_sec.icon=$icon_name"
    else
        uci -q delete "appcenter.$pkg_sec.icon" >/dev/null 2>&1 || true
    fi

    uci set "appcenter.$list_sec.name=$plugin_name"
    uci set "appcenter.$list_sec.pkg_name=$pkg_name"
    uci set "appcenter.$list_sec.parent=$plugin_name"
    uci set "appcenter.$list_sec.size=$size"
    uci set "appcenter.$list_sec.luci_module_file=$controller"
    uci set "appcenter.$list_sec.luci_module_route=$route"
    uci set "appcenter.$list_sec.version=$version"
    uci set "appcenter.$list_sec.has_luci=1"
    uci set "appcenter.$list_sec.type=1"
    if [ -n "$icon_name" ]; then
        uci set "appcenter.$list_sec.icon=$icon_name"
    else
        uci -q delete "appcenter.$list_sec.icon" >/dev/null 2>&1 || true
    fi
}

patch_common_template() {
    require_nradio_oem_appcenter
    backup_file "$TPL"

    mkdir -p "$WORKDIR"
    tmp1="$WORKDIR/appcenter.1"
    tmp2="$WORKDIR/appcenter.2"
    tmp3="$WORKDIR/appcenter.3"
    css_file="$WORKDIR/appcenter.css"
    js_file="$WORKDIR/appcenter.js"

    cat > "$css_file" <<'EOF'
    .app_frame_box{
        width: 100%;
    }
    .app_frame_nav{
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        padding: 0 15px 12px;
        border-bottom: 1px solid #e5e5e5;
    }
    .app_frame_nav_item{
        display: inline-block;
        padding: 6px 10px;
        color: #666;
        cursor: pointer;
        border-bottom: 2px solid transparent;
    }
    .app_frame_nav_item_active{
        color: #0088cc;
        border-bottom-color: #0088cc;
    }
    .app_frame_box iframe{
        height: 78vh;
        overflow: scroll;
        border: 0;
        width: 100%;
    }
EOF

    cat > "$js_file" <<'EOF'
    function reload_iframe(){
        var iframe_main = $('#sub_frame').contents().find('.main');
        var iframe_container = $('#sub_frame').contents().find('.body-container');
        if(iframe_main)
            $(iframe_main).addClass("inner_main");
        if(iframe_container)
            $(iframe_container).addClass("inner_container");

        try {
            var frame = document.getElementById('sub_frame');
            if (!frame || !frame.src)
                return;

            if (frame.src.indexOf('/admin/services/openclash') === -1 && frame.src.indexOf('/admin/services/AdGuardHome') === -1 && frame.src.indexOf('/nradioadv/system/openvpnfull') === -1 && frame.src.indexOf('/nradioadv/system/openlist') === -1 && frame.src.indexOf('/nradioadv/system/zerotier') === -1 && frame.src.indexOf('/admin/vpn/easytier') === -1 && frame.src.indexOf('/nradioadv/system/webssh') === -1)
                return;

            var d = frame.contentWindow.document;
            var hide_selectors = [
                'header',
                '.menu_mobile',
                '.mobile_bg_color.container.body-container.visible-xs-block',
                '.footer',
                '.tail_wave'
            ];

            $.each(hide_selectors, function(index, sel){
                $(d).find(sel).css('display', 'none');
            });

            $(d).find('.container.body-container').not('.visible-xs-block').css({
                'width': '100%',
                'margin': '0',
                'padding': '0 10px'
            });
            $(d).find('.main').css({
                'width': '100%',
                'margin': '0'
            });
            $(d).find('.main-content').css({
                'width': '100%',
                'margin': '0',
                'padding': '0'
            });
            $(d.body).css({
                'margin-top': '0',
                'padding-top': '0'
            });
        }
        catch(e) {}
    }
    function get_app_route_url(route){
        return "<%=controller%>" + route;
    }
    function build_app_iframe(route){
        if(route && route.length > 0)
            return "<iframe id='sub_frame' src='" + get_app_route_url(route) + "' name='subpage'></iframe>";
        return "<iframe id='sub_frame' name='subpage'></iframe>";
    }
    function is_openclash_route(route){
        return route && route.indexOf("admin/services/openclash") === 0;
    }
    function is_adguardhome_route(route){
        return route && route.indexOf("admin/services/AdGuardHome") === 0;
    }
    function get_openclash_frame(route){
        var current_route = route && route.length > 0 ? route : "admin/services/openclash/client";
        if(current_route == "admin/services/openclash")
            current_route = "admin/services/openclash/client";

        var tabs = [
            {route: "admin/services/openclash/client", title: "<%:Overviews%>"},
            {route: "admin/services/openclash/settings", title: "<%:Plugin Settings%>"},
            {route: "admin/services/openclash/config-overwrite", title: "<%:Overwrite Settings%>"},
            {route: "admin/services/openclash/config-subscribe", title: "<%:Config Subscribe%>"},
            {route: "admin/services/openclash/config", title: "<%:Config Manage%>"},
            {route: "admin/services/openclash/log", title: "<%:Server Logs%>"}
        ];

        var sub_web_ht = "<div class='app_frame_box'><div class='app_frame_nav'>";
        $.each(tabs, function(index, tab){
            var active_class = "";
            if(tab.route == current_route)
                active_class = " app_frame_nav_item_active";
            sub_web_ht += "<span class='app_frame_nav_item" + active_class + "' data-route='" + tab.route + "' onclick='switch_app_frame_route(this)'>" + tab.title + "</span>";
        });
        sub_web_ht += "</div>" + build_app_iframe(current_route) + "</div>";

        return sub_web_ht;
    }
    function get_adguardhome_frame(route){
        var current_route = route && route.length > 0 ? route : "admin/services/AdGuardHome/base";
        if(current_route == "admin/services/AdGuardHome")
            current_route = "admin/services/AdGuardHome/base";

        var tabs = [
            {route: "admin/services/AdGuardHome/base", title: "Base Setting"},
            {route: "admin/services/AdGuardHome/manual", title: "Manual Config"},
            {route: "admin/services/AdGuardHome/log", title: "Log"}
        ];

        var sub_web_ht = "<div class='app_frame_box'><div class='app_frame_nav'>";
        $.each(tabs, function(index, tab){
            var active_class = "";
            if(tab.route == current_route)
                active_class = " app_frame_nav_item_active";
            sub_web_ht += "<span class='app_frame_nav_item" + active_class + "' data-route='" + tab.route + "' onclick='switch_app_frame_route(this)'>" + tab.title + "</span>";
        });
        sub_web_ht += "</div>" + build_app_iframe(current_route) + "</div>";

        return sub_web_ht;
    }
    function build_app_frame(route){
        if(is_openclash_route(route))
            return get_openclash_frame(route);
        if(is_adguardhome_route(route))
            return get_adguardhome_frame(route);
        return build_app_iframe(route);
    }
    function switch_app_frame_route(obj){
        var route = $(obj).data("route");
        $(".app_frame_nav_item").removeClass("app_frame_nav_item_active");
        $(obj).addClass("app_frame_nav_item_active");
        $("#sub_frame").attr("src", get_app_route_url(route));
    }
    function nradio_plugin_uninstall_key(app_name){
        if(app_name == "luci-app-openclash" || app_name == "openclash")
            return "openclash";
        if(app_name == "Web SSH" || app_name == "webssh" || app_name == "ttyd")
            return "webssh";
        if(app_name == "luci-app-adguardhome" || app_name == "adguardhome")
            return "adguardhome";
        if(app_name == "OpenVPN" || app_name == "openvpn" || app_name == "luci-app-openvpn")
            return "openvpn";
        if(app_name == "OpenList" || app_name == "openlist" || app_name == "luci-app-openlist")
            return "openlist";
        if(app_name == "ZeroTier" || app_name == "zerotier")
            return "zerotier";
        if(app_name == "EasyTier" || app_name == "easytier" || app_name == "luci-app-easytier")
            return "easytier";
        if(app_name == "FanControl Plus" || app_name == "fanctrl-plus" || app_name == "FanControl" || app_name == "fanctrl")
            return "fanctrl";
        if(app_name == "奇游联机宝" || app_name == "QiYou" || app_name == "qiyou" || app_name == "nradio-qiyou")
            return "qiyou";
        if(app_name == "雷神加速器" || app_name == "Leigod" || app_name == "LeigodAcc" || app_name == "leigod" || app_name == "nradio-leigod")
            return "leigod";
        return "";
    }
    function nradio_plugin_uninstall_result(data){
        if(data && data.result)
            return data.result;
        return data || {};
    }
    function nradio_plugin_uninstall_finish(dialogDeal, ok, msg){
        if(dialogDeal)
            dialogDeal.close();

        BootstrapDialog.show({
            type: ok ? BootstrapDialog.TYPE_SUCCESS : BootstrapDialog.TYPE_DANGER,
            title: "<%:Tips%>",
            message: msg,
            buttons: [{
                label: "<%:OK%>",
                cssClass: "btn-primary",
                action: function(dialog){
                    dialog.close();
                    if(ok) {
                        if(typeof refresh_data == "function")
                            refresh_data();
                        else
                            window.location.reload();
                    }
                }
            }]
        });
    }
    function nradio_plugin_uninstall_poll(app_name, dialogDeal){
        $.ajax({
            type: "POST",
            url: "<%=controller%>nradioadv/system/plugin_uninstall/check",
            data: { name: app_name },
            dataType: "json",
            success: function(data){
                var result = nradio_plugin_uninstall_result(data);
                var code = parseInt(result.code, 10);

                if(code == 2) {
                    setTimeout(function(){
                        nradio_plugin_uninstall_poll(app_name, dialogDeal);
                    }, 2000);
                    return;
                }

                if(code == 0) {
                    nradio_plugin_uninstall_finish(dialogDeal, true, result.msg || "卸载完成");
                    return;
                }

                nradio_plugin_uninstall_finish(dialogDeal, false, result.errro_detail || result.error_detail || result.msg || "卸载失败");
            },
            error: function(){
                nradio_plugin_uninstall_finish(dialogDeal, false, "卸载状态检查失败");
            }
        });
    }
    function nradio_plugin_uninstall_start(app_name, dialogDeal){
        $.ajax({
            type: "POST",
            url: "<%=controller%>nradioadv/system/plugin_uninstall/start",
            data: { name: app_name },
            dataType: "json",
            success: function(data){
                var result = nradio_plugin_uninstall_result(data);
                var code = parseInt(result.code, 10);

                if(code == 2) {
                    nradio_plugin_uninstall_poll(app_name, dialogDeal);
                    return;
                }

                if(code == 0) {
                    nradio_plugin_uninstall_finish(dialogDeal, true, result.msg || "卸载完成");
                    return;
                }

                nradio_plugin_uninstall_finish(dialogDeal, false, result.errro_detail || result.error_detail || result.msg || "卸载失败");
            },
            error: function(){
                nradio_plugin_uninstall_finish(dialogDeal, false, "卸载启动失败");
            }
        });
    }
    function nradio_plugin_uninstall_action(app_name){
        var msg = {};
        var dialogDeal = null;

        if(!nradio_plugin_uninstall_key(app_name))
            return false;

        msg.message = '<i class="far fa-nradio-note fa-fw icon_disable" ></i><%:AppUninstallNote%>';
        msg.confirm = "<%:Confirm%>";
        msg.confirm_keep = true;
        msg.cancel = "<%:Cancel%>";
        msg.onhide = function(){};
        msg.callback = function(){
            $(".modal-footer").css("display","none");
            dialogDeal.setMessage(loading_htm);
            nradio_plugin_uninstall_start(app_name, dialogDeal);
        };
        dialogDeal = confirm_box(msg);
        return true;
    }
    function callback(id,route){
        var sub_web_ht = build_app_frame(route);
        $(".top_menu").removeClass("top_menu_active");
        $(".top_menu").each(function(){
            var cur_index = $(this).data("index");
            if(cur_index == id){
                $(this).addClass("top_menu_active");
            }
        });

        sub_dialogDeal = BootstrapDialog.show({
            type: BootstrapDialog.TYPE_DEFAULT,
            closeByBackdrop: true,
            cssClass:'app_frame',
            title: '',
            message: sub_web_ht,
            onhide:function(){
                $(".modal-dialog").css("display","none");
                $(".top_menu").removeClass("top_menu_active");
                $(".top_menu").eq(0).addClass("top_menu_active");
            },
            onshown:function(){
                reload_iframe();
                $('#sub_frame').on('load', function() {
                    reload_iframe();
                });
            }
        });
    }
EOF

    if grep -q 'app_frame_nav_item' "$TPL"; then
        cp "$TPL" "$tmp1"
    else
        awk -v css_file="$css_file" '
            {
                print
                if ($0 ~ /^    \.modal\.app_frame\.in \.modal-content\{$/) {
                    in_target = 1
                    next
                }
                if (in_target && $0 ~ /^    }$/) {
                    while ((getline extra < css_file) > 0) print extra
                    close(css_file)
                    in_target = 0
                }
            }
        ' "$TPL" > "$tmp1"
    fi

    awk -v js_file="$js_file" '
        BEGIN { skip = 0 }
        {
            if (!skip && $0 ~ /^    function reload_iframe\(\)\{$/) {
                while ((getline extra < js_file) > 0) print extra
                close(js_file)
                skip = 1
                next
            }

            if (skip) {
                if ($0 ~ /^    function app_action\(app_name,action,id,route\)\{$/) {
                    skip = 0
                    print
                }
                next
            }

            print
        }
    ' "$tmp1" > "$tmp2"

    if grep -q 'db.name == "OpenVPN"' "$tmp2" && grep -q 'db.name == "luci-app-openclash"' "$tmp2" && grep -q 'db.name == "luci-app-adguardhome"' "$tmp2"; then
        cp "$tmp2" "$tmp3"
    else
        awk '
            {
                print
                if ($0 ~ /^            if \(db\.luci_module_route\)$/) {
                    getline
                    print
                    print "            else if (db.name == \"luci-app-openclash\")"
                    print "                open_route = \"admin/services/openclash\";"
                    print "            else if (db.name == \"luci-app-adguardhome\")"
                    print "                open_route = \"admin/services/AdGuardHome\";"
                    print "            else if (db.name == \"OpenVPN\")"
                    print "                open_route = \"nradioadv/system/openvpnfull\";"
                }
            }
        ' "$tmp2" > "$tmp3"
    fi

    if ! grep -q 'db.name == "OpenVPN"' "$tmp3"; then
        log 'warn: OpenVPN fallback block not found after template patch; continue with current template'
    fi

    if grep -q 'nradioadv/system/fanctrl_plus' "$tmp3"; then
        tmp_fanctrl_route="$WORKDIR/appcenter.fanctrl-route"
        sed 's#nradioadv/system/fanctrl_plus#nradioadv/system/fanctrl#g' "$tmp3" > "$tmp_fanctrl_route"
        cp "$tmp_fanctrl_route" "$tmp3"
    fi

    need_openlist_route='1'
    need_zerotier_route='1'
    need_fanctrl_route='1'
    need_qiyou_route='1'
    need_leigod_route='1'
    grep -q 'db.name == "OpenList"' "$tmp3" && need_openlist_route='0'
    grep -q 'db.name == "ZeroTier"' "$tmp3" && need_zerotier_route='0'
    grep -q 'open_route = "nradioadv/system/fanctrl";' "$tmp3" && need_fanctrl_route='0'
    grep -q 'db.name == "奇游联机宝"' "$tmp3" && need_qiyou_route='0'
    grep -q 'db.name == "雷神加速器"' "$tmp3" && need_leigod_route='0'
    if [ "$need_openlist_route$need_zerotier_route$need_fanctrl_route$need_qiyou_route$need_leigod_route" != '00000' ]; then
        tmp4="$WORKDIR/appcenter.4"
        awk -v need_openlist="$need_openlist_route" -v need_zerotier="$need_zerotier_route" -v need_fanctrl="$need_fanctrl_route" -v need_qiyou="$need_qiyou_route" -v need_leigod="$need_leigod_route" '
            BEGIN { inserted = 0 }
            {
                print
                if (!inserted && $0 ~ /^                open_route = "nradioadv\/system\/openvpnfull";$/) {
                    if (need_openlist == "1") {
                        print "            else if (db.name == \"OpenList\")"
                        print "                open_route = \"nradioadv/system/openlist/basic\";"
                    }
                    if (need_zerotier == "1") {
                        print "            else if (db.name == \"ZeroTier\" || db.name == \"zerotier\")"
                        print "                open_route = \"nradioadv/system/zerotier/basic\";"
                    }
                    if (need_fanctrl == "1") {
                        print "            else if (db.name == \"FanControl Plus\" || db.name == \"fanctrl-plus\" || db.name == \"FanControl\" || db.name == \"fanctrl\")"
                        print "                open_route = \"nradioadv/system/fanctrl\";"
                    }
                    if (need_qiyou == "1") {
                        print "            else if (db.name == \"奇游联机宝\" || db.name == \"QiYou\" || db.name == \"qiyou\" || db.name == \"nradio-qiyou\")"
                        print "                open_route = \"nradioadv/system/qiyou\";"
                    }
                    if (need_leigod == "1") {
                        print "            else if (db.name == \"雷神加速器\" || db.name == \"Leigod\" || db.name == \"LeigodAcc\" || db.name == \"leigod\" || db.name == \"nradio-leigod\")"
                        print "                open_route = \"nradioadv/system/leigod\";"
                    }
                    inserted = 1
                }
            }
        ' "$tmp3" > "$tmp4"
        cp "$tmp4" "$tmp3"
    fi

    tmp5="$WORKDIR/appcenter.5"
    awk '
        BEGIN { skip_return = 0 }
        skip_return && $0 ~ /^[[:space:]]*return;[[:space:]]*$/ {
            skip_return = 0
            next
        }
        /window\.location\.href = .*nradioadv\/system\/plugin_uninstall\// {
            skip_return = 1
            next
        }
        {
            skip_return = 0
            print
        }
    ' "$tmp3" > "$tmp5"
    cp "$tmp5" "$TPL"

    if ! grep -q "action == 'uninstall' && nradio_plugin_uninstall_action(app_name)" "$TPL"; then
        tmp6="$WORKDIR/appcenter.6"
        awk '
            BEGIN { inserted = 0 }
            {
                print
                if (!inserted && $0 ~ /^        var info_msg = "";$/) {
                    print "        if (action == '\''uninstall'\'' && nradio_plugin_uninstall_action(app_name)) {"
                    print "            return;"
                    print "        }"
                    print ""
                    inserted = 1
                }
            }
        ' "$TPL" > "$tmp6"
        cp "$tmp6" "$TPL"
    fi

    icon_cache_tag="${SCRIPT_RELEASE_DATE}-${SCRIPT_VERSION}-unified-icons-v2"
    tmp7="$WORKDIR/appcenter.icon-cache"
    awk -v tag="$icon_cache_tag" '
        {
            gsub(/\/luci-static\/nradio\/images\/icon\/\{\{icon\}\}\?v=[A-Za-z0-9._-]+/, "/luci-static/nradio/images/icon/{{icon}}")
            gsub(/\/luci-static\/nradio\/images\/icon\/\{\{icon\}\}/, "/luci-static/nradio/images/icon/{{icon}}?v=" tag)
            print
        }
    ' "$TPL" > "$tmp7"
    cp "$tmp7" "$TPL"

    verify_template_marker 'open_route = "admin/services/openclash";' 'OpenClash 打开路由'
    verify_template_marker 'open_route = "admin/services/AdGuardHome";' 'AdGuardHome 打开路由'
    verify_template_marker 'open_route = "nradioadv/system/openvpnfull";' 'OpenVPN 打开路由'
    verify_template_marker 'open_route = "nradioadv/system/openlist/basic";' 'OpenList 打开路由'
    verify_template_marker 'open_route = "nradioadv/system/zerotier/basic";' 'ZeroTier 打开路由'
    verify_template_marker 'open_route = "nradioadv/system/fanctrl";' 'FanControl 打开路由'
    verify_template_marker "frame.src.indexOf('/admin/vpn/easytier') === -1" 'EasyTier iframe 白名单'
    verify_template_marker "frame.src.indexOf('/nradioadv/system/webssh') === -1" 'Web SSH iframe 白名单'
    verify_template_marker "action == 'uninstall' && nradio_plugin_uninstall_action(app_name)" '脚本插件异步卸载入口'
    verify_template_marker 'plugin_uninstall/start' '脚本插件异步卸载启动接口'
    verify_template_marker 'plugin_uninstall/check' '脚本插件异步卸载检查接口'
    verify_template_marker "/luci-static/nradio/images/icon/{{icon}}?v=$icon_cache_tag" '应用商店图标缓存刷新参数'
}

patch_appcenter_status_controller() {
    require_nradio_oem_appcenter
    verify_file_exists "$APPCENTER_CONTROLLER" "NRadio 应用商店控制器"

    mkdir -p "$WORKDIR"
    backup_file "$APPCENTER_CONTROLLER"

    if ! grep -q 'appcenter", "sys_status"' "$APPCENTER_CONTROLLER" 2>/dev/null; then
        tmp_controller_entry="$WORKDIR/appcenter-controller.sys-status-entry"
        awk '
            {
                print
                if ($0 ~ /"appcenter",[[:space:]]*"memory"/ && !inserted) {
                    print "\tentry({\"nradioadv\", \"system\", \"appcenter\", \"sys_status\"}, call(\"action_sys_status\"), nil, nil, true).leaf = true"
                    inserted = 1
                }
            }
        ' "$APPCENTER_CONTROLLER" > "$tmp_controller_entry"
        cp "$tmp_controller_entry" "$APPCENTER_CONTROLLER"
    fi

    if ! grep -q 'function action_sys_status()' "$APPCENTER_CONTROLLER" 2>/dev/null; then
        cat >> "$APPCENTER_CONTROLLER" <<'EOF_APPCENTER_SYS_STATUS_LUA'

local function nradio_appcenter_read_first_line(path)
	local fp = io.open(path, "r")
	if not fp then
		return nil
	end
	local line = fp:read("*l")
	fp:close()
	return line
end

local function nradio_appcenter_read_cpu_stat()
	local line = nradio_appcenter_read_first_line("/proc/stat")
	if not line then
		return nil
	end

	local values = {}
	for n in line:gmatch("%d+") do
		values[#values + 1] = tonumber(n) or 0
	end
	if #values < 4 then
		return nil
	end

	local idle = (values[4] or 0) + (values[5] or 0)
	local total = 0
	for _, value in ipairs(values) do
		total = total + value
	end

	return total, idle
end

local function nradio_appcenter_read_cpu_usage_percent()
	local fs = require "nixio.fs"
	local state_path = "/tmp/nradio_appcenter_cpu.stat"
	local total, idle = nradio_appcenter_read_cpu_stat()
	if not total or not idle then
		return nil
	end

	local prev_total, prev_idle
	local previous = fs.readfile(state_path)
	if previous then
		prev_total, prev_idle = previous:match("^(%d+)%s+(%d+)")
		prev_total = tonumber(prev_total)
		prev_idle = tonumber(prev_idle)
	end
	fs.writefile(state_path, string.format("%d %d\n", total, idle))

	if not prev_total or not prev_idle then
		return nil
	end

	local delta_total = total - prev_total
	local delta_idle = idle - prev_idle
	if delta_total <= 0 then
		return nil
	end

	local usage = (delta_total - delta_idle) * 100 / delta_total
	if usage < 0 then usage = 0 end
	if usage > 100 then usage = 100 end
	return math.floor(usage * 10 + 0.5) / 10
end

local function nradio_appcenter_read_temperature_celsius()
	local fs = require "nixio.fs"
	local max_temp = nil
	for i = 0, 8 do
		local path = string.format("/sys/class/thermal/thermal_zone%d/temp", i)
		if fs.access(path) then
			local raw = tonumber(nradio_appcenter_read_first_line(path) or "")
			if raw then
				local temp = raw
				if temp > 1000 then
					temp = temp / 1000
				end
				if not max_temp or temp > max_temp then
					max_temp = temp
				end
			end
		end
	end
	if not max_temp then
		return nil
	end
	return math.floor(max_temp * 10 + 0.5) / 10
end

local function nradio_appcenter_read_system_memory()
	local total, available = 0, 0
	for line in io.lines("/proc/meminfo") do
		local key, value = line:match("^(%w+):%s+(%d+)")
		value = tonumber(value)
		if key == "MemTotal" and value then
			total = value
		elseif key == "MemAvailable" and value then
			available = value
		end
		if total > 0 and available > 0 then
			break
		end
	end

	local used = total - available
	if used < 0 then
		used = 0
	end

	local percent = 0
	if total > 0 then
		percent = math.floor((used * 1000 / total) + 0.5) / 10
	end

	return total, used, percent
end

function action_sys_status()
	local load_line = nradio_appcenter_read_first_line("/proc/loadavg") or ""
	local load1 = load_line:match("^(%S+)") or "-"
	local mem_total, mem_used, mem_percent = nradio_appcenter_read_system_memory()

	luci.nradio.luci_call_result({
		cpu_percent = nradio_appcenter_read_cpu_usage_percent(),
		cpu_temp = nradio_appcenter_read_temperature_celsius(),
		mem_total = mem_total,
		mem_used = mem_used,
		mem_percent = mem_percent,
		load1 = load1,
	})
end
EOF_APPCENTER_SYS_STATUS_LUA
    fi

    grep -q 'appcenter", "sys_status"' "$APPCENTER_CONTROLLER" 2>/dev/null || die "appcenter controller verify failed: missing sys_status route"
    grep -q 'function action_sys_status()' "$APPCENTER_CONTROLLER" 2>/dev/null || die "appcenter controller verify failed: missing action_sys_status"
}

patch_appcenter_card_polish() {
    require_nradio_oem_appcenter

    mkdir -p "$WORKDIR"
    css_file="$WORKDIR/appcenter-card-polish.css"
    tmp_css="$WORKDIR/appcenter-card-polish.css.tmp"
    tmp_row="$WORKDIR/appcenter-card-polish.row.tmp"
    tmp_status="$WORKDIR/appcenter-card-polish.status.tmp"
    tmp_compose="$WORKDIR/appcenter-card-polish.compose.tmp"
    tmp_panel="$WORKDIR/appcenter-card-polish.panel.tmp"
    tmp_ready="$WORKDIR/appcenter-card-polish.ready.tmp"
    tmp_icon="$WORKDIR/appcenter-card-polish.icon.tmp"
    tmp_desc="$WORKDIR/appcenter-card-polish.desc.tmp"
    status_js_file="$WORKDIR/appcenter-card-polish.status-panel.js"
    empty_js_file="$WORKDIR/appcenter-card-polish.empty-state.js"

    cat > "$css_file" <<'EOF_APPCENTER_CARD_POLISH_CSS'
    /* NRadio appcenter card polish: visual-only layer */
    /* NRadio appcenter card polish V2.0.3 full repair layer */
    /* NRadio appcenter visual polish 1-5 safe refinement */
    /* Keep appcontainer/container_left/app_top_menu/container_right layout owned by NRadio OEM CSS. */
    .container_right .app_box{
        /* NRadio appcenter card surface safe polish */
        position: relative;
        min-height: 172px;
        padding: 14px 12px;
        overflow: hidden;
        box-sizing: border-box;
        border: 1px solid rgba(255,255,255,.11);
        border-radius: 14px;
        background:
            radial-gradient(circle at 18% 18%, rgba(34,211,238,.10), transparent 30%),
            radial-gradient(circle at 92% 0%, rgba(59,130,246,.09), transparent 34%),
            linear-gradient(145deg, rgba(255,255,255,.050), rgba(255,255,255,.024));
        background-blend-mode: screen, screen, normal;
        box-shadow: inset 0 1px 0 rgba(255,255,255,.06), 0 10px 24px rgba(0,0,0,.10);
        transition: border-color .18s ease, box-shadow .18s ease, transform .18s ease, background .18s ease;
    }
    .container_right .app_box:focus-within{
        border-color: rgba(96,165,250,.42);
        box-shadow: inset 0 1px 0 rgba(255,255,255,.08), 0 0 0 2px rgba(96,165,250,.12), 0 14px 26px rgba(0,0,0,.14);
    }
    .container_right .app_box::before{
        content: "";
        position: absolute;
        inset: 0 0 auto 0;
        height: 1px;
        background: linear-gradient(90deg, transparent, rgba(0,213,255,.62), transparent);
        opacity: .44;
        box-shadow: 0 0 12px rgba(34,211,238,.18);
    }
    .container_right .app_box::after{
        content: "";
        position: absolute;
        right: -35px;
        top: -38px;
        width: 92px;
        height: 92px;
        border-radius: 50%;
        background: rgba(0,213,255,.06);
        filter: blur(8px);
        opacity: 0;
        transition: opacity .18s ease;
        pointer-events: none;
    }
    .container_right .app_box:hover{
        transform: translateY(-2px);
        border-color: rgba(0,213,255,.34);
        background:
            radial-gradient(circle at 18% 18%, rgba(34,211,238,.14), transparent 30%),
            radial-gradient(circle at 92% 0%, rgba(59,130,246,.12), transparent 34%),
            linear-gradient(145deg, rgba(255,255,255,.066), rgba(255,255,255,.030));
        box-shadow: inset 0 1px 0 rgba(255,255,255,.08), 0 14px 26px rgba(0,0,0,.14), 0 0 0 1px rgba(0,213,255,.05);
    }
    .container_right .app_box:hover::after{
        opacity: 1;
    }
    .container_right .app_box:hover::before{
        opacity: .70;
    }
    .container_right .app_icon{
        position: relative;
        float: left;
        width: 35%;
        margin: 10px 0 0 5px;
        text-align: center;
        z-index: 1;
    }
    .container_right .app_icon_img{
        /* NRadio appcenter icon safe polish */
        width: 58px;
        height: 58px;
        padding: 7px;
        object-fit: contain;
        box-sizing: border-box;
        border-radius: 16px;
        background:
            linear-gradient(180deg, rgba(255,255,255,.16), rgba(255,255,255,.08));
        box-shadow: inset 0 1px 0 rgba(255,255,255,.12), 0 10px 18px rgba(0,0,0,.18);
        filter: saturate(1.08) contrast(1.02);
        transition: transform .18s ease, filter .18s ease, box-shadow .18s ease;
        will-change: transform;
    }
    .container_right .app_box:hover .app_icon_img{
        transform: translateY(-1px) scale(1.035);
        filter: saturate(1.16) contrast(1.04);
        box-shadow: inset 0 1px 0 rgba(255,255,255,.14), 0 12px 20px rgba(0,0,0,.20), 0 0 0 1px rgba(34,211,238,.06);
    }
    .container_right .app_icon_img.nr_app_default_icon{
        padding: 10px;
        background:
            linear-gradient(180deg, rgba(148,163,184,.20), rgba(71,85,105,.18));
        box-shadow: inset 0 1px 0 rgba(255,255,255,.13), 0 10px 18px rgba(0,0,0,.16);
        filter: grayscale(.08) saturate(.86) contrast(1.02);
        opacity: .92;
    }
    .container_right .app_info{
        position: relative;
        z-index: 1;
        float: right;
        width: 60%;
        min-width: 0;
        margin: 10px 0 0;
        padding-right: 0;
    }
    .container_right .app_name{
        /* NRadio appcenter text safe polish */
        float: none;
        width: 100%;
        height: auto;
        max-height: 40px;
        color: #f8fbff;
        font-size: 13px;
        font-weight: 900;
        line-height: 1.38;
        letter-spacing: 0;
        overflow: hidden;
        overflow-wrap: anywhere;
        word-break: break-word;
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        text-shadow: 0 1px 1px rgba(0,0,0,.24), 0 0 10px rgba(148,163,184,.08);
        transition: color .18s ease, text-shadow .18s ease;
    }
    .container_right .app_box:hover .app_name{
        color: #ffffff;
        text-shadow: 0 1px 1px rgba(0,0,0,.26), 0 0 12px rgba(125,211,252,.14);
    }
    .container_right .app_version{
        float: none;
        display: inline-flex;
        width: auto;
        max-width: 100%;
        height: auto;
        margin-top: 4px;
        padding: 2px 0;
        color: #f8fafc;
        font-size: 10px;
        font-weight: 800;
        line-height: 1.2;
        opacity: .95;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        text-shadow: 0 1px 1px rgba(0,0,0,.20);
        transition: color .18s ease, opacity .18s ease;
    }
    .container_right .app_box:hover .app_version{
        color: #e0f2fe;
        opacity: 1;
    }
    .container_right .app_meta_row{
        display: flex;
        flex-wrap: wrap;
        gap: 4px;
        margin-top: 6px;
    }
    .container_right .app_state_badge,
    .container_right .app_open_badge{
        /* NRadio appcenter button badge safe polish */
        display: inline-flex;
        align-items: center;
        gap: 4px;
        max-width: 100%;
        min-height: 19px;
        padding: 2px 7px;
        box-sizing: border-box;
        border-radius: 999px;
        border: 1px solid rgba(255,255,255,.10);
        background: rgba(255,255,255,.055);
        color: #cbd5e1;
        font-size: 10px;
        font-weight: 900;
        line-height: 1;
        text-shadow: 0 1px 1px rgba(0,0,0,.18);
        box-shadow: inset 0 1px 0 rgba(255,255,255,.08), 0 4px 9px rgba(0,0,0,.08);
    }
    .container_right .app_state_badge::before,
    .container_right .app_open_badge::before{
        content: "";
        width: 5px;
        height: 5px;
        border-radius: 50%;
        background: currentColor;
        box-shadow: 0 0 8px currentColor;
    }
    .container_right .app_state_1{
        color: #bbf7d0;
        border-color: rgba(74,222,128,.30);
        background: linear-gradient(180deg, rgba(34,197,94,.18), rgba(21,128,61,.12));
        box-shadow: inset 0 1px 0 rgba(255,255,255,.09), 0 0 0 1px rgba(34,197,94,.04), 0 5px 11px rgba(21,128,61,.10);
    }
    .container_right .app_state_2{
        color: #fde68a;
        border-color: rgba(251,191,36,.32);
        background: linear-gradient(180deg, rgba(245,158,11,.20), rgba(180,83,9,.12));
        box-shadow: inset 0 1px 0 rgba(255,255,255,.10), 0 0 0 1px rgba(245,158,11,.05), 0 5px 11px rgba(180,83,9,.10);
    }
    .container_right .app_state_0{
        color: #bae6fd;
        border-color: rgba(56,189,248,.30);
        background: linear-gradient(180deg, rgba(14,165,233,.18), rgba(2,132,199,.12));
        box-shadow: inset 0 1px 0 rgba(255,255,255,.09), 0 0 0 1px rgba(14,165,233,.04), 0 5px 11px rgba(2,132,199,.10);
    }
    .container_right .app_open_1{
        color: #a5f3fc;
        border-color: rgba(34,211,238,.34);
        background: linear-gradient(180deg, rgba(34,211,238,.18), rgba(8,145,178,.12));
        box-shadow: inset 0 1px 0 rgba(255,255,255,.09), 0 0 0 1px rgba(34,211,238,.05), 0 5px 11px rgba(8,145,178,.10);
    }
    .container_right .app_des{
        position: static;
        float: left;
        width: 100%;
        height: 34px;
        margin-top: 8px;
        color: #d4d8e7;
        font-size: 12px;
        line-height: 1.42;
        opacity: .92;
        overflow: hidden;
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        text-shadow: 0 1px 1px rgba(0,0,0,.18);
        transition: color .18s ease, opacity .18s ease;
    }
    .container_right .app_box:hover .app_des{
        color: #e2e8f0;
        opacity: .98;
    }
    .container_right .app_des_empty{
        display: none;
    }
    .container_right .app_action{
        position: relative;
        z-index: 2;
        float: left;
        width: 100%;
        margin: 10px 0 0;
        padding: 0 2px;
        box-sizing: border-box;
    }
    .container_right .action_list{
        display: flex;
        align-items: center;
        justify-content: flex-end;
        gap: 7px;
        float: none;
        margin: 0;
        padding: 0;
    }
    .container_right .action_list_li,
    .app_btn_class{
        min-width: 54px;
        height: 30px;
        padding: 0 12px;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        border: 1px solid rgba(255,255,255,.10);
        border-radius: 9px;
        color: #dce4f2;
        background: linear-gradient(180deg, rgba(255,255,255,.090), rgba(255,255,255,.052));
        box-shadow: inset 0 1px 0 rgba(255,255,255,.08), 0 6px 12px rgba(0,0,0,.10);
        box-sizing: border-box;
        font-size: 12px;
        font-weight: 800;
        line-height: 1;
        white-space: nowrap;
        cursor: pointer;
        transition: color .18s ease, background .18s ease, border-color .18s ease, transform .18s ease, box-shadow .18s ease;
    }
    .container_right .action_list_li:focus-visible,
    .app_btn_class:focus-visible{
        outline: 2px solid rgba(34,211,238,.38);
        outline-offset: 2px;
    }
    .container_right .action_list_li:active,
    .app_btn_class:active{
        transform: translateY(0);
        box-shadow: inset 0 1px 4px rgba(0,0,0,.18);
    }
    .container_right .action_list_li:hover,
    .app_btn_class:hover{
        transform: translateY(-1px);
        border-color: rgba(34,211,238,.42);
        color: #06111f;
        background: linear-gradient(135deg, #67e8f9, #38bdf8 54%, #60a5fa);
        -webkit-text-fill-color: currentColor;
        box-shadow: 0 10px 18px rgba(34,211,238,.14);
    }
    .app_btn_group{
        gap: 10px;
    }
    .app_btn_class{
        min-width: 84px;
        height: 32px;
        color: #cbd5e1;
        background: rgba(255,255,255,.065);
    }
    .mem_track{
        max-width: 280px;
    }
    .mem_header{
        color: #dce4f2;
        font-weight: 800;
    }
    .mem_progress{
        /* NRadio appcenter memory bar safe polish */
        height: 8px;
        border-radius: 999px;
        background: linear-gradient(180deg, rgba(255,255,255,.18), rgba(255,255,255,.10));
        box-shadow: inset 0 1px 2px rgba(0,0,0,.22);
        overflow: hidden;
    }
    .mem_progress_inner{
        position: relative;
        height: 100%;
        border-radius: inherit;
        background: linear-gradient(90deg, #67e8f9, #38bdf8 50%, #60a5fa);
        box-shadow: 0 0 12px rgba(34,211,238,.28);
        transition: width .25s ease;
    }
    .mem_progress_inner::after{
        content: "";
        position: absolute;
        left: 0;
        right: 0;
        top: 0;
        height: 1px;
        background: rgba(255,255,255,.30);
        pointer-events: none;
    }
    .app_status_panel{
        clear: both;
        width: calc(100% - 20px);
        margin: 12px 10px 0;
        padding: 12px 12px 11px;
        box-sizing: border-box;
        border-radius: 14px;
        border: 1px solid rgba(34,211,238,.16);
        background:
            radial-gradient(circle at 12% 12%, rgba(34,211,238,.11), transparent 34%),
            radial-gradient(circle at 88% 0%, rgba(59,130,246,.11), transparent 36%),
            linear-gradient(160deg, rgba(24,32,50,.92), rgba(16,22,36,.78));
        box-shadow: inset 0 1px 0 rgba(255,255,255,.07), 0 12px 24px rgba(0,0,0,.14);
    }
    .app_status_panel *{
        box-sizing: border-box;
    }
    .app_empty_state{
        clear: both;
        width: calc(100% - 20px);
        margin: 12px 10px 0;
        padding: 18px 16px;
        box-sizing: border-box;
        border-radius: 14px;
        border: 1px dashed rgba(125,211,252,.24);
        background: rgba(15,23,42,.36);
        color: #dbeafe;
        line-height: 1.7;
    }
    .app_empty_state strong{
        display: block;
        color: #f8fbff;
        font-size: 14px;
        font-weight: 900;
    }
    .app_empty_state span{
        display: block;
        margin-top: 4px;
        color: #b9c6d8;
        font-size: 12px;
    }
    .app_status_head{
        /* NRadio appcenter status panel safe polish */
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 10px;
        margin-bottom: 9px;
        padding-bottom: 8px;
        border-bottom-color: rgba(255,255,255,.10);
        color: #7dd3fc;
        text-shadow: 0 0 10px rgba(34,211,238,.16);
    }
    .app_status_head span{
        display: inline-flex;
        align-items: center;
        gap: 7px;
    }
    .app_status_head span::before{
        content: "";
        width: 7px;
        height: 7px;
        border-radius: 50%;
        background: #22d3ee;
        box-shadow: 0 0 14px rgba(34,211,238,.8);
    }
    .app_status_grid{
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 8px;
        margin-bottom: 8px;
    }
    .app_status_time{
        color: #cbd5e1;
        font-weight: 800;
        font-style: italic;
    }
    .app_status_tile{
        min-height: 46px;
        padding: 8px 9px;
        border-radius: 10px;
        border-color: rgba(255,255,255,.10);
        background:
            radial-gradient(circle at 10% 0%, rgba(34,211,238,.12), transparent 42%),
            linear-gradient(180deg, rgba(255,255,255,.075), rgba(255,255,255,.035));
        box-shadow: inset 0 1px 0 rgba(255,255,255,.06), 0 6px 14px rgba(0,0,0,.08);
        transition: border-color .18s ease, box-shadow .18s ease;
    }
    .app_status_tile:hover{
        border-color: rgba(34,211,238,.20);
        box-shadow: inset 0 1px 0 rgba(255,255,255,.08), 0 8px 16px rgba(0,0,0,.10);
    }
    .app_status_tile strong{
        color: #ffffff;
        font-size: 18px;
        line-height: 20px;
        text-shadow: 0 0 10px rgba(125,211,252,.18);
    }
    .app_status_tile span{
        color: #d8dfec;
        font-weight: 800;
        opacity: .96;
    }
    .app_status_metric{
        padding: 8px 0;
        border-top-color: rgba(255,255,255,.095);
    }
    .app_status_metric_row{
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 10px;
        margin-bottom: 5px;
        color: #cbd5e1;
        font-weight: 800;
    }
    .app_status_metric_row strong{
        color: #f8fafc;
        font-weight: 900;
        text-shadow: 0 0 8px rgba(148,163,184,.16);
    }
    .app_status_bar{
        position: relative;
        height: 6px;
        border-radius: 999px;
        background: linear-gradient(180deg, rgba(255,255,255,.18), rgba(255,255,255,.10));
        box-shadow: inset 0 1px 2px rgba(0,0,0,.20);
        overflow: hidden;
    }
    .app_status_bar::after{
        content: "";
        position: absolute;
        left: 0;
        right: 0;
        top: 0;
        height: 1px;
        background: rgba(255,255,255,.18);
        pointer-events: none;
    }
    .app_status_bar span{
        position: relative;
        display: block;
        height: 100%;
        width: 0;
        border-radius: inherit;
        background: linear-gradient(90deg, #22d3ee, #38bdf8 50%, #60a5fa);
        box-shadow: 0 0 12px rgba(34,211,238,.36);
        transition: width .25s ease;
    }
    .app_status_temp_bar{
        background: linear-gradient(90deg, #22c55e, #facc15 64%, #fb7185) !important;
    }
    .app_status_cpu_bar{
        background: linear-gradient(90deg, #38bdf8, #818cf8 72%, #c084fc) !important;
    }
    .app_status_mem_bar{
        background: linear-gradient(90deg, #2dd4bf, #38bdf8 58%, #60a5fa) !important;
    }
    .app_status_hint{
        margin-top: 7px;
        padding: 7px 8px 0;
        color: #b9c6d8;
        border-top-color: rgba(255,255,255,.095);
    }
    @media (max-width: 760px){
        .container_right .app_box{
            min-height: 168px;
        }
        .container_right .app_info{
            width: 62%;
        }
        .container_right .app_icon{
            width: 34%;
        }
        .app_status_head{
            align-items: flex-start;
            flex-direction: column;
            gap: 4px;
        }
        .app_status_grid{
            grid-template-columns: 1fr;
        }
    }
EOF_APPCENTER_CARD_POLISH_CSS

    awk -v css_file="$css_file" '
        /NRadio appcenter card polish: visual-only layer/ || /NRadio appcenter card polish V1\.60\.5 full repair layer/ {
            skip_polish_css = 1
            next
        }
        skip_polish_css && /^<\/style>$/ {
            while ((getline extra < css_file) > 0) print extra
            close(css_file)
            print
            inserted = 1
            skip_polish_css = 0
            next
        }
        skip_polish_css {
            next
        }
        /^<\/style>$/ && !inserted {
            while ((getline extra < css_file) > 0) print extra
            close(css_file)
            inserted = 1
        }
        { print }
    ' "$TPL" > "$tmp_css"
    cp "$tmp_css" "$TPL"

    cat > "$status_js_file" <<'EOF_APPCENTER_STATUS_PANEL_JS'
    var APP_STATUS_LAST = null;

    function build_app_status_panel_from_data(data){
        var installed_count = 0;
        var open_count = 0;
        var all_count = 0;

        if(data && data.result && data.result.applist){
            $.each(data.result.applist, function(index, db){
                all_count++;
                if(db.open == 1)
                    open_count++;
                if(db.status == APP_STATUS_APP_INSTALLED || db.status == APP_STATUS_APP_UPDATEED)
                    installed_count++;
            });
        }

        return build_app_status_panel(installed_count, open_count, all_count);
    }

    function build_app_empty_state(title, detail){
        return ''+
        '<div class="app_empty_state">'+
        '    <strong>'+title+'</strong>'+
        '    <span>'+detail+'</span>'+
        '</div>';
    }

    function build_app_status_panel(installed_count, open_count, all_count){
        return ''+
        '<aside class="app_status_panel">'+
        '    <div class="app_status_head"><span>系统状态</span><em class="app_status_time">等待刷新</em></div>'+
        '    <div class="app_status_grid">'+
        '        <div class="app_status_tile"><strong>'+installed_count+'</strong><span>已安装</span></div>'+
        '        <div class="app_status_tile"><strong>'+open_count+'</strong><span>后台</span></div>'+
        '        <div class="app_status_tile"><strong>'+all_count+'</strong><span>全部</span></div>'+
        '    </div>'+
        '    <div class="app_status_metric">'+
        '        <div class="app_status_metric_row"><span>CPU 温度</span><strong class="app_status_temp">--</strong></div>'+
        '        <div class="app_status_bar"><span class="app_status_temp_bar"></span></div>'+
        '    </div>'+
        '    <div class="app_status_metric">'+
        '        <div class="app_status_metric_row"><span>CPU 使用率</span><strong class="app_status_cpu">采样中</strong></div>'+
        '        <div class="app_status_bar"><span class="app_status_cpu_bar"></span></div>'+
        '    </div>'+
        '    <div class="app_status_metric">'+
        '        <div class="app_status_metric_row"><span>内存占用</span><strong class="app_status_mem">--</strong></div>'+
        '        <div class="app_status_bar"><span class="app_status_mem_bar"></span></div>'+
        '    </div>'+
        '    <div class="app_status_hint">只读状态 · 5 秒刷新 · 不参与安装卸载</div>'+
        '</aside>';
    }

    function format_kib(kib){
        var mb = Number(kib || 0) / 1024;
        if(mb >= 1024)
            return (mb / 1024).toFixed(1) + " G";
        return mb.toFixed(0) + " M";
    }

    function set_status_width(selector, value){
        var percent = Number(value || 0);
        percent = Math.max(0, Math.min(100, percent));
        $(selector).css("width", percent.toFixed(1) + "%");
    }

    function update_app_status_panel(data){
        if(!data) return;
        APP_STATUS_LAST = data;

        var temp = Number(data.cpu_temp || 0);
        var cpu = data.cpu_percent;
        var mem_percent = Number(data.mem_percent || 0);
        var now = new Date();

        $(".app_status_time").text(("0"+now.getHours()).slice(-2)+":"+("0"+now.getMinutes()).slice(-2)+":"+("0"+now.getSeconds()).slice(-2));
        $(".app_status_temp").text(temp > 0 ? temp.toFixed(1) + " ℃" : "--");
        set_status_width(".app_status_temp_bar", temp > 0 ? Math.min(100, temp) : 0);

        if(cpu === null || typeof cpu === "undefined" || cpu === ""){
            $(".app_status_cpu").text("采样中");
            set_status_width(".app_status_cpu_bar", 0);
        }
        else{
            cpu = Number(cpu || 0);
            $(".app_status_cpu").text(cpu.toFixed(1) + "%");
            set_status_width(".app_status_cpu_bar", cpu);
        }

        $(".app_status_mem").text(format_kib(data.mem_used) + " / " + format_kib(data.mem_total) + " · " + mem_percent.toFixed(1) + "%");
        set_status_width(".app_status_mem_bar", mem_percent);
    }

    function get_system_status(){
        var data={};
        data['token']='<%=token%>';
        (new XHR()).post('<%=controller%>nradioadv/system/appcenter/sys_status', data, function(xhr){
            if (xhr.getResponseHeader("Content-Type") == "application/json") {
                try {
                    var data_res = eval('(' + xhr.responseText + ')');
                    if(data_res && data_res.result)
                        update_app_status_panel(data_res.result);
                }
                catch(e) {
                }
            }
        });
    }
EOF_APPCENTER_STATUS_PANEL_JS

    cat > "$empty_js_file" <<'EOF_APPCENTER_EMPTY_STATE_JS'
    function build_app_empty_state(title, detail){
        return ''+
        '<div class="app_empty_state">'+
        '    <strong>'+title+'</strong>'+
        '    <span>'+detail+'</span>'+
        '</div>';
    }

EOF_APPCENTER_EMPTY_STATE_JS

    awk '
        /function appcenter_has_any_app\(data\)\{/ {
            skip_func = 1
            next
        }
        /function appcenter_has_installed_app\(data\)\{/ {
            skip_func = 1
            next
        }
        /function show_appcenter_all_view\(\)\{/ {
            skip_func = 1
            next
        }
        skip_func {
            if ($0 ~ /^    }$/)
                skip_func = 0
            next
        }
        /var has_any_app = appcenter_has_any_app\(data\);/ {
            next
        }
        /var has_installed_app = appcenter_has_installed_app\(data\);/ {
            next
        }
        /if\(!has_installed_app && has_any_app\)/ {
            skip_auto_switch = 1
            next
        }
        skip_auto_switch && /show_appcenter_all_view\(\);/ {
            skip_auto_switch = 0
            next
        }
        {
            gsub(/当前设备还没有可显示的已安装应用，已自动切换到所有应用。/, "当前分类没有可显示的已安装应用，可切换到所有应用查看。")
            print
        }
    ' "$TPL" > "$tmp_panel"
    cp "$tmp_panel" "$TPL"

    if ! grep -q '<div class="app_meta_row"' "$TPL" 2>/dev/null; then
        awk '
            {
                print
                if ($0 ~ /^        '\''            <div class="app_version" title=" \{\{version\}\}">'\''\+$/) {
                    getline line2; print line2
                    getline line3; print line3
                    print "        '\''            <div class=\"app_meta_row\">'\''+"
                    print "        '\''                <span class=\"app_state_badge app_state_{{status}}\">{{status_label}}</span>'\''+"
                    print "        '\''                {{open_badge}}'\''+"
                    print "        '\''            </div>'\''+"
                }
            }
        ' "$TPL" > "$tmp_row"
        cp "$tmp_row" "$TPL"
    fi

    if ! grep -q 'db.status_label' "$TPL" 2>/dev/null; then
        awk '
            {
                print
                if ($0 ~ /^            if \(db\.status == APP_STATUS_APP_NEW\)\{$/)
                    print "                db.status_label = \"未安装\";"
                else if ($0 ~ /^            else if \(db\.status == APP_STATUS_APP_INSTALLED\)\{$/)
                    print "                db.status_label = \"已安装\";"
                else if ($0 ~ /^            else if \(db\.status == APP_STATUS_APP_UPDATEED\)\{$/)
                    print "                db.status_label = \"可更新\";"
                else if ($0 ~ /^            if \(db\.icon && db\.icon\.length\)$/) {
                    print "            if (!db.status_label)"
                    print "                db.status_label = \"未知\";"
                    print ""
                    print "            var open_badge = \"\";"
                    print "            if (db.open == 1)"
                    print "                open_badge = '\''<span class=\"app_open_badge app_open_1\">后台</span>'\'';"
                    print ""
                }
            }
        ' "$TPL" > "$tmp_status"
        cp "$tmp_status" "$TPL"
    fi

    awk '
        {
            if ($0 ~ /^            if \(db\.icon && db\.icon\.length\)$/) {
                line2 = ""
                if ((getline line2) > 0 && line2 ~ /^            if \(!db\.status_label\)$/) {
                    getline line3
                    getline line4
                    getline line5
                    getline line6
                    getline line7
                    getline line8
                    getline line9
                    print "            if (!db.status_label)"
                    print "                db.status_label = \"未知\";"
                    print ""
                    print "            var open_badge = \"\";"
                    print "            if (db.open == 1)"
                    print "                open_badge = '\''<span class=\"app_open_badge app_open_1\">后台</span>'\'';"
                    print ""
                    print "            if (db.icon && db.icon.length)"
                    print "                icon_name = db.icon;"
                    next
                }
                print
                if (line2 != "")
                    print line2
                next
            }
            print
        }
    ' "$TPL" > "$tmp_status"
    cp "$tmp_status" "$TPL"

    if ! grep -q 'status_label: db.status_label' "$TPL" 2>/dev/null; then
        awk '
            {
                print
                if ($0 ~ /^                    opt:optht,$/ || $0 ~ /^                opt:optht,$/) {
                    prefix = substr($0, 1, index($0, "opt:") - 1)
                    print prefix "status: db.status,"
                    print prefix "status_label: db.status_label,"
                    print prefix "open_badge: open_badge,"
                }
            }
        ' "$TPL" > "$tmp_compose"
        cp "$tmp_compose" "$TPL"
    fi

    if ! grep -q 'var icon_fallback = ' "$TPL" 2>/dev/null; then
        awk '
            {
                print
                if ($0 ~ /^[[:space:]]*var icon_name = "app_default.png";[[:space:]]*$/) {
                    print "            var icon_fallback = \"this.onerror=null;this.src='\''/luci-static/nradio/images/icon/app_default.png'\'';this.className += '\'' nr_app_default_icon'\'';\";"
                }
            }
        ' "$TPL" > "$tmp_icon"
        cp "$tmp_icon" "$TPL"
    fi

    if ! grep -q 'onerror="{{icon_fallback}}"' "$TPL" 2>/dev/null; then
        awk -v tag="${SCRIPT_RELEASE_DATE}-${SCRIPT_VERSION}" '
            {
                gsub(/<img class="app_icon_img" src="\/luci-static\/nradio\/images\/icon\/\{\{icon\}\}\?v=[^"]+">/, "<img class=\"app_icon_img\" src=\"/luci-static/nradio/images/icon/{{icon}}?v=" tag "\" onerror=\"{{icon_fallback}}\">")
                gsub(/<img class="app_icon_img" src="\/luci-static\/nradio\/images\/icon\/\{\{icon\}\}">/, "<img class=\"app_icon_img\" src=\"/luci-static/nradio/images/icon/{{icon}}?v=" tag "\" onerror=\"{{icon_fallback}}\">")
                print
            }
        ' "$TPL" > "$tmp_icon"
        cp "$tmp_icon" "$TPL"
    fi

    if ! grep -q 'des_class: des_class' "$TPL" 2>/dev/null; then
        awk '
            {
                print
                if ($0 ~ /^[[:space:]]*var des_info = "&nbsp;";[[:space:]]*$/)
                    print "            var des_class = \"app_des_empty\";"
                else if ($0 ~ /^[[:space:]]*des_info[[:space:]]*=[[:space:]]*db\.des;[[:space:]]*$/)
                    print "                des_class = \"\";"
            }
        ' "$TPL" > "$tmp_desc"
        cp "$tmp_desc" "$TPL"

        awk '
            {
                gsub(/<div class="app_des" title="\{\{des\}\}">/, "<div class=\"app_des {{des_class}}\" title=\"{{des}}\">")
                print
            }
        ' "$TPL" > "$tmp_desc"
        cp "$tmp_desc" "$TPL"
    fi

    awk '
        {
            if ($0 ~ /^[[:space:]]*if\(db\.des && db\.des\.length\)[[:space:]]*$/) {
                print "            if(db.des && db.des.length){"
                if ((getline line1) > 0) {
                    if (line1 ~ /^[[:space:]]*des_info[[:space:]]*=[[:space:]]*db\.des;[[:space:]]*$/)
                        print "                des_info=db.des;"
                    else
                        print line1
                }
                if ((getline line2) > 0) {
                    if (line2 ~ /^[[:space:]]*des_class[[:space:]]*=[[:space:]]*"";[[:space:]]*$/) {
                        print "                des_class = \"\";"
                        print "            }"
                    }
                    else {
                        print "                des_class = \"\";"
                        print "            }"
                        print line2
                    }
                }
                next
            }
            print
        }
    ' "$TPL" > "$tmp_desc"
    cp "$tmp_desc" "$TPL"

    if grep -q 'icon_fallback: icon_fallback' "$TPL" 2>/dev/null && grep -q 'des_class: des_class' "$TPL" 2>/dev/null; then
        :
    else
        awk '
            {
                print
                if ($0 ~ /^[[:space:]]*icon: icon_name,$/) {
                    prefix = substr($0, 1, index($0, "icon:") - 1)
                    print prefix "icon_fallback: icon_fallback,"
                    print prefix "des_class: des_class,"
                }
            }
        ' "$TPL" > "$tmp_compose"
        cp "$tmp_compose" "$TPL"
    fi

    if ! grep -q 'build_app_status_panel_from_data' "$TPL" 2>/dev/null; then
        awk -v js_file="$status_js_file" '
            /^    var loading_htm = / && !inserted {
                while ((getline extra < js_file) > 0) print extra
                close(js_file)
                inserted = 1
            }
            { print }
        ' "$TPL" > "$tmp_panel"
        cp "$tmp_panel" "$TPL"
    fi

    if ! grep -q 'function build_app_empty_state' "$TPL" 2>/dev/null; then
        awk -v js_file="$empty_js_file" '
            /^    function build_app_status_panel\(/ && !inserted {
                while ((getline extra < js_file) > 0) print extra
                close(js_file)
                print ""
                inserted = 1
            }
            /^    var loading_htm = / && !inserted {
                while ((getline extra < js_file) > 0) print extra
                close(js_file)
                print ""
                inserted = 1
            }
            { print }
        ' "$TPL" > "$tmp_panel"
        cp "$tmp_panel" "$TPL"
    fi

    if ! grep -q 'var status_panel = build_app_status_panel_from_data(data);' "$TPL" 2>/dev/null; then
        awk '
            {
                if ($0 ~ /\$\("#app_top_menu"\)\.html\(top_menu_ht\);/) {
                    print
                    print "        var status_panel = build_app_status_panel_from_data(data);"
                    print "        if(!htm_installed)"
                    print "            htm_installed = build_app_empty_state(\"暂无已安装应用\", \"当前分类没有可显示的已安装应用，可切换到所有应用查看。\");"
                    print "        if(!htm)"
                    print "            htm = build_app_empty_state(\"暂无应用\", \"应用商店当前没有返回应用列表。\");"
                    next
                }
                if ($0 ~ /\$\("\.app_all"\)\.html\(htm\);/) {
                    print "        $(\".app_all\").html(htm + status_panel);"
                    next
                }
                if ($0 ~ /\$\("\.app_installed"\)\.html\(htm_installed\);/) {
                    print "        $(\".app_installed\").html(htm_installed + status_panel);"
                    print "        if(APP_STATUS_LAST)"
                    print "            update_app_status_panel(APP_STATUS_LAST);"
                    next
                }
                print
            }
        ' "$TPL" > "$tmp_panel"
        cp "$tmp_panel" "$TPL"
    fi

    if ! grep -q '当前分类没有可显示的已安装应用' "$TPL" 2>/dev/null; then
        awk '
            {
                if ($0 ~ /var status_panel = build_app_status_panel_from_data\(data\);/ || $0 ~ /var status_panel = build_app_status_panel\(installed_count, open_count, all_count\);/) {
                    print "        if(!htm_installed)"
                    print "            htm_installed = build_app_empty_state(\"暂无已安装应用\", \"当前分类没有可显示的已安装应用，可切换到所有应用查看。\");"
                    print "        if(!htm)"
                    print "            htm = build_app_empty_state(\"暂无应用\", \"应用商店当前没有返回应用列表。\");"
                    next
                }
                print
            }
        ' "$TPL" > "$tmp_panel"
        cp "$tmp_panel" "$TPL"
    fi

    if ! grep -q 'window.setInterval(get_system_status, 5000)' "$TPL" 2>/dev/null; then
        awk '
            {
                print
                if ($0 ~ /^[[:space:]]*get_memory\(\);[[:space:]]*$/)
                    print "        get_system_status();"
                if ($0 ~ /^[[:space:]]*window\.setInterval\(get_memory, 4000\);[[:space:]]*$/)
                    print "        window.setInterval(get_system_status, 5000);"
            }
        ' "$TPL" > "$tmp_ready"
        cp "$tmp_ready" "$TPL"
    fi

    verify_template_marker 'NRadio appcenter card polish: visual-only layer' '应用商店卡片美化 CSS'
    verify_template_marker 'NRadio appcenter card polish V2.0.3 full repair layer' '应用商店 V2.0.3 修复美化 CSS'
    verify_template_marker '<div class="app_meta_row"' '应用商店卡片状态徽标'
    verify_template_marker 'status_label: db.status_label' '应用商店卡片状态标签数据'
    verify_template_marker 'app_open_badge app_open_1' '应用商店后台状态徽标'
    verify_template_marker 'nr_app_default_icon' '应用商店破图图标兜底'
    verify_template_marker 'var icon_fallback = ' '应用商店破图兜底变量'
    verify_template_marker 'onerror="{{icon_fallback}}"' '应用商店破图兜底挂载'
    verify_template_marker 'des_class: des_class' '应用商店空描述隐藏'
    verify_template_marker 'build_app_status_panel_from_data' '应用商店右侧系统状态面板'
    verify_template_marker 'var status_panel = build_app_status_panel_from_data(data);' '应用商店右侧系统状态面板挂载'
    verify_template_marker 'function build_app_empty_state' '应用商店空列表提示'
    verify_template_marker '当前分类没有可显示的已安装应用' '应用商店已安装空列表提示文案'
    verify_template_marker 'window.setInterval(get_system_status, 5000)' '应用商店系统状态刷新定时器'
    if grep -q 'show_appcenter_all_view' "$TPL" 2>/dev/null; then
        die "appcenter template verify failed: unexpected auto switch to all apps"
    fi
    if grep -q '已自动切换到所有应用' "$TPL" 2>/dev/null; then
        die "appcenter template verify failed: old empty-state auto switch text remains"
    fi
}

install_appcenter_polish() {
    log_stage 1 5 "检查 NRadio 应用商店模板"
    require_nradio_oem_appcenter
    verify_file_exists "$TPL" "NRadio 应用商店模板"

    log_stage 2 5 "写入应用商店模板与只读状态接口"
    write_plugin_uninstall_assets
    patch_common_template
    patch_appcenter_status_controller
    patch_appcenter_card_polish

    log_stage 3 5 "统一刷新插件图标"
    install_unified_appcenter_icons || die "应用商店统一图标写入失败"

    log_stage 4 5 "刷新 LuCI 与应用商店缓存"
    refresh_luci_appcenter
    /etc/init.d/uhttpd reload >/dev/null 2>&1 || true

    log_stage 5 5 "校验应用商店页面"
    verify_luci_route "nradioadv/system/appcenter" "应用商店美化"

    log "应用商店美化完成"
    log "范围: 应用卡片、状态徽标、右侧系统状态面板、按钮、图标与打开弹窗视觉层"
    log "说明: 不修改插件下载链、安装链和卸载链；仅补应用商店模板与只读系统状态接口"
}

refresh_luci_appcenter() {
    rm -f /tmp/luci-indexcache /tmp/infocd/cache/appcenter 2>/dev/null || true
    rm -f /tmp/luci-modulecache/* 2>/dev/null || true
    /etc/init.d/infocd restart >/dev/null 2>&1 || true
    /etc/init.d/appcenter restart >/dev/null 2>&1 || true
    sleep 2
}

quiesce_service() {
    init_script="$1"
    [ -f "$init_script" ] || return 0
    "$init_script" stop >/dev/null 2>&1 || true
    "$init_script" disable >/dev/null 2>&1 || true
}

verify_luci_route() {
    route="$1"
    expect="$2"
    out="$WORKDIR/verify.$(echo "$route" | tr '/.' '__').html"
    code="$(curl -m 8 -s -o "$out" -w '%{http_code}' "http://127.0.0.1/cgi-bin/luci/$route" 2>/dev/null || true)"

    case "$code" in
        200|302|403)
            ;;
        *)
            die "$expect verify failed: route $route returned HTTP ${code:-000}"
            ;;
    esac

    if grep -Eq 'Failed to execute|error500|Runtime error|not found!|has no parent node|No page is registered at' "$out" 2>/dev/null; then
        die "$expect verify failed: route $route returned LuCI error page"
    fi
}

verify_file_exists() {
    path="$1"
    label="$2"
    [ -f "$path" ] || die "$label verify failed: missing $path"
}

verify_template_marker() {
    pattern="$1"
    label="$2"
    grep -Fq -- "$pattern" "$TPL" 2>/dev/null || die "appcenter template verify failed: missing $label"
}

get_installed_package_version() {
    pkg_name="$1"
    opkg status "$pkg_name" 2>/dev/null | awk -F': ' '/^Version: /{print $2; exit}'
}

delete_iptables_rule_loop() {
    table_name="$1"
    chain_name="$2"
    shift 2

    command -v iptables >/dev/null 2>&1 || return 0
    while iptables -t "$table_name" -C "$chain_name" "$@" >/dev/null 2>&1; do
        iptables -t "$table_name" -D "$chain_name" "$@" >/dev/null 2>&1 || break
    done
}

cleanup_openvpn_target_policy_rules() {
    target="$1"
    lan_if="$2"
    pri=60
    while [ "$pri" -le 119 ]; do
        ip rule del to "$target" lookup main priority "$pri" 2>/dev/null || true
        ip rule del iif "$lan_if" to "$target" lookup main priority "$pri" 2>/dev/null || true
        pri=$((pri + 1))
    done
}

cleanup_openvpn_target_runtime_rules() {
    target="$1"
    lan_if="$2"
    tun_if="$3"
    lan_subnet="$4"
    nat_flag="$5"
    forward_flag="$6"

    [ -n "$target" ] || return 0
    cleanup_openvpn_target_policy_rules "$target" "$lan_if"
    ip route del "$target" 2>/dev/null || true

    case "$nat_flag" in
        1|y|Y|yes|YES|true|TRUE)
            [ -n "$lan_subnet" ] && [ -n "$tun_if" ] && delete_iptables_rule_loop nat POSTROUTING -s "$lan_subnet" -d "$target" -o "$tun_if" -j MASQUERADE
            ;;
    esac

    case "$forward_flag" in
        1|y|Y|yes|YES|true|TRUE)
            [ -n "$lan_if" ] && [ -n "$tun_if" ] && delete_iptables_rule_loop filter FORWARD -d "$target" -i "$lan_if" -o "$tun_if" -j ACCEPT
            [ -n "$lan_if" ] && [ -n "$tun_if" ] && [ -n "$lan_subnet" ] && delete_iptables_rule_loop filter FORWARD -s "$lan_subnet" -d "$target" -i "$lan_if" -o "$tun_if" -j ACCEPT
            [ -n "$lan_if" ] && [ -n "$tun_if" ] && [ -n "$lan_subnet" ] && delete_iptables_rule_loop filter FORWARD -s "$target" -d "$lan_subnet" -i "$tun_if" -o "$lan_if" -j ACCEPT
            ;;
    esac
}

cleanup_saved_openvpn_runtime_state() {
    [ -n "${OLD_ROUTE_TUN_IF:-}" ] || return 0

    old_lan_if="${OLD_ROUTE_LAN_IF:-br-lan}"
    old_tun_if="${OLD_ROUTE_TUN_IF:-}"
    old_lan_subnet="${OLD_ROUTE_LAN_SUBNET:-}"
    old_route_nat="${OLD_ROUTE_NAT:-n}"
    old_route_forward="${OLD_ROUTE_FORWARD:-n}"

    if [ -s "$ROUTE_MAP_LIST_FILE" ]; then
        while IFS='|' read -r old_peer_target old_peer_gw old_peer_kind_saved; do
            [ -n "$old_peer_target" ] || continue
            [ -n "$old_peer_kind_saved" ] || old_peer_kind_saved="$(infer_map_target_kind "$old_peer_target")"
            if [ "$old_peer_kind_saved" = 'host' ]; then
                old_peer_target="${old_peer_target%/*}"
                ip neigh del proxy "$old_peer_target" dev "$old_lan_if" 2>/dev/null || true
            fi
            cleanup_openvpn_target_runtime_rules "$old_peer_target" "$old_lan_if" "$old_tun_if" "$old_lan_subnet" "$old_route_nat" "$old_route_forward"
        done < "$ROUTE_MAP_LIST_FILE"
    fi

    old_enhanced_pri=196
    if [ -s "$ROUTE_LIST_FILE" ]; then
        while IFS='|' read -r old_subnet old_gw; do
            [ -n "$old_subnet" ] || continue
            cleanup_openvpn_target_runtime_rules "$old_subnet" "$old_lan_if" "$old_tun_if" "$old_lan_subnet" "$old_route_nat" "$old_route_forward"
            case "${OLD_ROUTE_ENHANCED:-n}" in
                1|y|Y|yes|YES|true|TRUE)
                    [ -n "$old_lan_subnet" ] && ip rule del from "$old_lan_subnet" to "$old_subnet" lookup main priority "$old_enhanced_pri" 2>/dev/null || true
                    old_enhanced_pri=$((old_enhanced_pri + 1))
                    ;;
            esac
        done < "$ROUTE_LIST_FILE"
    fi

    case "${OLD_ROUTE_MAP_ENABLE:-n}" in
        1|y|Y|yes|YES|true|TRUE)
            case "${OLD_ROUTE_MAP_KIND:-}" in
                host)
                    if [ -n "${OLD_ROUTE_MAP_HOST:-}" ]; then
                        old_lan_host_ip="${OLD_ROUTE_LAN_HOST_IP:-}"
                        [ -n "$old_lan_host_ip" ] || old_lan_host_ip="$(get_interface_subnet "$old_lan_if" 2>/dev/null | cut -d/ -f1 || true)"
                        [ -n "$old_lan_host_ip" ] || old_lan_host_ip="$(uci -q get network.lan.ipaddr 2>/dev/null || true)"
                        old_lan_host_ip="$(normalize_ipv4_host "$old_lan_host_ip" 2>/dev/null || true)"
                        [ -n "$old_lan_host_ip" ] && delete_iptables_rule_loop nat PREROUTING -i "$old_tun_if" -d "${OLD_ROUTE_MAP_HOST}" -j DNAT --to-destination "$old_lan_host_ip"
                        [ -n "$old_lan_host_ip" ] && delete_iptables_rule_loop nat OUTPUT -d "${OLD_ROUTE_MAP_HOST}" -j DNAT --to-destination "$old_lan_host_ip"
                    fi
                    [ -n "${OLD_ROUTE_MAP_IP:-}" ] && ip addr del "${OLD_ROUTE_MAP_IP}" dev "$old_lan_if" 2>/dev/null || true
                    ;;
                subnet)
                    [ -n "${OLD_ROUTE_MAP_SUBNET:-}" ] && [ -n "$old_lan_subnet" ] && delete_iptables_rule_loop nat PREROUTING -i "$old_tun_if" -d "${OLD_ROUTE_MAP_SUBNET}" -j NETMAP --to "$old_lan_subnet"
                    [ -n "${OLD_ROUTE_MAP_SUBNET:-}" ] && [ -n "$old_lan_subnet" ] && delete_iptables_rule_loop nat OUTPUT -d "${OLD_ROUTE_MAP_SUBNET}" -j NETMAP --to "$old_lan_subnet"
                    ;;
            esac
            ;;
    esac
}

is_adguardhome_luci_ready() {
    current_adg_ver="$(get_installed_package_version luci-app-adguardhome 2>/dev/null || true)"
    [ "$current_adg_ver" = "$ADGUARDHOME_VERSION" ] || return 1

    for needed in \
        /usr/lib/lua/luci/controller/AdGuardHome.lua \
        /usr/lib/lua/luci/model/cbi/AdGuardHome/base.lua \
        /usr/lib/lua/luci/model/cbi/AdGuardHome/manual.lua \
        /usr/lib/lua/luci/model/cbi/AdGuardHome/log.lua \
        /usr/share/AdGuardHome/AdGuardHome_template.yaml; do
        [ -f "$needed" ] || return 1
    done

    return 0
}

print_openvpn_runtime_debug() {
    log "debug: openvpn service status"
    /etc/init.d/openvpn status 2>/dev/null || true
    log "debug: /tmp/openvpn-client.log"
    sed -n '1,120p' /tmp/openvpn-client.log 2>/dev/null || true
    log "debug: /tmp/openvpn-runtime-fix.log"
    sed -n '1,120p' /tmp/openvpn-runtime-fix.log 2>/dev/null || true
    log "debug: /var/run/openvpn.custom_config.status"
    sed -n '1,120p' /var/run/openvpn.custom_config.status 2>/dev/null || true
    log "debug: recent logread openvpn"
    logread 2>/dev/null | grep -i openvpn | tail -40 || true
}

print_openvpn_runtime_hints() {
    cert_auth="$1"
    tls_mode="$2"
    proto="$3"
    runtime_log="$4"

    case "$runtime_log" in
        *VERIFY\ KU\ ERROR*|*certificate\ verify\ failed*)
            log "hint: server certificate verification failed; rerun option 9 and choose server verify mode 1 (compat mode)"
            return 0
            ;;
        *'/dev/net/tun'*|*'Cannot open TUN/TAP dev'*|*'TUNSETIFF'*|*'No such device'*)
            log "hint: tun driver is missing or unusable; run option 8 to install/fix tun support first"
            return 0
            ;;
        *liblzo2.so.2*|*lzo1x_*|*__lzo_init_v2*)
            log "hint: OpenVPN runtime dependency liblzo2 is missing or broken; run option 8 again after fixing package installation"
            return 0
            ;;
    esac

    log "hint: check whether your server really requires client certificate/private key"
    [ "$cert_auth" = '1' ] && log "hint: if your server only uses username/password, rerun option 9 and choose n for client certificate/private key"
    [ "$tls_mode" = '0' ] && log "hint: if your server uses tls-auth or tls-crypt, rerun option 9 and choose the correct mode"
    case "$proto" in
        udp6|tcp6-client)
            log "hint: if your server or network does not support IPv6 transport well, rerun option 9 and choose ipv4"
            ;;
    esac
}

openvpn_selfcheck_bool() {
    case "$1" in
        1|y|Y|yes|YES|true|TRUE) printf '%s\n' 'yes' ;;
        *) printf '%s\n' 'no' ;;
    esac
}

openvpn_route_via_dev_exists() {
    route_target="$1"
    route_gw="$2"
    route_dev="$3"
    route_target_alt=""
    case "$route_target" in
        */32) route_target_alt="${route_target%/*}" ;;
        */*) ;;
        *) route_target_alt="${route_target}/32" ;;
    esac

    ip route 2>/dev/null | awk -v target="$route_target" -v alt="$route_target_alt" -v gw="$route_gw" -v dev="$route_dev" '
        $2 == "via" && $3 == gw && $4 == "dev" && $5 == dev && ($1 == target || (alt != "" && $1 == alt)) { found = 1 }
        END { exit found ? 0 : 1 }
    '
}

openvpn_ip_rule_to_exists() {
    rule_target="$1"
    rule_target_alt=""
    case "$rule_target" in
        */32) rule_target_alt="${rule_target%/*}" ;;
        */*) ;;
        *) rule_target_alt="${rule_target}/32" ;;
    esac

    ip rule 2>/dev/null | awk -v target="$rule_target" -v alt="$rule_target_alt" '
        {
            has_to = 0
            has_lookup = 0
            for (i = 1; i <= NF; i++) {
                if ($i == "to" && ($(i + 1) == target || (alt != "" && $(i + 1) == alt)))
                    has_to = 1
                if ($i == "lookup" && $(i + 1) == "main")
                    has_lookup = 1
            }
            if (has_to && has_lookup)
                found = 1
        }
        END { exit found ? 0 : 1 }
    '
}

openvpn_ip_rule_iif_to_exists() {
    rule_target="$1"
    rule_iface="$2"
    rule_target_alt=""
    case "$rule_target" in
        */32) rule_target_alt="${rule_target%/*}" ;;
        */*) ;;
        *) rule_target_alt="${rule_target}/32" ;;
    esac

    ip rule 2>/dev/null | awk -v target="$rule_target" -v alt="$rule_target_alt" -v iface="$rule_iface" '
        {
            has_iif = 0
            has_to = 0
            has_lookup = 0
            for (i = 1; i <= NF; i++) {
                if ($i == "iif" && $(i + 1) == iface)
                    has_iif = 1
                if ($i == "to" && ($(i + 1) == target || (alt != "" && $(i + 1) == alt)))
                    has_to = 1
                if ($i == "lookup" && $(i + 1) == "main")
                    has_lookup = 1
            }
            if (has_iif && has_to && has_lookup)
                found = 1
        }
        END { exit found ? 0 : 1 }
    '
}

selfcheck_print_header() {
    log "$1"
    log "------"
}

selfcheck_print_file_state() {
    label="$1"
    path="$2"
    if [ -s "$path" ]; then
        size="$(wc -c < "$path" 2>/dev/null | tr -d ' ' || true)"
        [ -n "$size" ] || size='?'
        log "file:     $label = present ($path, ${size} bytes)"
    elif [ -e "$path" ]; then
        log "file:     $label = present but empty ($path)"
    else
        log "file:     $label = missing ($path)"
    fi
}

openvpn_selfcheck_print_file_state() {
    label="$1"
    path="$2"

    case "$label" in
        "runtime state")
            if [ ! -e "$path" ] && [ "${OVPN_SELFCHECK_RUNTIME_SOURCE:-saved}" = 'profile' ]; then
                log "file:     $label = synthesized from current profile ($path)"
                return 0
            fi
            ;;
        "route state")
            if [ ! -e "$path" ] && [ "${OVPN_SELFCHECK_ROUTE_STATE_SOURCE:-saved}" = 'hotplug' ]; then
                log "file:     $label = synthesized from route hotplug ($path)"
                return 0
            fi
            ;;
        "saved route list")
            if [ ! -e "$path" ] && [ "${OVPN_SELFCHECK_ROUTE_LIST_SOURCE:-saved}" = 'runtime' ]; then
                log "file:     $label = synthesized from active tun routes ($path)"
                return 0
            fi
            ;;
        "saved mapped peers")
            if [ ! -e "$path" ] && [ "${OVPN_SELFCHECK_MAP_LIST_SOURCE:-saved}" = 'runtime' ]; then
                log "file:     $label = synthesized from proxy neighbors ($path)"
                return 0
            fi
            ;;
    esac

    selfcheck_print_file_state "$label" "$path"
}

selfcheck_print_service_state() {
    label="$1"
    init_script="$2"

    if [ ! -x "$init_script" ]; then
        log "service:  $label missing ($init_script)"
        return 0
    fi

    if "$init_script" enabled >/dev/null 2>&1; then
        service_enabled='1'
    else
        service_enabled='0'
    fi
    service_status="$( ( "$init_script" status 2>/dev/null || true ) | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' )"
    [ -n "$service_status" ] || service_status='stopped'
    log "service:  $label enabled=$(openvpn_selfcheck_bool "$service_enabled") status=$service_status"
}

selfcheck_luci_route_ok() {
    route="$1"
    out="$WORKDIR/selfcheck.$(printf '%s' "$route" | tr '/.' '__').probe"
    code="$(curl -m 8 -s -o "$out" -w '%{http_code}' "http://127.0.0.1/cgi-bin/luci/$route" 2>/dev/null || true)"

    case "$code" in
        200|302|403)
            if grep -Eq 'Failed to execute|error500|Runtime error|not found!|has no parent node|No page is registered at' "$out" 2>/dev/null; then
                return 1
            fi
            return 0
            ;;
    esac

    return 1
}

selfcheck_print_luci_route_state() {
    label="$1"
    route="$2"
    out="$WORKDIR/selfcheck.$(printf '%s' "$route" | tr '/.' '__').html"
    code="$(curl -m 8 -s -o "$out" -w '%{http_code}' "http://127.0.0.1/cgi-bin/luci/$route" 2>/dev/null || true)"

    if selfcheck_luci_route_ok "$route"; then
        log "路由:    $label = 正常 (HTTP ${code:-000})"
        return 0
    fi

    case "$code" in
        200|302|403)
            log "路由:    $label = LuCI 错误页 (HTTP $code)"
            ;;
        *)
            log "路由:    $label = 缺失 (HTTP ${code:-000})"
            ;;
    esac
}

selfcheck_appcenter_route_matches() {
    plugin_name="$1"
    expect_route="$2"
    sec_list="$(uci show appcenter 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            "appcenter.@package_list"*".name='${plugin_name}'"|"appcenter.cfg"*".name='${plugin_name}'")
                sec="${line#appcenter.}"
                sec="${sec%%.*}"
                printf '%s\n' "$sec"
                ;;
        esac
    done)"

    [ -n "$sec_list" ] || return 1

    for sec in $sec_list; do
        [ -n "$sec" ] || continue
        actual_route="$(uci -q get appcenter.$sec.luci_module_route 2>/dev/null || true)"
        [ "$actual_route" = "$expect_route" ] && return 0
        actual_controller="$(uci -q get appcenter.$sec.luci_module_file 2>/dev/null || true)"
        case "$plugin_name" in
            luci-app-openclash) [ "$actual_controller" = "/usr/lib/lua/luci/controller/openclash.lua" ] && return 0 ;;
            luci-app-adguardhome) [ "$actual_controller" = "/usr/lib/lua/luci/controller/AdGuardHome.lua" ] && return 0 ;;
            OpenVPN) [ "$actual_controller" = "/usr/lib/lua/luci/controller/nradio_adv/openvpn_full.lua" ] && return 0 ;;
        esac
    done
    return 1
}

selfcheck_print_appcenter_route_state() {
    label="$1"
    plugin_name="$2"
    expect_route="$3"

    sec="$(find_uci_section package_list "$plugin_name")"
    if [ -z "$sec" ]; then
        log "应用商店: $label = 缺失"
        return 0
    fi

    actual_route="$(uci -q get appcenter.$sec.luci_module_route 2>/dev/null || true)"
    if [ "$actual_route" = "$expect_route" ]; then
        log "应用商店: $label = 正常 ($actual_route)"
    else
        actual_controller="$(uci -q get appcenter.$sec.luci_module_file 2>/dev/null || true)"
        case "$plugin_name" in
            luci-app-openclash)
                [ "$actual_controller" = "/usr/lib/lua/luci/controller/openclash.lua" ] && {
                    log "应用商店: $label = 正常 (controller fallback)"
                    return 0
                }
                ;;
            luci-app-adguardhome)
                [ "$actual_controller" = "/usr/lib/lua/luci/controller/AdGuardHome.lua" ] && {
                    log "应用商店: $label = 正常 (controller fallback)"
                    return 0
                }
                ;;
            OpenVPN)
                [ "$actual_controller" = "/usr/lib/lua/luci/controller/nradio_adv/openvpn_full.lua" ] && {
                    log "应用商店: $label = 正常 (controller fallback)"
                    return 0
                }
                ;;
        esac
        log "应用商店: $label = 不匹配 (${actual_route:-缺失})"
    fi
}

selfcheck_print_process_state() {
    label="$1"
    pattern="$2"
    ps_text="$(pgrep -af "$pattern" 2>/dev/null || true)"
    if [ -n "$ps_text" ]; then
        first_line="$(printf '%s\n' "$ps_text" | sed -n '1p')"
        log "runtime:  $label process present ($first_line)"
    else
        log "runtime:  $label process missing"
    fi
}

selfcheck_finalize_summary() {
    failures="$1"
    warnings="$2"

    NRADIO_LAST_SELFCHECK_ERRORS="$failures"
    NRADIO_LAST_SELFCHECK_WARNINGS="$warnings"

    if [ "$failures" -gt 0 ]; then
        NRADIO_LAST_SELFCHECK_STATUS='FAIL'
        log "summary:  FAIL (errors=$failures warnings=$warnings)"
    elif [ "$warnings" -gt 0 ]; then
        NRADIO_LAST_SELFCHECK_STATUS='WARN'
        log "summary:  WARN (errors=0 warnings=$warnings)"
    else
        NRADIO_LAST_SELFCHECK_STATUS='PASS'
        log "summary:  PASS"
    fi
}

set_last_selfcheck_status() {
    status="$1"
    errors="${2:-0}"
    warnings="${3:-0}"

    NRADIO_LAST_SELFCHECK_ERRORS="$errors"
    NRADIO_LAST_SELFCHECK_WARNINGS="$warnings"
    case "$status" in
        FAIL|PASS|WARN)
            NRADIO_LAST_SELFCHECK_STATUS="$status"
            ;;
        *)
            NRADIO_LAST_SELFCHECK_STATUS='WARN'
            ;;
    esac
}

record_unified_selfcheck_summary() {
    label="$1"
    case "${NRADIO_LAST_SELFCHECK_STATUS:-WARN}" in
        FAIL)
            NRADIO_UNIFIED_FAILS=$((NRADIO_UNIFIED_FAILS + 1))
            ;;
        PASS)
            NRADIO_UNIFIED_PASSES=$((NRADIO_UNIFIED_PASSES + 1))
            ;;
        *)
            NRADIO_UNIFIED_WARNS=$((NRADIO_UNIFIED_WARNS + 1))
            NRADIO_LAST_SELFCHECK_STATUS='WARN'
            ;;
    esac
    log "overall:  $label = ${NRADIO_LAST_SELFCHECK_STATUS}"
}

run_openclash_cdn_selfcheck() {
    optimize_openclash_cdn_order
    if [ "${OPENCLASH_CDN_RANKED:-0}" = '1' ] && [ -n "${OPENCLASH_MIRRORS:-}" ]; then
        set_last_selfcheck_status PASS 0 0
    else
        log "CDN:      $OPENCLASH_DISPLAY_NAME = 未得出排序"
        set_last_selfcheck_status WARN 0 1
    fi
}

run_adguardhome_cdn_selfcheck() {
    optimize_adguardhome_cdn_order
    if [ "${ADGUARDHOME_CDN_RANKED:-0}" = '1' ] && [ -n "${ADGUARDHOME_IPK_URLS:-}" ]; then
        set_last_selfcheck_status PASS 0 0
    else
        log "CDN:      AdGuardHome = 未得出排序"
        set_last_selfcheck_status WARN 0 1
    fi
}

get_ttyd_bind_value() {
    opt_name="$1"
    value="$(uci -q show ttyd 2>/dev/null | awk -F"='" -v opt="$opt_name" '
        $1 ~ ("\\.(" opt ")$") {
            val=$2
            sub(/\047$/, "", val)
            print val
            exit
        }
    ' || true)"
    printf '%s\n' "$value"
}

run_openclash_selfcheck() {
    require_root
    oc_selfcheck_failures=0
    oc_selfcheck_warnings=0
    selfcheck_print_header "$OPENCLASH_DISPLAY_NAME 自检"

    selfcheck_print_service_state "openclash" "/etc/init.d/openclash"
    selfcheck_print_file_state "controller" "/usr/lib/lua/luci/controller/openclash.lua"
    selfcheck_print_file_state "uci config" "/etc/config/openclash"
    selfcheck_print_file_state "core version" "/etc/openclash/core_version"
    selfcheck_print_file_state "smart core clash" "/etc/openclash/core/clash"
    selfcheck_print_file_state "smart core clash_meta" "/etc/openclash/core/clash_meta"
    selfcheck_print_file_state "ASN.mmdb" "/etc/openclash/ASN.mmdb"
    selfcheck_print_appcenter_route_state "$OPENCLASH_DISPLAY_NAME" "luci-app-openclash" "admin/services/openclash"
    selfcheck_print_luci_route_state "$OPENCLASH_DISPLAY_NAME overview" "admin/services/openclash"
    selfcheck_print_luci_route_state "$OPENCLASH_DISPLAY_NAME settings" "admin/services/openclash/settings"
    [ -x /etc/init.d/openclash ] || oc_selfcheck_failures=$((oc_selfcheck_failures + 1))
    if [ -x /etc/init.d/openclash ]; then
        openclash_enabled='0'
        /etc/init.d/openclash enabled >/dev/null 2>&1 && openclash_enabled='1'
        openclash_service_status="$( ( /etc/init.d/openclash status 2>/dev/null || true ) | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' )"
        openclash_running='0'
        case "$openclash_service_status" in
            *running*|1) openclash_running='1' ;;
            *) oc_selfcheck_warnings=$((oc_selfcheck_warnings + 1)) ;;
        esac
        if [ "$openclash_enabled" = '0' ]; then
            if [ "$openclash_running" = '1' ]; then
                log "备注:     $OPENCLASH_DISPLAY_NAME autostart disabled, but runtime is active"
            else
                oc_selfcheck_warnings=$((oc_selfcheck_warnings + 1))
            fi
        fi
    fi
    [ -f /usr/lib/lua/luci/controller/openclash.lua ] || oc_selfcheck_failures=$((oc_selfcheck_failures + 1))
    [ -f /etc/config/openclash ] || oc_selfcheck_failures=$((oc_selfcheck_failures + 1))
    [ -s /etc/openclash/core_version ] || oc_selfcheck_warnings=$((oc_selfcheck_warnings + 1))
    [ -x /etc/openclash/core/clash ] || oc_selfcheck_warnings=$((oc_selfcheck_warnings + 1))
    [ -x /etc/openclash/core/clash_meta ] || oc_selfcheck_warnings=$((oc_selfcheck_warnings + 1))
    [ -f /etc/openclash/ASN.mmdb ] || oc_selfcheck_warnings=$((oc_selfcheck_warnings + 1))
    selfcheck_appcenter_route_matches "luci-app-openclash" "admin/services/openclash" || oc_selfcheck_failures=$((oc_selfcheck_failures + 1))
    selfcheck_luci_route_ok "admin/services/openclash" || oc_selfcheck_failures=$((oc_selfcheck_failures + 1))
    selfcheck_luci_route_ok "admin/services/openclash/settings" || oc_selfcheck_failures=$((oc_selfcheck_failures + 1))

    if [ -s /etc/openclash/core_version ]; then
        core_version_text="$(tr '\n' ' ' < /etc/openclash/core_version 2>/dev/null | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' || true)"
        [ -n "$core_version_text" ] && log "核心:     $core_version_text"
    fi

    active_clash_ps="$(pgrep -af '/etc/openclash/|openclash_watchdog|/etc/openclash/core/clash' 2>/dev/null || true)"
    if [ -n "$active_clash_ps" ]; then
        active_clash_line="$(printf '%s\n' "$active_clash_ps" | sed -n '1p')"
        log "runtime:  $OPENCLASH_DISPLAY_NAME process present ($active_clash_line)"
    else
        log "runtime:  $OPENCLASH_DISPLAY_NAME process missing"
        oc_selfcheck_warnings=$((oc_selfcheck_warnings + 1))
    fi
    selfcheck_finalize_summary "$oc_selfcheck_failures" "$oc_selfcheck_warnings"
}

run_adguardhome_selfcheck() {
    require_root
    selfcheck_print_header "AdGuardHome 自检"

    adg_selfcheck_failures=0
    adg_selfcheck_warnings=0
    adg_binpath="$(uci -q get AdGuardHome.AdGuardHome.binpath 2>/dev/null || true)"
    [ -n "$adg_binpath" ] || adg_binpath="/usr/bin/AdGuardHome/AdGuardHome"
    adg_configpath="$(get_adguard_configpath)"
    adg_core_present='0'
    [ -x "$adg_binpath" ] && adg_core_present='1'

    selfcheck_print_service_state "AdGuardHome" "/etc/init.d/AdGuardHome"
    selfcheck_print_file_state "controller" "/usr/lib/lua/luci/controller/AdGuardHome.lua"
    selfcheck_print_file_state "base page" "/usr/lib/lua/luci/model/cbi/AdGuardHome/base.lua"
    selfcheck_print_file_state "manual page" "/usr/lib/lua/luci/model/cbi/AdGuardHome/manual.lua"
    selfcheck_print_file_state "log page" "/usr/lib/lua/luci/model/cbi/AdGuardHome/log.lua"
    selfcheck_print_file_state "wrapper page" "/usr/lib/lua/luci/view/AdGuardHome/oem_wrapper.htm"
    selfcheck_print_file_state "core binary" "$adg_binpath"
    selfcheck_print_file_state "config" "$adg_configpath"
    selfcheck_print_appcenter_route_state "AdGuardHome" "luci-app-adguardhome" "admin/services/AdGuardHome"
    selfcheck_print_luci_route_state "AdGuardHome overview" "admin/services/AdGuardHome"
    selfcheck_print_luci_route_state "AdGuardHome base" "admin/services/AdGuardHome/base"
    selfcheck_print_luci_route_state "AdGuardHome manual" "admin/services/AdGuardHome/manual"
    selfcheck_print_luci_route_state "AdGuardHome log" "admin/services/AdGuardHome/log"
    [ -x /etc/init.d/AdGuardHome ] || adg_selfcheck_failures=$((adg_selfcheck_failures + 1))
    if [ "$adg_core_present" = '1' ]; then
        if ! /etc/init.d/AdGuardHome enabled >/dev/null 2>&1; then
            adg_selfcheck_warnings=$((adg_selfcheck_warnings + 1))
        fi
        adg_service_status="$( ( /etc/init.d/AdGuardHome status 2>/dev/null || true ) | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' )"
        case "$adg_service_status" in
            *running*|1) ;;
            *) adg_selfcheck_failures=$((adg_selfcheck_failures + 1)) ;;
        esac
    else
        log "备注:     AdGuardHome 核心未安装，当前按 LuCI-only 状态检查"
        adg_selfcheck_warnings=$((adg_selfcheck_warnings + 1))
    fi
    for needed in \
        /usr/lib/lua/luci/controller/AdGuardHome.lua \
        /usr/lib/lua/luci/model/cbi/AdGuardHome/base.lua \
        /usr/lib/lua/luci/model/cbi/AdGuardHome/manual.lua \
        /usr/lib/lua/luci/model/cbi/AdGuardHome/log.lua \
        /usr/lib/lua/luci/view/AdGuardHome/oem_wrapper.htm; do
        [ -f "$needed" ] || adg_selfcheck_failures=$((adg_selfcheck_failures + 1))
    done
    selfcheck_appcenter_route_matches "luci-app-adguardhome" "admin/services/AdGuardHome" || adg_selfcheck_failures=$((adg_selfcheck_failures + 1))
    selfcheck_luci_route_ok "admin/services/AdGuardHome" || adg_selfcheck_failures=$((adg_selfcheck_failures + 1))
    selfcheck_luci_route_ok "admin/services/AdGuardHome/base" || adg_selfcheck_failures=$((adg_selfcheck_failures + 1))
    selfcheck_luci_route_ok "admin/services/AdGuardHome/manual" || adg_selfcheck_failures=$((adg_selfcheck_failures + 1))
    selfcheck_luci_route_ok "admin/services/AdGuardHome/log" || adg_selfcheck_failures=$((adg_selfcheck_failures + 1))

    if [ "$adg_core_present" = '1' ]; then
        adg_version="$("$adg_binpath" --version 2>/dev/null | sed -n '1p' | tr -d '\r' || true)"
        [ -n "$adg_version" ] && log "核心:     $adg_version"
    else
        log "核心:     missing (LuCI-only install)"
    fi

    if [ -s "$adg_configpath" ]; then
        if is_adguard_placeholder_config "$adg_configpath"; then
            log "config:   placeholder config detected"
            adg_selfcheck_warnings=$((adg_selfcheck_warnings + 1))
        else
            log "config:   initialized config detected"
        fi
    else
        log "config:   config missing, first-run setup pending"
        adg_selfcheck_warnings=$((adg_selfcheck_warnings + 1))
    fi

    if [ "$adg_core_present" = '1' ]; then
        adg_ps="$(pgrep -af 'AdGuardHome' 2>/dev/null || true)"
        selfcheck_print_process_state "AdGuardHome" 'AdGuardHome'
        [ -n "$adg_ps" ] || adg_selfcheck_failures=$((adg_selfcheck_failures + 1))
    else
        log "runtime:  AdGuardHome core not installed"
    fi

    selfcheck_finalize_summary "$adg_selfcheck_failures" "$adg_selfcheck_warnings"
}

run_ttyd_webssh_selfcheck() {
    require_root
    selfcheck_print_header "Web SSH / ttyd 自检"

    ttyd_selfcheck_failures=0
    ttyd_selfcheck_warnings=0
    ttyd_port="$(get_ttyd_bind_value "port")"
    [ -n "$ttyd_port" ] || ttyd_port='7681'
    ttyd_iface="$(get_ttyd_bind_value "interface")"
    [ -n "$ttyd_iface" ] || ttyd_iface='all'

    selfcheck_print_service_state "ttyd" "/etc/init.d/ttyd"
    selfcheck_print_file_state "ttyd binary" "/usr/bin/ttyd"
    selfcheck_print_file_state "ttyd init" "/etc/init.d/ttyd"
    selfcheck_print_file_state "ttyd config" "/etc/config/ttyd"
    selfcheck_print_file_state "ttyd controller" "/usr/lib/lua/luci/controller/ttyd.lua"
    selfcheck_print_file_state "ttyd overview" "/usr/lib/lua/luci/view/ttyd/overview.htm"
    selfcheck_print_file_state "Web SSH controller" "/usr/lib/lua/luci/controller/nradio_adv/webssh.lua"
    selfcheck_print_file_state "Web SSH view" "/usr/lib/lua/luci/view/nradio_adv/webssh.htm"
    selfcheck_print_file_state "Web SSH icon" "/www/luci-static/nradio/images/icon/webssh.svg"
    selfcheck_print_luci_route_state "ttyd overview" "admin/system/ttyd/overview"
    selfcheck_print_luci_route_state "Web SSH wrapper" "nradioadv/system/webssh"
    [ -x /etc/init.d/ttyd ] || ttyd_selfcheck_failures=$((ttyd_selfcheck_failures + 1))
    if ! /etc/init.d/ttyd enabled >/dev/null 2>&1; then
        ttyd_selfcheck_warnings=$((ttyd_selfcheck_warnings + 1))
    fi
    ttyd_service_status="$( ( /etc/init.d/ttyd status 2>/dev/null || true ) | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' )"
    case "$ttyd_service_status" in
        *running*|1) ;;
        *) ttyd_selfcheck_failures=$((ttyd_selfcheck_failures + 1)) ;;
    esac
    for needed in \
        /usr/bin/ttyd \
        /etc/init.d/ttyd \
        /etc/config/ttyd \
        /usr/lib/lua/luci/controller/ttyd.lua \
        /usr/lib/lua/luci/view/ttyd/overview.htm \
        /usr/lib/lua/luci/controller/nradio_adv/webssh.lua \
        /usr/lib/lua/luci/view/nradio_adv/webssh.htm; do
        [ -f "$needed" ] || ttyd_selfcheck_failures=$((ttyd_selfcheck_failures + 1))
    done
    selfcheck_luci_route_ok "admin/system/ttyd/overview" || ttyd_selfcheck_failures=$((ttyd_selfcheck_failures + 1))
    selfcheck_luci_route_ok "nradioadv/system/webssh" || ttyd_selfcheck_failures=$((ttyd_selfcheck_failures + 1))

    if grep -q 'name:"Web SSH"' "$TPL" 2>/dev/null && grep -q 'nradioadv/system/webssh' "$TPL" 2>/dev/null; then
        log "应用商店: Web SSH 快捷入口 = 正常"
    else
        log "应用商店: Web SSH 快捷入口 = 缺失"
        ttyd_selfcheck_failures=$((ttyd_selfcheck_failures + 1))
    fi

    if grep -q "frame.src.indexOf('/admin/vpn/easytier') === -1" "$TPL" 2>/dev/null \
        && grep -q "frame.src.indexOf('/nradioadv/system/webssh') === -1" "$TPL" 2>/dev/null; then
        log "应用商店: Web SSH iframe 白名单 = 正常"
    else
        log "应用商店: Web SSH iframe 白名单 = 缺失"
        ttyd_selfcheck_failures=$((ttyd_selfcheck_failures + 1))
    fi

    if grep -q 'WEBSSH_EMBED_MODE' /usr/lib/lua/luci/view/nradio_adv/webssh.htm 2>/dev/null \
        && grep -q 'data-focus-toggle' /usr/lib/lua/luci/view/nradio_adv/webssh.htm 2>/dev/null; then
        log "Web SSH 页面: embed/focus 标记 = 正常"
    else
        log "Web SSH 页面: embed/focus 标记 = 缺失"
        ttyd_selfcheck_failures=$((ttyd_selfcheck_failures + 1))
    fi

    if grep -q 'function normalize_app_route(app_name, route)' "$TPL" 2>/dev/null \
        && grep -q 'embed=1' "$TPL" 2>/dev/null \
        && grep -q "app_name == 'Web SSH' && action == 'open' && route" "$TPL" 2>/dev/null; then
        log "应用商店: Web SSH embed/open 逻辑 = 正常"
    else
        log "应用商店: Web SSH embed/open 逻辑 = 缺失"
        ttyd_selfcheck_failures=$((ttyd_selfcheck_failures + 1))
    fi

    if grep -q "action == 'uninstall' && nradio_plugin_uninstall_action(app_name)" "$TPL" 2>/dev/null \
        && grep -q 'plugin_uninstall/start' "$TPL" 2>/dev/null \
        && grep -q 'plugin_uninstall/check' "$TPL" 2>/dev/null; then
        log "应用商店: Web SSH 异步卸载逻辑 = 正常"
    else
        log "应用商店: Web SSH 异步卸载逻辑 = 缺失"
        ttyd_selfcheck_warnings=$((ttyd_selfcheck_warnings + 1))
    fi

    if [ -f /www/luci-static/nradio/images/icon/webssh.svg ]; then
        log "图标:     Web SSH SVG = 正常"
    else
        log "图标:     Web SSH SVG = 缺失"
        ttyd_selfcheck_warnings=$((ttyd_selfcheck_warnings + 1))
    fi

    if [ -x /usr/bin/ttyd ]; then
        ttyd_version="$(/usr/bin/ttyd -v 2>/dev/null | sed -n '1p' | tr -d '\r' || true)"
        [ -n "$ttyd_version" ] && log "核心:     $ttyd_version"
    fi

    if command -v ss >/dev/null 2>&1; then
        if ss -lnt 2>/dev/null | grep -q ":$ttyd_port[[:space:]]"; then
            log "listen:   port $ttyd_port is listening"
        else
            log "listen:   port $ttyd_port is not listening"
            ttyd_selfcheck_failures=$((ttyd_selfcheck_failures + 1))
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -lnt 2>/dev/null | grep -q ":$ttyd_port[[:space:]]"; then
            log "listen:   port $ttyd_port is listening"
        else
            log "listen:   port $ttyd_port is not listening"
            ttyd_selfcheck_failures=$((ttyd_selfcheck_failures + 1))
        fi
    else
        log "listen:   socket probe unavailable"
        ttyd_selfcheck_warnings=$((ttyd_selfcheck_warnings + 1))
    fi

    if [ "$ttyd_iface" != 'all' ] && [ -n "$ttyd_iface" ] && ! ip link show "$ttyd_iface" >/dev/null 2>&1; then
        ttyd_selfcheck_failures=$((ttyd_selfcheck_failures + 1))
    fi

    log "bind:     interface=$ttyd_iface port=$ttyd_port"
    ttyd_ps="$(pgrep -af 'ttyd' 2>/dev/null || true)"
    selfcheck_print_process_state "ttyd" 'ttyd'
    [ -n "$ttyd_ps" ] || ttyd_selfcheck_failures=$((ttyd_selfcheck_failures + 1))

    selfcheck_finalize_summary "$ttyd_selfcheck_failures" "$ttyd_selfcheck_warnings"
}

run_openlist_selfcheck() {
    require_root
    selfcheck_print_header "OpenList 自检"

    openlist_selfcheck_failures=0
    openlist_selfcheck_warnings=0
    openlist_data_dir="$(get_openlist_effective_data_dir)"

    selfcheck_print_service_state "openlist" "/etc/init.d/openlist"
    selfcheck_print_file_state "openlist binary" "$OPENLIST_BIN_PATH"
    selfcheck_print_file_state "openlist symlink" "$OPENLIST_LINK_PATH"
    selfcheck_print_file_state "openlist init" "/etc/init.d/openlist"
    selfcheck_print_file_state "openlist helper" "/usr/libexec/openlist-sync-config"
    selfcheck_print_file_state "openlist config" "/etc/config/openlist"
    selfcheck_print_file_state "openlist data config" "$openlist_data_dir/config.json"
    selfcheck_print_file_state "openlist controller" "/usr/lib/lua/luci/controller/nradio_adv/openlist.lua"
    selfcheck_print_file_state "openlist cbi" "/usr/lib/lua/luci/model/cbi/nradio_adv/openlist_basic.lua"
    selfcheck_print_file_state "openlist logs view" "/usr/lib/lua/luci/view/nradio_adv/openlist_logs.htm"
    selfcheck_print_appcenter_route_state "OpenList" "OpenList" "nradioadv/system/openlist/basic"
    selfcheck_print_luci_route_state "OpenList overview" "nradioadv/system/openlist"
    selfcheck_print_luci_route_state "OpenList basic" "nradioadv/system/openlist/basic"
    selfcheck_print_luci_route_state "OpenList logs" "nradioadv/system/openlist/logs"

    [ -x /etc/init.d/openlist ] || openlist_selfcheck_failures=$((openlist_selfcheck_failures + 1))
    [ -x "$OPENLIST_BIN_PATH" ] || openlist_selfcheck_failures=$((openlist_selfcheck_failures + 1))
    [ -L "$OPENLIST_LINK_PATH" ] || [ -x "$OPENLIST_LINK_PATH" ] || openlist_selfcheck_failures=$((openlist_selfcheck_failures + 1))
    for needed in \
        /usr/libexec/openlist-sync-config \
        /etc/config/openlist \
        /usr/lib/lua/luci/controller/nradio_adv/openlist.lua \
        /usr/lib/lua/luci/model/cbi/nradio_adv/openlist_basic.lua \
        /usr/lib/lua/luci/view/nradio_adv/openlist_logs.htm; do
        [ -f "$needed" ] || openlist_selfcheck_failures=$((openlist_selfcheck_failures + 1))
    done
    [ -f "$openlist_data_dir/config.json" ] || openlist_selfcheck_failures=$((openlist_selfcheck_failures + 1))
    selfcheck_appcenter_route_matches "OpenList" "nradioadv/system/openlist/basic" || openlist_selfcheck_failures=$((openlist_selfcheck_failures + 1))
    selfcheck_luci_route_ok "nradioadv/system/openlist" || openlist_selfcheck_failures=$((openlist_selfcheck_failures + 1))
    selfcheck_luci_route_ok "nradioadv/system/openlist/basic" || openlist_selfcheck_failures=$((openlist_selfcheck_failures + 1))
    selfcheck_luci_route_ok "nradioadv/system/openlist/logs" || openlist_selfcheck_failures=$((openlist_selfcheck_failures + 1))

    if [ -x /etc/init.d/openlist ]; then
        /etc/init.d/openlist enabled >/dev/null 2>&1 || openlist_selfcheck_warnings=$((openlist_selfcheck_warnings + 1))
        openlist_service_status="$( ( /etc/init.d/openlist status 2>/dev/null || true ) | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' )"
        case "$openlist_service_status" in
            *running*|1) ;;
            *) openlist_selfcheck_warnings=$((openlist_selfcheck_warnings + 1)) ;;
        esac
    fi

    if [ -x "$OPENLIST_BIN_PATH" ]; then
        openlist_version_text="$("$OPENLIST_BIN_PATH" version 2>/dev/null | sed -n '1p' | tr -d '\r' || true)"
        [ -n "$openlist_version_text" ] && log "核心:     $openlist_version_text"
    fi

    selfcheck_print_process_state "OpenList" 'openlist'
    pgrep -af 'openlist' >/dev/null 2>&1 || openlist_selfcheck_warnings=$((openlist_selfcheck_warnings + 1))

    selfcheck_finalize_summary "$openlist_selfcheck_failures" "$openlist_selfcheck_warnings"
}

run_zerotier_selfcheck() {
    require_root
    selfcheck_print_header "ZeroTier 自检"

    zerotier_selfcheck_failures=0
    zerotier_selfcheck_warnings=0

    selfcheck_print_service_state "zerotier" "/etc/init.d/zerotier"
    selfcheck_print_file_state "zerotier config" "/etc/config/zerotier"
    selfcheck_print_file_state "zerotier controller" "$ZEROTIER_CONTROLLER"
    selfcheck_print_file_state "zerotier cbi" "$ZEROTIER_CBI"
    selfcheck_print_appcenter_route_state "ZeroTier" "ZeroTier" "$ZEROTIER_ROUTE"
    selfcheck_print_luci_route_state "ZeroTier overview" "nradioadv/system/zerotier"
    selfcheck_print_luci_route_state "ZeroTier basic" "nradioadv/system/zerotier/basic"

    [ -x /etc/init.d/zerotier ] || zerotier_selfcheck_failures=$((zerotier_selfcheck_failures + 1))
    for needed in \
        /etc/config/zerotier \
        "$ZEROTIER_CONTROLLER" \
        "$ZEROTIER_CBI"; do
        [ -f "$needed" ] || zerotier_selfcheck_failures=$((zerotier_selfcheck_failures + 1))
    done
    selfcheck_appcenter_route_matches "ZeroTier" "$ZEROTIER_ROUTE" || zerotier_selfcheck_failures=$((zerotier_selfcheck_failures + 1))
    selfcheck_luci_route_ok "nradioadv/system/zerotier" || zerotier_selfcheck_failures=$((zerotier_selfcheck_failures + 1))
    selfcheck_luci_route_ok "nradioadv/system/zerotier/basic" || zerotier_selfcheck_failures=$((zerotier_selfcheck_failures + 1))

    if [ -x /etc/init.d/zerotier ]; then
        /etc/init.d/zerotier enabled >/dev/null 2>&1 || zerotier_selfcheck_warnings=$((zerotier_selfcheck_warnings + 1))
        zerotier_service_status="$( ( /etc/init.d/zerotier status 2>/dev/null || true ) | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' )"
        case "$zerotier_service_status" in
            *running*|1) ;;
            *) zerotier_selfcheck_warnings=$((zerotier_selfcheck_warnings + 1)) ;;
        esac
    fi

    if command -v zerotier-cli >/dev/null 2>&1; then
        zerotier_info="$(zerotier-cli info 2>/dev/null | sed -n '1p' | tr -d '\r' || true)"
        [ -n "$zerotier_info" ] && log "核心:     $zerotier_info"
    fi

    selfcheck_print_process_state "ZeroTier" 'zerotier-one'
    pgrep -af 'zerotier-one' >/dev/null 2>&1 || zerotier_selfcheck_warnings=$((zerotier_selfcheck_warnings + 1))

    selfcheck_finalize_summary "$zerotier_selfcheck_failures" "$zerotier_selfcheck_warnings"
}

run_easytier_selfcheck() {
    require_root
    selfcheck_print_header "$EASYTIER_DISPLAY_NAME 自检"

    easytier_selfcheck_failures=0
    easytier_selfcheck_warnings=0
    easytier_core_bin="$(uci -q get easytier.@easytier[0].easytierbin 2>/dev/null || true)"
    [ -n "$easytier_core_bin" ] || easytier_core_bin="/usr/bin/easytier-core"

    selfcheck_print_service_state "easytier" "/etc/init.d/easytier"
    selfcheck_print_file_state "easytier config" "/etc/config/easytier"
    selfcheck_print_file_state "easytier controller" "$EASYTIER_CONTROLLER"
    selfcheck_print_file_state "easytier cbi" "/usr/lib/lua/luci/model/cbi/easytier.lua"
    selfcheck_print_file_state "easytier status view" "/usr/lib/lua/luci/view/easytier/easytier_status.htm"
    selfcheck_print_file_state "easytier core" "$easytier_core_bin"
    selfcheck_print_file_state "easytier cli" "/usr/bin/easytier-cli"
    selfcheck_print_file_state "easytier web" "/usr/bin/easytier-web"
    selfcheck_print_appcenter_route_state "$EASYTIER_DISPLAY_NAME" "$EASYTIER_DISPLAY_NAME" "$EASYTIER_ROUTE"
    selfcheck_print_luci_route_state "$EASYTIER_DISPLAY_NAME page" "$EASYTIER_ROUTE"

    [ -x /etc/init.d/easytier ] || easytier_selfcheck_failures=$((easytier_selfcheck_failures + 1))
    for needed in \
        /etc/config/easytier \
        "$EASYTIER_CONTROLLER" \
        /usr/lib/lua/luci/model/cbi/easytier.lua \
        /usr/lib/lua/luci/view/easytier/easytier_status.htm \
        /usr/bin/easytier-core \
        /usr/bin/easytier-cli \
        /usr/bin/easytier-web; do
        [ -f "$needed" ] || easytier_selfcheck_failures=$((easytier_selfcheck_failures + 1))
    done
    selfcheck_appcenter_route_matches "$EASYTIER_DISPLAY_NAME" "$EASYTIER_ROUTE" || easytier_selfcheck_failures=$((easytier_selfcheck_failures + 1))
    selfcheck_luci_route_ok "$EASYTIER_ROUTE" || easytier_selfcheck_failures=$((easytier_selfcheck_failures + 1))

    if [ -x /etc/init.d/easytier ]; then
        /etc/init.d/easytier enabled >/dev/null 2>&1 || easytier_selfcheck_warnings=$((easytier_selfcheck_warnings + 1))
        easytier_service_status="$( ( /etc/init.d/easytier status 2>/dev/null || true ) | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' )"
        case "$easytier_service_status" in
            *running*|1) ;;
            *) easytier_selfcheck_warnings=$((easytier_selfcheck_warnings + 1)) ;;
        esac
    fi

    if [ -x "$easytier_core_bin" ]; then
        easytier_version_text="$("$easytier_core_bin" -V 2>/dev/null | sed -n '1p' | tr -d '\r' || true)"
        [ -n "$easytier_version_text" ] || easytier_version_text="$("$easytier_core_bin" --version 2>/dev/null | sed -n '1p' | tr -d '\r' || true)"
        [ -n "$easytier_version_text" ] && log "核心:     $easytier_version_text"
    fi

    selfcheck_print_process_state "$EASYTIER_DISPLAY_NAME core" 'easytier-core'
    selfcheck_print_process_state "$EASYTIER_DISPLAY_NAME web" 'easytier-web'
    pgrep -af 'easytier-core' >/dev/null 2>&1 || easytier_selfcheck_warnings=$((easytier_selfcheck_warnings + 1))
    pgrep -af 'easytier-web' >/dev/null 2>&1 || easytier_selfcheck_warnings=$((easytier_selfcheck_warnings + 1))

    selfcheck_finalize_summary "$easytier_selfcheck_failures" "$easytier_selfcheck_warnings"
}

run_openlist_cdn_selfcheck() {
    openlist_probe_urls="$(build_openlist_download_urls 2>/dev/null || true)"
    if [ -z "$openlist_probe_urls" ]; then
        log "CDN:      OpenList = 下载地址解析失败"
        set_last_selfcheck_status FAIL 1 0
        return 1
    fi

    rank_url_list_hosts "openlist-unified" "OpenList GitHub 官方" "$OPENLIST_GITHUB_OFFICIAL_PROBE_URLS" "$openlist_probe_urls"
    if [ -n "${RANKED_URL_HOSTS:-}" ]; then
        log "CDN:      OpenList = $RANKED_URL_HOSTS"
        set_last_selfcheck_status PASS 0 0
    else
        log "CDN:      OpenList = 未得出排序"
        set_last_selfcheck_status WARN 0 1
    fi
}

run_easytier_cdn_selfcheck() {
    easytier_probe_urls="$(build_easytier_download_urls 2>/dev/null || true)"
    if [ -z "$easytier_probe_urls" ]; then
        log "CDN:      $EASYTIER_DISPLAY_NAME = 下载地址解析失败"
        set_last_selfcheck_status FAIL 1 0
        return 1
    fi

    rank_url_list_hosts "easytier-unified" "$EASYTIER_DISPLAY_NAME GitHub 官方" "$EASYTIER_GITHUB_OFFICIAL_PROBE_URLS" "$easytier_probe_urls"
    if [ -n "${RANKED_URL_HOSTS:-}" ]; then
        log "CDN:      $EASYTIER_DISPLAY_NAME = $RANKED_URL_HOSTS"
        set_last_selfcheck_status PASS 0 0
    else
        log "CDN:      $EASYTIER_DISPLAY_NAME = 未得出排序"
        set_last_selfcheck_status WARN 0 1
    fi
}

run_feed_package_cdn_selfcheck() {
    probe_label="$1"
    probe_package="$2"
    probe_prefix="$3"

    if [ ! -f "$FEEDS" ]; then
        log "CDN:      $probe_label = 软件源文件缺失"
        set_last_selfcheck_status FAIL 1 0
        return 1
    fi

    probe_meta="$(resolve_package_meta_any_feed "$probe_package" 2>/dev/null || true)"
    if [ -z "$probe_meta" ]; then
        log "CDN:      $probe_label = 无法从当前软件源解析"
        set_last_selfcheck_status FAIL 1 0
        return 1
    fi

    probe_feed_name="${probe_meta%%|*}"
    probe_meta_rest="${probe_meta#*|}"
    probe_feed_url="${probe_meta_rest%%|*}"
    probe_meta_rest="${probe_meta_rest#*|}"
    probe_filename="${probe_meta_rest%%|*}"
    probe_urls="$(build_package_download_urls_from_meta "$probe_feed_url" "$probe_filename" 2>/dev/null || true)"
    if [ -z "$probe_urls" ]; then
        log "CDN:      $probe_label = 下载地址生成失败（$probe_feed_name）"
        set_last_selfcheck_status FAIL 1 0
        return 1
    fi

    rank_url_list_hosts "$probe_prefix" "$probe_label" "$probe_urls"
    if [ -n "${RANKED_URL_HOSTS:-}" ]; then
        refine_ranked_hosts_by_http_probe "$probe_prefix" "$probe_label" "$RANKED_URL_HOSTS" "$probe_urls"
        log "CDN:      $probe_label = $RANKED_URL_HOSTS (feed=$probe_feed_name)"
        set_last_selfcheck_status PASS 0 0
    else
        log "CDN:      $probe_label = 未得出排序（feed=$probe_feed_name)"
        set_last_selfcheck_status WARN 0 1
    fi
}

run_unified_test_mode() {
    require_root
    NRADIO_UNIFIED_FAILS=0
    NRADIO_UNIFIED_WARNS=0
    NRADIO_UNIFIED_PASSES=0
    log "统一测试模式"
    log "------"
    log "备注:     this mode only probes CDN, routes and runtime state"
    log "备注:     no package install will be performed; metadata/feed index probes may still run"
    log ""

    selfcheck_print_header "CDN 测试"
    run_openclash_cdn_selfcheck
    record_unified_selfcheck_summary "$OPENCLASH_DISPLAY_NAME CDN"
    log ""
    run_adguardhome_cdn_selfcheck
    record_unified_selfcheck_summary "AdGuardHome CDN"
    log ""
    run_openlist_cdn_selfcheck
    record_unified_selfcheck_summary "OpenList CDN"
    log ""
    run_feed_package_cdn_selfcheck "ZeroTier" "$ZEROTIER_PACKAGE_NAME" "zerotier-unified"
    record_unified_selfcheck_summary "ZeroTier CDN"
    log ""
    run_easytier_cdn_selfcheck
    record_unified_selfcheck_summary "$EASYTIER_DISPLAY_NAME CDN"
    log ""
    run_feed_package_cdn_selfcheck "OpenVPN" "luci-app-openvpn" "openvpn-unified"
    record_unified_selfcheck_summary "OpenVPN CDN"
    log ""

    run_openclash_selfcheck
    record_unified_selfcheck_summary "$OPENCLASH_DISPLAY_NAME"
    log ""
    run_adguardhome_selfcheck
    record_unified_selfcheck_summary "AdGuardHome"
    log ""
    run_ttyd_webssh_selfcheck
    record_unified_selfcheck_summary "Web SSH / ttyd"
    log ""
    run_openlist_selfcheck
    record_unified_selfcheck_summary "OpenList"
    log ""
    run_zerotier_selfcheck
    record_unified_selfcheck_summary "ZeroTier"
    log ""
    run_easytier_selfcheck
    record_unified_selfcheck_summary "$EASYTIER_DISPLAY_NAME"
    log ""
    NRADIO_READONLY_SELFTEST=1 run_openvpn_selfcheck
    record_unified_selfcheck_summary "OpenVPN"
    log ""
    if [ "$NRADIO_UNIFIED_FAILS" -gt 0 ]; then
        log "overall:  FAIL (pass=$NRADIO_UNIFIED_PASSES warn=$NRADIO_UNIFIED_WARNS fail=$NRADIO_UNIFIED_FAILS)"
    elif [ "$NRADIO_UNIFIED_WARNS" -gt 0 ]; then
        log "overall:  WARN (pass=$NRADIO_UNIFIED_PASSES warn=$NRADIO_UNIFIED_WARNS fail=0)"
    else
        log "overall:  PASS (pass=$NRADIO_UNIFIED_PASSES)"
    fi
}

run_openvpn_selfcheck() {
    ovpn_dst="/etc/openvpn/client.ovpn"
    auth_dst="/etc/openvpn/auth.txt"
    hotplug_dst="/etc/hotplug.d/openvpn/99-openvpn-route"
    tun_if="tun0"
    lan_if_guess="br-lan"
    ovpn_selfcheck_failures=0
    ovpn_selfcheck_warnings=0

    require_root
    ensure_state_dir
    load_openvpn_runtime_state
    prepare_openvpn_selfcheck_runtime_view "$ovpn_dst"
    clear_openvpn_route_state_vars
    load_openvpn_route_state
    clear_openvpn_selfcheck_route_views

    [ -n "${ROUTE_TUN_IF:-}" ] && tun_if="$ROUTE_TUN_IF"
    [ -n "${ROUTE_LAN_IF:-}" ] && lan_if_guess="$ROUTE_LAN_IF"
    prepare_openvpn_selfcheck_route_views "$hotplug_dst" "$tun_if" "$lan_if_guess"
    [ -n "${ROUTE_TUN_IF:-}" ] && tun_if="$ROUTE_TUN_IF"
    [ -n "${ROUTE_LAN_IF:-}" ] && lan_if_guess="$ROUTE_LAN_IF"

    log "OpenVPN 自检"
    log "------"

    if command -v openvpn >/dev/null 2>&1; then
        openvpn_bin="$(command -v openvpn)"
    elif [ -x /usr/sbin/openvpn ]; then
        openvpn_bin="/usr/sbin/openvpn"
    else
        openvpn_bin=''
    fi
    if [ -n "$openvpn_bin" ]; then
        openvpn_ver="$("$openvpn_bin" --version 2>/dev/null | sed -n '1p' | tr -d '\r' || true)"
        [ -n "$openvpn_ver" ] || openvpn_ver="available ($openvpn_bin)"
        log "核心:     $openvpn_ver"
    else
        log "核心:     missing"
        ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
    fi

    if /etc/init.d/openvpn enabled >/dev/null 2>&1; then
        openvpn_enabled='1'
    else
        openvpn_enabled='0'
        ovpn_selfcheck_warnings=$((ovpn_selfcheck_warnings + 1))
    fi
    openvpn_status="$( ( /etc/init.d/openvpn status 2>/dev/null || true ) | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' )"
    [ -n "$openvpn_status" ] || openvpn_status='stopped'
    log "service:  enabled=$(openvpn_selfcheck_bool "$openvpn_enabled") status=$openvpn_status"
    case "$openvpn_status" in
        *running*|1) ;;
        *) ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1)) ;;
    esac

    openvpn_selfcheck_print_file_state "client profile" "$ovpn_dst"
    openvpn_selfcheck_print_file_state "auth file" "$auth_dst"
    openvpn_selfcheck_print_file_state "route hotplug" "$hotplug_dst"
    openvpn_selfcheck_print_file_state "runtime state" "$RUNTIME_STATE_FILE"
    openvpn_selfcheck_print_file_state "route state" "$ROUTE_STATE_FILE"
    openvpn_selfcheck_print_file_state "saved route list" "$ROUTE_LIST_FILE"
    openvpn_selfcheck_print_file_state "saved mapped peers" "$ROUTE_MAP_LIST_FILE"
    [ -s "$ovpn_dst" ] || ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
    [ -e "$hotplug_dst" ] || ovpn_selfcheck_warnings=$((ovpn_selfcheck_warnings + 1))
    if [ ! -e "$RUNTIME_STATE_FILE" ] && [ "${OVPN_SELFCHECK_RUNTIME_SOURCE:-saved}" != 'profile' ]; then
        ovpn_selfcheck_warnings=$((ovpn_selfcheck_warnings + 1))
    fi
    if [ ! -e "$ROUTE_STATE_FILE" ] && [ "${OVPN_SELFCHECK_ROUTE_STATE_SOURCE:-saved}" != 'hotplug' ]; then
        ovpn_selfcheck_warnings=$((ovpn_selfcheck_warnings + 1))
    fi
    remote_line="$(awk '$1=="remote"{print $2" "$3; exit}' "$ovpn_dst" 2>/dev/null | tr -d '\r' || true)"
    proto_line="$(awk '$1=="proto"{print $2; exit}' "$ovpn_dst" 2>/dev/null | tr -d '\r' || true)"
    auth_mode=''
    grep -q '^auth-user-pass' "$ovpn_dst" 2>/dev/null && auth_mode="userpass"
    if grep -q '<cert>' "$ovpn_dst" 2>/dev/null; then
        if [ -n "$auth_mode" ]; then auth_mode="$auth_mode+cert"; else auth_mode="cert"; fi
    fi
    if grep -q '<tls-auth>' "$ovpn_dst" 2>/dev/null; then
        if [ -n "$auth_mode" ]; then auth_mode="$auth_mode+tls-auth"; else auth_mode="tls-auth"; fi
    fi
    if grep -q '<tls-crypt>' "$ovpn_dst" 2>/dev/null; then
        if [ -n "$auth_mode" ]; then auth_mode="$auth_mode+tls-crypt"; else auth_mode="tls-crypt"; fi
    fi
    [ -n "$auth_mode" ] || auth_mode='unknown/none'
    case "$auth_mode" in
        userpass*|*+userpass*)
            [ -s "$auth_dst" ] || ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
            ;;
    esac
    [ -n "$remote_line" ] && log "remote:   $remote_line"
    [ -n "$proto_line" ] && log "proto:    $proto_line"
    log "auth:     $auth_mode"

    tun_line="$(ip -4 addr show "$tun_if" 2>/dev/null | grep -m1 'inet ' || true)"
    if [ -n "$tun_line" ]; then
        tun_ip="$(printf '%s\n' "$tun_line" | awk '{print $2}')"
        log "tun:      up on $tun_if ($tun_ip)"
    else
        log "tun:      down on $tun_if"
        ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
    fi

    if [ -n "${ROUTE_LAN_IF:-}" ] || [ -n "${ROUTE_LAN_SUBNET:-}" ] || [ -n "${ROUTE_TUN_IF:-}" ]; then
        log "state:    lan_if=${ROUTE_LAN_IF:-?} lan_subnet=${ROUTE_LAN_SUBNET:-?} tun_if=${ROUTE_TUN_IF:-?} tun_subnet=${ROUTE_TUN_SUBNET:-}"
        log "state:    nat=${ROUTE_NAT:-?} forward=${ROUTE_FORWARD:-?} enhanced=${ROUTE_ENHANCED:-?} map=${ROUTE_MAP_ENABLE:-?} map_kind=${ROUTE_MAP_KIND:-} map_ip=${ROUTE_MAP_IP:-} map_host=${ROUTE_MAP_HOST:-} map_subnet=${ROUTE_MAP_SUBNET:-}"
    else
        log "state:    no saved OpenVPN route state"
        ovpn_selfcheck_warnings=$((ovpn_selfcheck_warnings + 1))
    fi

    route_list_selfcheck_file="${OVPN_SELFCHECK_ROUTE_LIST_FILE:-$ROUTE_LIST_FILE}"
    if [ -s "$route_list_selfcheck_file" ]; then
        while IFS='|' read -r subnet gw; do
            [ -n "$subnet" ] || continue
            rule_pattern="(^|[[:space:]])to $subnet lookup main([[:space:]]|$)"
            if openvpn_route_via_dev_exists "$subnet" "$gw" "$tun_if"; then
                log "路由:    ok  $subnet via $gw"
            else
                log "路由:    miss $subnet via $gw"
                ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
            fi
            if openvpn_ip_rule_to_exists "$subnet" || ip rule | grep -Eq "$rule_pattern"; then
                log "policy:   ok  to $subnet lookup main"
            else
                log "policy:   miss to $subnet lookup main"
                ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
            fi
            if openvpn_ip_rule_iif_to_exists "$subnet" "$lan_if_guess"; then
                log "policy:   ok  iif $lan_if_guess to $subnet lookup main"
            else
                log "policy:   miss iif $lan_if_guess to $subnet lookup main"
                ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
            fi
        done < "$route_list_selfcheck_file"
    else
        log "路由:    no saved remote subnet list"
        ovpn_selfcheck_warnings=$((ovpn_selfcheck_warnings + 1))
    fi

    map_list_selfcheck_file="${OVPN_SELFCHECK_MAP_LIST_FILE:-$ROUTE_MAP_LIST_FILE}"
    if [ -s "$map_list_selfcheck_file" ]; then
        while IFS='|' read -r peer_map_target peer_map_gw peer_map_kind_saved; do
            [ -n "$peer_map_target" ] || continue
            [ -n "$peer_map_kind_saved" ] || peer_map_kind_saved="$(infer_map_target_kind "$peer_map_target")"
            if [ "$peer_map_kind_saved" = 'host' ]; then
                peer_map_match="${peer_map_target%/*}"
                peer_map_rule_pattern="(^|[[:space:]])to $peer_map_match(/32)? lookup main([[:space:]]|$)"
            else
                peer_map_match="$peer_map_target"
                peer_map_rule_pattern="(^|[[:space:]])to $peer_map_match lookup main([[:space:]]|$)"
            fi
            if openvpn_route_via_dev_exists "$peer_map_match" "$peer_map_gw" "$tun_if"; then
                log "map:      ok  $peer_map_match via $peer_map_gw ($peer_map_kind_saved)"
            else
                log "map:      miss $peer_map_match via $peer_map_gw ($peer_map_kind_saved)"
                ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
            fi
            if openvpn_ip_rule_to_exists "$peer_map_match" || ip rule | grep -Eq "$peer_map_rule_pattern"; then
                log "policy:   ok  to $peer_map_match lookup main"
            else
                log "policy:   miss to $peer_map_match lookup main"
                ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
            fi
            if openvpn_ip_rule_iif_to_exists "$peer_map_match" "$lan_if_guess"; then
                log "policy:   ok  iif $lan_if_guess to $peer_map_match lookup main"
            else
                log "policy:   miss iif $lan_if_guess to $peer_map_match lookup main"
                ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
            fi
        done < "$map_list_selfcheck_file"
    else
        log "map:      no saved mapped peer list"
        case "${ROUTE_MAP_ENABLE:-n}" in
            1|y|Y|yes|YES|true|TRUE) ovpn_selfcheck_warnings=$((ovpn_selfcheck_warnings + 1)) ;;
        esac
    fi

    map_kind_selfcheck="${ROUTE_MAP_KIND:-}"
    map_host_selfcheck="${ROUTE_MAP_HOST:-}"
    map_subnet_selfcheck="${ROUTE_MAP_SUBNET:-}"
    if [ -z "$map_kind_selfcheck" ] && [ -n "${ROUTE_MAP_IP:-}" ]; then
        case "$ROUTE_MAP_IP" in
            */32)
                map_kind_selfcheck='host'
                map_host_selfcheck="${ROUTE_MAP_IP%/*}"
                ;;
            */*)
                map_kind_selfcheck='subnet'
                map_subnet_selfcheck="$ROUTE_MAP_IP"
                ;;
            *)
                map_kind_selfcheck='host'
                map_host_selfcheck="$ROUTE_MAP_IP"
                ;;
        esac
    fi
    case "$map_kind_selfcheck" in
        host)
            [ -n "$map_host_selfcheck" ] || map_host_selfcheck="${ROUTE_MAP_IP%/*}"
            if [ -n "${ROUTE_MAP_IP:-}" ] && ip -4 addr show dev "$lan_if_guess" 2>/dev/null | grep -q "inet ${ROUTE_MAP_IP} "; then
                log "map-ip:   ok  ${ROUTE_MAP_IP} on $lan_if_guess"
            else
                log "map-ip:   miss ${ROUTE_MAP_IP:-unknown} on $lan_if_guess"
                ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
            fi
            if command -v iptables >/dev/null 2>&1 && [ -n "$map_host_selfcheck" ]; then
                if iptables -t nat -S PREROUTING 2>/dev/null | grep -Eq -- "-d ${map_host_selfcheck}(/32)? .*DNAT --to-destination "; then
                    log "nat:      ok  PREROUTING for ${map_host_selfcheck}"
                else
                    log "nat:      miss PREROUTING for ${map_host_selfcheck}"
                    ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
                fi
                if iptables -t nat -S OUTPUT 2>/dev/null | grep -Eq -- "-d ${map_host_selfcheck}(/32)? .*DNAT --to-destination "; then
                    log "nat:      ok  OUTPUT for ${map_host_selfcheck}"
                else
                    log "nat:      miss OUTPUT for ${map_host_selfcheck}"
                    ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
                fi
            fi
            ;;
        subnet)
            if command -v iptables >/dev/null 2>&1 && [ -n "$map_subnet_selfcheck" ] && [ -n "${ROUTE_LAN_SUBNET:-}" ]; then
                if iptables -t nat -S PREROUTING 2>/dev/null | grep -Eq -- "-d ${map_subnet_selfcheck} .*NETMAP --to ${ROUTE_LAN_SUBNET}"; then
                    log "nat:      ok  PREROUTING for ${map_subnet_selfcheck} -> ${ROUTE_LAN_SUBNET}"
                else
                    log "nat:      miss PREROUTING for ${map_subnet_selfcheck} -> ${ROUTE_LAN_SUBNET}"
                    ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
                fi
                if iptables -t nat -S OUTPUT 2>/dev/null | grep -Eq -- "-d ${map_subnet_selfcheck} .*NETMAP --to ${ROUTE_LAN_SUBNET}"; then
                    log "nat:      ok  OUTPUT for ${map_subnet_selfcheck} -> ${ROUTE_LAN_SUBNET}"
                else
                    log "nat:      miss OUTPUT for ${map_subnet_selfcheck} -> ${ROUTE_LAN_SUBNET}"
                    ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
                fi
            fi
            ;;
    esac

    log "rules:    $(ip rule | grep -c 'lookup main' 2>/dev/null || echo 0) main-lookup rules"
    if command -v iptables >/dev/null 2>&1; then
        log "iptables: nat=$(iptables -t nat -S 2>/dev/null | wc -l | tr -d ' ') filter=$(iptables -S 2>/dev/null | wc -l | tr -d ' ')"
    fi

    recent_runtime_log="$(tail -n 80 /tmp/openvpn-client.log 2>/dev/null || true)"
    recent_logread_openvpn="$(logread 2>/dev/null | grep -i openvpn | tail -n 80 || true)"
    last_runtime_init_line=''
    last_runtime_error_line=''
    if [ -f /tmp/openvpn-client.log ]; then
        last_runtime_init_line="$(awk '/Initialization Sequence Completed/{n=NR} END{if(n) print n}' /tmp/openvpn-client.log 2>/dev/null || true)"
        last_runtime_error_line="$(awk 'BEGIN{IGNORECASE=1} /AUTH_FAILED|TLS Error|Cannot resolve host address|Exiting due to fatal error|ERROR:/{n=NR} END{if(n) print n}' /tmp/openvpn-client.log 2>/dev/null || true)"
    fi

    if printf '%s\n' "$recent_runtime_log" | grep -q 'Initialization Sequence Completed'; then
        log "runtime:  initialization completed"
    elif printf '%s\n' "$recent_logread_openvpn" | grep -q 'Initialization Sequence Completed'; then
        log "runtime:  initialization completed (logread)"
    else
        log "runtime:  initialization marker not found"
        ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
    fi

    if [ -n "$last_runtime_error_line" ] && { [ -z "$last_runtime_init_line" ] || [ "$last_runtime_error_line" -gt "$last_runtime_init_line" ]; }; then
        log "runtime:  active error markers found after the last successful init"
        ovpn_selfcheck_failures=$((ovpn_selfcheck_failures + 1))
    elif [ -n "$last_runtime_error_line" ] && [ -n "$last_runtime_init_line" ] && [ "$last_runtime_error_line" -lt "$last_runtime_init_line" ]; then
        log "runtime:  previous error markers were recovered successfully"
    elif printf '%s\n' "$recent_logread_openvpn" | grep -qiE 'AUTH_FAILED|TLS Error|Cannot resolve host address|fatal error|ERROR:'; then
        log "runtime:  detected error markers in logread"
        ovpn_selfcheck_warnings=$((ovpn_selfcheck_warnings + 1))
    else
        log "runtime:  no recent fatal markers found"
    fi

    if [ -f /tmp/openvpn-client.log ]; then
        log "log:      tail /tmp/openvpn-client.log"
        tail -n 10 /tmp/openvpn-client.log 2>/dev/null || true
    fi
    log "log:      focused logread"
    logread 2>/dev/null | grep -i -E 'openvpn|tun0|tls|auth|route|error|fail|warn' | tail -n 12 || true

    selfcheck_finalize_summary "$ovpn_selfcheck_failures" "$ovpn_selfcheck_warnings"
}

read_nameservers_from_file() {
    file="$1"
    [ -f "$file" ] || return 0

    awk '
        /^[[:space:]]*nameserver[[:space:]]+/ {
            ns=$2
            if (ns != "" && ns !~ /^127\./ && ns != "::1" && ns != "0.0.0.0" && ns != "::") {
                print ns
            }
        }
    ' "$file" 2>/dev/null | awk '!seen[$0]++'
}

read_nameservers_from_dhcp_uci() {
    command -v uci >/dev/null 2>&1 || return 0
    [ -f /etc/config/dhcp ] || return 0

    uci -q show dhcp 2>/dev/null | awk -F"'" '
        /\.server=/ {
            ns = $2
            if (ns == "" || ns ~ /^\//)
                next
            if (ns ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ || ns ~ /^[0-9A-Fa-f:]+$/) {
                print ns
            }
        }
    ' | awk '!seen[$0]++'
}

list_openvpn_upstream_nameservers() {
    {
        read_nameservers_from_file /tmp/resolv.conf.d/resolv.conf.auto
        read_nameservers_from_file /tmp/resolv.conf.auto
        read_nameservers_from_file /etc/resolv.conf
        read_nameservers_from_dhcp_uci
    } | awk '!seen[$0]++'
}

list_openvpn_managed_dnsmasq_domains() {
    {
        [ -s "$OPENVPN_DNSMASQ_DOMAIN_STATE_FILE" ] && awk 'NF { print $0 }' "$OPENVPN_DNSMASQ_DOMAIN_STATE_FILE" 2>/dev/null
        awk '$1=="#nradio-remote-host"{print $2; exit}' /etc/openvpn/client.ovpn 2>/dev/null || true
    } | awk '!seen[$0]++'
}

remove_dnsmasq_server_rules_for_domain() {
    domain="$1"
    [ -n "$domain" ] || return 0
    command -v uci >/dev/null 2>&1 || return 0
    [ -f /etc/config/dhcp ] || return 0

    uci -q show dhcp 2>/dev/null | awk -F"'" -v domain="$domain" '
        /\.server=/ {
            value = $2
            prefix = "/" domain "/"
            if (index(value, prefix) == 1) {
                print value
            }
        }
    ' | while IFS= read -r server_rule; do
        [ -n "$server_rule" ] || continue
        uci -q del_list "dhcp.@dnsmasq[0].server=$server_rule" >/dev/null 2>&1 || true
    done
}

sync_openvpn_domain_dnsmasq_upstreams() {
    domain="$1"
    [ -n "$domain" ] || return 1
    command -v uci >/dev/null 2>&1 || return 1
    [ -f /etc/config/dhcp ] || return 1
    [ -x /etc/init.d/dnsmasq ] || return 1

    upstream_nameservers="$(list_openvpn_upstream_nameservers 2>/dev/null || true)"
    [ -n "$upstream_nameservers" ] || return 1

    mkdir -p "$WORKDIR" >/dev/null 2>&1 || return 1
    dhcp_restore_file="$WORKDIR/openvpn-dnsmasq-dhcp.sync.restore.$$"
    cp /etc/config/dhcp "$dhcp_restore_file" >/dev/null 2>&1 || return 1

    backup_file /etc/config/dhcp

    managed_domains="$(list_openvpn_managed_dnsmasq_domains 2>/dev/null || true)"
    if [ -n "$managed_domains" ]; then
        while IFS= read -r managed_domain; do
            [ -n "$managed_domain" ] || continue
            remove_dnsmasq_server_rules_for_domain "$managed_domain"
        done <<EOF
$managed_domains
EOF
    fi
    remove_dnsmasq_server_rules_for_domain "$domain"

    added_count=0
    while IFS= read -r resolver_ip; do
        [ -n "$resolver_ip" ] || continue
        server_rule="/$domain/$resolver_ip"
        uci -q add_list "dhcp.@dnsmasq[0].server=$server_rule" >/dev/null 2>&1 || {
            uci -q revert dhcp >/dev/null 2>&1 || true
            rm -f "$dhcp_restore_file" >/dev/null 2>&1 || true
            return 1
        }
        added_count=$((added_count + 1))
    done <<EOF
$upstream_nameservers
EOF

    [ "$added_count" -gt 0 ] || {
        rm -f "$dhcp_restore_file" >/dev/null 2>&1 || true
        return 1
    }
    uci commit dhcp >/dev/null 2>&1 || {
        uci -q revert dhcp >/dev/null 2>&1 || true
        rm -f "$dhcp_restore_file" >/dev/null 2>&1 || true
        return 1
    }
    /etc/init.d/dnsmasq restart >/dev/null 2>&1 || {
        uci -q revert dhcp >/dev/null 2>&1 || true
        cp "$dhcp_restore_file" /etc/config/dhcp >/dev/null 2>&1 || true
        /etc/init.d/dnsmasq restart >/dev/null 2>&1 || true
        rm -f "$dhcp_restore_file" >/dev/null 2>&1 || true
        return 1
    }
    ensure_state_dir
    printf '%s\n' "$domain" > "$OPENVPN_DNSMASQ_DOMAIN_STATE_FILE"
    chmod 600 "$OPENVPN_DNSMASQ_DOMAIN_STATE_FILE" 2>/dev/null || true
    rm -f "$dhcp_restore_file" >/dev/null 2>&1 || true
}

system_resolver_loopback_only() {
    resolver_file="/etc/resolv.conf"
    [ -f "$resolver_file" ] || return 1

    awk '
        BEGIN { saw = 0; nonloop = 0 }
        /^[[:space:]]*nameserver[[:space:]]+/ {
            saw = 1
            ns = $2
            if (ns !~ /^127\./ && ns != "::1" && ns != "0.0.0.0" && ns != "::") {
                nonloop = 1
            }
        }
        END { exit !(saw && nonloop == 0) }
    ' "$resolver_file" 2>/dev/null
}

resolve_host_records_via_nslookup() {
    host="$1"
    family="$2"
    server="${3:-}"

    command -v nslookup >/dev/null 2>&1 || return 1

    if [ -n "$server" ]; then
        nslookup "$host" "$server" 2>/dev/null
    else
        nslookup "$host" 2>/dev/null
    fi | awk -v family="$family" '
        /^Name:[[:space:]]*/ { seen_name = 1; next }
        !seen_name { next }
        /^Address [0-9]+:[[:space:]]*/ || /^[Aa]ddress:[[:space:]]*/ {
            ip = $NF
            if (family == "ipv4") {
                if (ip ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
                    print ip
                }
            }
            else if (family == "ipv6") {
                if (ip ~ /:/) {
                    print ip
                }
            }
        }
    ' | awk '!seen[$0]++'
}

resolve_host_records() {
    host="$1"
    family="$2"

    if system_resolver_loopback_only; then
        upstream_nameservers="$(list_openvpn_upstream_nameservers 2>/dev/null || true)"
        [ -n "$upstream_nameservers" ] || return 1
        while IFS= read -r resolver_ip; do
            [ -n "$resolver_ip" ] || continue
            resolved_list="$(resolve_host_records_via_nslookup "$host" "$family" "$resolver_ip" 2>/dev/null || true)"
            if [ -n "$resolved_list" ]; then
                printf '%s\n' "$resolved_list"
                return 0
            fi
        done <<EOF
$upstream_nameservers
EOF
        return 1
    fi

    resolved_list="$(resolve_host_records_via_nslookup "$host" "$family" 2>/dev/null || true)"
    if [ -n "$resolved_list" ]; then
        printf '%s\n' "$resolved_list"
        return 0
    fi

    if [ "$family" = 'ipv6' ] && command -v ping6 >/dev/null 2>&1; then
        ping6 -c 1 "$host" 2>/dev/null | awk -F'[()]' '/PING/{print $2; exit}'
    elif command -v ping >/dev/null 2>&1; then
        ping -c 1 "$host" 2>/dev/null | awk -F'[()]' '/PING/{print $2; exit}'
    else
        return 1
    fi
}

resolve_host_record() {
    host="$1"
    family="$2"
    resolve_host_records "$host" "$family" 2>/dev/null | sed -n '1p'
}

get_default_lan_subnet() {
    lan_ip="$(uci -q get network.lan.ipaddr 2>/dev/null || true)"
    lan_mask="$(uci -q get network.lan.netmask 2>/dev/null || true)"

    if [ -n "$lan_ip" ] && [ -n "$lan_mask" ]; then
        case "$lan_mask" in
            255.255.255.0) printf '%s/24\n' "$(printf '%s' "$lan_ip" | awk -F. '{print $1 "." $2 "." $3 ".0"}')"; return 0 ;;
            255.255.0.0) printf '%s/16\n' "$(printf '%s' "$lan_ip" | awk -F. '{print $1 "." $2 ".0.0"}')"; return 0 ;;
            255.0.0.0) printf '%s/8\n' "$(printf '%s' "$lan_ip" | awk -F. '{print $1 ".0.0.0"}')"; return 0 ;;
        esac
    fi

    ip -4 addr show br-lan 2>/dev/null | awk '/inet /{print $2; exit}'
}

get_interface_subnet() {
    iface="$1"
    ip -4 addr show "$iface" 2>/dev/null | awk '/inet /{print $2; exit}'
}

load_openvpn_runtime_defaults_from_profile() {
    ovpn_file="/etc/openvpn/client.ovpn"
    [ -f "$ovpn_file" ] || return 0

    if [ -z "${OVPN_SERVER:-}" ]; then
        OVPN_SERVER="$(awk '$1=="#nradio-remote-host" {print $2; exit} $1=="remote" {print $2; exit}' "$ovpn_file" 2>/dev/null || true)"
    fi
    if [ -z "${OVPN_PORT:-}" ]; then
        OVPN_PORT="$(awk '$1=="remote" {print $3; exit}' "$ovpn_file" 2>/dev/null || true)"
    fi
    if [ -z "${OVPN_TRANSPORT:-}" ] || [ -z "${OVPN_FAMILY:-}" ]; then
        ovpn_proto_saved="$(awk '$1=="proto" {print $2; exit}' "$ovpn_file" 2>/dev/null || true)"
        case "$ovpn_proto_saved" in
            udp4) OVPN_TRANSPORT='udp'; OVPN_FAMILY='ipv4' ;;
            udp6) OVPN_TRANSPORT='udp'; OVPN_FAMILY='ipv6' ;;
            tcp4-client) OVPN_TRANSPORT='tcp'; OVPN_FAMILY='ipv4' ;;
            tcp6-client) OVPN_TRANSPORT='tcp'; OVPN_FAMILY='ipv6' ;;
        esac
    fi
    [ -n "${OVPN_CIPHER:-}" ] || OVPN_CIPHER="$(awk '$1=="cipher" {print $2; exit}' "$ovpn_file" 2>/dev/null || true)"
    [ -n "${OVPN_MTU:-}" ] || OVPN_MTU="$(awk '$1=="tun-mtu" {print $2; exit}' "$ovpn_file" 2>/dev/null || true)"
    [ -n "${OVPN_AUTH_DIGEST:-}" ] || OVPN_AUTH_DIGEST="$(awk '$1=="auth" {print $2; exit}' "$ovpn_file" 2>/dev/null || true)"
    [ -n "${OVPN_LZO:-}" ] || { grep -q '^comp-lzo yes$' "$ovpn_file" 2>/dev/null && OVPN_LZO='y' || OVPN_LZO='n'; }

    if [ -z "${OVPN_AUTH_MODE:-}" ]; then
        has_auth='0'; has_cert='0'
        grep -Eq '^auth-user-pass([[:space:]]|$)' "$ovpn_file" 2>/dev/null && has_auth='1'
        grep -q '^<cert>$' "$ovpn_file" 2>/dev/null && has_cert='1'
        if [ "$has_auth" = '1' ] && [ "$has_cert" = '1' ]; then
            OVPN_AUTH_MODE='3'
        elif [ "$has_auth" = '1' ]; then
            OVPN_AUTH_MODE='1'
        elif [ "$has_cert" = '1' ]; then
            OVPN_AUTH_MODE='2'
        fi
    fi

    [ -n "${OVPN_TLS_MODE:-}" ] || {
        grep -q '^<tls-auth>$' "$ovpn_file" 2>/dev/null && OVPN_TLS_MODE='auth'
        grep -q '^<tls-crypt>$' "$ovpn_file" 2>/dev/null && OVPN_TLS_MODE='crypt'
        [ -n "${OVPN_TLS_MODE:-}" ] || OVPN_TLS_MODE='n'
    }
    [ -n "${OVPN_KEY_DIRECTION:-}" ] || OVPN_KEY_DIRECTION="$(awk '$1=="key-direction" {print $2; exit}' "$ovpn_file" 2>/dev/null || true)"

    [ -n "${OVPN_SERVER_VERIFY:-}" ] || {
        grep -q '^remote-cert-tls server$' "$ovpn_file" 2>/dev/null && OVPN_SERVER_VERIFY='2' || OVPN_SERVER_VERIFY='1'
    }

    [ -n "${OVPN_VERIFY_CN:-}" ] || {
        if grep -q '^verify-x509-name ' "$ovpn_file" 2>/dev/null; then
            OVPN_VERIFY_CN='y'
            [ -n "${OVPN_SERVER_CN:-}" ] || OVPN_SERVER_CN="$(awk '/^verify-x509-name /{sub(/^verify-x509-name /,""); sub(/ name$/,""); print; exit}' "$ovpn_file" 2>/dev/null || true)"
        else
            OVPN_VERIFY_CN='n'
        fi
    }

    if [ -z "${OVPN_USER:-}" ] && [ -f /etc/openvpn/auth.txt ]; then
        OVPN_USER="$(sed -n '1p' /etc/openvpn/auth.txt 2>/dev/null || true)"
    fi
}

extract_inline_block_to_file() {
    ovpn_file="$1"
    tag_name="$2"
    out_file="$3"

    awk -v tag="$tag_name" '
        $0 == "<" tag ">" { inblock = 1; next }
        $0 == "</" tag ">" { exit }
        inblock { print }
    ' "$ovpn_file" > "$out_file" 2>/dev/null || true
    [ -s "$out_file" ] || rm -f "$out_file"
}

derive_supernet16_from_cidr() {
    cidr="$1"
    printf '%s' "$cidr" | awk -F'[./]' '
        NF == 5 {
            print $1 "." $2 ".0.0/16"
            exit 0
        }
        { exit 1 }
    '
}

normalize_ipv4_cidr() {
    cidr="$1"
    printf '%s' "$cidr" | awk -F'[./]' '
        NF == 5 {
            a=$1; b=$2; c=$3; d=$4; m=$5;
            if (m < 0 || m > 32) exit 1;
            if (m >= 24) {
                if (m == 24) d = 0;
                print a "." b "." c "." d "/" m;
            }
            else if (m >= 16) {
                c = 0; d = 0;
                print a "." b "." c "." d "/" m;
            }
            else if (m >= 8) {
                b = 0; c = 0; d = 0;
                print a "." b "." c "." d "/" m;
            }
            else {
                a = 0; b = 0; c = 0; d = 0;
                print a "." b "." c "." d "/" m;
            }
            exit 0;
        }
        { exit 1 }
    '
}

normalize_ipv4_host() {
    host="$1"
    printf '%s' "$host" | awk -F. '
        NF == 4 {
            for (i = 1; i <= 4; i++) {
                if ($i !~ /^[0-9]+$/ || $i < 0 || $i > 255) exit 1;
            }
            print $1 "." $2 "." $3 "." $4;
            exit 0;
        }
        { exit 1 }
    '
}

infer_map_target_kind() {
    target="$1"
    case "$target" in
        */32) printf 'host\n' ;;
        */*) printf 'subnet\n' ;;
        *) printf 'host\n' ;;
    esac
}

parse_map_target() {
    target="$1"
    case "$target" in
        */*)
            target_norm="$(normalize_ipv4_cidr "$target" 2>/dev/null || true)"
            [ -n "$target_norm" ] || return 1
            target_host="${target%/*}"
            target_host_norm="$(normalize_ipv4_host "$target_host" 2>/dev/null || true)"
            [ -n "$target_host_norm" ] || return 1
            if [ "$target_norm" = "$target_host_norm/32" ]; then
                printf 'host|%s\n' "$target_host_norm"
            elif [ "$target_norm" = "$target" ]; then
                printf 'subnet|%s\n' "$target_norm"
            else
                printf 'host|%s\n' "$target_host_norm"
            fi
            ;;
        *)
            target_host_norm="$(normalize_ipv4_host "$target" 2>/dev/null || true)"
            [ -n "$target_host_norm" ] || return 1
            printf 'host|%s\n' "$target_host_norm"
            ;;
    esac
}

ensure_openvpn_profile_safety_flags() {
    ovpn_file="$1"
    [ -f "$ovpn_file" ] || return 0
    grep -q '^route-noexec$' "$ovpn_file" 2>/dev/null || printf '%s\n' 'route-noexec' >> "$ovpn_file"
}

validate_client_certificate_if_possible() {
    cert_file="$1"
    command -v openssl >/dev/null 2>&1 || return 0

    cert_subject="$(openssl x509 -noout -subject -in "$cert_file" 2>/dev/null || true)"
    [ -n "$cert_subject" ] || return 0

    case "$cert_subject" in
        *Server*|*server*)
            die "client certificate validate failed: this certificate subject looks like a server certificate ($cert_subject)"
            ;;
        *CA*|*Device\ CA*)
            die "client certificate validate failed: this certificate subject looks like a CA certificate ($cert_subject)"
            ;;
    esac
}

validate_client_cert_key_match_if_possible() {
    cert_file="$1"
    key_file="$2"
    command -v openssl >/dev/null 2>&1 || return 0

    cert_hash="$(openssl x509 -in "$cert_file" -pubkey -noout 2>/dev/null | openssl pkey -pubin -outform der 2>/dev/null | md5sum 2>/dev/null | awk '{print $1}')"
    key_hash="$(openssl pkey -in "$key_file" -pubout -outform der 2>/dev/null | md5sum 2>/dev/null | awk '{print $1}')"

    [ -n "$cert_hash" ] && [ -n "$key_hash" ] || return 0
    [ "$cert_hash" = "$key_hash" ] || die "client key validate failed: private key does not match client certificate"
}

fix_openclash_luci_compat() {
    oc_overwrite="/usr/lib/lua/luci/model/cbi/openclash/config-overwrite.lua"
    [ -f "$oc_overwrite" ] || return 0

    if grep -q 'datatype.cidr4(value)' "$oc_overwrite"; then
        backup_file "$oc_overwrite"
        sed -i 's/if datatype.cidr4(value) then/if ((datatype.cidr4 and datatype.cidr4(value)) or (datatype.ipmask4 and datatype.ipmask4(value))) then/' "$oc_overwrite"
    fi
}

write_openclash_switch_dashboard_template() {
    mkdir -p /usr/lib/lua/luci/view/openclash
    backup_file /usr/lib/lua/luci/view/openclash/switch_dashboard.htm

    cat > /usr/lib/lua/luci/view/openclash/switch_dashboard.htm <<'EOF'
<%+cbi/valueheader%>
<style type="text/css">
.cbi-value-field #switch_dashboard_Dashboard input[type="button"],
.cbi-value-field #switch_dashboard_Yacd input[type="button"],
.cbi-value-field #switch_dashboard_Metacubexd input[type="button"],
.cbi-value-field #switch_dashboard_Zashboard input[type="button"],
.cbi-value-field #delete_dashboard_Dashboard input[type="button"],
.cbi-value-field #delete_dashboard_Yacd input[type="button"],
.cbi-value-field #delete_dashboard_Metacubexd input[type="button"],
.cbi-value-field #delete_dashboard_Zashboard input[type="button"],
.cbi-value-field #default_dashboard_Dashboard input[type="button"],
.cbi-value-field #default_dashboard_Yacd input[type="button"],
.cbi-value-field #default_dashboard_Metacubexd input[type="button"],
.cbi-value-field #default_dashboard_Zashboard input[type="button"] {
	display: inline-block !important;
	min-width: 210px !important;
	padding: 6px 14px !important;
	margin: 0 8px 6px 0 !important;
	border: 1px solid #3b82f6 !important;
	border-radius: 8px !important;
	background: #ffffff !important;
	color: #1f2937 !important;
	font-weight: 600 !important;
	box-shadow: 0 1px 2px rgba(0,0,0,.08) !important;
	cursor: pointer !important;
}
</style>
<%
local uci = require "luci.model.uci".cursor()
local dashboard_type = uci:get("openclash", "config", "dashboard_type") or "Official"
local yacd_type = uci:get("openclash", "config", "yacd_type") or "Official"
local option_name = self.option or ""
local switch_title = ""
local switch_target = ""

if option_name == "Dashboard" then
    switch_title = dashboard_type == "Meta" and "Switch To Official Version" or "Switch To Meta Version"
    switch_target = dashboard_type == "Meta" and "Official" or "Meta"
elseif option_name == "Yacd" then
    switch_title = yacd_type == "Meta" and "Switch To Official Version" or "Switch To Meta Version"
    switch_target = yacd_type == "Meta" and "Official" or "Meta"
elseif option_name == "Metacubexd" then
    switch_title = "Update Metacubexd Version"
    switch_target = "Official"
elseif option_name == "Zashboard" then
    switch_title = "Update Zashboard Version"
    switch_target = "Official"
end
%>
<div class="cbi-value-field" id="switch_dashboard_<%=self.option%>">
	<% if switch_title ~= "" then %>
	<input type="button" class="btn cbi-button cbi-button-reset" value="<%=switch_title%>" onclick="return switch_dashboard(this, '<%=option_name%>', '<%=switch_target%>')"/>
	<% else %>
	<%:Collecting data...%>
	<% end %>
</div>
<div class="cbi-value-field" id="delete_dashboard_<%=self.option%>">
	<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Delete%>" onclick="return delete_dashboard(this, '<%=self.option%>')"/>
</div>
<div class="cbi-value-field" id="default_dashboard_<%=self.option%>">
	<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Set to Default%>" onclick="return default_dashboard(this, '<%=self.option%>')"/>
</div>

<script type="text/javascript">//<![CDATA[
	var btn_type_<%=self.option%> = "<%=self.option%>";
	var switch_dashboard_<%=self.option%> = document.getElementById('switch_dashboard_<%=self.option%>');
	var default_dashboard_<%=self.option%> = document.getElementById('default_dashboard_<%=self.option%>');
	var delete_dashboard_<%=self.option%> = document.getElementById('delete_dashboard_<%=self.option%>');
	XHR.get('<%=luci.dispatcher.build_url("admin", "services", "openclash", "dashboard_type")%>', null, function(x, status) {
	      	if ( x && x.status == 200 ) {
			if ( btn_type_<%=self.option%> == "Dashboard" ) {
				if ( status.dashboard_type == "Meta" ) {
					switch_dashboard_<%=self.option%>.innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Switch To Official Version%>" onclick="return switch_dashboard(this, btn_type_<%=self.option%>, \'Official\')"/>';
				}
				else {
					switch_dashboard_<%=self.option%>.innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Switch To Meta Version%>" onclick="return switch_dashboard(this, btn_type_<%=self.option%>, \'Meta\')"/>';
				}
			}
			if ( btn_type_<%=self.option%> == "Yacd" ) {
				if ( status.yacd_type == "Meta" ) {
					switch_dashboard_<%=self.option%>.innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Switch To Official Version%>" onclick="return switch_dashboard(this, btn_type_<%=self.option%>, \'Official\')"/>';
				}
				else {
					switch_dashboard_<%=self.option%>.innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Switch To Meta Version%>" onclick="return switch_dashboard(this, btn_type_<%=self.option%>, \'Meta\')"/>';
				}
			}
			if ( btn_type_<%=self.option%> == "Metacubexd" ) {
				switch_dashboard_<%=self.option%>.innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Update Metacubexd Version%>" onclick="return switch_dashboard(this, btn_type_<%=self.option%>, \'Official\')"/>';
			}
	      	if ( btn_type_<%=self.option%> == "Zashboard" ) {
				switch_dashboard_<%=self.option%>.innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Update Zashboard Version%>" onclick="return switch_dashboard(this, btn_type_<%=self.option%>, \'Official\')"/>';
			}

			if ( status.default_dashboard == btn_type_<%=self.option%>.toLowerCase() ) {
				default_dashboard_<%=self.option%>.innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Default%>" disabled="disabled" onclick="return default_dashboard(this, btn_type_<%=self.option%>)"/>';
			}

			if ( !status[btn_type_<%=self.option%>.toLowerCase()] ) {
				default_dashboard_<%=self.option%>.firstElementChild.disabled = true;
				delete_dashboard_<%=self.option%>.firstElementChild.disabled = true;
			}
	        }
		});

	function switch_dashboard(btn, name, type)
	{
		btn.disabled = true;
		btn.value = '<%:Downloading File...%>';
		XHR.get('<%=luci.dispatcher.build_url("admin", "services", "openclash", "switch_dashboard")%>', {name: name, type : type}, function(x, status) {
			if ( x && x.status == 200 ) {
				if ( status.download_state == "0" ) {
					if ( type == "Meta" ) {
						if ( name == "Dashboard" ) {
							document.getElementById("switch_dashboard_"+name).innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Switch Successful%> - <%:Switch To Official Version%>" onclick="return switch_dashboard(this, \'Dashboard\', \'Official\')"/>';
						}
						else
						{
							document.getElementById("switch_dashboard_"+name).innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Switch Successful%> - <%:Switch To Official Version%>" onclick="return switch_dashboard(this, \'Yacd\', \'Official\')"/>';
						}
					}
					else {
						if ( name == "Dashboard" ) {
							document.getElementById("switch_dashboard_"+name).innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Switch Successful%> - <%:Switch To Meta Version%>" onclick="return switch_dashboard(this, \'Dashboard\', \'Meta\')"/>';
						}
						else if ( name == "Yacd" ) 
						{
							document.getElementById("switch_dashboard_"+name).innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Switch Successful%> - <%:Switch To Meta Version%>" onclick="return switch_dashboard(this, \'Yacd\', \'Meta\')"/>';
						}
						else if ( name == "Metacubexd" ) {
							document.getElementById("switch_dashboard_"+name).innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Update Successful%> - <%:Update Metacubexd Version%>" onclick="return switch_dashboard(this, \'Metacubexd\', \'Official\')"/>';
						} else {
							document.getElementById("switch_dashboard_"+name).innerHTML = '<input type="button" class="btn cbi-button cbi-button-reset" value="<%:Update Successful%> - <%:Update Zashboard Version%>" onclick="return switch_dashboard(this, \'Zashboard\', \'Official\')"/>';
	            		}
					}
					document.getElementById("default_dashboard_"+name).firstElementChild.disabled = false;
					document.getElementById("delete_dashboard_"+name).firstElementChild.disabled = false;
				}
				else if ( status.download_state == "2" ) {
					btn.value = '<%:Unzip Error%>';
				}
				else {
					if ( name == "Metacubexd" || name == "Zashboard" ) {
						btn.value = '<%:Update Failed%>';
					}
					else {
						btn.value = '<%:Switch Failed%>';
					}
				}
			}
		});
		btn.disabled = false;
		return false; 
	}

	function delete_dashboard(btn, name)
	{
		if ( confirm("<%:Are you sure you want to delete this panel?%>") ) {
			btn.disabled = true;
			XHR.get('<%=luci.dispatcher.build_url("admin", "services", "openclash", "delete_dashboard")%>', {name: name}, function(x, status) {
				if ( x && x.status == 200 ) {
					if ( status.delete_state == "1" ) {
						if ( document.getElementById('default_dashboard_' + name).firstElementChild.disabled ) {
							document.getElementById('default_dashboard_' + name).firstElementChild.value = '<%:Set to Default%>';
						}
						document.getElementById('default_dashboard_' + name).firstElementChild.disabled = true;
					}
					else {
						btn.disabled = false;
					}
				}
			});
		}
		return false; 
	}

	function default_dashboard(btn, name)
	{
		btn.disabled = true;
		XHR.get('<%=luci.dispatcher.build_url("admin", "services", "openclash", "default_dashboard")%>', {name: name}, function(x, status) {
			if ( x && x.status == 200 ) {
				btn.value = '<%:Default%>';
				btn.disabled = true;
				var allBtns = document.querySelectorAll('[id^="default_dashboard_"]');
				for (var i = 0; i < allBtns.length; i++) {
					var btnEl = allBtns[i].firstElementChild;
					if (btnEl && btnEl !== btn && btnEl.value === '<%:Default%>') {
						btnEl.disabled = false;
						btnEl.value = '<%:Set to Default%>';
					}
				}
			} else {
				btn.disabled = false;
			}
		});
		return false;
	}

//]]></script>

<%+cbi/valuefooter%>
EOF
}

patch_openclash_switch_mode_template() {
    file="/usr/lib/lua/luci/view/openclash/switch_mode.htm"
    [ -f "$file" ] || return 0
    grep -q 'cbi-button-reset' "$file" || return 0

    backup_file "$file"
    sed -i 's/btn cbi-button cbi-button-reset/btn cbi-button/g' "$file"
}

patch_openclash_dashboard_settings() {
    settings="/usr/lib/lua/luci/model/cbi/openclash/settings.lua"
    [ -f "$settings" ] || return 0

    if ! grep -q 'o.rawhtml = true' "$settings"; then
        backup_file "$settings"
        sed -i '/o.template="openclash\/switch_dashboard"/a\	o.rawhtml = true' "$settings"
    fi
}

patch_openclash_cidr6_compat() {
    settings="/usr/lib/lua/luci/model/cbi/openclash/settings.lua"
    [ -f "$settings" ] || return 0
    grep -q 'datatype.cidr6(value)' "$settings" || return 0
    grep -q 'datatype.cidr6 or datatype.ipmask6' "$settings" && return 0

    backup_file "$settings"
    sed -i 's/datatype\.cidr6(value)/(datatype.cidr6 or datatype.ipmask6)(value)/' "$settings"
}

install_openclash() {
    require_nradio_oem_appcenter

    mkdir -p "$WORKDIR/openclash/pkg" "$WORKDIR/openclash/control"
    log_stage 1 7 "$OPENCLASH_DISPLAY_NAME 镜像探测与安装规划"
    optimize_openclash_cdn_order
    log "下一步将下载 $OPENCLASH_DISPLAY_NAME 安装包并修改系统文件: /etc/config/appcenter 和 $TPL"
    confirm_or_exit "确认继续安装 $OPENCLASH_DISPLAY_NAME 并修改系统吗？"
    version_file="$WORKDIR/openclash/version"
    raw_ipk="$WORKDIR/openclash/openclash.ipk"
    fixed_ipk="$WORKDIR/openclash/openclash-fixed.ipk"

    log_stage 2 7 "下载 $OPENCLASH_DISPLAY_NAME 元数据与安装包"
    log "提示: 正在下载 $OPENCLASH_DISPLAY_NAME 版本文件..."
    download_from_mirrors "version" "$version_file" || die "无法从全部镜像获取 $OPENCLASH_DISPLAY_NAME 版本文件"
    mirror_base="$LAST_DOWNLOAD_SOURCE"
    last_ver="$(sed -n '1p' "$version_file" | sed 's/^v//g' | tr -d '\r\n')"
    [ -n "$last_ver" ] || die "无法解析 $OPENCLASH_DISPLAY_NAME 版本号"

    log "提示: 正在下载 $OPENCLASH_DISPLAY_NAME v$last_ver 安装包..."
    package_rel="luci-app-openclash_${last_ver}_all.ipk"
    package_urls="$(build_urls_from_base_list "$package_rel" "$OPENCLASH_MIRRORS")"
    package_probe_min_bytes="$(( (OPENCLASH_PACKAGE_PROBE_BYTES + 1) / 2 ))"
    rank_hosts_by_partial_download_probe "openclash-package" "$OPENCLASH_DISPLAY_NAME 安装包" "$package_urls" "$OPENCLASH_PACKAGE_PROBE_BYTES" "$package_probe_min_bytes"
    package_mirrors="$OPENCLASH_MIRRORS"
    if [ -n "$RANKED_URL_HOSTS" ]; then
        package_mirrors="$(reorder_urls_by_host_rank "$OPENCLASH_MIRRORS" "$RANKED_URL_HOSTS")"
        log "提示: $OPENCLASH_DISPLAY_NAME 安装包镜像优先级: $RANKED_URL_HOSTS"
    fi
    log "提示: $OPENCLASH_DISPLAY_NAME 安装包下载已放宽慢速判定与总时长限制，慢速网络下可能持续较久，请耐心等待"
    package_download_max_time_saved="$DOWNLOAD_MAX_TIME"
    package_download_stall_time_saved="$DOWNLOAD_STALL_TIME"
    package_download_stall_speed_saved="$DOWNLOAD_STALL_SPEED"
    package_download_keep_partial_saved="${DOWNLOAD_KEEP_PARTIAL:-0}"
    DOWNLOAD_MAX_TIME="$OPENCLASH_PACKAGE_MAX_TIME"
    DOWNLOAD_STALL_TIME="$OPENCLASH_PACKAGE_STALL_TIME"
    DOWNLOAD_STALL_SPEED="$OPENCLASH_PACKAGE_STALL_SPEED"
    DOWNLOAD_KEEP_PARTIAL=1
    package_mirror_base=""
    if download_from_mirrors "$package_rel" "$raw_ipk" "$package_mirrors"; then
        package_mirror_base="$LAST_DOWNLOAD_SOURCE"
    fi
    if [ -z "$package_mirror_base" ]; then
        log "提示: 首轮 $OPENCLASH_DISPLAY_NAME 安装包下载未完成，正在以更宽松的速度阈值继续重试..."
        DOWNLOAD_STALL_TIME="$OPENCLASH_PACKAGE_RETRY_STALL_TIME"
        DOWNLOAD_STALL_SPEED="$OPENCLASH_PACKAGE_RETRY_STALL_SPEED"
        if download_from_mirrors "$package_rel" "$raw_ipk" "$package_mirrors"; then
            package_mirror_base="$LAST_DOWNLOAD_SOURCE"
        else
            package_mirror_base=""
        fi
    fi
    DOWNLOAD_MAX_TIME="$package_download_max_time_saved"
    DOWNLOAD_KEEP_PARTIAL="$package_download_keep_partial_saved"
    if [ -z "$package_mirror_base" ]; then
        DOWNLOAD_MAX_TIME="$package_download_max_time_saved"
        DOWNLOAD_STALL_TIME="$package_download_stall_time_saved"
        DOWNLOAD_STALL_SPEED="$package_download_stall_speed_saved"
        rm -f "$raw_ipk.tmp"
        die "$OPENCLASH_DISPLAY_NAME 安装包下载失败"
    fi
    DOWNLOAD_MAX_TIME="$package_download_max_time_saved"
    DOWNLOAD_STALL_TIME="$package_download_stall_time_saved"
    DOWNLOAD_STALL_SPEED="$package_download_stall_speed_saved"
    [ -s "$raw_ipk" ] || die "$OPENCLASH_DISPLAY_NAME 安装包下载失败"
    oc_download_size="$(wc -c < "$raw_ipk" | tr -d ' ')"
    log "已下载: $OPENCLASH_DISPLAY_NAME v$last_ver ($oc_download_size bytes)"
    [ -n "${package_mirror_base:-}" ] && log "安装包来源: $package_mirror_base"

    log_stage 3 7 "刷新 opkg 软件源并检查依赖"
    ensure_opkg_update
    ensure_packages dnsmasq-full bash curl ca-bundle ip-full ruby ruby-yaml kmod-inet-diag kmod-nft-tproxy kmod-tun unzip

    log_stage 4 7 "重打包并安装 $OPENCLASH_DISPLAY_NAME"
    extract_ipk_archive "$raw_ipk" "$WORKDIR/openclash/pkg"
    [ -f "$WORKDIR/openclash/pkg/control.tar.gz" ] || die "$OPENCLASH_DISPLAY_NAME 安装包缺少 control.tar.gz"
    [ -f "$WORKDIR/openclash/pkg/data.tar.gz" ] || die "$OPENCLASH_DISPLAY_NAME 安装包缺少 data.tar.gz"
    [ -f "$WORKDIR/openclash/pkg/debian-binary" ] || die "$OPENCLASH_DISPLAY_NAME 安装包缺少 debian-binary"
    tar -xzf "$WORKDIR/openclash/pkg/control.tar.gz" -C "$WORKDIR/openclash/control"
    sed -i \
        -e 's/, *luci-compat//g' \
        -e 's/luci-compat, *//g' \
        -e 's/luci-compat//g' \
        "$WORKDIR/openclash/control/control"
    tar -czf "$WORKDIR/openclash/pkg/control.tar.gz" -C "$WORKDIR/openclash/control" .
    (cd "$WORKDIR/openclash/pkg" && tar -czf "$fixed_ipk" ./debian-binary ./data.tar.gz ./control.tar.gz)
    [ -s "$fixed_ipk" ] || die "无法重新打包 $OPENCLASH_DISPLAY_NAME 安装包"

    backup_file "$CFG"
    if ! opkg install "$fixed_ipk" --force-reinstall >/tmp/openclash-install.log 2>&1; then
        if ! opkg install "$fixed_ipk" --force-reinstall --force-depends --force-maintainer >/tmp/openclash-install.log 2>&1; then
            sed -n '1,200p' /tmp/openclash-install.log >&2
            die "$OPENCLASH_DISPLAY_NAME 安装失败"
        fi
    fi

    oc_ver="$(opkg status luci-app-openclash 2>/dev/null | awk -F': ' '/Version: /{print $2; exit}')"
    [ -n "$oc_ver" ] || oc_ver="$last_ver"
    oc_size="$(wc -c < "$fixed_ipk" | tr -d ' ')"

    log_stage 5 7 "写入 LuCI、图标与应用商店接入"
    oc_icon_name=""
    if install_openclash_embedded_icon; then
        oc_icon_name="$OPENCLASH_ICON_NAME"
    fi
    set_appcenter_entry "luci-app-openclash" "luci-app-openclash" "$oc_ver" "$oc_size" "/usr/lib/lua/luci/controller/openclash.lua" "admin/services/openclash" "$oc_icon_name"
    uci commit appcenter

    fix_openclash_luci_compat
    write_openclash_switch_dashboard_template
    patch_openclash_switch_mode_template
    patch_openclash_dashboard_settings
    patch_openclash_cidr6_compat
    write_plugin_uninstall_assets
    patch_common_template
    refresh_luci_appcenter
    ensure_plugin_autostart_order
    log_stage 6 7 "检查并写入虚拟内存（swap）配置"
    ensure_openclash_swap_setup
    reduce_openclash_memory_pressure
    verify_appcenter_route "luci-app-openclash" "admin/services/openclash"
    verify_file_exists /usr/lib/lua/luci/controller/openclash.lua "$OPENCLASH_DISPLAY_NAME"
    verify_luci_route admin/services/openclash "$OPENCLASH_DISPLAY_NAME"
    verify_luci_route admin/services/openclash/settings "$OPENCLASH_DISPLAY_NAME"
    verify_luci_route admin/services/openclash/config-overwrite "$OPENCLASH_DISPLAY_NAME"
    verify_luci_route admin/services/openclash/config-subscribe "$OPENCLASH_DISPLAY_NAME"
    verify_luci_route admin/services/openclash/config "$OPENCLASH_DISPLAY_NAME"
    verify_luci_route admin/services/openclash/log "$OPENCLASH_DISPLAY_NAME"

    log_stage 7 7 "可选下载 smart 内核并完成最终校验"
    smart_core_downloaded='0'
    if confirm_default_yes "是否现在下载 $OPENCLASH_SMART_DISPLAY_NAME？"; then
        install_openclash_smart_core
        smart_core_downloaded='1'
        verify_file_exists /etc/openclash/core/clash_meta "$OPENCLASH_SMART_DISPLAY_NAME"
        verify_file_exists /etc/openclash/core/clash "$OPENCLASH_SMART_DISPLAY_NAME"
        log "备注:     smart core 已安装到 /etc/openclash/core"
    else
        log "备注:     已跳过 smart core 下载"
    fi

    log "安装完成"
    log "插件:   $OPENCLASH_DISPLAY_NAME"
    log "版本:  $oc_ver"
    log "路由:    admin/services/openclash"
    if [ "$smart_core_downloaded" = '1' ]; then
        log "核心:     $OPENCLASH_SMART_DISPLAY_NAME"
        log "核心版本: $smart_core_ver"
        log "核心路径: /etc/openclash/core"
    else
        log "核心:     未下载"
    fi
    log "下一步: 关闭应用商店弹窗后按 Ctrl+F5，再重新打开 $OPENCLASH_DISPLAY_NAME"
}

write_adguard_wrapper_files() {
    mkdir -p /usr/lib/lua/luci/controller /usr/lib/lua/luci/view/AdGuardHome
    cat > /usr/lib/lua/luci/controller/AdGuardHome.lua <<'EOF'
module("luci.controller.AdGuardHome",package.seeall)
local fs=require"nixio.fs"
local http=require"luci.http"
local sys=require"luci.sys"
local uci=require"luci.model.uci".cursor()
function index()
entry({"admin", "services", "AdGuardHome"},alias("admin", "services", "AdGuardHome", "oem"),_("AdGuard Home"), 10).dependent = true
entry({"admin","services","AdGuardHome","oem"},template("AdGuardHome/oem_wrapper"),_("Overview"),0).leaf = true
entry({"admin","services","AdGuardHome","base"},cbi("AdGuardHome/base"),_("Base Setting"),1).leaf = true
entry({"admin","services","AdGuardHome","log"},form("AdGuardHome/log"),_("Log"),2).leaf = true
entry({"admin","services","AdGuardHome","manual"},cbi("AdGuardHome/manual"),_("Manual Config"),3).leaf = true
entry({"admin", "services", "AdGuardHome", "status"},call("act_status")).leaf=true
entry({"admin", "services", "AdGuardHome", "check"}, call("check_update"))
entry({"admin", "services", "AdGuardHome", "doupdate"}, call("do_update"))
entry({"admin", "services", "AdGuardHome", "getlog"}, call("get_log"))
entry({"admin", "services", "AdGuardHome", "dodellog"}, call("do_dellog"))
entry({"admin", "services", "AdGuardHome", "reloadconfig"}, call("reload_config"))
entry({"admin", "services", "AdGuardHome", "gettemplateconfig"}, call("get_template_config"))
end
function get_template_config()
local b
local d=""
local rf=io.open("/tmp/resolv.conf.auto", "r")
if rf then
local lan_ip = uci:get("network", "lan", "ipaddr") or ""
for cnt in rf:lines() do
b=string.match (cnt,"^[^#]*nameserver%s+([^%s]+)$")
if (b~=nil) and not b:match("^127%.") and b ~= "0.0.0.0" and b ~= "::1" and b ~= lan_ip then
d=d.."  - "..b.."\n"
end
end
rf:close()
end
local f=io.open("/usr/share/AdGuardHome/AdGuardHome_template.yaml", "r+")
if not f then
http.prepare_content("text/plain; charset=utf-8")
http.write("")
return
end
local tbl = {}
local a=""
while (1) do
a=f:read("*l")
if (a=="#bootstrap_dns") then
a=d
elseif (a=="#upstream_dns") then
a=d
elseif (a==nil) then
break
end
table.insert(tbl, a)
end
f:close()
http.prepare_content("text/plain; charset=utf-8")
http.write(table.concat(tbl, "\n"))
end
function reload_config()
fs.remove("/tmp/AdGuardHometmpconfig.yaml")
http.prepare_content("application/json")
http.write('')
end
function act_status()
local e={}
local binpath=uci:get("AdGuardHome","AdGuardHome","binpath")
    e.running=sys.call("pgrep "..binpath.." >/dev/null")==0
e.redirect=(fs.readfile("/var/run/AdGredir")=="1")
http.prepare_content("application/json")
http.write_json(e)
end
function do_update()
fs.writefile("/var/run/lucilogpos","0")
http.prepare_content("application/json")
http.write('')
local arg
if luci.http.formvalue("force") == "1" then
arg="force"
else
arg=""
end
if fs.access("/var/run/update_core") then
if arg=="force" then
    sys.exec("kill $(pgrep /usr/share/AdGuardHome/update_core.sh) ; sh /usr/share/AdGuardHome/update_core.sh "..arg.." >/tmp/AdGuardHome_update.log 2>&1 &")
end
else
    sys.exec("sh /usr/share/AdGuardHome/update_core.sh "..arg.." >/tmp/AdGuardHome_update.log 2>&1 &")
end
end
function get_log()
local logfile=uci:get("AdGuardHome","AdGuardHome","logfile")
if (logfile==nil) then
http.write("no log available\n")
return
end
local data=fs.readfile(logfile)
if (data) then
http.write(data)
else
http.write("can't open log file\n")
end
end
function do_dellog()
local logfile=uci:get("AdGuardHome","AdGuardHome","logfile")
if (logfile) then
fs.writefile(logfile,"")
end
http.prepare_content("application/json")
http.write('')
end
function check_update()
local e={}
    local pkg_ver=sys.exec("grep PKG_VERSION /usr/share/AdGuardHome/Makefile 2>/dev/null | awk -F := '{print $2}'")
e.luciversion=string.sub(pkg_ver,1,-2)
e.coreversion=uci:get("AdGuardHome","AdGuardHome","coreversion") or ""
http.prepare_content("application/json")
http.write_json(e)
end
EOF

    cat > /usr/lib/lua/luci/view/AdGuardHome/oem_wrapper.htm <<'EOF'
<%
local dispatcher = require "luci.dispatcher"
local http = require "luci.http"
local base_url = dispatcher.build_url("admin", "services", "AdGuardHome")
local tab = http.formvalue("tab") or "base"
if tab ~= "base" and tab ~= "manual" and tab ~= "log" then
    tab = "base"
end
local frame_url = base_url .. "/" .. tab
%>
<%+header%>
<style>
    .adg-wrap { margin-bottom: 20px; }
    .adg-tabs { display: flex; flex-wrap: wrap; gap: 10px; margin: 12px 0 16px; }
    .adg-tab { display: inline-block; padding: 8px 14px; border-bottom: 2px solid transparent; color: #666; cursor: pointer; }
    .adg-tab.active { color: #0088cc; border-bottom-color: #0088cc; }
    .adg-frame { width: 100%; min-height: 760px; border: 0; background: #fff; }
</style>
<div class="cbi-map adg-wrap">
    <h2 name="content">AdGuard Home</h2>
    <div class="cbi-map-descr">OEM compatibility wrapper for AdGuard Home pages.</div>
    <div class="adg-tabs">
        <a class="adg-tab<%= tab == 'base' and ' active' or '' %>" data-tab="base" href="<%=base_url%>?tab=base">Base Setting</a>
        <a class="adg-tab<%= tab == 'manual' and ' active' or '' %>" data-tab="manual" href="<%=base_url%>?tab=manual">Manual Config</a>
        <a class="adg-tab<%= tab == 'log' and ' active' or '' %>" data-tab="log" href="<%=base_url%>?tab=log">Log</a>
    </div>
    <iframe id="adg_frame" class="adg-frame" name="adg_frame" src="<%=frame_url%>" onload="adgAfterLoad()"></iframe>
</div>
<script>
function adgResizeFrame() {
    var frame = document.getElementById('adg_frame');
    if (!frame) return;
    try {
        var d = frame.contentWindow.document;
        var h1 = d.body ? d.body.scrollHeight : 0;
        var h2 = d.documentElement ? d.documentElement.scrollHeight : 0;
        var height = Math.max(h1, h2, 760);
        frame.style.height = height + 'px';
    } catch (e) {}
}
function adgHideInnerChrome() {
    var frame = document.getElementById('adg_frame');
    if (!frame) return;
    try {
        var d = frame.contentWindow.document;
        var hideSelectors = ['header', '.menu_mobile', '.mobile_bg_color.container.body-container.visible-xs-block', '.footer', '.tail_wave'];
        for (var i = 0; i < hideSelectors.length; i++) {
            var nodes = d.querySelectorAll(hideSelectors[i]);
            for (var j = 0; j < nodes.length; j++) nodes[j].style.display = 'none';
        }
        var containers = d.querySelectorAll('.container.body-container');
        for (var k = 0; k < containers.length; k++) {
            if (!containers[k].classList.contains('visible-xs-block')) {
                containers[k].style.width = '100%';
                containers[k].style.margin = '0';
                containers[k].style.padding = '0 10px';
            }
        }
        var main = d.querySelector('.main');
        if (main) { main.style.width = '100%'; main.style.margin = '0'; }
        var content = d.querySelector('.main-content');
        if (content) { content.style.width = '100%'; content.style.margin = '0'; content.style.padding = '0'; }
        if (d.body) { d.body.style.marginTop = '0'; d.body.style.paddingTop = '0'; }
    } catch (e) {}
}
function adgAfterLoad() {
    adgHideInnerChrome();
    adgResizeFrame();
    setTimeout(function() { adgHideInnerChrome(); adgResizeFrame(); }, 300);
}
</script>
<%+footer%>
EOF
}

patch_adguard_enable_hook() {
    base_lua="/usr/lib/lua/luci/model/cbi/AdGuardHome/base.lua"
    [ -f "$base_lua" ] || return 0
    grep -q '/etc/init.d/AdGuardHome enable >/dev/null 2>&1; /etc/init.d/AdGuardHome restart >/dev/null 2>&1 &' "$base_lua" 2>/dev/null && return 0

    backup_file "$base_lua"
    mkdir -p "$WORKDIR/adguardhome"
    tmp_file="$WORKDIR/adguardhome/base.lua"
    awk '
        BEGIN { in_hook = 0 }
        /^function m\.on_commit\(map\)$/ {
            in_hook = 1
            print "function m.on_commit(map)"
            print "\tlocal enabled=uci:get(\"AdGuardHome\",\"AdGuardHome\",\"enabled\")"
            print "\tif enabled==\"1\" then"
            print "\t\tio.popen(\"/etc/init.d/AdGuardHome enable >/dev/null 2>&1; /etc/init.d/AdGuardHome restart >/dev/null 2>&1 &\")"
            print "\telse"
            print "\t\tio.popen(\"/etc/init.d/AdGuardHome disable >/dev/null 2>&1; /etc/init.d/AdGuardHome stop >/dev/null 2>&1 &\")"
            print "\tend"
            next
        }
        in_hook {
            if ($0 ~ /^return m$/) {
                in_hook = 0
                print "end"
                print
            }
            next
        }
        { print }
    ' "$base_lua" > "$tmp_file" && mv "$tmp_file" "$base_lua"
}

get_adguard_configpath() {
    adg_configpath="$(uci -q get AdGuardHome.AdGuardHome.configpath 2>/dev/null || true)"
    [ -n "$adg_configpath" ] || adg_configpath="/etc/AdGuardHome.yaml"
    printf '%s\n' "$adg_configpath"
}

is_adguard_placeholder_config() {
    yaml_file="$1"
    [ -s "$yaml_file" ] || return 1

    grep -q '^bind_host: 0\.0\.0\.0$' "$yaml_file" 2>/dev/null || return 1
    grep -q '^bind_port: ' "$yaml_file" 2>/dev/null || return 1
    grep -q '^#bootstrap_dns$' "$yaml_file" 2>/dev/null || return 1
    grep -q '^#upstream_dns$' "$yaml_file" 2>/dev/null || return 1
    grep -q '^- name: root$' "$yaml_file" 2>/dev/null || return 1
    return 0
}

cleanup_adguard_placeholder_config() {
    configpath="$(get_adguard_configpath)"
    [ -s "$configpath" ] || return 0
    is_adguard_placeholder_config "$configpath" || return 0

    backup_file "$configpath"
    rm -f "$configpath"
    log "备注:     已移除占位 AdGuardHome 配置，保留首次启动向导"
}

fix_adguard_runtime_if_possible() {
    binpath="$(uci -q get AdGuardHome.AdGuardHome.binpath 2>/dev/null || true)"
    [ -n "$binpath" ] || binpath="/usr/bin/AdGuardHome/AdGuardHome"
    [ -x "$binpath" ] || return 0

    configpath="$(get_adguard_configpath)"
    workdir="$(uci -q get AdGuardHome.AdGuardHome.workdir 2>/dev/null || true)"
    [ -n "$workdir" ] || workdir="/usr/bin/AdGuardHome"
    template_yaml="/usr/share/AdGuardHome/AdGuardHome_template.yaml"

    ensure_adguard_session_ttl() {
        yaml_file="$1"
        [ -f "$yaml_file" ] || return 0

        if grep -q '^  session_ttl: ' "$yaml_file" 2>/dev/null; then
            sed -i 's/^  session_ttl: .*/  session_ttl: 720h/' "$yaml_file"
        elif grep -q '^bind_port:' "$yaml_file" 2>/dev/null; then
            awk '
                {
                    print
                    if (!done && $0 ~ /^bind_port:/) {
                        print "session_ttl: 720h"
                        done = 1
                    }
                }
            ' "$yaml_file" > "$yaml_file.tmp" && mv "$yaml_file.tmp" "$yaml_file"
        fi
    }

    ensure_adguard_session_ttl "$template_yaml"
    mkdir -p "$workdir/data" >/dev/null 2>&1 || true
    [ -s "$configpath" ] || return 0

    ensure_adguard_session_ttl "$configpath"
    [ -s "$configpath" ] && "$binpath" -c "$configpath" --check-config >/tmp/AdGuardHometest.log 2>&1 || true
}

get_adguardhome_core_arch() { get_core_arch; }

download_adguardhome_core() {
    optimize_adguardhome_cdn_order
    core_arch="$(get_adguardhome_core_arch 2>/dev/null || true)"
    [ -n "$core_arch" ] || die "无法识别 AdGuardHome 核心架构"

    mkdir -p "$WORKDIR/adguardhome/core" /usr/bin/AdGuardHome
    core_tar="$WORKDIR/adguardhome/AdGuardHome_linux_${core_arch}.tar.gz"
    core_unpack="$WORKDIR/adguardhome/core"
    core_bin="/usr/bin/AdGuardHome/AdGuardHome"

    log "提示: 正在从 CDN 下载 AdGuardHome 核心..."
    download_from_mirrors "AdGuardHome_linux_${core_arch}.tar.gz" "$core_tar" "$ADGUARDHOME_CORE_MIRRORS" || die "无法从全部 CDN 镜像获取 AdGuardHome 核心"
    [ -s "$core_tar" ] || die "AdGuardHome 核心下载失败"

    for existing in "$core_bin"; do
        [ -f "$existing" ] && backup_file "$existing"
    done

    tar -xzf "$core_tar" -C "$core_unpack" >/dev/null 2>&1 || die "AdGuardHome 核心解压失败"

    core_src=""
    for candidate in "$core_unpack"/AdGuardHome "$core_unpack"/*/AdGuardHome "$core_unpack"/*/*/AdGuardHome; do
        [ -f "$candidate" ] || continue
        core_src="$candidate"
        break
    done
    [ -n "$core_src" ] || die "无法定位解压后的 AdGuardHome 核心二进制"

    cp "$core_src" "$core_bin"
    chmod 755 "$core_bin" 2>/dev/null || true
    uci set AdGuardHome.AdGuardHome.coreversion='latest' >/dev/null 2>&1 || true
    uci commit AdGuardHome >/dev/null 2>&1 || true

    log "安装完成"
    log "核心:     AdGuardHome"
    log "版本:  latest"
    log "arch:     $core_arch"
    log "path:     $core_bin"
}

set_init_start_order() {
    init_script="$1"
    start_order="$2"

    [ -f "$init_script" ] || return 0
    if ! grep -q "^START=$start_order$" "$init_script"; then
        backup_file "$init_script"
        sed -i "s/^START=.*/START=$start_order/" "$init_script"
    fi
}

ensure_plugin_autostart_order() {
    set_init_start_order /etc/init.d/openvpn 90
    set_init_start_order /etc/init.d/openclash 98
    set_init_start_order /etc/init.d/AdGuardHome 120
}

get_swapfile_size_bytes() {
    local swapfile="${1:-/overlay/swapfile}"
    [ -f "$swapfile" ] || {
        printf '0\n'
        return 0
    }
    wc -c < "$swapfile" 2>/dev/null | tr -d ' ' || printf '0\n'
}

get_swapfile_size_mib() {
    local swap_bytes
    swap_bytes="$(get_swapfile_size_bytes "${1:-/overlay/swapfile}")"
    case "$swap_bytes" in
        ''|*[!0-9]*) swap_bytes=0 ;;
    esac
    printf '%s\n' "$(( (swap_bytes + 1048575) / 1048576 ))"
}

swapfile_is_active() {
    local swapfile="${1:-/overlay/swapfile}"
    awk -v dev="$swapfile" 'NR > 1 && $1 == dev { found = 1 } END { exit(found ? 0 : 1) }' /proc/swaps 2>/dev/null
}

list_swap_sections_by_device() {
    local device="${1:-/overlay/swapfile}"
    uci -q show fstab 2>/dev/null | awk -v dev="$device" '
        /^fstab\.@swap\[[0-9]+\]\.device=/ {
            sec = $0
            sub(/^fstab\./, "", sec)
            sub(/\.device=.*/, "", sec)

            value = $0
            sub(/^.*\.device=/, "", value)
            gsub(/\047/, "", value)
            if (value == dev)
                print sec
        }
    '
}

ensure_swapfile_boot_config() {
    local swapfile="${1:-/overlay/swapfile}"
    local sec sections first changed current_device current_enabled current_label

    [ -f "$swapfile" ] || return 1

    first=""
    changed=0
    sections="$(list_swap_sections_by_device "$swapfile" 2>/dev/null || true)"
    first="$(printf '%s\n' "$sections" | awk 'NF { print; exit }')"

    for sec in $(printf '%s\n' "$sections" | awk 'NF { item[++count] = $0 } END { for (i = count; i >= 2; i--) print item[i] }'); do
        [ "$changed" -eq 1 ] || backup_file /etc/config/fstab
        uci -q delete fstab."$sec" >/dev/null 2>&1 || true
        changed=1
    done

    if [ -z "$first" ]; then
        backup_file /etc/config/fstab
        first="$(uci -q add fstab swap 2>/dev/null || true)"
        [ -n "$first" ] || return 1
        changed=1
    fi

    current_device="$(uci -q get fstab."$first".device 2>/dev/null || true)"
    current_enabled="$(uci -q get fstab."$first".enabled 2>/dev/null || true)"
    current_label="$(uci -q get fstab."$first".label 2>/dev/null || true)"
    if [ "$changed" -eq 1 ] || [ "$current_device" != "$swapfile" ] || [ "$current_enabled" != '1' ] || [ "$current_label" != 'swapfile' ]; then
        [ "$changed" -eq 1 ] || backup_file /etc/config/fstab
        uci -q set fstab."$first".device="$swapfile" >/dev/null 2>&1 || true
        uci -q set fstab."$first".enabled='1' >/dev/null 2>&1 || true
        uci -q set fstab."$first".label='swapfile' >/dev/null 2>&1 || true
        uci -q commit fstab >/dev/null 2>&1 || true
    fi

    return 0
}

activate_swapfile_if_needed() {
    local swapfile="${1:-/overlay/swapfile}"

    [ -f "$swapfile" ] || return 1
    swapfile_is_active "$swapfile" && return 0
    command -v swapon >/dev/null 2>&1 || return 1
    swapon "$swapfile" >/dev/null 2>&1
}

create_or_resize_swapfile_mib() {
    local target_mib="${1:-0}"
    local swapfile="${2:-/overlay/swapfile}"
    local target_bytes current_bytes required_bytes tmp_swapfile had_active_swap

    case "$target_mib" in
        ''|*[!0-9]*)
            return 1
            ;;
    esac
    [ "$target_mib" -gt 0 ] 2>/dev/null || return 1

    target_bytes="$((target_mib * 1048576))"
    current_bytes="$(get_swapfile_size_bytes "$swapfile")"
    case "$current_bytes" in
        ''|*[!0-9]*) current_bytes=0 ;;
    esac
    required_bytes=0
    had_active_swap='0'
    if [ "$current_bytes" -lt "$target_bytes" ] 2>/dev/null; then
        required_bytes="$((target_bytes - current_bytes))"
    fi

    ensure_dir_writable /overlay "/overlay"
    ensure_free_space_bytes /overlay "$required_bytes" "/overlay"

    if swapfile_is_active "$swapfile"; then
        command -v swapoff >/dev/null 2>&1 || die "系统缺少 swapoff，无法调整虚拟内存"
        had_active_swap='1'
        swapoff "$swapfile" >/dev/null 2>&1 || die "停用现有虚拟内存失败：$swapfile"
    fi

    command -v mkswap >/dev/null 2>&1 || die "系统缺少 mkswap，无法创建虚拟内存"
    tmp_swapfile="$swapfile.tmp.$$"
    rm -f "$tmp_swapfile" 2>/dev/null || true
    dd if=/dev/zero of="$tmp_swapfile" bs=1M count="$target_mib" >/dev/null 2>&1 || {
        rm -f "$tmp_swapfile" 2>/dev/null || true
        [ "$had_active_swap" = '1' ] && activate_swapfile_if_needed "$swapfile" >/dev/null 2>&1 || true
        die "创建 ${target_mib}M 虚拟内存文件失败"
    }
    chmod 600 "$tmp_swapfile" >/dev/null 2>&1 || true
    mkswap "$tmp_swapfile" >/dev/null 2>&1 || {
        rm -f "$tmp_swapfile" 2>/dev/null || true
        [ "$had_active_swap" = '1' ] && activate_swapfile_if_needed "$swapfile" >/dev/null 2>&1 || true
        die "格式化虚拟内存文件失败"
    }
    mv "$tmp_swapfile" "$swapfile" || {
        rm -f "$tmp_swapfile" 2>/dev/null || true
        [ "$had_active_swap" = '1' ] && activate_swapfile_if_needed "$swapfile" >/dev/null 2>&1 || true
        die "写入虚拟内存文件失败：$swapfile"
    }
    chmod 600 "$swapfile" >/dev/null 2>&1 || true
    sync
}

ensure_existing_swap_access() {
    local plugin_name="${1:-当前插件}"
    local swapfile="/overlay/swapfile"
    local swap_mib

    if [ ! -f "$swapfile" ]; then
        log "备注: 未检测到 /overlay/swapfile，$plugin_name 跳过虚拟内存接入"
        return 0
    fi

    swap_mib="$(get_swapfile_size_mib "$swapfile")"
    log "提示: 正在为 $plugin_name 写入虚拟内存接入配置..."
    ensure_swapfile_boot_config "$swapfile" || die "$plugin_name 写入虚拟内存开机配置失败"
    activate_swapfile_if_needed "$swapfile" || die "$plugin_name 启用虚拟内存失败"
    log "备注: 已接入现有虚拟内存（约 ${swap_mib}M）"
}

manage_swapfile() {
    local swapfile="/overlay/swapfile"
    local current_bytes current_mib target_mib final_mib swap_limit_mib

    swap_limit_mib=2048

    current_bytes="$(get_swapfile_size_bytes "$swapfile")"
    case "$current_bytes" in
        ''|*[!0-9]*) current_bytes=0 ;;
    esac
    current_mib="$(( (current_bytes + 1048575) / 1048576 ))"

    if [ "$current_bytes" -gt 0 ] 2>/dev/null && [ "$current_mib" -gt "$swap_limit_mib" ] 2>/dev/null; then
        log "备注: 当前虚拟内存约 ${current_mib}M，已超过菜单 1 的 ${swap_limit_mib}M 上限；将保留当前大小，仅重新写入开机接入配置"
        target_mib="$current_mib"
    elif [ "$current_bytes" -gt 0 ] 2>/dev/null; then
        if ! confirm_default_yes "检测到当前虚拟内存约 ${current_mib}M，是否继续修改扩容？"; then
            log "备注: 已取消虚拟内存调整"
            return 0
        fi

        while :; do
            prompt_with_default "请输入要扩容到的虚拟内存大小（单位 MiB）" "$current_mib"
            target_mib="$PROMPT_RESULT"
            case "$target_mib" in
                ''|*[!0-9]*)
                    log "提示: 请输入纯数字，例如 512、1024"
                    continue
                    ;;
                0)
                    log "提示: swap 大小必须大于 0"
                    continue
                    ;;
            esac
            if [ "$target_mib" -gt "$swap_limit_mib" ] 2>/dev/null; then
                log "提示: 菜单 1 最多只允许扩容到 ${swap_limit_mib}M"
                continue
            fi
            if [ "$target_mib" -lt "$current_mib" ] 2>/dev/null; then
                log "提示: 目标大小不能小于当前约 ${current_mib}M"
                continue
            fi
            break
        done
    else
        while :; do
            prompt_with_default "未检测到 /overlay/swapfile，请输入要创建的虚拟内存大小（单位 MiB）" "512"
            target_mib="$PROMPT_RESULT"
            case "$target_mib" in
                ''|*[!0-9]*)
                    log "提示: 请输入纯数字，例如 256、512、1024"
                    continue
                    ;;
                0)
                    log "提示: swap 大小必须大于 0"
                    continue
                    ;;
            esac
            if [ "$target_mib" -gt "$swap_limit_mib" ] 2>/dev/null; then
                log "提示: 菜单 1 最多只允许扩容到 ${swap_limit_mib}M"
                continue
            fi
            break
        done
    fi

    if [ "$current_bytes" -gt 0 ] 2>/dev/null && [ "$target_mib" -eq "$current_mib" ] 2>/dev/null; then
        log "提示: 当前虚拟内存大小未变化，正在重新写入接入配置..."
    else
        log "提示: 正在写入 ${target_mib}M 虚拟内存，文件较大时可能耗时较长，请耐心等待"
        create_or_resize_swapfile_mib "$target_mib" "$swapfile"
    fi

    ensure_swapfile_boot_config "$swapfile" || die "写入虚拟内存开机配置失败"
    activate_swapfile_if_needed "$swapfile" || die "启用虚拟内存失败"
    final_mib="$(get_swapfile_size_mib "$swapfile")"
    log "备注: 已完成虚拟内存设置（约 ${final_mib}M）"
}

ensure_openclash_swap_setup() {
    ensure_existing_swap_access "$OPENCLASH_DISPLAY_NAME"
}

ensure_swapfile_boot() {
    ensure_swapfile_boot_config "${1:-/overlay/swapfile}" || return 0
}

reduce_openclash_memory_pressure() {
    [ -f /etc/config/openclash ] || return 0

    uci set openclash.config.smart_collect='0' >/dev/null 2>&1 || true
    uci set openclash.config.enable_meta_sniffer='0' >/dev/null 2>&1 || true
    uci set openclash.config.enable_meta_sniffer_pure_ip='0' >/dev/null 2>&1 || true
    uci set openclash.config.enable_meta_sniffer_custom='0' >/dev/null 2>&1 || true
    uci set openclash.config.smart_enable_lgbm='0' >/dev/null 2>&1 || true
    uci set openclash.config.auto_smart_switch='0' >/dev/null 2>&1 || true
    uci set openclash.config.enable_tcp_concurrent='0' >/dev/null 2>&1 || true
    uci set openclash.config.enable_unified_delay='0' >/dev/null 2>&1 || true
    uci set openclash.config.enable_custom_dns='0' >/dev/null 2>&1 || true
    uci set openclash.config.enable_respect_rules='0' >/dev/null 2>&1 || true
    uci commit openclash >/dev/null 2>&1 || true
}

fix_adguard_start_order() {
    set_init_start_order /etc/init.d/AdGuardHome 120
}

install_adguardhome() {
    require_nradio_oem_appcenter

    mkdir -p "$WORKDIR/adguardhome"
    log_stage 1 5 "AdGuardHome 镜像探测与安装规划"
    optimize_adguardhome_cdn_order
    log "下一步将下载 AdGuardHome 安装包并修改系统文件: /etc/config/appcenter, $TPL 和 AdGuardHome LuCI 文件"
    confirm_or_exit "确认继续安装 AdGuardHome 并修改系统吗？"
    adg_luci_reused='0'
    if is_adguardhome_luci_ready; then
        adg_luci_reused='1'
        log "备注:     AdGuardHome LuCI $ADGUARDHOME_VERSION 已存在, 跳过重复安装"
    else
        adg_ipk="$WORKDIR/adguardhome/luci-app-adguardhome.ipk"
        log_stage 2 5 "下载并安装 AdGuardHome LuCI 包"
        log "提示: 正在从 CDN 下载 AdGuardHome 官方发行包..."
        adg_download_stall_time_saved="$DOWNLOAD_STALL_TIME"
        adg_download_stall_speed_saved="$DOWNLOAD_STALL_SPEED"
        adg_download_keep_partial_saved="${DOWNLOAD_KEEP_PARTIAL:-0}"
        DOWNLOAD_KEEP_PARTIAL=1
        adg_download_url=""
        if download_from_urls "$adg_ipk" $ADGUARDHOME_IPK_URLS; then
            adg_download_url="$LAST_DOWNLOAD_SOURCE"
        fi
        if [ -z "$adg_download_url" ]; then
            log "提示: 首轮 AdGuardHome 安装包下载未完成，正在放宽速度阈值后重试..."
            DOWNLOAD_STALL_TIME="$DOWNLOAD_PARTIAL_RETRY_STALL_TIME"
            DOWNLOAD_STALL_SPEED="$DOWNLOAD_PARTIAL_RETRY_STALL_SPEED"
            if download_from_urls "$adg_ipk" $ADGUARDHOME_IPK_URLS; then
                adg_download_url="$LAST_DOWNLOAD_SOURCE"
            else
                adg_download_url=""
            fi
        fi
        DOWNLOAD_STALL_TIME="$adg_download_stall_time_saved"
        DOWNLOAD_STALL_SPEED="$adg_download_stall_speed_saved"
        DOWNLOAD_KEEP_PARTIAL="$adg_download_keep_partial_saved"
        [ -n "$adg_download_url" ] || die "无法从全部 CDN 镜像下载 AdGuardHome 安装包"
        [ -s "$adg_ipk" ] || die "AdGuardHome 安装包下载失败"
        adg_download_size="$(wc -c < "$adg_ipk" | tr -d ' ')"
        log "已下载: AdGuardHome $ADGUARDHOME_VERSION ($adg_download_size bytes)"
        install_ipk_file "$adg_ipk" "AdGuardHome"
    fi

    for needed in \
        /usr/lib/lua/luci/controller/AdGuardHome.lua \
        /usr/lib/lua/luci/model/cbi/AdGuardHome/base.lua \
        /usr/lib/lua/luci/model/cbi/AdGuardHome/manual.lua \
        /usr/lib/lua/luci/model/cbi/AdGuardHome/log.lua \
        /usr/share/AdGuardHome/AdGuardHome_template.yaml; do
        [ -f "$needed" ] || die "AdGuardHome 安装不完整，缺少 $needed"
    done

    log_stage 3 5 "写入 LuCI 包装页与运行时文件"
    backup_file /usr/lib/lua/luci/controller/AdGuardHome.lua
    backup_file /usr/lib/lua/luci/view/AdGuardHome/oem_wrapper.htm

    write_adguard_wrapper_files
    patch_adguard_enable_hook
    fix_adguard_start_order
    cleanup_adguard_placeholder_config

    adg_ver="$(opkg status luci-app-adguardhome 2>/dev/null | awk -F': ' '/Version: /{print $2; exit}')"
    [ -n "$adg_ver" ] || adg_ver="$ADGUARDHOME_VERSION"
    adg_size="$(opkg status luci-app-adguardhome 2>/dev/null | awk -F': ' '/Installed-Size: /{print $2; exit}')"
    [ -n "$adg_size" ] || adg_size="91326"

    log_stage 4 5 "写入图标、应用商店入口、虚拟内存并校验 LuCI 路由"
    backup_file "$CFG"
    adg_icon_name=""
    if install_adguardhome_embedded_icon; then
        adg_icon_name="$ADGUARDHOME_ICON_NAME"
    fi
    set_appcenter_entry "luci-app-adguardhome" "luci-app-adguardhome" "$adg_ver" "$adg_size" "/usr/lib/lua/luci/controller/AdGuardHome.lua" "admin/services/AdGuardHome" "$adg_icon_name"
    uci commit appcenter

    write_plugin_uninstall_assets
    patch_common_template
    refresh_luci_appcenter
    ensure_plugin_autostart_order
    fix_adguard_runtime_if_possible
    ensure_existing_swap_access "AdGuardHome"
    verify_appcenter_route "luci-app-adguardhome" "admin/services/AdGuardHome"
    verify_file_exists /usr/lib/lua/luci/controller/AdGuardHome.lua "AdGuardHome"
    verify_luci_route admin/services/AdGuardHome "AdGuardHome"
    verify_luci_route admin/services/AdGuardHome/base "AdGuardHome"
    verify_luci_route admin/services/AdGuardHome/manual "AdGuardHome"
    verify_luci_route admin/services/AdGuardHome/log "AdGuardHome"

    log_stage 5 5 "可选下载核心并完成最终校验"
    adg_core_downloaded='0'
    if confirm_default_yes "是否现在下载 AdGuardHome 核心（CDN）？"; then
        download_adguardhome_core
        adg_core_downloaded='1'
        verify_file_exists /usr/bin/AdGuardHome/AdGuardHome "AdGuardHome core"
        fix_adguard_runtime_if_possible
    else
        log "备注:     已跳过 AdGuardHome 核心下载"
    fi

    log "安装完成"
    log "插件:   AdGuardHome"
    log "版本:  $adg_ver"
    log "路由:    admin/services/AdGuardHome"
    if [ "$adg_core_downloaded" = '1' ]; then
        log "核心:     AdGuardHome"
        log "核心版本: latest"
        log "核心路径: /usr/bin/AdGuardHome/AdGuardHome"
    elif [ "$adg_luci_reused" = '1' ]; then
        log "备注:     LuCI 安装包已是目标版本，仅刷新包装页和运行时检查"
    elif [ -x /usr/bin/AdGuardHome/AdGuardHome ]; then
        log "备注:     已检测到核心，配置与启动链路已检查"
    else
        log "备注:     LuCI 已装好；核心请在 AdGuardHome 页面里更新后再启动"
    fi
    log "下一步: 关闭应用商店弹窗后按 Ctrl+F5，再重新打开 AdGuardHome"
}

write_openlist_runtime_files() {
    openlist_helper="/usr/libexec/openlist-sync-config"
    openlist_init="/etc/init.d/openlist"

    mkdir -p /usr/libexec
    backup_file "$openlist_helper"
    backup_file "$openlist_init"

    cat > "$openlist_helper" <<'EOF_OPENLIST_SYNC'
#!/bin/sh
set -e
. /lib/functions.sh

DEFAULT_DATA_DIR="/mnt/app_data/openlist/data"
DEFAULT_TEMP_DIR="/mnt/app_data/openlist/tmp"
DEFAULT_LOG_PATH="/mnt/app_data/openlist/openlist.log"
SKIP_FIREWALL_SYNC="${OPENLIST_SKIP_FIREWALL_SYNC:-0}"

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

load_old_secret() {
    cfg="$1"
    [ -s "$cfg" ] || return 1
    sed -n 's/^[[:space:]]*"jwt_secret"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$cfg" | head -n 1
}

generate_secret() {
    if command -v md5sum >/dev/null 2>&1; then
        dd if=/dev/urandom bs=32 count=1 2>/dev/null | md5sum | awk '{print substr($1,1,16)}'
    else
        date +%s | awk '{printf "openlist%s", $1}'
    fi
}

ensure_firewall_rule() {
    port="$1"
    allow_wan="$2"
    firewall_changed='0'

    existing_openlist_rules="$(uci show firewall 2>/dev/null | awk '
        /^firewall\.@rule\[[0-9]+\]=rule$/ {
            sec=$1
            sub(/^firewall\./, "", sec)
            sub(/=.*/, "", sec)
            current=sec
            next
        }
        current != "" && $0 == ("firewall." current ".name='\''nradio_openlist'\''") {
            print current
            current=""
        }
    ')"
    for sec in $existing_openlist_rules; do
        [ -n "$sec" ] || continue
        uci -q delete "firewall.$sec" >/dev/null 2>&1 || true
        firewall_changed='1'
    done

    if [ "$allow_wan" = "1" ]; then
        sec="$(uci -q add firewall rule 2>/dev/null || true)"
        if [ -n "$sec" ]; then
            uci -q set "firewall.$sec.name=nradio_openlist" >/dev/null 2>&1 || true
            uci -q set "firewall.$sec.src=wan" >/dev/null 2>&1 || true
            uci -q set "firewall.$sec.proto=tcp" >/dev/null 2>&1 || true
            uci -q set "firewall.$sec.dest_port=$port" >/dev/null 2>&1 || true
            uci -q set "firewall.$sec.target=ACCEPT" >/dev/null 2>&1 || true
            firewall_changed='1'
        fi
    fi

    if [ "$firewall_changed" = "1" ]; then
        uci -q commit firewall >/dev/null 2>&1 || true
        /etc/init.d/firewall reload >/dev/null 2>&1 || true
    fi
}

config_load openlist
enabled="1"; config_get enabled main enabled '1'
port="5244"; config_get port main port '5244'
allow_wan="0"; config_get allow_wan main allow_wan '0'
data_dir="$DEFAULT_DATA_DIR"; config_get data_dir main data_dir "$DEFAULT_DATA_DIR"
temp_dir="$DEFAULT_TEMP_DIR"; config_get temp_dir main temp_dir "$DEFAULT_TEMP_DIR"
site_url=""; config_get site_url main site_url ''
log_enable="1"; config_get log_enable main log '1'
log_path="$DEFAULT_LOG_PATH"; config_get log_path main log_path "$DEFAULT_LOG_PATH"
token_expires_in="48"; config_get token_expires_in main token_expires_in '48'
jwt_secret=""; config_get jwt_secret main jwt_secret ''

mkdir -p "$data_dir" "$temp_dir" "$(dirname "$log_path")"
touch "$log_path" 2>/dev/null || true

config_json="$data_dir/config.json"
db_file="$data_dir/data.db"
bleve_dir="$data_dir/bleve"

if [ -z "$jwt_secret" ]; then
    jwt_secret="$(load_old_secret "$config_json" 2>/dev/null || true)"
fi
[ -n "$jwt_secret" ] || jwt_secret="$(generate_secret)"

esc_site_url="$(json_escape "$site_url")"
esc_jwt_secret="$(json_escape "$jwt_secret")"
esc_db_file="$(json_escape "$db_file")"
esc_temp_dir="$(json_escape "$temp_dir")"
esc_bleve_dir="$(json_escape "$bleve_dir")"
esc_log_path="$(json_escape "$log_path")"

log_enable_json="true"
[ "$log_enable" = "1" ] || log_enable_json="false"

cat > "$config_json" <<EOF_JSON
{
  "force": false,
  "site_url": "$esc_site_url",
  "cdn": "",
  "jwt_secret": "$esc_jwt_secret",
  "token_expires_in": $token_expires_in,
  "database": {
    "type": "sqlite3",
    "host": "",
    "port": 0,
    "user": "",
    "password": "",
    "name": "",
    "db_file": "$esc_db_file",
    "table_prefix": "x_",
    "ssl_mode": "",
    "dsn": ""
  },
  "meilisearch": {
    "host": "http://localhost:7700",
    "api_key": "",
    "index": "openlist"
  },
  "scheme": {
    "address": "0.0.0.0",
    "http_port": $port,
    "https_port": -1,
    "force_https": false,
    "cert_file": "",
    "key_file": "",
    "unix_file": "",
    "unix_file_perm": "",
    "enable_h2c": false,
    "enable_h3": false
  },
  "temp_dir": "$esc_temp_dir",
  "bleve_dir": "$esc_bleve_dir",
  "dist_dir": "",
  "log": {
    "enable": $log_enable_json,
    "name": "$esc_log_path",
    "max_size": 50,
    "max_backups": 30,
    "max_age": 28,
    "compress": false,
    "filter": {
      "enable": false,
      "filters": [
        {
          "cidr": "",
          "path": "/ping",
          "method": ""
        },
        {
          "cidr": "",
          "path": "",
          "method": "HEAD"
        },
        {
          "cidr": "",
          "path": "/dav/",
          "method": "PROPFIND"
        }
      ]
    }
  },
  "delayed_start": 0,
  "max_buffer_limitMB": -1,
  "mmap_thresholdMB": 4,
  "max_connections": 0,
  "max_concurrency": 64,
  "tls_insecure_skip_verify": false,
  "tasks": {
    "download": {
      "workers": 5,
      "max_retry": 1,
      "task_persistant": false
    },
    "transfer": {
      "workers": 5,
      "max_retry": 2,
      "task_persistant": false
    },
    "upload": {
      "workers": 5,
      "max_retry": 0,
      "task_persistant": false
    },
    "copy": {
      "workers": 5,
      "max_retry": 2,
      "task_persistant": false
    },
    "move": {
      "workers": 5,
      "max_retry": 2,
      "task_persistant": false
    },
    "decompress": {
      "workers": 5,
      "max_retry": 2,
      "task_persistant": false
    },
    "decompress_upload": {
      "workers": 5,
      "max_retry": 2,
      "task_persistant": false
    },
    "allow_retry_canceled": false
  },
  "cors": {
    "allow_origins": [
      "*"
    ],
    "allow_methods": [
      "*"
    ],
    "allow_headers": [
      "*"
    ]
  },
  "s3": {
    "enable": false,
    "port": 5246,
    "ssl": false
  },
  "ftp": {
    "enable": false,
    "listen": ":5221",
    "find_pasv_port_attempts": 50,
    "active_transfer_port_non_20": false,
    "idle_timeout": 900,
    "connection_timeout": 30,
    "disable_active_mode": false,
    "default_transfer_binary": false,
    "enable_active_conn_ip_check": true,
    "enable_pasv_conn_ip_check": true
  },
  "sftp": {
    "enable": false,
    "listen": ":5222"
  },
  "last_launched_version": "",
  "proxy_address": ""
}
EOF_JSON

chmod 600 "$config_json" 2>/dev/null || true
if [ "$SKIP_FIREWALL_SYNC" != "1" ]; then
    ensure_firewall_rule "$port" "$allow_wan"
fi
exit 0
EOF_OPENLIST_SYNC
    chmod 755 "$openlist_helper"

    cat > "$openlist_init" <<'EOF_OPENLIST_INIT'
#!/bin/sh /etc/rc.common

USE_PROCD=1
START=99
STOP=15

OPENLIST_BIN="/mnt/app_data/openlist/bin/openlist"
OPENLIST_HELPER="/usr/libexec/openlist-sync-config"
OPENLIST_DATA_DIR="/mnt/app_data/openlist/data"

start_service() {
    [ -x "$OPENLIST_BIN" ] || return 1
    [ -x "$OPENLIST_HELPER" ] || return 1
    "$OPENLIST_HELPER" >/tmp/openlist-sync.log 2>&1 || return 1

    enabled="$(uci -q get openlist.main.enabled 2>/dev/null || echo 1)"
    [ "$enabled" = "1" ] || return 0

    data_dir="$(uci -q get openlist.main.data_dir 2>/dev/null || echo "$OPENLIST_DATA_DIR")"
    mkdir -p "$data_dir"

    procd_open_instance
    procd_set_param command "$OPENLIST_BIN" server --data "$data_dir"
    procd_set_param respawn 3600 5 5
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

reload_service() {
    stop
    start
}

service_triggers() {
    procd_add_reload_trigger "openlist"
}
EOF_OPENLIST_INIT
    chmod 755 "$openlist_init"
}

write_openlist_oem_files() {
    openlist_controller="/usr/lib/lua/luci/controller/nradio_adv/openlist.lua"
    openlist_cbi="/usr/lib/lua/luci/model/cbi/nradio_adv/openlist_basic.lua"
    openlist_logs="/usr/lib/lua/luci/view/nradio_adv/openlist_logs.htm"

    mkdir -p /usr/lib/lua/luci/controller/nradio_adv /usr/lib/lua/luci/model/cbi/nradio_adv /usr/lib/lua/luci/view/nradio_adv
    backup_file "$openlist_controller"
    backup_file "$openlist_cbi"
    backup_file "$openlist_logs"

    cat > "$openlist_controller" <<'EOF_OPENLIST_CONTROLLER'
module("luci.controller.nradio_adv.openlist", package.seeall)

function index()
    entry({"nradioadv", "system", "openlist"}, alias("nradioadv", "system", "openlist", "basic"), _("OpenList"), 91)
    entry({"nradioadv", "system", "openlist", "basic"}, cbi("nradio_adv/openlist_basic"), _("设置"), 10).leaf = true
    entry({"nradioadv", "system", "openlist", "logs"}, template("nradio_adv/openlist_logs"), _("运行日志"), 20).leaf = true
    entry({"nradioadv", "system", "appcenter", "openlist"}, alias("nradioadv", "system", "openlist"), nil, nil, true).leaf = true
end
EOF_OPENLIST_CONTROLLER

    cat > "$openlist_cbi" <<'EOF_OPENLIST_CBI'
local sys = require "luci.sys"
local http = require "luci.http"
local dispatcher = require "luci.dispatcher"

m = Map("openlist", translate("OpenList"), translate("OpenList OEM 兼容设置页"))

local function build_access_url(section)
    local site = m.uci:get("openlist", section, "site_url") or ""
    if site ~= "" then
        if not site:match("^https?://") then
            site = "http://" .. site
        end
        return site
    end

    local host = (http.getenv("HTTP_HOST") or ""):gsub(":%d+$", "")
    local port_value = m.uci:get("openlist", section, "port") or "5244"
    if host == "" then
        host = "192.168.66.1"
    end
    return string.format("http://%s:%s/", host, port_value)
end

s = m:section(TypedSection, "openlist", "")
s.anonymous = true
s.addremove = false

local status = s:option(DummyValue, "_status", translate("服务状态"))
function status.cfgvalue()
    local running = sys.call("/etc/init.d/openlist status >/dev/null 2>&1") == 0
    return running and translate("运行中") or translate("未运行")
end

local access_url = s:option(DummyValue, "_access_url", translate("访问地址"))
function access_url.cfgvalue(self, section)
    return build_access_url(section)
end

local open_web = s:option(DummyValue, "_open_web", translate("打开 Web"))
open_web.rawhtml = true
function open_web.cfgvalue(self, section)
    local url = build_access_url(section)
    return string.format('<a class="cbi-button cbi-button-apply" href="%s" target="_blank" rel="noopener noreferrer">%s</a>', url, translate("一键打开 Web"))
end

local open_logs = s:option(DummyValue, "_open_logs", translate("查看日志"))
open_logs.rawhtml = true
function open_logs.cfgvalue()
    return string.format('<a class="cbi-button" href="%s" target="_self">%s</a>', dispatcher.build_url("nradioadv", "system", "openlist", "logs"), translate("打开日志页"))
end

local restart_btn = s:option(Button, "_restart", translate("启动/重启服务"))
restart_btn.inputtitle = translate("启动/重启 OpenList")
restart_btn.inputstyle = "apply"
function restart_btn.write()
    sys.call("/etc/init.d/openlist restart >/dev/null 2>&1")
    http.redirect(dispatcher.build_url("nradioadv", "system", "openlist", "basic"))
end

local stop_btn = s:option(Button, "_stop", translate("停止服务"))
stop_btn.inputtitle = translate("停止 OpenList")
stop_btn.inputstyle = "reset"
function stop_btn.write()
    sys.call("/etc/init.d/openlist stop >/dev/null 2>&1")
    http.redirect(dispatcher.build_url("nradioadv", "system", "openlist", "basic"))
end

enabled = s:option(Flag, "enabled", translate("开机自启"))
enabled.rmempty = false

port = s:option(Value, "port", translate("监听端口"))
port.datatype = "port"
port.placeholder = "5244"
port.rmempty = false

allow_wan = s:option(Flag, "allow_wan", translate("放行 WAN 访问"))
allow_wan.rmempty = false

data_dir = s:option(Value, "data_dir", translate("数据目录"))
data_dir.placeholder = "/mnt/app_data/openlist/data"
data_dir.rmempty = false

temp_dir = s:option(Value, "temp_dir", translate("临时目录"))
temp_dir.placeholder = "/mnt/app_data/openlist/tmp"
temp_dir.rmempty = false

site_url = s:option(Value, "site_url", translate("站点地址"))
site_url.placeholder = "http://example.com/"
site_url.description = translate("如果你有反向代理或外网域名，可以填在这里，打开 Web 按钮会优先跳转到此地址。")
site_url.rmempty = true

log_enabled = s:option(Flag, "log", translate("启用日志"))
log_enabled.rmempty = false

log_path = s:option(Value, "log_path", translate("日志文件"))
log_path:depends("log", "1")
log_path.placeholder = "/mnt/app_data/openlist/openlist.log"
log_path.rmempty = true

note = s:option(DummyValue, "_note", translate("说明"))
note.rawhtml = true
function note.cfgvalue()
    return "<span>安装脚本不会自动启动 OpenList，保存配置后如需运行，请点“启动/重启服务”。</span>"
end

return m
EOF_OPENLIST_CBI

    cat > "$openlist_logs" <<'EOF_OPENLIST_LOGS'
<%+header%>
<%
local dispatcher = require "luci.dispatcher"
local util = require "luci.util"
local uci = require "luci.model.uci".cursor()
local log_path = "/var/log/openlist.log"

uci:foreach("openlist", "openlist", function(s)
    if s.log_path and s.log_path ~= "" then
        log_path = s.log_path
    end
end)

local content = util.exec("tail -n 400 " .. util.shellquote(log_path) .. " 2>/dev/null")
if not content or content == "" then
    content = "日志文件为空或不存在。"
end
%>
<div class="cbi-map">
    <h2 name="content">OpenList 运行日志</h2>
    <div class="cbi-section">
        <div class="cbi-section-node">
            <div class="cbi-value">
                <div class="cbi-value-title">日志路径</div>
                <div class="cbi-value-field"><%=util.pcdata(log_path)%></div>
            </div>
            <div class="cbi-value">
                <div class="cbi-value-field">
                    <a class="cbi-button cbi-button-apply" href="<%=dispatcher.build_url("nradioadv", "system", "openlist", "basic")%>">返回设置页</a>
                </div>
            </div>
            <div class="cbi-value">
                <div class="cbi-value-field">
                    <pre style="white-space: pre-wrap; word-break: break-all; max-height: 70vh; overflow: auto;"><%=util.pcdata(content)%></pre>
                </div>
            </div>
        </div>
    </div>
</div>
<%+footer%>
EOF_OPENLIST_LOGS
}

ensure_openlist_config_defaults() {
    mkdir -p "$OPENLIST_ROOT_DIR" "$OPENLIST_BIN_DIR" "$OPENLIST_DATA_DIR" "$OPENLIST_TEMP_DIR"
    [ -f "$OPENLIST_LOG_PATH" ] || touch "$OPENLIST_LOG_PATH"

    if [ ! -f /etc/config/openlist ]; then
        cat > /etc/config/openlist <<'EOF_OPENLIST_UCI'
config openlist 'main'
    option enabled '1'
    option port '5244'
    option allow_wan '0'
    option data_dir '/mnt/app_data/openlist/data'
    option temp_dir '/mnt/app_data/openlist/tmp'
    option site_url ''
    option log '1'
    option log_path '/mnt/app_data/openlist/openlist.log'
    option token_expires_in '48'
    option jwt_secret ''
EOF_OPENLIST_UCI
    fi

    uci -q get openlist.main >/dev/null 2>&1 || uci -q set openlist.main=openlist
    [ -n "$(uci -q get openlist.main.enabled 2>/dev/null || true)" ] || uci -q set openlist.main.enabled='1'
    [ -n "$(uci -q get openlist.main.port 2>/dev/null || true)" ] || uci -q set openlist.main.port='5244'
    [ -n "$(uci -q get openlist.main.allow_wan 2>/dev/null || true)" ] || uci -q set openlist.main.allow_wan='0'
    [ -n "$(uci -q get openlist.main.data_dir 2>/dev/null || true)" ] || uci -q set openlist.main.data_dir='/mnt/app_data/openlist/data'
    [ -n "$(uci -q get openlist.main.temp_dir 2>/dev/null || true)" ] || uci -q set openlist.main.temp_dir='/mnt/app_data/openlist/tmp'
    [ -n "$(uci -q get openlist.main.site_url 2>/dev/null || true)" ] || uci -q set openlist.main.site_url=''
    [ -n "$(uci -q get openlist.main.log 2>/dev/null || true)" ] || uci -q set openlist.main.log='1'
    [ -n "$(uci -q get openlist.main.log_path 2>/dev/null || true)" ] || uci -q set openlist.main.log_path='/mnt/app_data/openlist/openlist.log'
    [ -n "$(uci -q get openlist.main.token_expires_in 2>/dev/null || true)" ] || uci -q set openlist.main.token_expires_in='48'
    [ -n "$(uci -q get openlist.main.jwt_secret 2>/dev/null || true)" ] || uci -q set openlist.main.jwt_secret=''
    uci -q commit openlist >/dev/null 2>&1 || true
}

get_openlist_effective_data_dir() {
    openlist_effective_data_dir="$(uci -q get openlist.main.data_dir 2>/dev/null || true)"
    [ -n "$openlist_effective_data_dir" ] || openlist_effective_data_dir="$OPENLIST_DATA_DIR"
    printf '%s\n' "$openlist_effective_data_dir"
}

install_openlist() {
    require_nradio_oem_appcenter

    mkdir -p "$WORKDIR/openlist"
    openlist_archive="$WORKDIR/openlist/$OPENLIST_ASSET_NAME"
    openlist_unpack="$WORKDIR/openlist/unpack"
    OPENLIST_RESOLVED_DOWNLOAD_URLS=''

    log_stage 1 5 "OpenList GitHub 官方 CDN 安装规划"
    openlist_official_ping_hosts=""
    rank_url_list_hosts "openlist-official" "OpenList GitHub 官方" "$OPENLIST_GITHUB_OFFICIAL_PROBE_URLS"
    openlist_official_ping_hosts="$RANKED_URL_HOSTS"
    [ -n "$openlist_official_ping_hosts" ] || openlist_official_ping_hosts="$OPENLIST_STABLE_HOST_ORDER"
    if [ "${OPENLIST_FAST_DOWNLOAD_MODE:-1}" = '1' ]; then
        log "提示: OpenList 启用 GitHub 官方快速下载模式，跳过 HTTP / 部分下载探测"
    else
        openlist_package_urls="$(build_openlist_download_urls)"
        if [ -n "$openlist_official_ping_hosts" ]; then
            openlist_package_urls="$(reorder_urls_by_host_rank "$openlist_package_urls" "$openlist_official_ping_hosts")"
        fi
        openlist_probe_min_bytes="$(( (OPENCLASH_PACKAGE_PROBE_BYTES + 1) / 2 ))"
        rank_hosts_by_partial_download_probe "openlist-package" "OpenList 官方安装包" "$openlist_package_urls" "$OPENCLASH_PACKAGE_PROBE_BYTES" "$openlist_probe_min_bytes"
        if [ -n "${RANKED_URL_HOSTS:-}" ]; then
            openlist_package_urls="$(reorder_urls_by_host_rank "$openlist_package_urls" "$RANKED_URL_HOSTS")"
            openlist_official_ping_hosts="$RANKED_URL_HOSTS"
        fi
    fi
    openlist_official_ping_hosts="$(printf '%s\n' "$openlist_official_ping_hosts" | sed 's/[[:space:]][[:space:]]*/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//')"
    log "提示: OpenList 下载主机优先级: $openlist_official_ping_hosts"
    log "说明: 将下载 OpenList 官方发布包，并自动接入 OEM 应用商店"
    confirm_or_exit "确认继续安装 OpenList 并修改系统吗？"

    log_stage 2 5 "通过 GitHub 官方 CDN 下载 OpenList 官方安装包"
    openlist_package_urls="$(build_openlist_download_urls)"
    if [ -n "${openlist_official_ping_hosts:-}" ]; then
        openlist_package_urls="$(reorder_urls_by_host_rank "$openlist_package_urls" "$openlist_official_ping_hosts")"
    fi
    log "提示: OpenList 实际下载源顺序: $(summarize_url_hosts $openlist_package_urls)"
    log "提示: OpenList 官方安装包内容较大，下载与断点续传可能耗时较长，请耐心等待"
    openlist_download_stall_time_saved="$DOWNLOAD_STALL_TIME"
    openlist_download_stall_speed_saved="$DOWNLOAD_STALL_SPEED"
    openlist_download_max_time_saved="$DOWNLOAD_MAX_TIME"
    openlist_download_keep_partial_saved="${DOWNLOAD_KEEP_PARTIAL:-0}"
    openlist_download_skip_content_length_saved="${DOWNLOAD_SKIP_CONTENT_LENGTH:-0}"
    DOWNLOAD_MAX_TIME="$OPENLIST_PACKAGE_MAX_TIME"
    DOWNLOAD_STALL_TIME="$OPENLIST_PACKAGE_STALL_TIME"
    DOWNLOAD_STALL_SPEED="$OPENLIST_PACKAGE_STALL_SPEED"
    DOWNLOAD_KEEP_PARTIAL=1
    DOWNLOAD_SKIP_CONTENT_LENGTH=1
    openlist_download_url=""
    if download_from_urls "$openlist_archive" $openlist_package_urls; then
        openlist_download_url="$LAST_DOWNLOAD_SOURCE"
    fi
    if [ -z "$openlist_download_url" ]; then
        log "提示: 首轮下载未完成，正在放宽速度阈值后重试..."
        DOWNLOAD_STALL_TIME="$OPENLIST_PACKAGE_RETRY_STALL_TIME"
        DOWNLOAD_STALL_SPEED="$OPENLIST_PACKAGE_RETRY_STALL_SPEED"
        if download_from_urls "$openlist_archive" $openlist_package_urls; then
            openlist_download_url="$LAST_DOWNLOAD_SOURCE"
        else
            openlist_download_url=""
        fi
    fi
    DOWNLOAD_MAX_TIME="$openlist_download_max_time_saved"
    DOWNLOAD_STALL_TIME="$openlist_download_stall_time_saved"
    DOWNLOAD_STALL_SPEED="$openlist_download_stall_speed_saved"
    DOWNLOAD_KEEP_PARTIAL="$openlist_download_keep_partial_saved"
    DOWNLOAD_SKIP_CONTENT_LENGTH="$openlist_download_skip_content_length_saved"
    [ -n "$openlist_download_url" ] || die "无法从全部 GitHub 官方下载链路获取 OpenList 官方安装包"
    openlist_download_host="$(extract_url_host "$openlist_download_url" 2>/dev/null || true)"
    openlist_download_size="$(wc -c < "$openlist_archive" | tr -d ' ')"

    log_stage 3 5 "解压安装 OpenList 并写入运行文件"
    validate_tar_gzip_archive "$openlist_archive" "OpenList 官方安装包" "/tmp/openlist-archive-validate.log"
    openlist_extract_need="$(estimate_archive_extract_bytes "$openlist_archive" 2>/dev/null || true)"
    rm -rf "$openlist_unpack"
    mkdir -p "$openlist_unpack"
    ensure_dir_writable "$openlist_unpack" "OpenList 临时解压目录"
    [ -d /mnt/app_data ] || die "未检测到 /mnt/app_data，无法安装 OpenList 官方二进制"
    ensure_dir_writable /mnt/app_data "/mnt/app_data"
    case "$openlist_extract_need" in
        ''|*[!0-9]*) ;;
        *)
            ensure_free_space_bytes "$openlist_unpack" "$openlist_extract_need" "OpenList 临时解压目录"
            ensure_free_space_bytes /mnt/app_data "$openlist_extract_need" "/mnt/app_data"
            ;;
    esac
    tar -xzf "$openlist_archive" -C "$openlist_unpack" >/dev/null 2>&1 || die "解压 OpenList 官方安装包失败"
    openlist_bin_src=""
    for candidate in "$openlist_unpack"/openlist "$openlist_unpack"/*/openlist "$openlist_unpack"/*/*/openlist; do
        [ -f "$candidate" ] || continue
        openlist_bin_src="$candidate"
        break
    done
    [ -n "$openlist_bin_src" ] || die "解压后未找到 OpenList 可执行文件"

    mkdir -p "$OPENLIST_ROOT_DIR" "$OPENLIST_BIN_DIR" "$OPENLIST_DATA_DIR" "$OPENLIST_TEMP_DIR"
    ensure_dir_writable "$OPENLIST_ROOT_DIR" "$OPENLIST_ROOT_DIR"
    ensure_dir_writable "$OPENLIST_BIN_DIR" "$OPENLIST_BIN_DIR"
    ensure_dir_writable "$OPENLIST_DATA_DIR" "$OPENLIST_DATA_DIR"
    ensure_dir_writable "$OPENLIST_TEMP_DIR" "$OPENLIST_TEMP_DIR"
    rm -f "$OPENLIST_LINK_PATH" "$OPENLIST_BIN_PATH" 2>/dev/null || true
    cp "$openlist_bin_src" "$OPENLIST_BIN_PATH"
    chmod 755 "$OPENLIST_BIN_PATH" 2>/dev/null || true
    ln -sf "$OPENLIST_BIN_PATH" "$OPENLIST_LINK_PATH"

    write_openlist_runtime_files
    ensure_openlist_config_defaults
    OPENLIST_SKIP_FIREWALL_SYNC=1 /usr/libexec/openlist-sync-config >/tmp/openlist-sync.log 2>&1 || die "生成 OpenList 配置失败，请查看 /tmp/openlist-sync.log"
    openlist_effective_data_dir="$(get_openlist_effective_data_dir)"
    (
        cd "$OPENLIST_ROOT_DIR" &&
        ./bin/openlist admin set "$OPENLIST_DEFAULT_ADMIN_PASSWORD"
    ) >/tmp/openlist-admin.log 2>&1 || die "设置 OpenList 默认管理员密码失败，请查看 /tmp/openlist-admin.log"
    /etc/init.d/openlist enable >/dev/null 2>&1 || true

    log_stage 4 5 "写入 OEM 页面、图标并注册应用商店"
    log "提示: 正在接入 OEM 应用商店并刷新模板与配置，内容较多时可能持续较长，请耐心等待"
    write_openlist_oem_files
    backup_file "$CFG"
    cleanup_appcenter_entry "OpenList" "OpenList" "nradioadv/system/openlist/basic"
    cleanup_appcenter_entry "OpenList" "openlist" "nradioadv/system/openlist/basic"
    cleanup_appcenter_entry "OpenList" "luci-app-openlist" "admin/services/openlist"
    openlist_icon_name=""
    if install_openlist_embedded_icon; then
        openlist_icon_name="$OPENLIST_ICON_NAME"
    fi
    set_appcenter_entry "OpenList" "OpenList" "$OPENLIST_VERSION" "$openlist_download_size" "/usr/lib/lua/luci/controller/nradio_adv/openlist.lua" "nradioadv/system/openlist/basic" "$openlist_icon_name"
    uci commit appcenter
    write_plugin_uninstall_assets
    patch_common_template
    refresh_luci_appcenter
    /etc/init.d/uhttpd reload >/dev/null 2>&1 || true

    log_stage 5 5 "写入虚拟内存并校验 OpenList 页面与应用商店入口"
    ensure_existing_swap_access "OpenList"
    verify_appcenter_route "OpenList" "nradioadv/system/openlist/basic"
    verify_file_exists "$OPENLIST_BIN_PATH" "OpenList"
    verify_file_exists "$OPENLIST_LINK_PATH" "OpenList"
    verify_file_exists /etc/init.d/openlist "OpenList"
    verify_file_exists /usr/libexec/openlist-sync-config "OpenList"
    verify_file_exists /etc/config/openlist "OpenList"
    verify_file_exists "$openlist_effective_data_dir/config.json" "OpenList"
    verify_file_exists /usr/lib/lua/luci/controller/nradio_adv/openlist.lua "OpenList"
    verify_file_exists /usr/lib/lua/luci/model/cbi/nradio_adv/openlist_basic.lua "OpenList"
    verify_file_exists /usr/lib/lua/luci/view/nradio_adv/openlist_logs.htm "OpenList"
    verify_luci_route nradioadv/system/openlist "OpenList"
    verify_luci_route nradioadv/system/openlist/basic "OpenList"
    verify_luci_route nradioadv/system/openlist/logs "OpenList"

    log "安装完成"
    log "插件:   OpenList"
    log "版本:   $OPENLIST_VERSION"
    log "路由:   nradioadv/system/openlist/basic"
    log "图标:   内置 OpenList SVG"
    if [ -n "$openlist_download_host" ]; then
        log "下载源: GitHub 官方 CDN（$openlist_download_host）"
    else
        log "下载源: GitHub 官方 CDN"
    fi
    log "说明:   已写入二进制、init.d、UCI 配置、OEM 页面和应用商店入口"
    log "默认账号: admin"
    log "默认密码: $OPENLIST_DEFAULT_ADMIN_PASSWORD"
    log "说明:   当前安装链只重置默认管理员密码，不主动修改用户名"
    log "说明:   本次安装不会自动启动 OpenList，如需运行请在设置页点“启动/重启服务”"
}

write_zerotier_oem_files() {
    mkdir -p /usr/lib/lua/luci/controller/nradio_adv /usr/lib/lua/luci/model/cbi/nradio_adv
    backup_file "$ZEROTIER_CONTROLLER"
    backup_file "$ZEROTIER_CBI"

    cat > "$ZEROTIER_CONTROLLER" <<'EOF_ZEROTIER_CONTROLLER'
module("luci.controller.nradio_adv.zerotier", package.seeall)

function index()
    entry({"nradioadv", "system", "zerotier"}, alias("nradioadv", "system", "zerotier", "basic"), _("ZeroTier"), 92)
    entry({"nradioadv", "system", "zerotier", "basic"}, cbi("nradio_adv/zerotier_basic"), _("设置"), 10).leaf = true
    entry({"nradioadv", "system", "appcenter", "zerotier"}, alias("nradioadv", "system", "zerotier"), nil, nil, true).leaf = true
end
EOF_ZEROTIER_CONTROLLER

    cat > "$ZEROTIER_CBI" <<'EOF_ZEROTIER_CBI'
local sys = require "luci.sys"
local http = require "luci.http"
local dispatcher = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"

m = Map("zerotier", translate("ZeroTier"), translate("ZeroTier OEM 兼容设置页"))

local function get_section()
    local sid
    uci:foreach("zerotier", "zerotier", function(s)
        if not sid then
            sid = s[".name"]
        end
    end)
    if not sid then
        sid = "sample_config"
        uci:set("zerotier", sid, "zerotier")
        uci:set("zerotier", sid, "enabled", "0")
        uci:save("zerotier")
        uci:commit("zerotier")
    end
    return sid
end

local sid = get_section()

s = m:section(NamedSection, sid, "zerotier", "")
s.addremove = false
s.anonymous = true

local status = s:option(DummyValue, "_status", translate("服务状态"))
function status.cfgvalue()
    local running = sys.call("/etc/init.d/zerotier status >/dev/null 2>&1") == 0
    return running and translate("运行中") or translate("未运行")
end

local node = s:option(DummyValue, "_node", translate("节点信息"))
function node.cfgvalue()
    local info = sys.exec("zerotier-cli info 2>/dev/null | tr -d '\\r' | head -n 1") or ""
    info = info:gsub("^%s+", ""):gsub("%s+$", "")
    if info == "" then
        return translate("暂未获取到节点信息")
    end
    return info
end

local nets = s:option(DummyValue, "_nets", translate("已加入网络"))
nets.rawhtml = true
function nets.cfgvalue()
    local info = sys.exec("zerotier-cli listnetworks 2>/dev/null | tr -d '\\r'") or ""
    info = info:gsub("^%s+", ""):gsub("%s+$", "")
    if info == "" then
        return translate("暂无")
    end
    return "<pre style=\"white-space:pre-wrap;word-break:break-all;margin:0;\">" .. util.pcdata(info) .. "</pre>"
end

local restart_btn = s:option(Button, "_restart", translate("启动/重启服务"))
restart_btn.inputtitle = translate("启动/重启 ZeroTier")
restart_btn.inputstyle = "apply"
function restart_btn.write()
    sys.call("/etc/init.d/zerotier enable >/dev/null 2>&1")
    sys.call("/etc/init.d/zerotier restart >/dev/null 2>&1")
    http.redirect(dispatcher.build_url("nradioadv", "system", "zerotier", "basic"))
end

local stop_btn = s:option(Button, "_stop", translate("停止服务"))
stop_btn.inputtitle = translate("停止 ZeroTier")
stop_btn.inputstyle = "reset"
function stop_btn.write()
    sys.call("/etc/init.d/zerotier stop >/dev/null 2>&1")
    http.redirect(dispatcher.build_url("nradioadv", "system", "zerotier", "basic"))
end

enabled = s:option(Flag, "enabled", translate("开机自启"))
enabled.rmempty = false

port = s:option(Value, "port", translate("监听端口"))
port.placeholder = "9993"
port.datatype = "port"
port.rmempty = true

secret = s:option(Value, "secret", translate("节点密钥"))
secret.password = true
secret.rmempty = true

join = s:option(DynamicList, "join", translate("加入网络 ID"))
join.datatype = "and(uciname,rangelength(16,16))"
join.placeholder = "8056c2e21c000001"
join.rmempty = true

note = s:option(DummyValue, "_note", translate("说明"))
note.rawhtml = true
function note.cfgvalue()
    return "<span>保存后如需立即生效，可点击“启动/重启服务”。</span>"
end

return m
EOF_ZEROTIER_CBI

    chmod 644 "$ZEROTIER_CONTROLLER" "$ZEROTIER_CBI"
}

ensure_zerotier_config_defaults() {
    if [ ! -f /etc/config/zerotier ]; then
        cat > /etc/config/zerotier <<'EOF_ZEROTIER_UCI'
config zerotier 'sample_config'
    option enabled '0'
EOF_ZEROTIER_UCI
    fi

    uci -q show zerotier 2>/dev/null | grep -q "=zerotier" || uci -q set zerotier.sample_config=zerotier
    [ -n "$(uci -q get zerotier.sample_config.enabled 2>/dev/null || true)" ] || uci -q set zerotier.sample_config.enabled='0'
    uci -q commit zerotier >/dev/null 2>&1 || true
}

install_zerotier() {
    require_nradio_oem_appcenter
    ensure_default_feeds
    mkdir -p "$WORKDIR/zerotier"
    zerotier_ipk="$WORKDIR/zerotier/${ZEROTIER_PACKAGE_NAME}.ipk"

    log_stage 1 5 "ZeroTier CDN 探测与安装规划"
    zerotier_meta="$(resolve_package_meta_any_feed "$ZEROTIER_PACKAGE_NAME" 2>/dev/null || true)"
    [ -n "$zerotier_meta" ] || { sed -n '1,80p' "$FEEDS" >&2; die "无法从当前软件源解析 ZeroTier 安装包"; }
    zerotier_feed_name="${zerotier_meta%%|*}"
    zerotier_meta_rest="${zerotier_meta#*|}"
    zerotier_feed_url="${zerotier_meta_rest%%|*}"
    zerotier_meta_rest="${zerotier_meta_rest#*|}"
    zerotier_filename="${zerotier_meta_rest%%|*}"
    zerotier_version="${zerotier_meta_rest##*|}"
    zerotier_package_urls="$(build_package_download_urls_from_meta "$zerotier_feed_url" "$zerotier_filename" 2>/dev/null || true)"
    [ -n "$zerotier_package_urls" ] || die "无法生成 ZeroTier 下载地址"

    rank_url_list_hosts "zerotier" "ZeroTier" "$zerotier_package_urls"
    if [ -n "${RANKED_URL_HOSTS:-}" ]; then
        refine_ranked_hosts_by_http_probe "zerotier" "ZeroTier" "$RANKED_URL_HOSTS" "$zerotier_package_urls"
        zerotier_package_urls="$(reorder_urls_by_host_rank "$zerotier_package_urls" "$RANKED_URL_HOSTS")"
        log "提示: ZeroTier CDN 优先级: $RANKED_URL_HOSTS"
    fi
    zerotier_probe_min_bytes="$(( (OPENCLASH_PACKAGE_PROBE_BYTES + 1) / 2 ))"
    rank_hosts_by_partial_download_probe "zerotier-package" "ZeroTier 安装包" "$zerotier_package_urls" "$OPENCLASH_PACKAGE_PROBE_BYTES" "$zerotier_probe_min_bytes"
    if [ -n "${RANKED_URL_HOSTS:-}" ]; then
        zerotier_package_urls="$(reorder_urls_by_host_rank "$zerotier_package_urls" "$RANKED_URL_HOSTS")"
        log "提示: ZeroTier 安装包 CDN 顺序: $RANKED_URL_HOSTS"
    fi
    log "提示: ZeroTier 当前解析源: $zerotier_feed_name"
    log "下一步将通过 CDN 下载 ZeroTier 安装包，并写入 OEM 应用商店入口"
    confirm_or_exit "确认继续安装 ZeroTier 并修改系统吗？"

    log_stage 2 5 "通过 CDN 下载 ZeroTier 安装包"
    zerotier_download_stall_time_saved="$DOWNLOAD_STALL_TIME"
    zerotier_download_stall_speed_saved="$DOWNLOAD_STALL_SPEED"
    zerotier_download_keep_partial_saved="${DOWNLOAD_KEEP_PARTIAL:-0}"
    DOWNLOAD_STALL_TIME="$ZEROTIER_PACKAGE_STALL_TIME"
    DOWNLOAD_STALL_SPEED="$ZEROTIER_PACKAGE_STALL_SPEED"
    DOWNLOAD_KEEP_PARTIAL=1
    zerotier_download_url=""
    if download_from_urls "$zerotier_ipk" $zerotier_package_urls; then
        zerotier_download_url="$LAST_DOWNLOAD_SOURCE"
    fi
    if [ -z "$zerotier_download_url" ]; then
        log "提示: 首轮 ZeroTier 安装包下载未完成，正在放宽速度阈值后重试..."
        DOWNLOAD_STALL_TIME="$ZEROTIER_PACKAGE_RETRY_STALL_TIME"
        DOWNLOAD_STALL_SPEED="$ZEROTIER_PACKAGE_RETRY_STALL_SPEED"
        if download_from_urls "$zerotier_ipk" $zerotier_package_urls; then
            zerotier_download_url="$LAST_DOWNLOAD_SOURCE"
        fi
    fi
    DOWNLOAD_STALL_TIME="$zerotier_download_stall_time_saved"
    DOWNLOAD_STALL_SPEED="$zerotier_download_stall_speed_saved"
    DOWNLOAD_KEEP_PARTIAL="$zerotier_download_keep_partial_saved"
    [ -n "$zerotier_download_url" ] || die "无法从全部 CDN 地址下载 ZeroTier 安装包"
    [ -s "$zerotier_ipk" ] || die "ZeroTier 安装包下载失败"
    zerotier_download_host="$(extract_url_host "$zerotier_download_url" 2>/dev/null || true)"
    zerotier_download_size="$(wc -c < "$zerotier_ipk" | tr -d ' ')"

    log_stage 3 5 "安装 ZeroTier 核心并准备配置"
    ensure_opkg_update
    install_ipk_file "$zerotier_ipk" "ZeroTier"
    ensure_zerotier_config_defaults
    [ -n "$zerotier_version" ] || zerotier_version="$(get_installed_package_version zerotier 2>/dev/null || true)"
    [ -n "$zerotier_version" ] || zerotier_version="installed"

    log_stage 4 5 "写入 OEM 页面、图标并注册应用商店"
    write_zerotier_oem_files
    backup_file "$CFG"
    cleanup_appcenter_entry "ZeroTier" "ZeroTier" "$ZEROTIER_ROUTE"
    cleanup_appcenter_entry "ZeroTier" "zerotier" "$ZEROTIER_ROUTE"
    zerotier_icon_name=""
    if install_zerotier_embedded_icon; then
        zerotier_icon_name="$ZEROTIER_ICON_NAME"
    fi
    set_appcenter_entry "ZeroTier" "zerotier" "$zerotier_version" "$zerotier_download_size" "$ZEROTIER_CONTROLLER" "$ZEROTIER_ROUTE" "$zerotier_icon_name"
    zerotier_pkg_sec="$(find_uci_section package "ZeroTier")"
    [ -n "$zerotier_pkg_sec" ] && uci -q set "appcenter.$zerotier_pkg_sec.open=0" >/dev/null 2>&1 || true
    uci commit appcenter
    write_plugin_uninstall_assets
    patch_common_template
    refresh_luci_appcenter
    /etc/init.d/uhttpd reload >/dev/null 2>&1 || true

    log_stage 5 5 "写入虚拟内存并校验 ZeroTier 页面与应用商店入口"
    ensure_existing_swap_access "ZeroTier"
    verify_appcenter_route "ZeroTier" "$ZEROTIER_ROUTE"
    verify_file_exists /etc/init.d/zerotier "ZeroTier"
    verify_file_exists /etc/config/zerotier "ZeroTier"
    verify_file_exists "$ZEROTIER_CONTROLLER" "ZeroTier"
    verify_file_exists "$ZEROTIER_CBI" "ZeroTier"
    verify_luci_route nradioadv/system/zerotier "ZeroTier"
    verify_luci_route nradioadv/system/zerotier/basic "ZeroTier"

    zerotier_installed_ver="$(get_installed_package_version zerotier 2>/dev/null || true)"
    [ -n "$zerotier_installed_ver" ] || zerotier_installed_ver="$zerotier_version"

    log "安装完成"
    log "插件:   ZeroTier"
    log "版本:   $zerotier_installed_ver"
    log "路由:   $ZEROTIER_ROUTE"
    if [ -n "$zerotier_download_host" ]; then
        log "下载源: CDN（$zerotier_download_host）"
    else
        log "下载源: CDN"
    fi
    log "说明:   已下载 ZeroTier 安装包、安装核心、写入 OEM 设置页并接入应用商店"
    log "说明:   如需联网请进入设置页填写网络 ID 后点“启动/重启服务”"
}

install_easytier() {
    require_nradio_oem_appcenter
    ensure_default_feeds

    mkdir -p "$WORKDIR/easytier"
    easytier_archive="$WORKDIR/easytier/$EASYTIER_ASSET_NAME"
    easytier_unpack="$WORKDIR/easytier/unpack"
    easytier_core_ipk=""
    easytier_luci_ipk=""
    easytier_i18n_ipk=""
    EASYTIER_RESOLVED_DOWNLOAD_URLS=''

    log_stage 1 5 "$EASYTIER_DISPLAY_NAME GitHub 官方 CDN 安装规划"
    easytier_official_ping_hosts=""
    rank_url_list_hosts "easytier-official" "$EASYTIER_DISPLAY_NAME GitHub 官方" "$EASYTIER_GITHUB_OFFICIAL_PROBE_URLS"
    easytier_official_ping_hosts="$RANKED_URL_HOSTS"
    [ -n "$easytier_official_ping_hosts" ] || easytier_official_ping_hosts="$EASYTIER_STABLE_HOST_ORDER"
    easytier_official_ping_hosts="$(printf '%s\n' "$easytier_official_ping_hosts" | sed 's/[[:space:]][[:space:]]*/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//')"
    log "提示: $EASYTIER_DISPLAY_NAME 下载主机优先级: $easytier_official_ping_hosts"
    log "说明: 将下载 $EASYTIER_DISPLAY_NAME 官方发布包，并自动接入 OEM 应用商店"
    confirm_or_exit "确认继续安装 $EASYTIER_DISPLAY_NAME 并修改系统吗？"

    log_stage 2 5 "通过 GitHub 官方 CDN 下载 $EASYTIER_DISPLAY_NAME 官方安装包"
    easytier_package_urls="$(build_easytier_download_urls)"
    if [ -n "${easytier_official_ping_hosts:-}" ]; then
        easytier_package_urls="$(reorder_urls_by_host_rank "$easytier_package_urls" "$easytier_official_ping_hosts")"
    fi
    easytier_probe_min_bytes="$(( (OPENCLASH_PACKAGE_PROBE_BYTES + 1) / 2 ))"
    rank_hosts_by_partial_download_probe "easytier-package" "$EASYTIER_DISPLAY_NAME 官方安装包" "$easytier_package_urls" "$OPENCLASH_PACKAGE_PROBE_BYTES" "$easytier_probe_min_bytes"
    if [ -n "${RANKED_URL_HOSTS:-}" ]; then
        easytier_package_urls="$(reorder_urls_by_host_rank "$easytier_package_urls" "$RANKED_URL_HOSTS")"
    fi
    log "提示: $EASYTIER_DISPLAY_NAME 实际下载源顺序: $(summarize_url_hosts $easytier_package_urls)"
    log "提示: $EASYTIER_DISPLAY_NAME 官方安装包内容较大，下载与断点续传可能耗时较长，请耐心等待"
    easytier_download_stall_time_saved="$DOWNLOAD_STALL_TIME"
    easytier_download_stall_speed_saved="$DOWNLOAD_STALL_SPEED"
    easytier_download_max_time_saved="$DOWNLOAD_MAX_TIME"
    easytier_download_keep_partial_saved="${DOWNLOAD_KEEP_PARTIAL:-0}"
    easytier_download_skip_content_length_saved="${DOWNLOAD_SKIP_CONTENT_LENGTH:-0}"
    DOWNLOAD_MAX_TIME="$EASYTIER_PACKAGE_MAX_TIME"
    DOWNLOAD_STALL_TIME="$EASYTIER_PACKAGE_STALL_TIME"
    DOWNLOAD_STALL_SPEED="$EASYTIER_PACKAGE_STALL_SPEED"
    DOWNLOAD_KEEP_PARTIAL=1
    DOWNLOAD_SKIP_CONTENT_LENGTH=1
    easytier_download_url=""
    if download_from_urls "$easytier_archive" $easytier_package_urls; then
        easytier_download_url="$LAST_DOWNLOAD_SOURCE"
    fi
    if [ -z "$easytier_download_url" ]; then
        log "提示: 首轮下载未完成，正在放宽速度阈值后重试..."
        DOWNLOAD_STALL_TIME="$EASYTIER_PACKAGE_RETRY_STALL_TIME"
        DOWNLOAD_STALL_SPEED="$EASYTIER_PACKAGE_RETRY_STALL_SPEED"
        if download_from_urls "$easytier_archive" $easytier_package_urls; then
            easytier_download_url="$LAST_DOWNLOAD_SOURCE"
        fi
    fi
    DOWNLOAD_MAX_TIME="$easytier_download_max_time_saved"
    DOWNLOAD_STALL_TIME="$easytier_download_stall_time_saved"
    DOWNLOAD_STALL_SPEED="$easytier_download_stall_speed_saved"
    DOWNLOAD_KEEP_PARTIAL="$easytier_download_keep_partial_saved"
    DOWNLOAD_SKIP_CONTENT_LENGTH="$easytier_download_skip_content_length_saved"
    [ -n "$easytier_download_url" ] || die "无法从全部 GitHub 官方下载链路获取 $EASYTIER_DISPLAY_NAME 官方安装包"
    [ -s "$easytier_archive" ] || die "$EASYTIER_DISPLAY_NAME 官方安装包下载失败"
    easytier_download_host="$(extract_url_host "$easytier_download_url" 2>/dev/null || true)"
    easytier_download_size="$(wc -c < "$easytier_archive" | tr -d ' ')"

    log_stage 3 5 "解压安装 $EASYTIER_DISPLAY_NAME 并修正 LuCI 控制器"
    ensure_opkg_update
    ensure_packages kmod-tun unzip
    extract_easytier_release_bundle "$easytier_archive" "$easytier_unpack"
    for candidate in \
        "$easytier_unpack"/easytier_"$EASYTIER_VERSION"_"$EASYTIER_PACKAGE_ARCH".ipk \
        "$easytier_unpack"/*/easytier_"$EASYTIER_VERSION"_"$EASYTIER_PACKAGE_ARCH".ipk \
        "$easytier_unpack"/*/*/easytier_"$EASYTIER_VERSION"_"$EASYTIER_PACKAGE_ARCH".ipk
    do
        [ -f "$candidate" ] || continue
        easytier_core_ipk="$candidate"
        break
    done
    for candidate in \
        "$easytier_unpack"/luci-app-easytier_"$EASYTIER_VERSION"_all.ipk \
        "$easytier_unpack"/*/luci-app-easytier_"$EASYTIER_VERSION"_all.ipk \
        "$easytier_unpack"/*/*/luci-app-easytier_"$EASYTIER_VERSION"_all.ipk
    do
        [ -f "$candidate" ] || continue
        easytier_luci_ipk="$candidate"
        break
    done
    for candidate in \
        "$easytier_unpack"/luci-i18n-easytier-zh-cn*_all.ipk \
        "$easytier_unpack"/*/luci-i18n-easytier-zh-cn*_all.ipk \
        "$easytier_unpack"/*/*/luci-i18n-easytier-zh-cn*_all.ipk
    do
        [ -f "$candidate" ] || continue
        easytier_i18n_ipk="$candidate"
        break
    done
    [ -n "$easytier_core_ipk" ] || die "解压后未找到 $EASYTIER_DISPLAY_NAME 核心安装包"
    [ -n "$easytier_luci_ipk" ] || die "解压后未找到 $EASYTIER_DISPLAY_NAME LuCI 安装包"
    log "提示: $EASYTIER_DISPLAY_NAME LuCI 官方包依赖 luci-compat，当前会自动重打包并以本地包无依赖方式安装"
    easytier_luci_fixed_ipk="$WORKDIR/easytier/luci-app-easytier_${EASYTIER_VERSION}_oem.ipk"
    repack_ipk_control "$easytier_luci_ipk" "$easytier_luci_fixed_ipk" "all" "libc, kmod-tun"
    install_ipk_file "$easytier_core_ipk" "$EASYTIER_DISPLAY_NAME 核心"
    install_ipk_file_force_flags_verify "$easytier_luci_fixed_ipk" "$EASYTIER_DISPLAY_NAME LuCI" "$EASYTIER_LUCI_PACKAGE_NAME" "$EASYTIER_CONTROLLER" --nodeps
    if [ -n "$easytier_i18n_ipk" ]; then
        install_ipk_file_force_flags_verify "$easytier_i18n_ipk" "$EASYTIER_DISPLAY_NAME 中文语言包" "$EASYTIER_I18N_PACKAGE_NAME" "/usr/lib/lua/luci/i18n/easytier.zh-cn.lmo" --nodeps --force-overwrite
    else
        log "备注: 未找到 $EASYTIER_DISPLAY_NAME 中文语言包，继续安装"
    fi
    ensure_easytier_config_defaults
    write_easytier_controller_file

    log_stage 4 5 "写入图标、应用商店并接入 EasyTier 打开入口"
    backup_file "$CFG"
    cleanup_appcenter_entry "$EASYTIER_DISPLAY_NAME" "$EASYTIER_PACKAGE_NAME" "$EASYTIER_ROUTE"
    cleanup_appcenter_entry "$EASYTIER_DISPLAY_NAME" "$EASYTIER_LUCI_PACKAGE_NAME" "$EASYTIER_ROUTE"
    cleanup_appcenter_entry "$EASYTIER_PACKAGE_NAME" "$EASYTIER_PACKAGE_NAME" "$EASYTIER_ROUTE"
    cleanup_appcenter_entry "$EASYTIER_LUCI_PACKAGE_NAME" "$EASYTIER_LUCI_PACKAGE_NAME" "$EASYTIER_ROUTE"
    cleanup_appcenter_entry "$EASYTIER_I18N_PACKAGE_NAME" "$EASYTIER_I18N_PACKAGE_NAME" "$EASYTIER_ROUTE"
    easytier_icon_name=""
    if install_easytier_embedded_icon; then
        easytier_icon_name="$EASYTIER_ICON_NAME"
    fi
    easytier_installed_ver="$(get_installed_package_version "$EASYTIER_PACKAGE_NAME" 2>/dev/null || true)"
    [ -n "$easytier_installed_ver" ] || easytier_installed_ver="$EASYTIER_VERSION"
    set_appcenter_entry "$EASYTIER_DISPLAY_NAME" "$EASYTIER_LUCI_PACKAGE_NAME" "$easytier_installed_ver" "$easytier_download_size" "$EASYTIER_CONTROLLER" "$EASYTIER_ROUTE" "$easytier_icon_name"
    easytier_pkg_sec="$(find_uci_section package "$EASYTIER_DISPLAY_NAME")"
    [ -n "$easytier_pkg_sec" ] && uci -q set "appcenter.$easytier_pkg_sec.open=1" >/dev/null 2>&1 || true
    uci commit appcenter
    write_plugin_uninstall_assets
    patch_common_template
    refresh_luci_appcenter
    /etc/init.d/uhttpd reload >/dev/null 2>&1 || true

    log_stage 5 5 "写入虚拟内存并校验 EasyTier 页面与应用商店入口"
    ensure_existing_swap_access "$EASYTIER_DISPLAY_NAME"
    verify_appcenter_route "$EASYTIER_DISPLAY_NAME" "$EASYTIER_ROUTE"
    verify_file_exists /usr/bin/easytier-core "$EASYTIER_DISPLAY_NAME"
    verify_file_exists /usr/bin/easytier-cli "$EASYTIER_DISPLAY_NAME"
    verify_file_exists /usr/bin/easytier-web "$EASYTIER_DISPLAY_NAME"
    verify_file_exists /etc/config/easytier "$EASYTIER_DISPLAY_NAME"
    verify_file_exists /etc/init.d/easytier "$EASYTIER_DISPLAY_NAME"
    verify_file_exists "$EASYTIER_CONTROLLER" "$EASYTIER_DISPLAY_NAME"
    verify_file_exists /usr/lib/lua/luci/model/cbi/easytier.lua "$EASYTIER_DISPLAY_NAME"
    verify_file_exists /usr/lib/lua/luci/view/easytier/easytier_status.htm "$EASYTIER_DISPLAY_NAME"
    verify_luci_route "$EASYTIER_ROUTE" "$EASYTIER_DISPLAY_NAME"

    log "安装完成"
    log "插件:   $EASYTIER_DISPLAY_NAME"
    log "版本:   $easytier_installed_ver"
    log "路由:   $EASYTIER_ROUTE"
    if [ -n "$easytier_download_host" ]; then
        log "下载源: GitHub 官方 CDN（$easytier_download_host）"
    else
        log "下载源: GitHub 官方 CDN"
    fi
    log "说明:   已下载官方发布包、安装核心与 LuCI、修正原生控制器并接入 OEM 应用商店"
    log "说明:   如页面未立即刷新，请关闭应用商店弹窗后按 Ctrl+F5 再重新打开 $EASYTIER_DISPLAY_NAME"
}

write_fanctrl_plugin_files() {
    fanctrl_model="${1:-}"
    fanctrl_tempsource='max'
    fanctrl_interval='12'

    case "$fanctrl_model" in
        NRadio_C8-688)
            fanctrl_tempsource='cpu'
            fanctrl_interval='10'
            ;;
        NRadio_C2000MAX)
            fanctrl_tempsource='max'
            fanctrl_interval='12'
            ;;
    esac

    mkdir -p \
        "$(dirname "$FANCTRL_CONTROLLER")" \
        "$(dirname "$FANCTRL_CBI")" \
        "$FANCTRL_VIEW_DIR"
    backup_file "$FANCTRL_CONTROLLER"
    backup_file "$FANCTRL_CBI"
    backup_file "$FANCTRL_TEMP_AJAX_VIEW"
    backup_file "$FANCTRL_TEMP_VIEW"
    backup_file "$FANCTRL_BIN_PATH"
    backup_file "$FANCTRL_INIT_FILE"
    backup_file "$FANCTRL_CONFIG_FILE"

    cat > "$FANCTRL_CONTROLLER" <<'EOF_FANCTRL_CONTROLLER'
module("luci.controller.nradio_adv.fanctrl", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/fanctrl") then
        return
    end

    local page = entry({"nradioadv", "system", "fanctrl"}, cbi("nradio_adv/fanctrl"), _("FanControl"), 90, true)
    page.show = true
    page.icon = 'nradio-fanctrl'
    entry({"nradioadv", "system", "fanctrl", "temperature"}, call("action_get_temperature"), nil, nil, true).leaf = true
end

local function mode_label(mode)
    if mode == "0" then
        return "关闭"
    elseif mode == "1" then
        return "Low"
    elseif mode == "2" then
        return "Medium"
    elseif mode == "3" then
        return "High"
    end
    return "Smart"
end

local function read_int_file(path, divisor)
    local fs = require "nixio.fs"
    local raw = fs.readfile(path) or ""
    local num = tonumber((raw:gsub("%s+", "")) or "") or 0
    if divisor and divisor > 1 and num > 0 then
        num = math.floor(num / divisor)
    end
    return num
end

local function read_cpe_temp()
    local sys = require "luci.sys"
    local raw = sys.exec("/etc/cpetools/quectel.sh -c temp 2>/dev/null") or ""
    return tonumber((raw:gsub("%s+", "")) or "") or 0
end

local function choose_temp(source, cpu_temp, cpe_temp)
    if source == "cpu" then
        return cpu_temp
    elseif source == "cpe" then
        if cpe_temp > 0 then
            return cpe_temp
        end
        return cpu_temp
    end

    if cpe_temp > cpu_temp then
        return cpe_temp
    end
    return cpu_temp
end

local function temp_source_label(source)
    if source == "cpu" then
        return "CPU"
    elseif source == "cpe" then
        return "CPE"
    end
    return "CPU/CPE 取高值"
end

local function pwm_to_percent(pwm_num)
    if pwm_num >= 255 then
        return "100"
    elseif pwm_num >= 204 then
        return "80"
    elseif pwm_num >= 127 then
        return "50"
    elseif pwm_num >= 76 then
        return "30"
    end
    return "0"
end

function action_get_temperature()
    local fs = require "nixio.fs"
    local data = {}
    local uci = require "luci.model.uci".cursor()

    data.mode = uci:get("fanctrl", "fanctrl", "mode") or "4"
    data.mode_label = mode_label(data.mode)
    data.enabled = uci:get("fanctrl", "fanctrl", "enabled") or "0"
    data.temp_source = uci:get("fanctrl", "fanctrl", "tempsource") or "max"
    data.temp_source_label = temp_source_label(data.temp_source)
    data.interval = uci:get("fanctrl", "fanctrl", "interval") or "12"
    data.protecttemp = uci:get("fanctrl", "fanctrl", "protecttemp") or "85"

    local pwm_raw = fs.readfile("/sys/devices/platform/pwm-fan/hwmon/hwmon0/pwm1") or ""
    local gpio_raw = fs.readfile("/sys/class/gpio/fan-hw/value") or ""
    local cpu_temp = read_int_file("/sys/class/thermal/thermal_zone0/temp", 1000)
    local cpe_temp = read_cpe_temp()
    local temp_num = choose_temp(data.temp_source, cpu_temp, cpe_temp)
    local pwm_num = tonumber((pwm_raw:gsub("%s+", "")) or "") or 0

    if temp_num > 0 then
        data.temp = tostring(temp_num)
    else
        data.temp = ""
    end

    data.cpu_temp = cpu_temp > 0 and tostring(cpu_temp) or ""
    data.cpe_temp = cpe_temp > 0 and tostring(cpe_temp) or ""
    data.pwm = pwm_num > 0 and tostring(pwm_num) or "0"
    data.gpio = (gpio_raw:gsub("%s+", "")) or ""
    data.fan = pwm_to_percent(pwm_num)

    luci.nradio.luci_call_result(data)
end
EOF_FANCTRL_CONTROLLER

    cat > "$FANCTRL_CBI" <<'EOF_FANCTRL_CBI'
m = Map("fanctrl", translate("FanSetting"))

s = m:section(NamedSection, "fanctrl", "service")

enabled = s:option(Flag, "enabled", translate("FanSwitch"))
enabled.rmempty = false

tempdes = s:option(DummyValue, "tempdes", " ")
tempdes.template = "nradio_fanctrl/temperature_ajax"

tempdesdevice = s:option(DummyValue, "tempdesdevice", translate("DeviceTemperature"))
tempdesdevice.template = "nradio_fanctrl/temperature"

fandesdevice = s:option(DummyValue, "fandesdevice", translate("DeviceFanSpeed"))
fandesdevice.template = "nradio_fanctrl/temperature"

mode = s:option(ListValue, "mode", translate("FanMode"))
mode:value("0", translate("Close"))
mode:value("1", translate("Low"))
mode:value("2", translate("Medium"))
mode:value("3", translate("High"))
mode:value("4", translate("Smart"))
mode.default = "4"
mode:depends("enabled", "1")

tempsource = s:option(ListValue, "tempsource", translate("温度来源"))
tempsource:value("max", translate("CPU/CPE 取高值"))
tempsource:value("cpu", translate("CPU"))
tempsource:value("cpe", translate("CPE"))
tempsource.default = "max"
tempsource:depends("enabled", "1")

smartmin = s:option(ListValue, "smartmin", translate("Smart 最低风速"))
smartmin:value("0", translate("关闭"))
smartmin:value("30", translate("30%"))
smartmin:value("50", translate("50%"))
smartmin.default = "30"
smartmin:depends("mode", "4")

smarttemp_low = s:option(Value, "smarttemp_low", translate("Smart 30% 温度"))
smarttemp_low.default = "50"
smarttemp_low.datatype = "uinteger"
smarttemp_low:depends("mode", "4")

smarttemp_mid = s:option(Value, "smarttemp_mid", translate("Smart 50% 温度"))
smarttemp_mid.default = "60"
smarttemp_mid.datatype = "uinteger"
smarttemp_mid:depends("mode", "4")

smarttemp_high = s:option(Value, "smarttemp_high", translate("Smart 80% 温度"))
smarttemp_high.default = "70"
smarttemp_high.datatype = "uinteger"
smarttemp_high:depends("mode", "4")

smarttemp_full = s:option(Value, "smarttemp_full", translate("Smart 100% 温度"))
smarttemp_full.default = "80"
smarttemp_full.datatype = "uinteger"
smarttemp_full:depends("mode", "4")

protecttemp = s:option(Value, "protecttemp", translate("过热保护温度"))
protecttemp.default = "85"
protecttemp.datatype = "uinteger"
protecttemp:depends("enabled", "1")

interval = s:option(ListValue, "interval", translate("检测间隔"))
interval:value("5", translate("5s"))
interval:value("10", translate("10s"))
interval:value("12", translate("12s"))
interval:value("15", translate("15s"))
interval:value("30", translate("30s"))
interval.default = "12"
interval:depends("enabled", "1")

function m.on_after_commit(map)
    os.execute("/etc/init.d/fanctrl restart >/dev/null 2>&1")
end

return m
EOF_FANCTRL_CBI

    cat > "$FANCTRL_TEMP_AJAX_VIEW" <<'EOF_FANCTRL_TEMP_AJAX'
<%+cbi/valueheader%>

<script type="text/javascript">//<![CDATA[
	function update_fanctrl_value(id, value) {
		var s = document.getElementById(id);
		if (s) s.innerHTML = value;
	}

	XHR.poll(5, '<%=url('nradioadv/system/fanctrl/temperature')%>', null,
		function(x, rv)
		{
			if (!(rv && rv.result))
				return;

			var temp = rv.result.temp || '';
			var fan = rv.result.fan || '0';
			var mode = rv.result.mode || '4';
			var modeLabel = rv.result.mode_label || 'Smart';
			var enabled = rv.result.enabled || '0';
			var sourceLabel = rv.result.temp_source_label || '';

			var tempLabel = temp ? (temp + ' °C' + (sourceLabel ? (' / ' + sourceLabel) : '')) : '<em>暂无数据</em>';
			var fanLabel = '关闭';

			if (enabled === '1') {
				if (mode === '0')
					fanLabel = '关闭';
				else
					fanLabel = fan + '% / ' + modeLabel;
			}

			update_fanctrl_value('tempdesdevice-temperature-status', tempLabel);
			update_fanctrl_value('fandesdevice-temperature-status', fanLabel);
		}
	);

	$("#cbi-fanctrl-fanctrl-tempdes").css("display", "none");
	$("#cbi-fanctrl-fanctrl-tempdesmodel").css("display", "none");
//]]></script>
<%+cbi/valuefooter%>
EOF_FANCTRL_TEMP_AJAX

    cat > "$FANCTRL_TEMP_VIEW" <<'EOF_FANCTRL_TEMP'
<%+cbi/valueheader%>
<style>
  #<%=self.option%>-temperature-status{margin-top: 7px;display: block;}
</style>
<span id="<%=self.option%>-temperature-status"><em><%:Collecting data...%></em></span>
<%+cbi/valuefooter%>
EOF_FANCTRL_TEMP

    cat > "$FANCTRL_BIN_PATH" <<'EOF_FANCTRL_SERVICE'
#!/bin/ash
. /lib/functions.sh
. /usr/share/libubox/jshn.sh

GPIO_FAN="/sys/class/gpio/fan-hw/value"
PWM_FAN="/sys/devices/platform/pwm-fan/hwmon/hwmon0/pwm1"
DEFAULT_WAIT=12

set_pwm_by_percent() {
    case "$1" in
        0) echo 0 ;;
        30) echo 76 ;;
        50) echo 127 ;;
        80) echo 204 ;;
        100) echo 255 ;;
        *) echo 0 ;;
    esac
}

get_fan_percent() {
    cur="$(cat "$PWM_FAN" 2>/dev/null || echo 0)"
    case "$cur" in
        0) echo 0 ;;
        76) echo 30 ;;
        127) echo 50 ;;
        204) echo 80 ;;
        255) echo 100 ;;
        *) echo 0 ;;
    esac
}

get_cpu_temp() {
    awk '{printf "%d", $1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0
}

get_model_temp() {
    cur="$(/etc/cpetools/quectel.sh -c temp 2>/dev/null || true)"
    echo "$cur" | grep -qE '^[0-9]+$' && echo "$cur" || true
}

is_uint() {
    echo "$1" | grep -qE '^[0-9]+$'
}

safe_uint() {
    value="$1"
    fallback="$2"
    if is_uint "$value"; then
        echo "$value"
    else
        echo "$fallback"
    fi
}

get_drive_temp() {
    source="$1"
    cpu_temp="$(get_cpu_temp)"
    model_temp="$(get_model_temp)"

    case "$source" in
        cpu)
            echo "${cpu_temp:-0}"
            ;;
        cpe)
            if [ -n "$model_temp" ]; then
                echo "$model_temp"
            else
                echo "${cpu_temp:-0}"
            fi
            ;;
        *)
            if [ -n "$model_temp" ] && [ "$model_temp" -gt "${cpu_temp:-0}" ]; then
                echo "$model_temp"
            else
                echo "${cpu_temp:-0}"
            fi
            ;;
    esac
}

disable_fan() {
    echo 0 > "$GPIO_FAN" 2>/dev/null || true
    echo 0 > "$PWM_FAN" 2>/dev/null || true
}

enable_fan() {
    percent="$1"
    pwm="$(set_pwm_by_percent "$percent")"
    echo 1 > "$GPIO_FAN" 2>/dev/null || true
    echo "$pwm" > "$PWM_FAN" 2>/dev/null || true
}

smart_percent() {
    temp="$1"
    smart_min="$2"
    smart_low="$3"
    smart_mid="$4"
    smart_high="$5"
    smart_full="$6"
    percent=0

    [ -n "$smart_min" ] || smart_min=30
    [ -n "$smart_low" ] || smart_low=50
    [ -n "$smart_mid" ] || smart_mid=60
    [ -n "$smart_high" ] || smart_high=70
    [ -n "$smart_full" ] || smart_full=80

    case "$smart_min" in
        0|30|50) ;;
        *) smart_min=30 ;;
    esac

    if [ "$temp" -ge "$smart_full" ]; then
        percent=100
    elif [ "$temp" -ge "$smart_high" ]; then
        percent=80
    elif [ "$temp" -ge "$smart_mid" ]; then
        percent=50
    elif [ "$temp" -ge "$smart_low" ]; then
        percent=30
    else
        percent="$smart_min"
    fi

    if [ "$percent" -lt "$smart_min" ]; then
        percent="$smart_min"
    fi
    echo "$percent"
}

report_state() {
    cpu_temp="$(get_cpu_temp)"
    model_temp="$(get_model_temp)"
    fan_percent="$(get_fan_percent)"
    ubus call infocdp passthrough "{'name':'temperature','parameter':{'device':'$cpu_temp','cpe':'$model_temp','fan':'$fan_percent'}}" >/dev/null 2>&1 || true
}

while true; do
    enabled="$(uci -q get fanctrl.fanctrl.enabled 2>/dev/null || echo 1)"
    mode="$(uci -q get fanctrl.fanctrl.mode 2>/dev/null || echo 4)"
    tempsource="$(uci -q get fanctrl.fanctrl.tempsource 2>/dev/null || echo max)"
    smartmin="$(uci -q get fanctrl.fanctrl.smartmin 2>/dev/null || echo 30)"
    smarttemp_low="$(uci -q get fanctrl.fanctrl.smarttemp_low 2>/dev/null || echo 50)"
    smarttemp_mid="$(uci -q get fanctrl.fanctrl.smarttemp_mid 2>/dev/null || echo 60)"
    smarttemp_high="$(uci -q get fanctrl.fanctrl.smarttemp_high 2>/dev/null || echo 70)"
    smarttemp_full="$(uci -q get fanctrl.fanctrl.smarttemp_full 2>/dev/null || echo 80)"
    protecttemp="$(uci -q get fanctrl.fanctrl.protecttemp 2>/dev/null || echo 85)"
    wait_time="$(uci -q get fanctrl.fanctrl.interval 2>/dev/null || echo "$DEFAULT_WAIT")"

    smarttemp_low="$(safe_uint "$smarttemp_low" 50)"
    smarttemp_mid="$(safe_uint "$smarttemp_mid" 60)"
    smarttemp_high="$(safe_uint "$smarttemp_high" 70)"
    smarttemp_full="$(safe_uint "$smarttemp_full" 80)"
    protecttemp="$(safe_uint "$protecttemp" 85)"

    case "$wait_time" in
        5|10|12|15|30) ;;
        *) wait_time="$DEFAULT_WAIT" ;;
    esac

    [ "$smarttemp_mid" -ge "$smarttemp_low" ] || smarttemp_mid="$smarttemp_low"
    [ "$smarttemp_high" -ge "$smarttemp_mid" ] || smarttemp_high="$smarttemp_mid"
    [ "$smarttemp_full" -ge "$smarttemp_high" ] || smarttemp_full="$smarttemp_high"

    if [ "$enabled" != "1" ]; then
        disable_fan
        report_state
        sleep "$wait_time"
        continue
    fi

    current_temp="$(get_drive_temp "$tempsource")"
    [ -n "$current_temp" ] || current_temp=0

    if [ "$current_temp" -ge "$protecttemp" ]; then
        enable_fan 100
        report_state
        sleep "$wait_time"
        continue
    fi

    case "$mode" in
        0) disable_fan ;;
        1) enable_fan 30 ;;
        2) enable_fan 50 ;;
        3) enable_fan 80 ;;
        4) enable_fan "$(smart_percent "$current_temp" "$smartmin" "$smarttemp_low" "$smarttemp_mid" "$smarttemp_high" "$smarttemp_full")" ;;
        *) enable_fan 50 ;;
    esac

    report_state
    sleep "$wait_time"
done
EOF_FANCTRL_SERVICE

    cat > "$FANCTRL_INIT_FILE" <<'EOF_FANCTRL_INIT'
#!/bin/sh /etc/rc.common
START=95
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/fanctrl.sh
    procd_set_param respawn
    procd_close_instance
}
EOF_FANCTRL_INIT

    cat > "$FANCTRL_CONFIG_FILE" <<EOF_FANCTRL_UCI
config service 'fanctrl'
    option enabled '1'
    option mode '4'
    option tempsource '$fanctrl_tempsource'
    option smartmin '30'
    option smarttemp_low '50'
    option smarttemp_mid '60'
    option smarttemp_high '70'
    option smarttemp_full '80'
    option protecttemp '85'
    option interval '$fanctrl_interval'
EOF_FANCTRL_UCI

    chmod 644 "$FANCTRL_CONTROLLER" "$FANCTRL_CBI" "$FANCTRL_TEMP_AJAX_VIEW" "$FANCTRL_TEMP_VIEW" "$FANCTRL_CONFIG_FILE"
    chmod 755 "$FANCTRL_BIN_PATH" "$FANCTRL_INIT_FILE"
}

install_fanctrl() {
    local raw_model raw_board raw_compat current_model fanctrl_icon_name

    require_nradio_oem_appcenter
    raw_model="$(detect_board_model_raw)"
    raw_board="$(detect_board_name_raw)"
    raw_compat="$(detect_board_compatible_raw)"
    current_model="$(normalize_nradio_model "$raw_model" "$raw_board" "$raw_compat")"
    case "$current_model" in
        NRadio_C8-688|NRadio_C2000MAX)
            ;;
        *)
            log "提示: 14 号风扇控制仅支持 NRadio_C8-688 / NRadio_C2000MAX。"
            log "当前机型: ${current_model:-unknown}"
            log "原始识别: model=${raw_model:-unknown} board_name=${raw_board:-unknown}"
            printf '按回车返回上一级菜单...'
            ui_read_line >/dev/null 2>&1 || true
            return 2
            ;;
    esac

    log_stage 1 5 "NRadio_C8-688 / NRadio_C2000MAX 原厂风扇控制页面安装规划"
    log "提示: 当前机型已识别为 ${current_model}，将按独立脚本逻辑写回原厂“更多-风扇”页面和后台脚本"
    confirm_or_exit "确认继续安装 ${FANCTRL_DISPLAY_NAME} 并修改系统吗？"

    log_stage 2 5 "写入原厂风扇控制页面与后台脚本"
    write_fanctrl_plugin_files "$current_model"

    log_stage 3 5 "启用风扇控制服务并写入默认配置"
    "$FANCTRL_INIT_FILE" enable >/dev/null 2>&1 || true
    "$FANCTRL_INIT_FILE" restart >/dev/null 2>&1 || true

    log_stage 4 5 "刷新原厂更多-风扇入口"
    backup_file "$CFG"
    cleanup_appcenter_entry "$FANCTRL_DISPLAY_NAME" "$FANCTRL_PACKAGE_NAME" "$FANCTRL_ROUTE"
    rm -f /tmp/appcenter/luci/nradioadv.system.fanctrl 2>/dev/null || true
    refresh_luci_appcenter
    /etc/init.d/uhttpd reload >/dev/null 2>&1 || true

    log_stage 5 5 "校验原厂更多-风扇页面"
    verify_file_exists "$FANCTRL_CONTROLLER" "$FANCTRL_DISPLAY_NAME"
    verify_file_exists "$FANCTRL_CBI" "$FANCTRL_DISPLAY_NAME"
    verify_file_exists "$FANCTRL_BIN_PATH" "$FANCTRL_DISPLAY_NAME"
    verify_file_exists "$FANCTRL_INIT_FILE" "$FANCTRL_DISPLAY_NAME"
    verify_file_exists "$FANCTRL_CONFIG_FILE" "$FANCTRL_DISPLAY_NAME"
    verify_luci_route "$FANCTRL_ROUTE" "$FANCTRL_DISPLAY_NAME"

    log "安装完成"
    log "插件:   $FANCTRL_DISPLAY_NAME"
    log "版本:   builtin"
    log "路由:   $FANCTRL_ROUTE"
    log "说明:   仅支持 NRadio_C8-688 / NRadio_C2000MAX，已按独立脚本逻辑写回原厂“更多-风扇”页面"
}

load_easytier_route_state() {
    ET_ROUTE_VIRTUAL_IP=''
    ET_ROUTE_LOCAL_SUBNET=''
    ET_ROUTE_REMOTE_SUBNET=''
    ET_ROUTE_LAN_IF=''
    ET_ROUTE_TUN_IF=''
    if [ -f "$EASYTIER_ROUTE_STATE_FILE" ]; then
        . "$EASYTIER_ROUTE_STATE_FILE" 2>/dev/null || true
    fi
}

save_easytier_route_state() {
    ensure_state_dir
    {
        printf 'ET_ROUTE_VIRTUAL_IP=%s\n' "$(shell_quote "${ET_ROUTE_VIRTUAL_IP:-}")"
        printf 'ET_ROUTE_LOCAL_SUBNET=%s\n' "$(shell_quote "${ET_ROUTE_LOCAL_SUBNET:-}")"
        printf 'ET_ROUTE_REMOTE_SUBNET=%s\n' "$(shell_quote "${ET_ROUTE_REMOTE_SUBNET:-}")"
        printf 'ET_ROUTE_LAN_IF=%s\n' "$(shell_quote "${ET_ROUTE_LAN_IF:-}")"
        printf 'ET_ROUTE_TUN_IF=%s\n' "$(shell_quote "${ET_ROUTE_TUN_IF:-}")"
    } > "$EASYTIER_ROUTE_STATE_FILE"
    chmod 600 "$EASYTIER_ROUTE_STATE_FILE" 2>/dev/null || true
}

cleanup_easytier_route_runtime_state() {
    local route_local_subnet="${1:-}"
    local route_remote_subnet="${2:-}"
    local route_lan_if="${3:-br-lan}"
    local route_tun_if="${4:-tun0}"

    [ -n "$route_local_subnet" ] || return 0
    [ -n "$route_remote_subnet" ] || return 0

    ip route del "$route_remote_subnet" 2>/dev/null || true
    ip rule del to "$route_remote_subnet" lookup main priority 60 2>/dev/null || true
    ip rule del iif "$route_lan_if" to "$route_remote_subnet" lookup main priority 70 2>/dev/null || true
    ip rule del from "$route_local_subnet" to "$route_remote_subnet" lookup main priority 196 2>/dev/null || true

    command -v iptables >/dev/null 2>&1 || return 0
    while iptables -t nat -C POSTROUTING -s "$route_local_subnet" -d "$route_remote_subnet" -o "$route_tun_if" -j MASQUERADE >/dev/null 2>&1; do
        iptables -t nat -D POSTROUTING -s "$route_local_subnet" -d "$route_remote_subnet" -o "$route_tun_if" -j MASQUERADE >/dev/null 2>&1 || break
    done
    while iptables -t filter -C FORWARD -s "$route_remote_subnet" -d "$route_local_subnet" -i "$route_tun_if" -o "$route_lan_if" -j ACCEPT >/dev/null 2>&1; do
        iptables -t filter -D FORWARD -s "$route_remote_subnet" -d "$route_local_subnet" -i "$route_tun_if" -o "$route_lan_if" -j ACCEPT >/dev/null 2>&1 || break
    done
    while iptables -t filter -C FORWARD -d "$route_remote_subnet" -i "$route_lan_if" -o "$route_tun_if" -j ACCEPT >/dev/null 2>&1; do
        iptables -t filter -D FORWARD -d "$route_remote_subnet" -i "$route_lan_if" -o "$route_tun_if" -j ACCEPT >/dev/null 2>&1 || break
    done
}

cleanup_easytier_route_rc_hook() {
    local rc_local="/etc/rc.local"
    local rc_tmp="$WORKDIR/rc.local.easytier.cleanup"

    [ -f "$rc_local" ] || return 0
    grep -q 'EASYTIER_ROUTE_WIZARD_BEGIN' "$rc_local" 2>/dev/null || return 0

    backup_file "$rc_local"
    awk '
        BEGIN { skip = 0 }
        /^# EASYTIER_ROUTE_WIZARD_BEGIN$/ { skip = 1; next }
        /^# EASYTIER_ROUTE_WIZARD_END$/ { skip = 0; next }
        skip { next }
        { print }
    ' "$rc_local" > "$rc_tmp" && mv "$rc_tmp" "$rc_local"
    chmod 755 "$rc_local" 2>/dev/null || true
}

write_easytier_route_config() {
    route_virtual_ip="$1"
    route_local_subnet="$2"
    route_old_local_subnet="${3:-}"
    tmp_cfg="$WORKDIR/easytier-config.toml"

    awk -v new_ipv4="$route_virtual_ip" -v new_lan="$route_local_subnet" -v old_lan="$route_old_local_subnet" '
        function print_proxy_block() {
            print "[[proxy_network]]"
            print "cidr = \"" new_lan "\""
            print ""
            inserted_proxy = 1
            seen_target_proxy = 1
        }
        function ensure_root_ipv4() {
            if (!inserted_ipv4) {
                print "ipv4 = \"" new_ipv4 "\""
                print ""
                inserted_ipv4 = 1
            }
        }
        function flush_proxy_block(    drop_block) {
            if (!in_proxy)
                return

            drop_block = 0
            if (proxy_cidr == new_lan)
                seen_target_proxy = 1
            if (old_lan != "" && old_lan != new_lan && proxy_cidr == old_lan)
                drop_block = 1

            if (!drop_block)
                printf "%s", proxy_block

            in_proxy = 0
            proxy_block = ""
            proxy_cidr = ""
        }
        BEGIN {
            inserted_proxy = 0
            seen_target_proxy = 0
            seen_flags = 0
            inserted_ipv4 = 0
            in_proxy = 0
            proxy_block = ""
            proxy_cidr = ""
        }
        {
            line = $0
            if (in_proxy) {
                if (line ~ /^\[\[proxy_network\]\]/ || line ~ /^\[/) {
                    flush_proxy_block()
                } else {
                    proxy_block = proxy_block line ORS
                    if (line ~ /^[[:space:]]*cidr[[:space:]]*=[[:space:]]*"/) {
                        proxy_cidr = line
                        sub(/^[^"]*"/, "", proxy_cidr)
                        sub(/".*$/, "", proxy_cidr)
                    }
                    next
                }
            }
            if (line ~ /^ipv4 = "/) {
                print "ipv4 = \"" new_ipv4 "\""
                inserted_ipv4 = 1
                next
            }
            if (line ~ /^\[\[proxy_network\]\]/) {
                if (!inserted_ipv4)
                    ensure_root_ipv4()
                in_proxy = 1
                proxy_block = line ORS
                proxy_cidr = ""
                next
            }
            if (line ~ /^proxy_networks = /) next
            if (line ~ /^\[/ && !inserted_ipv4)
                ensure_root_ipv4()
            if (line ~ /^\[flags\]/) {
                if (!seen_target_proxy && !inserted_proxy) print_proxy_block()
                print line
                print "proxy_forward_by_system = true"
                seen_flags = 1
                next
            }
            if (line ~ /^proxy_forward_by_system = /) next
            print line
        }
        END {
            flush_proxy_block()
            if (!inserted_ipv4)
                ensure_root_ipv4()
            if (!seen_flags) {
                if (!seen_target_proxy && !inserted_proxy) print_proxy_block()
                print "[flags]"
                print "proxy_forward_by_system = true"
            } else if (!seen_target_proxy && !inserted_proxy) {
                print_proxy_block()
            }
        }
    ' "$EASYTIER_CONFIG_FILE" > "$tmp_cfg"

    easytier-core --check-config -c "$tmp_cfg" >/dev/null 2>&1 || die 'EasyTier 配置写入后校验失败'
    backup_file "$EASYTIER_CONFIG_FILE"
    mv "$tmp_cfg" "$EASYTIER_CONFIG_FILE"
}

write_easytier_route_apply_script() {
    mkdir -p "$(dirname "$EASYTIER_ROUTE_APPLY_SCRIPT")"
    backup_file "$EASYTIER_ROUTE_APPLY_SCRIPT"

    cat > "$EASYTIER_ROUTE_APPLY_SCRIPT" <<EOF_EASYTIER_ROUTE_APPLY
#!/bin/sh
set -eu

STATE_FILE='$EASYTIER_ROUTE_STATE_FILE'

log() { printf '%s\n' "\$*"; }
die() { printf 'ERROR: %s\n' "\$*" >&2; exit 1; }

[ -f "\$STATE_FILE" ] || die '未找到 EasyTier 路由状态文件'
. "\$STATE_FILE" 2>/dev/null || die '读取 EasyTier 路由状态文件失败'

[ -n "\${ET_ROUTE_REMOTE_SUBNET:-}" ] || die '未找到远端 LAN 网段'
[ -n "\${ET_ROUTE_LOCAL_SUBNET:-}" ] || die '未找到本机 LAN 网段'
[ -n "\${ET_ROUTE_LAN_IF:-}" ] || ET_ROUTE_LAN_IF='br-lan'
[ -n "\${ET_ROUTE_TUN_IF:-}" ] || ET_ROUTE_TUN_IF='tun0'
command -v easytier-cli >/dev/null 2>&1 || die '未检测到 easytier-cli'
command -v ip >/dev/null 2>&1 || die '未检测到 ip 命令'
ip link show "\$ET_ROUTE_LAN_IF" >/dev/null 2>&1 || die "未检测到本地 LAN 接口：\$ET_ROUTE_LAN_IF"
ip link show "\$ET_ROUTE_TUN_IF" >/dev/null 2>&1 || die "未检测到 EasyTier 隧道接口：\$ET_ROUTE_TUN_IF"

parse_peer_virtual_ip() {
    target="\$1"
    easytier-cli route 2>/dev/null | awk -F'|' -v target="\$target" '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        {
            ip = trim(\$2)
            cidr = trim(\$4)
            if (cidr == target) {
                sub(/\/.*/, "", ip)
                print ip
                exit
            }
        }
    '
}

wait_for_peer_route() {
    target="\$1"
    count=0
    while [ "\$count" -lt 30 ]; do
        peer_ip="\$(parse_peer_virtual_ip "\$target" 2>/dev/null || true)"
        if [ -n "\$peer_ip" ]; then
            printf '%s\n' "\$peer_ip"
            return 0
        fi
        sleep 2
        count=\$((count + 1))
    done
    return 1
}

delete_rule_loop() {
    table="\$1"
    chain="\$2"
    shift 2
    command -v iptables >/dev/null 2>&1 || return 0
    while iptables -t "\$table" -C "\$chain" "\$@" >/dev/null 2>&1; do
        iptables -t "\$table" -D "\$chain" "\$@" >/dev/null 2>&1 || break
    done
}

ensure_rule() {
    table="\$1"
    chain="\$2"
    shift 2
    command -v iptables >/dev/null 2>&1 || return 0
    delete_rule_loop "\$table" "\$chain" "\$@"
    iptables -t "\$table" -A "\$chain" "\$@" >/dev/null 2>&1 || true
}

peer_virtual_ip="\$(wait_for_peer_route "\$ET_ROUTE_REMOTE_SUBNET" 2>/dev/null || true)"
[ -n "\$peer_virtual_ip" ] || die "未找到远端网段 \$ET_ROUTE_REMOTE_SUBNET 对应的 EasyTier 节点"

ip route replace "\$ET_ROUTE_REMOTE_SUBNET" via "\$peer_virtual_ip" dev "\$ET_ROUTE_TUN_IF" 2>/dev/null || die '写入远端网段路由失败'
ip rule del to "\$ET_ROUTE_REMOTE_SUBNET" lookup main priority 60 2>/dev/null || true
ip rule add to "\$ET_ROUTE_REMOTE_SUBNET" lookup main priority 60 2>/dev/null || true
ip rule del iif "\$ET_ROUTE_LAN_IF" to "\$ET_ROUTE_REMOTE_SUBNET" lookup main priority 70 2>/dev/null || true
ip rule add iif "\$ET_ROUTE_LAN_IF" to "\$ET_ROUTE_REMOTE_SUBNET" lookup main priority 70 2>/dev/null || true
ip rule del from "\$ET_ROUTE_LOCAL_SUBNET" to "\$ET_ROUTE_REMOTE_SUBNET" lookup main priority 196 2>/dev/null || true
ip rule add from "\$ET_ROUTE_LOCAL_SUBNET" to "\$ET_ROUTE_REMOTE_SUBNET" lookup main priority 196 2>/dev/null || true

ensure_rule nat POSTROUTING -s "\$ET_ROUTE_LOCAL_SUBNET" -d "\$ET_ROUTE_REMOTE_SUBNET" -o "\$ET_ROUTE_TUN_IF" -j MASQUERADE
ensure_rule filter FORWARD -s "\$ET_ROUTE_REMOTE_SUBNET" -d "\$ET_ROUTE_LOCAL_SUBNET" -i "\$ET_ROUTE_TUN_IF" -o "\$ET_ROUTE_LAN_IF" -j ACCEPT
ensure_rule filter FORWARD -d "\$ET_ROUTE_REMOTE_SUBNET" -i "\$ET_ROUTE_LAN_IF" -o "\$ET_ROUTE_TUN_IF" -j ACCEPT

log "route applied: \$ET_ROUTE_REMOTE_SUBNET via \$peer_virtual_ip dev \$ET_ROUTE_TUN_IF"
EOF_EASYTIER_ROUTE_APPLY

    chmod 755 "$EASYTIER_ROUTE_APPLY_SCRIPT"
    sh -n "$EASYTIER_ROUTE_APPLY_SCRIPT" >/dev/null 2>&1 || die 'generated EasyTier route script has syntax error'
}

install_easytier_route_rc_hook() {
    rc_local="/etc/rc.local"
    rc_tmp="$WORKDIR/rc.local.easytier"

    if [ ! -f "$rc_local" ]; then
        cat > "$rc_local" <<'EOF_EASYTIER_RC_LOCAL'
#!/bin/sh
exit 0
EOF_EASYTIER_RC_LOCAL
        chmod 755 "$rc_local"
    fi

    grep -q 'EASYTIER_ROUTE_WIZARD_BEGIN' "$rc_local" 2>/dev/null && return 0

    backup_file "$rc_local"
    awk -v cmd='[ -x /etc/easytier/route-apply.sh ] && sh /etc/easytier/route-apply.sh >/tmp/easytier-route-apply.log 2>&1 &' '
        BEGIN { inserted = 0 }
        /^exit 0$/ {
            if (!inserted) {
                print "# EASYTIER_ROUTE_WIZARD_BEGIN"
                print cmd
                print "# EASYTIER_ROUTE_WIZARD_END"
                inserted = 1
            }
        }
        { print }
        END {
            if (!inserted) {
                print "# EASYTIER_ROUTE_WIZARD_BEGIN"
                print cmd
                print "# EASYTIER_ROUTE_WIZARD_END"
                print "exit 0"
            }
        }
    ' "$rc_local" > "$rc_tmp" && mv "$rc_tmp" "$rc_local"
    chmod 755 "$rc_local" 2>/dev/null || true
}

wait_easytier_route_publish() {
    route_target="$1"
    wait_count=0
    while [ "$wait_count" -lt 15 ]; do
        easytier-cli node 2>/dev/null | grep -F "$route_target" >/dev/null 2>&1 && return 0
        sleep 2
        wait_count=$((wait_count + 1))
    done
    return 1
}

configure_easytier_routes() {
    local old_route_local_subnet old_route_remote_subnet old_route_lan_if old_route_tun_if

    mkdir -p "$WORKDIR" >/dev/null 2>&1 || die "无法创建临时工作目录：$WORKDIR"
    ensure_state_dir
    [ -f "$EASYTIER_CONFIG_FILE" ] || die '未检测到 /etc/easytier/config.toml，请先安装并配置 EasyTier'
    command -v easytier-core >/dev/null 2>&1 || die '未检测到 easytier-core，请先安装 EasyTier'
    command -v easytier-cli >/dev/null 2>&1 || die '未检测到 easytier-cli，请先安装 EasyTier'
    command -v ip >/dev/null 2>&1 || die '未检测到 ip 命令，请先安装 ip-full 或确认系统环境完整'
    [ -f /etc/init.d/easytier ] || die '未检测到 /etc/init.d/easytier，请先安装 EasyTier'

    load_easytier_route_state
    old_route_local_subnet="${ET_ROUTE_LOCAL_SUBNET:-}"
    old_route_remote_subnet="${ET_ROUTE_REMOTE_SUBNET:-}"
    old_route_lan_if="${ET_ROUTE_LAN_IF:-}"
    old_route_tun_if="${ET_ROUTE_TUN_IF:-}"

    lan_if_default="${ET_ROUTE_LAN_IF:-br-lan}"
    prompt_with_default '本地 LAN 接口' "$lan_if_default"
    ET_ROUTE_LAN_IF="$PROMPT_RESULT"
    case "$ET_ROUTE_LAN_IF" in
        *[[:space:]]*) die 'LAN interface must not contain spaces' ;;
    esac
    ip link show "$ET_ROUTE_LAN_IF" >/dev/null 2>&1 || die "未检测到本地 LAN 接口：$ET_ROUTE_LAN_IF"

    tun_if_default="${ET_ROUTE_TUN_IF:-}"
    if [ -z "$tun_if_default" ]; then
        tun_if_default="$(ip -o link show 2>/dev/null | awk -F': ' '/tun[0-9]+/{print $2; exit}' | sed 's/@.*//')"
    fi
    [ -n "$tun_if_default" ] || tun_if_default='tun0'
    prompt_with_default 'EasyTier 隧道接口名' "$tun_if_default"
    ET_ROUTE_TUN_IF="$PROMPT_RESULT"
    case "$ET_ROUTE_TUN_IF" in
        *[[:space:]]*) die 'EasyTier interface must not contain spaces' ;;
    esac
    if ! ip link show "$ET_ROUTE_TUN_IF" >/dev/null 2>&1; then
        log "提示: 当前尚未检测到 EasyTier 隧道接口 $ET_ROUTE_TUN_IF，将在重启 EasyTier 后继续校验"
    fi

    virtual_default="$ET_ROUTE_VIRTUAL_IP"
    [ -n "$virtual_default" ] || virtual_default="$(sed -n 's/^ipv4 = "\([^\"]*\)"/\1/p' "$EASYTIER_CONFIG_FILE" | sed -n '1p')"
    [ -n "$virtual_default" ] || virtual_default='11.11.11.12/24'
    prompt_with_default 'EasyTier 虚拟 IP（CIDR，例如 11.11.11.12/24）' "$virtual_default"
    ET_ROUTE_VIRTUAL_IP="$(normalize_ipv4_cidr "$PROMPT_RESULT" 2>/dev/null || true)"
    [ -n "$ET_ROUTE_VIRTUAL_IP" ] || die 'EasyTier 虚拟 IP 格式无效'

    local_default="$ET_ROUTE_LOCAL_SUBNET"
    [ -n "$local_default" ] || local_default="$(get_default_lan_subnet 2>/dev/null || true)"
    [ -n "$local_default" ] || local_default='192.168.66.0/24'
    prompt_with_default '本机 LAN 网段（CIDR，例如 192.168.66.0/24）' "$local_default"
    ET_ROUTE_LOCAL_SUBNET="$(normalize_ipv4_cidr "$PROMPT_RESULT" 2>/dev/null || true)"
    [ -n "$ET_ROUTE_LOCAL_SUBNET" ] || die '本机 LAN 网段格式无效'

    remote_default="$ET_ROUTE_REMOTE_SUBNET"
    if [ -z "$remote_default" ]; then
        remote_default="$(easytier-cli route 2>/dev/null | awk -F'|' -v local="$ET_ROUTE_LOCAL_SUBNET" '
            function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
            {
                cidr = trim($4)
                if (cidr ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+$/ && cidr != local && cidr != "192.0.0.0/8") {
                    print cidr
                    exit
                }
            }
        ')"
    fi
    [ -n "$remote_default" ] || remote_default='192.168.88.0/24'
    prompt_with_default '远端 LAN 网段（CIDR，例如 192.168.88.0/24）' "$remote_default"
    ET_ROUTE_REMOTE_SUBNET="$(normalize_ipv4_cidr "$PROMPT_RESULT" 2>/dev/null || true)"
    [ -n "$ET_ROUTE_REMOTE_SUBNET" ] || die '远端 LAN 网段格式无效'
    [ "$ET_ROUTE_REMOTE_SUBNET" != "$ET_ROUTE_LOCAL_SUBNET" ] || die '远端 LAN 网段不能与本机 LAN 网段相同'

    log "summary: EasyTier 隧道接口=$ET_ROUTE_TUN_IF"
    log "summary: 本地 LAN 接口=$ET_ROUTE_LAN_IF"
    log "summary: 虚拟 IP=$ET_ROUTE_VIRTUAL_IP"
    log "summary: 本机 LAN 网段=$ET_ROUTE_LOCAL_SUBNET"
    log "summary: 远端 LAN 网段=$ET_ROUTE_REMOTE_SUBNET"
    log 'summary: 将启用 EasyTier 原生子网代理，并写入独立路由脚本'
    confirm_or_exit '确认写入 EasyTier 路由配置并修改系统吗？'

    if [ -n "$old_route_remote_subnet" ] && {
        [ "$old_route_remote_subnet" != "$ET_ROUTE_REMOTE_SUBNET" ] ||
        [ "$old_route_local_subnet" != "$ET_ROUTE_LOCAL_SUBNET" ] ||
        [ "${old_route_lan_if:-br-lan}" != "$ET_ROUTE_LAN_IF" ] ||
        [ "${old_route_tun_if:-tun0}" != "$ET_ROUTE_TUN_IF" ];
    }; then
        cleanup_easytier_route_runtime_state "$old_route_local_subnet" "$old_route_remote_subnet" "$old_route_lan_if" "$old_route_tun_if"
    fi

    write_easytier_route_config "$ET_ROUTE_VIRTUAL_IP" "$ET_ROUTE_LOCAL_SUBNET" "$old_route_local_subnet"
    save_easytier_route_state
    write_easytier_route_apply_script
    install_easytier_route_rc_hook

    if uci -q get firewall.easytierzone >/dev/null 2>&1; then
        uci -q set firewall.easytierzone.masq='0'
        uci -q commit firewall >/dev/null 2>&1 || true
    fi

    /etc/init.d/easytier enable >/dev/null 2>&1 || true
    /etc/init.d/easytier restart >/dev/null 2>&1 || die '重启 EasyTier 失败'
    /etc/init.d/firewall restart >/dev/null 2>&1 || true
    sh "$EASYTIER_ROUTE_APPLY_SCRIPT" >/tmp/easytier-route-apply.log 2>&1 || {
        sed -n '1,120p' /tmp/easytier-route-apply.log >&2
        die '应用 EasyTier 路由脚本失败'
    }

    ip route | awk -v subnet="$ET_ROUTE_REMOTE_SUBNET" -v tun="$ET_ROUTE_TUN_IF" '
        $1 == subnet && $2 == "via" && $4 == "dev" && $5 == tun { found = 1 }
        END { exit found ? 0 : 1 }
    ' || die "route apply failed: missing $ET_ROUTE_REMOTE_SUBNET dev $ET_ROUTE_TUN_IF"
    wait_easytier_route_publish "$ET_ROUTE_LOCAL_SUBNET" || die '本机 LAN 网段尚未发布到 EasyTier'

    log "安装完成"
    log "插件:   EasyTier 路由向导"
    log "脚本:   $EASYTIER_ROUTE_APPLY_SCRIPT"
    log "lan-if:  $ET_ROUTE_LAN_IF"
    log "tun-if:  $ET_ROUTE_TUN_IF"
    log "virtual: $ET_ROUTE_VIRTUAL_IP"
    log "local:   $ET_ROUTE_LOCAL_SUBNET"
    log "remote:  $ET_ROUTE_REMOTE_SUBNET"
}

write_openvpn_custom_ui_files() {
    mkdir -p /usr/lib/lua/luci/controller/nradio_adv /usr/lib/lua/luci/view/nradio_adv /usr/lib/lua/luci/view/openvpn /usr/lib/lua/luci/model/cbi

    cat > /usr/lib/lua/luci/controller/nradio_adv/openvpn_full.lua <<'EOF_OPENVPN_FULL_CONTROLLER'
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
EOF_OPENVPN_FULL_CONTROLLER

    cat > /usr/lib/lua/luci/view/nradio_adv/openvpn_full.htm <<'EOF_OPENVPN_FULL_VIEW'
<%+header%>
<%
local dispatcher = require "luci.dispatcher"
local util = require "luci.util"
local function cmd(c) return util.trim(util.exec(c) or "") end
local function esc(s) return luci.util.pcdata(s or "") end
local cfg = cmd("sed -n '1,240p' /etc/openvpn/client.ovpn 2>/dev/null")
%>

<%+openvpn/ovpn_css%>

<div class="vpn-shell vpn-shell-refined vpn-shell-mk2">
  <section class="vpn-hero vpn-hero-mk2">
    <div class="vpn-hero-main">
      <div class="vpn-brand-block">
        <div class="vpn-toolbar">
          <span class="vpn-pill">OpenVPN</span>
          <span id="vpn-health-chip" class="vpn-health-chip bad">等待更新</span>
          <span id="vpn-live-ts" class="vpn-inline-note">更新中</span>
        </div>
        <h2>OpenVPN 连接中枢</h2>
        <p class="vpn-sub">右侧处理启动、停止、刷新和复制；下方集中查看运行、认证、路由和日志。</p>
        <div class="vpn-stage-line" aria-label="OpenVPN 状态闭环">
          <span id="vpn-stage-config" class="vpn-stage-chip wait">配置</span>
          <span id="vpn-stage-auth" class="vpn-stage-chip wait">认证</span>
          <span id="vpn-stage-tunnel" class="vpn-stage-chip wait">隧道</span>
          <span id="vpn-stage-route" class="vpn-stage-chip wait">路由</span>
        </div>
      </div>

      <aside class="vpn-command-card">
        <div class="vpn-orb-wrap">
          <div id="vpn-orb-ring" class="vpn-orb-ring bad">
            <span id="vpn-orb-status">等待</span>
          </div>
          <div class="vpn-orb-copy">
            <strong id="vpn-orb-subtitle">正在读取状态</strong>
            <span id="vpn-orb-meta">连接、认证、路由会自动汇总。</span>
          </div>
        </div>
        <div class="vpn-hero-actions">
          <form id="vpn-primary-form" method="post" action="#">
            <input id="vpn-primary-button" class="cbi-button vpn-button-muted" type="submit" value="读取状态中" disabled="disabled" />
          </form>
          <form id="vpn-stop-form" method="post" action="<%=dispatcher.build_url('nradioadv','system','openvpnfull','stop')%>" style="display:none">
            <input id="vpn-stop-button" class="cbi-button vpn-button-muted" type="submit" value="停止 OpenVPN" />
          </form>
          <a id="vpn-refresh-button" class="cbi-button vpn-button-muted" href="#" onclick="return vpnManualRefresh();">刷新状态</a>
          <a id="vpn-copy-button" class="cbi-button vpn-button-muted" href="#" onclick="return vpnCopyConfig();">复制配置</a>
          <span id="vpn-copy-feedback" class="vpn-copy-feedback" aria-live="polite"></span>
        </div>
        <div id="vpn-action-hint" class="vpn-hero-note">当前页会按配置状态自动切换主操作。</div>
      </aside>
    </div>

    <div class="vpn-mini-grid vpn-mini-grid-mk2">
      <div class="vpn-mini-card vpn-mini-card-accent vpn-mini-card-wide">
        <span class="vpn-mini-label">当前动作</span>
        <strong id="vpn-mini-action">等待更新</strong>
        <span id="vpn-mini-action-note" class="vpn-mini-note">主按钮会按状态自动切换。</span>
      </div>
      <div class="vpn-mini-card">
        <span class="vpn-mini-label">服务接管</span>
        <strong id="vpn-mini-managed">等待更新</strong>
        <span id="vpn-mini-managed-note" class="vpn-mini-note">运行链路和接管状态将在此汇总。</span>
      </div>
      <div class="vpn-mini-card">
        <span class="vpn-mini-label">认证准备</span>
        <strong id="vpn-mini-auth">等待更新</strong>
        <span id="vpn-mini-auth-note" class="vpn-mini-note">账号、证书和 TLS 密钥准备情况。</span>
      </div>
      <div class="vpn-mini-card">
        <span class="vpn-mini-label">路由健康</span>
        <strong id="vpn-mini-route">等待更新</strong>
        <span id="vpn-mini-route-note" class="vpn-mini-note">远端目标和 DNAT 规则会一起汇总。</span>
      </div>
    </div>

    <div class="vpn-stat-grid">
      <div class="vpn-stat-card">
        <span class="vpn-stat-label">隧道 IP</span>
        <strong id="vpn-stat-tun-ip" class="vpn-stat-value">-</strong>
        <span id="vpn-stat-tun-meta" class="vpn-stat-meta">tun0 当前地址</span>
      </div>

      <div class="vpn-stat-card vpn-stat-card-remote">
        <span class="vpn-stat-label">配置远端</span>
        <strong id="vpn-stat-remote" class="vpn-stat-value">-</strong>
        <span id="vpn-stat-remote-meta" class="vpn-stat-meta">协议: - · 当前写入的 remote</span>
        <span id="vpn-stat-remote-note" class="vpn-stat-note">实际链路解析结果请以下方关键日志为准。</span>
      </div>

      <div class="vpn-stat-card">
        <span class="vpn-stat-label">认证方式</span>
        <strong id="vpn-stat-auth-mode" class="vpn-stat-value">-</strong>
        <span id="vpn-stat-auth-meta" class="vpn-stat-meta">TLS: - · Cipher: -</span>
      </div>

      <div class="vpn-stat-card vpn-stat-card-emphasis">
        <span class="vpn-stat-label">在线设备</span>
        <strong id="vpn-stat-health-ratio" class="vpn-stat-value">-</strong>
        <span id="vpn-stat-health-meta" class="vpn-stat-meta">远端目标在线比例</span>
      </div>
    </div>
  </section>

  <section class="vpn-overview-grid">
    <article id="vpn-runtime-card" class="vpn-card">
      <div class="vpn-card-head">
        <div class="vpn-card-title">运行与启动</div>
        <span id="vpn-runtime-badge" class="vpn-card-badge vpn-badge-bad">等待更新</span>
      </div>
      <div class="vpn-kv"><span>服务状态</span><strong id="vpn-runtime-service">-</strong></div>
      <div class="vpn-kv"><span>接管状态</span><strong id="vpn-runtime-managed">-</strong></div>
      <div class="vpn-kv"><span>推荐动作</span><strong id="vpn-runtime-action">-</strong></div>
      <div class="vpn-kv"><span>启动方式</span><strong id="vpn-runtime-mode">-</strong></div>
      <div class="vpn-kv"><span>连接日志</span><strong id="vpn-runtime-log-state" class="vpn-inline-badge vpn-badge-neutral">等待更新</strong></div>
      <div class="vpn-kv"><span>进程状态</span><strong id="vpn-runtime-process">-</strong></div>
      <div id="vpn-runtime-note" class="vpn-card-note">断开后如条件满足，可直接从当前页启动或接管启动。</div>
    </article>

    <article id="vpn-auth-card" class="vpn-card">
      <div class="vpn-card-head">
        <div class="vpn-card-title">认证与准备</div>
        <span id="vpn-auth-badge" class="vpn-card-badge vpn-badge-neutral">等待更新</span>
      </div>
      <div class="vpn-kv"><span>账号认证</span><strong id="vpn-auth-userpass">-</strong></div>
      <div class="vpn-kv"><span>认证要求</span><strong id="vpn-auth-requirement">-</strong></div>
      <div class="vpn-kv"><span>证书材料</span><strong id="vpn-auth-cert-material">-</strong></div>
      <div class="vpn-kv"><span>启动条件</span><strong id="vpn-auth-ready">-</strong></div>
      <div class="vpn-kv"><span>TLS 密钥</span><strong id="vpn-auth-tls">-</strong></div>
      <div id="vpn-auth-note" class="vpn-card-note">配置文件和认证材料齐全后，当前页才能直接启动。</div>
    </article>

    <article id="vpn-route-card" class="vpn-card">
      <div class="vpn-card-head">
        <div class="vpn-card-title">路由与映射</div>
        <span id="vpn-route-badge" class="vpn-card-badge vpn-badge-neutral">等待更新</span>
      </div>
      <div class="vpn-kv"><span>远端目标</span><strong id="vpn-route-count">-</strong></div>
      <div class="vpn-kv"><span>远端在线</span><strong id="vpn-peer-count">-</strong></div>
      <div class="vpn-kv"><span>规则健康</span><strong id="vpn-route-ratio">-</strong></div>
      <div class="vpn-kv"><span>本地映射 IP</span><strong id="vpn-map-ip">-</strong></div>
      <div class="vpn-kv"><span>DNAT</span><strong id="vpn-dnat-status" class="vpn-inline-badge vpn-badge-neutral">等待更新</strong></div>
      <div id="vpn-route-note" class="vpn-card-note">下方“实时校验”展示每个目标的详细结果。</div>
    </article>
  </section>

  <section class="vpn-quick-rail">
    <div class="vpn-quick-rail-head">
      <div>
        <div class="vpn-quick-rail-title">配置入口</div>
        <p class="vpn-quick-rail-sub">把配置类操作收在一行，首屏先看状态和动作，需要改项时再下钻。</p>
      </div>
      <span class="vpn-card-badge vpn-badge-neutral">导航</span>
    </div>
    <div class="vpn-action-list vpn-action-list-compact">
        <a class="vpn-action-tile" href="<%=url('admin/services/openvpn/basic', 'custom_config')%>">
          <strong>基础配置</strong>
          <span>适合修改远端、协议、端口和证书。</span>
        </a>
        <a class="vpn-action-tile" href="<%=url('admin/services/openvpn/advanced', 'custom_config')%>">
          <strong>高级配置</strong>
          <span>适合调整更细粒度的 OpenVPN 指令。</span>
        </a>
        <a class="vpn-action-tile" href="<%=url('admin/services/openvpn')%>">
          <strong>标准 OpenVPN</strong>
          <span>进入原生实例管理页和兼容配置入口。</span>
        </a>
      </div>
  </section>

  <section class="vpn-panel-shell">
    <div class="vpn-panel-shell-head">
      <div>
        <span class="vpn-panel-shell-kicker">诊断工作区</span>
        <h3>日志与路由联动排查</h3>
        <p>优先看关键日志和实时校验，出现异常后再下钻到完整运行日志、配置内容和隧道信息。</p>
      </div>
      <span id="vpn-panel-live-badge" class="vpn-panel-live-badge">等待更新</span>
    </div>
    <div class="vpn-tabbar">
      <button class="vpn-tab-btn vpn-tab-btn-major is-active" type="button" data-target="vpn-focus-panel">关键日志</button>
      <button class="vpn-tab-btn vpn-tab-btn-major" type="button" data-target="vpn-route-panel">实时校验</button>
      <button class="vpn-tab-btn" type="button" data-target="vpn-config-panel">客户端配置</button>
      <button class="vpn-tab-btn" type="button" data-target="vpn-runtime-panel">运行日志</button>
      <button class="vpn-tab-btn" type="button" data-target="vpn-tun-panel">隧道信息</button>
    </div>

    <div id="vpn-focus-panel" class="vpn-panel vpn-panel-major is-active">
      <div class="vpn-panel-head">
        <h3>关键日志</h3>
        <span id="vpn-focus-meta">优先展示连接、认证、路由相关行。</span>
      </div>
      <div class="vpn-focus-strip">
        <span class="vpn-focus-pill">优先项: TLS / AUTH / tun0</span>
        <span id="vpn-focus-ts" class="vpn-focus-pill vpn-focus-pill-muted">等待更新</span>
      </div>
      <pre id="vpn-focus-log">等待更新</pre>
    </div>

    <div id="vpn-route-panel" class="vpn-panel vpn-panel-major">
      <div class="vpn-panel-head">
        <h3>实时校验</h3>
        <span id="vpn-route-meta">基于当前内核状态与目标探测的实时结果。优先看离线和缺规则项。</span>
      </div>
      <div class="vpn-focus-strip vpn-focus-strip-route">
        <span id="vpn-route-strip-count" class="vpn-focus-pill">目标数: -</span>
        <span id="vpn-route-strip-health" class="vpn-focus-pill vpn-focus-pill-muted">规则健康: -</span>
        <span id="vpn-route-strip-dnat" class="vpn-focus-pill vpn-focus-pill-muted">DNAT: -</span>
      </div>
      <div class="vpn-split-grid">
        <div class="vpn-subcard">
          <div class="vpn-subcard-title">远端目标</div>
          <div id="vpn-route-check-list" class="vpn-check-list">
            <div class="vpn-check-empty">等待更新</div>
          </div>
        </div>

        <div class="vpn-subcard">
          <div class="vpn-subcard-title">本地映射</div>
          <div id="vpn-nat-check-list" class="vpn-check-list">
            <div class="vpn-check-empty">等待更新</div>
          </div>
        </div>
      </div>
    </div>

    <div id="vpn-config-panel" class="vpn-panel">
      <div class="vpn-panel-head">
        <h3>客户端配置</h3>
        <span>只读展示当前写入的 client.ovpn 内容。</span>
      </div>
      <textarea id="vpn-config-copy-source" class="vpn-copy-source"><%=esc(cfg ~= "" and cfg or "no config")%></textarea>
      <pre id="vpn-config-pre"><%=esc(cfg ~= "" and cfg or "no config")%></pre>
    </div>

    <div id="vpn-runtime-panel" class="vpn-panel">
      <div class="vpn-panel-head">
        <h3>运行日志</h3>
        <span id="vpn-runtime-meta">完整日志更适合排查重连、认证和 TLS 问题。</span>
      </div>
      <pre id="vpn-runtime-log">等待更新</pre>
    </div>

    <div id="vpn-tun-panel" class="vpn-panel">
      <div class="vpn-panel-head">
        <h3>隧道信息</h3>
        <span id="vpn-tun-meta">展示 tun0 与 br-lan 的当前地址信息。</span>
      </div>
      <div class="vpn-split-grid">
        <div class="vpn-subcard">
          <div class="vpn-subcard-title">tun0</div>
          <pre id="vpn-tun-pre">等待更新</pre>
        </div>
        <div class="vpn-subcard">
          <div class="vpn-subcard-title">br-lan</div>
          <pre id="vpn-lan-pre">等待更新</pre>
        </div>
      </div>
    </div>
  </section>
</div>

<script>
function vpnCopyConfig() {
  var source = document.getElementById('vpn-config-copy-source');
  if (!source || !source.value || source.value === 'no config') {
    if (window.vpnShowCopyFeedback) {
      window.vpnShowCopyFeedback('当前没有可复制的 client.ovpn', 'warn');
    }
    return false;
  }
  source.style.display = 'block';
  source.select();
  source.setSelectionRange(0, source.value.length);
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(source.value).then(function() {
        if (window.vpnShowCopyFeedback) {
          window.vpnShowCopyFeedback('已复制 client.ovpn', 'ok');
        }
      }).catch(function() {
        document.execCommand('copy');
        if (window.vpnShowCopyFeedback) {
          window.vpnShowCopyFeedback('已复制 client.ovpn', 'ok');
        }
      });
    } else {
      document.execCommand('copy');
      if (window.vpnShowCopyFeedback) {
        window.vpnShowCopyFeedback('已复制 client.ovpn', 'ok');
      }
    }
  } catch (e) {
    if (window.vpnShowCopyFeedback) {
      window.vpnShowCopyFeedback('浏览器限制，已切到手动复制', 'warn');
    }
    window.prompt('复制配置', source.value);
  }
  source.blur();
  source.style.display = 'none';
  return false;
}

(function() {
  var buttons = document.querySelectorAll('.vpn-tab-btn');
  var panels = document.querySelectorAll('.vpn-panel');

  function activate(targetId) {
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].className = buttons[i].className.replace(/\bis-active\b/g, '').replace(/\s+/g, ' ').replace(/^\s|\s$/g, '');
      if (buttons[i].getAttribute('data-target') === targetId) {
        buttons[i].className += (buttons[i].className ? ' ' : '') + 'is-active';
      }
    }
    for (var j = 0; j < panels.length; j++) {
      panels[j].className = panels[j].className.replace(/\bis-active\b/g, '').replace(/\s+/g, ' ').replace(/^\s|\s$/g, '');
      if (panels[j].id === targetId) {
        panels[j].className += (panels[j].className ? ' ' : '') + 'is-active';
      }
    }
  }

  for (var i = 0; i < buttons.length; i++) {
    buttons[i].onclick = function() {
      activate(this.getAttribute('data-target'));
      return false;
    };
  }
})();

(function() {
  var copyFeedbackTimer = 0;

  window.vpnShowCopyFeedback = function(message, state) {
    var el = document.getElementById('vpn-copy-feedback');
    if (!el) {
      return;
    }
    if (copyFeedbackTimer) {
      window.clearTimeout(copyFeedbackTimer);
      copyFeedbackTimer = 0;
    }
    el.className = 'vpn-copy-feedback is-visible' + (state ? (' ' + state) : '');
    el.textContent = message || '';
    copyFeedbackTimer = window.setTimeout(function() {
      el.className = 'vpn-copy-feedback';
      el.textContent = '';
    }, 2200);
  };

  var statusUrl = '<%=dispatcher.build_url("nradioadv","system","openvpnfull","status")%>';
  var restartUrl = '<%=dispatcher.build_url("nradioadv","system","openvpnfull","restart")%>';
  var applyCurrentUrl = '<%=dispatcher.build_url("nradioadv","system","openvpnfull","applycurrent")%>';
  var statusBusy = false;
  var lastGoodStatus = null;
  var pendingManualRefresh = false;

  function esc(text) {
    return String(text == null ? '' : text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function setText(id, text) {
    var el = document.getElementById(id);
    if (el) {
      el.textContent = text == null ? '' : String(text);
    }
  }

  function setHtml(id, html) {
    var el = document.getElementById(id);
    if (el) {
      el.innerHTML = html;
    }
  }

  function setClass(id, className) {
    var el = document.getElementById(id);
    if (el) {
      el.className = className;
    }
  }

  function setVisible(id, visible) {
    var el = document.getElementById(id);
    if (el) {
      el.style.display = visible ? '' : 'none';
    }
  }

  function setShellState(stateClass) {
    var shell = document.querySelector('.vpn-shell-refined');
    if (shell) {
      shell.className = 'vpn-shell vpn-shell-refined vpn-shell-mk2' + (stateClass ? (' ' + stateClass) : '');
    }
  }

  function setCardState(id, stateClass) {
    var el = document.getElementById(id);
    if (el) {
      el.className = 'vpn-card' + (stateClass ? (' ' + stateClass) : '');
    }
  }

  function setStageState(id, stateClass) {
    var el = document.getElementById(id);
    if (el) {
      el.className = 'vpn-stage-chip ' + (stateClass || 'wait');
    }
  }

  function renderRemoteValue(remote) {
    var text = String(remote == null ? '' : remote).replace(/^\s+|\s+$/g, '');
    if (!text || text === '-') {
      return '-';
    }

    var parts = text.split(/\s+/);
    if (parts.length >= 2 && /^\d{2,5}$/.test(parts[parts.length - 1])) {
      var port = parts.pop();
      var host = parts.join(' ');
      return '<span class="vpn-remote-host">' + esc(host) + '</span><span class="vpn-remote-port">' + esc(port) + '</span>';
    }

    return '<span class="vpn-remote-host">' + esc(text) + '</span>';
  }

  function renderBadges(items) {
    var html = [];
    for (var i = 0; i < items.length; i++) {
      html.push('<span class="vpn-micro-badge ' + esc(items[i].state || 'neutral') + '">' + esc(items[i].label || '-') + '</span>');
    }
    return html.join('');
  }

  function renderRouteChecks(status) {
    var html = [];
    if (!status.route_checks || !status.route_checks.length) {
      setHtml('vpn-route-check-list', '<div class="vpn-check-empty">当前没有检测到远端目标。</div>');
      return;
    }

    var ordered = status.route_checks.slice().sort(function(a, b) {
      var aKind = a.kind === 'host' ? 1 : 0;
      var bKind = b.kind === 'host' ? 1 : 0;
      if (aKind !== bKind) {
        return aKind - bKind;
      }
      if (!!a.probe_ok !== !!b.probe_ok) {
        return a.probe_ok ? 1 : -1;
      }
      return String(a.target || '').localeCompare(String(b.target || ''));
    });

    var subnetHtml = [];
    var hostHtml = [];

    for (var i = 0; i < ordered.length; i++) {
      var item = ordered[i];
      var badges = [
        { label: '主规则', state: item.to_rule_ok ? 'ok' : 'bad' },
        { label: 'LAN规则', state: item.iif_rule_ok ? 'ok' : 'bad' },
        { label: item.probe_ok ? '在线' : '离线', state: item.probe_ok ? 'ok' : 'bad' }
      ];

      if (item.kind === 'host') {
        badges.push({ label: '代理', state: item.proxy_ok ? 'ok' : 'bad' });
      }

      var rowHtml =
        '<div class="vpn-check-row">' +
          '<div class="vpn-check-main">' +
            '<strong>' + esc(item.target) + '</strong>' +
            '<span>via ' + esc(item.via || '-') + ' · ' + (item.kind === 'host' ? '主机映射' : '网段路由') + ' · 探测 ' + esc(item.probe_ip || '-') + '</span>' +
          '</div>' +
          '<div class="vpn-check-badges">' + renderBadges(badges) + '</div>' +
        '</div>';

      if (item.kind === 'host') {
        hostHtml.push(rowHtml);
      } else {
        subnetHtml.push(rowHtml);
      }
    }

    html.push('<div class="vpn-check-section"><div class="vpn-check-section-title">网段路由</div>' + (subnetHtml.length ? subnetHtml.join('') : '<div class="vpn-check-empty">当前没有网段路由。</div>') + '</div>');
    html.push('<div class="vpn-check-section"><div class="vpn-check-section-title">主机映射</div>' + (hostHtml.length ? hostHtml.join('') : '<div class="vpn-check-empty">当前没有主机映射。</div>') + '</div>');
    setHtml('vpn-route-check-list', html.join(''));
  }

  function renderNatChecks(status) {
    var mapEnabled = !!(status.map_ip && status.map_ip !== '-');
    var natHtml =
      '<div class="vpn-check-row">' +
        '<div class="vpn-check-main">' +
          '<strong>本地映射 IP</strong>' +
          '<span>' + esc(mapEnabled ? status.map_ip : '未检测到 /32 映射地址') + '</span>' +
        '</div>' +
        '<div class="vpn-check-badges">' + renderBadges([{ label: 'IP', state: mapEnabled ? 'ok' : 'bad' }]) + '</div>' +
      '</div>' +
      '<div class="vpn-check-row">' +
        '<div class="vpn-check-main">' +
          '<strong>DNAT 规则</strong>' +
          '<span>检查 PREROUTING / OUTPUT 两条当前内核规则。</span>' +
        '</div>' +
        '<div class="vpn-check-badges">' + renderBadges([
          { label: '入口', state: status.dnat_pre_ok ? 'ok' : 'bad' },
          { label: '回环', state: status.dnat_out_ok ? 'ok' : 'bad' }
        ]) + '</div>' +
      '</div>' +
      '<div class="vpn-check-row">' +
        '<div class="vpn-check-main">' +
          '<strong>MASQUERADE</strong>' +
          '<span>当前命中 ' + esc(status.masquerade_hits || 0) + ' 条 tun0 目的规则。</span>' +
        '</div>' +
        '<div class="vpn-check-badges">' + renderBadges([{ label: 'NAT', state: (status.masquerade_hits || 0) > 0 ? 'ok' : 'neutral' }]) + '</div>' +
      '</div>';

    setHtml('vpn-nat-check-list', natHtml);
  }

  function applyStatus(status) {
    if (!status) {
      return;
    }

    var shellState = 'is-empty';
    if (status.connected) {
      if (status.health_class === 'ok') {
        shellState = 'is-ok';
      } else if (status.health_class === 'warn') {
        shellState = 'is-warn';
      } else {
        shellState = 'is-bad';
      }
    } else if (status.activation_ready) {
      shellState = 'is-ready';
    } else if (status.profile_ready) {
      shellState = 'is-profile-ready';
    }
    setShellState(shellState);

    var primaryForm = document.getElementById('vpn-primary-form');
    var primaryButton = document.getElementById('vpn-primary-button');
    var stopForm = document.getElementById('vpn-stop-form');
    if (primaryForm && primaryButton) {
      if (status.connected) {
        if (status.health_class === 'ok') {
          primaryForm.action = '#';
          primaryButton.value = status.action_label || 'OpenVPN 运行中';
          primaryButton.className = 'cbi-button vpn-button-passive';
          primaryButton.disabled = true;
          primaryButton.title = '当前连接稳定，如无异常无需重连。';
          setVisible('vpn-stop-form', true);
        } else {
          primaryForm.action = restartUrl;
          primaryButton.value = status.action_label || '重连 OpenVPN';
          primaryButton.className = 'cbi-button cbi-button-apply';
          primaryButton.disabled = false;
          primaryButton.title = '当前连接存在异常，建议重新拉起。';
          setVisible('vpn-stop-form', true);
        }
      } else if (status.activation_ready) {
        primaryForm.action = applyCurrentUrl;
        primaryButton.value = status.action_label || (status.uci_managed ? '启动 OpenVPN' : '接管并启动');
        primaryButton.className = 'cbi-button cbi-button-apply';
        primaryButton.disabled = false;
        primaryButton.title = '当前配置和认证材料已齐，可直接启动。';
        setVisible('vpn-stop-form', false);
      } else if (status.profile_ready) {
        primaryForm.action = '#';
        primaryButton.value = status.action_label || '补齐认证文件';
        primaryButton.className = 'cbi-button vpn-button-muted';
        primaryButton.disabled = true;
        primaryButton.title = '还缺少认证文件，当前不能直接启动。';
        setVisible('vpn-stop-form', false);
      } else {
        primaryForm.action = '#';
        primaryButton.value = status.action_label || '先写入配置';
        primaryButton.className = 'cbi-button vpn-button-muted';
        primaryButton.disabled = true;
        primaryButton.title = '当前还没有完整配置，请先写入 client.ovpn。';
        setVisible('vpn-stop-form', false);
      }
    }

    setClass('vpn-health-chip', 'vpn-health-chip ' + esc(status.health_class || 'bad'));
    setText('vpn-health-chip', status.status_summary_label || status.health_label || '未连接');
    setText('vpn-live-ts', (status.ts ? ('更新 ' + status.ts) : '更新中'));
    setClass('vpn-orb-ring', 'vpn-orb-ring ' + esc(status.health_class || 'bad'));
    setText('vpn-orb-status', status.connected ? (status.health_label || '在线') : (status.activation_ready ? '可启动' : (status.profile_ready ? '待补齐' : '待配置')));
    setText('vpn-orb-subtitle', status.action_label || '-');
    setText('vpn-orb-meta', (status.mode_label || status.mode || '-') + ' · ' + (status.online_breakdown || '等待路由状态'));
    setStageState('vpn-stage-config', status.profile_ready ? 'ok' : 'bad');
    setStageState('vpn-stage-auth', status.activation_ready ? 'ok' : (status.profile_ready ? 'warn' : 'wait'));
    setStageState('vpn-stage-tunnel', status.connected ? (status.health_class === 'ok' ? 'ok' : 'warn') : (status.activation_ready ? 'ready' : 'wait'));
    setStageState('vpn-stage-route', status.route_badge_ok ? 'ok' : (((status.route_count || 0) > 0 || (status.map_ip && status.map_ip !== '-')) ? 'warn' : 'wait'));

    setText('vpn-stat-tun-ip', status.tun_ip || '-');
    setHtml('vpn-stat-remote', renderRemoteValue(status.remote || '-'));
    setText('vpn-stat-remote-meta', '协议: ' + (status.proto || '-') + ' · 当前写入的 remote');
    setText('vpn-stat-remote-note', status.connected ? '实际链路解析结果请以下方关键日志为准。' : '当前展示的是配置文件中的 remote 入口。');
    setText('vpn-stat-auth-mode', status.auth_mode || '未知');
    setText('vpn-stat-auth-meta', 'TLS: ' + (status.tls_label || '-') + ' · Cipher: ' + (status.cipher || '-'));
    setText('vpn-stat-health-ratio', status.online_device_ratio || status.remote_online_ratio || '-');
    setText('vpn-stat-health-meta', status.online_breakdown || '远端目标在线比例');

    var authReady = !!status.activation_ready;
    var runtimeCardState = shellState;
    var authCardState = authReady ? 'is-ok' : (status.profile_ready ? 'is-profile-ready' : 'is-empty');
    var routeCardState = status.route_badge_ok ? 'is-ok' : (((status.route_count || 0) > 0 || (status.map_ip && status.map_ip !== '-')) ? 'is-warn' : 'is-empty');
    setCardState('vpn-runtime-card', runtimeCardState);
    setCardState('vpn-auth-card', authCardState);
    setCardState('vpn-route-card', routeCardState);
    setClass('vpn-panel-live-badge', 'vpn-panel-live-badge ' + runtimeCardState);
    setText('vpn-panel-live-badge', status.connected ? (status.health_class === 'ok' ? '在线诊断' : '异常待处理') : (authReady ? '可直接启动' : (status.profile_ready ? '待补认证' : '待写配置')));

    setClass('vpn-runtime-badge', 'vpn-card-badge ' + (status.connected ? 'vpn-badge-ok' : 'vpn-badge-bad'));
    setText('vpn-runtime-badge', status.connected ? '在线' : '离线');
    setText('vpn-runtime-service', status.service_label || status.service_status || 'stopped');
    setText('vpn-runtime-managed', status.managed_label || (status.uci_managed ? (status.uci_enabled ? '已接管' : '已接管未启用') : (status.profile_ready ? '可接管' : '未配置')));
    setText('vpn-runtime-action', status.action_label || '-');
    setText('vpn-runtime-mode', status.mode_label || status.mode || '-');
    setClass('vpn-runtime-log-state', 'vpn-inline-badge ' + (status.log_state_ok ? 'vpn-badge-ok' : 'vpn-badge-bad'));
    setText('vpn-runtime-log-state', status.log_state || '未确认');
    setText('vpn-runtime-process', status.process_summary || status.process_line || '-');

    setClass('vpn-auth-badge', 'vpn-card-badge ' + (authReady ? 'vpn-badge-ok' : 'vpn-badge-bad'));
    setText('vpn-auth-badge', status.auth_badge_label || (authReady ? '可启动' : '待补齐'));
    setText('vpn-auth-userpass', status.auth_ready || '-');
    setText('vpn-auth-requirement', status.auth_requirement_label || '-');
    setText('vpn-auth-cert-material', status.cert_material_label || '-');
    setText('vpn-auth-ready', status.startup_label || (status.activation_ready ? '可启动' : (status.profile_ready ? '待认证文件' : '待配置')));
    setText('vpn-auth-tls', status.tls_label || '-');

    setClass('vpn-route-badge', 'vpn-card-badge ' + (status.route_badge_ok ? 'vpn-badge-ok' : 'vpn-badge-bad'));
    setText('vpn-route-badge', status.route_badge_label || (status.route_badge_ok ? '完整' : '待检查'));
    setText('vpn-route-count', (status.route_count || 0) + ' 条');
    setText('vpn-route-ratio', status.route_rule_ratio || '-');
    setText('vpn-peer-count', status.remote_online_ratio || '-');
    setClass('vpn-dnat-status', 'vpn-inline-badge ' + (status.dnat_ok ? 'vpn-badge-ok' : 'vpn-badge-bad'));
    setText('vpn-dnat-status', status.dnat_status || '未启用');
    setText('vpn-map-ip', status.map_ip || '-');
    setText('vpn-route-note', '下方“实时校验”展示每个目标的详细结果。');

    setText('vpn-action-hint', status.action_hint || '当前页会按配置状态自动切换主操作。');
    setText('vpn-runtime-note', status.runtime_note || '断开后如条件满足，可直接从当前页启动或接管启动。');
    setText('vpn-auth-note', status.auth_note || '配置文件和认证材料齐全后，当前页才能直接启动。');
    setText('vpn-mini-action', status.action_label || '-');
    setText('vpn-mini-action-note', status.connected ? (status.health_class === 'ok' ? '当前连接稳定，主按钮已转为状态提示。' : '当前连接有异常，主按钮保持可重连。') : (status.activation_ready ? '配置已齐，可直接从首屏启动。' : '首屏会提示还缺哪一类材料。'));
    setText('vpn-mini-managed', status.managed_label || (status.uci_managed ? (status.uci_enabled ? '已接管' : '已接管未启用') : (status.profile_ready ? '可接管' : '未配置')));
    setText('vpn-mini-managed-note', (status.service_label || status.service_status || 'stopped') + ' · ' + (status.mode_label || status.mode || '-'));
    setText('vpn-mini-auth', status.auth_badge_label || (authReady ? '可启动' : '待补齐'));
    setText('vpn-mini-auth-note', (status.auth_requirement_label || '-') + ' · ' + (status.cert_material_label || '-'));
    setText('vpn-mini-route', status.route_badge_label || (status.route_badge_ok ? '完整' : '待检查'));
    setText('vpn-mini-route-note', (status.route_rule_ratio || '-') + ' · ' + (status.online_breakdown || '远端目标在线比例'));

    var copyButton = document.getElementById('vpn-copy-button');
    if (copyButton) {
      if (status.copy_ready) {
        copyButton.className = 'cbi-button vpn-button-muted';
        copyButton.setAttribute('aria-disabled', 'false');
        copyButton.title = '复制当前 client.ovpn';
      } else {
        copyButton.className = 'cbi-button vpn-button-muted is-disabled';
        copyButton.setAttribute('aria-disabled', 'true');
        copyButton.title = '当前没有可复制的 client.ovpn';
      }
    }

    renderRouteChecks(status);
    renderNatChecks(status);

    setText('vpn-focus-meta', '优先展示连接、认证、路由相关行。' + (status.ts ? (' · ' + status.ts) : ''));
    setText('vpn-focus-ts', status.ts ? ('最近刷新: ' + status.ts) : '等待刷新');
    setText('vpn-route-strip-count', '目标数: ' + ((status.route_count || 0) + ' 条'));
    setText('vpn-route-strip-health', '规则健康: ' + (status.route_rule_ratio || '-'));
    setText('vpn-route-strip-dnat', 'DNAT: ' + (status.dnat_status || '未启用'));
    setHtml('vpn-focus-log', esc(status.log_focus || 'no focus log')
      .replace(/(Initialization Sequence Completed)/g, '<span class="vpn-log-good">$1</span>')
      .replace(/(TLS Error)/g, '<span class="vpn-log-bad">$1</span>')
      .replace(/(AUTH_FAILED)/g, '<span class="vpn-log-bad">$1</span>')
      .replace(/(error)/gi, '<span class="vpn-log-bad">$1</span>')
      .replace(/(fail)/gi, '<span class="vpn-log-bad">$1</span>')
      .replace(/(warn)/gi, '<span class="vpn-log-warn">$1</span>')
      .replace(/(tun0)/g, '<span class="vpn-log-info">$1</span>')
      .replace(/(route)/gi, '<span class="vpn-log-info">$1</span>'));
    setText('vpn-route-meta', '基于当前内核状态与目标探测的实时结果。优先看离线和缺规则项。');
    setText('vpn-runtime-meta', '完整日志更适合排查重连、认证和 TLS 问题。' + (status.ts ? (' · ' + status.ts) : ''));
    setText('vpn-runtime-log', status.log || 'no log');
    setText('vpn-tun-meta', '展示 tun0 与 br-lan 的当前地址信息。' + (status.ts ? (' · ' + status.ts) : ''));
    setText('vpn-tun-pre', status.tun || 'tun0-down');
    setText('vpn-lan-pre', status.lan_addr_dump || 'no br-lan data');
  }

  function applyStatusError(message) {
    setShellState('is-warn');
    setClass('vpn-health-chip', 'vpn-health-chip warn');
    setText('vpn-health-chip', '状态未返回');
    setText('vpn-live-ts', lastGoodStatus && lastGoodStatus.ts ? ('保留上次 ' + lastGoodStatus.ts) : '等待重新读取');
    setClass('vpn-orb-ring', 'vpn-orb-ring warn');
    setText('vpn-orb-status', '待查');
    setText('vpn-orb-subtitle', '状态接口未返回');
    setText('vpn-orb-meta', message || '请刷新页面，或从应用商店重新打开 OpenVPN。');
    setStageState('vpn-stage-config', 'wait');
    setStageState('vpn-stage-auth', 'wait');
    setStageState('vpn-stage-tunnel', 'warn');
    setStageState('vpn-stage-route', 'wait');
    setText('vpn-action-hint', message || '状态读取失败，当前不改动 OpenVPN 运行状态。');
    setText('vpn-mini-action', '等待状态接口');
    setText('vpn-mini-action-note', '页面没有执行启动、停止或重连，只是状态读取未完成。');
    setText('vpn-mini-managed', '未确认');
    setText('vpn-mini-managed-note', '保留当前系统运行状态。');
    setText('vpn-mini-auth', '未确认');
    setText('vpn-mini-auth-note', '认证状态需要接口返回后确认。');
    setText('vpn-mini-route', '未确认');
    setText('vpn-mini-route-note', '路由状态需要接口返回后确认。');
  }

  function refreshStatus() {
    if (statusBusy) {
      pendingManualRefresh = true;
      return;
    }

    statusBusy = true;
    pendingManualRefresh = false;
    setText('vpn-live-ts', lastGoodStatus && lastGoodStatus.ts ? ('刷新中 · 上次 ' + lastGoodStatus.ts) : '刷新中');
    var xhr = new XMLHttpRequest();
    xhr.open('GET', statusUrl, true);
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== 4) {
        return;
      }

      statusBusy = false;

      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          var payload = JSON.parse(xhr.responseText);
          if (payload && payload.ok === false) {
            applyStatusError(payload.error || '状态接口返回异常。');
            return;
          }
          lastGoodStatus = payload;
          applyStatus(payload);
        } catch (e) {
          applyStatusError('状态响应无法解析，保留页面不执行操作。');
        }
      } else {
        applyStatusError('状态请求失败：HTTP ' + xhr.status);
      }

      if (pendingManualRefresh) {
        window.setTimeout(refreshStatus, 80);
      }
    };
    xhr.send(null);
  }

  window.vpnManualRefresh = function() {
    refreshStatus();
    return false;
  };

  refreshStatus();
  window.setInterval(refreshStatus, 8000);
})();
</script>

<%+footer%>
EOF_OPENVPN_FULL_VIEW

    cat > /usr/lib/lua/luci/view/openvpn/ovpn_css.htm <<'EOF_OPENVPN_OVPN_CSS'
<style type="text/css">
    .vpn-shell {
        max-width: 1180px;
        margin: 0 auto;
        padding: 0 6px 18px;
    }
    .vpn-shell-refined {
        color: #0f172a;
        --vpn-accent: #0ea5e9;
        --vpn-accent-strong: #2563eb;
        --vpn-border: #dfe8f2;
        --vpn-surface: #ffffff;
        --vpn-surface-soft: #f8fbff;
        --vpn-shadow: 0 18px 40px rgba(15, 23, 42, 0.07);
        --vpn-state-rgb: 14, 165, 233;
        --vpn-state-ink: #0369a1;
        --vpn-state-border: rgba(14, 165, 233, 0.22);
        --vpn-state-soft: rgba(14, 165, 233, 0.08);
        padding: 10px 10px 14px;
        border-radius: 28px;
        background: linear-gradient(180deg, #f7fbff 0%, #fbfdff 100%);
    }
    .vpn-shell-refined.is-ok {
        --vpn-state-rgb: 22, 163, 74;
        --vpn-state-ink: #166534;
        --vpn-state-border: rgba(34, 197, 94, 0.24);
        --vpn-state-soft: rgba(34, 197, 94, 0.08);
    }
    .vpn-shell-refined.is-warn {
        --vpn-state-rgb: 234, 88, 12;
        --vpn-state-ink: #9a3412;
        --vpn-state-border: rgba(249, 115, 22, 0.24);
        --vpn-state-soft: rgba(249, 115, 22, 0.08);
    }
    .vpn-shell-refined.is-bad,
    .vpn-shell-refined.is-empty {
        --vpn-state-rgb: 220, 38, 38;
        --vpn-state-ink: #991b1b;
        --vpn-state-border: rgba(239, 68, 68, 0.24);
        --vpn-state-soft: rgba(239, 68, 68, 0.08);
    }
    .vpn-shell-refined.is-ready {
        --vpn-state-rgb: 37, 99, 235;
        --vpn-state-ink: #1d4ed8;
        --vpn-state-border: rgba(37, 99, 235, 0.24);
        --vpn-state-soft: rgba(37, 99, 235, 0.08);
    }
    .vpn-shell-refined.is-profile-ready {
        --vpn-state-rgb: 217, 119, 6;
        --vpn-state-ink: #b45309;
        --vpn-state-border: rgba(245, 158, 11, 0.24);
        --vpn-state-soft: rgba(245, 158, 11, 0.08);
    }
    .vpn-hero {
        position: relative;
        overflow: hidden;
        margin: 12px 0 16px;
        padding: 24px 24px 22px;
        border: 1px solid var(--vpn-border);
        border-radius: 24px;
        background:
            radial-gradient(circle at top right, rgba(var(--vpn-state-rgb), 0.16), transparent 32%),
            radial-gradient(circle at bottom left, rgba(var(--vpn-state-rgb), 0.09), transparent 28%),
            linear-gradient(160deg, #f8fbff 0%, #ffffff 54%, #f9fbfe 100%);
        box-shadow: var(--vpn-shadow);
        animation: vpnHeroIntro .36s ease-out;
    }
    .vpn-hero::after {
        content: "";
        position: absolute;
        inset: 0;
        border-radius: inherit;
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.75);
        pointer-events: none;
    }
    .vpn-hero-top {
        display: grid;
        grid-template-columns: minmax(0, 1fr) auto;
        align-items: start;
        gap: 22px;
        position: relative;
        z-index: 1;
    }
    .vpn-brand-block {
        max-width: 720px;
        display: grid;
        gap: 10px;
    }
    .vpn-toolbar {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        align-items: center;
        margin-bottom: 0;
    }
    .vpn-pill,
    .vpn-health-chip,
    .vpn-status-chip,
    .vpn-card-badge {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        min-height: 30px;
        padding: 4px 13px;
        border-radius: 999px;
        font-size: 12px;
        font-weight: 700;
        letter-spacing: 0.02em;
        box-sizing: border-box;
    }
    .vpn-pill {
        background: #eff6ff;
        color: #1d4ed8;
    }
    .vpn-inline-note {
        display: inline-flex;
        align-items: center;
        min-height: 30px;
        padding: 4px 13px;
        border-radius: 999px;
        background: #f1f5f9;
        color: #526072;
        font-size: 12px;
        font-weight: 700;
        letter-spacing: 0.02em;
    }
    .vpn-health-chip.ok,
    .vpn-status-chip {
        background: #dcfce7;
        color: #166534;
    }
    .vpn-health-chip.warn {
        background: #fff7ed;
        color: #c2410c;
    }
    .vpn-health-chip.bad,
    .vpn-status-chip.off {
        background: #fee2e2;
        color: #991b1b;
    }
    .vpn-card-badge {
        background: #eef2ff;
        color: #3730a3;
    }
    .vpn-badge-ok {
        background: #dcfce7;
        color: #166534;
    }
    .vpn-badge-bad {
        background: #fee2e2;
        color: #991b1b;
    }
    .vpn-badge-neutral {
        background: #eef2f7;
        color: #475569;
    }
    .vpn-hero h2 {
        margin: 0;
        font-size: 32px;
        line-height: 1.08;
        letter-spacing: -0.03em;
        color: #0f172a;
    }
    .vpn-sub {
        margin: 0;
        max-width: 64ch;
        color: #5f6b7a;
        font-size: 13px;
        line-height: 1.75;
    }
    .vpn-mini-grid {
        display: grid;
        grid-template-columns: 1.2fr 1.2fr 1fr 1fr 1fr;
        gap: 12px;
        margin: 16px 0 20px;
    }
    .vpn-mini-card {
        padding: 14px 15px;
        border-radius: 16px;
        border: 1px solid #e6edf5;
        background: rgba(255, 255, 255, 0.94);
        box-shadow: inset 0 1px 0 rgba(255,255,255,.7);
    }
    .vpn-mini-card-accent {
        border-color: var(--vpn-state-border);
        background: linear-gradient(180deg, rgba(var(--vpn-state-rgb), 0.10) 0%, rgba(255, 255, 255, 0.96) 100%);
        box-shadow: 0 10px 22px rgba(var(--vpn-state-rgb), 0.10), inset 0 1px 0 rgba(255,255,255,.76);
    }
    .vpn-mini-card-wide {
        grid-column: span 2;
        padding: 16px 17px;
    }
    .vpn-mini-label {
        display: block;
        color: #64748b;
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.04em;
        text-transform: uppercase;
    }
    .vpn-mini-card strong {
        display: block;
        margin-top: 7px;
        color: #0f172a;
        font-size: 15px;
        line-height: 1.5;
        word-break: break-word;
    }
    .vpn-mini-card-wide strong {
        font-size: 17px;
        line-height: 1.4;
    }
    .vpn-shell-refined .vpn-mini-card-accent strong {
        color: var(--vpn-state-ink);
    }
    .vpn-mini-note {
        display: block;
        margin-top: 6px;
        color: #64748b;
        font-size: 12px;
        line-height: 1.6;
    }
    .vpn-hero-actions {
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        align-items: flex-start;
        justify-content: flex-end;
        min-width: 280px;
    }
    .vpn-hero-actions form {
        margin: 0;
    }
    .vpn-copy-feedback {
        display: inline-flex;
        align-items: center;
        justify-content: flex-end;
        min-height: 20px;
        width: 100%;
        color: #64748b;
        font-size: 12px;
        line-height: 1.5;
        opacity: 0;
        transform: translateY(-2px);
        transition: opacity .16s ease, transform .16s ease, color .16s ease;
        pointer-events: none;
    }
    .vpn-copy-feedback.is-visible {
        opacity: 1;
        transform: translateY(0);
    }
    .vpn-copy-feedback.ok {
        color: #166534;
    }
    .vpn-copy-feedback.warn {
        color: #b45309;
    }
    .vpn-hero-actions .cbi-button,
    .vpn-hero-actions a.cbi-button {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-width: 148px;
        min-height: 46px;
        padding: 10px 18px;
        border-radius: 14px;
        text-align: center;
        text-decoration: none;
        white-space: nowrap;
        line-height: 1.2;
        transition: transform .16s ease, box-shadow .16s ease, border-color .16s ease, background-color .16s ease;
    }
    .vpn-hero-actions .cbi-button:not(.cbi-button-apply) {
        background: #fff;
        border: 1px solid #d7e0ea;
        color: #2563eb;
        box-shadow: none;
    }
    .vpn-hero-note {
        margin-top: 16px;
        padding: 12px 14px;
        max-width: 72ch;
        border: 1px solid var(--vpn-state-border);
        border-radius: 14px;
        background: linear-gradient(180deg, var(--vpn-state-soft) 0%, rgba(255, 255, 255, 0.92) 100%);
        color: #64748b;
        font-size: 12px;
        line-height: 1.7;
    }
    .vpn-button-muted {
        background: #fff;
        border: 1px solid #d7e0ea;
        color: #2563eb;
        box-shadow: none;
    }
    .vpn-button-passive {
        background: linear-gradient(180deg, #f0fdf4 0%, #ffffff 100%);
        border: 1px solid #bbf7d0;
        color: #166534;
        box-shadow: inset 0 1px 0 rgba(255,255,255,.8);
    }
    .vpn-button-muted.is-disabled,
    .vpn-button-muted[aria-disabled="true"] {
        opacity: .55;
        cursor: not-allowed;
        pointer-events: none;
    }
    .vpn-button-passive[disabled] {
        opacity: 1;
        cursor: default;
    }
    .vpn-button-muted[disabled] {
        opacity: .55;
        cursor: not-allowed;
    }
    .vpn-stat-grid {
        display: grid;
        grid-template-columns: 1.02fr 1.12fr 1fr 0.88fr;
        gap: 12px;
        margin-top: 16px;
        position: relative;
        z-index: 1;
    }
    .vpn-stat-card {
        display: flex;
        flex-direction: column;
        min-height: 130px;
        padding: 16px 17px 15px;
        border-radius: 20px;
        border: 1px solid #e5edf6;
        background: linear-gradient(180deg, rgba(255, 255, 255, 0.98) 0%, rgba(248, 251, 255, 0.92) 100%);
        box-shadow: 0 10px 22px rgba(15, 23, 42, 0.03), inset 0 1px 0 rgba(255,255,255,.68);
        transition: transform .18s ease, box-shadow .18s ease, border-color .18s ease;
    }
    .vpn-stat-card-remote {
        background: linear-gradient(180deg, rgba(255,255,255,0.98) 0%, rgba(243,248,255,0.95) 100%);
    }
    .vpn-stat-card-emphasis {
        border-color: var(--vpn-state-border);
        background: linear-gradient(180deg, rgba(var(--vpn-state-rgb), 0.09) 0%, rgba(255,255,255,0.98) 100%);
        box-shadow: 0 14px 26px rgba(var(--vpn-state-rgb), 0.10), inset 0 1px 0 rgba(255,255,255,.72);
    }
    .vpn-shell-refined .vpn-stat-card-emphasis .vpn-stat-value {
        color: var(--vpn-state-ink);
    }
    .vpn-stat-label {
        display: block;
        color: #64748b;
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.06em;
        text-transform: uppercase;
    }
    .vpn-stat-value {
        display: block;
        margin-top: 10px;
        color: #0f172a;
        font-size: 19px;
        line-height: 1.32;
        letter-spacing: -0.02em;
        word-break: break-word;
    }
    .vpn-stat-card-remote .vpn-stat-value {
        font-size: 17px;
        line-height: 1.4;
    }
    .vpn-remote-host,
    .vpn-remote-port {
        display: block;
    }
    .vpn-remote-port {
        margin-top: 4px;
        color: #334155;
        font-size: 16px;
    }
    .vpn-stat-meta {
        display: block;
        margin-top: auto;
        padding-top: 10px;
        color: #64748b;
        font-size: 12px;
        line-height: 1.55;
    }
    .vpn-stat-note {
        display: block;
        margin-top: 8px;
        color: #64748b;
        font-size: 11px;
        line-height: 1.6;
    }
    .vpn-overview-grid {
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 0;
        margin-bottom: 10px;
        border: 1px solid rgba(15, 23, 42, 0.07);
        border-radius: 22px;
        background: linear-gradient(180deg, rgba(255, 255, 255, 0.98) 0%, #fbfdff 100%);
        box-shadow: none;
        overflow: hidden;
        animation: vpnSurfaceIntro .42s ease-out .06s both;
    }
    .vpn-card {
        position: relative;
        padding: 18px 18px 16px;
        min-width: 0;
        background: transparent;
        transition: background-color .18s ease;
    }
    .vpn-card::before {
        content: "";
        position: absolute;
        left: 18px;
        right: 18px;
        top: 0;
        height: 3px;
        border-radius: 0 0 999px 999px;
        opacity: 0;
        transition: opacity .18s ease, background-color .18s ease;
    }
    .vpn-card + .vpn-card {
        border-left: 1px solid #edf2f7;
    }
    .vpn-card.is-ok {
        background: linear-gradient(180deg, rgba(34, 197, 94, 0.045) 0%, transparent 36%);
    }
    .vpn-card.is-ok::before {
        opacity: 1;
        background: #22c55e;
    }
    .vpn-card.is-warn,
    .vpn-card.is-profile-ready {
        background: linear-gradient(180deg, rgba(249, 115, 22, 0.05) 0%, transparent 36%);
    }
    .vpn-card.is-warn::before,
    .vpn-card.is-profile-ready::before {
        opacity: 1;
        background: #f97316;
    }
    .vpn-card.is-bad,
    .vpn-card.is-empty {
        background: linear-gradient(180deg, rgba(239, 68, 68, 0.05) 0%, transparent 36%);
    }
    .vpn-card.is-bad::before,
    .vpn-card.is-empty::before {
        opacity: 1;
        background: #ef4444;
    }
    .vpn-card.is-ready {
        background: linear-gradient(180deg, rgba(37, 99, 235, 0.05) 0%, transparent 36%);
    }
    .vpn-card.is-ready::before {
        opacity: 1;
        background: #2563eb;
    }
    .vpn-card-head {
        display: flex;
        justify-content: space-between;
        gap: 12px;
        align-items: center;
        margin-bottom: 14px;
    }
    .vpn-card-title {
        font-size: 16px;
        font-weight: 700;
        letter-spacing: -0.01em;
        color: #0f172a;
    }
    .vpn-kv {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        gap: 14px;
        padding: 10px 0;
        border-bottom: 1px solid #eff3f6;
    }
    .vpn-kv:last-child {
        border-bottom: 0;
        padding-bottom: 0;
    }
    .vpn-kv span:first-child {
        color: #64748b;
    }
    .vpn-kv strong {
        color: #0f172a;
        word-break: break-all;
        text-align: right;
        max-width: 62%;
    }
    .vpn-card-note {
        margin-top: 14px;
        padding-top: 12px;
        border-top: 1px dashed #edf2f7;
        color: #64748b;
        font-size: 12px;
        line-height: 1.6;
    }
    .vpn-inline-badge {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-height: 24px;
        padding: 4px 10px;
        border-radius: 999px;
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.02em;
        line-height: 1.4;
    }
    .vpn-route-strip {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        margin-top: 14px;
    }
    .vpn-route-pill,
    .vpn-empty-pill {
        display: inline-flex;
        align-items: center;
        min-height: 30px;
        padding: 6px 10px;
        border-radius: 999px;
        font-size: 12px;
        line-height: 1.4;
        background: #f8fafc;
        border: 1px solid #e2e8f0;
        color: #334155;
        word-break: break-all;
    }
    .vpn-empty-pill {
        background: #fff7ed;
        border-color: #fed7aa;
        color: #9a3412;
    }
    .vpn-action-list {
        display: grid;
        gap: 12px;
    }
    .vpn-action-list-compact {
        grid-template-columns: repeat(3, minmax(0, 1fr));
    }
    .vpn-quick-rail {
        position: relative;
        margin-bottom: 10px;
        padding: 16px 18px 18px;
        border: 1px solid var(--vpn-state-border);
        border-radius: 20px;
        background-color: #fbfdff;
        background: linear-gradient(180deg, var(--vpn-state-soft) 0%, #ffffff 32%, #fbfdff 100%);
        box-shadow: none;
        animation: vpnSurfaceIntro .42s ease-out .12s both;
        overflow: hidden;
    }
    .vpn-quick-rail::before {
        content: "";
        position: absolute;
        left: 0;
        right: 0;
        top: 0;
        height: 1px;
        background: rgba(255,255,255,0.68);
        pointer-events: none;
    }
    .vpn-quick-rail-head {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        gap: 12px;
        margin-bottom: 14px;
    }
    .vpn-quick-rail-title {
        color: #0f172a;
        font-size: 16px;
        font-weight: 700;
        letter-spacing: -0.01em;
    }
    .vpn-quick-rail-sub {
        margin: 5px 0 0;
        color: #64748b;
        font-size: 12px;
        line-height: 1.7;
        max-width: 60ch;
    }
    .vpn-action-tile {
        position: relative;
        display: block;
        padding: 15px 44px 15px 16px;
        border-radius: 16px;
        border: 1px solid #e6edf5;
        background: linear-gradient(180deg, rgba(255,255,255,0.96) 0%, rgba(248,250,252,0.92) 100%);
        color: #334155;
        text-decoration: none;
        transition: transform .15s ease, box-shadow .15s ease, border-color .15s ease;
    }
    .vpn-action-tile::after {
        content: "→";
        position: absolute;
        top: 50%;
        right: 16px;
        color: var(--vpn-state-ink);
        font-size: 16px;
        font-weight: 700;
        opacity: 0.42;
        transform: translateY(-50%);
        transition: transform .15s ease, opacity .15s ease;
    }
    .vpn-action-tile:hover {
        transform: translateY(-1px);
        border-color: #cbd5e1;
        box-shadow: 0 10px 20px rgba(15, 23, 42, 0.06);
    }
    .vpn-action-tile:hover::after {
        opacity: 0.9;
        transform: translate(3px, -50%);
    }
    .vpn-action-tile strong {
        display: block;
        margin-bottom: 4px;
        color: #0f172a;
    }
    .vpn-action-tile span {
        display: block;
        color: #64748b;
        line-height: 1.6;
        font-size: 12px;
    }
    .vpn-action-tile[href*="admin/services/openvpn"] {
        border-style: dashed;
        background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%);
    }
    .vpn-entry-grid {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 14px;
        margin-bottom: 16px;
    }
    .vpn-entry-card {
        padding: 18px;
        border-radius: 18px;
        border: 1px solid #e6edf5;
        background: linear-gradient(180deg, #ffffff 0%, #f8fafc 100%);
        box-shadow: 0 10px 24px rgba(15, 23, 42, 0.04);
    }
    .vpn-entry-head {
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 12px;
        margin-bottom: 10px;
    }
    .vpn-entry-head h4 {
        margin: 0;
        color: #0f172a;
        font-size: 17px;
    }
    .vpn-entry-badge {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-height: 26px;
        padding: 4px 10px;
        border-radius: 999px;
        background: #dcfce7;
        color: #166534;
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.02em;
    }
    .vpn-entry-lead {
        margin: 0 0 14px;
        color: #64748b;
        font-size: 13px;
        line-height: 1.7;
    }
    .vpn-field-label {
        display: block;
        margin: 10px 0 6px;
        color: #334155;
        font-size: 12px;
        font-weight: 700;
    }
    .vpn-field-help {
        margin-top: 6px;
        color: #64748b;
        font-size: 12px;
        line-height: 1.6;
    }
    .vpn-entry-card input[type="text"],
    .vpn-entry-card input[type="file"],
    .vpn-entry-card select {
        width: 100%;
        min-height: 42px;
        box-sizing: border-box;
    }
    .vpn-entry-card code {
        color: #0f172a;
        background: #f1f5f9;
        padding: 1px 5px;
        border-radius: 6px;
    }
    .vpn-entry-actions {
        margin-top: 14px;
        display: flex;
        justify-content: flex-start;
    }
    .vpn-entry-actions .cbi-button {
        min-width: 132px;
    }
    .vpn-output {
        margin-top: 10px;
        color: #64748b;
        font-size: 12px;
        line-height: 1.6;
    }
    .vpn-output em {
        display: inline-flex;
        padding: 8px 12px;
        border-radius: 12px;
        background: #fff7ed;
        color: #9a3412;
        font-style: normal;
    }
    .vpn-panel-shell {
        border: 1px solid var(--vpn-state-border);
        border-radius: 22px;
        background: linear-gradient(180deg, #ffffff 0%, #fcfdff 100%);
        box-shadow: none;
        overflow: hidden;
        animation: vpnSurfaceIntro .42s ease-out .18s both;
    }
    .vpn-panel-shell-head {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        gap: 16px;
        padding: 18px 18px 14px;
        border-bottom: 1px solid rgba(15, 23, 42, 0.06);
        background-color: #fbfdff;
        background: linear-gradient(180deg, var(--vpn-state-soft) 0%, rgba(255, 255, 255, 0.96) 100%);
    }
    .vpn-panel-shell-kicker {
        display: inline-flex;
        margin-bottom: 8px;
        color: var(--vpn-state-ink);
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.12em;
        text-transform: uppercase;
    }
    .vpn-panel-shell-head h3 {
        margin: 0;
        color: #0f172a;
        font-size: 20px;
        line-height: 1.15;
        letter-spacing: -0.02em;
    }
    .vpn-panel-shell-head p {
        margin: 8px 0 0;
        max-width: 64ch;
        color: #64748b;
        font-size: 12px;
        line-height: 1.7;
    }
    .vpn-panel-live-badge {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-height: 34px;
        padding: 6px 12px;
        border-radius: 999px;
        border: 1px solid #d7e0ea;
        background: #fff;
        color: #475569;
        font-size: 12px;
        font-weight: 700;
        white-space: nowrap;
    }
    .vpn-panel-live-badge.is-ok {
        border-color: rgba(34, 197, 94, 0.24);
        background: rgba(34, 197, 94, 0.10);
        color: #166534;
    }
    .vpn-panel-live-badge.is-ready {
        border-color: rgba(37, 99, 235, 0.24);
        background: rgba(37, 99, 235, 0.10);
        color: #1d4ed8;
    }
    .vpn-panel-live-badge.is-warn,
    .vpn-panel-live-badge.is-profile-ready {
        border-color: rgba(249, 115, 22, 0.24);
        background: rgba(249, 115, 22, 0.10);
        color: #9a3412;
    }
    .vpn-panel-live-badge.is-bad,
    .vpn-panel-live-badge.is-empty {
        border-color: rgba(239, 68, 68, 0.24);
        background: rgba(239, 68, 68, 0.10);
        color: #991b1b;
    }
    .vpn-tabbar {
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        padding: 14px 16px;
        border-bottom: 1px solid #eef2f6;
        background: linear-gradient(180deg, #fafcff 0%, #f6faff 100%);
    }
    .vpn-tab-btn {
        padding: 8px 14px;
        border: 1px solid #d7e0ea;
        border-radius: 12px;
        background: #fff;
        color: #475569;
        cursor: pointer;
        font-size: 13px;
        font-weight: 700;
        transition: transform .15s ease, box-shadow .15s ease, border-color .15s ease, color .15s ease;
    }
    .vpn-tab-btn-major {
        background: var(--vpn-state-soft);
        border-color: var(--vpn-state-border);
        color: var(--vpn-state-ink);
    }
    .vpn-tab-btn.is-active {
        background: linear-gradient(135deg, #2563eb 0%, #0ea5e9 100%);
        border-color: transparent;
        color: #fff;
        box-shadow: 0 10px 18px rgba(37, 99, 235, 0.22);
    }
    .vpn-tab-btn:hover {
        border-color: #bfd0e1;
        color: #1d4ed8;
    }
    .vpn-panel {
        display: none;
        padding: 20px 20px 18px;
    }
    .vpn-panel.is-active {
        display: block;
        background: linear-gradient(180deg, var(--vpn-state-soft) 0%, rgba(255, 255, 255, 0.98) 24%);
    }
    .vpn-panel-major.is-active {
        background:
            linear-gradient(180deg, var(--vpn-state-soft) 0%, rgba(255, 255, 255, 0.98) 28%),
            linear-gradient(90deg, rgba(15, 23, 42, 0.015) 0%, transparent 32%);
    }
    .vpn-panel-head {
        display: flex;
        justify-content: space-between;
        gap: 14px;
        align-items: flex-start;
        margin-bottom: 12px;
    }
    .vpn-panel-head h3 {
        margin: 0;
        font-size: 15px;
        color: #0f172a;
    }
    .vpn-panel-head span {
        color: #64748b;
        font-size: 12px;
        line-height: 1.6;
        text-align: right;
    }
    .vpn-focus-strip {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        margin: 0 0 12px;
    }
    .vpn-focus-pill {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-height: 30px;
        padding: 6px 11px;
        border-radius: 999px;
        background: var(--vpn-state-soft);
        border: 1px solid var(--vpn-state-border);
        color: var(--vpn-state-ink);
        font-size: 12px;
        font-weight: 700;
        line-height: 1.4;
    }
    .vpn-focus-pill-muted {
        background: #f8fafc;
        border-color: #e2e8f0;
        color: #475569;
    }
    .vpn-focus-strip-route .vpn-focus-pill {
        min-height: 28px;
    }
    .vpn-panel pre,
    .vpn-subcard pre {
        margin: 0;
        padding: 15px 16px;
        border: 1px solid #eef2f6;
        border-radius: 16px;
        background: #0f172a;
        color: #dbeafe;
        white-space: pre-wrap;
        word-break: break-word;
        line-height: 1.7;
        overflow-x: auto;
    }
    #vpn-focus-log {
        min-height: 280px;
        border-color: rgba(125, 211, 252, 0.16);
        box-shadow: inset 0 1px 0 rgba(255,255,255,0.03);
    }
    #vpn-runtime-log {
        min-height: 220px;
    }
    .vpn-split-grid {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 14px;
    }
    .vpn-subcard {
        display: flex;
        flex-direction: column;
        gap: 10px;
    }
    .vpn-subcard-title {
        font-size: 13px;
        font-weight: 700;
        color: #334155;
    }
    .vpn-check-list {
        display: grid;
        gap: 10px;
    }
    .vpn-check-section {
        display: grid;
        gap: 10px;
    }
    .vpn-check-section + .vpn-check-section {
        margin-top: 8px;
    }
    .vpn-check-section-title {
        color: #334155;
        font-size: 12px;
        font-weight: 700;
        letter-spacing: 0.03em;
        text-transform: uppercase;
    }
    .vpn-check-row {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        gap: 12px;
        padding: 13px 14px;
        border-radius: 16px;
        border: 1px solid #e8eef5;
        background: linear-gradient(180deg, #ffffff 0%, #f8fafc 100%);
    }
    .vpn-check-main strong {
        display: block;
        color: #0f172a;
        margin-bottom: 4px;
    }
    .vpn-check-main span {
        display: block;
        color: #64748b;
        font-size: 12px;
        line-height: 1.6;
        word-break: break-word;
    }
    .vpn-check-badges {
        display: flex;
        flex-wrap: wrap;
        justify-content: flex-end;
        gap: 6px;
        min-width: 132px;
    }
    .vpn-micro-badge {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-height: 24px;
        padding: 4px 10px;
        border-radius: 999px;
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.02em;
        background: #eef2f7;
        color: #475569;
    }
    .vpn-micro-badge.ok {
        background: #dcfce7;
        color: #166534;
    }
    .vpn-micro-badge.bad {
        background: #fee2e2;
        color: #991b1b;
    }
    .vpn-micro-badge.neutral {
        background: #eef2f7;
        color: #475569;
    }
    .vpn-check-empty {
        padding: 14px 15px;
        border-radius: 14px;
        border: 1px dashed #d7dee7;
        color: #64748b;
        background: #fafcff;
    }
    .vpn-copy-source {
        position: absolute;
        left: -9999px;
        top: -9999px;
        width: 1px;
        height: 1px;
        opacity: 0;
        pointer-events: none;
    }
    .vpn-log-good {
        color: #4ade80;
        font-weight: 700;
    }
    .vpn-log-bad {
        color: #fca5a5;
        font-weight: 700;
    }
    .vpn-log-warn {
        color: #fcd34d;
        font-weight: 700;
    }
    .vpn-log-info {
        color: #7dd3fc;
        font-weight: 700;
    }
    .cbi-map .btn.cbi-button,
    .cbi-map .cbi-button,
    .cbi-map .cbi-button-add,
    .cbi-map .cbi-button-apply,
    .cbi-map .cbi-button-reset {
        border-radius: 12px;
        padding: 9px 14px;
    }
    .cbi-map .cbi-button-apply {
        background: linear-gradient(135deg, #2563eb 0%, #0ea5e9 100%);
        border: 0;
        color: #fff;
        box-shadow: 0 10px 20px rgba(37, 99, 235, 0.2);
    }
    .cbi-map .cbi-button-apply:hover {
        filter: brightness(1.03);
    }
    .vpn-hero-actions .cbi-button:hover,
    .vpn-hero-actions a.cbi-button:hover {
        transform: translateY(-1px);
    }
    .vpn-stat-card:hover {
        transform: translateY(-1px);
        border-color: #d7e5f1;
        box-shadow: 0 16px 30px rgba(15, 23, 42, 0.06);
    }
    .vpn-card:hover {
        background: rgba(var(--vpn-state-rgb), 0.03);
    }
    @keyframes vpnHeroIntro {
        from {
            opacity: 0;
            transform: translateY(6px);
        }
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }
    @keyframes vpnSurfaceIntro {
        from {
            opacity: 0;
            transform: translateY(8px);
        }
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }
    .cbi-map .cbi-section,
    .cbi-map .cbi-section-node {
        margin-bottom: 16px;
        padding: 18px;
        border: 1px solid #e7eaee;
        border-radius: 18px;
        background: #fff;
        box-shadow: 0 10px 24px rgba(15, 23, 42, 0.04);
    }
    .cbi-map .cbi-section > h3,
    .cbi-map .cbi-section-node > h3,
    .cbi-map .cbi-section > h4,
    .cbi-map .cbi-section-node > h4 {
        margin: 0 0 12px;
        color: #0f172a;
        font-size: 17px;
        font-weight: 700;
        line-height: 1.35;
        padding-left: 12px;
        border-left: 4px solid #22c7f5;
        white-space: normal;
        display: block;
    }
    .cbi-map .cbi-section legend {
        margin: 0 0 12px;
        color: #0f172a;
        font-size: 17px;
        font-weight: 700;
        line-height: 1.35;
        padding: 0 12px 0 12px;
        border-left: 4px solid #22c7f5;
        white-space: normal;
        display: table;
        max-width: 100%;
        box-sizing: border-box;
        position: static;
        float: none;
        background: #fff;
    }
    .cbi-map .cbi-section-table legend,
    .cbi-map fieldset.cbi-section-table > legend {
        margin: 0 0 12px;
        color: #0f172a;
        font-size: 17px;
        font-weight: 700;
        line-height: 1.35;
        padding: 0 0 0 12px;
        border-left: 4px solid #22c7f5;
        white-space: normal;
        display: table;
        max-width: 100%;
        box-sizing: border-box;
        position: static;
        float: none;
        background: #fff;
    }
    .cbi-map fieldset.cbi-section {
        padding-top: 22px;
    }
    .cbi-map fieldset.cbi-section-table {
        padding-top: 22px;
    }
    .cbi-map fieldset#cbi-openvpn-openvpn {
        position: relative;
        margin-top: 14px;
        padding-top: 56px;
        overflow: hidden;
    }
    .cbi-map fieldset#cbi-openvpn-openvpn > legend {
        display: none;
    }
    .cbi-map fieldset#cbi-openvpn-openvpn::before {
        content: "实例列表";
        position: absolute;
        top: 18px;
        left: 18px;
        color: #0f172a;
        font-size: 17px;
        font-weight: 700;
        line-height: 1.35;
        padding: 0 12px;
        border-left: 4px solid #22c7f5;
        white-space: normal;
        background: #fff;
        z-index: 2;
    }
    .cbi-map fieldset.cbi-section > .cbi-section-node,
    .cbi-map fieldset.cbi-section > .cbi-optionals,
    .cbi-map fieldset.cbi-section > .cbi-section-descr {
        margin-top: 10px;
    }
    .cbi-map fieldset.cbi-section-table > .cbi-section-descr,
    .cbi-map fieldset.cbi-section-table > .cbi-section-create,
    .cbi-map fieldset.cbi-section-table > .table,
    .cbi-map fieldset.cbi-section-table > table {
        margin-top: 10px;
    }
    .vpn-cbi-section .vpn-section-title {
        margin: 0 0 12px;
        color: #0f172a;
        font-size: 17px;
        font-weight: 700;
        line-height: 1.35;
        padding-left: 12px;
        border-left: 4px solid #22c7f5;
        white-space: normal;
        display: block;
    }
    .cbi-map .cbi-value {
        padding: 14px 0;
        border-bottom: 1px solid #eef2f6;
    }
    .cbi-map .cbi-value:last-child {
        border-bottom: 0;
        padding-bottom: 0;
    }
    .cbi-map .cbi-value-title {
        color: #334155;
        font-weight: 700;
        margin-bottom: 6px;
    }
    .cbi-map .cbi-value-description {
        color: #64748b;
        font-size: 12px;
        line-height: 1.6;
        margin-top: 6px;
    }
    .cbi-map input[type="text"],
    .cbi-map input[type="password"],
    .cbi-map input[type="file"],
    .cbi-map textarea,
    .cbi-map select {
        width: 100%;
        max-width: 100%;
        min-height: 42px;
        box-sizing: border-box;
        padding: 9px 12px;
        border-radius: 12px;
        border: 1px solid #d7e0ea;
        background: #fff;
        color: #0f172a;
    }
    .cbi-map textarea {
        min-height: 220px;
        line-height: 1.7;
        resize: vertical;
    }
    .cbi-map .cbi-section-table {
        width: 100%;
        border-collapse: separate;
        border-spacing: 0;
    }
    .cbi-map .cbi-section-table-titles,
    .cbi-map .cbi-section-table-descr,
    .cbi-map .cbi-section-table-cell {
        padding: 10px 12px;
        border-bottom: 1px solid #eef2f6;
        vertical-align: top;
    }
    .cbi-map .cbi-section-table-titles {
        color: #64748b;
        font-size: 12px;
        font-weight: 700;
        letter-spacing: 0.03em;
        text-transform: uppercase;
        background: #f8fafc;
    }
    .cbi-map .cbi-section-table-row:last-child .cbi-section-table-cell {
        border-bottom: 0;
    }
    .cbi-map .cbi-section-create {
        margin-top: 14px;
    }
    @media (min-width: 981px) and (max-width: 1180px) {
        .vpn-action-list-compact {
            grid-template-columns: repeat(2, minmax(0, 1fr));
        }
        .vpn-action-list-compact .vpn-action-tile:last-child {
            grid-column: 1 / -1;
        }
        .vpn-mini-grid {
            grid-template-columns: repeat(2, minmax(0, 1fr));
        }
        .vpn-mini-card-wide {
            grid-column: span 2;
        }
        .vpn-overview-grid {
            grid-template-columns: repeat(2, minmax(0, 1fr));
        }
        .vpn-card + .vpn-card {
            border-left: 1px solid #edf2f7;
        }
        .vpn-card:nth-child(2n+1) {
            border-left: 0;
        }
        .vpn-card:nth-child(n+3) {
            border-top: 1px solid #edf2f7;
        }
        .vpn-quick-rail-head {
            flex-direction: column;
        }
    }
    @media (max-width: 980px) {
        .vpn-stat-grid,
        .vpn-overview-grid,
        .vpn-mini-grid,
        .vpn-action-list-compact,
        .vpn-entry-grid,
        .vpn-split-grid {
            grid-template-columns: 1fr;
        }
        .vpn-mini-card-wide {
            grid-column: auto;
        }
        .vpn-action-list-compact .vpn-action-tile:last-child {
            grid-column: auto;
        }
        .vpn-hero {
            padding: 20px 18px 18px;
        }
        .vpn-hero-top {
            grid-template-columns: 1fr;
            gap: 16px;
        }
        .vpn-hero h2 {
            font-size: 28px;
        }
        .cbi-map .cbi-section-table,
        .cbi-map .cbi-section-table-row,
        .cbi-map .cbi-section-table-cell,
        .cbi-map .cbi-section-table-titles {
            display: block;
            width: 100%;
            box-sizing: border-box;
        }
        .vpn-hero-actions {
            justify-content: flex-start;
            min-width: 0;
        }
        .vpn-copy-feedback {
            justify-content: flex-start;
        }
        .vpn-hero-actions .cbi-button,
        .vpn-hero-actions a.cbi-button,
        .vpn-hero-actions form {
            width: 100%;
        }
        .vpn-stat-card {
            min-height: 0;
        }
        .vpn-card + .vpn-card {
            border-left: 0;
            border-top: 1px solid #edf2f7;
        }
        .vpn-panel-head {
            flex-direction: column;
        }
        .vpn-panel-head span {
            text-align: left;
        }
        .vpn-panel-shell-head {
            flex-direction: column;
        }
        .vpn-check-row {
            flex-direction: column;
        }
        .vpn-check-badges {
            justify-content: flex-start;
            min-width: 0;
        }
    }
    @media (prefers-reduced-motion: reduce) {
        .vpn-hero,
        .vpn-overview-grid,
        .vpn-quick-rail,
        .vpn-panel-shell {
            animation: none;
        }
        .vpn-hero-actions .cbi-button,
        .vpn-hero-actions a.cbi-button,
        .vpn-stat-card,
        .vpn-card,
        .vpn-action-tile,
        .vpn-tab-btn,
        .vpn-copy-feedback {
            transition: none;
        }
        .vpn-action-tile::after {
            transition: none;
        }
    }
    /* NRadio OpenVPN Mk2: dark command-center layer */
    .vpn-shell-mk2 {
        max-width: 1220px;
        padding: 8px 8px 22px;
        color: #f8fbff;
        background:
            radial-gradient(circle at 14% 8%, rgba(34, 211, 238, 0.13), transparent 30%),
            radial-gradient(circle at 86% 16%, rgba(59, 130, 246, 0.16), transparent 32%),
            linear-gradient(180deg, rgba(12, 18, 32, 0.98) 0%, rgba(16, 22, 36, 0.94) 100%);
        border: 1px solid rgba(255, 255, 255, 0.08);
        box-shadow: 0 22px 48px rgba(0, 0, 0, 0.26);
        --vpn-accent: #22d3ee;
        --vpn-accent-strong: #38bdf8;
        --vpn-border: rgba(148, 163, 184, 0.22);
        --vpn-surface: rgba(20, 27, 43, 0.82);
        --vpn-surface-soft: rgba(26, 35, 54, 0.72);
        --vpn-shadow: 0 18px 36px rgba(0, 0, 0, 0.22);
        --vpn-state-rgb: 34, 211, 238;
        --vpn-state-ink: #67e8f9;
        --vpn-state-border: rgba(34, 211, 238, 0.28);
        --vpn-state-soft: rgba(34, 211, 238, 0.10);
    }
    .vpn-shell-mk2.is-ok {
        --vpn-state-rgb: 52, 211, 153;
        --vpn-state-ink: #86efac;
        --vpn-state-border: rgba(74, 222, 128, 0.34);
        --vpn-state-soft: rgba(34, 197, 94, 0.12);
    }
    .vpn-shell-mk2.is-warn {
        --vpn-state-rgb: 251, 191, 36;
        --vpn-state-ink: #fde68a;
        --vpn-state-border: rgba(251, 191, 36, 0.34);
        --vpn-state-soft: rgba(251, 191, 36, 0.13);
    }
    .vpn-shell-mk2.is-bad,
    .vpn-shell-mk2.is-empty {
        --vpn-state-rgb: 248, 113, 113;
        --vpn-state-ink: #fecaca;
        --vpn-state-border: rgba(248, 113, 113, 0.34);
        --vpn-state-soft: rgba(248, 113, 113, 0.12);
    }
    .vpn-shell-mk2.is-ready {
        --vpn-state-rgb: 56, 189, 248;
        --vpn-state-ink: #bae6fd;
        --vpn-state-border: rgba(56, 189, 248, 0.34);
        --vpn-state-soft: rgba(56, 189, 248, 0.12);
    }
    .vpn-shell-mk2.is-profile-ready {
        --vpn-state-rgb: 251, 146, 60;
        --vpn-state-ink: #fed7aa;
        --vpn-state-border: rgba(251, 146, 60, 0.34);
        --vpn-state-soft: rgba(251, 146, 60, 0.12);
    }
    .vpn-shell-mk2 .vpn-hero-mk2 {
        margin: 8px 0 14px;
        padding: 22px;
        border-color: rgba(255, 255, 255, 0.10);
        background:
            radial-gradient(circle at 78% 18%, rgba(var(--vpn-state-rgb), 0.22), transparent 34%),
            radial-gradient(circle at 18% 92%, rgba(14, 165, 233, 0.14), transparent 32%),
            linear-gradient(145deg, rgba(24, 33, 52, 0.96) 0%, rgba(12, 18, 31, 0.98) 100%);
        box-shadow: 0 24px 48px rgba(0, 0, 0, 0.26), inset 0 1px 0 rgba(255, 255, 255, 0.08);
    }
    .vpn-shell-mk2 .vpn-hero-mk2::before {
        content: "";
        position: absolute;
        inset: 12px;
        border-radius: 20px;
        border: 1px solid rgba(255, 255, 255, 0.045);
        pointer-events: none;
    }
    .vpn-shell-mk2 .vpn-hero-main {
        position: relative;
        z-index: 1;
        display: grid;
        grid-template-columns: minmax(0, 1fr) 360px;
        gap: 20px;
        align-items: stretch;
    }
    .vpn-shell-mk2 .vpn-brand-block {
        max-width: none;
        padding: 6px 0;
    }
    .vpn-shell-mk2 .vpn-toolbar {
        margin-bottom: 4px;
    }
    .vpn-shell-mk2 .vpn-pill,
    .vpn-shell-mk2 .vpn-health-chip,
    .vpn-shell-mk2 .vpn-inline-note,
    .vpn-shell-mk2 .vpn-card-badge,
    .vpn-shell-mk2 .vpn-panel-live-badge,
    .vpn-shell-mk2 .vpn-inline-badge,
    .vpn-shell-mk2 .vpn-micro-badge,
    .vpn-shell-mk2 .vpn-focus-pill {
        border: 1px solid rgba(255, 255, 255, 0.10);
        background: rgba(255, 255, 255, 0.07);
        color: #dbeafe;
        backdrop-filter: blur(10px);
    }
    .vpn-shell-mk2 .vpn-pill {
        color: #a5f3fc;
        background: rgba(34, 211, 238, 0.12);
        border-color: rgba(34, 211, 238, 0.28);
    }
    .vpn-shell-mk2 .vpn-health-chip.ok,
    .vpn-shell-mk2 .vpn-badge-ok,
    .vpn-shell-mk2 .vpn-micro-badge.ok {
        background: rgba(34, 197, 94, 0.16);
        border-color: rgba(74, 222, 128, 0.30);
        color: #bbf7d0;
    }
    .vpn-shell-mk2 .vpn-health-chip.warn,
    .vpn-shell-mk2 .vpn-micro-badge.warn {
        background: rgba(245, 158, 11, 0.16);
        border-color: rgba(251, 191, 36, 0.30);
        color: #fde68a;
    }
    .vpn-shell-mk2 .vpn-health-chip.bad,
    .vpn-shell-mk2 .vpn-badge-bad,
    .vpn-shell-mk2 .vpn-micro-badge.bad {
        background: rgba(239, 68, 68, 0.16);
        border-color: rgba(248, 113, 113, 0.30);
        color: #fecaca;
    }
    .vpn-shell-mk2 .vpn-badge-neutral,
    .vpn-shell-mk2 .vpn-micro-badge.neutral {
        background: rgba(148, 163, 184, 0.12);
        color: #cbd5e1;
    }
    .vpn-shell-mk2 .vpn-hero h2,
    .vpn-shell-mk2 .vpn-brand-block h2 {
        display: block !important;
        max-width: 760px;
        margin: 0 !important;
        padding: 0 !important;
        border: 0 !important;
        background: none !important;
        font-size: clamp(30px, 3.4vw, 42px);
        line-height: 1.02;
        letter-spacing: -0.045em;
        color: #ffffff !important;
        text-decoration: none !important;
        text-shadow: 0 18px 34px rgba(0, 0, 0, 0.30);
    }
    .vpn-shell-mk2 .vpn-brand-block h2::before,
    .vpn-shell-mk2 .vpn-brand-block h2::after {
        display: none !important;
        content: none !important;
    }
    .vpn-shell-mk2 .vpn-sub {
        max-width: 680px;
        color: #b7c5d8;
        font-size: 13px;
        line-height: 1.65;
        opacity: 0.86;
    }
    .vpn-stage-line {
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        margin-top: 16px;
    }
    .vpn-stage-chip {
        position: relative;
        display: inline-flex;
        align-items: center;
        gap: 8px;
        min-height: 34px;
        padding: 7px 13px;
        border-radius: 999px;
        border: 1px solid rgba(255,255,255,0.10);
        background: rgba(255,255,255,0.06);
        color: #cbd5e1;
        font-size: 12px;
        font-weight: 800;
        letter-spacing: 0.06em;
    }
    .vpn-stage-chip::before {
        content: "";
        width: 7px;
        height: 7px;
        border-radius: 999px;
        background: currentColor;
        box-shadow: 0 0 16px currentColor;
    }
    .vpn-stage-chip.ok {
        color: #86efac;
        border-color: rgba(74, 222, 128, 0.30);
        background: rgba(34, 197, 94, 0.13);
    }
    .vpn-stage-chip.ready {
        color: #7dd3fc;
        border-color: rgba(56, 189, 248, 0.30);
        background: rgba(14, 165, 233, 0.13);
    }
    .vpn-stage-chip.warn {
        color: #fde68a;
        border-color: rgba(251, 191, 36, 0.30);
        background: rgba(245, 158, 11, 0.13);
    }
    .vpn-stage-chip.bad {
        color: #fecaca;
        border-color: rgba(248, 113, 113, 0.30);
        background: rgba(239, 68, 68, 0.13);
    }
    .vpn-command-card {
        display: grid;
        gap: 16px;
        align-content: start;
        padding: 16px;
        border-radius: 22px;
        border: 1px solid rgba(255, 255, 255, 0.11);
        background:
            linear-gradient(180deg, rgba(255, 255, 255, 0.075) 0%, rgba(255, 255, 255, 0.035) 100%);
        box-shadow: inset 0 1px 0 rgba(255,255,255,0.08);
    }
    .vpn-orb-wrap {
        display: grid;
        grid-template-columns: 96px minmax(0, 1fr);
        gap: 13px;
        align-items: center;
    }
    .vpn-orb-ring {
        position: relative;
        display: grid;
        place-items: center;
        width: 96px;
        height: 96px;
        border-radius: 999px;
        background:
            radial-gradient(circle, rgba(15, 23, 42, 0.88) 0 52%, transparent 53%),
            conic-gradient(from 220deg, rgba(var(--vpn-state-rgb), 0.14), rgba(var(--vpn-state-rgb), 0.96), rgba(var(--vpn-state-rgb), 0.14));
        color: var(--vpn-state-ink);
        box-shadow: 0 16px 32px rgba(0,0,0,0.25), 0 0 34px rgba(var(--vpn-state-rgb), 0.18);
        font-weight: 900;
        letter-spacing: -0.03em;
        text-align: center;
    }
    .vpn-orb-ring::after {
        content: "";
        position: absolute;
        inset: 12px;
        border-radius: inherit;
        border: 1px solid rgba(255, 255, 255, 0.08);
        pointer-events: none;
    }
    .vpn-orb-ring span {
        max-width: 62px;
        font-size: 16px;
        line-height: 1.12;
        word-break: break-word;
    }
    .vpn-orb-copy strong {
        display: block;
        color: #f8fafc;
        font-size: 17px;
        line-height: 1.35;
    }
    .vpn-orb-copy span {
        display: block;
        margin-top: 7px;
        color: #aebed2;
        font-size: 12px;
        line-height: 1.65;
    }
    .vpn-shell-mk2 .vpn-hero-actions {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 10px;
        min-width: 0;
        justify-content: stretch;
        align-items: stretch;
    }
    .vpn-shell-mk2 .vpn-hero-actions form {
        width: 100%;
    }
    .vpn-shell-mk2 .vpn-hero-actions .cbi-button,
    .vpn-shell-mk2 .vpn-hero-actions a.cbi-button {
        width: 100%;
        min-width: 0;
        min-height: 44px;
        border-radius: 14px;
        border: 1px solid rgba(255,255,255,0.12);
        color: #e2f5ff;
        background: rgba(255,255,255,0.08);
        box-shadow: inset 0 1px 0 rgba(255,255,255,0.08);
    }
    .vpn-shell-mk2 .vpn-hero-actions .cbi-button-apply {
        color: #06111f;
        background: linear-gradient(135deg, #67e8f9 0%, #38bdf8 52%, #60a5fa 100%);
        border: 0;
        box-shadow: 0 16px 28px rgba(34, 211, 238, 0.20);
        font-weight: 900;
    }
    .vpn-shell-mk2 .vpn-button-passive {
        color: #bbf7d0;
        background: rgba(34,197,94,0.13);
        border-color: rgba(74,222,128,0.30);
        box-shadow: none;
    }
    .vpn-shell-mk2 .vpn-copy-feedback {
        grid-column: 1 / -1;
        justify-content: flex-start;
        color: #aebed2;
    }
    .vpn-shell-mk2 .vpn-hero-note {
        margin: 0;
        max-width: none;
        border-color: rgba(var(--vpn-state-rgb), 0.22);
        background: rgba(var(--vpn-state-rgb), 0.08);
        color: #cbd5e1;
    }
    .vpn-shell-mk2 .vpn-mini-grid-mk2 {
        grid-template-columns: repeat(4, minmax(0, 1fr));
        gap: 10px;
        margin: 16px 0 14px;
    }
    .vpn-shell-mk2 .vpn-mini-card,
    .vpn-shell-mk2 .vpn-stat-card,
    .vpn-shell-mk2 .vpn-overview-grid,
    .vpn-shell-mk2 .vpn-quick-rail,
    .vpn-shell-mk2 .vpn-panel-shell,
    .vpn-shell-mk2 .vpn-entry-card,
    .vpn-shell-mk2 .cbi-map .cbi-section,
    .vpn-shell-mk2 .cbi-map .cbi-section-node {
        border-color: rgba(255, 255, 255, 0.095);
        background:
            linear-gradient(180deg, rgba(255,255,255,0.065) 0%, rgba(255,255,255,0.028) 100%);
        box-shadow: inset 0 1px 0 rgba(255,255,255,0.055);
    }
    .vpn-shell-mk2 .vpn-mini-card-accent,
    .vpn-shell-mk2 .vpn-stat-card-emphasis {
        border-color: rgba(var(--vpn-state-rgb), 0.28);
        background:
            linear-gradient(180deg, rgba(var(--vpn-state-rgb), 0.16) 0%, rgba(255,255,255,0.035) 100%);
        box-shadow: 0 16px 28px rgba(var(--vpn-state-rgb), 0.10), inset 0 1px 0 rgba(255,255,255,0.08);
    }
    .vpn-shell-mk2 .vpn-mini-card-wide {
        grid-column: auto;
    }
    .vpn-shell-mk2 .vpn-mini-label,
    .vpn-shell-mk2 .vpn-stat-label,
    .vpn-shell-mk2 .vpn-kv span:first-child,
    .vpn-shell-mk2 .vpn-card-note,
    .vpn-shell-mk2 .vpn-stat-meta,
    .vpn-shell-mk2 .vpn-stat-note,
    .vpn-shell-mk2 .vpn-mini-note,
    .vpn-shell-mk2 .vpn-quick-rail-sub,
    .vpn-shell-mk2 .vpn-action-tile span,
    .vpn-shell-mk2 .vpn-panel-shell-head p,
    .vpn-shell-mk2 .vpn-panel-head span,
    .vpn-shell-mk2 .vpn-check-main span,
    .vpn-shell-mk2 .cbi-map .cbi-value-description {
        color: #9fb0c5;
    }
    .vpn-shell-mk2 .vpn-mini-card strong,
    .vpn-shell-mk2 .vpn-stat-value,
    .vpn-shell-mk2 .vpn-card-title,
    .vpn-shell-mk2 .vpn-kv strong,
    .vpn-shell-mk2 .vpn-quick-rail-title,
    .vpn-shell-mk2 .vpn-action-tile strong,
    .vpn-shell-mk2 .vpn-panel-shell-head h3,
    .vpn-shell-mk2 .vpn-panel-head h3,
    .vpn-shell-mk2 .vpn-subcard-title,
    .vpn-shell-mk2 .vpn-check-main strong,
    .vpn-shell-mk2 .cbi-map .cbi-section > h3,
    .vpn-shell-mk2 .cbi-map .cbi-section-node > h3,
    .vpn-shell-mk2 .cbi-map .cbi-section > h4,
    .vpn-shell-mk2 .cbi-map .cbi-section-node > h4,
    .vpn-shell-mk2 .cbi-map .cbi-section legend,
    .vpn-shell-mk2 .cbi-map .cbi-value-title {
        color: #f8fafc;
    }
    .vpn-shell-mk2 .vpn-overview-grid {
        gap: 0;
        overflow: hidden;
    }
    .vpn-shell-mk2 .vpn-card {
        background: transparent;
    }
    .vpn-shell-mk2 .vpn-card + .vpn-card {
        border-left-color: rgba(255,255,255,0.08);
    }
    .vpn-shell-mk2 .vpn-card.is-ok {
        background: linear-gradient(180deg, rgba(34, 197, 94, 0.07) 0%, transparent 48%);
    }
    .vpn-shell-mk2 .vpn-card.is-warn,
    .vpn-shell-mk2 .vpn-card.is-profile-ready {
        background: linear-gradient(180deg, rgba(245, 158, 11, 0.07) 0%, transparent 48%);
    }
    .vpn-shell-mk2 .vpn-card.is-bad,
    .vpn-shell-mk2 .vpn-card.is-empty {
        background: linear-gradient(180deg, rgba(239, 68, 68, 0.07) 0%, transparent 48%);
    }
    .vpn-shell-mk2 .vpn-card.is-ready {
        background: linear-gradient(180deg, rgba(14, 165, 233, 0.07) 0%, transparent 48%);
    }
    .vpn-shell-mk2 .vpn-kv {
        border-bottom-color: rgba(255,255,255,0.07);
    }
    .vpn-shell-mk2 .vpn-card-note {
        border-top-color: rgba(255,255,255,0.10);
    }
    .vpn-shell-mk2 .vpn-stat-grid {
        grid-template-columns: 1fr 1.1fr 1fr .9fr;
        gap: 10px;
    }
    .vpn-shell-mk2 .vpn-stat-card {
        min-height: 116px;
    }
    .vpn-shell-mk2 .vpn-stat-card-remote,
    .vpn-shell-mk2 .vpn-action-tile[href*="admin/services/openvpn"],
    .vpn-shell-mk2 .vpn-panel,
    .vpn-shell-mk2 .vpn-panel-major.is-active,
    .vpn-shell-mk2 .vpn-panel.is-active,
    .vpn-shell-mk2 .vpn-tabbar,
    .vpn-shell-mk2 .vpn-panel-shell-head {
        background:
            linear-gradient(180deg, rgba(255,255,255,0.055) 0%, rgba(255,255,255,0.025) 100%);
    }
    .vpn-shell-mk2 .vpn-action-tile {
        border-color: rgba(255,255,255,0.10);
        background: rgba(255,255,255,0.045);
        color: #e2e8f0;
    }
    .vpn-shell-mk2 .vpn-action-tile::after,
    .vpn-shell-mk2 .vpn-panel-shell-kicker,
    .vpn-shell-mk2 .vpn-shell-refined .vpn-stat-card-emphasis .vpn-stat-value {
        color: var(--vpn-state-ink);
    }
    .vpn-shell-mk2 .vpn-tabbar,
    .vpn-shell-mk2 .vpn-panel-shell-head {
        border-bottom-color: rgba(255,255,255,0.08);
    }
    .vpn-shell-mk2 .vpn-tab-btn {
        border-color: rgba(255,255,255,0.10);
        background: rgba(255,255,255,0.06);
        color: #cbd5e1;
    }
    .vpn-shell-mk2 .vpn-tab-btn-major {
        background: rgba(var(--vpn-state-rgb), 0.10);
        border-color: rgba(var(--vpn-state-rgb), 0.24);
        color: var(--vpn-state-ink);
    }
    .vpn-shell-mk2 .vpn-tab-btn.is-active {
        background: linear-gradient(135deg, #67e8f9 0%, #38bdf8 50%, #60a5fa 100%);
        color: #06111f;
        box-shadow: 0 14px 24px rgba(34, 211, 238, 0.18);
    }
    .vpn-shell-mk2 .vpn-check-row,
    .vpn-shell-mk2 .vpn-check-empty {
        border-color: rgba(255,255,255,0.09);
        background: rgba(255,255,255,0.045);
        color: #cbd5e1;
    }
    .vpn-shell-mk2 .vpn-panel pre,
    .vpn-shell-mk2 .vpn-subcard pre {
        border-color: rgba(125, 211, 252, 0.18);
        background:
            radial-gradient(circle at top left, rgba(34, 211, 238, 0.10), transparent 34%),
            linear-gradient(180deg, #07101d 0%, #0b1220 100%);
        color: #dbeafe;
        box-shadow: inset 0 1px 0 rgba(255,255,255,0.035);
    }
    .vpn-shell-mk2 .vpn-quick-rail {
        border-color: rgba(var(--vpn-state-rgb), 0.18);
    }
    .vpn-shell-mk2 .vpn-panel-shell {
        border-color: rgba(var(--vpn-state-rgb), 0.18);
    }
    .vpn-shell-mk2 .cbi-map input[type="text"],
    .vpn-shell-mk2 .cbi-map input[type="password"],
    .vpn-shell-mk2 .cbi-map input[type="file"],
    .vpn-shell-mk2 .cbi-map textarea,
    .vpn-shell-mk2 .cbi-map select,
    .vpn-shell-mk2 .vpn-entry-card input[type="text"],
    .vpn-shell-mk2 .vpn-entry-card input[type="file"],
    .vpn-shell-mk2 .vpn-entry-card select {
        border-color: rgba(255,255,255,0.12);
        background: rgba(8, 13, 24, 0.74);
        color: #f8fafc;
    }
    .vpn-shell-mk2 .cbi-map .cbi-section-table-titles {
        background: rgba(255,255,255,0.05);
        color: #cbd5e1;
    }
    .vpn-shell-mk2 .cbi-map .cbi-section-table-descr,
    .vpn-shell-mk2 .cbi-map .cbi-section-table-cell {
        border-bottom-color: rgba(255,255,255,0.08);
    }
    .vpn-shell-mk2 .cbi-map .cbi-button-apply {
        background: linear-gradient(135deg, #67e8f9 0%, #38bdf8 52%, #60a5fa 100%);
        color: #06111f;
        box-shadow: 0 14px 24px rgba(34, 211, 238, 0.18);
    }
    .vpn-shell-mk2 .vpn-entry-card code {
        background: rgba(255,255,255,0.08);
        color: #a5f3fc;
    }
    .vpn-shell-mk2 .vpn-output em {
        background: rgba(245,158,11,0.14);
        color: #fde68a;
    }
    .vpn-shell-secondary {
        max-width: 1220px;
        margin: 0 auto 12px;
        padding: 8px;
    }
    .vpn-shell-secondary .vpn-hero-secondary {
        margin: 8px 0 12px;
        padding: 20px 22px;
    }
    .vpn-shell-secondary .vpn-hero-top {
        display: grid;
        grid-template-columns: minmax(0, 1fr) auto;
        gap: 18px;
        align-items: start;
    }
    .vpn-shell-secondary .vpn-page-title a {
        color: #a5f3fc !important;
        text-decoration: none !important;
    }
    .vpn-shell-secondary .vpn-page-title a:hover {
        color: #e0f2fe !important;
    }
    .vpn-shell-secondary .vpn-mini-grid {
        grid-template-columns: repeat(4, minmax(0, 1fr));
        gap: 10px;
        margin-top: 16px;
    }
    .vpn-shell-secondary .vpn-mini-card {
        min-height: 96px;
    }
    .vpn-shell-secondary .vpn-category-rail .vpn-toolbar {
        gap: 8px;
    }
    .vpn-shell-secondary .vpn-category-rail .vpn-pill,
    .vpn-shell-secondary .vpn-category-rail .vpn-status-chip {
        min-height: 32px;
        padding: 6px 12px;
    }
    .vpn-shell-secondary + .cbi-map,
    .cbi-map {
        max-width: 1220px;
        margin: 0 auto 18px;
        padding: 8px;
        color: #e5edf7;
        border-radius: 24px;
        background:
            radial-gradient(circle at 18% 0%, rgba(34, 211, 238, 0.10), transparent 30%),
            radial-gradient(circle at 88% 12%, rgba(96, 165, 250, 0.10), transparent 34%),
            linear-gradient(180deg, rgba(14, 20, 34, 0.96) 0%, rgba(12, 18, 31, 0.98) 100%);
        border: 1px solid rgba(255,255,255,0.08);
        box-shadow: 0 18px 42px rgba(0,0,0,0.22), inset 0 1px 0 rgba(255,255,255,0.05);
    }
    .cbi-map > h2,
    .cbi-map > .cbi-map-descr {
        margin-left: 10px;
        margin-right: 10px;
    }
    .cbi-map > h2 {
        color: #f8fafc !important;
        font-size: 22px;
        line-height: 1.2;
        letter-spacing: -0.02em;
    }
    .cbi-map > .cbi-map-descr {
        color: #9fb0c5;
        line-height: 1.7;
    }
    .cbi-map .cbi-section,
    .cbi-map .cbi-section-node,
    .cbi-map fieldset.cbi-section,
    .cbi-map fieldset.cbi-section-table {
        border-color: rgba(255,255,255,0.09) !important;
        background:
            linear-gradient(180deg, rgba(255,255,255,0.065) 0%, rgba(255,255,255,0.028) 100%) !important;
        box-shadow: inset 0 1px 0 rgba(255,255,255,0.055) !important;
    }
    .cbi-map .cbi-section > h3,
    .cbi-map .cbi-section-node > h3,
    .cbi-map .cbi-section > h4,
    .cbi-map .cbi-section-node > h4,
    .cbi-map .cbi-section legend,
    .cbi-map .cbi-section-table legend,
    .cbi-map fieldset.cbi-section-table > legend,
    .vpn-cbi-section .vpn-section-title {
        color: #f8fafc !important;
        background: transparent !important;
        border-left-color: #22d3ee !important;
    }
    .cbi-map fieldset#cbi-openvpn-openvpn::before {
        color: #f8fafc !important;
        background: transparent !important;
        border-left-color: #22d3ee !important;
    }
    .cbi-map .cbi-value {
        border-bottom-color: rgba(255,255,255,0.08) !important;
    }
    .cbi-map .cbi-value-title,
    .cbi-map .cbi-section-table-titles {
        color: #dbeafe !important;
    }
    .cbi-map .cbi-value-description,
    .cbi-map .cbi-section-descr,
    .cbi-map .cbi-section-table-descr {
        color: #9fb0c5 !important;
    }
    .cbi-map .cbi-section-table-titles {
        background: rgba(255,255,255,0.055) !important;
        border-bottom-color: rgba(255,255,255,0.08) !important;
    }
    .cbi-map .cbi-section-table-cell,
    .cbi-map .cbi-section-table-descr {
        border-bottom-color: rgba(255,255,255,0.08) !important;
    }
    .cbi-map input[type="text"],
    .cbi-map input[type="password"],
    .cbi-map input[type="file"],
    .cbi-map textarea,
    .cbi-map select {
        border-color: rgba(255,255,255,0.13) !important;
        background: rgba(7, 12, 22, 0.78) !important;
        color: #f8fafc !important;
        box-shadow: inset 0 1px 0 rgba(255,255,255,0.04);
    }
    .cbi-map input:focus,
    .cbi-map textarea:focus,
    .cbi-map select:focus {
        border-color: rgba(34,211,238,0.48) !important;
        box-shadow: 0 0 0 3px rgba(34,211,238,0.10), inset 0 1px 0 rgba(255,255,255,0.04);
        outline: none;
    }
    .cbi-map .cbi-button,
    .cbi-map .btn.cbi-button,
    .cbi-map .cbi-button-add,
    .cbi-map .cbi-button-reset {
        border: 1px solid rgba(255,255,255,0.12) !important;
        background: rgba(255,255,255,0.07) !important;
        color: #e2f5ff !important;
        box-shadow: inset 0 1px 0 rgba(255,255,255,0.07);
    }
    .cbi-map .cbi-button-apply,
    .cbi-map input.cbi-button-apply {
        border: 0 !important;
        background: linear-gradient(135deg, #67e8f9 0%, #38bdf8 52%, #60a5fa 100%) !important;
        color: #06111f !important;
        font-weight: 900;
        box-shadow: 0 14px 24px rgba(34, 211, 238, 0.18) !important;
    }
    .cbi-map .vpn-entry-grid-mk2 {
        gap: 12px;
        margin: 10px;
    }
    .cbi-map .vpn-entry-card {
        border-color: rgba(255,255,255,0.10);
        background: rgba(255,255,255,0.045);
        box-shadow: inset 0 1px 0 rgba(255,255,255,0.055);
    }
    .cbi-map .vpn-entry-lead,
    .cbi-map .vpn-field-help,
    .cbi-map .vpn-output {
        color: #9fb0c5;
    }
    .cbi-map .vpn-entry-badge {
        border: 1px solid rgba(74,222,128,0.30);
        background: rgba(34,197,94,0.16);
        color: #bbf7d0;
    }
    .cbi-map code {
        background: rgba(255,255,255,0.08) !important;
        color: #a5f3fc !important;
        border-radius: 6px;
    }
    @media (max-width: 1180px) {
        .vpn-shell-mk2 .vpn-hero-main {
            grid-template-columns: 1fr;
        }
        .vpn-shell-mk2 .vpn-command-card {
            grid-template-columns: minmax(0, 1fr) minmax(260px, 360px);
            align-items: center;
        }
    }
    @media (max-width: 980px) {
        .vpn-shell-mk2 {
            padding: 6px;
            border-radius: 20px;
        }
        .vpn-shell-mk2 .vpn-hero-mk2 {
            padding: 18px;
            border-radius: 20px;
        }
        .vpn-shell-mk2 .vpn-hero h2,
        .vpn-shell-mk2 .vpn-brand-block h2 {
            font-size: 30px !important;
        }
        .vpn-shell-mk2 .vpn-command-card {
            grid-template-columns: 1fr;
        }
        .vpn-shell-mk2 .vpn-orb-wrap {
            grid-template-columns: 92px minmax(0, 1fr);
        }
        .vpn-shell-mk2 .vpn-orb-ring {
            width: 92px;
            height: 92px;
        }
        .vpn-shell-mk2 .vpn-orb-ring span {
            font-size: 15px;
        }
        .vpn-shell-mk2 .vpn-mini-grid-mk2,
        .vpn-shell-mk2 .vpn-stat-grid {
            grid-template-columns: 1fr;
        }
        .vpn-shell-mk2 .vpn-hero-actions {
            grid-template-columns: 1fr;
        }
        .vpn-shell-mk2 .vpn-card + .vpn-card {
            border-left: 0;
            border-top: 1px solid rgba(255,255,255,0.08);
        }
        .vpn-shell-secondary .vpn-hero-top,
        .vpn-shell-secondary .vpn-mini-grid,
        .vpn-entry-grid-mk2 {
            grid-template-columns: 1fr;
        }
    }
</style>
EOF_OPENVPN_OVPN_CSS
    cat > /usr/lib/lua/luci/view/openvpn/pageswitch.htm <<'EOF_OPENVPN_PAGESWITCH'
<%#
 Copyright 2008 Steven Barth <steven@midlink.org>
 Copyright 2008 Jo-Philipp Wich <jow@openwrt.org>
 Licensed to the public under the Apache License 2.0.
-%>

<%+openvpn/ovpn_css%>

<%
local mode = self.mode or "basic"
local uci = require("luci.model.uci").cursor()
local category_title = nil
local instance = self.instance or "-"
local cfg_path = uci:get("openvpn", instance, "config") or "-"
local enabled = uci:get("openvpn", instance, "enabled")
local proto = uci:get("openvpn", instance, "proto") or "-"
local port = uci:get("openvpn", instance, "port") or "-"
local route_noexec = uci:get("openvpn", instance, "route_noexec") == "1" and "手动路由" or "自动路由"
local enabled_label = (enabled == "1") and "已启用" or "未启用"
local mode_label = "高级配置"
local mode_desc = "适合查看与编辑更细粒度的 OpenVPN 参数分组。"
local primary_href = url("admin/services/openvpn/basic", self.instance)
local primary_label = "切换到基础配置"
if mode == "advanced" then
    for _, c in ipairs(self.categories or {}) do
        if c.id == self.category then
            category_title = c.title
            break
        end
    end
elseif mode == "basic" then
    mode_label = "基础配置"
    mode_desc = "适合快速修改常用参数，保存后会自动应用到当前实例。"
    primary_href = url("admin/services/openvpn/advanced", self.instance)
    primary_label = "切换到高级配置"
elseif mode == "file" then
    mode_label = "文件编辑"
    mode_desc = "适合直接维护 ovpn 原始配置和 auth-user-pass 凭据文件。"
    primary_href = url("admin/services/openvpn")
    primary_label = "返回标准 OpenVPN"
end
%>

<div class="vpn-shell vpn-shell-refined vpn-shell-mk2 vpn-shell-secondary">
  <div class="vpn-hero vpn-hero-mk2 vpn-hero-secondary">
    <div class="vpn-toolbar">
      <span class="vpn-pill">OpenVPN</span>
      <span class="vpn-status-chip"><%=mode_label%></span>
    </div>
    <h2 class="vpn-page-title">
      <a href="<%=url('admin/services/openvpn')%>">标准 OpenVPN</a> &#187;
      实例 <%=pcdata(self.instance)%>
    </h2>
    <p class="vpn-sub">
      <%=mode_desc%>
    </p>
    <div class="vpn-hero-actions">
      <a class="cbi-button cbi-button-apply" href="<%=primary_href%>"><%=primary_label%></a>
      <a class="cbi-button" href="<%=url('nradioadv/system/openvpnfull')%>">返回连接中枢</a>
    </div>
  </div>

  <div class="vpn-mini-grid">
    <div class="vpn-mini-card">
      <span class="vpn-mini-label">当前实例</span>
      <strong><%=pcdata(instance)%></strong>
      <span class="vpn-mini-note">当前正在编辑的 OpenVPN UCI 节点</span>
    </div>
    <div class="vpn-mini-card">
      <span class="vpn-mini-label">配置来源</span>
      <strong><%=pcdata(cfg_path)%></strong>
      <span class="vpn-mini-note">若使用外部 ovpn 文件，这里显示其落盘路径</span>
    </div>
    <div class="vpn-mini-card">
      <span class="vpn-mini-label">实例状态</span>
      <strong><%=enabled_label%></strong>
      <span class="vpn-mini-note">协议：<%=pcdata(proto)%> · 端口：<%=pcdata(port)%></span>
    </div>
    <div class="vpn-mini-card">
      <span class="vpn-mini-label">路由模式</span>
      <strong><%=route_noexec%></strong>
      <span class="vpn-mini-note">用于判断当前实例是否交给外部脚本接管</span>
    </div>
  </div>

  <% if mode == "advanced" then %>
    <div class="vpn-card vpn-category-rail" style="margin-bottom:14px;">
      <div class="vpn-card-title">高级分类</div>
      <div class="vpn-toolbar">
        <% for i, c in ipairs(self.categories or {}) do %>
          <% if c.id == self.category then %>
            <span class="vpn-status-chip"><%=c.title%></span>
          <% else %>
            <a class="vpn-pill" href="<%=luci.dispatcher.build_url('admin','services','openvpn','advanced', self.instance, c.id)%>"><%=c.title%></a>
          <% end %>
        <% end %>
      </div>
      <% if category_title then %>
        <div class="vpn-mini-note">当前分类：<strong><%=category_title%></strong></div>
      <% end %>
    </div>
  <% end %>
</div>
EOF_OPENVPN_PAGESWITCH

    cat > /usr/lib/lua/luci/view/openvpn/cbi-select-input-add.htm <<'EOF_OPENVPN_SELECT_INPUT_ADD'

<script type="text/javascript">
//<![CDATA[
	function vpn_add()
	{
		var vpn_name     = div_add.querySelector("#instance_name1").value.replace(/[^\x00-\x7F]|[\s\.!@#$%^&*()\-+=\[\]{};':"\\|,<>\/?]/g,'');
		var vpn_template = div_add.querySelector("#instance_template").value;
		var form         = document.getElementsByName('cbi')[0];

		if (!vpn_name || !vpn_name.length)
		{
			return info_message(vpn_output, "实例名称不能为空。", 2000);
		}

		document.getElementById("instance_name1").value = vpn_name;
		if (document.getElementById("cbi-openvpn-" + vpn_name) != null)
		{
			return info_message(vpn_output, "该实例名称已存在，请更换一个名称。", 2000);
		}

		if (!vpn_template || !vpn_template.length)
		{
			return info_message(vpn_output, "请选择一个可用的模板。", 2000);
		}

		if (form)
		{
			form.submit();
		}
	}

	function vpn_upload()
	{
		var vpn_name = div_upload.querySelector("#instance_name2").value.replace(/[^\x00-\x7F]|[\s\.!@#$%^&*()\-+=\[\]{};':"\\|,<>\/?]/g,'');
		var vpn_file = document.getElementById("ovpn_file").value;
		var form     = document.getElementsByName('cbi')[0];

		if (!vpn_name || !vpn_name.length)
		{
			return info_message(vpn_output, "实例名称不能为空。", 2000);
		}

		document.getElementById("instance_name2").value = vpn_name;
		if (document.getElementById("cbi-openvpn-" + vpn_name) != null)
		{
			return info_message(vpn_output, "该实例名称已存在，请更换一个名称。", 2000);
		}

		if (!vpn_file || !vpn_file.length)
		{
			return info_message(vpn_output, "请选择一个有效的 OVPN 配置文件。", 2000);
		}

		if (form)
		{
			form.enctype = 'multipart/form-data';
			form.action  = '<%=url('admin/services/openvpn/upload')%>';
			form.submit();
		}
	}

	function info_message(output, msg, timeout)
	{
		timeout = timeout || 0;
		output.innerHTML = '<em>' + msg + '</em>';
		if (timeout > 0)
		{
			setTimeout(function(){ output.innerHTML=""}, timeout);
		}
	}
//]]>
</script>

<%+openvpn/ovpn_css%>

<div class="vpn-entry-grid vpn-entry-grid-mk2">
	<div class="vpn-entry-card" id="div_add">
		<div class="vpn-entry-head">
			<h4>模板创建</h4>
			<span class="vpn-entry-badge">推荐</span>
		</div>
		<p class="vpn-entry-lead">适合快速生成一个标准 OpenVPN 实例，再进入基础配置或高级配置继续细化。</p>
		<label class="vpn-field-label" for="instance_name1">实例名称</label>
		<input type="text" maxlength="20" placeholder="例如 custom_config" name="cbi.cts.<%=self.config%>.<%=self.sectiontype%>.text" id="instance_name1" />
		<div class="vpn-field-help">仅允许字母、数字和下划线。创建后会出现在实例列表中。</div>
		<label class="vpn-field-label" for="instance_template">模板</label>
		<select id="instance_template" name="cbi.cts.<%=self.config%>.<%=self.sectiontype%>.select">
			<option value="" selected="selected" disabled="disabled">请选择模板...</option>
			<%- for k, v in luci.util.kspairs(self.add_select_options) do %>
				<option value="<%=k%>"><%=pcdata(v)%></option>
			<% end -%>
		</select>
		<div class="vpn-field-help">模板会预填一组常用参数，后续仍可继续编辑。</div>
		<div class="vpn-entry-actions">
			<input class="btn cbi-button cbi-button-add" type="submit" onclick="vpn_add(); return false;" value="创建实例" title="创建模板实例" />
		</div>
	</div>

	<div class="vpn-entry-card" id="div_upload">
		<div class="vpn-entry-head">
			<h4>OVPN 文件上传</h4>
			<span class="vpn-entry-badge vpn-badge-neutral">兼容</span>
		</div>
		<p class="vpn-entry-lead">适合直接导入现成客户端文件。上传后将创建实例并把配置落盘到 <code>/etc/openvpn/&lt;name&gt;.ovpn</code>。</p>
		<label class="vpn-field-label" for="instance_name2">实例名称</label>
		<input type="text" maxlength="20" placeholder="例如 custom_config" name="instance_name2" id="instance_name2" />
		<div class="vpn-field-help">实例名称会决定落盘文件名和列表中的显示项。</div>
		<label class="vpn-field-label" for="ovpn_file">配置文件</label>
		<input type="file" name="ovpn_file" id="ovpn_file" accept="application/x-openvpn-profile,.ovpn" />
		<div class="vpn-field-help">支持标准 `.ovpn` 客户端配置文件，上传后可再到 OEM 视图核对运行状态。</div>
		<div class="vpn-entry-actions">
			<input class="btn cbi-button cbi-button-add" type="submit" onclick="vpn_upload(); return false;" value="上传导入" title="上传 ovpn 文件" />
		</div>
	</div>
</div>

<div class="vpn-output">
	<span id="vpn_output"></span>
</div>
EOF_OPENVPN_SELECT_INPUT_ADD

    cat > /usr/lib/lua/luci/view/openvpn/overview_intro.htm <<'EOF_OPENVPN_OVERVIEW_INTRO'
<%+openvpn/ovpn_css%>

<div class="vpn-shell vpn-shell-refined vpn-shell-mk2 vpn-shell-secondary">
  <div class="vpn-hero vpn-hero-mk2 vpn-hero-secondary">
    <div class="vpn-hero-top">
      <div class="vpn-brand-block">
        <div class="vpn-toolbar">
          <span class="vpn-pill">OpenVPN</span>
          <span class="vpn-status-chip">标准实例管理</span>
        </div>
        <h2>标准 OpenVPN</h2>
        <p class="vpn-sub">用于新建模板实例、导入现成 ovpn 文件，或维护原生 OpenVPN 节点；运行态建议回到连接中枢查看。</p>
      </div>
      <div class="vpn-hero-actions">
        <a class="cbi-button cbi-button-apply" href="<%=url('nradioadv/system/openvpnfull')%>">返回连接中枢</a>
      </div>
    </div>

    <div class="vpn-mini-grid">
      <div class="vpn-mini-card">
        <span class="vpn-mini-label">实例总数</span>
        <strong><%=self.instance_count or 0%></strong>
        <span class="vpn-mini-note">当前 UCI 中已注册的 OpenVPN 实例数量</span>
      </div>
      <div class="vpn-mini-card">
        <span class="vpn-mini-label">启用实例</span>
        <strong><%=self.enabled_count or 0%></strong>
        <span class="vpn-mini-note">已开启 `enabled` 的实例数量</span>
      </div>
      <div class="vpn-mini-card">
        <span class="vpn-mini-label">运行实例</span>
        <strong><%=self.running_count or 0%></strong>
        <span class="vpn-mini-note">当前检测到仍在运行的进程数量</span>
      </div>
      <div class="vpn-mini-card">
        <span class="vpn-mini-label">文件型实例</span>
        <strong><%=self.file_cfg_count or 0%></strong>
        <span class="vpn-mini-note">配置来源为外部 `.ovpn` 文件的实例数量</span>
      </div>
    </div>
  </div>
</div>
EOF_OPENVPN_OVERVIEW_INTRO

    cat > /usr/lib/lua/luci/view/openvpn/nsection.htm <<'EOF_OPENVPN_NSECTION'
<% if self:cfgvalue(self.section) then section = self.section %>
	<fieldset class="cbi-section vpn-cbi-section">
		<% if self.title and #self.title > 0 then -%>
			<div class="vpn-section-title"><%=self.title%></div>
		<%- end %>
		<% if self.description and #self.description > 0 then -%>
			<div class="cbi-section-descr"><%=self.description%></div>
		<%- end %>
		<% if self.addremove then -%>
			<div class="cbi-section-remove right">
				<input type="submit" class="cbi-button" name="cbi.rns.<%=self.config%>.<%=section%>" value="<%:Delete%>" />
			</div>
		<%- end %>
		<%+cbi/tabmenu%>
		<div class="cbi-section-node<% if self.tabs then %> cbi-section-node-tabbed<% end %>" id="cbi-<%=self.config%>-<%=section%>">
			<%+cbi/ucisection%>
		</div>
		<br />
	</fieldset>
<% elseif self.addremove then %>
	<% if self.template_addremove then include(self.template_addremove) else -%>
	<fieldset class="cbi-section vpn-cbi-section" id="cbi-<%=self.config%>-<%=self.section%>">
		<% if self.title and #self.title > 0 then -%>
			<div class="vpn-section-title"><%=self.title%></div>
		<%- end %>
		<div class="cbi-section-descr"><%=self.description%></div>
		<input type="submit" class="cbi-button cbi-button-add" name="cbi.cns.<%=self.config%>.<%=self.section%>" value="<%:Add%>" />
	</fieldset>
	<%- end %>
<% end %>
EOF_OPENVPN_NSECTION

    cat > /usr/lib/lua/luci/model/cbi/openvpn.lua <<'EOF_OPENVPN_STANDARD_MODEL'
-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Licensed to the public under the Apache License 2.0.

local fs  = require "nixio.fs"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()
local testfullps = sys.exec("ps --help 2>&1 | grep BusyBox") --check which ps do we have
local psstring = (string.len(testfullps)>0) and  "ps w" or  "ps axfw" --set command we use to get pid

local function getPID(section)
	local pid = sys.exec("%s | grep -w '[o]penvpn(%s)'" % { psstring, section })
	if pid and #pid > 0 then
		return tonumber(pid:match("^%s*(%d+)"))
	end
	return nil
end

local instance_count = 0
local enabled_count = 0
local running_count = 0
local file_cfg_count = 0

uci:foreach("openvpn", "openvpn", function(section)
	instance_count = instance_count + 1
	if section.enabled == "1" then
		enabled_count = enabled_count + 1
	end
	if section.config then
		file_cfg_count = file_cfg_count + 1
	end
	local pid = getPID(section[".name"])
	if pid ~= nil and sys.process.signal(pid, 0) then
		running_count = running_count + 1
	end
end)

local m = Map("openvpn", translate("标准 OpenVPN"), translate("原生实例管理入口。适合新建模板实例、导入 ovpn 文件，或直接维护现有 OpenVPN 节点。"))
local intro = m:section(SimpleSection)
intro.template = "openvpn/overview_intro"
intro.instance_count = instance_count
intro.enabled_count = enabled_count
intro.running_count = running_count
intro.file_cfg_count = file_cfg_count
local s = m:section( TypedSection, "openvpn", translate("实例列表"), translate("这里展示当前已配置的 OpenVPN 实例及其运行状态。"))
s.template = "cbi/tblsection"
s.template_addremove = "openvpn/cbi-select-input-add"
s.addremove = true
s.add_select_options = { }

local cfg = s:option(DummyValue, "config", "配置来源")
function cfg.cfgvalue(self, section)
	local file_cfg = self.map:get(section, "config")
	if file_cfg then
		s.extedit = luci.dispatcher.build_url("admin", "services", "openvpn", "file", "%s")
	else
		s.extedit = luci.dispatcher.build_url("admin", "services", "openvpn", "basic", "%s")
	end
end

uci:load("openvpn_recipes")
uci:foreach( "openvpn_recipes", "openvpn_recipe",
	function(section)
		s.add_select_options[section['.name']] =
			section['_description'] or section['.name']
	end
)

function s.getPID(section) -- Universal function which returns valid pid # or nil
	return getPID(section)
end

function s.parse(self, section)
	local recipe = luci.http.formvalue(
		luci.cbi.CREATE_PREFIX .. self.config .. "." ..
		self.sectiontype .. ".select"
	)

	if recipe and not s.add_select_options[recipe] then
		self.invalid_cts = true
	else
		TypedSection.parse( self, section )
	end
end

function s.create(self, name)
	local recipe = luci.http.formvalue(
		luci.cbi.CREATE_PREFIX .. self.config .. "." ..
		self.sectiontype .. ".select"
	)
	local name = luci.http.formvalue(
		luci.cbi.CREATE_PREFIX .. self.config .. "." ..
		self.sectiontype .. ".text"
	)
	if #name > 3 and not name:match("[^a-zA-Z0-9_]") then
		local s = uci:section("openvpn", "openvpn", name)
		if s then
			local options = uci:get_all("openvpn_recipes", recipe)
			for k, v in pairs(options) do
				if k ~= "_role" and k ~= "_description" then
					if type(v) == "boolean" then
						v = v and "1" or "0"
					end
					uci:set("openvpn", name, k, v)
				end
			end
			uci:save("openvpn")
			uci:commit("openvpn")
			if extedit then
				luci.http.redirect( self.extedit:format(name) )
			end
		end
	elseif #name > 0 then
		self.invalid_cts = true
	end
	return 0
end

function s.remove(self, name)
	local cfg_file  = "/etc/openvpn/" ..name.. ".ovpn"
	local auth_file = "/etc/openvpn/" ..name.. ".auth"
	if fs.access(cfg_file) then
		fs.unlink(cfg_file)
	end
	if fs.access(auth_file) then
		fs.unlink(auth_file)
	end
	uci:delete("openvpn", name)
	uci:save("openvpn")
	uci:commit("openvpn")
end

s:option( Flag, "enabled", "启用" )

local active = s:option( DummyValue, "_active", "运行中" )
function active.cfgvalue(self, section)
	local pid = s.getPID(section)
	if pid ~= nil then
		return (sys.process.signal(pid, 0))
			and string.format("是 (%i)", pid)
			or  "否"
	end
	return "否"
end

local updown = s:option( Button, "_updown", "操作" )
updown._state = false
updown.redirect = luci.dispatcher.build_url(
	"admin", "services", "openvpn"
)
function updown.cbid(self, section)
	local pid = s.getPID(section)
	self._state = pid ~= nil and sys.process.signal(pid, 0)
	self.option = self._state and "stop" or "start"
	return AbstractValue.cbid(self, section)
end
function updown.cfgvalue(self, section)
	self.title = self._state and "停止" or "启动"
	self.inputstyle = self._state and "reset" or "reload"
end
function updown.write(self, section, value)
	if self.option == "stop" then
		sys.call("/etc/init.d/openvpn stop %s" % section)
	else
		sys.call("/etc/init.d/openvpn start %s" % section)
	end
	luci.http.redirect( self.redirect )
end

local port = s:option( DummyValue, "port", "端口" )
function port.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	if not val then
		local file_cfg = self.map:get(section, "config")
		if file_cfg  and fs.access(file_cfg) then
			val = sys.exec("awk '{if(match(tolower($1),/^port$/)&&match($2,/[0-9]+/)){cnt++;printf $2;exit}}END{if(cnt==0)printf \"-\"}' " ..file_cfg)
			if val == "-" then
				val = sys.exec("awk '{if(match(tolower($1),/^remote$/)&&match($3,/[0-9]+/)){cnt++;printf $3;exit}}END{if(cnt==0)printf \"-\"}' " ..file_cfg)
			end
		end
	end
	return val or "-"
end

local proto = s:option( DummyValue, "proto", "协议" )
function proto.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	if not val then
		local file_cfg = self.map:get(section, "config")
		if file_cfg and fs.access(file_cfg) then
			val = sys.exec("awk '{if(match(tolower($1),/^proto$/)&&match(tolower($2),/^udp[46]*$|^tcp[a-z46-]*$/)){cnt++;print tolower(substr($2,1,3));exit}}END{if(cnt==0)printf \"-\"}' " ..file_cfg)
			if val == "-" then
				val = sys.exec("awk '{if(match(tolower($1),/^remote$/)&&match(tolower($4),/^udp[46]*$|^tcp[a-z46-]*$/)){cnt++;print tolower(substr($4,1,3));exit}}END{if(cnt==0)printf \"-\"}' " ..file_cfg)
			end
		end
	end
	return val or "-"
end

function m.on_after_apply(self,map)
	sys.call('/etc/init.d/openvpn reload')
end

return m
EOF_OPENVPN_STANDARD_MODEL

    cat > /usr/lib/lua/luci/model/cbi/openvpn-file.lua <<'EOF_OPENVPN_FILE_MODEL'
-- Licensed to the public under the Apache License 2.0.

local ip        = require("luci.ip")
local fs        = require("nixio.fs")
local util      = require("luci.util")
local uci       = require("luci.model.uci").cursor()
local cfg_file  = uci:get("openvpn", arg[1], "config")
local auth_file = cfg_file:match("(.+)%..+").. ".auth"

local function makeForm(id, title, desc)
	local t = Template("openvpn/pageswitch")
	t.mode = "file"
	t.instance = arg[1]

	local f = SimpleForm(id, title, desc)
	f:append(t)

	return f
end

if not cfg_file or not fs.access(cfg_file) then
	local f = makeForm("error", "文件编辑不可用", translatef("未找到当前实例绑定的 OVPN 配置文件（%s），请先检查实例配置或返回标准 OpenVPN 重新导入。", cfg_file or "n/a"))
	f:append(Template("openvpn/ovpn_css"))
	f.reset = false
	f.submit = false
	return f
end

if fs.stat(cfg_file).size >= 102400 then
	local f = makeForm("error", "文件过大",
		translatef("当前 OVPN 配置文件（%s）已超过在线编辑限制（&ge; 100 KB）。", cfg_file)
		.. translate("请改用终端直接编辑该文件。"))
	f:append(Template("openvpn/ovpn_css"))
	f.reset = false
	f.submit = false
	return f
end

f = makeForm("cfg", "文件编辑")
f:append(Template("openvpn/ovpn_css"))
f.submit = translate("保存修改")
f.reset = false

s = f:section(SimpleSection, nil, translatef("这里直接编辑 OVPN 原始配置文件：%s", cfg_file))
file = s:option(TextValue, "data1")
file.datatype = "string"
file.rows = 20

function file.cfgvalue()
	return fs.readfile(cfg_file) or ""
end

function file.write(self, section, data1)
	return fs.writefile(cfg_file, "\n" .. util.trim(data1:gsub("\r\n", "\n")) .. "\n")
end

function file.remove(self, section, value)
	return fs.writefile(cfg_file, "")
end

function s.handle(self, state, data1)
	return true
end

s = f:section(SimpleSection, nil, translatef("这里编辑可选的 auth-user-pass 凭据文件：%s", auth_file))
file = s:option(TextValue, "data2")
file.datatype = "string"
file.rows = 5

function file.cfgvalue()
	return fs.readfile(auth_file) or ""
end

function file.write(self, section, data2)
	return fs.writefile(auth_file, util.trim(data2:gsub("\r\n", "\n")) .. "\n")
end

function file.remove(self, section, value)
	return fs.writefile(auth_file, "")
end

function s.handle(self, state, data2)
	return true
end

return f
EOF_OPENVPN_FILE_MODEL

    cat > /usr/lib/lua/luci/model/cbi/openvpn-basic.lua <<'EOF_OPENVPN_BASIC_MODEL'
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
EOF_OPENVPN_BASIC_MODEL

    cat > /usr/lib/lua/luci/model/cbi/openvpn-advanced.lua <<'EOF_OPENVPN_ADVANCED_MODEL'
-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Licensed to the public under the Apache License 2.0.

local fs = require("nixio.fs")

local _translate = translate
local zh = {
	["Accept options pushed from server"] = "接受服务端下发的选项",
	["Add route after establishing connection"] = "连接建立后添加路由",
	["Additional authentication over TLS"] = "TLS 附加认证",
	["Allow client-to-client traffic"] = "允许客户端之间互访",
	["Allow multiple clients with same certificate"] = "允许多个客户端使用同一证书",
	["Allow only one session"] = "仅允许单个会话",
	["Allow remote to change its IP or port"] = "允许对端变更 IP 或端口",
	["Allowed maximum of connected clients"] = "允许的最大连接客户端数",
	["Allowed maximum of internal"] = "允许的最大内部条目数",
	["Allowed maximum of new connections"] = "允许的最大新连接数",
	["Append log to file"] = "追加日志到文件",
	["Authenticate using username/password"] = "使用用户名/密码认证",
	["Automatically redirect default route"] = "自动重定向默认路由",
	["Call down cmd/script before TUN/TAP close"] = "在关闭 TUN/TAP 前执行 down 脚本",
	["Certificate authority"] = "CA 证书",
	["Change process priority"] = "调整进程优先级",
	["Change to directory before initialization"] = "初始化前切换到目录",
	["Check peer certificate against a CRL"] = "使用 CRL 校验对端证书",
	["Chroot to directory after initialization"] = "初始化后 chroot 到目录",
	["Client is disabled"] = "客户端已禁用",
	["Configure client mode"] = "配置客户端模式",
	["Configure server bridge"] = "配置服务端桥接",
	["Configure server mode"] = "配置服务端模式",
	["Connect through Socks5 proxy"] = "通过 Socks5 代理连接",
	["Connect to remote host through an HTTP proxy"] = "通过 HTTP 代理连接远端",
	["Connection retry interval"] = "连接重试间隔",
	["Cryptography"] = "加密",
	["Daemonize after initialization"] = "初始化后转入守护进程",
	["Delay n seconds after connection"] = "连接后延迟 n 秒",
	["Delay tun/tap open and up script execution"] = "延迟打开 tun/tap 并执行 up 脚本",
	["Diffie-Hellman parameters"] = "Diffie-Hellman 参数",
	["Directory for custom client config files"] = "自定义客户端配置目录",
	["Disable options consistency check"] = "禁用选项一致性检查",
	["Disable Paging"] = "禁止内存换页",
	["Do not bind to local address and port"] = "不绑定本地地址和端口",
	["Don't actually execute ifconfig"] = "不实际执行 ifconfig",
	["Don't add routes automatically"] = "不自动添加路由",
	["Don't cache --askpass or --auth-user-pass passwords"] = "不缓存 --askpass 或 --auth-user-pass 密码",
	["Don't drop incoming tun packets with same destination as host"] = "不丢弃目标与主机相同的入站 tun 报文",
	["Don't inherit global push options"] = "不继承全局 push 选项",
	["Don't log timestamps"] = "日志不写时间戳",
	["Don't pull routes automatically"] = "不自动拉取路由",
	["Don't re-read key on restart"] = "重启时不重新读取密钥",
	["Don't use adaptive lzo compression"] = "不使用自适应 LZO 压缩",
	["Don't warn on ifconfig inconsistencies"] = "不对 ifconfig 不一致发出警告",
	["Echo parameters to log"] = "将参数回显到日志",
	["Empirically measure MTU"] = "经验性测量 MTU",
	["Enable a compression algorithm"] = "启用压缩算法",
	["Enable internal datagram fragmentation"] = "启用内部数据报分片",
	["Enable management interface on <em>IP</em> <em>port</em>"] = "在 <em>IP</em> <em>端口</em> 启用管理接口",
	["Enable OpenSSL hardware crypto engines"] = "启用 OpenSSL 硬件加密引擎",
	["Enable Path MTU discovery"] = "启用路径 MTU 发现",
	["Enable Static Key encryption mode (non-TLS)"] = "启用静态密钥加密模式（非 TLS）",
	["Enable TLS and assume client role"] = "启用 TLS 并作为客户端",
	["Enable TLS and assume server role"] = "启用 TLS 并作为服务端",
	["Encrypt and authenticate all control channel packets with the key"] = "使用该密钥加密并认证所有控制通道数据包",
	["Encryption cipher for packets"] = "数据包加密算法",
	["Execute shell cmd after routes are added"] = "路由添加后执行 shell 命令",
	["Execute shell command on remote IP change"] = "远端 IP 变化时执行 shell 命令",
	["Executed in server mode on new client connections, when the client is still untrusted"] = "服务端模式下新客户端连接且尚未可信时执行",
	["Executed in server mode whenever an IPv4 address/route or MAC address is added to OpenVPN's internal routing table"] = "服务端模式下每次向 OpenVPN 内部路由表添加 IPv4 地址、路由或 MAC 时执行",
	["Exit on TLS negotiation failure"] = "TLS 协商失败时退出",
	["Get PEM password from controlling tty before we daemonize"] = "守护化前从控制终端读取 PEM 密码",
	["Handling of authentication failures"] = "认证失败处理方式",
	["Helper directive to simplify the expression of --ping and --ping-restart in server mode configurations"] = "用于简化服务端模式下 --ping 与 --ping-restart 的辅助指令",
	["HMAC authentication for packets"] = "数据包 HMAC 认证",
	["If hostname resolve fails, retry"] = "主机名解析失败时重试",
	["Keep local IP address on restart"] = "重启时保留本地 IP 地址",
	["Keep remote IP address on restart"] = "重启时保留远端 IP 地址",
	["Keep tun/tap device open on restart"] = "重启时保持 tun/tap 设备打开",
	["Key transition window"] = "密钥轮换窗口",
	["Limit repeated log messages"] = "限制重复日志消息",
	["Local certificate"] = "本地证书",
	["Local host name or IP address"] = "本地主机名或 IP 地址",
	["Local private key"] = "本地私钥",
	["Major mode"] = "主模式",
	["Maximum number of queued TCP output packets"] = "TCP 输出队列最大包数",
	["'net30', 'p2p', or 'subnet'"] = "net30、p2p 或 subnet",
	["Networking"] = "网络",
	["Number of allocated broadcast buffers"] = "分配的广播缓冲区数量",
	["Number of lines for log file history"] = "日志历史行数",
	["Only accept connections from given X509 name"] = "仅接受指定 X509 名称的连接",
	["Only process ping timeouts if routes exist"] = "仅在路由存在时处理 ping 超时",
	["Optimize TUN/TAP/UDP writes"] = "优化 TUN/TAP/UDP 写入",
	["Output to syslog and do not daemonize"] = "输出到 syslog 且不转为守护进程",
	["Pass environment variables to script"] = "向脚本传递环境变量",
	["Persist replay-protection state"] = "持久化重放保护状态",
	["Persist/unpersist ifconfig-pool"] = "持久化/取消持久化 ifconfig-pool",
	["Ping remote every n seconds over TCP/UDP port"] = "每 n 秒通过 TCP/UDP 端口 ping 远端",
	["PKCS#12 file containing keys"] = "包含密钥的 PKCS#12 文件",
	["Policy level over usage of external programs and scripts"] = "外部程序与脚本使用策略级别",
	["Proxy timeout in seconds"] = "代理超时时间（秒）",
	["Push an ifconfig option to remote"] = "向远端推送 ifconfig 选项",
	["Push options to peer"] = "向对端推送选项",
	["Query management channel for private key"] = "通过管理通道查询私钥",
	["Randomly choose remote server"] = "随机选择远端服务器",
	["Refuse connection if no custom client config"] = "无自定义客户端配置时拒绝连接",
	["Remap SIGUSR1 signals"] = "重映射 SIGUSR1 信号",
	["Remote host name or IP address"] = "远端主机名或 IP 地址",
	["Remote ping timeout"] = "远端 ping 超时",
	["Renegotiate data chan. key after bytes"] = "传输指定字节数后重新协商数据通道密钥",
	["Renegotiate data chan. key after packets"] = "传输指定包数后重新协商数据通道密钥",
	["Renegotiate data chan. key after seconds"] = "经过指定秒数后重新协商数据通道密钥",
	["Replay protection sliding window size"] = "重放保护滑动窗口大小",
	["Require explicit designation on certificate"] = "要求证书显式指定用途",
	["Require explicit key usage on certificate"] = "要求证书显式指定密钥用途",
	["Restart after remote ping timeout"] = "远端 ping 超时后重启",
	["Restrict the allowed ciphers to be negotiated"] = "限制可协商的加密算法",
	["Retransmit timeout on TLS control channel"] = "TLS 控制通道重传超时",
	["Retry indefinitely on HTTP proxy errors"] = "HTTP 代理错误时无限重试",
	["Retry indefinitely on Socks proxy errors"] = "Socks 代理错误时无限重试",
	["Route subnet to client"] = "将子网路由到客户端",
	["Run as an inetd or xinetd server"] = "作为 inetd 或 xinetd 服务运行",
	["Run script cmd on client connection"] = "客户端连接时运行脚本",
	["Run script cmd on client disconnection"] = "客户端断开时运行脚本",
	["Run up/down scripts for all restarts"] = "所有重启都运行 up/down 脚本",
	["Send notification to peer on disconnect"] = "断开时通知对端",
	["Service"] = "服务",
	["Set aside a pool of subnets"] = "预留一组子网地址池",
	["Set extended HTTP proxy options"] = "设置扩展 HTTP 代理选项",
	["Set GID to group"] = "设置进程 GID",
	["Set output verbosity"] = "设置输出详细级别",
	["Set size of real and virtual address hash tables"] = "设置真实与虚拟地址哈希表大小",
	["Set TCP/UDP MTU"] = "设置 TCP/UDP MTU",
	["Set the TCP/UDP receive buffer size"] = "设置 TCP/UDP 接收缓冲区大小",
	["Set the TCP/UDP send buffer size"] = "设置 TCP/UDP 发送缓冲区大小",
	["Set tun/tap adapter parameters"] = "设置 tun/tap 适配器参数",
	["Set tun/tap device MTU"] = "设置 tun/tap 设备 MTU",
	["Set tun/tap device overhead"] = "设置 tun/tap 设备额外开销",
	["Set tun/tap TX queue length"] = "设置 tun/tap 发送队列长度",
	["Set UID to user"] = "设置进程 UID",
	["Set upper bound on TCP MSS"] = "设置 TCP MSS 上限",
	["Shaping for peer bandwidth"] = "对端带宽整形",
	["Shell cmd to execute after tun device open"] = "打开 tun 设备后执行的 shell 命令",
	["Shell cmd to run after tun device close"] = "关闭 tun 设备后执行的 shell 命令",
	["Shell command to verify X509 name"] = "用于校验 X509 名称的 shell 命令",
	["Silence the output of replay warnings"] = "静默重放警告输出",
	["Size of cipher key"] = "密钥长度",
	["Specify a default gateway for routes"] = "为路由指定默认网关",
	["Specify whether the client is required to supply a valid certificate"] = "指定客户端是否必须提供有效证书",
	["Start OpenVPN in a hibernating state"] = "以休眠状态启动 OpenVPN",
	["Status file format version"] = "状态文件格式版本",
	["TCP/UDP port # for both local and remote"] = "本地与远端共用的 TCP/UDP 端口",
	["TCP/UDP port # for local (default=1194)"] = "本地 TCP/UDP 端口（默认 1194）",
	["TCP/UDP port # for remote (default=1194)"] = "远端 TCP/UDP 端口（默认 1194）",
	["Temporary directory for client-connect return file"] = "client-connect 返回文件的临时目录",
	["The highest supported TLS version"] = "支持的最高 TLS 版本",
	["The key direction for 'tls-auth' and 'secret' options"] = "tls-auth 与 secret 选项的密钥方向",
	["The lowest supported TLS version"] = "支持的最低 TLS 版本",
	["This completely disables cipher negotiation"] = "完全禁用加密算法协商",
	["Timeframe for key exchange"] = "密钥交换时间窗口",
	["TLS 1.3 or newer cipher"] = "TLS 1.3 及以上加密算法",
	["TLS cipher"] = "TLS 加密套件",
	["TOS passthrough (applies to IPv4 only)"] = "TOS 透传（仅 IPv4）",
	["tun/tap device"] = "tun/tap 设备",
	["tun/tap inactivity timeout"] = "tun/tap 空闲超时",
	["Type of used device"] = "设备类型",
	["Use fast LZO compression"] = "使用快速 LZO 压缩",
	["Use protocol"] = "使用协议",
	["Use tun/tap device node"] = "使用 tun/tap 设备节点",
	["Use username as common name"] = "使用用户名作为通用名",
	["VPN"] = "VPN",
	["Write log to file"] = "写日志到文件",
	["Write process ID to file"] = "写 PID 到文件",
	["Write status to file every n seconds"] = "每 n 秒写入一次状态文件"
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
	["float"] = "允许漂移",
	["net30"] = "net30 点对点",
	["p2p"] = "点对点",
	["subnet"] = "子网",
	["system"] = "系统默认",
	["server"] = "服务端",
	["client"] = "客户端",
	["always"] = "始终",
	["maybe"] = "自动",
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

local knownParams = {
	--
	--Widget
	--	ID
	--	Display name
	--	Default(s)
	--	Description
	--	Option(s)

	{ "service", translate("Service"), {
	-- initialisation and daemon options
		{ ListValue,
			"verb",
			{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
			translate("Set output verbosity") },
		{ Flag,
			"mlock",
			0,
			translate("Disable Paging") },
		{ Flag,
			"disable_occ",
			0,
			translate("Disable options consistency check") },
	--	{ Value,
	--		"user",
	--		"root",
	--		translate("Set UID to user") },
	--	{ Value,
	--		"group",
	--		"root",
	--		translate("Set GID to group") },
		{ Value,
			"cd",
			"/etc/openvpn",
			translate("Change to directory before initialization") },
		{ Value,
			"chroot",
			"/var/run",
			translate("Chroot to directory after initialization") },
	--	{ Value,
	--		"daemon",
	--		"Instance-Name",
	--		translate("Daemonize after initialization") },
	--	{ Value,
	--		"syslog",
	--		"Instance-Name",
	--		translate("Output to syslog and do not daemonize") },
		{ Flag,
			"passtos",
			0,
			translate("TOS passthrough (applies to IPv4 only)") },
	--	{ Value,
	--		"inetd",
	--		"nowait Instance-Name",
	--		translate("Run as an inetd or xinetd server") },
		{ Value,
			"log",
			"/var/log/openvpn.log",
			translate("Write log to file") },
		{ Value,
			"log_append",
			"/var/log/openvpn.log",
			translate("Append log to file") },
		{ Flag,
			"suppress_timestamps",
			0,
			translate("Don't log timestamps") },
	--	{ Value,
	--		"writepid",
	--		"/var/run/openvpn.pid",
	--		translate("Write process ID to file") },
		{ Value,
			"nice",
			0,
			translate("Change process priority") },
		{ Flag,
			"fast_io",
			0,
			translate("Optimize TUN/TAP/UDP writes") },
		{ Value,
			"echo",
			"some params echoed to log",
			translate("Echo parameters to log") },
		{ ListValue,
			"remap_usr1",
			{ "SIGHUP", "SIGTERM" },
			translate("Remap SIGUSR1 signals") },
		{ Value,
			"status",
			"/var/run/openvpn.status 5",
			translate("Write status to file every n seconds") },
		{ Value,
			"status_version",
			{ 1, 2 },
			translate("Status file format version") },	-- status
		{ Value,
			"mute",
			5,
			translate("Limit repeated log messages") },
		{ Value,
			"up",
			"/usr/bin/ovpn-up",
			translate("Shell cmd to execute after tun device open") },
		{ Value,
			"up_delay",
			5,
			translate("Delay tun/tap open and up script execution") },
		{ Value,
			"down",
			"/usr/bin/ovpn-down",
			translate("Shell cmd to run after tun device close") },
		{ Flag,
			"down_pre",
			0,
			translate("Call down cmd/script before TUN/TAP close") },
		{ Flag,
			"up_restart",
			0,
			translate("Run up/down scripts for all restarts") },
		{ Value,
			"route_up",
			"/usr/bin/ovpn-routeup",
			translate("Execute shell cmd after routes are added") },
		{ Value,
			"ipchange",
			"/usr/bin/ovpn-ipchange",
			translate("Execute shell command on remote IP change"),
			{ mode="p2p" } },
		{ DynamicList,
			"setenv",
			{ "VAR1 value1", "VAR2 value2" },
			translate("Pass environment variables to script") },
		{ Value,
			"tls_verify",
			"/usr/bin/ovpn-tlsverify",
			translate("Shell command to verify X509 name") },
		{ Value,
			"client_connect",
			"/usr/bin/ovpn-clientconnect",
			translate("Run script cmd on client connection") },
		{ Value,
			"client_disconnect",
			"/usr/bin/ovpn-clientdisconnect",
			translate("Run script cmd on client disconnection") },
		{ Value,
			"learn_address",
			"/usr/bin/ovpn-learnaddress",
			translate("Executed in server mode whenever an IPv4 address/route or MAC address is added to OpenVPN's internal routing table") },
		{ Value,
			"auth_user_pass_verify",
			"/usr/bin/ovpn-userpass via-env",
			translate("Executed in server mode on new client connections, when the client is still untrusted") },
		{ ListValue,
			"script_security",
			{ 0, 1, 2, 3 },
			translate("Policy level over usage of external programs and scripts") },
		{ ListValue,
			"compress",
			{ "lzo", "lz4" },
			translate("Enable a compression algorithm") },
	} },

	{ "networking", translate("Networking"), {
	-- socket config
		{ ListValue,
			"mode",
			{ "p2p", "server" },
			translate("Major mode") },
		{ Value,
			"local",
			"0.0.0.0",
			translate("Local host name or IP address") },
		{ Value,
			"port",
			1194,
			translate("TCP/UDP port # for both local and remote") },
		{ Value,
			"lport",
			1194,
			translate("TCP/UDP port # for local (default=1194)") },
		{ Value,
			"rport",
			1194,
			translate("TCP/UDP port # for remote (default=1194)") },
		{ Flag,
			"float",
			0,
			translate("Allow remote to change its IP or port") },
		{ Flag,
			"nobind",
			0,
			translate("Do not bind to local address and port") },
		{ Value,
			"dev",
			"tun0",
			translate("tun/tap device") },
		{ ListValue,
			"dev_type",
			{ "tun", "tap" },
			translate("Type of used device") },
		{ Value,
			"dev_node",
			"/dev/net/tun",
			translate("Use tun/tap device node") },
		{ Value,
			"ifconfig",
			"10.200.200.3 10.200.200.1",
			translate("Set tun/tap adapter parameters") },
		{ Flag,
			"ifconfig_noexec",
			0,
			translate("Don't actually execute ifconfig") },
		{ Flag,
			"ifconfig_nowarn",
			0,
			translate("Don't warn on ifconfig inconsistencies") },
		{ DynamicList,
			"route",
			"10.123.0.0 255.255.0.0",
			translate("Add route after establishing connection") },
		{ Value,
			"route_gateway",
			"10.234.1.1",
			translate("Specify a default gateway for routes") },
		{ Value,
			"route_delay",
			0,
			translate("Delay n seconds after connection") },
		{ Flag,
			"route_noexec",
			0,
			translate("Don't add routes automatically") },
		{ Flag,
			"route_nopull",
			0,
			translate("Don't pull routes automatically") },
		{ Flag,
			"allow_recursive_routing",
			0,
			translate("Don't drop incoming tun packets with same destination as host") },
		{ ListValue,
			"mtu_disc",
			{ "yes", "maybe", "no" },
			translate("Enable Path MTU discovery") },
		{ Flag,
			"mtu_test",
			0,
			translate("Empirically measure MTU") },
		{ ListValue,
			"comp_lzo",
			{ "yes", "no", "adaptive" },
			translate("Use fast LZO compression") },
		{ Flag,
			"comp_noadapt",
			0,
			translate("Don't use adaptive lzo compression"),
			{ comp_lzo=1 } },
		{ Value,
			"link_mtu",
			1500,
			translate("Set TCP/UDP MTU") },
		{ Value,
			"tun_mtu",
			1500,
			translate("Set tun/tap device MTU") },
		{ Value,
			"tun_mtu_extra",
			1500,
			translate("Set tun/tap device overhead") },
		{ Value,
			"fragment",
			1500,
			translate("Enable internal datagram fragmentation"),
			{ proto="udp" } },
		{ Value,
			"mssfix",
			1500,
			translate("Set upper bound on TCP MSS"),
			{ proto="udp" } },
		{ Value,
			"sndbuf",
			65536,
			translate("Set the TCP/UDP send buffer size") },
		{ Value,
			"rcvbuf",
			65536,
			translate("Set the TCP/UDP receive buffer size") },
		{ Value,
			"txqueuelen",
			100,
			translate("Set tun/tap TX queue length") },
		{ Value,
			"shaper",
			10240,
			translate("Shaping for peer bandwidth") },
		{ Value,
			"inactive",
			240,
			translate("tun/tap inactivity timeout") },
		{ Value,
			"keepalive",
			"10 60",
			translate("Helper directive to simplify the expression of --ping and --ping-restart in server mode configurations") },
		{ Value,
			"ping",
			30,
			translate("Ping remote every n seconds over TCP/UDP port") },
		{ Value,
			"ping_exit",
			120,
			translate("Remote ping timeout") },
		{ Value,
			"ping_restart",
			60,
			translate("Restart after remote ping timeout") },
		{ Flag,
			"ping_timer_rem",
			0,
			translate("Only process ping timeouts if routes exist") },
		{ Flag,
			"persist_tun",
			0,
			translate("Keep tun/tap device open on restart") },
		{ Flag,
			"persist_key",
			0,
			translate("Don't re-read key on restart") },
		{ Flag,
			"persist_local_ip",
			0,
			translate("Keep local IP address on restart") },
		{ Flag,
			"persist_remote_ip",
			0,
			translate("Keep remote IP address on restart") },
	-- management channel
		{ Value,
			"management",
			"127.0.0.1 31194 /etc/openvpn/mngmt-pwds",
			translate("Enable management interface on <em>IP</em> <em>port</em>") },
	-- management
		{ Flag,
			"management_query_passwords",
			0,
			translate("Query management channel for private key") },
	-- management
		{ Flag,
			"management_hold",
			0,
			translate("Start OpenVPN in a hibernating state") },
	-- management
		{ Value,
			"management_log_cache",
			100,
			translate("Number of lines for log file history") },
		{ ListValue,
			"topology",
			{ "net30", "p2p", "subnet" },
			translate("'net30', 'p2p', or 'subnet'"),
			{dev_type="tun" } },
	} },

	{ "vpn", translate("VPN"), {
		{ Value,
			"server",
			"10.200.200.0 255.255.255.0",
			translate("Configure server mode"),
			{ client="0" }, { client="" } },
		{ Value,
			"server_bridge",
			"10.200.200.1 255.255.255.0 10.200.200.200 10.200.200.250",
			translate("Configure server bridge"),
			{ client="0" }, { client="" } },
		{ DynamicList,
			"push",
			{ "redirect-gateway", "comp-lzo" },
			translate("Push options to peer"),
			{ client="0" }, { client="" } },
		{ Flag,
			"push_reset",
			0,
			translate("Don't inherit global push options"),
			{ client="0" }, { client="" } },
		{ Flag,
			"disable",
			0,
			translate("Client is disabled"),
			{ client="0" }, { client="" } },
		{ Value,
			"ifconfig_pool",
			"10.200.200.100 10.200.200.150 255.255.255.0",
			translate("Set aside a pool of subnets"),
			{ client="0" }, { client="" } },
		{ Value,
			"ifconfig_pool_persist",
			"/etc/openvpn/ipp.txt 600",
			translate("Persist/unpersist ifconfig-pool"),
			{ client="0" }, { client="" } },
		{ Value,
			"ifconfig_push",
			"10.200.200.1 255.255.255.255",
			translate("Push an ifconfig option to remote"),
			{ client="0" }, { client="" } },
		{ Value,
			"iroute",
			"10.200.200.0 255.255.255.0",
			translate("Route subnet to client"),
			{ client="0" }, { client="" } },
		{ Flag,
			"client_to_client",
			0,
			translate("Allow client-to-client traffic"),
			{ client="0" }, { client="" } },
		{ Flag,
			"duplicate_cn",
			0,
			translate("Allow multiple clients with same certificate"),
			{ client="0" }, { client="" } },
		{ Value,
			"client_config_dir",
			"/etc/openvpn/ccd",
			translate("Directory for custom client config files"),
			{ client="0" }, { client="" } },
		{ Flag,
			"ccd_exclusive",
			0,
			translate("Refuse connection if no custom client config"),
			{ client="0" }, { client="" } },
		{ Value,
			"tmp_dir",
			"/var/run/openvpn",
			translate("Temporary directory for client-connect return file"),
			{ client="0" }, { client="" } },
		{ Value,
			"hash_size",
			"256 256",
			translate("Set size of real and virtual address hash tables"),
			{ client="0" }, { client="" } },
		{ Value,
			"bcast_buffers",
			256,
			translate("Number of allocated broadcast buffers"),
			{ client="0" }, { client="" } },
		{ Value,
			"tcp_queue_limit",
			64,
			translate("Maximum number of queued TCP output packets"),
			{ client="0" }, { client="" } },
		{ Value,
			"max_clients",
			10,
			translate("Allowed maximum of connected clients"),
			{ client="0" }, { client="" } },
		{ Value,
			"max_routes_per_client",
			256,
			translate("Allowed maximum of internal"),
			{ client="0" }, { client="" } },
		{ Value,
			"connect_freq",
			"3 10",
			translate("Allowed maximum of new connections"),
			{ client="0" }, { client="" } },
		{ Flag,
			"username_as_common_name",
			0,
			translate("Use username as common name"),
			{ client="0" }, { client="" } },
		{ Flag,
			"client",
			0,
			translate("Configure client mode") },
		{ Flag,
			"pull",
			0,
			translate("Accept options pushed from server"),
			{ client="1" } },
		{ FileUpload,
			"auth_user_pass",
			"/etc/openvpn/userpass.txt",
			translate("Authenticate using username/password"),
			{ client="1" } },
		{ ListValue,
			"auth_retry",
			{ "none", "nointeract", "interact" },
			translate("Handling of authentication failures"),
			{ client="1" } },
		{ Value,
			"explicit_exit_notify",
			1,
			translate("Send notification to peer on disconnect"),
			{ client="1" } },
		{ DynamicList,
			"remote",
			"1.2.3.4",
			translate("Remote host name or IP address") },
		{ Flag,
			"remote_random",
			0,
			translate("Randomly choose remote server"),
			{ client="1" } },
		{ ListValue,
			"proto",
			{ "udp", "tcp-client", "tcp-server" },
			translate("Use protocol"),
			{ client="1" } },
		{ Value,
			"connect_retry",
			5,
			translate("Connection retry interval"),
			{ proto="tcp-client" }, { client="1" } },
		{ Value,
			"http_proxy",
			"192.168.1.100 8080",
			translate("Connect to remote host through an HTTP proxy"),
			{ client="1" } },
		{ Flag,
			"http_proxy_retry",
			0,
			translate("Retry indefinitely on HTTP proxy errors"),
			{ client="1" } },
		{ Value,
			"http_proxy_timeout",
			5,
			translate("Proxy timeout in seconds"),
			{ client="1" } },
		{ DynamicList,
			"http_proxy_option",
			{ "VERSION 1.0", "AGENT OpenVPN/2.0.9" },
			translate("Set extended HTTP proxy options"),
			{ client="1" } },
		{ Value,
			"socks_proxy",
			"192.168.1.200 1080",
			translate("Connect through Socks5 proxy"),
			{ client="1" } },
	-- client && socks_proxy
		{ Value,
			"socks_proxy_retry",
			5,
			translate("Retry indefinitely on Socks proxy errors"),
			{ client="1" } },
		{ Value,
			"resolv_retry",
			"infinite",
			translate("If hostname resolve fails, retry"),
			{ client="1" } },
		{ ListValue,
			"redirect_gateway",
			{ "", "local", "def1", "local def1" },
			translate("Automatically redirect default route"),
			{ client="1" } },
		{ Value,
			"verify_client_cert",
			{  "none", "optional", "require" },
			translate("Specify whether the client is required to supply a valid certificate") },
	} },

	{ "cryptography", translate("Cryptography"), {
		{ FileUpload,
			"secret",
			"/etc/openvpn/secret.key",
			translate("Enable Static Key encryption mode (non-TLS)") },
	-- parse
		{ Value,
			"auth",
			"SHA1",
			translate("HMAC authentication for packets") },
	-- parse
		{ Value,
			"cipher",
			{
				"AES-128-CBC",
				"AES-128-CFB",
				"AES-128-CFB1",
				"AES-128-CFB8",
				"AES-128-GCM",
				"AES-128-OFB",
				"AES-192-CBC",
				"AES-192-CFB",
				"AES-192-CFB1",
				"AES-192-CFB8",
				"AES-192-GCM",
				"AES-192-OFB",
				"AES-256-CBC",
				"AES-256-CFB",
				"AES-256-CFB1",
				"AES-256-CFB8",
				"AES-256-GCM",
				"AES-256-OFB",
				"BF-CBC",
				"BF-CFB",
				"BF-OFB",
				"CAST5-CBC",
				"CAST5-CFB",
				"CAST5-OFB",
				"DES-CBC",
				"DES-CFB",
				"DES-CFB1",
				"DES-CFB8",
				"DES-EDE-CBC",
				"DES-EDE-CFB",
				"DES-EDE-OFB",
				"DES-EDE3-CBC",
				"DES-EDE3-CFB",
				"DES-EDE3-CFB1",
				"DES-EDE3-CFB8",
				"DES-EDE3-OFB",
				"DES-OFB",
				"DESX-CBC",
				"RC2-40-CBC",
				"RC2-64-CBC",
				"RC2-CBC",
				"RC2-CFB",
				"RC2-OFB"
			},
			translate("Encryption cipher for packets") },
	-- parse
		{ Value,
			"keysize",
			1024,
			translate("Size of cipher key") },
	-- parse
		{ Value,
			"engine",
			"dynamic",
			translate("Enable OpenSSL hardware crypto engines") },
		{ Value,
			"replay_window",
			"64 15",
			translate("Replay protection sliding window size") },
		{ Flag,
			"mute_replay_warnings",
			0,
			translate("Silence the output of replay warnings") },
		{ Value,
			"replay_persist",
			"/var/run/openvpn-replay-state",
			translate("Persist replay-protection state") },
		{ Flag,
			"tls_server",
			0,
			translate("Enable TLS and assume server role"),
			{ tls_client="" }, { tls_client="0" } },
		{ Flag,
			"tls_client",
			0,
			translate("Enable TLS and assume client role"),
			{ tls_server="" }, { tls_server="0" } },
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
		{ FileUpload,
			"pkcs12",
			"/etc/easy-rsa/keys/some-client.pk12",
			translate("PKCS#12 file containing keys") },
		{ ListValue,
			"key_method",
			{ 1, 2 },
			translate("Enable TLS and assume client role") },
		{ DynamicList,
			"tls_cipher",
			{
				"TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384",
				"TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384",
				"TLS-DHE-RSA-WITH-AES-256-GCM-SHA384",
				"TLS-ECDHE-ECDSA-WITH-CHACHA20-POLY1305-SHA256",
				"TLS-ECDHE-RSA-WITH-CHACHA20-POLY1305-SHA256",
				"TLS-DHE-RSA-WITH-CHACHA20-POLY1305-SHA256",
				"TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256",
				"TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256",
				"TLS-DHE-RSA-WITH-AES-128-GCM-SHA256",
				"TLS-ECDHE-ECDSA-WITH-AES-256-CBC-SHA384",
				"TLS-ECDHE-RSA-WITH-AES-256-CBC-SHA384",
				"TLS-DHE-RSA-WITH-AES-256-CBC-SHA256",
				"TLS-ECDHE-ECDSA-WITH-AES-128-CBC-SHA256",
				"TLS-ECDHE-RSA-WITH-AES-128-CBC-SHA256",
				"TLS-DHE-RSA-WITH-AES-128-CBC-SHA256",
				"TLS-ECDHE-ECDSA-WITH-AES-256-CBC-SHA",
				"TLS-ECDHE-RSA-WITH-AES-256-CBC-SHA",
				"TLS-DHE-RSA-WITH-AES-256-CBC-SHA",
				"TLS-ECDHE-ECDSA-WITH-AES-128-CBC-SHA",
				"TLS-ECDHE-RSA-WITH-AES-128-CBC-SHA",
				"TLS-DHE-RSA-WITH-AES-128-CBC-SHA"
			},
			translate("TLS cipher") },
		{ DynamicList,
			"tls_ciphersuites",
			{
				"TLS_AES_256_GCM_SHA384",
				"TLS_AES_128_GCM_SHA256",
				"TLS_CHACHA20_POLY1305_SHA256"
			},
			translate("TLS 1.3 or newer cipher") },
		{ Value,
			"tls_timeout",
			2,
			translate("Retransmit timeout on TLS control channel") },
		{ Value,
			"reneg_bytes",
			1024,
			translate("Renegotiate data chan. key after bytes") },
		{ Value,
			"reneg_pkts",
			100,
			translate("Renegotiate data chan. key after packets") },
		{ Value,
			"reneg_sec",
			3600,
			translate("Renegotiate data chan. key after seconds") },
		{ Value,
			"hand_window",
			60,
			translate("Timeframe for key exchange") },
		{ Value,
			"tran_window",
			3600,
			translate("Key transition window") },
		{ Flag,
			"single_session",
			0,
			translate("Allow only one session") },
		{ Flag,
			"tls_exit",
			0,
			translate("Exit on TLS negotiation failure") },
		{ Value,
			"tls_auth",
			"/etc/openvpn/tlsauth.key",
			translate("Additional authentication over TLS") },
		{ Value,
			"tls_crypt",
			"/etc/openvpn/tlscrypt.key",
			translate("Encrypt and authenticate all control channel packets with the key") },
	--	{ Value,
	--		"askpass",
	--		"[file]",
	--		translate("Get PEM password from controlling tty before we daemonize") },
		{ Flag,
			"auth_nocache",
			0,
			translate("Don't cache --askpass or --auth-user-pass passwords") },
		{ Value,
			"tls_remote",
			"remote_x509_name",
			translate("Only accept connections from given X509 name") },
		{ ListValue,
			"ns_cert_type",
			{ "client", "server" },
			translate("Require explicit designation on certificate") },
		{ ListValue,
			"remote_cert_tls",
			{ "client", "server" },
			translate("Require explicit key usage on certificate") },
		{ Value,
			"crl_verify",
			"/etc/easy-rsa/keys/crl.pem",
			translate("Check peer certificate against a CRL") },
		{ Value,
			"tls_version_min",
			"1.0",
			translate("The lowest supported TLS version") },
		{ Value,
			"tls_version_max",
			"1.2",
			translate("The highest supported TLS version") },
		{ ListValue,
			"key_direction",
			{ 0, 1 },
			translate("The key direction for 'tls-auth' and 'secret' options") },
		{ Flag,
			"ncp_disable",
			0,
			translate("This completely disables cipher negotiation") },
		{ Value,
			"ncp_ciphers",
			"AES-256-GCM:AES-128-GCM",
			translate("Restrict the allowed ciphers to be negotiated") },
	} }
}


local cts = { }
local params = { }
local title = ""

local m = Map("openvpn")
m.redirect = luci.dispatcher.build_url("admin", "services", "openvpn")
m.apply_on_parse = true

local p = m:section( SimpleSection )
p.template = "openvpn/pageswitch"
p.mode     = "advanced"
p.instance = arg[1]
p.category = arg[2] or knownParams[1][1]

for _, c in ipairs(knownParams) do
	cts[#cts+1] = { id = c[1], title = c[2] }
	if c[1] == p.category then
		title = c[2]
		params = c[3]
	end
end

p.categories = cts


local s = m:section(
	NamedSection, arg[1], "openvpn", title
)
s.template = "openvpn/nsection"

s.addremove = false
s.anonymous = true


for _, option in ipairs(params) do
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
EOF_OPENVPN_ADVANCED_MODEL

}
fix_openvpn_luci_compat() {
    for f in \
        /usr/lib/lua/luci/controller/openvpn.lua \
        /usr/lib/lua/luci/model/cbi/openvpn.lua \
        /usr/lib/lua/luci/model/cbi/openvpn-basic.lua \
        /usr/lib/lua/luci/model/cbi/openvpn-advanced.lua \
        /usr/lib/lua/luci/view/openvpn/pageswitch.htm \
        /usr/lib/lua/luci/view/openvpn/cbi-select-input-add.htm; do
        [ -f "$f" ] || continue
        backup_file "$f"
        sed -i \
            -e 's/"vpn", "openvpn"/"services", "openvpn"/g' \
            -e 's#admin/vpn/openvpn#admin/services/openvpn#g' \
            "$f"
    done

    if [ -f /usr/lib/lua/luci/view/openvpn/cbi-select-input-add.htm ]; then
        sed -i 's/luci.xml.pcdata(v)/pcdata(v)/g' /usr/lib/lua/luci/view/openvpn/cbi-select-input-add.htm
    fi
}

install_openvpn_core() {
    ensure_default_feeds
    mkdir -p "$WORKDIR/openvpn/core"

    openvpn_core_ipk="$WORKDIR/openvpn/core/openvpn-openssl.ipk"
    liblzo2_ipk="$WORKDIR/openvpn/core/liblzo2.ipk"
    liblzo2_fixed_ipk="$WORKDIR/openvpn/core/liblzo2-fixed.ipk"
    openvpn_core_fixed_ipk="$WORKDIR/openvpn/core/openvpn-openssl-fixed.ipk"
    kmod_tun_ipk="$WORKDIR/openvpn/core/kmod-tun.ipk"
    kmod_tun_fixed_ipk="$WORKDIR/openvpn/core/kmod-tun-fixed.ipk"
    target_arch="$(get_primary_arch)"

    [ -n "$target_arch" ] || die "OpenVPN 核心预检查失败：无法识别当前 opkg 架构"

    if [ ! -e /usr/lib/libssl.so.1.1 ] || [ ! -e /usr/lib/libcrypto.so.1.1 ]; then
        die "OpenVPN 核心预检查失败：系统缺少 libopenssl1.1，请先修复 SSL 库"
    fi

    if [ ! -e /dev/net/tun ] && [ ! -e /sys/module/tun ] && ! opkg status kmod-tun >/dev/null 2>&1; then
        log "提示: 正在从软件源下载 OpenVPN 依赖 kmod-tun..."
        kmod_tun_url="$(resolve_package_url_any_feed kmod-tun 2>/dev/null || true)"
        [ -n "$kmod_tun_url" ] || { sed -n '1,80p' "$FEEDS" >&2; die "无法从当前软件源解析 kmod-tun"; }
        download_file "$kmod_tun_url" "$kmod_tun_ipk" || die "下载 kmod-tun 安装包失败"
        repack_ipk_control "$kmod_tun_ipk" "$kmod_tun_fixed_ipk" "$target_arch" "kernel"
        install_ipk_file "$kmod_tun_fixed_ipk" "OpenVPN kmod-tun"
    fi

    if [ ! -e /usr/lib/liblzo2.so.2 ] || ! opkg status liblzo2 >/dev/null 2>&1; then
        log "提示: 正在从软件源下载 OpenVPN 依赖 liblzo2..."
        liblzo2_url="$(resolve_package_url_any_feed liblzo2 2>/dev/null || true)"
        [ -n "$liblzo2_url" ] || { sed -n '1,80p' "$FEEDS" >&2; die "无法从当前软件源解析 liblzo2"; }
        download_file "$liblzo2_url" "$liblzo2_ipk" || die "下载 liblzo2 安装包失败"
        repack_ipk_control "$liblzo2_ipk" "$liblzo2_fixed_ipk" "$target_arch" "libc"
        install_ipk_file "$liblzo2_fixed_ipk" "OpenVPN liblzo2"
    fi

    log "提示: 正在从软件源下载 OpenVPN 核心..."
    openvpn_core_url="$(resolve_package_url_any_feed openvpn-openssl 2>/dev/null || true)"
    [ -n "$openvpn_core_url" ] || { sed -n '1,80p' "$FEEDS" >&2; die "无法从当前软件源解析 openvpn-openssl"; }
    download_file "$openvpn_core_url" "$openvpn_core_ipk" || die "下载 openvpn-openssl 安装包失败"
    repack_ipk_control "$openvpn_core_ipk" "$openvpn_core_fixed_ipk" "$target_arch" "libc"
    if ! opkg install "$openvpn_core_fixed_ipk" >/tmp/openvpn-core-install.log 2>&1; then
        if [ -c /dev/net/tun ] || [ -e /sys/module/tun ]; then
            opkg install "$openvpn_core_fixed_ipk" --force-depends >/tmp/openvpn-core-install.log 2>&1 || {
                sed -n '1,200p' /tmp/openvpn-core-install.log >&2
                die "openvpn-openssl 安装失败"
            }
        else
            sed -n '1,200p' /tmp/openvpn-core-install.log >&2
            die "openvpn-openssl 安装失败，可能缺少 tun 支持"
        fi
    fi

    opkg status openvpn-openssl >/dev/null 2>&1 || die "OpenVPN 核心校验失败：缺少 openvpn-openssl"
    if [ ! -e /dev/net/tun ] && [ ! -e /sys/module/tun ]; then
        opkg status kmod-tun >/dev/null 2>&1 || die "OpenVPN 核心校验失败：缺少 tun 驱动"
    fi
    command -v openvpn >/dev/null 2>&1 || [ -x /usr/sbin/openvpn ] || die "OpenVPN 核心校验失败：缺少 openvpn 二进制"
}

install_openvpn() {
    require_nradio_oem_appcenter

    log_stage 1 5 "准备 OpenVPN 软件源与安装来源"
    log "下一步将下载 OpenVPN 核心/LuCI 包并修改 /etc/config/appcenter, $TPL 和 OpenVPN OEM 文件"
    confirm_or_exit "确认继续安装 OpenVPN 并修改系统吗？"
    ensure_default_feeds

    mkdir -p "$WORKDIR/openvpn/pkg" "$WORKDIR/openvpn/data"
    ovpn_ipk="$WORKDIR/openvpn/luci-app-openvpn.ipk"
    log_stage 2 5 "下载 OpenVPN LuCI 包与核心依赖"
    log "提示: 正在从软件源下载 OpenVPN LuCI 包..."
    ovpn_meta="$(resolve_package_meta_any_feed luci-app-openvpn 2>/dev/null || true)"
    [ -n "$ovpn_meta" ] || { sed -n '1,80p' "$FEEDS" >&2; die "无法从当前软件源解析 OpenVPN LuCI 安装包"; }
    ovpn_feed_name="${ovpn_meta%%|*}"
    ovpn_meta_rest="${ovpn_meta#*|}"
    ovpn_feed_url="${ovpn_meta_rest%%|*}"
    ovpn_meta_rest="${ovpn_meta_rest#*|}"
    ovpn_filename="${ovpn_meta_rest%%|*}"
    ovpn_meta_version="${ovpn_meta_rest##*|}"
    ovpn_package_urls="$(build_package_download_urls_from_meta "$ovpn_feed_url" "$ovpn_filename" 2>/dev/null || true)"
    [ -n "$ovpn_package_urls" ] || die "无法生成 OpenVPN LuCI 下载地址"
    log "提示: OpenVPN LuCI 当前解析源: $ovpn_feed_name"
    download_from_urls "$ovpn_ipk" $ovpn_package_urls || die "下载 OpenVPN LuCI 安装包失败"
    ovpn_download_url="$LAST_DOWNLOAD_SOURCE"
    [ -n "$OPENVPN_VERSION" ] || OPENVPN_VERSION="$ovpn_meta_version"
    [ -n "$OPENVPN_VERSION" ] || OPENVPN_VERSION="$(resolve_package_version_any_feed luci-app-openvpn 2>/dev/null || true)"
    ovpn_download_size="$(wc -c < "$ovpn_ipk" | tr -d ' ')"
    log "已下载: OpenVPN LuCI $OPENVPN_VERSION ($ovpn_download_size bytes)"
    [ -n "${ovpn_download_url:-}" ] && log "来源:    $(extract_url_host "$ovpn_download_url" 2>/dev/null || printf '%s' "$ovpn_download_url")"

    install_openvpn_core

    log_stage 3 5 "解包官方 LuCI 文件并部署"
    extract_ipk_archive "$ovpn_ipk" "$WORKDIR/openvpn/pkg"
    [ -f "$WORKDIR/openvpn/pkg/data.tar.gz" ] || die "OpenVPN LuCI 安装包缺少 data.tar.gz"
    [ -f "$WORKDIR/openvpn/pkg/control.tar.gz" ] || die "OpenVPN LuCI 安装包缺少 control.tar.gz"
    tar -xzf "$WORKDIR/openvpn/pkg/data.tar.gz" -C "$WORKDIR/openvpn/data" >/dev/null 2>&1 || die "解压 OpenVPN LuCI 内容失败"

    for needed in \
        usr/lib/lua/luci/controller/openvpn.lua \
        usr/lib/lua/luci/model/cbi/openvpn.lua \
        usr/lib/lua/luci/model/cbi/openvpn-basic.lua \
        usr/lib/lua/luci/model/cbi/openvpn-advanced.lua \
        usr/lib/lua/luci/model/cbi/openvpn-file.lua \
        usr/lib/lua/luci/view/openvpn/pageswitch.htm \
        usr/lib/lua/luci/view/openvpn/cbi-select-input-add.htm; do
        [ -f "$WORKDIR/openvpn/data/$needed" ] || die "OpenVPN LuCI 安装包不完整，缺少 $needed"
    done

    backup_file /usr/lib/lua/luci/controller/openvpn.lua
    backup_file /usr/lib/lua/luci/model/cbi/openvpn.lua
    backup_file /usr/lib/lua/luci/model/cbi/openvpn-basic.lua
    backup_file /usr/lib/lua/luci/model/cbi/openvpn-advanced.lua
    backup_file /usr/lib/lua/luci/model/cbi/openvpn-file.lua
    backup_file /usr/lib/lua/luci/view/openvpn/ovpn_css.htm
    backup_file /usr/lib/lua/luci/view/openvpn/pageswitch.htm
    backup_file /usr/lib/lua/luci/view/openvpn/cbi-select-input-add.htm
    backup_file /usr/lib/lua/luci/view/openvpn/overview_intro.htm
    backup_file /usr/lib/lua/luci/view/openvpn/nsection.htm
    backup_file /usr/lib/lua/luci/controller/nradio_adv/openvpn_full.lua
    backup_file /usr/lib/lua/luci/view/nradio_adv/openvpn_full.htm

    cp -rf "$WORKDIR/openvpn/data/etc" / >/dev/null 2>&1 || true
    cp -rf "$WORKDIR/openvpn/data/usr" / >/dev/null 2>&1 || true

    write_openvpn_custom_ui_files
    fix_openvpn_luci_compat

    log_stage 4 5 "写入图标、应用商店与 OEM 集成"
    ovpn_size="$(wc -c < "$ovpn_ipk" | tr -d ' ')"
    backup_file "$CFG"
    openvpn_icon_name=""
    if install_openvpn_embedded_icon; then
        openvpn_icon_name="$OPENVPN_ICON_NAME"
    fi
    set_appcenter_entry "OpenVPN" "luci-app-openvpn" "$OPENVPN_VERSION" "$ovpn_size" "/usr/lib/lua/luci/controller/nradio_adv/openvpn_full.lua" "nradioadv/system/openvpnfull" "$openvpn_icon_name"
    uci commit appcenter

    write_plugin_uninstall_assets
    patch_common_template
    refresh_luci_appcenter
    log_stage 5 5 "写入虚拟内存并校验 OpenVPN 界面文件与 LuCI 路由"
    ensure_existing_swap_access "OpenVPN"
    verify_appcenter_route "OpenVPN" "nradioadv/system/openvpnfull"
    for openvpn_ui_file in \
        /usr/lib/lua/luci/controller/nradio_adv/openvpn_full.lua \
        /usr/lib/lua/luci/view/nradio_adv/openvpn_full.htm \
        /usr/lib/lua/luci/view/openvpn/ovpn_css.htm \
        /usr/lib/lua/luci/view/openvpn/pageswitch.htm \
        /usr/lib/lua/luci/view/openvpn/cbi-select-input-add.htm \
        /usr/lib/lua/luci/view/openvpn/overview_intro.htm \
        /usr/lib/lua/luci/view/openvpn/nsection.htm \
        /usr/lib/lua/luci/model/cbi/openvpn.lua \
        /usr/lib/lua/luci/model/cbi/openvpn-file.lua \
        /usr/lib/lua/luci/model/cbi/openvpn-basic.lua \
        /usr/lib/lua/luci/model/cbi/openvpn-advanced.lua; do
        verify_file_exists "$openvpn_ui_file" "OpenVPN"
    done
    verify_luci_route admin/services/openvpn "OpenVPN"
    verify_luci_route nradioadv/system/openvpnfull "OpenVPN"

    log "安装完成"
    log "插件:   OpenVPN"
    log "版本:  $OPENVPN_VERSION"
    log "路由:    nradioadv/system/openvpnfull"
    log "备注:     OpenVPN 核心与 LuCI 页面已安装，OEM 应用商店兼容页已接入"
    log "下一步: 关闭应用商店弹窗后按 Ctrl+F5，再重新打开 OpenVPN"
}

configure_openvpn_runtime() {
    ovpn_dst="/etc/openvpn/client.ovpn"
    auth_dst="/etc/openvpn/auth.txt"
    hotplug_src="/etc/hotplug.d/iface/99-openvpn-route"
    hotplug_dst="/etc/hotplug.d/openvpn/99-openvpn-route"
    ca_tmp="$WORKDIR/openvpn-wizard-ca.crt"
    cert_tmp="$WORKDIR/openvpn-wizard-client.crt"
    key_tmp="$WORKDIR/openvpn-wizard-client.key"
    ta_tmp="$WORKDIR/openvpn-wizard-ta.key"
    extra_tmp="$WORKDIR/openvpn-wizard-extra.conf"

    command -v openvpn >/dev/null 2>&1 || [ -x /usr/sbin/openvpn ] || die "OpenVPN core not installed; run option 8 first"

    mkdir -p "$WORKDIR" /etc/openvpn /etc/hotplug.d/openvpn

    if [ -f "$ovpn_dst" ] && confirm_default_yes '检测到现有 OpenVPN 配置，是否直接复用当前配置并重启？'; then
        ensure_openvpn_profile_safety_flags "$ovpn_dst"
        /etc/init.d/openvpn enable >/dev/null 2>&1 || true
        /etc/init.d/openvpn restart >/tmp/openvpn-runtime-fix.log 2>&1 || true
        sleep 10
        if [ -f "$hotplug_dst" ]; then
            ACTION=up sh "$hotplug_dst" >/tmp/openvpn-route-apply.log 2>&1 || true
        fi
        tun_line="$(ip addr show tun0 2>/dev/null | grep -m1 'inet ' || true)"
        if [ -n "$tun_line" ]; then
            synthesize_openvpn_runtime_state_from_current_profile
            log "安装完成"
            log "插件:   OpenVPN runtime"
            log "profile:  $ovpn_dst"
            log "status:   $(/etc/init.d/openvpn status 2>/dev/null || true)"
            log "tun0:     $tun_line"
            log "备注:     reused current profile"
            return 0
        fi
        print_openvpn_runtime_debug
        log 'warn: current profile restart did not establish tun0, continue into wizard to rewrite the profile'
    fi

    load_openvpn_runtime_state
    load_openvpn_runtime_defaults_from_profile

    ovpn_verify_cn='0'
    ovpn_server_cn=''
    ovpn_key_direction='1'
    ovpn_user=''

    printf '服务器域名: '
    ui_read_line || die "input cancelled"
    ovpn_server="$UI_READ_RESULT"
    [ -n "$ovpn_server" ] || die "server domain is required"
    case "$ovpn_server" in
        *[,，]* ) die "server domain format invalid: do not use commas" ;;
        *[[:space:]]*) die "server domain must not contain spaces" ;;
    esac

    prompt_with_default '端口号' "${OVPN_PORT:-1194}"
    ovpn_port="$PROMPT_RESULT"
    case "$ovpn_port" in
        *[!0-9]*|'') die "port must be numeric" ;;
    esac
    [ "$ovpn_port" -ge 1 ] && [ "$ovpn_port" -le 65535 ] || die "port must be between 1 and 65535"

    prompt_with_default '协议类型 tcp 还是 udp' "${OVPN_TRANSPORT:-udp}"
    ovpn_transport="$PROMPT_RESULT"
    [ "$ovpn_transport" = 'upd' ] && ovpn_transport='udp'
    case "$ovpn_transport" in
        tcp|TCP) ovpn_transport='tcp' ;;
        udp|UDP) ovpn_transport='udp' ;;
        *) die "protocol must be tcp or udp" ;;
    esac

    prompt_with_default 'IP 版本 ipv4 还是 ipv6' "${OVPN_FAMILY:-ipv6}"
    ovpn_family="$PROMPT_RESULT"
    case "$ovpn_family" in
        ipv4|4)
            ovpn_family='ipv4'
            if [ "$ovpn_transport" = 'tcp' ]; then
                ovpn_proto='tcp4-client'
            else
                ovpn_proto='udp4'
            fi
            ;;
        ipv6|6)
            ovpn_family='ipv6'
            if [ "$ovpn_transport" = 'tcp' ]; then
                ovpn_proto='tcp6-client'
            else
                ovpn_proto='udp6'
            fi
            ;;
        *)
            die "IP family must be ipv4 or ipv6"
            ;;
    esac

    ovpn_server_is_domain='1'
    if normalize_ipv4_host "$ovpn_server" >/dev/null 2>&1; then
        ovpn_server_is_domain='0'
    elif printf '%s\n' "$ovpn_server" | awk '
        {
            host = $0
            gsub(/^\[/, "", host)
            gsub(/\]$/, "", host)
            if (host ~ /^[0-9A-Fa-f:]+$/ && index(host, ":") > 0) {
                exit 0
            }
            exit 1
        }
    '; then
        ovpn_server_is_domain='0'
    fi
    ovpn_pin_remote='0'
    ovpn_dnsmasq_sync='0'
    [ "$ovpn_server_is_domain" = '1' ] && ovpn_dnsmasq_sync='1'
    resolved_ip_list="$(resolve_host_records "$ovpn_server" "$ovpn_family" 2>/dev/null || true)"
    resolved_ip="$(printf '%s\n' "$resolved_ip_list" | sed -n '1p')"
    [ -n "$resolved_ip" ] || die "server resolve failed: $ovpn_server has no usable $ovpn_family record"
    ovpn_remote_entries="remote $ovpn_server $ovpn_port"

    prompt_with_default '是否开启 lzo 压缩？(y/n)' "${OVPN_LZO:-n}"
    ovpn_lzo="$PROMPT_RESULT"
    case "$ovpn_lzo" in
        y|Y|yes|YES) ovpn_lzo='1' ;;
        n|N|no|NO) ovpn_lzo='0' ;;
        *) die "lzo choice must be y or n" ;;
    esac

    prompt_with_default '加密协议是什么？' "${OVPN_CIPHER:-AES-256-GCM}"
    ovpn_cipher="$PROMPT_RESULT"

    prompt_with_default 'MTU 值' "${OVPN_MTU:-1400}"
    ovpn_mtu="$PROMPT_RESULT"
    case "$ovpn_mtu" in
        *[!0-9]*|'') die "MTU must be numeric" ;;
    esac
    [ "$ovpn_mtu" -ge 576 ] && [ "$ovpn_mtu" -le 9000 ] || die "MTU must be between 576 and 9000"

    prompt_with_default '认证摘要算法（auth）是什么？' "${OVPN_AUTH_DIGEST:-}"
    ovpn_auth_digest="$PROMPT_RESULT"

    printf '提示: 如果你还不确定服务端要求什么，建议先选 1（仅用户名密码）验证是否能连通。\n'
    prompt_with_default '认证方式 [1=仅用户名密码, 2=仅客户端证书/私钥, 3=用户名密码+客户端证书/私钥]' "${OVPN_AUTH_MODE:-1}"
    ovpn_auth_mode="$PROMPT_RESULT"
    case "$ovpn_auth_mode" in
        1)
            ovpn_auth='1'
            ovpn_cert_auth='0'
            ;;
        2)
            ovpn_auth='0'
            ovpn_cert_auth='1'
            ;;
        3)
            ovpn_auth='1'
            ovpn_cert_auth='1'
            ;;
        *)
            die "auth mode must be 1, 2 or 3"
            ;;
    esac

    if [ "$ovpn_auth" = '1' ]; then
        if [ -f "$auth_dst" ] && confirm_default_yes '检测到现有账号文件，是否直接复用当前用户名密码？'; then
            ovpn_user="$(sed -n '1p' "$auth_dst" 2>/dev/null || true)"
            ovpn_pass="$(sed -n '2p' "$auth_dst" 2>/dev/null || true)"
        else
            prompt_with_default '用户名' "${OVPN_USER:-}"
            ovpn_user="$PROMPT_RESULT"
            printf '密码: '
            ui_read_secret || die "input cancelled"
            ovpn_pass="$UI_READ_RESULT"
        fi
        [ -n "$ovpn_user" ] || die "username is required"
        [ -n "$ovpn_pass" ] || die "password is required"
    fi

    if [ "$ovpn_cert_auth" = '1' ]; then
        printf '注意: 只有你手里明确有客户端证书/客户端私钥（通常类似 client.crt / client.key）时，才应该选择包含客户端证书的认证方式。\n'
    fi

    prompt_with_default '服务端证书校验模式 [1=兼容模式(CA校验), 2=严格模式(remote-cert-tls server)]' "${OVPN_SERVER_VERIFY:-1}"
    ovpn_server_verify="$PROMPT_RESULT"
    case "$ovpn_server_verify" in
        1)
            ovpn_server_verify='compat'
            ;;
        2)
            ovpn_server_verify='strict'
            ;;
        *)
            die "server verify mode must be 1 or 2"
            ;;
    esac

    ovpn_verify_cn='0'
    ovpn_server_cn=''
    if [ "$ovpn_server_verify" = 'compat' ]; then
        prompt_with_default '是否额外校验服务端证书 CN？(y/n)' "${OVPN_VERIFY_CN:-n}"
        ovpn_verify_cn="$PROMPT_RESULT"
        case "$ovpn_verify_cn" in
            y|Y|yes|YES)
                ovpn_verify_cn='1'
                prompt_with_default '服务端证书 CN（仅填写名称，不要粘贴证书内容；例如 iKuai OpenVPN Server）' "${OVPN_SERVER_CN:-}"
                ovpn_server_cn="$PROMPT_RESULT"
                [ -n "$ovpn_server_cn" ] || die "server certificate CN is required"
                case "$ovpn_server_cn" in
                    *BEGIN\ CERTIFICATE*|*END\ CERTIFICATE*)
                        die "server certificate CN must be a short name only; do not paste certificate content"
                        ;;
                esac
                ;;
            n|N|no|NO)
                ovpn_verify_cn='0'
                ;;
            *)
                die "CN verify choice must be y or n"
                ;;
        esac
    fi

    prompt_with_default '是否使用 tls-auth 或 tls-crypt 密钥？(n/auth/crypt)' "${OVPN_TLS_MODE:-n}"
    ovpn_tls_mode="$PROMPT_RESULT"
    case "$ovpn_tls_mode" in
        n|N|no|NO) ovpn_tls_mode='0' ;;
        auth|AUTH) ovpn_tls_mode='auth' ;;
        crypt|CRYPT) ovpn_tls_mode='crypt' ;;
        *) die "tls key mode must be n, auth or crypt" ;;
    esac

    printf '说明: CA 证书用于验证服务端；如果服务端要求双向证书认证，后面再填写客户端证书和客户端私钥。\n'
    : > "$ca_tmp"
    if [ -f "$RUNTIME_CA_FILE" ]; then
        cp "$RUNTIME_CA_FILE" "$ca_tmp"
    elif [ -f /etc/openvpn/client.ovpn ]; then
        extract_inline_block_to_file /etc/openvpn/client.ovpn ca "$ca_tmp"
    else
        printf '请粘贴 CA 证书内容（CA 用于验证服务端身份），结束请输入单独一行 EOF:\n'
        while IFS= read -r line; do
            [ "$line" = 'EOF' ] && break
            printf '%s\n' "$line" >> "$ca_tmp"
        done
    fi
    grep -q 'BEGIN CERTIFICATE' "$ca_tmp" || die "CA certificate format invalid"

    if [ "$ovpn_cert_auth" = '1' ]; then
        : > "$cert_tmp"
        if [ -f "$RUNTIME_CERT_FILE" ]; then
            cp "$RUNTIME_CERT_FILE" "$cert_tmp"
        elif [ -f /etc/openvpn/client.ovpn ]; then
            extract_inline_block_to_file /etc/openvpn/client.ovpn cert "$cert_tmp"
        else
            printf '请粘贴客户端证书内容（客户端身份认证证书，不是服务端证书），结束请输入单独一行 EOF:\n'
            while IFS= read -r line; do
                [ "$line" = 'EOF' ] && break
                printf '%s\n' "$line" >> "$cert_tmp"
            done
        fi
        grep -q 'BEGIN CERTIFICATE' "$cert_tmp" || die "client certificate format invalid"
        validate_client_certificate_if_possible "$cert_tmp"

        : > "$key_tmp"
        if [ -f "$RUNTIME_KEY_FILE" ]; then
            cp "$RUNTIME_KEY_FILE" "$key_tmp"
        elif [ -f /etc/openvpn/client.ovpn ]; then
            extract_inline_block_to_file /etc/openvpn/client.ovpn key "$key_tmp"
        else
            printf '请粘贴客户端私钥内容（与客户端证书对应的私钥），结束请输入单独一行 EOF:\n'
            while IFS= read -r line; do
                [ "$line" = 'EOF' ] && break
                printf '%s\n' "$line" >> "$key_tmp"
            done
        fi
        grep -Eq 'BEGIN (RSA )?PRIVATE KEY|BEGIN EC PRIVATE KEY' "$key_tmp" || die "client key format invalid"
        validate_client_cert_key_match_if_possible "$cert_tmp" "$key_tmp"
    fi

    if [ "$ovpn_tls_mode" != '0' ]; then
        if [ "$ovpn_tls_mode" = 'auth' ]; then
            prompt_with_default 'tls-auth 的 key-direction' "${OVPN_KEY_DIRECTION:-1}"
            ovpn_key_direction="$PROMPT_RESULT"
            case "$ovpn_key_direction" in
                0|1) ;;
                *) die "key-direction must be 0 or 1" ;;
            esac
        fi
        : > "$ta_tmp"
        if [ -f "$RUNTIME_TLS_FILE" ]; then
            cp "$RUNTIME_TLS_FILE" "$ta_tmp"
        elif [ -f /etc/openvpn/client.ovpn ]; then
            if [ "$ovpn_tls_mode" = 'auth' ]; then
                extract_inline_block_to_file /etc/openvpn/client.ovpn tls-auth "$ta_tmp"
            else
                extract_inline_block_to_file /etc/openvpn/client.ovpn tls-crypt "$ta_tmp"
            fi
        else
            printf '请粘贴 tls-auth/tls-crypt 密钥内容，结束请输入单独一行 EOF:\n'
            while IFS= read -r line; do
                [ "$line" = 'EOF' ] && break
                printf '%s\n' "$line" >> "$ta_tmp"
            done
        fi
        grep -q 'BEGIN OpenVPN Static key V1' "$ta_tmp" || die "tls-auth/tls-crypt key format invalid"
    fi

    prompt_with_default '是否需要追加额外 OpenVPN 指令？(y/n)' "${OVPN_EXTRA:-n}"
    ovpn_extra="$PROMPT_RESULT"
    case "$ovpn_extra" in
        y|Y|yes|YES)
            : > "$extra_tmp"
            if [ -f "$RUNTIME_EXTRA_FILE" ]; then
                cp "$RUNTIME_EXTRA_FILE" "$extra_tmp"
            else
                printf '请逐行粘贴额外指令，结束请输入单独一行 EOF:\n'
                while IFS= read -r line; do
                    [ "$line" = 'EOF' ] && break
                    printf '%s\n' "$line" >> "$extra_tmp"
                done
            fi
            ;;
        n|N|no|NO)
            ovpn_extra='0'
            ;;
        *)
            die "extra options choice must be y or n"
            ;;
    esac

    log "summary: OpenVPN profile will be written to $ovpn_dst"
    log "summary: server=$ovpn_server port=$ovpn_port proto=$ovpn_proto cipher=$ovpn_cipher mtu=$ovpn_mtu"
    if [ "$ovpn_dnsmasq_sync" = '1' ]; then
        log "summary: detected remote domain $ovpn_server; will try to write dnsmasq upstream rules so remote can remain domain-based"
        log "summary: if dnsmasq rule write fails, remote will fall back to upstream-resolved $ovpn_family address(es)"
    elif [ "$ovpn_pin_remote" = '1' ]; then
        log "summary: remote entries will be pinned to upstream-resolved $ovpn_family address(es) to avoid local fake-ip DNS interference"
        printf '%s\n' "$resolved_ip_list" | while IFS= read -r resolved_ip_item; do
            [ -n "$resolved_ip_item" ] || continue
            log "  - remote $resolved_ip_item $ovpn_port"
        done
    fi
    [ "$ovpn_server_verify" = 'strict' ] && log "summary: server cert verify=remote-cert-tls server"
    [ "$ovpn_verify_cn" = '1' ] && log "summary: verify-x509-name=$ovpn_server_cn"
    [ -n "$ovpn_auth_digest" ] && log "summary: auth=$ovpn_auth_digest"
    [ "$ovpn_auth" = '1' ] && log "summary: auth file will be written to $auth_dst"
    [ "$ovpn_cert_auth" = '1' ] && log "summary: inline client cert/key will be written"
    [ "$ovpn_tls_mode" = 'auth' ] && log "summary: inline tls-auth key will be written (key-direction=$ovpn_key_direction)"
    [ "$ovpn_tls_mode" = 'crypt' ] && log "summary: inline tls-crypt key will be written"
    [ "$ovpn_extra" != '0' ] && log "summary: extra OpenVPN directives will be appended"
    confirm_or_exit "确认写入 OpenVPN 配置并启动吗？"

    if [ "$ovpn_dnsmasq_sync" = '1' ]; then
        log "提示: 正在为 $ovpn_server 写入 dnsmasq 上游解析规则，请稍候..."
        if sync_openvpn_domain_dnsmasq_upstreams "$ovpn_server"; then
            log "提示: 已自动写入 $ovpn_server 的 dnsmasq 上游解析规则，OpenVPN 将保留域名 remote"
        else
            ovpn_pin_remote='1'
            ovpn_remote_entries="$(printf '%s\n' "$resolved_ip_list" | awk -v port="$ovpn_port" 'NF { print "remote " $0 " " port }')"
            [ -n "$ovpn_remote_entries" ] || die "server resolve failed: $ovpn_server upstream DNS returned no usable $ovpn_family record"
            cleanup_openvpn_dnsmasq_domain_rules || die "旧的 OpenVPN dnsmasq 域名上游规则清理失败"
            log "提示: dnsmasq 上游解析规则写入失败，已回退为固定 remote 地址"
        fi
    else
        cleanup_openvpn_dnsmasq_domain_rules || die "旧的 OpenVPN dnsmasq 域名上游规则清理失败"
    fi

    backup_file "$ovpn_dst"
    [ -f "$auth_dst" ] && backup_file "$auth_dst"
    backup_file /etc/config/openvpn
    backup_file /etc/init.d/openvpn_client
    [ -f "$hotplug_dst" ] && backup_file "$hotplug_dst"

    {
        printf '%s\n' 'client'
        printf '%s\n' 'dev tun'
        printf 'proto %s\n' "$ovpn_proto"
        if [ "$ovpn_pin_remote" = '1' ]; then
            printf '#nradio-remote-host %s\n' "$ovpn_server"
        fi
        printf '%s\n' "$ovpn_remote_entries"
        printf '%s\n' 'resolv-retry infinite'
        printf '%s\n' 'nobind'
        printf '%s\n' 'persist-key'
        printf '%s\n' 'persist-tun'
        printf '%s\n' 'route-noexec'
        printf 'tun-mtu %s\n' "$ovpn_mtu"
        printf '%s\n' 'status /var/run/openvpn.custom_config.status 10'
        printf '%s\n' 'log /tmp/openvpn-client.log'
        printf '%s\n' 'verb 3'
    } > "$ovpn_dst"

    if [ "$ovpn_server_verify" = 'strict' ]; then
        cat >> "$ovpn_dst" <<'EOF'
remote-cert-tls server
EOF
    fi

    if [ "$ovpn_verify_cn" = '1' ]; then
        printf 'verify-x509-name "%s" name\n' "$ovpn_server_cn" >> "$ovpn_dst"
    fi

    if [ "$ovpn_auth" = '1' ]; then
        printf '%s\n%s\n' "$ovpn_user" "$ovpn_pass" > "$auth_dst"
        chmod 600 "$auth_dst"
        printf 'auth-user-pass %s\n' "$auth_dst" >> "$ovpn_dst"
        printf '%s\n' 'auth-nocache' >> "$ovpn_dst"
    else
        rm -f "$auth_dst"
    fi

    if [ -n "$ovpn_cipher" ]; then
        printf 'cipher %s\n' "$ovpn_cipher" >> "$ovpn_dst"
        printf 'data-ciphers %s\n' "$ovpn_cipher" >> "$ovpn_dst"
        printf 'data-ciphers-fallback %s\n' "$ovpn_cipher" >> "$ovpn_dst"
    fi

    if [ -n "$ovpn_auth_digest" ]; then
        printf 'auth %s\n' "$ovpn_auth_digest" >> "$ovpn_dst"
    fi

    if [ "$ovpn_lzo" = '1' ]; then
        cat >> "$ovpn_dst" <<'EOF'
comp-lzo yes
EOF
    fi

    cat >> "$ovpn_dst" <<EOF
<ca>
$(cat "$ca_tmp")
</ca>
EOF

    if [ "$ovpn_cert_auth" = '1' ]; then
        cat >> "$ovpn_dst" <<EOF
<cert>
$(cat "$cert_tmp")
</cert>
<key>
$(cat "$key_tmp")
</key>
EOF
    fi

    if [ "$ovpn_tls_mode" = 'auth' ]; then
        cat >> "$ovpn_dst" <<EOF
key-direction $ovpn_key_direction
<tls-auth>
$(cat "$ta_tmp")
</tls-auth>
EOF
    fi

    if [ "$ovpn_tls_mode" = 'crypt' ]; then
        cat >> "$ovpn_dst" <<EOF
<tls-crypt>
$(cat "$ta_tmp")
</tls-crypt>
EOF
    fi

    if [ "$ovpn_extra" != '0' ]; then
        printf '\n' >> "$ovpn_dst"
        cat "$extra_tmp" >> "$ovpn_dst"
        printf '\n' >> "$ovpn_dst"
    fi

    chmod 600 "$ovpn_dst"
    save_openvpn_runtime_state

    uci set openvpn.custom_config=openvpn
    uci set openvpn.custom_config.enabled='1'
    uci set openvpn.custom_config.config="$ovpn_dst"
    uci commit openvpn

    if [ -f /etc/init.d/openvpn_client ]; then
        /etc/init.d/openvpn_client disable >/dev/null 2>&1 || true
        /etc/init.d/openvpn_client stop >/dev/null 2>&1 || true
    fi

    if [ -f "$hotplug_src" ] && [ ! -f "$hotplug_dst" ]; then
        cp "$hotplug_src" "$hotplug_dst"
    fi
    if [ -f "$hotplug_dst" ]; then
        sed -i 's/ifup)/up|ifup)/' "$hotplug_dst"
        chmod 755 "$hotplug_dst"
    fi

    /etc/init.d/openvpn enable >/dev/null 2>&1 || true
    /etc/init.d/openvpn stop >/dev/null 2>&1 || true
    killall openvpn 2>/dev/null || true
    rm -f /tmp/openvpn-runtime-fix.log /tmp/openvpn-client.log /var/run/openvpn.custom_config.status /var/run/openvpn.custom_config.pid 2>/dev/null || true
    sleep 2

    /etc/init.d/openvpn restart >/tmp/openvpn-runtime-fix.log 2>&1 || true
    sleep 12

    if [ -f "$hotplug_dst" ]; then
        ACTION=up sh "$hotplug_dst" >/tmp/openvpn-route-apply.log 2>&1 || true
    fi

    ovpn_status="$(/etc/init.d/openvpn status 2>/dev/null || true)"
    tun_line="$(ip addr show tun0 2>/dev/null | grep -m1 'inet ' || true)"
    route_hits="$(ip route | grep 'dev tun0' || true)"
    runtime_log_text="$(sed -n '1,120p' /tmp/openvpn-client.log 2>/dev/null; sed -n '1,120p' /tmp/openvpn-runtime-fix.log 2>/dev/null)"
    verify_file_exists "$ovpn_dst" "OpenVPN runtime"

    if [ -z "$tun_line" ]; then
        print_openvpn_runtime_debug
        print_openvpn_runtime_hints "$ovpn_cert_auth" "$ovpn_tls_mode" "$ovpn_proto" "$runtime_log_text"
        die "OpenVPN runtime failed: tun0 not established"
    fi

    log "安装完成"
    log "插件:   OpenVPN runtime"
    log "profile:  $ovpn_dst"
    [ "$ovpn_auth" = '1' ] && log "auth:     $auth_dst"
    log "status:   ${ovpn_status:-unknown}"
    log "tun0:     ${tun_line:-missing}"
    if [ -n "$route_hits" ]; then
        log "routes:   detected via tun0"
    else
        log "routes:   not detected"
    fi
    log "备注:     full log at /tmp/openvpn-runtime-fix.log"
}

configure_openvpn_routes() {
    hotplug_dst="/etc/hotplug.d/openvpn/99-openvpn-route"
    route_tmp="$WORKDIR/openvpn-route.rules"
    map_route_tmp="$WORKDIR/openvpn-map-peers.rules"

    mkdir -p /etc/hotplug.d/openvpn "$WORKDIR"
    load_openvpn_route_state_snapshot
    clear_openvpn_route_state_vars
    if [ -f "$ROUTE_STATE_FILE" ] && confirm_default_yes '复用上次保存的路由基础设置吗？'; then
        load_openvpn_route_state
    fi

    case "${ROUTE_NAT:-}" in
        1) ROUTE_NAT='y' ;;
        0) ROUTE_NAT='n' ;;
    esac
    case "${ROUTE_FORWARD:-}" in
        1) ROUTE_FORWARD='y' ;;
        0) ROUTE_FORWARD='n' ;;
    esac
    case "${ROUTE_ENHANCED:-}" in
        1) ROUTE_ENHANCED='y' ;;
        0) ROUTE_ENHANCED='n' ;;
    esac
    case "${ROUTE_MAP_ENABLE:-}" in
        1) ROUTE_MAP_ENABLE='y' ;;
        0) ROUTE_MAP_ENABLE='n' ;;
    esac

    prompt_with_default '本地 LAN 接口' "${ROUTE_LAN_IF:-br-lan}"
    lan_if="$PROMPT_RESULT"
    case "$lan_if" in
        *[[:space:]]*) die 'LAN interface must not contain spaces' ;;
    esac

    prompt_with_default 'VPN 接口名' "${ROUTE_TUN_IF:-tun0}"
    tun_if="$PROMPT_RESULT"
    case "$tun_if" in
        *[[:space:]]*) die 'VPN interface must not contain spaces' ;;
    esac

    lan_default_subnet="$(get_default_lan_subnet 2>/dev/null || true)"
    [ -n "$lan_default_subnet" ] || lan_default_subnet='192.168.66.0/24'
    [ -n "${ROUTE_LAN_SUBNET:-}" ] && lan_default_subnet="$ROUTE_LAN_SUBNET"
    printf '本地 LAN 网段（例如 192.168.66.0/24） [%s]: ' "$lan_default_subnet"
    ui_read_line || die "input cancelled"
    lan_subnet="$UI_READ_RESULT"
    [ -n "$lan_subnet" ] || lan_subnet="$lan_default_subnet"
    case "$lan_subnet" in
        */*) ;;
        *) die 'LAN subnet must be CIDR format' ;;
    esac
    lan_subnet_norm="$(normalize_ipv4_cidr "$lan_subnet" 2>/dev/null || true)"
    [ -n "$lan_subnet_norm" ] || die 'LAN subnet format invalid'
    lan_subnet="$lan_subnet_norm"

    tun_default_subnet="${ROUTE_TUN_SUBNET:-}"
    if [ -z "$tun_default_subnet" ]; then
        tun_default_subnet="$(get_interface_subnet "$tun_if" 2>/dev/null || true)"
        if [ -n "$tun_default_subnet" ]; then
            tun_default_subnet="$(normalize_ipv4_cidr "$tun_default_subnet" 2>/dev/null || true)"
        fi
    fi
    prompt_with_default 'VPN 隧道网段（客户端地址池所在网段，例如 11.1.0.0/16；留空则不单独添加）' "$tun_default_subnet"
    tun_subnet="$PROMPT_RESULT"
    if [ -n "$tun_subnet" ]; then
        case "$tun_subnet" in
            */*) ;;
            *) die 'VPN subnet must be CIDR format' ;;
        esac
        tun_subnet_norm="$(normalize_ipv4_cidr "$tun_subnet" 2>/dev/null || true)"
        [ -n "$tun_subnet_norm" ] || die 'VPN subnet format invalid'
        tun_subnet="$tun_subnet_norm"
    fi

    prompt_with_default '是否添加 NAT 伪装（MASQUERADE）？(y/n)' "${ROUTE_NAT:-y}"
    route_nat="$PROMPT_RESULT"
    case "$route_nat" in
        y|Y|yes|YES) route_nat='1' ;;
        n|N|no|NO) route_nat='0' ;;
        *) die 'NAT choice must be y or n' ;;
    esac

    prompt_with_default '是否添加 FORWARD 放行规则？(y/n)' "${ROUTE_FORWARD:-y}"
    route_forward="$PROMPT_RESULT"
    case "$route_forward" in
        y|Y|yes|YES) route_forward='1' ;;
        n|N|no|NO) route_forward='0' ;;
        *) die 'FORWARD choice must be y or n' ;;
    esac

    prompt_with_default '是否启用互访增强模式（统一 tun 网段并补策略路由）？(y/n)' "${ROUTE_ENHANCED:-y}"
    route_enhanced="$PROMPT_RESULT"
    case "$route_enhanced" in
        y|Y|yes|YES) route_enhanced='1' ;;
        n|N|no|NO) route_enhanced='0' ;;
        *) die 'enhanced mode choice must be y or n' ;;
    esac

    prompt_with_default '是否自动补齐 NAT 映射互访（映射目标、主机/网段路由、proxy_arp、客户端回程SNAT）？(y/n)' "${ROUTE_MAP_ENABLE:-n}"
    route_map_enable="$PROMPT_RESULT"
    case "$route_map_enable" in
        y|Y|yes|YES) route_map_enable='1' ;;
        n|N|no|NO) route_map_enable='0' ;;
        *) die 'mapping complement choice must be y or n' ;;
    esac

    map_ip=''
    map_host=''
    map_kind=''
    map_subnet=''
    lan_host_ip=''
    : > "$map_route_tmp"
    if [ "$route_map_enable" = '1' ]; then
        log 'tip: mapping complement requires at least one mapped peer target; if you only need normal remote routes, rerun option 10 and choose n'
        prompt_with_default '本机映射地址或映射网段（单 IP 例如 192.168.66.167；整段例如 192.168.167.0/24）' "${ROUTE_MAP_IP:-}"
        map_ip="$PROMPT_RESULT"
        [ -n "$map_ip" ] || die 'mapped LAN IP is required when mapping complement is enabled'
        map_parse_result="$(parse_map_target "$map_ip" 2>/dev/null || true)"
        [ -n "$map_parse_result" ] || die 'mapped LAN IP format invalid'
        map_kind="${map_parse_result%%|*}"
        map_ip_value="${map_parse_result#*|}"
        if [ "$map_kind" = 'host' ]; then
            map_host="$map_ip_value"
            map_ip="$map_host/32"
            map_subnet=''
        else
            map_host=''
            map_ip="$map_ip_value"
            map_subnet="$map_ip"
            [ "${map_subnet##*/}" = "${lan_subnet##*/}" ] || die 'subnet mapping requires the mapped subnet prefix length to match the local LAN subnet prefix length'
            [ "$map_subnet" = "$lan_subnet" ] && die 'mapped subnet must not equal local LAN subnet'
        fi

        lan_host_ip="$(get_interface_subnet "$lan_if" 2>/dev/null | cut -d/ -f1)"
        [ -n "$lan_host_ip" ] || lan_host_ip="$(uci -q get network.lan.ipaddr 2>/dev/null || true)"
        lan_host_ip="$(normalize_ipv4_host "$lan_host_ip" 2>/dev/null || true)"
        [ -n "$lan_host_ip" ] || die 'failed to detect local LAN host IP'
        [ "$map_kind" = 'host' ] && [ "$map_host" = "$lan_host_ip" ] && die 'mapped host must not equal local LAN host IP'

        if [ -s "$ROUTE_MAP_LIST_FILE" ] && confirm_default_yes '复用已保存的映射对端列表吗？'; then
            cp "$ROUTE_MAP_LIST_FILE" "$map_route_tmp"
        else
            while :; do
                printf '对端映射地址或网段（至少输入一个，留空结束；例如 192.168.66.166 或 192.168.167.0/24）: '
                ui_read_line || die "input cancelled"
                peer_map_ip="$UI_READ_RESULT"
                [ -z "$peer_map_ip" ] && break
                peer_parse_result="$(parse_map_target "$peer_map_ip" 2>/dev/null || true)"
                [ -n "$peer_parse_result" ] || die 'peer mapped target format invalid'
                peer_map_kind="${peer_parse_result%%|*}"
                peer_map_target="${peer_parse_result#*|}"
                if [ "$peer_map_kind" = 'host' ]; then
                    [ "$peer_map_target" = "$map_host" ] && die 'peer mapped target must not equal local mapped target; do not input this device own mapped IP again'
                else
                    [ "$peer_map_target" = "$lan_subnet" ] && die 'peer mapped subnet must not equal local LAN subnet'
                    [ -n "$map_subnet" ] && [ "$peer_map_target" = "$map_subnet" ] && die 'peer mapped target must not equal local mapped target; do not input this device own mapped subnet again'
                fi
                grep -q "^$peer_map_target|" "$map_route_tmp" 2>/dev/null && die "duplicate mapped peer target: $peer_map_target"
                printf '该映射地址对应的对端隧道 IP（例如 11.1.1.4）: '
                ui_read_line || die "input cancelled"
                peer_map_gw="$UI_READ_RESULT"
                peer_map_gw_norm="$(normalize_ipv4_host "$peer_map_gw" 2>/dev/null || true)"
                [ -n "$peer_map_gw_norm" ] || die 'peer tunnel IP format invalid'
                printf '%s|%s|%s\n' "$peer_map_target" "$peer_map_gw_norm" "$peer_map_kind" >> "$map_route_tmp"
            done
        fi

        if [ -s "$map_route_tmp" ]; then
            map_route_tmp_norm="$WORKDIR/openvpn-map-peers.normalized"
            : > "$map_route_tmp_norm"
            while IFS='|' read -r peer_map_target peer_map_gw peer_map_kind_saved; do
                [ -n "$peer_map_target" ] || continue
                [ -n "$peer_map_kind_saved" ] || peer_map_kind_saved="$(infer_map_target_kind "$peer_map_target")"
                if [ "$peer_map_kind_saved" = 'host' ]; then
                    peer_map_target="${peer_map_target%/*}"
                fi
                printf '%s|%s|%s\n' "$peer_map_target" "$peer_map_gw" "$peer_map_kind_saved" >> "$map_route_tmp_norm"
            done < "$map_route_tmp"
            mv "$map_route_tmp_norm" "$map_route_tmp"
        fi

        [ -s "$map_route_tmp" ] || die 'at least one mapped peer target is required when mapping complement is enabled'
    fi

    tun_supernet=''
    tun_route_verify="$tun_subnet"
    if [ "$route_enhanced" = '1' ] && [ -n "$tun_subnet" ]; then
        tun_supernet="$(derive_supernet16_from_cidr "$tun_subnet" 2>/dev/null || true)"
        [ -n "$tun_supernet" ] || die 'failed to derive tunnel supernet from VPN subnet'
        tun_route_verify="$tun_supernet"
    fi

    : > "$route_tmp"
    if [ -f "$ROUTE_LIST_FILE" ] && confirm_default_yes '复用已保存的远端网段列表吗？'; then
        cp "$ROUTE_LIST_FILE" "$route_tmp"
    else
        log 'tip: single host targets should be entered as plain IP or /32; do not use /24 for a single host'
        while :; do
            printf '远端网段或单主机（留空结束，例如 192.168.2.0/24 或 192.168.66.167）: '
            ui_read_line || die "input cancelled"
            remote_subnet="$UI_READ_RESULT"
            [ -z "$remote_subnet" ] && break
            remote_parse_result="$(parse_map_target "$remote_subnet" 2>/dev/null || true)"
            [ -n "$remote_parse_result" ] || die 'remote subnet format invalid'
            remote_target_kind="${remote_parse_result%%|*}"
            remote_target_value="${remote_parse_result#*|}"
            if [ "$remote_target_kind" = 'host' ]; then
                remote_subnet="$remote_target_value/32"
            else
                remote_subnet="$remote_target_value"
            fi
            printf '该网段对应的对端隧道 IP（例如 11.1.1.1）: '
            ui_read_line || die "input cancelled"
            remote_gw="$UI_READ_RESULT"
            [ -n "$remote_gw" ] || die 'gateway is required'
            case "$remote_gw" in
                */*) die 'gateway must be a host IP, not CIDR' ;;
            esac
            remote_gw_norm="$(normalize_ipv4_host "$remote_gw" 2>/dev/null || true)"
            [ -n "$remote_gw_norm" ] || die 'gateway format invalid'
            remote_gw="$remote_gw_norm"
            grep -q "^$remote_subnet|" "$route_tmp" 2>/dev/null && die "duplicate remote target after normalization: $remote_subnet"
            printf '%s|%s\n' "$remote_subnet" "$remote_gw" >> "$route_tmp"
        done
    fi

    [ -s "$route_tmp" ] || die 'at least one remote subnet is required'

    log "summary: OpenVPN 路由脚本将写入 $hotplug_dst"
    log "summary: 本地 LAN 接口=$lan_if 本地 LAN 网段=$lan_subnet"
    log "summary: VPN 接口=$tun_if"
    [ -n "$tun_subnet" ] && log "summary: VPN 隧道网段=$tun_subnet"
    [ "$route_nat" = '1' ] && log "summary: NAT masquerade will be added"
    [ "$route_forward" = '1' ] && log "summary: FORWARD accept rules will be added"
    [ "$route_enhanced" = '1' ] && log "summary: enhanced mode enabled (tun supernet + policy rules)"
    if [ "$route_map_enable" = '1' ]; then
        if [ "$map_kind" = 'host' ]; then
            log "summary: mapping complement enabled local-host=$map_ip -> $lan_host_ip"
        else
            log "summary: mapping complement enabled local-subnet=$map_subnet -> $lan_subnet"
        fi
        if [ -s "$map_route_tmp" ]; then
            log "summary: mapped peer list"
            while IFS='|' read -r peer_map_target peer_map_gw peer_map_kind_saved; do
                [ -n "$peer_map_target" ] || continue
                [ -n "$peer_map_kind_saved" ] || peer_map_kind_saved="$(infer_map_target_kind "$peer_map_target")"
                log "  - $peer_map_target via $peer_map_gw ($peer_map_kind_saved)"
            done < "$map_route_tmp"
        fi
    fi
    log "summary: route list"
    while IFS='|' read -r subnet gw; do
        log "  - $subnet via $gw"
    done < "$route_tmp"
    [ -f "$ROUTE_LIST_FILE" ] && log "summary: saved route list file=$ROUTE_LIST_FILE"
    confirm_or_exit "确认写入 OpenVPN 路由脚本吗？"

    backup_file "$hotplug_dst"

    {
        printf '%s\n' '#!/bin/sh'
        printf '%s\n' ''
        printf '%s\n' '[ "$ACTION" = "up" ] || [ "$ACTION" = "ifup" ] || exit 0'
        printf '%s\n' ''
        printf '%s\n' 'LAN_IF="'"$lan_if"'"'
        printf '%s\n' 'TUN_IF="'"$tun_if"'"'
        printf '%s\n' 'LAN_SUBNET="'"$lan_subnet"'"'
        if [ -n "$tun_subnet" ]; then
            printf '%s\n' 'TUN_SUBNET="'"$tun_subnet"'"'
        else
            printf '%s\n' 'TUN_SUBNET=""'
        fi
        if [ "$route_enhanced" = '1' ] && [ -n "$tun_supernet" ]; then
            printf '%s\n' 'TUN_SUPERNET="'"$tun_supernet"'"'
        else
            printf '%s\n' 'TUN_SUPERNET=""'
        fi
        if [ "$route_map_enable" = '1' ]; then
            printf '%s\n' 'MAP_KIND="'"$map_kind"'"'
            printf '%s\n' 'MAP_IP="'"$map_ip"'"'
            printf '%s\n' 'MAP_HOST="'"$map_host"'"'
            printf '%s\n' 'MAP_SUBNET="'"$map_subnet"'"'
            printf '%s\n' 'LAN_HOST_IP="'"$lan_host_ip"'"'
        else
            printf '%s\n' 'MAP_KIND=""'
            printf '%s\n' 'MAP_IP=""'
            printf '%s\n' 'MAP_HOST=""'
            printf '%s\n' 'MAP_SUBNET=""'
            printf '%s\n' 'LAN_HOST_IP=""'
        fi
        printf '%s\n' ''
        printf '%s\n' 'apply_routes() {'
        printf '%s\n' '    [ -d "/sys/class/net/$TUN_IF" ] || exit 0'
        printf '%s\n' '    cleanup_target_rules() {'
        printf '%s\n' '        target="$1"'
        printf '%s\n' '        pri=60'
        printf '%s\n' '        while [ "$pri" -le 119 ]; do'
        printf '%s\n' '            ip rule del to "$target" lookup main priority "$pri" 2>/dev/null || true'
        printf '%s\n' '            ip rule del iif "$LAN_IF" to "$target" lookup main priority "$pri" 2>/dev/null || true'
        printf '%s\n' '            pri=$((pri + 1))'
        printf '%s\n' '        done'
        printf '%s\n' '    }'
        printf '%s\n' '    delete_rule_loop() {'
        printf '%s\n' '        table="$1"'
        printf '%s\n' '        chain="$2"'
        printf '%s\n' '        shift 2'
        printf '%s\n' '        command -v iptables >/dev/null 2>&1 || return 0'
        printf '%s\n' '        while iptables -t "$table" -C "$chain" "$@" >/dev/null 2>&1; do'
        printf '%s\n' '            iptables -t "$table" -D "$chain" "$@" >/dev/null 2>&1 || break'
        printf '%s\n' '        done'
        printf '%s\n' '    }'
        printf '%s\n' '    ensure_iptables_rule() {'
        printf '%s\n' '        table="$1"'
        printf '%s\n' '        chain="$2"'
        printf '%s\n' '        mode="$3"'
        printf '%s\n' '        shift 3'
        printf '%s\n' '        command -v iptables >/dev/null 2>&1 || return 0'
        printf '%s\n' '        delete_rule_loop "$table" "$chain" "$@"'
        printf '%s\n' '        case "$mode" in'
        printf '%s\n' '            insert) iptables -t "$table" -I "$chain" 1 "$@" >/dev/null 2>&1 || true ;;'
        printf '%s\n' '            *) iptables -t "$table" -A "$chain" "$@" >/dev/null 2>&1 || true ;;'
        printf '%s\n' '        esac'
        printf '%s\n' '    }'
        if [ "$route_enhanced" = '1' ]; then
            printf '%s\n' '    CUR_IP=$(ip -4 addr show dev "$TUN_IF" | awk '\''/inet /{print $2; exit}'\'' | cut -d/ -f1)'
            printf '%s\n' '    [ -n "$CUR_IP" ] || exit 0'
            printf '%s\n' '    ip link set "$TUN_IF" up'
            printf '%s\n' '    [ -n "$TUN_SUBNET" ] && ip route del "$TUN_SUBNET" 2>/dev/null'
            printf '%s\n' '    [ -n "$TUN_SUPERNET" ] && ip route del "$TUN_SUPERNET" 2>/dev/null'
            printf '%s\n' '    [ -n "$TUN_SUPERNET" ] && ip route add "$TUN_SUPERNET" dev "$TUN_IF" 2>/dev/null'
        else
            printf '%s\n' '    [ -n "$TUN_SUBNET" ] && ip route replace "$TUN_SUBNET" dev "$TUN_IF" 2>/dev/null'
        fi
        printf '%s\n' '    TO_ROUTE_PRI=60'
        printf '%s\n' '    IIF_ROUTE_PRI=70'
        if [ "$route_map_enable" = '1' ]; then
            printf '%s\n' '    if [ "$MAP_KIND" = "host" ]; then'
            printf '%s\n' '        ip -4 addr show dev "$LAN_IF" | grep -q "inet ${MAP_IP}" || ip addr add "$MAP_IP" dev "$LAN_IF" 2>/dev/null'
            printf '%s\n' '        [ -w "/proc/sys/net/ipv4/conf/all/proxy_arp" ] && echo 1 > /proc/sys/net/ipv4/conf/all/proxy_arp'
            printf '%s\n' '        [ -w "/proc/sys/net/ipv4/conf/$LAN_IF/proxy_arp" ] && echo 1 > /proc/sys/net/ipv4/conf/$LAN_IF/proxy_arp'
            printf '%s\n' '        ensure_iptables_rule nat PREROUTING insert -i "$TUN_IF" -d "$MAP_HOST" -j DNAT --to-destination "$LAN_HOST_IP"'
            printf '%s\n' '        ensure_iptables_rule nat OUTPUT insert -d "$MAP_HOST" -j DNAT --to-destination "$LAN_HOST_IP"'
            printf '%s\n' '    else'
            printf '%s\n' '        ensure_iptables_rule nat PREROUTING insert -i "$TUN_IF" -d "$MAP_SUBNET" -j NETMAP --to "$LAN_SUBNET"'
            printf '%s\n' '        ensure_iptables_rule nat OUTPUT insert -d "$MAP_SUBNET" -j NETMAP --to "$LAN_SUBNET"'
            printf '%s\n' '    fi'
            while IFS='|' read -r peer_map_target peer_map_gw peer_map_kind_saved; do
                [ -n "$peer_map_target" ] || continue
                if [ "$peer_map_kind_saved" = 'host' ]; then
                    peer_map_match="$peer_map_target/32"
                    printf '%s\n' "    ip neigh replace proxy \"$peer_map_target\" dev \"\$LAN_IF\" 2>/dev/null || ip neigh add proxy \"$peer_map_target\" dev \"\$LAN_IF\" 2>/dev/null || true"
                else
                    peer_map_match="$peer_map_target"
                fi
                printf '%s\n' "    cleanup_target_rules \"$peer_map_match\""
                printf '%s\n' "    ip route replace \"$peer_map_match\" via \"$peer_map_gw\" dev \"\$TUN_IF\" 2>/dev/null"
                printf '%s\n' "    ensure_iptables_rule nat POSTROUTING append -s \"\$LAN_SUBNET\" -d \"$peer_map_match\" -o \"\$TUN_IF\" -j MASQUERADE"
                printf '%s\n' "    ensure_iptables_rule filter FORWARD append -s \"\$LAN_SUBNET\" -d \"$peer_map_match\" -i \"\$LAN_IF\" -o \"\$TUN_IF\" -j ACCEPT"
                printf '%s\n' "    ensure_iptables_rule filter FORWARD append -s \"$peer_map_match\" -d \"\$LAN_SUBNET\" -i \"\$TUN_IF\" -o \"\$LAN_IF\" -j ACCEPT"
                printf '%s\n' "    ip rule del to \"$peer_map_match\" lookup main priority \$TO_ROUTE_PRI 2>/dev/null"
                printf '%s\n' "    ip rule add to \"$peer_map_match\" lookup main priority \$TO_ROUTE_PRI"
                printf '%s\n' '    TO_ROUTE_PRI=$((TO_ROUTE_PRI + 1))'
                printf '%s\n' "    ip rule del iif \"\$LAN_IF\" to \"$peer_map_match\" lookup main priority \$IIF_ROUTE_PRI 2>/dev/null"
                printf '%s\n' "    ip rule add iif \"\$LAN_IF\" to \"$peer_map_match\" lookup main priority \$IIF_ROUTE_PRI"
                printf '%s\n' '    IIF_ROUTE_PRI=$((IIF_ROUTE_PRI + 1))'
            done < "$map_route_tmp"
        fi
        while IFS='|' read -r subnet gw; do
            [ -n "$subnet" ] || continue
            printf '%s\n' "    cleanup_target_rules \"$subnet\""
            printf '%s\n' "    ip route replace \"$subnet\" via \"$gw\" dev \"\$TUN_IF\" 2>/dev/null"
            if [ "$route_nat" = '1' ]; then
                printf '%s\n' "    ensure_iptables_rule nat POSTROUTING append -s \"\$LAN_SUBNET\" -d \"$subnet\" -o \"\$TUN_IF\" -j MASQUERADE"
            fi
            if [ "$route_forward" = '1' ]; then
                printf '%s\n' "    ensure_iptables_rule filter FORWARD append -s \"$subnet\" -d \"\$LAN_SUBNET\" -i \"\$TUN_IF\" -o \"\$LAN_IF\" -j ACCEPT"
                printf '%s\n' "    ensure_iptables_rule filter FORWARD append -d \"$subnet\" -i \"\$LAN_IF\" -o \"\$TUN_IF\" -j ACCEPT"
            fi
            printf '%s\n' "    ip rule del to \"$subnet\" lookup main priority \$TO_ROUTE_PRI 2>/dev/null"
            printf '%s\n' "    ip rule add to \"$subnet\" lookup main priority \$TO_ROUTE_PRI"
            printf '%s\n' '    TO_ROUTE_PRI=$((TO_ROUTE_PRI + 1))'
            printf '%s\n' "    ip rule del iif \"\$LAN_IF\" to \"$subnet\" lookup main priority \$IIF_ROUTE_PRI 2>/dev/null"
            printf '%s\n' "    ip rule add iif \"\$LAN_IF\" to \"$subnet\" lookup main priority \$IIF_ROUTE_PRI"
            printf '%s\n' '    IIF_ROUTE_PRI=$((IIF_ROUTE_PRI + 1))'
        done < "$route_tmp"
        if [ "$route_enhanced" = '1' ]; then
            pri=196
            while IFS='|' read -r subnet gw; do
                [ -n "$subnet" ] || continue
                printf '%s\n' "    ip rule del from \"\$LAN_SUBNET\" to \"$subnet\" lookup main priority $pri 2>/dev/null"
                printf '%s\n' "    ip rule add from \"\$LAN_SUBNET\" to \"$subnet\" lookup main priority $pri"
                pri=$((pri + 1))
            done < "$route_tmp"
        fi
        printf '%s\n' '}'
        printf '%s\n' ''
        printf '%s\n' 'apply_routes'
    } > "$hotplug_dst"

    chmod 755 "$hotplug_dst"
    sh -n "$hotplug_dst" >/dev/null 2>&1 || die 'generated OpenVPN route script has syntax error'

    cleanup_saved_openvpn_runtime_state
    save_openvpn_route_state

    route_apply_status='skipped'
    if [ -d "/sys/class/net/$tun_if" ]; then
        ACTION=up sh "$hotplug_dst" >/tmp/openvpn-route-apply.log 2>&1 || {
            sed -n '1,120p' /tmp/openvpn-route-apply.log >&2
            die 'failed to apply OpenVPN route script immediately'
        }
        while IFS='|' read -r subnet gw; do
            ip route | grep -q "^$subnet via $gw dev $tun_if" || die "route apply failed: missing $subnet via $gw dev $tun_if"
        done < "$route_tmp"
        if [ "$route_map_enable" = '1' ]; then
            if [ "$map_kind" = 'host' ]; then
                ip -4 addr show dev "$lan_if" | grep -q "inet $map_ip" || die "route apply failed: missing mapped LAN IP $map_ip on $lan_if"
            fi
            while IFS='|' read -r peer_map_target peer_map_gw peer_map_kind_saved; do
                [ -n "$peer_map_target" ] || continue
                [ -n "$peer_map_kind_saved" ] || peer_map_kind_saved="$(infer_map_target_kind "$peer_map_target")"
                if [ "$peer_map_kind_saved" = 'host' ]; then
                    peer_map_verify="${peer_map_target%/*}"
                else
                    peer_map_verify="$peer_map_target"
                fi
                ip route | grep -q "^$peer_map_verify via $peer_map_gw dev $tun_if" || die "route apply failed: missing mapped peer route $peer_map_verify via $peer_map_gw dev $tun_if"
            done < "$map_route_tmp"
        fi
        if [ -n "$tun_route_verify" ]; then
            ip route | grep -q "^$tun_route_verify dev $tun_if" || die "route apply failed: missing tunnel subnet $tun_route_verify dev $tun_if"
        fi
        route_apply_status='applied'
    fi

    log "安装完成"
    log "插件:   OpenVPN routes"
    log "script:   $hotplug_dst"
    log "lan-if:   $lan_if"
    log "lan-net:  $lan_subnet"
    [ -n "$tun_subnet" ] && log "tun-net:  $tun_subnet"
    log "apply:    $route_apply_status"
    log "备注:     routes will also be applied on OpenVPN up/ifup"
}

set_webssh_shortcut_icon() {
    icon_name="$1"
    template_file="/usr/lib/lua/luci/view/nradio_appcenter/appcenter.htm"
    [ -n "$icon_name" ] || return 0
    [ -f "$template_file" ] || return 0
    grep -q 'app_list.result.applist.unshift({name:"Web SSH"' "$template_file" || return 0

    backup_file "$template_file"
    tmp_file="$WORKDIR/appcenter-webssh-icon.htm"
    awk -v icon="$icon_name" '
        {
            if ($0 ~ /app_list\.result\.applist\.unshift\(\{name:"Web SSH"/) {
                print "    app_list.result.applist.unshift({name:\"Web SSH\", version:\"ttyd 1.7.7\", des:\"浏览器 SSH 终端\", icon:\"" icon "\", open:1, has_luci:1, status:1, luci_module_route:\"nradioadv/system/webssh\"});"
                next
            }
            print
        }
    ' "$template_file" > "$tmp_file" && mv "$tmp_file" "$template_file"
}

install_ttyd_webssh() {
    require_nradio_oem_appcenter
    confirm_or_exit "确认继续安装 ttyd / Web SSH 并修改系统吗？"

    helper="$WORKDIR/nradio-ttyd-webssh-embedded.sh"
    mkdir -p "$WORKDIR"
    cat > "$helper" <<'__TTYD_HELPER__'
#!/bin/sh
set -eu
umask 077

APP_NAME="ttyd Web SSH 助手"
TTYD_VERSION="1.7.7"
TTYD_RELEASE_MIRRORS="${TTYD_RELEASE_MIRRORS:-https://ghproxy.net/https://github.com/tsl0922/ttyd/releases/download/$TTYD_VERSION https://github.com/tsl0922/ttyd/releases/download/$TTYD_VERSION}"
TTYD_RAW_MIRRORS="${TTYD_RAW_MIRRORS:-https://ghproxy.net/https://raw.githubusercontent.com/ozon/luci-app-ttyd/master https://cdn.jsdelivr.net/gh/ozon/luci-app-ttyd@master https://raw.githubusercontent.com/ozon/luci-app-ttyd/master}"
BACKUP_DIR="/root/ttyd-webssh-backup"
WORKDIR="/tmp/ttyd-webssh.$$"
ACTIVE_DOWNLOAD_PID=''
ABORTING='0'

cleanup() {
    terminate_active_download
    rm -rf "$WORKDIR"
}

abort_script() {
    [ "${ABORTING:-0}" = '1' ] && exit 130
    ABORTING='1'
    trap - EXIT INT TERM HUP QUIT
    cleanup
    printf '\n已取消\n' >&2
    exit 130
}

trap cleanup EXIT
trap abort_script INT TERM HUP QUIT

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
_STAGE_T0=""
log_stage() {
    _si="$1"; _st="$2"; shift 2
    _bl=20; _fi=$(( _si * _bl / _st )); [ "$_fi" -gt "$_bl" ] && _fi="$_bl"; _ei=$(( _bl - _fi ))
    _b=""; _j=0; while [ "$_j" -lt "$_fi" ]; do _b="${_b}="; _j=$((_j+1)); done
    if [ "$_ei" -gt 0 ]; then _b="${_b}>"; _j=1; while [ "$_j" -lt "$_ei" ]; do _b="${_b}."; _j=$((_j+1)); done; fi
    _pc=$(( _si * 100 / _st ))
    _et=""; _nw="$(date +%s 2>/dev/null || printf '')"
    if [ -n "$_nw" ] && [ -n "$_STAGE_T0" ]; then
        _d=$((_nw - _STAGE_T0))
        if [ "$_d" -ge 60 ] 2>/dev/null; then _et="  (上一步耗时 $((_d/60))分$((_d%60))秒)"
        elif [ "$_d" -gt 0 ] 2>/dev/null; then _et="  (上一步耗时 ${_d}秒)"; fi
    fi
    [ -n "$_nw" ] && _STAGE_T0="$_nw"
    printf '[%s] %3d%%  [%s/%s] %s%s\n' "$_b" "$_pc" "$_si" "$_st" "$*" "$_et"
}

stderr_is_tty() { [ -t 2 ]; }

get_file_size_bytes() {
    path="$1"
    [ -f "$path" ] || {
        printf '0\n'
        return 0
    }
    wc -c < "$path" 2>/dev/null | tr -d ' ' || printf '0\n'
}

format_bytes_human() {
    size_bytes="${1:-0}"
    case "$size_bytes" in
        ''|*[!0-9]*) size_bytes=0 ;;
    esac
    if [ "$size_bytes" -ge 1073741824 ] 2>/dev/null; then
        awk -v v="$size_bytes" 'BEGIN { printf "%.1f GB", v / 1073741824 }'
    elif [ "$size_bytes" -ge 1048576 ] 2>/dev/null; then
        awk -v v="$size_bytes" 'BEGIN { printf "%.1f MB", v / 1048576 }'
    elif [ "$size_bytes" -ge 1024 ] 2>/dev/null; then
        awk -v v="$size_bytes" 'BEGIN { printf "%.1f KB", v / 1024 }'
    else
        printf '%s B' "$size_bytes"
    fi
}

get_url_content_length() {
    url="$1"
    content_length=""

    if command -v curl >/dev/null 2>&1; then
        headers="$(curl -k -L -sSI --connect-timeout 15 --max-time 20 "$url" 2>/dev/null || true)"
        content_length="$(printf '%s\n' "$headers" | tr -d '\r' | sed -n 's/^[Cc]ontent-[Ll]ength: *//p' | tail -n 1)"
    fi

    case "$content_length" in
        ''|*[!0-9]*) content_length="" ;;
    esac

    printf '%s\n' "$content_length"
}

render_download_progress() {
    progress_state="$1"
    current_bytes="$2"
    total_bytes="${3:-}"
    current_human="$(format_bytes_human "$current_bytes")"

    if [ -n "$total_bytes" ] && [ "$total_bytes" -gt 0 ] 2>/dev/null; then
        total_human="$(format_bytes_human "$total_bytes")"
        progress_percent=$(( current_bytes * 100 / total_bytes ))
        [ "$progress_percent" -le 100 ] 2>/dev/null || progress_percent=100
        _dl_bar_len=15
        _dl_filled=$(( progress_percent * _dl_bar_len / 100 ))
        _dl_empty=$(( _dl_bar_len - _dl_filled ))
        _dl_bar=""
        _dbi=0
        while [ "$_dbi" -lt "$_dl_filled" ]; do _dl_bar="${_dl_bar}="; _dbi=$((_dbi + 1)); done
        if [ "$_dl_empty" -gt 0 ]; then
            _dl_bar="${_dl_bar}>"
            _dbi=1
            while [ "$_dbi" -lt "$_dl_empty" ]; do _dl_bar="${_dl_bar}."; _dbi=$((_dbi + 1)); done
        fi
        line="[${_dl_bar}] ${progress_state} ${current_human} / ${total_human} (${progress_percent}%)"
    else
        line="${progress_state} 已下载 ${current_human}"
    fi

    if stderr_is_tty; then
        printf '\r%-88s' "$line" >&2
    else
        printf '%s\n' "$line" >&2
    fi
}

finish_download_progress_line() {
    if stderr_is_tty; then
        printf '\n' >&2
    fi
}

sleep_abort_poll() {
    usleep 100000 2>/dev/null || sleep 0.1 2>/dev/null || sleep 1
}

terminate_pid_quick() {
    target_pid="$1"
    [ -n "$target_pid" ] || return 0

    if kill -0 "$target_pid" 2>/dev/null; then
        kill -INT "$target_pid" 2>/dev/null || kill "$target_pid" 2>/dev/null || true
        _tp_try=0
        while kill -0 "$target_pid" 2>/dev/null; do
            _tp_try=$((_tp_try + 1))
            [ "$_tp_try" -lt 4 ] || break
            sleep_abort_poll
        done
        if kill -0 "$target_pid" 2>/dev/null; then
            kill -TERM "$target_pid" 2>/dev/null || true
            _tp_try=0
            while kill -0 "$target_pid" 2>/dev/null; do
                _tp_try=$((_tp_try + 1))
                [ "$_tp_try" -lt 4 ] || break
                sleep_abort_poll
            done
        fi
        if kill -0 "$target_pid" 2>/dev/null; then
            kill -9 "$target_pid" 2>/dev/null || true
        fi
    fi

    wait "$target_pid" 2>/dev/null || true
}

terminate_active_download() {
    active_pid="${ACTIVE_DOWNLOAD_PID:-}"
    [ -n "$active_pid" ] || return 0

    terminate_pid_quick "$active_pid"
    ACTIVE_DOWNLOAD_PID=''
}

run_download_with_progress() {
    progress_url="$1"
    progress_out="$2"
    shift 2

    progress_total="$(get_url_content_length "$progress_url")"
    progress_last_size='-1'
    progress_last_percent='-1'

    "$@" &
    progress_pid="$!"
    ACTIVE_DOWNLOAD_PID="$progress_pid"

    while kill -0 "$progress_pid" 2>/dev/null; do
        progress_size="$(get_file_size_bytes "$progress_out")"
        if [ -n "$progress_total" ] && [ "$progress_total" -gt 0 ] 2>/dev/null; then
            progress_percent=$(( progress_size * 100 / progress_total ))
            [ "$progress_percent" -le 100 ] 2>/dev/null || progress_percent=100
        else
            progress_percent='-1'
        fi

        if stderr_is_tty; then
            render_download_progress "下载中" "$progress_size" "$progress_total"
        elif [ "$progress_size" != "$progress_last_size" ] || [ "$progress_percent" != "$progress_last_percent" ]; then
            render_download_progress "下载中" "$progress_size" "$progress_total"
        fi

        progress_last_size="$progress_size"
        progress_last_percent="$progress_percent"
        sleep_abort_poll
    done

    if wait "$progress_pid"; then
        progress_rc=0
    else
        progress_rc="$?"
    fi
    ACTIVE_DOWNLOAD_PID=''
    progress_size="$(get_file_size_bytes "$progress_out")"

    if [ "$progress_rc" -eq 0 ]; then
        render_download_progress "下载完成" "$progress_size" "$progress_total"
    else
        render_download_progress "下载失败" "$progress_size" "$progress_total"
    fi
    finish_download_progress_line

    return "$progress_rc"
}

ensure_root() {
    [ "$(id -u)" = "0" ] || die "run as root"
}

ensure_workdir() {
    mkdir -p "$WORKDIR" "$BACKUP_DIR"
}

backup_file() {
    path="$1"
    [ -f "$path" ] || return 0
    mkdir -p "$BACKUP_DIR"
    cp "$path" "$BACKUP_DIR/$(basename "$path").$$.bak"
}

download_file() {
    download_url="$1"
    download_out="$2"
    download_tmp="$download_out.tmp"

    rm -f "$download_tmp"
    if command -v curl >/dev/null 2>&1; then
        run_download_with_progress "$download_url" "$download_tmp" curl -fL --retry 3 --silent --show-error --connect-timeout 15 --max-time 900 -o "$download_tmp" "$download_url" || return 1
    elif command -v wget >/dev/null 2>&1; then
        run_download_with_progress "$download_url" "$download_tmp" wget -q --no-check-certificate -O "$download_tmp" "$download_url" || return 1
    elif command -v uclient-fetch >/dev/null 2>&1; then
        run_download_with_progress "$download_url" "$download_tmp" uclient-fetch -q -O "$download_tmp" "$download_url" || return 1
    else
        die "系统缺少 curl、wget 或 uclient-fetch，无法下载文件"
    fi

    [ -s "$download_tmp" ] || return 1
    mv "$download_tmp" "$download_out"
}

download_from_mirrors() {
    rel="$1"
    out="$2"
    mirrors="$3"
    mirror_count=0
    mirror_index=0

    for base in $mirrors; do
        mirror_count=$((mirror_count + 1))
    done

    for base in $mirrors; do
        mirror_index=$((mirror_index + 1))
        if download_file "$base/$rel" "$out"; then
            return 0
        fi
        if [ "$mirror_index" -lt "$mirror_count" ]; then
            log "提示: 当前镜像下载未完成，准备切换到下一个镜像..."
        fi
    done

    return 1
}

fetch_luci_file() {
    rel="$1"
    out="$2"
    pattern="$3"
    fetch_tmp="$WORKDIR/$(basename "$out").fetch"

    rm -f "$fetch_tmp"
    for base in $TTYD_RAW_MIRRORS; do
        if download_file "$base/$rel" "$fetch_tmp" && grep -q "$pattern" "$fetch_tmp"; then
            [ -f "$out" ] && backup_file "$out"
            mv "$fetch_tmp" "$out"
            return 0
        fi
    done

    rm -f "$fetch_tmp"
    return 1
}

map_ttyd_arch() {
    case "$1" in
        x86_64) printf '%s\n' x86_64 ;;
        i?86) printf '%s\n' i686 ;;
        aarch64*|arm64*) printf '%s\n' aarch64 ;;
        armv7*|armv6*|armv8*|arm*) printf '%s\n' armhf ;;
        mips64el) printf '%s\n' mips64el ;;
        mips64) printf '%s\n' mips64 ;;
        mipsel) printf '%s\n' mipsel ;;
        mips*) printf '%s\n' mips ;;
        s390x) printf '%s\n' s390x ;;
        ppc64le) printf '%s\n' ppc64le ;;
        ppc64|powerpc64) printf '%s\n' ppc64 ;;
        *) die "不支持的架构: $1" ;;
    esac
}

get_lan_iface() {
    iface="$(uci -q get network.lan.device 2>/dev/null || true)"
    [ -n "$iface" ] || iface="$(uci -q get network.lan.ifname 2>/dev/null || true)"
    [ -n "$iface" ] || iface="br-lan"
    printf '%s\n' "$iface"
}

get_lan_ip() {
    ip -4 addr show br-lan 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1 || true
}

is_ttyd_binary_ready() {
    [ -x /usr/bin/ttyd ] || return 1
    ttyd_version_text="$(/usr/bin/ttyd -v 2>/dev/null | sed -n '1p' | tr -d '\r' || true)"
    printf '%s\n' "$ttyd_version_text" | grep -q "ttyd version $TTYD_VERSION" || return 1
}

is_ttyd_luci_ready() {
    [ -f /usr/lib/lua/luci/controller/ttyd.lua ] || return 1
    [ -f /usr/lib/lua/luci/view/ttyd/overview.htm ] || return 1
    grep -q 'module("luci.controller.ttyd"' /usr/lib/lua/luci/controller/ttyd.lua 2>/dev/null || return 1
    grep -q 'ttyd' /usr/lib/lua/luci/view/ttyd/overview.htm 2>/dev/null || return 1
}

install_ttyd_binary() {
    arch="$(map_ttyd_arch "$(uname -m 2>/dev/null || echo unknown)")"
    bin_name="ttyd.$arch"
    bin_tmp="$WORKDIR/$bin_name"
    sum_tmp="$WORKDIR/SHA256SUMS"

    if is_ttyd_binary_ready; then
        log "备注: ttyd 二进制 $TTYD_VERSION 已存在, 跳过下载"
        return 0
    fi

    log "提示: 正在从 CDN 下载 ttyd 二进制..."
    download_from_mirrors "$bin_name" "$bin_tmp" "$TTYD_RELEASE_MIRRORS" || die "下载 $bin_name 失败"
    download_from_mirrors "SHA256SUMS" "$sum_tmp" "$TTYD_RELEASE_MIRRORS" || die "下载 SHA256SUMS 失败"

    expected="$(awk -v f="$bin_name" '$2==f {print $1; exit}' "$sum_tmp")"
    [ -n "$expected" ] || die "$bin_name 缺少校验和条目"
    actual="$(sha256sum "$bin_tmp" | awk '{print $1}')"
    [ "$expected" = "$actual" ] || die "$bin_name 校验和不匹配"

    backup_file /usr/bin/ttyd
    cp "$bin_tmp" /usr/bin/ttyd
    chmod 755 /usr/bin/ttyd
    /usr/bin/ttyd --help >/dev/null 2>&1 || die "ttyd 二进制自检失败"
}

write_ttyd_init_script() {
    init_file="/etc/init.d/ttyd"
    [ -f "$init_file" ] && backup_file "$init_file"
    cat > "$init_file" <<'EOF'
#!/bin/sh /etc/rc.common

START=30
USE_PROCD=1

EXTRA_COMMANDS="status"
EXTRA_HELP="status	Print runtime information"

ttyd="/usr/bin/ttyd"
ttyd_params=""
ttyd_run="/bin/sh"

start_service()
{
    config_load ttyd
    config_get port default port 7681
    config_get_bool use_credential default credential 0
    config_get username default username
    config_get password default password
    config_get shell default shell /bin/sh
    config_get interface default interface
    config_get_bool once default once 0
    config_get_bool ssl default ssl 0
    config_get_bool readonly default readonly 0
    config_get_bool check_origin default check_origin 0
    config_get max_clients default max_clients 0
    config_get reconnect default reconnect 10
    config_get signal default signal HUP
    config_get index default index
    config_get uid default uid
    config_get gid default gid

    [ -n "$port" ] && ttyd_params="${ttyd_params} --port $port"
    [ -n "$interface" ] && ttyd_params="${ttyd_params} --interface $interface"
    [ "$once" = 1 ] && ttyd_params="${ttyd_params} --once"
    [ "$ssl" = 1 ] && ttyd_params="${ttyd_params} --ssl"
    [ "$readonly" = 1 ] && ttyd_params="${ttyd_params} --readonly"
    [ "$readonly" != 1 ] && ttyd_params="${ttyd_params} --writable"
    [ "$check_origin" = 1 ] && ttyd_params="${ttyd_params} --check-origin"
    [ "$max_clients" != 0 ] && ttyd_params="${ttyd_params} --max-clients $max_clients"
    [ "$reconnect" != 10 ] && ttyd_params="${ttyd_params} --reconnect $reconnect"
    [ -n "$signal" ] && ttyd_params="${ttyd_params} --signal $signal"
    [ -n "$index" ] && ttyd_params="${ttyd_params} --index $index"
    [ "$use_credential" = 1 ] && ttyd_params="${ttyd_params} --credential ${username}:${password}"
    [ -n "$uid" ] && ttyd_params="${ttyd_params} --uid $uid"
    [ -n "$gid" ] && ttyd_params="${ttyd_params} --gid $gid"
    [ -n "$shell" ] && ttyd_run="$shell"

    procd_open_instance "ttyd"
    procd_set_param command ${ttyd} ${ttyd_params} ${ttyd_run} --login
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param pidfile /var/run/ttyd.pid
    procd_close_instance
}

reload_service()
{
    rc_procd start_service reload
}

restart()
{
    rc_procd start_service restart
}

status()
{
    if [ "$(pgrep ttyd 2>/dev/null | head -n 1)" ]; then
        echo 1
    else
        echo 0
    fi
}
EOF
    chmod 755 "$init_file"
}

write_ttyd_config() {
    config_file="/etc/config/ttyd"
    if [ ! -f "$config_file" ]; then
        cat > "$config_file" <<'EOF'
config server 'default'
    option once '0'
    option port '7681'
    option shell '/bin/sh'
    option check_origin '1'
    option max_clients '0'
EOF
    fi

    uci -q set ttyd.default=server
    current_once="$(uci -q get ttyd.default.once 2>/dev/null || true)"
    [ -n "$current_once" ] || uci -q set ttyd.default.once='0'
    current_port="$(uci -q get ttyd.default.port 2>/dev/null || true)"
    [ -n "$current_port" ] || uci -q set ttyd.default.port='7681'
    current_shell="$(uci -q get ttyd.default.shell 2>/dev/null || true)"
    [ -n "$current_shell" ] || uci -q set ttyd.default.shell='/bin/sh'
    current_check_origin="$(uci -q get ttyd.default.check_origin 2>/dev/null || true)"
    [ -n "$current_check_origin" ] || uci -q set ttyd.default.check_origin='1'
    current_max_clients="$(uci -q get ttyd.default.max_clients 2>/dev/null || true)"
    [ -n "$current_max_clients" ] || uci -q set ttyd.default.max_clients='0'
    uci -q commit ttyd
}

write_ttyd_cbi_model() {
    model_file="/usr/lib/lua/luci/model/cbi/ttyd.lua"
    [ -f "$model_file" ] && backup_file "$model_file"
    cat > "$model_file" <<'EOF'
local fs = require("nixio.fs")
local util = require("luci.util")
local ttydcfg = "/etc/config/ttyd"

if not fs.access(ttydcfg) then
    m = SimpleForm("error", nil, "未找到配置文件，请检查 ttyd 配置。")
    m.reset = false
    m.submit = false
    return m
end

m = Map("ttyd", "配置")
s = m:section(TypedSection, "server")
s.addremove = false
s.anonymous = true

once = s:option(Flag, "once", "单次模式", "仅允许一个客户端连接，断开后自动退出")
once.rmempty = true

shells = s:option(ListValue, "shell", "Shell", "选择要启动的 Shell")
local shell_file = fs.readfile("/etc/shells") or "/bin/sh\n/bin/ash\n"
for i in string.gmatch(shell_file, "%S+") do
    shells:value(i)
end
shells.rmempty = false

port = s:option(Value, "port", "端口", "监听端口（默认 7681，填 0 表示随机端口）")
port.default = 7681
port.datatype = "port"
port.rmempty = true
port.placeholder = 7681

iface = s:option(Value, "interface", "接口", "绑定的网络接口（如 eth0），也可填写 UNIX 套接字路径（如 /var/run/ttyd.sock）")
iface.template = "cbi/network_netlist"
iface.nocreate = true
iface.unspecified = true
iface.nobridges = true
iface.optional = true

signals = s:option(ListValue, "signal", "退出信号", "会话退出时发送给命令的信号（默认 SIGHUP）")
local signal_text = util.exec("ttyd --signal-list 2>/dev/null") or ""
for i in string.gmatch(signal_text, "[^\r\n]+") do
    signals:value(string.match(i, "%u+"), string.sub(i, 4))
end
signals.rmempty = true
signals.optional = true

ssl = s:option(Flag, "ssl", "启用 SSL", "启用 HTTPS/WSS")
ssl.rmempty = true

ssl_cert = s:option(FileUpload, "ssl_cert", "SSL 证书文件", "证书文件路径"):depends("ssl", 1)
ssl_key = s:option(FileUpload, "ssl_key", "SSL 私钥文件", "私钥文件路径"):depends("ssl", 1)
ssl_ca = s:option(FileUpload, "ssl_ca", "SSL CA 文件", "客户端证书校验所需的 CA 文件路径"):depends("ssl", 1)

reconnect = s:option(Value, "reconnect", "重连时间", "客户端断开后的自动重连秒数（默认 10）")
reconnect.datatype = "integer"
reconnect.rmempty = true
reconnect.placeholder = 10
reconnect.optional = true

readonly = s:option(Flag, "readonly", "只读模式", "禁止客户端向终端写入")
readonly.rmempty = true
readonly.optional = true

check_origin = s:option(Flag, "check_origin", "同源校验", "禁止来自不同来源的 WebSocket 连接")
check_origin.rmempty = true
check_origin.optional = true

max_clients = s:option(Value, "max_clients", "最大客户端数", "最大并发客户端数量（默认 0，不限制）")
max_clients.datatype = "integer"
max_clients.rmempty = true
max_clients.placeholder = 0
max_clients.optional = true

credential = s:option(Flag, "credential", "启用基础认证", "使用用户名和密码进行访问认证")
credential.rmempty = true

credential_username = s:option(Value, "username", "用户名", "基础认证用户名")
credential_username:depends("credential", 1)
credential_username.rmempty = true

credential_password = s:option(Value, "password", "密码", "基础认证密码")
credential_password:depends("credential", 1)
credential_password.rmempty = true

debug = s:option(Value, "debug", "调试级别", "设置日志级别（默认 7）")
debug.datatype = "integer"
debug.rmempty = true
debug.placeholder = "7"
debug.optional = true

uid = s:option(Value, "uid", "用户 ID", "运行 ttyd 使用的用户 ID")
uid.rmempty = true
uid.optional = true

gid = s:option(Value, "gid", "组 ID", "运行 ttyd 使用的组 ID")
gid.rmempty = true
gid.optional = true

client_option = s:option(Value, "client_option", "客户端参数", "发送给客户端的参数（格式：key=value，可重复添加）")
client_option.rmempty = true
client_option.optional = true

index = s:option(Value, "index", "自定义 index.html", "自定义首页文件路径")
index.rmempty = true
index.optional = true

return m
EOF
}

install_luci_ttyd() {
    mkdir -p /usr/lib/lua/luci/controller /usr/lib/lua/luci/model/cbi /usr/lib/lua/luci/view/ttyd /etc/init.d /etc/config
    if is_ttyd_luci_ready; then
        log "备注:     LuCI ttyd 资源已存在且状态正常，跳过 CDN 下载"
    else
        log "提示: 正在从 CDN 下载 LuCI ttyd 资源..."
        fetch_luci_file "luasrc/controller/ttyd.lua" "/usr/lib/lua/luci/controller/ttyd.lua" 'module("luci.controller.ttyd"' || die "下载 ttyd 控制器失败"
        fetch_luci_file "luasrc/view/ttyd/overview.htm" "/usr/lib/lua/luci/view/ttyd/overview.htm" 'ttyd' || die "下载 ttyd 概览页失败"
    fi

    write_ttyd_init_script
    write_ttyd_config
    write_ttyd_cbi_model
}

install_webssh_wrapper() {
    controller="/usr/lib/lua/luci/controller/nradio_adv/webssh.lua"
    view="/usr/lib/lua/luci/view/nradio_adv/webssh.htm"

    mkdir -p "$(dirname "$controller")" "$(dirname "$view")"
    [ -f "$controller" ] && backup_file "$controller"
    cat > "$controller" <<'EOF'
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
EOF

    [ -f "$view" ] && backup_file "$view"
    cat > "$view" <<'EOF'
<% if true then %>
<%
local dsp = require "luci.dispatcher"
local http = require "luci.http"
local webssh = require "luci.controller.nradio_adv.webssh"
local status_data = webssh.collect_status()
local installed = status_data.installed
local restart_url = dsp.build_url("nradioadv", "system", "webssh", "restart")
local status_url = dsp.build_url("nradioadv", "system", "webssh", "status")
local embed_mode = http.formvalue("embed") == "1" or http.formvalue("embed") == "true"
local stage_class = embed_mode and "webssh-stage is-embed" or "webssh-stage"
%>
<% if not embed_mode then %><%+header%><% end %>
<style>
.webssh-stage{--ws-bg:#f4f7fb;--ws-ink:#111827;--ws-muted:#64748b;--ws-line:#d8e1ec;--ws-panel:#ffffff;--ws-terminal:#07111f;--ws-terminal-2:#0d1b2e;--ws-accent:#0ea5e9;--ws-accent-2:#10b981;max-width:1180px;margin:18px auto 28px;padding:0 18px;color:var(--ws-ink)}
.webssh-stage.is-embed{max-width:none;margin:0;padding:0}
.webssh-shell{position:relative;overflow:hidden;border:1px solid var(--ws-line);border-radius:8px;background:linear-gradient(180deg,#ffffff 0%,#f8fbff 100%);box-shadow:0 18px 48px rgba(15,23,42,.12)}
.webssh-topbar{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:18px 20px;border-bottom:1px solid var(--ws-line);background:linear-gradient(90deg,#0b1220 0%,#10233a 58%,#113f54 100%);color:#fff}
.webssh-identity{display:flex;align-items:center;gap:14px;min-width:0}
.webssh-mark{display:flex;align-items:center;justify-content:center;width:42px;height:42px;border-radius:8px;background:rgba(255,255,255,.1);box-shadow:inset 0 0 0 1px rgba(255,255,255,.12)}
.webssh-mark svg{width:25px;height:25px;display:block}
.webssh-titlewrap{min-width:0}
.webssh-label{margin:0 0 4px;color:#8bdcff;font-size:12px;font-weight:700;letter-spacing:0;text-transform:uppercase}
.webssh-title{margin:0;color:#fff;font-size:22px;line-height:1.2;font-weight:800;letter-spacing:0}
.webssh-summary{display:flex;flex-wrap:wrap;align-items:center;justify-content:flex-end;gap:8px}
.webssh-badge{display:inline-flex;align-items:center;gap:7px;min-height:28px;padding:5px 10px;border-radius:999px;font-size:12px;font-weight:700;line-height:1;border:1px solid transparent;white-space:nowrap}
.webssh-badge:before{content:"";width:7px;height:7px;border-radius:999px;background:currentColor}
.webssh-badge.ok{background:#dcfce7;color:#166534}
.webssh-badge.warn{background:#fef3c7;color:#92400e}
.webssh-badge.off{background:#fee2e2;color:#991b1b}
.webssh-badge.soft{background:rgba(255,255,255,.12);color:#dbeafe;border-color:rgba(255,255,255,.18)}
.webssh-main{display:grid;grid-template-columns:minmax(0,1fr) 300px;gap:0;background:var(--ws-bg)}
.webssh-terminal{min-width:0;padding:18px}
.webssh-terminal-head{display:flex;align-items:center;justify-content:space-between;gap:14px;margin-bottom:12px}
.webssh-terminal-meta{display:flex;flex-wrap:wrap;align-items:center;gap:8px}
.webssh-terminal-meta .webssh-badge.soft{background:#e8f1fb;color:#334155;border-color:#d7e3ef}
.webssh-terminal-title{margin:0;color:#111827;font-size:16px;line-height:1.3;font-weight:800;letter-spacing:0}
.webssh-livebar{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:12px;padding:10px 12px;border:1px solid #172033;border-radius:8px;background:#0b1220;color:#dbeafe}
.webssh-live-left{display:flex;align-items:center;gap:9px;min-width:0}
.webssh-live-dot{width:9px;height:9px;border-radius:999px;background:#22c55e;box-shadow:0 0 0 6px rgba(34,197,94,.14)}
.webssh-live-url{font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace;font-size:12px;line-height:1.4;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.webssh-live-actions{display:flex;align-items:center;gap:6px;flex:0 0 auto}
.webssh-iconbtn{display:inline-flex;align-items:center;justify-content:center;width:32px;height:32px;border:1px solid rgba(148,163,184,.28);border-radius:7px;background:rgba(255,255,255,.06);color:#e0f2fe;text-decoration:none;font-size:13px;font-weight:900;cursor:pointer}
.webssh-iconbtn:hover{background:rgba(14,165,233,.18);border-color:rgba(125,211,252,.55);color:#fff}
.webssh-actions{display:flex;flex-wrap:wrap;align-items:center;justify-content:flex-end;gap:8px}
.webssh-actions-start{justify-content:flex-start}
.webssh-btn{display:inline-flex;align-items:center;justify-content:center;min-height:36px;padding:8px 12px;border:1px solid var(--ws-line);border-radius:8px;background:#fff;color:#172033;text-decoration:none;font-size:12px;font-weight:800;line-height:1.2;cursor:pointer;transition:background-color .16s ease,border-color .16s ease,color .16s ease,transform .16s ease,box-shadow .16s ease}
.webssh-btn:hover{transform:translateY(-1px);border-color:#93c5fd;box-shadow:0 10px 20px rgba(15,23,42,.08);color:#0f172a}
.webssh-btn-primary{border-color:#0284c7;background:#0284c7;color:#fff}
.webssh-btn-primary:hover{border-color:#0369a1;background:#0369a1;color:#fff}
.webssh-btn-dark{border-color:#172033;background:#172033;color:#dbeafe}
.webssh-btn-dark:hover{border-color:#0f172a;background:#0f172a;color:#fff}
.webssh-toolbar{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:12px;padding:10px;border:1px solid rgba(148,163,184,.26);border-radius:8px;background:#fff}
.webssh-segmented{display:inline-flex;gap:4px;padding:3px;border-radius:8px;background:#edf3f9}
.webssh-segmented button{min-width:52px;padding:7px 10px;border:0;border-radius:6px;background:transparent;color:#526173;font-size:12px;font-weight:800;cursor:pointer}
.webssh-segmented button.active{background:#fff;color:#0f172a;box-shadow:0 1px 4px rgba(15,23,42,.12)}
.webssh-sync{display:inline-flex;align-items:center;gap:7px;color:#64748b;font-size:12px;font-weight:700}
.webssh-sync:before{content:"";width:7px;height:7px;border-radius:999px;background:var(--ws-accent-2);box-shadow:0 0 0 5px rgba(16,185,129,.13)}
.webssh-alert{margin-bottom:12px;padding:11px 12px;border:1px solid #fdba74;border-radius:8px;background:#fff7ed;color:#9a3412;font-size:12px;line-height:1.65}
.webssh-framebox{position:relative;overflow:hidden;border-radius:8px;background:linear-gradient(180deg,var(--ws-terminal) 0%,var(--ws-terminal-2) 100%);box-shadow:0 18px 40px rgba(7,17,31,.26)}
.webssh-framebox:before{content:"";display:block;height:34px;background:#101827;border-bottom:1px solid rgba(148,163,184,.18)}
.webssh-dots{position:absolute;left:14px;top:12px;display:flex;gap:7px}
.webssh-dots span{width:9px;height:9px;border-radius:999px;background:#ef4444}
.webssh-dots span:nth-child(2){background:#f59e0b}
.webssh-dots span:nth-child(3){background:#22c55e}
.webssh-framealert{display:none;position:absolute;left:14px;right:14px;top:48px;z-index:2;padding:10px 12px;border-radius:8px;background:rgba(127,29,29,.92);color:#fff;font-size:12px;line-height:1.6;box-shadow:0 14px 30px rgba(15,23,42,.28)}
.webssh-terminal-frame{display:block;width:100%;height:680px;border:0;background:#020617;transition:height .16s ease,box-shadow .16s ease}
.webssh-terminal-frame:focus{box-shadow:inset 0 0 0 2px rgba(14,165,233,.8)}
.webssh-hint{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-top:12px;color:#64748b;font-size:12px;line-height:1.6}
.webssh-hint code{padding:2px 5px;border-radius:4px;background:#e9eef5;color:#334155}
.webssh-aside{border-left:1px solid var(--ws-line);background:#fff;padding:18px}
.webssh-section+.webssh-section{margin-top:18px;padding-top:18px;border-top:1px solid #e8eef5}
.webssh-section h3{margin:0 0 11px;color:#111827;font-size:13px;line-height:1.3;font-weight:800;letter-spacing:0}
.webssh-details{border-top:1px solid #e8eef5}
.webssh-details summary{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:13px 0;color:#111827;font-size:13px;font-weight:800;cursor:pointer;list-style:none}
.webssh-details summary::-webkit-details-marker{display:none}
.webssh-details summary:after{content:"+";display:inline-flex;align-items:center;justify-content:center;width:22px;height:22px;border-radius:999px;background:#eef4fb;color:#334155}
.webssh-details[open] summary:after{content:"-"}
.webssh-details-body{padding-bottom:14px}
.webssh-code{display:block;padding:11px 12px;border-radius:8px;background:#0f172a;color:#dbeafe;font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace;font-size:12px;line-height:1.65;word-break:break-all;text-decoration:none}
.webssh-code+.webssh-code{margin-top:8px}
.webssh-copyrow{display:grid;grid-template-columns:1fr auto;gap:8px;align-items:stretch;margin-top:10px}
.webssh-copyrow .webssh-code{margin:0}
.webssh-copyrow .webssh-btn{min-height:auto}
.webssh-kv{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:8px 0;border-bottom:1px solid #eef3f8;font-size:12px}
.webssh-kv:last-child{border-bottom:0}
.webssh-kv span{color:#64748b}
.webssh-kv strong{color:#111827;text-align:right;word-break:break-word}
.webssh-linkrow{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:10px}
.webssh-linkrow .webssh-btn{width:100%}
.webssh-quick{display:grid;gap:8px}
.webssh-quick button{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:9px 10px;border:1px solid var(--ws-line);border-radius:8px;background:#fff;color:#111827;font-size:12px;font-weight:800;cursor:pointer;text-align:left}
.webssh-quick button span{color:#64748b;font-weight:700}
.webssh-empty{padding:18px;border:1px dashed #cbd5e1;border-radius:8px;background:#fff;color:#475569;font-size:13px;line-height:1.7}
.webssh-toast{position:fixed;right:18px;bottom:22px;z-index:9999;padding:10px 13px;border-radius:8px;background:rgba(15,23,42,.94);box-shadow:0 16px 36px rgba(15,23,42,.24);color:#f8fafc;font-size:13px;line-height:1.4;opacity:0;transform:translateY(10px);pointer-events:none;transition:opacity .16s ease,transform .16s ease}
.webssh-toast.show{opacity:1;transform:translateY(0)}
.webssh-toast.warn{background:rgba(146,64,14,.94)}
.webssh-stage.is-focus .webssh-topbar,.webssh-stage.is-focus .webssh-aside,.webssh-stage.is-focus .webssh-toolbar{display:none}
.webssh-stage.is-focus .webssh-main{grid-template-columns:1fr}
.webssh-stage.is-focus .webssh-terminal-frame{height:min(82vh,960px)}
.webssh-stage.is-embed .webssh-shell{border:0;border-radius:0;box-shadow:none}
.webssh-stage.is-embed .webssh-topbar{padding:12px 14px}
.webssh-stage.is-embed .webssh-label{display:none}
.webssh-stage.is-embed .webssh-title{font-size:18px}
.webssh-stage.is-embed .webssh-main{grid-template-columns:1fr}
.webssh-stage.is-embed .webssh-aside{display:none}
.webssh-stage.is-embed .webssh-terminal{padding:12px}
.webssh-stage.is-embed .webssh-terminal-head{display:none}
.webssh-stage.is-embed .webssh-livebar{margin-bottom:10px}
.webssh-stage.is-embed .webssh-toolbar{display:none}
.webssh-stage.is-embed .webssh-terminal-frame{height:72vh;min-height:460px}
.webssh-stage.is-embed .webssh-hint{display:none}
@keyframes websshFade{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}
.webssh-shell{animation:websshFade .22s ease both}
@media (max-width:980px){.webssh-main{grid-template-columns:1fr}.webssh-aside{border-left:0;border-top:1px solid var(--ws-line)}.webssh-topbar,.webssh-terminal-head,.webssh-toolbar{align-items:flex-start;flex-direction:column}.webssh-summary,.webssh-actions{justify-content:flex-start}.webssh-linkrow{grid-template-columns:1fr}}
@media (max-width:640px){.webssh-stage{padding:0 10px}.webssh-topbar{padding:14px}.webssh-terminal{padding:12px}.webssh-title{font-size:18px}.webssh-summary{gap:6px}.webssh-badge{font-size:11px}.webssh-terminal-frame{height:540px}.webssh-hint{align-items:flex-start;flex-direction:column}.webssh-btn{width:auto}}
</style>
<div id="webssh-stage" class="<%=stage_class%>">
  <div class="webssh-shell">
    <div class="webssh-topbar">
      <div class="webssh-identity">
        <div class="webssh-mark" aria-hidden="true">
          <svg viewBox="0 0 64 64" role="img">
            <rect x="10" y="14" width="44" height="36" rx="7" fill="rgba(255,255,255,.10)"/>
            <path d="M21 28 L28 33 L21 38" fill="none" stroke="#ffffff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
            <path d="M34 39 H44" fill="none" stroke="#7dd3fc" stroke-width="4" stroke-linecap="round"/>
          </svg>
        </div>
        <div class="webssh-titlewrap">
          <div class="webssh-label">NRadio Terminal</div>
          <h2 class="webssh-title">Web SSH / ttyd</h2>
        </div>
      </div>
      <div class="webssh-summary">
        <span id="webssh-runtime-badge" class="webssh-badge <%=status_data.runtime_tone%>"><%=status_data.runtime_label%></span>
        <span id="webssh-check-badge" class="webssh-badge <%=status_data.self_check_tone%>"><%=status_data.self_check_label%></span>
        <span class="webssh-badge soft">端口 <span id="webssh-port-inline"><%=status_data.bind_port%></span></span>
        <span class="webssh-badge soft">接口 <span id="webssh-iface-inline"><%=status_data.bind_iface_label%></span></span>
      </div>
    </div>

    <div class="webssh-main">
      <main class="webssh-terminal">
        <div class="webssh-terminal-head">
          <div>
            <h3 class="webssh-terminal-title">终端工作区</h3>
            <div class="webssh-terminal-meta">
              <span id="webssh-frame-state" class="webssh-badge soft">终端加载中</span>
              <span class="webssh-badge soft">协议 <span id="webssh-transport-inline"><%=status_data.transport_label%></span></span>
              <span class="webssh-badge soft">进程 <span id="webssh-proc-inline"><%=status_data.ttyd_proc_count%></span></span>
            </div>
          </div>
          <% if installed then %>
          <div class="webssh-actions">
            <button class="webssh-btn" type="button" onclick="return reload_terminal_frame();">重载</button>
            <button class="webssh-btn" type="button" onclick="return focus_terminal_frame();">激活键盘</button>
            <% if not embed_mode then %>
            <button class="webssh-btn" type="button" data-focus-toggle="1" aria-pressed="false" onclick="return toggle_focus_mode();">专注</button>
            <% end %>
            <a class="webssh-btn webssh-btn-primary" href="<%=status_data.ttyd_url%>" target="_blank" rel="noopener noreferrer">独立打开</a>
          </div>
          <% end %>
        </div>

        <% if installed and status_data.self_check_label ~= "通过" then %>
        <div class="webssh-alert">自检未通过。优先重载终端；如果仍为空白，使用独立打开。</div>
        <% end %>

        <% if installed then %>
        <div class="webssh-livebar">
          <div class="webssh-live-left">
            <span class="webssh-live-dot" aria-hidden="true"></span>
            <span id="webssh-live-url" class="webssh-live-url"><%=status_data.ttyd_url%></span>
          </div>
          <div class="webssh-live-actions">
            <button class="webssh-iconbtn" type="button" title="激活键盘" onclick="return focus_terminal_frame();">K</button>
            <button class="webssh-iconbtn" type="button" title="重载终端" onclick="return reload_terminal_frame();">R</button>
            <a class="webssh-iconbtn" title="独立打开" href="<%=status_data.ttyd_url%>" target="_blank" rel="noopener noreferrer">↗</a>
          </div>
        </div>
        <div class="webssh-toolbar">
          <div class="webssh-segmented">
            <button type="button" data-height="520" onclick="set_terminal_height(520, this)">紧凑</button>
            <button type="button" data-height="680" class="active" onclick="set_terminal_height(680, this)">标准</button>
            <button type="button" data-height="860" onclick="set_terminal_height(860, this)">扩展</button>
          </div>
          <div class="webssh-sync" id="webssh-updated">更新 <%=status_data.updated_at%></div>
        </div>

        <div class="webssh-framebox">
          <div class="webssh-dots" aria-hidden="true"><span></span><span></span><span></span></div>
          <div id="webssh-frame-hint" class="webssh-framealert">内嵌终端暂未完成连接。可以重载，或独立打开 ttyd 页面。</div>
          <iframe id="webssh-frame" src="<%=status_data.ttyd_url%>" data-current-src="<%=status_data.ttyd_url%>" title="ttyd Web SSH" loading="lazy" allow="clipboard-read; clipboard-write" tabindex="0" class="webssh-terminal-frame"></iframe>
        </div>

        <div class="webssh-hint">
          <span>默认进入 <code>/bin/sh --login</code>。键盘不响应时，点“激活键盘”后再点终端区域。</span>
          <span>独立页面：<a id="webssh-url" href="<%=status_data.ttyd_url%>" target="_blank" rel="noopener noreferrer"><%=status_data.ttyd_url%></a></span>
        </div>
        <% else %>
        <div class="webssh-empty">ttyd 未安装。请先运行总脚本第 3 项安装 Web SSH。</div>
        <% end %>
      </main>

      <% if not embed_mode then %>
      <aside class="webssh-aside">
        <section class="webssh-section">
          <h3>快速操作</h3>
          <% if installed then %>
          <div class="webssh-actions webssh-actions-start">
            <a class="webssh-btn webssh-btn-primary" href="<%=status_data.ttyd_url%>" target="_blank" rel="noopener noreferrer">打开终端</a>
            <button class="webssh-btn" type="button" onclick="return copy_text(document.getElementById('webssh-ssh').textContent, 'SSH 命令已复制');">复制 SSH</button>
            <a class="webssh-btn webssh-btn-dark" href="<%=restart_url%>">重启服务</a>
          </div>
          <div class="webssh-copyrow">
            <a id="webssh-url-side" class="webssh-code" href="<%=status_data.ttyd_url%>" target="_blank" rel="noopener noreferrer"><%=status_data.ttyd_url%></a>
            <button class="webssh-btn" type="button" onclick="return copy_text(document.getElementById('webssh-url-side').textContent, '终端地址已复制');">复制</button>
          </div>
          <div class="webssh-copyrow">
            <div id="webssh-ssh" class="webssh-code"><%=status_data.ssh_cmd%></div>
            <button class="webssh-btn" type="button" onclick="return copy_text(document.getElementById('webssh-ssh').textContent, 'SSH 命令已复制');">复制</button>
          </div>
          <div class="webssh-linkrow">
            <a class="webssh-btn" href="<%=dsp.build_url('admin', 'system', 'ttyd', 'overview')%>" target="_blank" rel="noopener noreferrer">LuCI</a>
            <a class="webssh-btn" href="<%=dsp.build_url('admin', 'system', 'ttyd', 'config')%>">配置</a>
          </div>
          <% else %>
          <div class="webssh-empty">没有可用操作。</div>
          <% end %>
        </section>

        <details class="webssh-details" open>
          <summary>运行状态</summary>
          <div class="webssh-details-body">
          <div class="webssh-kv"><span>运行</span><strong id="webssh-runtime-text"><%=status_data.runtime_label%></strong></div>
          <div class="webssh-kv"><span>自检</span><strong id="webssh-check-text"><%=status_data.self_check_label%></strong></div>
          <div class="webssh-kv"><span>协议</span><strong id="webssh-transport-text"><%=status_data.transport_label%></strong></div>
          <div class="webssh-kv"><span>端口</span><strong id="webssh-port-text"><%=status_data.bind_port%></strong></div>
          <div class="webssh-kv"><span>接口</span><strong id="webssh-iface-text"><%=status_data.bind_iface_label%></strong></div>
          <div class="webssh-kv"><span>客户端</span><strong id="webssh-limit-text"><%=status_data.client_limit_label%></strong></div>
          <div class="webssh-kv"><span>进程</span><strong id="webssh-proc-text"><%=status_data.ttyd_proc_count%></strong></div>
          <div class="webssh-kv"><span>监听</span><strong id="webssh-port-check"><%=status_data.port_check_label%></strong></div>
          <div class="webssh-kv"><span>绑定</span><strong id="webssh-iface-check"><%=status_data.iface_check_label%></strong></div>
          </div>
        </details>

        <details class="webssh-details">
          <summary>排查命令</summary>
          <div class="webssh-details-body">
          <div class="webssh-quick">
            <button type="button" onclick="return copy_text('logread | tail -50', '日志命令已复制');">最近日志 <span>logread</span></button>
            <button type="button" onclick="return copy_text('netstat -lnt | grep 7681', '监听命令已复制');">监听端口 <span>7681</span></button>
            <button type="button" onclick="return copy_text('/etc/init.d/ttyd restart', '重启命令已复制');">重启服务 <span>ttyd</span></button>
          </div>
          <% if status_data.listen_line ~= "" then %>
          <div style="margin-top:10px" class="webssh-code" id="webssh-listen"><%=status_data.listen_line%></div>
          <% end %>
          </div>
        </details>
      </aside>
      <% end %>
    </div>
  </div>
</div>
<div id="webssh-toast" class="webssh-toast"></div>
<script type="text/javascript">//<![CDATA[
var WEBSSH_STATUS_URL = '<%=status_url%>';
var WEBSSH_EMBED_MODE = <%=embed_mode and "true" or "false"%>;
var WEBSSH_STORAGE_PREFIX = WEBSSH_EMBED_MODE ? 'webssh-embed' : 'webssh';
function show_toast(message, tone){var toast=document.getElementById('webssh-toast');if(!toast)return;toast.textContent=message;toast.className='webssh-toast show'+(tone?' '+tone:'');if(window.__websshToastTimer)window.clearTimeout(window.__websshToastTimer);window.__websshToastTimer=window.setTimeout(function(){toast.className='webssh-toast';},1800);}
function copy_text(value, success_text){if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(value).then(function(){show_toast(success_text||'已复制');}).catch(function(){window.prompt('复制内容',value);});}else{window.prompt('复制内容',value);}return false;}
function set_badge_state(el, tone, text){if(!el)return;el.className='webssh-badge '+tone;el.textContent=text;}
function set_text(id, value){var el=document.getElementById(id);if(el)el.textContent=value;}
function set_code(id, value, href){var el=document.getElementById(id);if(!el)return;el.textContent=value;if(href)el.href=href;}
function set_href(id, value){var el=document.getElementById(id);if(el&&value)el.href=value;}
function set_terminal_height(height, el){var frame=document.getElementById('webssh-frame');var buttons=document.querySelectorAll('.webssh-segmented button[data-height]');var i;if(frame)frame.style.height=String(height)+'px';if(window.localStorage)localStorage.setItem(WEBSSH_STORAGE_PREFIX+'-terminal-height',String(height));for(i=0;i<buttons.length;i++)buttons[i].classList.remove('active');if(el)el.classList.add('active');return false;}
function restore_terminal_height(){if(!window.localStorage)return;var saved=localStorage.getItem(WEBSSH_STORAGE_PREFIX+'-terminal-height');if(!saved)return;var button=document.querySelector('.webssh-segmented button[data-height="'+saved+'"]');if(button)set_terminal_height(parseInt(saved,10),button);}
function sync_focus_buttons(){var stage=document.getElementById('webssh-stage');var buttons=document.querySelectorAll('[data-focus-toggle]');var active=stage&&stage.classList.contains('is-focus');var i;for(i=0;i<buttons.length;i++){buttons[i].setAttribute('aria-pressed',active?'true':'false');buttons[i].textContent=active?'退出专注':'专注';}}
function toggle_focus_mode(force_state){if(WEBSSH_EMBED_MODE)return false;var stage=document.getElementById('webssh-stage');var active;if(!stage)return false;active=(typeof force_state==='boolean')?force_state:!stage.classList.contains('is-focus');stage.classList.toggle('is-focus',active);if(window.localStorage)localStorage.setItem(WEBSSH_STORAGE_PREFIX+'-focus-mode',active?'1':'0');sync_focus_buttons();return false;}
function restore_focus_mode(){if(WEBSSH_EMBED_MODE)return;try{if(window.localStorage&&localStorage.getItem(WEBSSH_STORAGE_PREFIX+'-focus-mode')==='1')toggle_focus_mode(true);else sync_focus_buttons();}catch(e){sync_focus_buttons();}}
function arm_terminal_timeout(){var state=document.getElementById('webssh-frame-state');var hint=document.getElementById('webssh-frame-hint');if(window.__websshFrameTimer)window.clearTimeout(window.__websshFrameTimer);window.__websshFrameLoaded=false;window.__websshFrameTimer=window.setTimeout(function(){if(window.__websshFrameLoaded)return;if(state)set_badge_state(state,'warn','终端握手中');if(hint)hint.style.display='block';},5000);}
function clear_terminal_timeout(){if(window.__websshFrameTimer)window.clearTimeout(window.__websshFrameTimer);window.__websshFrameLoaded=true;}
function reload_terminal_frame(){var frame=document.getElementById('webssh-frame');var state=document.getElementById('webssh-frame-state');var hint=document.getElementById('webssh-frame-hint');if(!frame)return false;if(state)set_badge_state(state,'soft','终端重新加载中');if(hint)hint.style.display='none';arm_terminal_timeout();frame.src=frame.getAttribute('data-current-src')||frame.src;return false;}
function focus_terminal_frame(){var frame=document.getElementById('webssh-frame');if(!frame)return false;try{frame.setAttribute('tabindex','0');frame.focus();}catch(e){}try{if(frame.contentWindow&&frame.contentWindow.focus)frame.contentWindow.focus();}catch(e){}show_toast('键盘焦点已激活');return false;}
function sync_terminal_url(next_url){var frame=document.getElementById('webssh-frame');var current='';if(!frame||!next_url)return;current=frame.getAttribute('data-current-src')||'';if(!current){frame.setAttribute('data-current-src',frame.src||next_url);current=frame.getAttribute('data-current-src')||'';}if(current!==next_url){frame.setAttribute('data-current-src',next_url);frame.src=next_url;arm_terminal_timeout();}}
function apply_status(data){set_badge_state(document.getElementById('webssh-runtime-badge'),data.runtime_tone||'soft',data.runtime_label||'未知');set_badge_state(document.getElementById('webssh-check-badge'),data.self_check_tone||'soft',data.self_check_label||'未知');set_text('webssh-runtime-text',data.runtime_label||'未知');set_text('webssh-check-text',data.self_check_label||'未知');set_text('webssh-transport-text',data.transport_label||'-');set_text('webssh-transport-inline',data.transport_label||'-');set_text('webssh-port-text',data.bind_port||'-');set_text('webssh-port-inline',data.bind_port||'-');set_text('webssh-iface-text',data.bind_iface_label||'-');set_text('webssh-iface-inline',data.bind_iface_label||'-');set_text('webssh-limit-text',data.client_limit_label||'-');set_text('webssh-proc-text',data.ttyd_proc_count||'0');set_text('webssh-proc-inline',data.ttyd_proc_count||'0');set_text('webssh-port-check',data.port_check_label||'-');set_text('webssh-iface-check',data.iface_check_label||'-');set_text('webssh-updated','更新 '+(data.updated_at||'--:--:--'));set_text('webssh-live-url',data.ttyd_url||'');set_code('webssh-url',data.ttyd_url||'',data.ttyd_url||'');set_code('webssh-url-side',data.ttyd_url||'',data.ttyd_url||'');set_href('webssh-url',data.ttyd_url||'');set_href('webssh-url-side',data.ttyd_url||'');set_code('webssh-ssh',data.ssh_cmd||'');if(document.getElementById('webssh-listen')&&data.listen_line)set_code('webssh-listen',data.listen_line);sync_terminal_url(data.ttyd_url||'');}
function poll_status(initial){var xhr=new XMLHttpRequest();xhr.open('GET',WEBSSH_STATUS_URL,true);xhr.onreadystatechange=function(){if(xhr.readyState!==4)return;if(xhr.status>=200&&xhr.status<300){try{apply_status(JSON.parse(xhr.responseText||'{}'));}catch(e){if(!initial)show_toast('状态刷新失败，保留上次结果','warn');}}else if(!initial){show_toast('状态刷新失败，保留上次结果','warn');}};xhr.send(null);}
(function(){var frame=document.getElementById('webssh-frame');var state=document.getElementById('webssh-frame-state');var hint=document.getElementById('webssh-frame-hint');restore_terminal_height();restore_focus_mode();poll_status(true);if(!frame||!state||!hint){window.setInterval(function(){poll_status(false);},12000);return;}frame.addEventListener('load',function(){clear_terminal_timeout();frame.setAttribute('data-current-src',frame.src||frame.getAttribute('data-current-src')||'');set_badge_state(state,'ok','终端已连接');hint.style.display='none';window.setTimeout(function(){focus_terminal_frame();},140);});frame.addEventListener('mouseenter',function(){focus_terminal_frame();});frame.addEventListener('click',function(){focus_terminal_frame();});arm_terminal_timeout();window.setInterval(function(){poll_status(false);},12000);})();
//]]></script>
<% if not embed_mode then %><%+footer%><% end %>
<% else %>
<%
local dsp = require "luci.dispatcher"
local http = require "luci.http"
local webssh = require "luci.controller.nradio_adv.webssh"
local status_data = webssh.collect_status()
local installed = status_data.installed
local restart_url = dsp.build_url("nradioadv", "system", "webssh", "restart")
local status_url = dsp.build_url("nradioadv", "system", "webssh", "status")
local embed_mode = http.formvalue("embed") == "1" or http.formvalue("embed") == "true"
local stage_class = embed_mode and "webssh-stage is-embed" or "webssh-stage"
%>
<% if not embed_mode then %><%+header%><% end %>
<style>
.webssh-stage{--ws-ink:#0f172a;--ws-ink-soft:#475569;--ws-line:#dbe5ee;--ws-accent:#38bdf8;--ws-accent-strong:#2563eb;--ws-surface:#ffffff;--ws-surface-soft:#f8fafc;max-width:1180px;margin:18px auto 30px;padding:0 18px}
.webssh-stage.is-embed{max-width:none;margin:0;padding:0}
.webssh-masthead{position:relative;display:flex;flex-wrap:wrap;align-items:flex-start;justify-content:space-between;gap:20px;padding:6px 0 20px;animation:websshFadeUp .42s ease both}
.webssh-masthead:before{content:"";position:absolute;left:-40px;top:-18px;width:220px;height:220px;border-radius:999px;background:radial-gradient(circle,rgba(37,99,235,.13) 0%,rgba(37,99,235,0) 72%);pointer-events:none}
.webssh-brand{position:relative;z-index:1;display:flex;gap:16px;min-width:0;max-width:760px}
.webssh-brandmark{flex:0 0 auto;width:58px;height:58px;border-radius:18px;background:linear-gradient(135deg,#0f172a 0%,#1d4ed8 100%);box-shadow:0 18px 34px rgba(15,23,42,.18);display:flex;align-items:center;justify-content:center}
.webssh-brandmark svg{width:32px;height:32px;display:block}
.webssh-eyebrow{display:inline-flex;align-items:center;gap:9px;padding:6px 12px;border-radius:999px;background:#e0ecff;color:#1d4ed8;font-size:12px;font-weight:700;letter-spacing:.03em;text-transform:uppercase}
.webssh-eyebrow-dot{width:8px;height:8px;border-radius:999px;background:currentColor;box-shadow:0 0 0 6px rgba(29,78,216,.12)}
.webssh-title{margin:10px 0 0;font-size:34px;line-height:1.06;color:var(--ws-ink);letter-spacing:-.03em}
.webssh-desc{margin:12px 0 0;max-width:62ch;color:#5b6472;font-size:14px;line-height:1.75}
.webssh-meta{display:flex;flex-wrap:wrap;gap:9px;margin-top:16px}
.webssh-badge{display:inline-flex;align-items:center;gap:8px;padding:6px 12px;border-radius:999px;font-size:12px;font-weight:700;letter-spacing:.02em}
.webssh-badge.ok{background:#dcfce7;color:#166534}
.webssh-badge.warn{background:#fff4d6;color:#9a6700}
.webssh-badge.off{background:#fee2e2;color:#991b1b}
.webssh-badge.soft{background:#eef2ff;color:#334155}
.webssh-actions{position:relative;z-index:1;display:flex;flex-wrap:wrap;justify-content:flex-end;gap:10px;max-width:420px}
.webssh-btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;min-height:42px;padding:10px 15px;border-radius:14px;border:1px solid var(--ws-line);background:#fff;color:var(--ws-ink);text-decoration:none;font-size:13px;font-weight:700;line-height:1.2;transition:transform .18s ease,box-shadow .18s ease,border-color .18s ease,background-color .18s ease,color .18s ease;cursor:pointer}
.webssh-btn:hover{transform:translateY(-1px);border-color:#94a3b8;box-shadow:0 12px 24px rgba(15,23,42,.08)}
.webssh-btn-primary{background:linear-gradient(135deg,#1d4ed8 0%,#0ea5e9 100%);border-color:transparent;color:#fff;box-shadow:0 16px 32px rgba(29,78,216,.22)}
.webssh-btn-primary:hover{color:#fff;box-shadow:0 20px 36px rgba(29,78,216,.28)}
.webssh-btn-ghost{background:#0f172a;border-color:#0f172a;color:#dbeafe}
.webssh-btn-ghost:hover{color:#fff;border-color:#1e293b}
.webssh-btn-soft{background:#eff6ff;border-color:#bfdbfe;color:#1d4ed8}
.webssh-btn-soft:hover{border-color:#60a5fa;color:#1e3a8a}
.webssh-focus-btn[aria-pressed="true"]{background:#082f49;border-color:#082f49;color:#dbeafe;box-shadow:0 16px 30px rgba(8,47,73,.24)}
.webssh-warning{margin:0 0 18px;padding:13px 15px;border:1px solid #fed7aa;border-radius:16px;background:#fff7ed;color:#9a3412;font-size:13px;line-height:1.7;animation:websshFadeUp .48s ease .02s both}
.webssh-workspace{display:grid;grid-template-columns:minmax(0,1.45fr) minmax(320px,.72fr);gap:18px;align-items:start}
.webssh-terminal-panel{position:relative;overflow:hidden;padding:18px;border:1px solid #0f172a;border-radius:24px;background:radial-gradient(circle at top left,rgba(59,130,246,.18) 0%,rgba(59,130,246,0) 28%),linear-gradient(180deg,#0f172a 0%,#111827 100%);box-shadow:0 26px 64px rgba(15,23,42,.24);animation:websshFadeUp .5s ease .06s both}
.webssh-terminal-panel:after{content:"";position:absolute;inset:0;border-radius:24px;box-shadow:inset 0 0 0 1px rgba(255,255,255,.05);pointer-events:none}
.webssh-compactbar{display:none;align-items:flex-start;justify-content:space-between;gap:16px;padding:0 0 16px;margin-bottom:16px;border-bottom:1px solid rgba(148,163,184,.18)}
.webssh-compactlabel{display:inline-flex;align-items:center;gap:8px;padding:5px 10px;border-radius:999px;background:rgba(125,211,252,.12);color:#7dd3fc;font-size:11px;font-weight:700;letter-spacing:.04em;text-transform:uppercase}
.webssh-compacttitle{margin:10px 0 0;font-size:24px;line-height:1.08;color:#f8fafc;letter-spacing:-.03em}
.webssh-compactmeta{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}
.webssh-panelhead{display:flex;flex-wrap:wrap;align-items:flex-start;justify-content:space-between;gap:16px}
.webssh-kicker{display:inline-flex;align-items:center;gap:8px;color:#7dd3fc;font-size:12px;font-weight:700;letter-spacing:.08em;text-transform:uppercase}
.webssh-paneltitle{margin:8px 0 0;font-size:22px;line-height:1.08;color:#f8fafc;letter-spacing:-.03em}
.webssh-paneldesc{margin:8px 0 0;max-width:56ch;color:rgba(226,232,240,.72);font-size:13px;line-height:1.7}
.webssh-panelmeta{display:flex;flex-wrap:wrap;gap:8px;margin-top:14px}
.webssh-panelmeta .webssh-badge{background:rgba(255,255,255,.08);color:#e2e8f0}
.webssh-panelmeta .webssh-badge.ok{background:rgba(34,197,94,.18);color:#dcfce7}
.webssh-panelmeta .webssh-badge.warn{background:rgba(245,158,11,.16);color:#fde68a}
.webssh-panelmeta .webssh-badge.off{background:rgba(239,68,68,.16);color:#fecaca}
.webssh-toolbar{display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:12px;margin-top:18px;padding-top:16px;border-top:1px solid rgba(148,163,184,.18)}
.webssh-toolbar-right{display:flex;flex-wrap:wrap;align-items:center;gap:10px}
.webssh-segmented{display:inline-flex;gap:6px;padding:4px;border-radius:999px;background:rgba(255,255,255,.06);box-shadow:inset 0 0 0 1px rgba(148,163,184,.16)}
.webssh-segmented button{display:inline-flex;align-items:center;justify-content:center;padding:8px 12px;border:0;border-radius:999px;background:transparent;color:#94a3b8;font-size:12px;font-weight:700;cursor:pointer;transition:background-color .18s ease,color .18s ease,transform .18s ease}
.webssh-segmented button.active{background:#fff;color:#0f172a;transform:translateY(-1px)}
.webssh-segmented button:hover{color:#f8fafc}
.webssh-inlinehint{display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:10px;margin-top:14px;padding:12px 14px;border-radius:16px;background:rgba(255,255,255,.06);box-shadow:inset 0 0 0 1px rgba(148,163,184,.16);color:#cbd5e1;font-size:12px;line-height:1.7}
.webssh-inlinehint strong{color:#f8fafc}
.webssh-inlinehint .webssh-btn{min-height:36px;padding:8px 12px;border-radius:12px;background:rgba(255,255,255,.08);border-color:rgba(148,163,184,.18);color:#f8fafc}
.webssh-framewrap{position:relative;margin-top:16px}
.webssh-framealert{display:none;position:absolute;left:16px;right:16px;top:16px;z-index:2;padding:12px 14px;border-radius:14px;background:rgba(127,29,29,.88);box-shadow:0 16px 30px rgba(15,23,42,.26);color:#fff;font-size:13px;line-height:1.65}
.webssh-terminal-frame{display:block;width:100%;height:680px;border:0;border-radius:18px;background:#020617;box-shadow:inset 0 0 0 1px rgba(148,163,184,.14);transition:height .18s ease,box-shadow .18s ease}
.webssh-terminal-frame:focus{box-shadow:0 0 0 1px rgba(125,211,252,.5),0 0 0 8px rgba(14,165,233,.08)}
.webssh-footline{display:flex;flex-wrap:wrap;justify-content:space-between;gap:10px;margin-top:14px;color:rgba(226,232,240,.72);font-size:12px;line-height:1.7}
.webssh-sync{display:inline-flex;align-items:center;gap:8px;color:rgba(226,232,240,.8);font-size:12px}
.webssh-sync-dot{width:7px;height:7px;border-radius:999px;background:#38bdf8;box-shadow:0 0 0 6px rgba(56,189,248,.12)}
.webssh-sidepanel{position:sticky;top:18px;padding:18px;border:1px solid var(--ws-line);border-radius:22px;background:linear-gradient(180deg,#fbfdff 0%,#f8fafc 100%);box-shadow:0 22px 56px rgba(15,23,42,.08);animation:websshFadeUp .5s ease .14s both}
.webssh-sidepanel section+section{margin-top:18px;padding-top:18px;border-top:1px solid #e8edf3}
.webssh-sidepanel h3{margin:0 0 12px;font-size:14px;color:var(--ws-ink)}
.webssh-kv{display:flex;justify-content:space-between;gap:14px;padding:10px 0;border-bottom:1px solid #eef2f7;font-size:13px}
.webssh-kv:last-child{border-bottom:0;padding-bottom:0}
.webssh-kv span{color:#64748b}
.webssh-kv strong{color:var(--ws-ink);text-align:right;word-break:break-word}
.webssh-code{display:block;padding:14px 16px;border-radius:16px;background:#0f172a;color:#dbeafe;font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace;font-size:12px;line-height:1.75;word-break:break-all;box-shadow:inset 0 0 0 1px rgba(148,163,184,.18)}
.webssh-linkstack{display:grid;gap:10px;margin-top:12px}
.webssh-link{display:block;padding:11px 13px;border-radius:14px;border:1px solid var(--ws-line);background:#fff;color:#334155;text-decoration:none;font-size:12px;line-height:1.6;transition:border-color .18s ease,transform .18s ease,box-shadow .18s ease}
.webssh-link strong{display:block;margin-bottom:2px;color:var(--ws-ink);font-size:12px}
.webssh-link:hover{transform:translateY(-1px);border-color:#93c5fd;box-shadow:0 12px 24px rgba(15,23,42,.06)}
.webssh-checklist{margin:0;padding-left:18px;color:#475569;font-size:13px;line-height:1.8}
.webssh-checklist li+li{margin-top:5px}
.webssh-quickgrid{display:grid;gap:8px;margin-top:12px}
.webssh-quickgrid button{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:10px 12px;border:1px solid var(--ws-line);border-radius:12px;background:#fff;color:var(--ws-ink);font-size:12px;font-weight:700;cursor:pointer;transition:border-color .18s ease,transform .18s ease}
.webssh-quickgrid button span{color:#64748b;font-weight:600}
.webssh-quickgrid button:hover{transform:translateY(-1px);border-color:#93c5fd}
.webssh-toast{position:fixed;right:18px;bottom:22px;z-index:9999;padding:11px 14px;border-radius:14px;background:rgba(15,23,42,.94);box-shadow:0 18px 40px rgba(15,23,42,.24);color:#f8fafc;font-size:13px;line-height:1.4;opacity:0;transform:translateY(12px);pointer-events:none;transition:opacity .18s ease,transform .18s ease}
.webssh-toast.show{opacity:1;transform:translateY(0)}
.webssh-toast.warn{background:rgba(146,64,14,.94)}
.webssh-empty{margin-top:18px;padding:16px;border-radius:18px;background:#fff;border:1px solid var(--ws-line);color:#475569;font-size:13px;line-height:1.8}
.webssh-stage.is-focus .webssh-masthead,.webssh-stage.is-focus .webssh-warning,.webssh-stage.is-focus .webssh-sidepanel{display:none}
.webssh-stage.is-focus .webssh-workspace{grid-template-columns:1fr}
.webssh-stage.is-focus .webssh-terminal-frame{height:min(82vh,960px)}
.webssh-stage.is-focus .webssh-terminal-panel{box-shadow:0 32px 80px rgba(15,23,42,.3)}
.webssh-stage.is-embed .webssh-masthead,.webssh-stage.is-embed .webssh-sidepanel{display:none}
.webssh-stage.is-embed .webssh-workspace{grid-template-columns:1fr}
.webssh-stage.is-embed .webssh-terminal-panel{border-radius:20px;padding:16px 16px 14px}
.webssh-stage.is-embed .webssh-compactbar{display:flex}
.webssh-stage.is-embed .webssh-paneltitle{font-size:20px}
.webssh-stage.is-embed .webssh-paneldesc{max-width:none}
.webssh-stage.is-embed .webssh-terminal-frame{height:72vh;min-height:460px}
.webssh-stage.is-embed .webssh-footline{display:none}
@keyframes websshFadeUp{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:translateY(0)}}
@media (max-width:980px){.webssh-workspace{grid-template-columns:1fr}.webssh-sidepanel{position:static}.webssh-actions{justify-content:flex-start;max-width:none}.webssh-stage.is-focus .webssh-masthead{display:none}}
@media (max-width:640px){.webssh-stage{padding:0 14px}.webssh-stage.is-embed{padding:0}.webssh-title{font-size:28px}.webssh-terminal-frame{height:540px}.webssh-masthead{padding-bottom:16px}.webssh-inlinehint,.webssh-toolbar,.webssh-compactbar{align-items:flex-start}.webssh-compacttitle{font-size:20px}}
</style>
<div id="webssh-stage" class="<%=stage_class%>">
  <% if not embed_mode then %>
  <div class="webssh-masthead">
    <div class="webssh-brand">
      <div class="webssh-brandmark" aria-hidden="true">
        <svg viewBox="0 0 64 64" role="img">
          <rect x="9" y="13" width="46" height="38" rx="8" fill="rgba(255,255,255,.12)"/>
          <path d="M21 28 L28 33 L21 38" fill="none" stroke="#ffffff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M33 39 H43" fill="none" stroke="#7dd3fc" stroke-width="4" stroke-linecap="round"/>
        </svg>
      </div>
      <div>
        <div class="webssh-eyebrow"><span class="webssh-eyebrow-dot"></span>浏览器终端入口</div>
        <h2 class="webssh-title">Web SSH / ttyd</h2>
        <div class="webssh-desc">把终端本身放回首屏中心，状态和入口退到第二层。先在工作区里操作，再决定是否跳去独立页面或 LuCI 配置。</div>
        <div class="webssh-meta">
          <span id="webssh-runtime-badge" class="webssh-badge <%=status_data.runtime_tone%>"><%=status_data.runtime_label%></span>
          <span class="webssh-badge soft">协议 <span id="webssh-transport-inline"><%=status_data.transport_label%></span></span>
          <span class="webssh-badge soft">端口 <span id="webssh-port-inline"><%=status_data.bind_port%></span></span>
          <span class="webssh-badge soft">接口 <span id="webssh-iface-inline"><%=status_data.bind_iface_label%></span></span>
        </div>
      </div>
    </div>
    <div class="webssh-actions">
      <% if installed then %>
        <a class="webssh-btn webssh-btn-primary" href="<%=status_data.ttyd_url%>" target="_blank" rel="noopener noreferrer">打开终端</a>
        <a class="webssh-btn" href="#" onclick="return copy_text('<%=status_data.ssh_cmd%>', 'SSH 命令已复制');">复制 SSH 命令</a>
        <a class="webssh-btn webssh-btn-ghost" href="<%=restart_url%>">重启 ttyd</a>
      <% else %>
        <div class="webssh-empty">ttyd 还没安装。请先运行总脚本的 `3. ttyd / Web SSH`，然后再回到这里继续使用。</div>
      <% end %>
    </div>
  </div>
  <% if installed and status_data.self_check_label ~= "通过" then %>
  <div class="webssh-warning">当前自检还没完全通过。先试“重启 ttyd”，如果内嵌终端仍然空白，优先走“打开终端”进入独立页面。</div>
  <% end %>
  <% end %>
  <div class="webssh-workspace">
    <section class="webssh-terminal-panel">
      <div class="webssh-compactbar">
        <div>
          <div class="webssh-compactlabel">嵌入工作区</div>
          <h2 class="webssh-compacttitle">Web SSH / ttyd</h2>
          <div class="webssh-compactmeta">
            <span id="webssh-runtime-badge-compact" class="webssh-badge <%=status_data.runtime_tone%>"><%=status_data.runtime_label%></span>
            <span class="webssh-badge soft">协议 <span id="webssh-transport-inline-compact"><%=status_data.transport_label%></span></span>
            <span class="webssh-badge soft">端口 <span id="webssh-port-inline-compact"><%=status_data.bind_port%></span></span>
            <span class="webssh-badge soft">接口 <span id="webssh-iface-inline-compact"><%=status_data.bind_iface_label%></span></span>
          </div>
        </div>
        <% if installed then %>
        <div class="webssh-actions">
          <a class="webssh-btn webssh-btn-primary" href="<%=status_data.ttyd_url%>" target="_blank" rel="noopener noreferrer">独立打开</a>
          <a class="webssh-btn" href="#" onclick="return copy_text('<%=status_data.ssh_cmd%>', 'SSH 命令已复制');">复制 SSH</a>
        </div>
        <% end %>
      </div>

      <% if embed_mode and installed and status_data.self_check_label ~= "通过" then %>
      <div class="webssh-warning">当前自检还没完全通过。先试“重载终端”，如果还是空白，再切到独立页面。</div>
      <% end %>

      <div class="webssh-panelhead">
        <div>
          <div class="webssh-kicker">终端工作区</div>
          <h3 class="webssh-paneltitle"><%=embed_mode and "把操作留在这张卡片里" or "让工作区成为第一层"%></h3>
          <% if not embed_mode then %>
          <div class="webssh-paneldesc">默认把 ttyd 留在这个工作区里，键盘激活、尺寸切换、状态刷新和失败提示都在这里完成。</div>
          <% end %>
          <div class="webssh-panelmeta">
            <span id="webssh-check-badge" class="webssh-badge <%=status_data.self_check_tone%>"><%=status_data.self_check_label%></span>
            <span id="webssh-frame-state" class="webssh-badge soft">终端加载中</span>
            <span class="webssh-badge soft">协议 <span id="webssh-transport-inline-panel"><%=status_data.transport_label%></span></span>
            <span class="webssh-badge soft">进程 <span id="webssh-proc-inline"><%=status_data.ttyd_proc_count%></span></span>
          </div>
        </div>
        <% if installed then %>
        <div class="webssh-actions">
          <% if not embed_mode then %>
          <button class="webssh-btn webssh-btn-soft webssh-focus-btn" type="button" data-focus-toggle="1" aria-pressed="false" onclick="return toggle_focus_mode();">专注模式</button>
          <% end %>
          <a class="webssh-btn webssh-btn-primary" href="<%=status_data.ttyd_url%>" target="_blank" rel="noopener noreferrer">全屏打开</a>
          <a class="webssh-btn" href="#" onclick="return reload_terminal_frame();">重载终端</a>
        </div>
        <% end %>
      </div>
      <% if installed then %>
      <div class="webssh-toolbar">
        <div class="webssh-segmented">
          <button type="button" data-height="520" onclick="set_terminal_height(520, this)">紧凑</button>
          <button type="button" data-height="680" class="active" onclick="set_terminal_height(680, this)">标准</button>
          <button type="button" data-height="860" onclick="set_terminal_height(860, this)">扩展</button>
        </div>
        <div class="webssh-toolbar-right">
          <div class="webssh-sync"><span class="webssh-sync-dot"></span><span id="webssh-updated">更新 <%=status_data.updated_at%></span></div>
        </div>
      </div>
      <div class="webssh-inlinehint">
        <span><strong>如果能看到终端但打不了字：</strong>先点一次“激活键盘”，再点击终端区域。</span>
        <button class="webssh-btn" type="button" onclick="return focus_terminal_frame();">激活键盘</button>
      </div>
      <div class="webssh-framewrap">
        <div id="webssh-frame-hint" class="webssh-framealert">内嵌终端还没正常显示，可能是浏览器拦截 iframe、ttyd 刚重启，或握手尚未完成。先试“重载终端”，再试“全屏打开”。</div>
        <iframe id="webssh-frame" src="<%=status_data.ttyd_url%>" data-current-src="<%=status_data.ttyd_url%>" title="ttyd Web SSH" loading="lazy" allow="clipboard-read; clipboard-write" tabindex="0" class="webssh-terminal-frame"></iframe>
      </div>
      <div class="webssh-footline">
        <span>默认进入 <code>/bin/sh --login</code>，适合应急维护和救援操作。</span>
        <span><%=embed_mode and "卡片里保持轻量，复杂调整再进独立页面。" or "独立页面通常比 iframe 更稳定。"%></span>
      </div>
      <% else %>
      <div class="webssh-empty">当前没有可用终端。先安装 ttyd，再回到这个工作区。</div>
      <% end %>
    </section>

    <% if not embed_mode then %>
    <aside class="webssh-sidepanel">
      <section>
        <h3>直接入口</h3>
        <a id="webssh-url" class="webssh-code" href="<%=status_data.ttyd_url%>" target="_blank" rel="noopener noreferrer"><%=status_data.ttyd_url%></a>
        <div style="margin-top:12px" id="webssh-ssh" class="webssh-code"><%=status_data.ssh_cmd%></div>
        <div class="webssh-linkstack">
          <a class="webssh-link" href="<%=dsp.build_url('admin', 'system', 'ttyd', 'overview')%>" target="_blank" rel="noopener noreferrer"><strong>LuCI 页面</strong>查看 ttyd 原生概览页</a>
          <a class="webssh-link" href="<%=dsp.build_url('admin', 'system', 'ttyd', 'config')%>"><strong>配置页面</strong>调整监听端口、认证与接口</a>
        </div>
      </section>
      <section>
        <h3>运行摘要</h3>
        <div class="webssh-kv"><span>运行状态</span><strong id="webssh-runtime-text"><%=status_data.runtime_label%></strong></div>
        <div class="webssh-kv"><span>自检结果</span><strong id="webssh-check-text"><%=status_data.self_check_label%></strong></div>
        <div class="webssh-kv"><span>访问协议</span><strong id="webssh-transport-text"><%=status_data.transport_label%></strong></div>
        <div class="webssh-kv"><span>监听端口</span><strong id="webssh-port-text"><%=status_data.bind_port%></strong></div>
        <div class="webssh-kv"><span>绑定接口</span><strong id="webssh-iface-text"><%=status_data.bind_iface_label%></strong></div>
        <div class="webssh-kv"><span>客户端上限</span><strong id="webssh-limit-text"><%=status_data.client_limit_label%></strong></div>
        <div class="webssh-kv"><span>进程数</span><strong id="webssh-proc-text"><%=status_data.ttyd_proc_count%></strong></div>
        <div class="webssh-kv"><span>端口检查</span><strong id="webssh-port-check"><%=status_data.port_check_label%></strong></div>
        <div class="webssh-kv"><span>接口检查</span><strong id="webssh-iface-check"><%=status_data.iface_check_label%></strong></div>
      </section>
      <section>
        <h3>排障顺序</h3>
        <ol class="webssh-checklist">
          <li>先看“运行摘要”，确认协议、端口和接口是否还在。</li>
          <li>内嵌终端空白时，先重载，再切到独立页面。</li>
          <li>仍然异常时，复制命令直接排查服务和路由。</li>
        </ol>
        <div class="webssh-quickgrid">
          <button type="button" onclick="return copy_text('logread | tail -50', '最近日志命令已复制');">最近日志<span>logread</span></button>
          <button type="button" onclick="return copy_text('ip route', '路由检查命令已复制');">查看路由<span>ip route</span></button>
          <button type="button" onclick="return copy_text('/etc/init.d/ttyd restart', 'ttyd 重启命令已复制');">重启服务<span>/etc/init.d/ttyd restart</span></button>
        </div>
        <% if status_data.listen_line ~= "" then %>
        <div style="margin-top:12px" class="webssh-code" id="webssh-listen"><%=status_data.listen_line%></div>
        <% end %>
      </section>
    </aside>
    <% end %>
  </div>
</div>
<div id="webssh-toast" class="webssh-toast"></div>
<script type="text/javascript">//<![CDATA[
var WEBSSH_STATUS_URL = '<%=status_url%>';
var WEBSSH_EMBED_MODE = <%=embed_mode and "true" or "false"%>;
var WEBSSH_STORAGE_PREFIX = WEBSSH_EMBED_MODE ? 'webssh-embed' : 'webssh';
function show_toast(message, tone){var toast=document.getElementById('webssh-toast');if(!toast)return;toast.textContent=message;toast.className='webssh-toast show'+(tone?' '+tone:'');if(window.__websshToastTimer)window.clearTimeout(window.__websshToastTimer);window.__websshToastTimer=window.setTimeout(function(){toast.className='webssh-toast';},1800);}
function copy_text(value, success_text){if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(value).then(function(){show_toast(success_text||'已复制');}).catch(function(){window.prompt('复制内容',value);});}else{window.prompt('复制内容',value);}return false;}
function set_badge_state(el, tone, text){if(!el)return;el.className='webssh-badge '+tone;el.textContent=text;}
function set_text(id, value){var el=document.getElementById(id);if(el)el.textContent=value;}
function set_code(id, value, href){var el=document.getElementById(id);if(!el)return;el.textContent=value;if(href)el.href=href;}
function set_terminal_height(height, el){var frame=document.getElementById('webssh-frame');var buttons=document.querySelectorAll('.webssh-segmented button[data-height]');var i;if(frame)frame.style.height=String(height)+'px';if(window.localStorage)localStorage.setItem(WEBSSH_STORAGE_PREFIX+'-terminal-height',String(height));for(i=0;i<buttons.length;i++)buttons[i].classList.remove('active');if(el)el.classList.add('active');return false;}
function restore_terminal_height(){if(!window.localStorage)return;var saved=localStorage.getItem(WEBSSH_STORAGE_PREFIX+'-terminal-height');if(!saved)return;var button=document.querySelector('.webssh-segmented button[data-height="'+saved+'"]');if(button)set_terminal_height(parseInt(saved,10),button);}
function sync_focus_buttons(){var stage=document.getElementById('webssh-stage');var buttons=document.querySelectorAll('[data-focus-toggle]');var active=stage&&stage.classList.contains('is-focus');var i;for(i=0;i<buttons.length;i++){buttons[i].setAttribute('aria-pressed',active?'true':'false');buttons[i].textContent=active?'退出专注':'专注模式';}}
function toggle_focus_mode(force_state){if(WEBSSH_EMBED_MODE)return false;var stage=document.getElementById('webssh-stage');var active;if(!stage)return false;active=(typeof force_state==='boolean')?force_state:!stage.classList.contains('is-focus');stage.classList.toggle('is-focus',active);if(window.localStorage)localStorage.setItem(WEBSSH_STORAGE_PREFIX+'-focus-mode',active?'1':'0');sync_focus_buttons();return false;}
function restore_focus_mode(){if(WEBSSH_EMBED_MODE)return;try{if(window.localStorage&&localStorage.getItem(WEBSSH_STORAGE_PREFIX+'-focus-mode')==='1')toggle_focus_mode(true);else sync_focus_buttons();}catch(e){sync_focus_buttons();}}
function arm_terminal_timeout(){var state=document.getElementById('webssh-frame-state');var hint=document.getElementById('webssh-frame-hint');if(window.__websshFrameTimer)window.clearTimeout(window.__websshFrameTimer);window.__websshFrameLoaded=false;window.__websshFrameTimer=window.setTimeout(function(){if(window.__websshFrameLoaded)return;if(state)set_badge_state(state,'warn','终端可能未完成握手');if(hint)hint.style.display='block';},5000);}
function clear_terminal_timeout(){if(window.__websshFrameTimer)window.clearTimeout(window.__websshFrameTimer);window.__websshFrameLoaded=true;}
function reload_terminal_frame(){var frame=document.getElementById('webssh-frame');var state=document.getElementById('webssh-frame-state');var hint=document.getElementById('webssh-frame-hint');if(!frame)return false;if(state)set_badge_state(state,'soft','终端重新加载中');if(hint)hint.style.display='none';arm_terminal_timeout();frame.src=frame.getAttribute('data-current-src')||frame.src;return false;}
function focus_terminal_frame(){var frame=document.getElementById('webssh-frame');if(!frame)return false;try{frame.setAttribute('tabindex','0');frame.focus();}catch(e){}try{if(frame.contentWindow&&frame.contentWindow.focus)frame.contentWindow.focus();}catch(e){}show_toast('键盘焦点已激活');return false;}
function sync_terminal_url(next_url){var frame=document.getElementById('webssh-frame');var current='';if(!frame||!next_url)return;current=frame.getAttribute('data-current-src')||'';if(!current){frame.setAttribute('data-current-src',frame.src||next_url);current=frame.getAttribute('data-current-src')||'';}if(current!==next_url){frame.setAttribute('data-current-src',next_url);frame.src=next_url;arm_terminal_timeout();}}
function apply_status(data){set_badge_state(document.getElementById('webssh-runtime-badge'),data.runtime_tone||'soft',data.runtime_label||'未知');set_badge_state(document.getElementById('webssh-runtime-badge-compact'),data.runtime_tone||'soft',data.runtime_label||'未知');set_badge_state(document.getElementById('webssh-check-badge'),data.self_check_tone||'soft',data.self_check_label||'未知');set_text('webssh-runtime-text',data.runtime_label||'未知');set_text('webssh-check-text',data.self_check_label||'未知');set_text('webssh-transport-text',data.transport_label||'-');set_text('webssh-transport-inline',data.transport_label||'-');set_text('webssh-transport-inline-compact',data.transport_label||'-');set_text('webssh-transport-inline-panel',data.transport_label||'-');set_text('webssh-port-text',data.bind_port||'-');set_text('webssh-port-inline',data.bind_port||'-');set_text('webssh-port-inline-compact',data.bind_port||'-');set_text('webssh-iface-text',data.bind_iface_label||'-');set_text('webssh-iface-inline',data.bind_iface_label||'-');set_text('webssh-iface-inline-compact',data.bind_iface_label||'-');set_text('webssh-limit-text',data.client_limit_label||'-');set_text('webssh-proc-text',data.ttyd_proc_count||'0');set_text('webssh-proc-inline',data.ttyd_proc_count||'0');set_text('webssh-port-check',data.port_check_label||'-');set_text('webssh-iface-check',data.iface_check_label||'-');set_text('webssh-updated','更新 '+(data.updated_at||'--:--:--'));set_code('webssh-url',data.ttyd_url||'',data.ttyd_url||'');set_code('webssh-ssh',data.ssh_cmd||'');if(document.getElementById('webssh-listen')&&data.listen_line)set_code('webssh-listen',data.listen_line);sync_terminal_url(data.ttyd_url||'');}
function poll_status(initial){var xhr=new XMLHttpRequest();xhr.open('GET',WEBSSH_STATUS_URL,true);xhr.onreadystatechange=function(){if(xhr.readyState!==4)return;if(xhr.status>=200&&xhr.status<300){try{apply_status(JSON.parse(xhr.responseText||'{}'));}catch(e){if(!initial)show_toast('状态刷新失败，保留上次结果','warn');}}else if(!initial){show_toast('状态刷新失败，保留上次结果','warn');}};xhr.send(null);}
(function(){var frame=document.getElementById('webssh-frame');var state=document.getElementById('webssh-frame-state');var hint=document.getElementById('webssh-frame-hint');restore_terminal_height();restore_focus_mode();poll_status(true);if(!frame||!state||!hint){window.setInterval(function(){poll_status(false);},12000);return;}frame.addEventListener('load',function(){clear_terminal_timeout();frame.setAttribute('data-current-src',frame.src||frame.getAttribute('data-current-src')||'');set_badge_state(state,'ok','终端已连接');hint.style.display='none';window.setTimeout(function(){focus_terminal_frame();},140);});frame.addEventListener('mouseenter',function(){focus_terminal_frame();});frame.addEventListener('click',function(){focus_terminal_frame();});arm_terminal_timeout();window.setInterval(function(){poll_status(false);},12000);})();
//]]></script>
<% if not embed_mode then %><%+footer%><% end %>
<% end %>
EOF
}

patch_appcenter_shortcut() {
    template_file="/usr/lib/lua/luci/view/nradio_appcenter/appcenter.htm"
    [ -f "$template_file" ] || return 0

    if grep -q 'app_list.result.applist.unshift({name:"Web SSH"' "$template_file"; then
        backup_file "$template_file"
        tmp_file="$WORKDIR/appcenter-entry.htm"
        awk '
            {
                if ($0 ~ /app_list\.result\.applist\.unshift\(\{name:"Web SSH"/) {
                    print "    app_list.result.applist.unshift({name:\"Web SSH\", version:\"ttyd 1.7.7\", des:\"浏览器 SSH 终端\", icon:\"webssh.svg\", open:1, has_luci:1, status:1, luci_module_route:\"nradioadv/system/webssh\"});"
                    next
                }
                print
            }
        ' "$template_file" > "$tmp_file" && mv "$tmp_file" "$template_file"
    else
        backup_file "$template_file"
        tmp_file="$WORKDIR/appcenter-entry.htm"
        awk '
            BEGIN { done = 0 }
            {
                print
                if (!done && $0 ~ /^    var app_list = /) {
                    print "    if (!app_list.result) app_list.result = {applist: []};"
                    print "    if (!app_list.result.applist) app_list.result.applist = [];"
                    print "    app_list.result.applist.unshift({name:\"Web SSH\", version:\"ttyd 1.7.7\", des:\"浏览器 SSH 终端\", icon:\"webssh.svg\", open:1, has_luci:1, status:1, luci_module_route:\"nradioadv/system/webssh\"});"
                    done = 1
                }
            }
        ' "$template_file" > "$tmp_file" && mv "$tmp_file" "$template_file"
    fi

    if ! grep -q 'function normalize_app_route(app_name, route)' "$template_file"; then
        backup_file "$template_file"
        tmp_file="$WORKDIR/appcenter-webssh-normalize.htm"
        awk '
            BEGIN { inserted = 0 }
            {
                print
                if (!inserted && $0 ~ /^    var APPSTORE_SPACE_ERR = 8;$/) {
                    print ""
                    print "    function normalize_app_route(app_name, route){"
                    print "        if (!route || !route.length)"
                    print "            return route;"
                    print "        if (app_name == \"Web SSH\" && route.indexOf(\"embed=\") === -1)"
                    print "            return route + (route.indexOf(\"?\") === -1 ? \"?embed=1\" : \"&embed=1\");"
                    print "        return route;"
                    print "    }"
                    inserted = 1
                }
            }
        ' "$template_file" > "$tmp_file" && mv "$tmp_file" "$template_file"
    fi

    if ! grep -q 'open_route = normalize_app_route(db.name, open_route);' "$template_file"; then
        backup_file "$template_file"
        tmp_file="$WORKDIR/appcenter-webssh-open-route.htm"
        awk '
            {
                if ($0 ~ /^            var open_ht=/) {
                    print "            open_route = normalize_app_route(db.name, open_route);"
                }
                print
            }
        ' "$template_file" > "$tmp_file" && mv "$tmp_file" "$template_file"
    fi

    if ! grep -q "frame.src.indexOf('/nradioadv/system/webssh')" "$template_file" || ! grep -q "frame.src.indexOf('/admin/vpn/easytier')" "$template_file"; then
        backup_file "$template_file"
        tmp_file="$WORKDIR/appcenter-iframe.htm"
        awk '
            {
                if ($0 ~ /frame\.src\.indexOf\('\''\/admin\/services\/openclash'\''\)/ && $0 ~ /\/nradioadv\/system\/zerotier'\''\) === -1/) {
                    print "            if (frame.src.indexOf('\''/admin/services/openclash'\'') === -1 && frame.src.indexOf('\''/admin/services/AdGuardHome'\'') === -1 && frame.src.indexOf('\''/nradioadv/system/openvpnfull'\'') === -1 && frame.src.indexOf('\''/nradioadv/system/openlist'\'') === -1 && frame.src.indexOf('\''/nradioadv/system/zerotier'\'') === -1 && frame.src.indexOf('\''/admin/vpn/easytier'\'') === -1 && frame.src.indexOf('\''/nradioadv/system/webssh'\'') === -1)"
                    next
                }
                print
            }
        ' "$template_file" > "$tmp_file" && mv "$tmp_file" "$template_file"
    fi

    if ! grep -q "tabindex='0' allow='clipboard-read; clipboard-write'" "$template_file"; then
        backup_file "$template_file"
        tmp_file="$WORKDIR/appcenter-iframe-attrs.htm"
        sed "s|return \"<iframe id='sub_frame' src='\" + get_app_route_url(route) + \"' name='subpage'></iframe>\";|return \"<iframe id='sub_frame' src='\" + get_app_route_url(route) + \"' name='subpage' tabindex='0' allow='clipboard-read; clipboard-write'></iframe>\";|" "$template_file" | sed "s|return \"<iframe id='sub_frame' name='subpage'></iframe>\";|return \"<iframe id='sub_frame' name='subpage' tabindex='0' allow='clipboard-read; clipboard-write'></iframe>\";|" > "$tmp_file" && mv "$tmp_file" "$template_file"
    fi

    if ! grep -q 'function is_webssh_route(route)' "$template_file"; then
        backup_file "$template_file"
        tmp_file="$WORKDIR/appcenter-webssh-route.htm"
        awk '
            BEGIN { in_fn = 0; done = 0 }
            {
                print
                if (!done && $0 ~ /^    function is_adguardhome_route\(route\)\{$/) {
                    in_fn = 1
                    next
                }
                if (in_fn && $0 ~ /^    }$/) {
                    print "    function is_webssh_route(route){"
                    print "        return route && route.indexOf(\"nradioadv/system/webssh\") === 0;"
                    print "    }"
                    print "    function enable_webssh_iframe_input(){"
                    print "        try {"
                    print "            var frame = document.getElementById(\"sub_frame\");"
                    print "            if (!frame || !frame.src || frame.src.indexOf(\"/nradioadv/system/webssh\") === -1)"
                    print "                return;"
                    print ""
                    print "            $(document).off(\"focusin.bs.modal\");"
                    print "            $(\".modal.app_frame.in\").attr(\"tabindex\", \"-1\");"
                    print "            $(frame).attr(\"tabindex\", \"0\");"
                    print ""
                    print "            frame.focus();"
                    print "            if (frame.contentWindow && frame.contentWindow.focus)"
                    print "                frame.contentWindow.focus();"
                    print "        }"
                    print "        catch(e) {}"
                    print "    }"
                    in_fn = 0
                    done = 1
                }
            }
        ' "$template_file" > "$tmp_file" && mv "$tmp_file" "$template_file"
    fi

    if ! grep -q "app_name == 'Web SSH' && action == 'open' && route" "$template_file"; then
        backup_file "$template_file"
        tmp_file="$WORKDIR/appcenter-webssh-open.htm"
        awk '
            BEGIN { inserted = 0 }
            {
                print
                if (!inserted && $0 ~ /^        var info_msg = \"\";$/) {
                    print "        if (app_name == '\''Web SSH'\'' && action == '\''open'\'' && route) {"
                    print "            callback(id, route);"
                    print "            return;"
                    print "        }"
                    print ""
                    inserted = 1
                }
            }
        ' "$template_file" > "$tmp_file" && mv "$tmp_file" "$template_file"
    fi

    if grep -q 'window.location.href = get_app_route_url(route);' "$template_file"; then
        backup_file "$template_file"
        tmp_file="$WORKDIR/appcenter-webssh-direct-open.htm"
        awk '
            BEGIN { skip = 0 }
            {
                if (!skip && $0 ~ /^        if \(is_webssh_route\(route\)\) \{$/) {
                    skip = 1
                    next
                }
                if (skip) {
                    if ($0 ~ /^        }$/) {
                        skip = 0
                    }
                    next
                }
                print
            }
        ' "$template_file" > "$tmp_file" && mv "$tmp_file" "$template_file"
    fi

    if ! grep -q 'closeByKeyboard: false,' "$template_file" || ! grep -q 'modal_data.enforceFocus = function(){};' "$template_file"; then
        backup_file "$template_file"
        tmp_file="$WORKDIR/appcenter-webssh-dialog.htm"
        awk '
            BEGIN {
                in_callback = 0
                in_dialog = 0
                inserted_close = 0
                inserted_focus = 0
            }
            {
                if ($0 ~ /^    function callback\(id,route\)\{$/)
                    in_callback = 1
                if (in_callback && $0 ~ /^    function app_action\(/) {
                    in_callback = 0
                    in_dialog = 0
                }
                if (in_callback && $0 ~ /^        sub_dialogDeal = BootstrapDialog\.show\(\{$/)
                    in_dialog = 1

                print

                if (in_dialog && !inserted_close && $0 ~ /^            closeByBackdrop: true,$/) {
                    print "            closeByKeyboard: false,"
                    inserted_close = 1
                }

                if (in_dialog && !inserted_focus && $0 ~ /^            onshown:function\(\)\{$/) {
                    print "                try {"
                    print "                    var modal = sub_dialogDeal && sub_dialogDeal.getModal ? sub_dialogDeal.getModal() : $(\".modal.app_frame.in\");"
                    print "                    var modal_data = modal && modal.data ? modal.data(\"bs.modal\") : null;"
                    print "                    if (modal_data)"
                    print "                        modal_data.enforceFocus = function(){};"
                    print "                    $(document).off(\"focusin.bs.modal\");"
                    print "                    $(modal).attr(\"tabindex\", \"-1\");"
                    print "                }"
                    print "                catch(e) {}"
                    print ""
                    inserted_focus = 1
                }

                if (in_dialog && $0 ~ /^        \}\);$/)
                    in_dialog = 0
            }
        ' "$template_file" > "$tmp_file" && mv "$tmp_file" "$template_file"
    fi

    if grep -Eq '\$\(\.modal\.app_frame\.in\)|modal\.data\(bs\.modal\)|\$\(document\)\.off\(focusin\.bs\.modal\)|\$\(modal\)\.attr\(tabindex, -1\)' "$template_file" 2>/dev/null; then
        backup_file "$template_file"
        tmp_file="$WORKDIR/appcenter-webssh-jsfix.htm"
        sed -e 's/$(\.modal\.app_frame\.in)/$(".modal.app_frame.in")/g' \
            -e 's/modal\.data(bs\.modal)/modal.data("bs.modal")/g' \
            -e 's/$(document)\.off(focusin\.bs\.modal)/$(document).off("focusin.bs.modal")/g' \
            -e 's/$(modal)\.attr(tabindex, -1)/$(modal).attr("tabindex", "-1")/g' \
            "$template_file" > "$tmp_file" && mv "$tmp_file" "$template_file"
    fi
}

restart_services() {
    rm -f /tmp/luci-indexcache /tmp/infocd/cache/appcenter /tmp/luci-modulecache /tmp/luci-modulecache/* 2>/dev/null || true
    if [ -x /etc/init.d/ttyd ]; then
        /etc/init.d/ttyd enable >/dev/null 2>&1 || true
        /etc/init.d/ttyd stop >/dev/null 2>&1 || true
        killall ttyd >/dev/null 2>&1 || true
        sleep 1
        /etc/init.d/ttyd start >/dev/null 2>&1 || true
    fi
    /etc/init.d/infocd restart >/dev/null 2>&1 || true
    /etc/init.d/appcenter restart >/dev/null 2>&1 || true
    sleep 2
    /etc/init.d/uhttpd reload >/dev/null 2>&1 || true
}

show_summary() {
    lan_ip="$(get_lan_ip)"
    [ -n "$lan_ip" ] || lan_ip="$(uci -q get network.lan.ipaddr 2>/dev/null || echo 192.168.1.1)"
    log "安装完成"
    log "Web SSH 页面: /cgi-bin/luci/nradioadv/system/appcenter/webssh"
    log "LuCI ttyd 页面: /cgi-bin/luci/admin/system/ttyd/overview"
    log "直连 ttyd:     http://$lan_ip:7681/"
}

install_all() {
    log_stage 1 5 "下载或校验 ttyd 二进制"
    install_ttyd_binary
    log_stage 2 5 "安装或刷新 LuCI ttyd 文件"
    install_luci_ttyd
    log_stage 3 5 "写入 Web SSH 包装页"
    install_webssh_wrapper
    log_stage 4 5 "写入应用商店快捷入口"
    patch_appcenter_shortcut
    log_stage 5 5 "重启 ttyd 与 uhttpd 服务"
    restart_services
}

main() {
    ensure_root
    ensure_workdir

    choice="${1:-}"
    if [ -z "$choice" ]; then
        printf '%s\n' "$APP_NAME"
        printf '1. 安装 ttyd Web SSH\n'
        printf '请选择 1: '
        read -r choice || die "input cancelled"
    fi

    case "$choice" in
        1) install_all ;;
        *) die "仅支持选项 1" ;;
    esac

    show_summary
}

main "$@"
__TTYD_HELPER__
    chmod 700 "$helper"
    log "running embedded ttyd/Web SSH installer..."
    sh "$helper" 1 || die "ttyd/Web SSH 安装失败"

    if install_webssh_embedded_icon; then
        set_webssh_shortcut_icon "$WEBSSH_ICON_NAME"
        rm -f /tmp/luci-indexcache /tmp/luci-modulecache/* 2>/dev/null || true
    fi
    write_plugin_uninstall_assets
    patch_common_template

    ensure_existing_swap_access "ttyd / Web SSH"
    verify_file_exists /usr/bin/ttyd "Web SSH / ttyd"
    verify_file_exists /etc/init.d/ttyd "Web SSH / ttyd"
    verify_file_exists /etc/config/ttyd "Web SSH / ttyd"
    verify_file_exists /usr/lib/lua/luci/controller/ttyd.lua "Web SSH / ttyd"
    verify_file_exists /usr/lib/lua/luci/view/ttyd/overview.htm "Web SSH / ttyd"
    verify_file_exists /usr/lib/lua/luci/controller/nradio_adv/webssh.lua "Web SSH"
    verify_file_exists /usr/lib/lua/luci/view/nradio_adv/webssh.htm "Web SSH"
    verify_luci_route admin/system/ttyd/overview "Web SSH / ttyd"
    verify_luci_route nradioadv/system/webssh "Web SSH"
    verify_template_marker 'app_list.result.applist.unshift({name:"Web SSH"' 'Web SSH 快捷入口'
    verify_template_marker 'nradioadv/system/webssh' 'Web SSH 路由'
    verify_template_marker "frame.src.indexOf('/admin/vpn/easytier') === -1" 'EasyTier iframe 白名单'
    verify_template_marker "frame.src.indexOf('/nradioadv/system/webssh') === -1" 'Web SSH iframe 白名单'
    verify_template_marker 'function normalize_app_route(app_name, route)' 'Web SSH embed 路由标准化'
    verify_template_marker "app_name == 'Web SSH' && action == 'open' && route" 'Web SSH 直接打开逻辑'
    verify_template_marker "action == 'uninstall' && nradio_plugin_uninstall_action(app_name)" '脚本插件异步卸载入口'
    verify_template_marker 'plugin_uninstall/start' '脚本插件异步卸载启动接口'
    verify_template_marker 'plugin_uninstall/check' '脚本插件异步卸载检查接口'
}

die_menu_input_issue() {
    choice_text="$1"
    if [ -n "$choice_text" ]; then
        die "invalid choice: $choice_text"
    fi
    if [ -t 0 ]; then
        die "invalid choice: empty input"
    fi
    die "invalid choice: no menu input detected; please run the saved script in an interactive terminal, or pass an action like: sh -s -- 4"

}

print_support_page_hint() {
    log "如果这个脚本帮到了你，可自愿支持后续维护与更新（需 IPv6 网络访问）:"
    log "$SUPPORT_PAGE_URL"
    log "说明: 页面仅提供自愿支持入口，不影响脚本功能使用"
    log "提示: 若当前网络不支持 IPv6，该页面可能无法打开"
}

print_startup_disclaimer_text() {
    disclaimer_model="${CURRENT_DETECTED_MODEL:-当前识别机型}"
    cat <<EOF
免责声明书

深圳鲲鹏无线科技有限公司当前检测到的设备机型（${disclaimer_model}，以下简称“本设备”）系基于Linux技术开发的5G CPE产品。本设备支持开源，为了使您正确并合法地使用本设备，请您在开源使用前务必阅读清楚下面的协议条款（如您对以下任一条款持反对意见或未能完全理解，请勿勾选本免责声明书）：
一、本免责声明书适用于当前检测到的设备机型（${disclaimer_model}）
二、许可的权利
1. 您可以在完全遵守本声明书的基础上，将本设备应用于非商业用途；
2. 您可以在《中华人民共和国网络安全法》及相关法律法规允许的范围内修改源代码以适应您的使用要求/需求；
3. 您在获取本设备密钥后拥有使用本设备构建源代码等全部内容所有权，并独立承担与这些内容的相关法律义务；
4. 获得商业授权之后，您可以将本设备应用于商业用途，同时依据所购买的授权类型中确定的技术支持内容，自购买时刻起，在技术支持期限内拥有通过指定的方式获得指定范围内的技术支持服务。商业授权用户享有反映和提出意见的权力，相关意见将被作为首要考虑，但没有一定被采纳的承诺或保证。
三、约束和限制
1. 未获商业授权之前，不得将本设备用于商业用途（包括但不限于以营利为目的或实现盈利）。购买商业授权请与我司了解最新说明；
2. 未经官方许可，不得对本设备或与之关联的商业授权进行出租、出售、抵押或发放子许可证；
3. 不管您是否整体使用，还是部分使用，在本设备的整体或任何部分基础上以发展任何派生版本、修改版本或第三方版本不得用于重新分发；
4. 本设备开源后您可根据自身需求对本设备进行使用，故本公司也不对开源后您的任何行为承担任何类型的责任担保，开源后您在使用过程中产生的一切风险全部由您自行承担；
5. 您不得删除或更改受保护的源代码形式中包含的任何许可声明（包括版权、专利、免责声明或责任限制）的实质内容，除非是纠正已知的事实错误所需；
6. 请您在开源使用过程中严格遵守国内外法律法规，不得将本设备用于任何非法用途；
7. 如果您未能遵守本协议的条款，您的授权将被终止，所被许可的权利将被收回，并承担相应法律责任。
四、有限担保和免责声明
1. 本设备及所附带的文件是作为不提供任何明确的或隐含的赔偿或担保的形式提供的；
2. 用户出于自愿而使用本设备，您必须了解开源使用本设备的风险，在尚未购买产品技术服务之前，我们不承诺对免费用户提供任何形式的技术支持、使用担保，也不承担任何因使用本设备而产生问题的相关责任；
3. 电子文本形式的授权协议如同双方书面签署的协议一样，具有完全的和等同的法律效力。您一旦开始确认本协议并使用开源相关功能，即被视为完全理解并接受本协议的各项条款，在享有上述条款授予的权力的同时，受到相关的约束和限制。协议许可范围以外的行为，将直接违反本授权协议并构成侵权，我们有权随时终止授权，责令停止损害，并保留追究相关责任的权力；
4. 如果本设备带有其它软件的整合示范例子包，这些文件版权不属于本软件官方，并且这些文件是没经过授权发布的，请参考相关软件的使用许可合法的使用。
五、用户责任声明
1. 用户已认真阅读并理解上述内容，同意上述条款，并承诺遵守以上约定；
2. 用户知悉本设备生产商/提供方在开源后不对本设备存在任何管理责任，因此用户承诺开源使用本设备过程中发生的一切法律、经济责任均由用户本人承担，与本设备生产商/提供方无关；
3. 用户开源使用本设备视为对本免责声明书以上全部内容的理解和认可。
EOF
}

run_menu_feature() {
    feature_choice="$1"
    show_support_page_hint='0'

    case "$feature_choice" in
        1)
            manage_swapfile
            ;;
        2)
            install_openclash
            show_support_page_hint='1'
            ;;
        3)
            install_ttyd_webssh
            show_support_page_hint='1'
            ;;
        4)
            install_adguardhome
            show_support_page_hint='1'
            ;;
        5)
            install_openlist
            show_support_page_hint='1'
            ;;
        6)
            install_zerotier
            show_support_page_hint='1'
            ;;
        7)
            install_easytier
            show_support_page_hint='1'
            ;;
        8)
            install_openvpn
            show_support_page_hint='1'
            ;;
        9)
            configure_openvpn_runtime
            show_support_page_hint='1'
            ;;
        10)
            configure_openvpn_routes
            show_support_page_hint='1'
            ;;
        11)
            configure_easytier_routes
            show_support_page_hint='1'
            ;;
        12)
            run_openvpn_selfcheck
            ;;
        13)
            run_unified_test_mode
            ;;
        14)
            if install_fanctrl; then
                :
            else
                fanctrl_rc="$?"
                [ "$fanctrl_rc" = '2' ] && return 2
                return "$fanctrl_rc"
            fi
            ;;
        15)
            confirm_appcenter_polish_risk
            install_appcenter_polish
            show_support_page_hint='1'
            ;;
        *)
            die_menu_input_issue "$feature_choice"
            ;;
    esac

    [ "$show_support_page_hint" = '1' ] && print_support_page_hint
    return 0
}

read_category_choice() {
    if ! ui_read_line; then
        [ -t 0 ] && die "input cancelled"
        UI_READ_RESULT=''
    fi
}

common_plugin_menu() {
    while :; do
        submenu_feature=''
        printf '\n常用插件安装:\n'
        printf '1. 扩容 swap 虚拟内存\n'
        printf '2. 哈基米\n'
        printf '3. ttyd / Web SSH\n'
        printf '4. AdGuardHome\n'
        printf '5. OpenList\n'
        printf '0. 返回功能分类\n'
        printf '请选择 0、1、2、3、4 或 5: '
        read_category_choice
        case "$UI_READ_RESULT" in
            0) return 2 ;;
            1) submenu_feature='1' ;;
            2) submenu_feature='2' ;;
            3) submenu_feature='3' ;;
            4) submenu_feature='4' ;;
            5) submenu_feature='5' ;;
            *) die_menu_input_issue "$UI_READ_RESULT" ;;
        esac
        if run_menu_feature "$submenu_feature"; then
            return 0
        else
            return "$?"
        fi
    done
}

network_route_menu() {
    while :; do
        submenu_feature=''
        printf '\nVPN / 组网 / 路由向导:\n'
        printf '1. ZeroTier\n'
        printf '2. EasyTier\n'
        printf '3. OpenVPN\n'
        printf '4. OpenVPN 向导配置并运行\n'
        printf '5. OpenVPN 路由表向导\n'
        printf '6. EasyTier 路由表向导\n'
        printf '7. OpenVPN 自检\n'
        printf '0. 返回功能分类\n'
        printf '请选择 0、1、2、3、4、5、6 或 7: '
        read_category_choice
        case "$UI_READ_RESULT" in
            0) return 2 ;;
            1) submenu_feature='6' ;;
            2) submenu_feature='7' ;;
            3) submenu_feature='8' ;;
            4) submenu_feature='9' ;;
            5) submenu_feature='10' ;;
            6) submenu_feature='11' ;;
            7) submenu_feature='12' ;;
            *) die_menu_input_issue "$UI_READ_RESULT" ;;
        esac
        if run_menu_feature "$submenu_feature"; then
            return 0
        else
            return "$?"
        fi
    done
}

appcenter_polish_menu() {
    while :; do
        submenu_feature=''
        printf '\n应用商店与页面美化:\n'
        printf '1. 美化应用商店\n'
        printf '0. 返回功能分类\n'
        printf '请选择 0 或 1: '
        read_category_choice
        case "$UI_READ_RESULT" in
            0) return 2 ;;
            1) submenu_feature='15' ;;
            *) die_menu_input_issue "$UI_READ_RESULT" ;;
        esac
        if run_menu_feature "$submenu_feature"; then
            return 0
        else
            return "$?"
        fi
    done
}

game_accel_require_appcenter() {
    [ -f "$CFG" ] || die "未检测到 NRadio 应用商店配置: $CFG"
    [ -f "$TPL" ] || die "未检测到 NRadio 应用商店模板: $TPL"
}

game_accel_set_appcenter_entry() {
    ga_app_name="$1"
    ga_pkg_name="$2"
    ga_version="$3"
    ga_size="$4"
    ga_route="$5"
    ga_controller="$6"
    ga_icon="$7"

    cleanup_appcenter_entry "$ga_app_name" "$ga_pkg_name" "$ga_route"
    ga_pkg_sec="$(uci add appcenter package)"
    ga_list_sec="$(uci add appcenter package_list)"

    uci set "appcenter.$ga_pkg_sec.name=$ga_app_name"
    uci set "appcenter.$ga_pkg_sec.version=$ga_version"
    uci set "appcenter.$ga_pkg_sec.size=$ga_size"
    uci set "appcenter.$ga_pkg_sec.status=1"
    uci set "appcenter.$ga_pkg_sec.has_luci=1"
    uci set "appcenter.$ga_pkg_sec.open=1"
    uci set "appcenter.$ga_pkg_sec.icon=$ga_icon"

    uci set "appcenter.$ga_list_sec.name=$ga_app_name"
    uci set "appcenter.$ga_list_sec.pkg_name=$ga_pkg_name"
    uci set "appcenter.$ga_list_sec.parent=$ga_app_name"
    uci set "appcenter.$ga_list_sec.size=$ga_size"
    uci set "appcenter.$ga_list_sec.luci_module_file=$ga_controller"
    uci set "appcenter.$ga_list_sec.luci_module_route=$ga_route"
    uci set "appcenter.$ga_list_sec.version=$ga_version"
    uci set "appcenter.$ga_list_sec.has_luci=1"
    uci set "appcenter.$ga_list_sec.type=1"
    uci set "appcenter.$ga_list_sec.icon=$ga_icon"
    uci -q commit appcenter >/dev/null 2>&1 || true
}

qiyou_version() {
    qy_version="$(sed -n 's/^VERSION=//p' /tmp/qy/etc/PKG_INFO 2>/dev/null | head -n 1)"
    [ -n "$qy_version" ] || qy_version='1.2.1'
    printf '%s\n' "$qy_version"
}

qiyou_size() {
    qy_size="$(du -sk /tmp/qy /etc/qy 2>/dev/null | awk '{s+=$1} END{if(s>0) printf "%s KB", s}')"
    [ -n "$qy_size" ] || qy_size='QiYou'
    printf '%s\n' "$qy_size"
}

qiyou_write_icon() {
    mkdir -p "$APP_ICON_DIR"
    cat > "$APP_ICON_DIR/qiyou.svg" <<'EOF_QIYOU_ICON'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="QiYou"><defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#eef8ff"/><stop offset="100%" stop-color="#cbeaff"/></linearGradient><linearGradient id="speed" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#22c55e"/><stop offset="100%" stop-color="#0ea5e9"/></linearGradient><filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="26" stdDeviation="22" flood-color="#8db7dd" flood-opacity="0.28"/></filter></defs><rect x="84" y="84" width="856" height="856" rx="188" fill="url(#bg)" stroke="#9fd7ff" stroke-width="18" filter="url(#shadow)"/><rect x="162" y="162" width="700" height="700" rx="154" fill="#f8fcff" stroke="#d8eefc" stroke-width="12"/><path d="M268 612a244 244 0 0 1 488 0" fill="none" stroke="#d7ecfb" stroke-width="60" stroke-linecap="round"/><path d="M268 612a244 244 0 0 1 388-197" fill="none" stroke="url(#speed)" stroke-width="60" stroke-linecap="round"/><circle cx="512" cy="612" r="86" fill="url(#speed)"/><path d="M512 612L676 448" stroke="#0f3554" stroke-width="46" stroke-linecap="round"/><circle cx="512" cy="612" r="28" fill="#eef8ff"/><path d="M338 706h348" stroke="#9fd7ff" stroke-width="36" stroke-linecap="round"/></svg>
EOF_QIYOU_ICON
    chmod 644 "$APP_ICON_DIR/qiyou.svg" 2>/dev/null || true
}

qiyou_write_uninstall_helper() {
    mkdir -p /usr/libexec
    cat > /usr/libexec/nradio-qiyou-uninstall <<'EOF_QIYOU_UNINSTALL'
#!/bin/sh
APP_NAME="奇游联机宝"
PKG_NAME="nradio-qiyou"
APP_ROUTE="nradioadv/system/qiyou"
APP_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/qiyou.lua"
APP_VIEW="/usr/lib/lua/luci/view/nradiobridge_qiyou/qiyou.htm"
APP_ICON="/www/luci-static/nradio/images/icon/qiyou.svg"
delete_sections() {
    st="$1"; fn="$2"; fv="$3"
    [ -n "$fv" ] || return 0
    uci show appcenter 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            "appcenter.@${st}"*".${fn}='${fv}'"|"appcenter.cfg"*".${fn}='${fv}'")
                sec="${line#appcenter.}"; sec="${sec%%.*}"; printf '%s\n' "$sec" ;;
        esac
    done | sort -u | while IFS= read -r sec; do
        [ -n "$sec" ] && uci -q delete "appcenter.$sec" >/dev/null 2>&1 || true
    done
}
/etc/qy/qy_acc.sh stop >/dev/null 2>&1 || true
[ -x /tmp/qy/init.sh ] && /tmp/qy/init.sh stop >/dev/null 2>&1 || true
killall -9 qy_proxy qy_mosq qy_acc >/dev/null 2>&1 || true
rm -rf /tmp/qy /etc/qy 2>/dev/null || true
rm -f /tmp/qyplug.sh /tmp/qyplug.ret /tmp/qyplug.pid /tmp/qyplug.get /tmp/qiyou-install.sh 2>/dev/null || true
rm -f /etc/init.d/qy_acc.boot /etc/rc.d/S99qy_acc.boot 2>/dev/null || true
rm -f "$APP_CONTROLLER" "$APP_VIEW" "$APP_ICON" 2>/dev/null || true
delete_sections package name "$APP_NAME"
delete_sections package name "$PKG_NAME"
delete_sections package_list name "$APP_NAME"
delete_sections package_list pkg_name "$PKG_NAME"
delete_sections package_list parent "$APP_NAME"
delete_sections package_list luci_module_route "$APP_ROUTE"
uci -q commit appcenter >/dev/null 2>&1 || true
rm -f /tmp/luci-indexcache /tmp/infocd/cache/appcenter 2>/dev/null || true
rm -f /tmp/luci-modulecache/* 2>/dev/null || true
/etc/init.d/infocd restart >/dev/null 2>&1 || true
/etc/init.d/appcenter restart >/dev/null 2>&1 || true
/etc/init.d/uhttpd reload >/dev/null 2>&1 || true
exit 0
EOF_QIYOU_UNINSTALL
    chmod 755 /usr/libexec/nradio-qiyou-uninstall
}

qiyou_write_controller() {
    mkdir -p /usr/lib/lua/luci/controller/nradio_adv
    cat > /usr/lib/lua/luci/controller/nradio_adv/qiyou.lua <<'EOF_QIYOU_CONTROLLER'
module("luci.controller.nradio_adv.qiyou", package.seeall)
function index()
    local page = entry({"nradioadv", "system", "qiyou"}, template("nradiobridge_qiyou/qiyou"), _("QiYou"), 90)
    page.show = true
    entry({"nradioadv", "system", "qiyou", "status"}, call("action_status"), nil).leaf = true
    entry({"nradioadv", "system", "qiyou", "uninstall"}, call("action_uninstall"), nil).leaf = true
end
local function trim(v) v=tostring(v or ""); local o=v:gsub("^%s+",""):gsub("%s+$",""); return o end
local function readfile(p) local f=io.open(p,"r"); if not f then return "" end; local d=f:read("*a") or ""; f:close(); return d end
local function exec(c) return trim(require("luci.sys").exec(c.." 2>/dev/null")) end
local function write_json(data) local h=require "luci.http"; h.prepare_content("application/json"); if type(h.write_json)=="function" then h.write_json(data) else h.write("{}") end end
local function pkg_info()
    local info={}
    for line in readfile("/tmp/qy/etc/PKG_INFO"):gmatch("[^\r\n]+") do
        local k,v=line:match("^([A-Z0-9_]+)=(.*)$")
        if k then info[k]=v end
    end
    return info
end
function action_status()
    local fs=require "nixio.fs"
    local installed=fs.access("/etc/qy/qy_acc.sh") and true or false
    local info=pkg_info()
    local status="NOT_INSTALLED"
    if installed then status=exec("/etc/qy/qy_acc.sh status"); if status=="" then status="UNKNOWN" end end
    local qy_acc=exec("pidof qy_acc")
    local qy_mosq=exec("pidof qy_mosq")
    local qy_proxy=exec("pidof qy_proxy")
    write_json({
        installed=installed,status=status,ret=trim(readfile("/tmp/qyplug.ret")),
        mode=info.MODE or "",version=info.VERSION or "",date=info.DATE or "",pver=info.PVER or "",
        qy_acc=qy_acc~="",qy_mosq=qy_mosq~="",qy_proxy=qy_proxy~="",
        qy_acc_pid=qy_acc,qy_mosq_pid=qy_mosq,qy_proxy_pid=qy_proxy,
        proxy_conn=tonumber(exec("netstat -tunap | grep qy_proxy | grep ESTABLISHED | wc -l")) or 0,
        proxy_listen=exec("netstat -lntup | grep qy_proxy | head -n 1"),
        cloud_conn=tonumber(exec("netstat -tunap | grep qy_acc | grep ESTABLISHED | wc -l")) or 0
    })
end
function action_uninstall()
    os.execute("/usr/libexec/nradio-qiyou-uninstall >/tmp/nradio-qiyou-uninstall.log 2>&1 &")
    write_json({ok=true,msg="已开始卸载奇游联机宝"})
end
EOF_QIYOU_CONTROLLER
    chmod 644 /usr/lib/lua/luci/controller/nradio_adv/qiyou.lua 2>/dev/null || true
}

qiyou_write_view() {
    mkdir -p /usr/lib/lua/luci/view/nradiobridge_qiyou
    cat > /usr/lib/lua/luci/view/nradiobridge_qiyou/qiyou.htm <<'EOF_QIYOU_VIEW'
<%+header%>
<style>
.qy-wrap{min-height:520px;padding:26px;color:#eef8ff;background:linear-gradient(135deg,#0b1724,#10283a 58%,#0b1724);box-sizing:border-box}.qy-head{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-bottom:18px}.qy-title{font-size:28px;font-weight:900}.qy-sub{margin-top:6px;color:#b8d7ea;font-size:13px}.qy-pill{display:inline-flex;align-items:center;gap:8px;border:1px solid rgba(125,211,252,.32);border-radius:999px;padding:8px 12px;background:rgba(14,165,233,.12);font-weight:800}.qy-dot{width:8px;height:8px;border-radius:50%;background:#94a3b8;box-shadow:0 0 10px currentColor}.qy-dot.boosting{background:#22c55e;color:#22c55e}.qy-dot.running{background:#38bdf8;color:#38bdf8}.qy-dot.off{background:#f97316;color:#f97316}.qy-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin:18px 0}.qy-card{border:1px solid rgba(255,255,255,.10);border-radius:14px;padding:16px;background:linear-gradient(145deg,rgba(255,255,255,.08),rgba(255,255,255,.03));box-shadow:inset 0 1px 0 rgba(255,255,255,.08),0 14px 30px rgba(0,0,0,.18)}.qy-label{color:#9ec6da;font-size:12px;font-weight:800}.qy-value{margin-top:8px;font-size:22px;font-weight:900;color:#fff;word-break:break-all}.qy-row{display:grid;grid-template-columns:190px 1fr;gap:10px;padding:11px 0;border-bottom:1px solid rgba(255,255,255,.08);color:#cfe7f5}.qy-k{color:#9ec6da;font-weight:800}.qy-v{font-weight:800;word-break:break-all}.qy-actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:18px}.qy-btn{border:1px solid rgba(125,211,252,.34);border-radius:10px;background:rgba(14,165,233,.16);color:#eef8ff;font-weight:900;padding:10px 16px;cursor:pointer}.qy-btn.danger{border-color:rgba(248,113,113,.48);background:rgba(239,68,68,.18)}.qy-note{margin-top:16px;color:#b8d7ea;line-height:1.7;font-size:13px}@media(max-width:900px){.qy-grid{grid-template-columns:1fr}.qy-row{grid-template-columns:1fr}.qy-head{align-items:flex-start;flex-direction:column}}
</style>
<div class="qy-wrap"><div class="qy-head"><div><div class="qy-title">奇游联机宝</div><div class="qy-sub">只读监听奇游后台状态，绑定和选择游戏仍在奇游联机宝 App 内完成。</div></div><div class="qy-pill"><span id="qy-dot" class="qy-dot"></span><span id="qy-status">读取中</span></div></div><div class="qy-grid"><div class="qy-card"><div class="qy-label">插件状态</div><div id="qy-main" class="qy-value">-</div></div><div class="qy-card"><div class="qy-label">实际代理连接</div><div id="qy-proxy-conn" class="qy-value">-</div></div><div class="qy-card"><div class="qy-label">云端连接</div><div id="qy-cloud-conn" class="qy-value">-</div></div></div><div class="qy-card"><div class="qy-row"><div class="qy-k">安装返回</div><div id="qy-ret" class="qy-v">-</div></div><div class="qy-row"><div class="qy-k">qy_acc</div><div id="qy-acc" class="qy-v">-</div></div><div class="qy-row"><div class="qy-k">qy_mosq</div><div id="qy-mosq" class="qy-v">-</div></div><div class="qy-row"><div class="qy-k">qy_proxy</div><div id="qy-proxy" class="qy-v">-</div></div><div class="qy-row"><div class="qy-k">包信息</div><div id="qy-pkg" class="qy-v">-</div></div><div class="qy-row"><div class="qy-k">代理监听</div><div id="qy-listen" class="qy-v">-</div></div></div><div class="qy-actions"><button class="qy-btn" onclick="qyRefresh()">刷新状态</button><button class="qy-btn danger" onclick="qyUninstall()">卸载奇游联机宝</button></div><div class="qy-note"><strong>状态解释：</strong>BOOSTING 表示正在加速；RUNNING 表示插件在线但未开启加速；实际代理连接不是连接路由器的设备数。</div></div>
<script>
var qyBase='<%=controller%>nradioadv/system/qiyou';function qyText(id,text){var el=document.getElementById(id);if(el)el.textContent=text||'-';}function qyBool(v,p){return v?('运行中'+(p?' / '+p:'')):'未运行';}function qyApply(d){var st=d.status||'UNKNOWN';var dot=document.getElementById('qy-dot');qyText('qy-status',st);qyText('qy-main',st==='BOOSTING'?'正在加速':(st==='RUNNING'?'插件在线':st));qyText('qy-proxy-conn',String(d.proxy_conn||0));qyText('qy-cloud-conn',String(d.cloud_conn||0));qyText('qy-ret',d.ret||'-');qyText('qy-acc',qyBool(d.qy_acc,d.qy_acc_pid));qyText('qy-mosq',qyBool(d.qy_mosq,d.qy_mosq_pid));qyText('qy-proxy',qyBool(d.qy_proxy,d.qy_proxy_pid));qyText('qy-pkg',[d.mode,d.version,d.date].filter(Boolean).join(' / ')||'-');qyText('qy-listen',d.proxy_listen||'-');if(dot){dot.className='qy-dot '+(st==='BOOSTING'?'boosting':(st==='RUNNING'?'running':'off'));}}function qyRefresh(){var x=new XMLHttpRequest();x.open('GET',qyBase+'/status?_='+Date.now(),true);x.onreadystatechange=function(){if(x.readyState===4){try{qyApply(JSON.parse(x.responseText||'{}'));}catch(e){qyText('qy-status','读取失败');}}};x.send(null);}function qyUninstall(){if(!confirm('确认卸载奇游联机宝并移除应用商店入口吗？'))return;var x=new XMLHttpRequest();x.open('POST',qyBase+'/uninstall',true);x.onreadystatechange=function(){if(x.readyState===4)alert('已开始卸载，稍后刷新应用商店。');};x.send('');}qyRefresh();setInterval(qyRefresh,5000);
</script>
<%+footer%>
EOF_QIYOU_VIEW
    chmod 644 /usr/lib/lua/luci/view/nradiobridge_qiyou/qiyou.htm 2>/dev/null || true
}

qiyou_install_assets() {
    qiyou_assets_log="${1:-写入奇游应用商店接入文件}"
    log "$qiyou_assets_log"
    qiyou_write_icon
    qiyou_write_uninstall_helper
    write_plugin_uninstall_assets
    qiyou_write_controller
    qiyou_write_view
    game_accel_set_appcenter_entry "奇游联机宝" "nradio-qiyou" "$(qiyou_version)" "$(qiyou_size)" "nradioadv/system/qiyou" "/usr/lib/lua/luci/controller/nradio_adv/qiyou.lua" "qiyou.svg"
    refresh_luci_appcenter
}

qiyou_install_integrated() {
    game_accel_require_appcenter
    confirm_or_exit "确认安装奇游联机宝官方脚本并接入 NRadio 应用商店吗？"
    command -v opkg >/dev/null 2>&1 || die "系统没有 opkg，无法按奇游官方方式安装依赖"
    log "[1/3] 安装奇游依赖"
    opkg update || die "opkg update 失败"
    opkg install curl kmod-tun ip-full || die "安装 curl/kmod-tun/ip-full 失败"
    log "[2/3] 下载并执行奇游官方安装脚本"
    download_file "http://sd.qiyou.cn" "/tmp/qiyou-install.sh" || die "下载奇游入口脚本失败"
    grep -q 'qyplug.sh' /tmp/qiyou-install.sh 2>/dev/null || die "奇游入口脚本内容异常，已停止执行"
    if command -v sha256sum >/dev/null 2>&1; then
        log "奇游入口脚本 SHA256: $(sha256sum /tmp/qiyou-install.sh | awk '{print $1}')"
    fi
    sh /tmp/qiyou-install.sh || die "奇游官方安装脚本执行失败"
    sleep 2
    [ -f /etc/qy/qy_acc.sh ] || die "奇游安装后未发现 /etc/qy/qy_acc.sh"
    qiyou_install_assets "[3/3] 写入奇游应用商店接入文件"
    qiyou_show_status
    log "完成：奇游联机宝已接入 NRadio 应用商店"
}

qiyou_show_status() {
    log "奇游状态:"
    if [ -x /etc/qy/qy_acc.sh ]; then
        qy_status_text="$(/etc/qy/qy_acc.sh status 2>/dev/null || true)"
        [ -n "$qy_status_text" ] && log "$qy_status_text" || true
    else
        log "NOT_INSTALLED"
    fi
    log "安装返回: $(cat /tmp/qyplug.ret 2>/dev/null || true)"
    log "qy_acc: $(pidof qy_acc 2>/dev/null || printf '-')"
    log "qy_mosq: $(pidof qy_mosq 2>/dev/null || printf '-')"
    log "qy_proxy: $(pidof qy_proxy 2>/dev/null || printf '-')"
    [ -f /tmp/qy/etc/PKG_INFO ] && cat /tmp/qy/etc/PKG_INFO
}

qiyou_uninstall_integrated() {
    confirm_or_exit "确认卸载奇游联机宝并移除应用商店入口吗？"
    [ -x /usr/libexec/nradio-qiyou-uninstall ] || qiyou_write_uninstall_helper
    /usr/libexec/nradio-qiyou-uninstall
    log "已执行奇游联机宝卸载流程"
}

leigod_installed() {
    [ -d /usr/sbin/leigod ] && ls /usr/sbin/leigod/acc-gw.router.* >/dev/null 2>&1
}

leigod_version() {
    lg_version=''
    if [ -f /usr/sbin/leigod/acc_version.ini ]; then
        lg_version="$(awk -F= '/version|VERSION|Ver|VER/ {print $2; exit}' /usr/sbin/leigod/acc_version.ini 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    fi
    if [ -z "$lg_version" ] && [ -f /usr/sbin/leigod/plugin_common.sh ]; then
        lg_version="$(grep -m 1 '^download_base_url=' /usr/sbin/leigod/plugin_common.sh 2>/dev/null | sed 's/^download_base_url=//' | sed 's/"//g')"
    fi
    [ -n "$lg_version" ] || lg_version='LeigodAcc'
    printf '%s\n' "$lg_version"
}

leigod_size() {
    lg_size="$(du -sk /usr/sbin/leigod 2>/dev/null | awk '{print $1}')"
    [ -n "$lg_size" ] || lg_size='0'
    printf '%s\n' "$lg_size"
}

leigod_write_icon() {
    mkdir -p "$APP_ICON_DIR"
    cat > "$APP_ICON_DIR/leigod.svg" <<'EOF_LEIGOD_ICON'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" role="img" aria-label="Leigod"><defs><linearGradient id="lg-bg" x1="18" y1="10" x2="110" y2="118" gradientUnits="userSpaceOnUse"><stop stop-color="#f7fbff"/><stop offset="1" stop-color="#d7ecff"/></linearGradient><linearGradient id="lg-bolt" x1="48" y1="20" x2="83" y2="108" gradientUnits="userSpaceOnUse"><stop stop-color="#f59e0b"/><stop offset=".5" stop-color="#f97316"/><stop offset="1" stop-color="#ef4444"/></linearGradient><filter id="lg-shadow" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="6" stdDeviation="7" flood-color="#0f172a" flood-opacity=".22"/></filter></defs><rect x="14" y="14" width="100" height="100" rx="24" fill="url(#lg-bg)" filter="url(#lg-shadow)"/><path d="M70 16 32 74h27l-8 38 45-63H68l2-33Z" fill="url(#lg-bolt)"/><path d="M72 28 47 66h22l-4 22 22-31H65l7-29Z" fill="#fff" opacity=".42"/><path d="M31 83c9 9 21 14 34 14 14 0 27-6 36-16" fill="none" stroke="#38bdf8" stroke-width="7" stroke-linecap="round" opacity=".78"/></svg>
EOF_LEIGOD_ICON
    chmod 644 "$APP_ICON_DIR/leigod.svg" 2>/dev/null || true
}

leigod_write_uninstall_helper() {
    mkdir -p /usr/libexec
    cat > /usr/libexec/nradio-leigod-uninstall <<'EOF_LEIGOD_UNINSTALL'
#!/bin/sh
APP_NAME="雷神加速器"
PKG_NAME="nradio-leigod"
APP_ROUTE="nradioadv/system/leigod"
APP_CONTROLLER="/usr/lib/lua/luci/controller/nradio_adv/leigod.lua"
APP_VIEW="/usr/lib/lua/luci/view/nradiobridge_leigod/leigod.htm"
APP_ICON="/www/luci-static/nradio/images/icon/leigod.svg"
LEIGOD_DIR="/usr/sbin/leigod"
LEIGOD_INIT="/etc/init.d/acc"
delete_sections() {
    st="$1"; fn="$2"; fv="$3"
    [ -n "$fv" ] || return 0
    uci show appcenter 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            "appcenter.@${st}"*".${fn}='${fv}'"|"appcenter.cfg"*".${fn}='${fv}'")
                sec="${line#appcenter.}"; sec="${sec%%.*}"; printf '%s\n' "$sec" ;;
        esac
    done | sort -u | while IFS= read -r sec; do
        [ -n "$sec" ] && uci -q delete "appcenter.$sec" >/dev/null 2>&1 || true
    done
}
if [ -x "$LEIGOD_INIT" ]; then
    "$LEIGOD_INIT" disable >/dev/null 2>&1 || true
    "$LEIGOD_INIT" stop >/dev/null 2>&1 || true
fi
if [ -f "$LEIGOD_DIR/leigod_uninstall.sh" ]; then
    ( cd "$LEIGOD_DIR" && sh ./leigod_uninstall.sh ) >/tmp/nradio-leigod-official-uninstall.log 2>&1 || true
else
    killall acc-gw.router.arm64 acc-gw.router.aarch64 acc_upgrade_monitor >/dev/null 2>&1 || true
    rm -rf "$LEIGOD_DIR" /tmp/acc 2>/dev/null || true
    rm -f "$LEIGOD_INIT" /etc/config/accelerator 2>/dev/null || true
fi
delete_sections package name "$APP_NAME"
delete_sections package name "$PKG_NAME"
delete_sections package_list name "$APP_NAME"
delete_sections package_list pkg_name "$PKG_NAME"
delete_sections package_list parent "$APP_NAME"
delete_sections package_list luci_module_route "$APP_ROUTE"
uci -q commit appcenter >/dev/null 2>&1 || true
rm -f "$APP_CONTROLLER" "$APP_VIEW" "$APP_ICON" 2>/dev/null || true
rm -f /tmp/luci-indexcache /tmp/infocd/cache/appcenter 2>/dev/null || true
rm -f /tmp/luci-modulecache/* 2>/dev/null || true
/etc/init.d/infocd restart >/dev/null 2>&1 || true
/etc/init.d/appcenter restart >/dev/null 2>&1 || true
/etc/init.d/uhttpd reload >/dev/null 2>&1 || true
exit 0
EOF_LEIGOD_UNINSTALL
    chmod 755 /usr/libexec/nradio-leigod-uninstall
}

leigod_write_controller() {
    mkdir -p /usr/lib/lua/luci/controller/nradio_adv
    cat > /usr/lib/lua/luci/controller/nradio_adv/leigod.lua <<'EOF_LEIGOD_CONTROLLER'
module("luci.controller.nradio_adv.leigod", package.seeall)
function index()
    local page=entry({"nradioadv","system","leigod"},template("nradiobridge_leigod/leigod"),_("LeigodAcc"),91)
    page.show=true
    entry({"nradioadv","system","leigod","status"},call("action_status"),nil).leaf=true
    entry({"nradioadv","system","leigod","uninstall"},call("action_uninstall"),nil).leaf=true
end
local function trim(v) v=tostring(v or ""); local o=v:gsub("^%s+",""):gsub("%s+$",""); return o end
local function exec(c) return trim(require("luci.sys").exec(c.." 2>/dev/null")) end
local function has_file(p) return require("nixio.fs").access(p) and true or false end
local function write_json(data) local h=require "luci.http"; h.prepare_content("application/json"); if type(h.write_json)=="function" then h.write_json(data) else h.write("{}") end end
local function listen_line(port) return exec("netstat -lntup | grep ':"..port.." ' | head -n 1") end
local function conn_count(pattern) return tonumber(exec("netstat -tunap | grep "..pattern.." | grep ESTABLISHED | wc -l")) or 0 end
local function detect_mode()
    local tun=exec("uci -q get accelerator.base.tun")
    if tun=="1" then return "TUN" elseif tun=="0" then return "Tproxy" end
    if exec("grep -q -- '--mode tun' /etc/init.d/acc && echo yes || echo no")=="yes" then return "TUN" end
    if has_file("/etc/init.d/acc") then return "Tproxy" end
    return "UNKNOWN"
end
local function tail_log()
    local log=exec("ls -t /tmp/acc/log/acc_Game.log /tmp/acc/acc-gw.log-* 2>/dev/null | head -n 1")
    if log=="" then return "" end
    return exec("tail -n 12 "..log)
end
function action_status()
    local installed=has_file("/usr/sbin/leigod/acc-gw.router.arm64") or has_file("/usr/sbin/leigod/acc-gw.router.aarch64") or exec("ls /usr/sbin/leigod/acc-gw.router.* 2>/dev/null | head -n 1")~=""
    local acc_pid=exec("pidof acc-gw.router.arm64")
    if acc_pid=="" then acc_pid=exec("pidof acc-gw.router.aarch64") end
    if acc_pid=="" then acc_pid=exec("ps | grep 'acc-gw.router' | grep -v grep | awk '{print $1}'") end
    local acc_runner_pid=exec("ps | grep 'acc-gw.router' | grep ' -r acc ' | grep -v grep | awk '{print $1}'")
    local init_exists=has_file("/etc/init.d/acc")
    local service_enabled=false
    if init_exists then service_enabled=exec("/etc/init.d/acc enabled && echo yes || echo no")=="yes" end
    write_json({
        installed=installed,service_enabled=service_enabled,service_running=acc_pid~="",accelerating=acc_runner_pid~="",
        init_exists=init_exists,acc_pid=acc_pid,acc_runner_pid=acc_runner_pid,upgrade_pid=exec("pidof acc_upgrade_monitor"),
        web5588=listen_line("5588")~="",web5588_line=listen_line("5588"),
        port10001=listen_line("10001")~="",port10001_line=listen_line("10001"),
        udp6066=exec("netstat -lunp | grep ':6066 ' | head -n 1")~="",udp6066_line=exec("netstat -lunp | grep ':6066 ' | head -n 1"),
        mode=detect_mode(),acc_conn=conn_count("acc-gw.router"),log_tail=tail_log()
    })
end
function action_uninstall()
    os.execute("/usr/libexec/nradio-leigod-uninstall >/tmp/nradio-leigod-uninstall.log 2>&1 &")
    write_json({ok=true,msg="已开始卸载雷神加速器"})
end
EOF_LEIGOD_CONTROLLER
    chmod 644 /usr/lib/lua/luci/controller/nradio_adv/leigod.lua 2>/dev/null || true
}

leigod_write_view() {
    mkdir -p /usr/lib/lua/luci/view/nradiobridge_leigod
    cat > /usr/lib/lua/luci/view/nradiobridge_leigod/leigod.htm <<'EOF_LEIGOD_VIEW'
<%+header%>
<style>
.lg-wrap{min-height:560px;padding:26px;color:#f8fbff;background:linear-gradient(135deg,#121827,#1f273c 58%,#111827);box-sizing:border-box}.lg-head{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-bottom:18px}.lg-title{font-size:28px;font-weight:900}.lg-sub{margin-top:6px;color:#c6d3e1;font-size:13px}.lg-pill{display:inline-flex;align-items:center;gap:8px;border:1px solid rgba(248,181,74,.38);border-radius:999px;padding:8px 12px;background:rgba(245,158,11,.13);font-weight:900}.lg-dot{width:8px;height:8px;border-radius:50%;background:#94a3b8;box-shadow:0 0 10px currentColor}.lg-dot.ok{background:#22c55e;color:#22c55e}.lg-dot.warn{background:#f59e0b;color:#f59e0b}.lg-dot.bad{background:#ef4444;color:#ef4444}.lg-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin:18px 0}.lg-card{border:1px solid rgba(255,255,255,.10);border-radius:14px;padding:16px;background:linear-gradient(145deg,rgba(255,255,255,.075),rgba(255,255,255,.032));box-shadow:inset 0 1px 0 rgba(255,255,255,.08),0 14px 30px rgba(0,0,0,.18)}.lg-label{color:#fcd38a;font-size:12px;font-weight:900}.lg-value{margin-top:8px;font-size:22px;font-weight:900;color:#fff;word-break:break-all}.lg-row{display:grid;grid-template-columns:180px 1fr;gap:10px;padding:11px 0;border-bottom:1px solid rgba(255,255,255,.08);color:#d8e2f0}.lg-k{color:#fcd38a;font-weight:900}.lg-v{font-weight:800;word-break:break-all}.lg-actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:18px}.lg-btn{border:1px solid rgba(248,181,74,.42);border-radius:10px;background:rgba(245,158,11,.15);color:#fff7ed;font-weight:900;padding:10px 16px;cursor:pointer}.lg-btn.danger{border-color:rgba(248,113,113,.50);background:rgba(239,68,68,.18)}.lg-log{white-space:pre-wrap;line-height:1.55;font-family:monospace;font-size:12px;max-height:180px;overflow:auto;color:#dbeafe}.lg-note{margin-top:16px;color:#c6d3e1;line-height:1.7;font-size:13px}@media(max-width:900px){.lg-grid{grid-template-columns:1fr}.lg-row{grid-template-columns:1fr}.lg-head{align-items:flex-start;flex-direction:column}}
</style>
<div class="lg-wrap"><div class="lg-head"><div><div class="lg-title">雷神加速器</div><div class="lg-sub">只读监听雷神后台状态；绑定设备和选择游戏仍在雷神 App 内完成。</div></div><div class="lg-pill"><span id="lg-dot" class="lg-dot"></span><span id="lg-status">读取中</span></div></div><div class="lg-grid"><div class="lg-card"><div class="lg-label">服务状态</div><div id="lg-main" class="lg-value">-</div></div><div class="lg-card"><div class="lg-label">代理连接</div><div id="lg-conn" class="lg-value">-</div></div><div class="lg-card"><div class="lg-label">运行模式</div><div id="lg-mode" class="lg-value">-</div></div></div><div class="lg-card"><div class="lg-row"><div class="lg-k">安装目录</div><div id="lg-installed" class="lg-v">-</div></div><div class="lg-row"><div class="lg-k">acc-gw</div><div id="lg-acc" class="lg-v">-</div></div><div class="lg-row"><div class="lg-k">升级监控</div><div id="lg-upgrade" class="lg-v">-</div></div><div class="lg-row"><div class="lg-k">5588 Web</div><div id="lg-web" class="lg-v">-</div></div><div class="lg-row"><div class="lg-k">10001 服务端口</div><div id="lg-port" class="lg-v">-</div></div><div class="lg-row"><div class="lg-k">6066 UDP</div><div id="lg-udp" class="lg-v">-</div></div><div class="lg-row"><div class="lg-k">启动脚本</div><div id="lg-init" class="lg-v">-</div></div><div class="lg-row"><div class="lg-k">最近日志</div><div id="lg-log" class="lg-v lg-log">-</div></div></div><div class="lg-actions"><button class="lg-btn" onclick="lgRefresh()">刷新状态</button><button class="lg-btn danger" onclick="lgUninstall()">卸载雷神加速器</button></div><div class="lg-note"><strong>状态解释：</strong>检测到 <code>-r acc</code> 进程显示加速中；仅后台 web/daemon 在线显示插件在线。</div></div>
<script>
var lgBase='<%=controller%>nradioadv/system/leigod';function lgText(id,text){var el=document.getElementById(id);if(el)el.textContent=text||'-';}function lgApply(d){var dot=document.getElementById('lg-dot');var running=!!d.service_running;var accelerating=!!d.accelerating;var installed=!!d.installed;var statusText=accelerating?'加速中':(running?'插件在线':(installed?'已安装未在线':'未安装'));lgText('lg-status',statusText);lgText('lg-main',statusText);lgText('lg-conn',String(d.acc_conn||0));lgText('lg-mode',d.mode||'UNKNOWN');lgText('lg-installed',installed?'已安装':'未安装');lgText('lg-acc',accelerating?('加速中 / '+(d.acc_runner_pid||'-')):(running?('插件在线 / '+(d.acc_pid||'-')):'未运行'));lgText('lg-upgrade',d.upgrade_pid?('运行中 / '+d.upgrade_pid):'未运行');lgText('lg-web',d.web5588?d.web5588_line:'未监听');lgText('lg-port',d.port10001?d.port10001_line:'未监听');lgText('lg-udp',d.udp6066?d.udp6066_line:'未监听');lgText('lg-init',d.init_exists?(d.service_enabled?'已启用':'未启用'):'缺失');lgText('lg-log',d.log_tail||'-');if(dot){dot.className='lg-dot '+(running?'ok':(installed?'warn':'bad'));}}function lgRefresh(){var x=new XMLHttpRequest();x.open('GET',lgBase+'/status?_='+Date.now(),true);x.onreadystatechange=function(){if(x.readyState===4){try{lgApply(JSON.parse(x.responseText||'{}'));}catch(e){lgText('lg-status','读取失败');}}};x.send(null);}function lgUninstall(){if(!confirm('确认卸载雷神加速器并移除应用商店入口吗？'))return;var x=new XMLHttpRequest();x.open('POST',lgBase+'/uninstall',true);x.onreadystatechange=function(){if(x.readyState===4)alert('已开始卸载，稍后刷新应用商店。');};x.send('');}lgRefresh();setInterval(lgRefresh,5000);
</script>
<%+footer%>
EOF_LEIGOD_VIEW
    chmod 644 /usr/lib/lua/luci/view/nradiobridge_leigod/leigod.htm 2>/dev/null || true
}

leigod_install_assets() {
    leigod_assets_log="${1:-写入雷神应用商店接入文件}"
    log "$leigod_assets_log"
    leigod_write_icon
    leigod_write_uninstall_helper
    write_plugin_uninstall_assets
    leigod_write_controller
    leigod_write_view
    game_accel_set_appcenter_entry "雷神加速器" "nradio-leigod" "$(leigod_version)" "$(leigod_size)" "nradioadv/system/leigod" "/usr/lib/lua/luci/controller/nradio_adv/leigod.lua" "leigod.svg"
    refresh_luci_appcenter
}

leigod_attach_integrated() {
    game_accel_require_appcenter
    leigod_installed || die "未检测到 /usr/sbin/leigod/acc-gw.router.*，请先安装雷神加速器"
    leigod_install_assets
    log "完成：雷神加速器已接入 NRadio 应用商店"
}

leigod_install_integrated() {
    game_accel_require_appcenter
    cat <<'EOF_LEIGOD_RISK'
高风险提示：
雷神官方脚本可能修改系统网络、防火墙、UPnP、/etc/init.d/acc 和相关依赖。
已经安装雷神时，建议优先使用“检测已安装并接入应用商店”。
EOF_LEIGOD_RISK
    confirm_or_exit "确认安装雷神官方脚本并接入 NRadio 应用商店吗？"
    command -v opkg >/dev/null 2>&1 || die "系统没有 opkg，无法自动安装雷神依赖"
    log "[1/3] 安装雷神依赖"
    opkg update || die "opkg update 失败"
    lg_dep_failed=''
    for lg_pkg in curl libpcap iptables kmod-ipt-nat iptables-mod-tproxy kmod-ipt-ipset ipset kmod-tun kmod-ipt-tproxy kmod-netem tc-full conntrack miniupnpd luci-app-upnp; do
        if ! opkg list-installed 2>/dev/null | grep -q "^$lg_pkg "; then
            log "安装依赖：$lg_pkg"
            if ! opkg install "$lg_pkg"; then
                lg_dep_failed="${lg_dep_failed} $lg_pkg"
            fi
        fi
    done
    if [ -n "$lg_dep_failed" ]; then
        log "提示: 以下雷神依赖安装失败或不可用，仍将交由官方脚本继续处理:${lg_dep_failed}"
    fi
    if [ -f /etc/config/upnpd ]; then
        uci set upnpd.config.enabled='1' >/dev/null 2>&1 || true
        uci commit upnpd >/dev/null 2>&1 || true
        /etc/init.d/miniupnpd start >/dev/null 2>&1 || true
        /etc/init.d/miniupnpd enable >/dev/null 2>&1 || true
    fi
    log "[2/3] 下载并执行雷神官方安装脚本"
    download_file "http://119.3.40.126/router_plugin_new/plugin_install.sh" "/tmp/leigod-plugin-install.sh" || die "下载雷神官方安装脚本失败"
    grep -q 'leigod\|acc-gw\|accelerator' /tmp/leigod-plugin-install.sh 2>/dev/null || die "雷神官方安装脚本内容异常，已停止执行"
    if command -v sha256sum >/dev/null 2>&1; then
        log "雷神官方安装脚本 SHA256: $(sha256sum /tmp/leigod-plugin-install.sh | awk '{print $1}')"
    fi
    sh /tmp/leigod-plugin-install.sh || die "雷神官方安装脚本执行失败"
    sleep 2
    leigod_installed || die "安装后仍未检测到 /usr/sbin/leigod/acc-gw.router.*"
    leigod_install_assets "[3/3] 写入雷神应用商店接入文件"
    leigod_show_status
    log "完成：雷神加速器已接入 NRadio 应用商店"
}

leigod_show_status() {
    log "雷神状态:"
    if leigod_installed; then log "安装状态: 已安装"; else log "安装状态: 未安装"; fi
    if [ -x /etc/init.d/acc ]; then /etc/init.d/acc enabled >/dev/null 2>&1 && log "服务启用: 是" || log "服务启用: 否"; else log "服务启用: 启动脚本缺失"; fi
    log "acc-gw PID: $(pidof acc-gw.router.arm64 2>/dev/null || pidof acc-gw.router.aarch64 2>/dev/null || true)"
    log "加速进程: $(ps | grep 'acc-gw.router' | grep ' -r acc ' | grep -v grep | awk '{print $1}' 2>/dev/null || true)"
    log "升级监控 PID: $(pidof acc_upgrade_monitor 2>/dev/null || true)"
    log "代理连接数: $(netstat -tunap 2>/dev/null | grep acc-gw.router | grep ESTABLISHED | wc -l)"
    netstat -lntup 2>/dev/null | grep -E ':5588 |:10001 ' || true
    netstat -lunp 2>/dev/null | grep ':6066 ' || true
}

leigod_uninstall_integrated() {
    confirm_or_exit "确认卸载雷神加速器并移除应用商店入口吗？"
    [ -x /usr/libexec/nradio-leigod-uninstall ] || leigod_write_uninstall_helper
    /usr/libexec/nradio-leigod-uninstall
    log "已执行雷神加速器卸载流程"
}

qiyou_integrated_menu() {
    while :; do
        printf '\n奇游联机宝:\n'
        printf '1. 安装奇游官方脚本并接入应用商店\n'
        printf '2. 查看奇游状态\n'
        printf '3. 卸载奇游联机宝\n'
        printf '0. 返回游戏加速器\n'
        printf '请选择 0、1、2 或 3: '
        read_category_choice
        case "$UI_READ_RESULT" in
            0) return 2 ;;
            1) if qiyou_install_integrated; then return 0; else return "$?"; fi ;;
            2) qiyou_show_status; return 0 ;;
            3) if qiyou_uninstall_integrated; then return 0; else return "$?"; fi ;;
            *) die_menu_input_issue "$UI_READ_RESULT" ;;
        esac
    done
}

leigod_integrated_menu() {
    while :; do
        printf '\n雷神加速器:\n'
        printf '1. 检测已安装雷神并接入应用商店\n'
        printf '2. 安装雷神官方脚本并接入应用商店\n'
        printf '3. 查看雷神状态\n'
        printf '4. 卸载雷神加速器\n'
        printf '0. 返回游戏加速器\n'
        printf '请选择 0、1、2、3 或 4: '
        read_category_choice
        case "$UI_READ_RESULT" in
            0) return 2 ;;
            1) if leigod_attach_integrated; then return 0; else return "$?"; fi ;;
            2) if leigod_install_integrated; then return 0; else return "$?"; fi ;;
            3) leigod_show_status; return 0 ;;
            4) if leigod_uninstall_integrated; then return 0; else return "$?"; fi ;;
            *) die_menu_input_issue "$UI_READ_RESULT" ;;
        esac
    done
}

game_accelerator_menu() {
    while :; do
        printf '\n游戏加速器:\n'
        printf '1. 奇游联机宝\n'
        printf '2. 雷神加速器\n'
        printf '0. 返回功能分类\n'
        printf '请选择 0、1 或 2: '
        read_category_choice
        case "$UI_READ_RESULT" in
            0)
                return 2
                ;;
            1)
                if qiyou_integrated_menu; then game_rc='0'; else game_rc="$?"; fi
                ;;
            2)
                if leigod_integrated_menu; then game_rc='0'; else game_rc="$?"; fi
                ;;
            *)
                die_menu_input_issue "$UI_READ_RESULT"
                ;;
        esac
        [ "$game_rc" = '2' ] && continue
        return "$game_rc"
    done
}

maintenance_test_menu() {
    while :; do
        submenu_feature=''
        printf '\n设备维护与检测:\n'
        printf '1. 统一测试模式\n'
        printf '2. NRadio_C8-688 / C2000MAX 风扇控制\n'
        printf '0. 返回功能分类\n'
        printf '请选择 0、1 或 2: '
        read_category_choice
        case "$UI_READ_RESULT" in
            0) return 2 ;;
            1) submenu_feature='13' ;;
            2) submenu_feature='14' ;;
            *) die_menu_input_issue "$UI_READ_RESULT" ;;
        esac
        if run_menu_feature "$submenu_feature"; then
            return 0
        else
            return "$?"
        fi
    done
}

main_menu() {
    choice="${1:-}"
    require_root
    acquire_script_lock
    require_startup_disclaimer_acceptance_once
printf '%s\n' "$SCRIPT_TITLE"
printf '%s\n' "$SCRIPT_SIGNATURE"
printf '%s\n' "$SCRIPT_MODEL_NOTICE"
printf '%s\n' "$SCRIPT_SCOPE_NOTICE"
    require_supported_nradio_model_environment
    log_nradio_oem_environment_hint

    if [ -n "$choice" ]; then
        if run_menu_feature "$choice"; then
            feature_rc='0'
        else
            feature_rc="$?"
        fi
        [ "$feature_rc" = '2' ] && return 0
        return "$feature_rc"
    fi

    while :; do
        printf '%s\n' "$SCRIPT_SUPPORT_NOTICE"
        printf '请选择功能分类:\n'
        printf '1. 常用插件安装\n'
        printf '2. VPN / 组网 / 路由向导\n'
        printf '3. 游戏加速器\n'
        printf '4. 应用商店与页面美化\n'
        printf '5. 设备维护与检测\n'
        printf '0. 退出\n'
        printf '请输入 0、1、2、3、4 或 5: '
        read_category_choice

        case "$UI_READ_RESULT" in
            0)
                return 0
                ;;
            1)
                if common_plugin_menu; then menu_rc='0'; else menu_rc="$?"; fi
                ;;
            2)
                if network_route_menu; then menu_rc='0'; else menu_rc="$?"; fi
                ;;
            3)
                if game_accelerator_menu; then menu_rc='0'; else menu_rc="$?"; fi
                ;;
            4)
                if appcenter_polish_menu; then menu_rc='0'; else menu_rc="$?"; fi
                ;;
            5)
                if maintenance_test_menu; then menu_rc='0'; else menu_rc="$?"; fi
                ;;
            *)
                die_menu_input_issue "$UI_READ_RESULT"
                ;;
        esac

        [ "$menu_rc" = '2' ] && continue
        return "$menu_rc"
    done
}

main_menu "$@"
