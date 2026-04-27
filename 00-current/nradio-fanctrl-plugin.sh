#!/bin/sh
set -eu

APP_NAME="NRadio-C8-688风扇控制插件脚本"
WORKDIR="/tmp/nradio-fanctrl.$$"
CFG="/etc/config/appcenter"

cleanup() {
    rm -rf "$WORKDIR"
}

trap cleanup EXIT INT TERM

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

ensure_root() {
    [ "$(id -u)" = "0" ] || die "请使用 root 执行"
}

ensure_workdir() {
    mkdir -p "$WORKDIR"
}

backup_file() {
    path="$1"
    [ -f "$path" ] || return 0
    mkdir -p /root/fanctrl-backup
    cp "$path" "/root/fanctrl-backup/$(basename "$path").$(date +%s).bak"
}

find_uci_section() {
    sec_type="$1"
    pkg_name="$2"

    uci show appcenter 2>/dev/null | awk -v st="$sec_type" -v n="$pkg_name" '
        $0 ~ ("^appcenter\\.@" st "\\[[0-9]+\\]=" st "$") {
            line = $0
            sub(/^appcenter\./, "", line)
            sub(/=.*/, "", line)
            sec = line
            next
        }
        sec != "" && $0 == ("appcenter." sec ".name='\''" n "'\''") {
            print sec
            exit
        }
    '
}

cleanup_appcenter_route_entries() {
    target_route="$1"

    uci show appcenter 2>/dev/null | awk -v route="$target_route" '
        /^appcenter\\.@package_list\\[[0-9]+\\]=package_list$/ {
            sec=$1
            sub(/^appcenter\./, "", sec)
            sub(/=.*/, "", sec)
            current=sec
            next
        }
        current != "" && $0 == ("appcenter." current ".luci_module_route='\''" route "'\''") {
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

set_appcenter_entry() {
    plugin_name="$1"
    pkg_name="$2"
    version="$3"
    size="$4"
    controller="$5"
    route="$6"

    [ -f "$CFG" ] || return 0

    cleanup_appcenter_route_entries "$route"

    pkg_sec="$(find_uci_section package "$plugin_name")"
    [ -n "$pkg_sec" ] || pkg_sec="$(uci add appcenter package)"

    list_sec="$(find_uci_section package_list "$plugin_name")"
    [ -n "$list_sec" ] || list_sec="$(uci add appcenter package_list)"

    uci set "appcenter.$pkg_sec.name=$plugin_name"
    uci set "appcenter.$pkg_sec.version=$version"
    uci set "appcenter.$pkg_sec.size=$size"
    uci set "appcenter.$pkg_sec.status=1"
    uci set "appcenter.$pkg_sec.has_luci=1"
    uci set "appcenter.$pkg_sec.open=1"

    uci set "appcenter.$list_sec.name=$plugin_name"
    uci set "appcenter.$list_sec.pkg_name=$pkg_name"
    uci set "appcenter.$list_sec.parent=$plugin_name"
    uci set "appcenter.$list_sec.size=$size"
    uci set "appcenter.$list_sec.luci_module_file=$controller"
    uci set "appcenter.$list_sec.luci_module_route=$route"
    uci set "appcenter.$list_sec.version=$version"
    uci set "appcenter.$list_sec.has_luci=1"
    uci set "appcenter.$list_sec.type=1"
    uci commit appcenter
}

remove_appcenter_entry() {
    plugin_name="$1"
    route="$2"
    [ -f "$CFG" ] || return 0

    cleanup_appcenter_route_entries "$route"

    pkg_sec="$(find_uci_section package "$plugin_name")"
    [ -n "$pkg_sec" ] && uci delete "appcenter.$pkg_sec" >/dev/null 2>&1 || true

    list_sec="$(find_uci_section package_list "$plugin_name")"
    [ -n "$list_sec" ] && uci delete "appcenter.$list_sec" >/dev/null 2>&1 || true

    uci commit appcenter
}

refresh_luci_appcenter() {
    rm -f /tmp/luci-indexcache /tmp/infocd/cache/appcenter 2>/dev/null || true
    rm -f /tmp/luci-modulecache/* 2>/dev/null || true
    /etc/init.d/infocd restart >/dev/null 2>&1 || true
    /etc/init.d/appcenter restart >/dev/null 2>&1 || true
    /etc/init.d/uhttpd reload >/dev/null 2>&1 || true
    sleep 2
}

write_controller() {
    mkdir -p /usr/lib/lua/luci/controller/nradio_adv
    backup_file /usr/lib/lua/luci/controller/nradio_adv/fanctrl.lua
    cat > /usr/lib/lua/luci/controller/nradio_adv/fanctrl.lua <<'EOF'
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
    else
        return "Smart"
    end
end

function action_get_temperature()
    local fs = require "nixio.fs"
    local data = {}
    local uci = require "luci.model.uci".cursor()

    data.mode = uci:get("fanctrl", "fanctrl", "mode") or "4"
    data.mode_label = mode_label(data.mode)
    data.enabled = uci:get("fanctrl", "fanctrl", "enabled") or "0"

    local temp_raw = fs.readfile("/sys/class/thermal/thermal_zone0/temp") or ""
    local pwm_raw = fs.readfile("/sys/devices/platform/pwm-fan/hwmon/hwmon0/pwm1") or ""
    local temp_num = tonumber((temp_raw:gsub("%s+", "")) or "") or 0
    local pwm_num = tonumber((pwm_raw:gsub("%s+", "")) or "") or 0

    if temp_num > 0 then
        data.temp = tostring(math.floor(temp_num / 1000))
    else
        data.temp = ""
    end

    if pwm_num >= 255 then
        data.fan = "100"
    elseif pwm_num >= 204 then
        data.fan = "80"
    elseif pwm_num >= 127 then
        data.fan = "50"
    elseif pwm_num >= 76 then
        data.fan = "30"
    else
        data.fan = "0"
    end

    luci.nradio.luci_call_result(data)
end
EOF
}

write_view_templates() {
    mkdir -p /usr/lib/lua/luci/view/nradio_fanctrl
    backup_file /usr/lib/lua/luci/view/nradio_fanctrl/temperature_ajax.htm
    backup_file /usr/lib/lua/luci/view/nradio_fanctrl/temperature.htm

    cat > /usr/lib/lua/luci/view/nradio_fanctrl/temperature_ajax.htm <<'EOF'
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
			var enabled = rv.result.enabled || '0';

			var tempLabel = temp ? (temp + ' °C') : '<em>暂无数据</em>';
			var fanLabel = '关闭';

			if (enabled === '1') {
				if (mode === '1')
					fanLabel = fan + '% / Low';
				else if (mode === '2')
					fanLabel = fan + '% / Medium';
				else if (mode === '3')
					fanLabel = fan + '% / High';
				else
					fanLabel = fan + '% / Smart';
			}

			update_fanctrl_value('tempdesdevice-temperature-status', tempLabel);
			update_fanctrl_value('fandesdevice-temperature-status', fanLabel);
		}
	);

	$("#cbi-fanctrl-fanctrl-tempdes").css("display", "none");
	$("#cbi-fanctrl-fanctrl-tempdesmodel").css("display", "none");
	
//]]></script>
<%+cbi/valuefooter%>
EOF

    cat > /usr/lib/lua/luci/view/nradio_fanctrl/temperature.htm <<'EOF'
<%+cbi/valueheader%>
<style>
 #<%=self.option%>-temperature-status{margin-top: 7px;display: block;}
</style>
<span id="<%=self.option%>-temperature-status"><em><%:Collecting data...%></em></span>
<%+cbi/valuefooter%>
EOF
}

write_model() {
    mkdir -p /usr/lib/lua/luci/model/cbi/nradio_adv
    backup_file /usr/lib/lua/luci/model/cbi/nradio_adv/fanctrl.lua
    cat > /usr/lib/lua/luci/model/cbi/nradio_adv/fanctrl.lua <<'EOF'
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

smarttemp = s:option(Value, "smarttemp", translate("SmartTemp"))
smarttemp.default = "60"
smarttemp.datatype = "uinteger"
smarttemp:depends("mode", "4")

function m.on_after_commit(map)
    os.execute("/etc/init.d/fanctrl restart >/dev/null 2>&1")
end

return m
EOF
}

write_service_script() {
    backup_file /usr/bin/fanctrl.sh
    cat > /usr/bin/fanctrl.sh <<'EOF'
#!/bin/ash
. /lib/functions.sh
. /usr/share/libubox/jshn.sh

GPIO_FAN="/sys/class/gpio/fan-hw/value"
PWM_FAN="/sys/devices/platform/pwm-fan/hwmon/hwmon0/pwm1"
WAIT=12

log_info() {
    logger -t "fanctrl" "$*"
}

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

get_drive_temp() {
    model_temp="$(get_model_temp)"
    if [ -n "$model_temp" ]; then
        echo "$model_temp"
    else
        get_cpu_temp
    fi
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
    threshold="$2"
    [ -n "$threshold" ] || threshold=60
    if [ "$temp" -ge 80 ]; then
        echo 100
    elif [ "$temp" -ge 70 ]; then
        echo 80
    elif [ "$temp" -ge "$threshold" ]; then
        echo 50
    else
        echo 30
    fi
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
    smarttemp="$(uci -q get fanctrl.fanctrl.smarttemp 2>/dev/null || echo 60)"

    if [ "$enabled" != "1" ]; then
        disable_fan
        report_state
        sleep "$WAIT"
        continue
    fi

    case "$mode" in
        0) disable_fan ;;
        1) enable_fan 30 ;;
        2) enable_fan 50 ;;
        3) enable_fan 80 ;;
        4) enable_fan "$(smart_percent "$(get_drive_temp)" "$smarttemp")" ;;
        *) enable_fan 50 ;;
    esac

    report_state
    sleep "$WAIT"
done
EOF
    chmod 755 /usr/bin/fanctrl.sh
}

install_all() {
    ensure_root
    ensure_workdir
    write_controller
    write_model
    write_view_templates
    write_service_script
    uci -q set fanctrl.fanctrl=service
    uci -q set fanctrl.fanctrl.enabled='1'
    uci -q set fanctrl.fanctrl.mode='4'
    uci -q set fanctrl.fanctrl.smarttemp='60'
    uci -q commit fanctrl
    [ -f /etc/init.d/fanctrl ] && /etc/init.d/fanctrl enable >/dev/null 2>&1 || true
    [ -f /etc/init.d/fanctrl ] && /etc/init.d/fanctrl restart >/dev/null 2>&1 || true
    remove_appcenter_entry "FanControl" "nradioadv/system/fanctrl"
    rm -f /tmp/appcenter/luci/nradioadv.system.fanctrl 2>/dev/null || true
    refresh_luci_appcenter
    log "done"
    log "route:    nradioadv/system/fanctrl"
}

main() {
    printf '%s\n' "$APP_NAME"
    printf '1. 安装风扇控制\n'
    printf '请选择 1: '
    read -r choice || die "input cancelled"
    case "$choice" in
        1) install_all ;;
        *) die "仅支持选项 1" ;;
    esac
}

main "$@"
