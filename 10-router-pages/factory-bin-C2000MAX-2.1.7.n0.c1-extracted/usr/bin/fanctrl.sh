#!/bin/ash
. /lib/functions.sh
. /lib/network/switch.sh
. /usr/share/libubox/jshn.sh

GPIO_FAN="/sys/class/gpio/fan-hw/value"
dWait=12

gWait=$dWait
gMode=
gModelTemp=
gDeviceTemp=
gRunning=
gTempSpeedOld=
gTempLowTrigger=0
gTempMediumTrigger=0
gTempScheduleSpeed=0
usage() {
	cat <<-EOF
		Usage: $0 OPTION...
		Led control daemon.

		  -w		wait period, use '$dWait' seconds as default
		  -m		fan mode, 0: normal, 1: disable, use '$dMode' as default
	EOF
}

async_sleep() {
	sleep "$1" &
	wait $!
}

log_info() {
	logger -t "fanctrl" "$*"
}

disable_fan() {
	echo "0" > $GPIO_FAN
	echo "0" > /sys/devices/platform/pwm-fan/hwmon/hwmon0/pwm1

	if [ "$gRunning" != "0" ];then
		gRunning="0"
		log_info "disable_fan"
	fi
}
enable_fan() {
	local speed="$1"
	local gpio_v=""

	echo "1" > $GPIO_FAN
	if [ "$gRunning" != "1" ];then
		gRunning="1"
	fi

	if [ "$gTempSpeedOld" != "$speed" ];then
		gTempSpeedOld=$speed
		log_info "enable_fan,speed:$speed"
	fi

	if [ -n "$speed" ];then
		case $speed in
		"0")          gpio_v="0" ;;
		"10")         gpio_v="25" ;;
		"20")         gpio_v="51" ;;
		"30")         gpio_v="76" ;;
		"40")         gpio_v="102" ;;
		"50")         gpio_v="127" ;;
		"60")         gpio_v="153" ;;
		"70")         gpio_v="178" ;;
		"80")         gpio_v="204" ;;
		"90")         gpio_v="229" ;;
		"100")        gpio_v="255" ;;
		esac
	fi
	if [ -n "$gpio_v" ];then
		echo "$gpio_v" > /sys/devices/platform/pwm-fan/hwmon/hwmon0/pwm1
	fi
}

get_fan_speed(){
	local speed=""
	local gpio_v=$(cat /sys/devices/platform/pwm-fan/hwmon/hwmon0/pwm1)
	if [ -n "$gpio_v" ];then
		case $gpio_v in
		"0")        speed="0" ;;
		"25")       speed="10" ;;
		"51")       speed="20" ;;
		"76")       speed="30" ;;
		"102")      speed="40" ;;
		"127")      speed="50" ;;
		"153")      speed="60" ;;
		"178")      speed="70" ;;
		"204")      speed="80" ;;
		"229")      speed="90" ;;
		"255")      speed="100" ;;
		esac
	fi
	echo -e "$speed"
}

get_device_temperature(){
	echo -e $(cat /sys/class/thermal/thermal_zone0/temp|awk '{printf "%d",$1/1000}')
}
get_model_temperature(){
	local cur=$(cpetools.sh -c temp)
	if echo "$cur"|grep -qE '^[0-9].*$'; then
		echo -e "$cur"
	fi
}

check_schedule_temperature(){
	local higher_temp=$gModelTemp
	local night=true

	#if [ -f "/tmp/test" ];then
	#	higher_temp="$(cat /tmp/test)"
	#fi
	if check_schedule_time "06:00" "24:00";then
		night=false
	fi
	
	if [ -z "$higher_temp" ];then
		gTempScheduleSpeed=0
	else
		if $night ;then
			if [ $higher_temp -lt 85 ];then
				gTempScheduleSpeed=0
				if [ $higher_temp -lt 80 ];then
					gTempLowTrigger=0
					gTempMediumTrigger=0
				fi
				if [ $higher_temp -ge 80 -a $gTempMediumTrigger -eq 1 ];then
					gTempScheduleSpeed=50
				fi
			else
				gTempMediumTrigger=1
				gTempLowTrigger=0
				gTempScheduleSpeed=50
			fi
		else
			if [ $higher_temp -lt 70 ];then
				gTempScheduleSpeed=0
				if [ $higher_temp -lt 65 ];then
					gTempLowTrigger=0
					gTempMediumTrigger=0
				fi
				if [ $higher_temp -ge 65 -a $gTempLowTrigger -eq 1 ];then
					gTempScheduleSpeed=30
				fi
			elif [ $higher_temp -lt 80 ];then
				gTempScheduleSpeed=30
				gTempLowTrigger=1

				if [ $higher_temp -lt 75 ];then
					gTempMediumTrigger=0
				fi
				if [ $higher_temp -ge 75 -a $gTempMediumTrigger -eq 1 ];then
					gTempScheduleSpeed=50
				fi
			else
				gTempMediumTrigger=1
				gTempLowTrigger=0
				gTempScheduleSpeed=50
			fi
		fi
	fi

	if [ "$gTempSpeedOld" != "$gTempScheduleSpeed" ];then
		log_info "temp cpu:$gDeviceTemp,model:$higher_temp"
	fi

	echo $gTempScheduleSpeed
}

check_schedule_time(){
	local ymd_s=$(date +%Y-%m-%d)
	local now_t=$(date +%s)
	local starttime
	local endtime
	local cfg_start_time="$1"
	local cfg_end_time="$2"

	if [ -n "$cfg_start_time" ];then
		starttime="${cfg_start_time}:00"
	else
		starttime="00:00:00"
	fi
	starttime_s=$(date -d "$ymd_s $starttime" +%s)
	if [ -n "$cfg_end_time" ];then
		endtime="${cfg_end_time}:00"
	else
		endtime="00:00:00"
	fi
	endtime_s=$(date -d "$ymd_s $endtime" +%s)

	if [ $starttime_s -ge $endtime_s ];then
		if [ $now_t -lt $endtime_s ];then
			return 0
		fi
		endtime_s=$((endtime_s+86400))
	fi

	if [ $now_t -gt $starttime_s -a $now_t -lt $endtime_s ];then		
		if [ "$gRunning" != "1" ];then
			log_info "schedule time match"
		fi
		return 0
	fi
	return 1
}

handle_fan() {
	local fan_speed="$(get_fan_speed)"
	
	gDeviceTemp=$(get_device_temperature)
	gModelTemp="$(get_model_temperature)"	
	
	if [ "$gMode" = "0" ]; then
		disable_fan
	elif [ "$gScheduleMode" = "2" ];then
		enable_fan "$gSpeed"
	elif [ "$gScheduleMode" = "1" ];then
		check_schedule_temperature
		enable_fan "$gTempScheduleSpeed"
	elif [ "$gScheduleMode" = "0" ];then
		if check_schedule_time "$gScheduleStarttime" "$gScheduleEndtime";then
			enable_fan "$gSpeed"
		else
			disable_fan
		fi
	fi
	if [ "$gRunning" != "1" ];then
		fan_speed="0"
	fi
	ubus call infocdp passthrough "{'name':'temperature','parameter':{'device':'$gDeviceTemp','cpe':'$gModelTemp','fan':'$fan_speed'}}"
}

while getopts "w:h" opt; do
	case "${opt}" in
		w)
			gWait=${OPTARG}
			;;
		h)
			usage
			;;
		\?)
			usage >&2
			exit 1
			;;
	esac
done

gMode=$(uci -q get fanctrl.fanctrl.enabled)
gScheduleMode=$(uci -q get fanctrl.fanctrl.mode)
gScheduleStarttime=$(uci -q get fanctrl.fanctrl.starttime)
gScheduleEndtime=$(uci -q get fanctrl.fanctrl.endtime)
gSpeed=$(uci -q get fanctrl.fanctrl.fanspeed)
[ -z "$gSpeed" ] && gSpeed=1
handle_fan

while true; do
	handle_fan
	async_sleep "$gWait"
done
