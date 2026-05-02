#!/bin/ash

. /usr/share/libubox/jshn.sh
. /lib/functions.sh
include /etc/cpetools
. /lib/netifd/netifd-proto.sh
readonly GPIO_EXPORT_DIR="/sys/class/gpio"
readonly CPE_DEV_CONF_PATH="/lib/network/wwan/"
readonly CPE_SIM_CTRL_DIR="$GPIO_EXPORT_DIR"
readonly COMGT_EXE_SCRIPT="/etc/gcom/nradio/exe.gcom"
readonly COMGT_RUN_SCRIPT="/etc/gcom/nradio/run.gcom"
readonly AT_GENERIC_PREFIX="AT+"
readonly AT_PRIVATE_PREFIX="AT^"
readonly CPE_LOCK_PATH="/var/run"
readonly TTY_CTRL_COMMAND="/usr/bin/comgt"
readonly CPESEL_PATH="/var/run/cpesel"
readonly CPETOOLS_PATH="/var/run/cpetools"
readonly ATSD_POWER_TAG="/var/run/atsd"

CPESEL_FS=
CPESEL_AT_OK=
CPESEL_GPIO_CHANGE=
CPE_SIM_SEL_PID=
CPE_USIM_FIRST_DELAY=
dNet=$(uci -q get network.globals.default_cellular)
[ -z "$dNet" ] && dNet="cpe"
dType=2
gName="cpetools"
gNet="$dNet"
gNetDefault=1
gNetGp="$gNet"
gReset=
gDown=
gUp=
gType="$dType"
gCmd=
gSim=
gSimgpio=0
gUpdate=
gMode=
gIndex=
gExternalParam=""
gFreqLock=""
gFreqLockPeak=""
gProcess=""
gAction=""
gLogMode=$(uci -q get logservice.root.mode)
usage() {
	cat <<-EOF
		usage: $0 OPTION...
		CPE control tool.

		  -i      network interface, $dNet as default
		  -r      reset cpe power.Reset all cpex-pwr,as no '-i' setted.Reset certain cpe,with '-i' setted
		  -d      down cpe power.Down all cpex-pwr,as no '-i' setted.Down certain cpe,with '-i' setted
		  -k      keep cpe power.Up all cpex-pwr,as no '-i' setted.Up certain cpe,with '-i' setted
		  -c      command
		  -t      command type, 0: AT-COMMAND, 1: AT-COMMAND script, 2: function, $dType as default
		  -s      switch to specified sim card number
		  -S      switch to specified sim card number only gpio
		  -u      update cpe settings
		  -m      update cpe mode custom
		  -l      freq lock trigger for cellular_freqtime,0 force unlock,1 force use cpecfg freq cfg
		  -L      freq lock trigger for PeakHour Assurance,0 follow the system,1 force use LTE
		  -f      which process using at tools
		  -a      at tools used way,mutual exclusion or share. relate to -f 
	EOF
}

log_info() {
	logger -t "$gName $$" "$*"
	if [ "$gLogMode" == "1" ] ;then
		logclient -i "$gName $$"  -l 6 -m "$*"
	fi
}

block_atsd_send(){
	[ ! -d "${ATSD_POWER_TAG}/${gNet}" ] && mkdir -p "${ATSD_POWER_TAG}/${gNet}"
	touch "${ATSD_POWER_TAG}/${gNet}/block_at"
	sleep 3
}

recovery_atsd_send(){
	sleep 2
	rm "${ATSD_POWER_TAG}/${gNet}/block_at"
}

rst_power_once(){
	local _f=

	log_info "apply $1 power reset!"
	_f="$GPIO_EXPORT_DIR/${1}/value"
	if [ -f "$_f" ]; then
		block_atsd_send
		log_info "apply $gNet power down!"
		echo "0" > "$_f"
		sleep 1
		log_info "apply $gNet power on!"
		echo "1" > "$_f"
		recovery_atsd_send
	fi
}

rst_power(){
	local force="$1"
	local _f=
	local _vendor
	local work_mode

	_vendor=$(check_soc_vendor)

	work_mode=$(uci -q get "network.$gNet.mode")
	if [ "$force" != "2" -a "$work_mode" = "odu" ];then
		log_info "apply $gNet power reset!"
		run_command "$gNet" reboot "2"
		block_atsd_send
		recovery_atsd_send
		return 0
	fi

	if [ "${_vendor}" = "nradio" -o "${_vendor}" = "simcom" ]; then
		if [ $gNetDefault -eq 0 ];then
			rst_power_once "$gNet-pwr"
			return
		fi
		ls "$GPIO_EXPORT_DIR"|while read -r line;do
			if echo "$line" |grep -qs "\-pwr";then
				rst_power_once "$line"
			fi
		done
	else
		if [ "$vendor" == "quectel_opsdk" ]; then
			/etc/init.d/qlatc.init restart
		else
			run_command "$gNet" cfun_c "2"
			run_command "$gNet" cfun_o "2"
		fi
	fi
}

ctl_power_once(){
	_f="$GPIO_EXPORT_DIR/${1}/value"
	if [ -f "$_f" ]; then
		if [ "$2" = "down" ];then
			log_info "apply $gNet power down!"
			echo "0" > "$_f"
		else
			log_info "apply $gNet power on!"
			echo "1" > "$_f"
		fi
	fi
}

ctl_power_core(){
	local _f=
	if [ $gNetDefault -eq 0 ];then
		ctl_power_once "$gNet-pwr" "$1"
		return
	fi
	ls "$GPIO_EXPORT_DIR"|while read -r line;do
		if echo "$line" |grep -qs "\-pwr";then
			ctl_power_once "$line" "$1"
		fi
	done
}
shutdown_power() {
	ctl_power_core "down"
}

keep_power() {
	ctl_power_core "up"
}

rstsim() {
	if run_command "$gNet" rstsim "2"; then
		return 0
	fi
	return 1
}

get_sim_gpio_val() {
	local _sum="$1"
	local _gval=

	_gval=$(uci -q get cpesel.sim${gIndex}.gval)

	[ -z "$_gval" ] && _gval="01,10,11"

	echo "$_gval"|cut -d, -f "$_sum"
}

set_sim_num() {
	local _gval="$1"
	local _gnum=
	local _val=
	local _tmp=

	_gnum=${#_gval}
	_gnum=$((_gnum-1))

	for _i in $(seq 0 "$_gnum"); do
		echo "${_gval:$((_gnum-_i)):1}" > "$CPE_SIM_CTRL_DIR/${gNetGp}-sel${_i}/value"
	done
}

set_usim() {
	local _uval="$1"

	[ -z "$_uval" ] && return 0

	while true; do
		if run_command "$gNet" usim_set "2" "$_uval"; then
			return 0
		fi
		sleep 1
	done
}

save_sim_num() {
	local _val=$1
	local _old=""
	_old=$(uci -q get cpesel.sim${gIndex}.cur)

	if [ "$_val" != "$_old" ];then
		uci -q set cpesel.sim${gIndex}.cur="$_val"
		uci commit cpesel.sim${gIndex}
		
		if [ -z "$gIndex" ];then
			log_info "notice kpcped.event"
			ubus send kpcped.event
		fi
	fi
}

chk_sim_num() {
	local _gval="$1"
	local _gnum=
	local _val=
	local _tmp=
	local gpio_num=0
	local odu=$(uci -q get network.${gNet}.mode)

	[ "$odu" == "odu" ] && return 0
	_gnum=${#_gval}
	_gnum=$((_gnum-1))

	for _i in $(seq 0 "$_gnum"); do
		if [ -f "$CPE_SIM_CTRL_DIR/${gNetGp}-sel${_i}/value" ];then
			_tmp=$(cat "$CPE_SIM_CTRL_DIR/${gNetGp}-sel${_i}/value")
			_val="$_tmp$_val"
			gpio_num=$((gpio_num+1))
		fi
	done
	[ $gpio_num -eq 0 ] && return 0
	[ "$_val" = "$_gval" ]
}

reset_special_usim(){
	run_command "$gNet" usim_reset "2"
	return 0
}

chk_usim() {
	local _uval="$1"
	local _val
	[ -f $CPESEL_AT_OK ] && rm $CPESEL_AT_OK
	[ -z "$_uval" ] && reset_special_usim && return 0
	[ ! -f $CPE_USIM_FIRST_DELAY ] && log_info "$CPE_USIM_FIRST_DELAY not exsit"
	log_info "chk_usim"
	[ ! -f $CPE_USIM_FIRST_DELAY ] && sleep 15 && log_info "usim first delay start 15s"
	log_info "touch $CPE_USIM_FIRST_DELAY"
	touch $CPE_USIM_FIRST_DELAY
	while true; do
		version=$(uci -q get "cellular_init.$gNet.version")
		if echo "$version" |grep -sq "RW" ;then
			return 0
		fi
		_val=$(run_command "$gNet" usim_get "2"|xargs -r printf)
		[ "$_val" != "none" ] && touch $CPESEL_AT_OK && break
		sleep 1
	done

	[ "$_val" = "$_uval" ]
}

_switch_sim_tdtech() {
	local _simnum="$1"
	local _val
	local _simval
	local _cursim

	_val=$(get_sim_gpio_val "$_simnum")

	if [ "$_val" = "1" ]; then
		_simval="usim"
	elif [ "$_val" = "2" ]; then
		_simval="esim1"
	elif [ "$_val" = "3" ]; then
		_simval="esim2"
	else
		log_info "unknown sim $_val"
		return 1
	fi

	_cursim=$(ubus call atserver get '{"mod": "switchcard"}'|jsonfilter -e '$["data"]["card"]')
	[ "$_cursim" = "$_simval" ] && return 0

	uci -q set network.cpe.sim=${_simval}
	uci -q commit network
	uci -q set cpesel.sim.cur=${_simnum}
	uci -q commit cpesel
	ubus call atserver set "{\"mod\":\"switchcard\",\"card\":\"${_simval}\"}"
}

_switch_sim_nradio() {
	local _simnum="$1"
	local _val=
	local _gval=
	local _uval=
	local _usimset=0
	local reset=0

	local vendor=$(check_soc_vendor)
	if [ "$vendor" = "quectel_opsdk" ]; then
		local hardware_version="$(uci get oem.board.hardware_version)"
		local open_hot="0"
		if [ -n "$hardware_version" -a "$hardware_version" != "1.0" ] ;then
			open_hot="1"
		fi
		command_quectel_checkdet2 "$1" "$open_hot"
	fi

	_val=$(get_sim_gpio_val "$_simnum")
	_gval=$(echo "$_val"|awk -F'-' '{print $1}')
	_uval=$(echo "$_val"|awk -F'-' '{print $2}')

	if ! chk_sim_num "$_gval"; then
		touch $CPESEL_GPIO_CHANGE
		set_sim_num "$_gval"
	fi

	[ -n "$_uval" -a $gSimgpio -eq 1 ] && return
	save_sim_num "$_simnum"
	if [ $gSimgpio -eq 0 ] && ! chk_usim "$_uval"; then
		_usimset=1
		set_usim "$_uval"
	fi

	if [ -f $CPESEL_GPIO_CHANGE ] || [ "$_usimset" -eq 1 ]; then
		if [ "$_usimset" -eq 0 ]; then
			reset=1
			touch $CPESEL_FS
			rstsim || rst_power
			log_info "model reset"
		fi
		proto_set_available "$gNet" 1
		if [ ! -f "/bin/serial_atcmd" ]; then
			log_info "ifup $gNet as for switch_sim $_simnum"
			ifup "$gNet"
		else
			log_info "switch sim done"
			# /etc/init.d/quec_diagd restart
			# sleep 5
			# ubus call quec_diagd set_wan "{'action':'down'}"
			# sleep 1
			# ubus call quec_diagd set_wan "{'action':'up'}"
		fi
		[ -f $CPESEL_GPIO_CHANGE ] && rm $CPESEL_GPIO_CHANGE
	fi
	
	keep_power
}

switch_sim() {
	local _vendor
	local _func

	_vendor=$(check_soc_vendor)
	_func="_switch_sim_${_vendor}"

	if type "$_func" 2>/dev/null | grep -qs function; then
		$_func "$1"
	else
		_switch_sim_nradio "$1"
	fi
	log_info "switch sim exit: $(cat $CPE_SIM_SEL_PID)"
	rm -f "$CPE_SIM_SEL_PID"
}

get_conf() {
	local _file=

	for _file in $(lsusb|awk '{print $6}'|sed "s|^|$CPE_DEV_CONF_PATH|"); do
		if [ -f "$_file" ]; then
			echo "$_file"
			return 0
		fi
	done

	return 1
}

lock_freq() {
	local _freq=$1
	local _info=
	local _file=
	local _msg=
	local _cmd=
	local _val=
	local _def=

	_file=$(get_conf) || return 2

	_info=$(cat "$_file")

	for _i in $(seq 0 10); do
		_msg=$(echo "$_info" | jsonfilter -e '$["lock_freq"]' | jsonfilter -e "\$[$_i]") || break

		_cmd=$(echo "$_msg" | jsonfilter -e '$["command"]')
		_val=$(echo "$_msg" | jsonfilter -e "\$['freqlist']['$_freq']")
		_def=$(echo "$_msg" | jsonfilter -e "\$['freqlist']['DEFAULT']")

		if ! atsd_cli -i "$gNet" -c "${_cmd}${_val:-$_def}"; then
			return 1
		fi
	done

	return 0
}

run_command() {
	local _net=
	local _cmd=
	local _type=
	local _ctl=
	local _info=
	local _vendor=
	local _cmdset=
	local _func=

	_net="$1"
	_cmd="$2"
	_type="$3"
	_param="$4"
	_param_index=4
	_vendor=$(check_soc_vendor)
	
	local process_status=$(cat $CPETOOLS_PATH/${gNet}/exclusive 2>/dev/null)
	if [ -n "$process_status" -a "$gProcess" != "$process_status" ];then
		return 1
	fi

	if [ "$_type" = "0" ]; then
		_command_exec_raw "$_ctl" "$_cmd" "$4"
	elif [ "$_type" = "1" ]; then
		res=$(_command_exec_raw "$_ctl" "$_cmd"	"5")
		if echo "$res"|grep -qsw "OK" ;then
			return 0
		else
			return 1
		fi
	else
		if [ "$_vendor" = "quectel_ysdk" ]; then
			_info=$(cat "/var/run/infocd/cache/${_net}_dev" |jsonfilter -e '$["parameter"]')
		else
			_info=$(cat "/tmp/infocd/cache/${_net}_dev" |jsonfilter -e '$["parameter"]')
		fi

		[ -n "$_info" ] || {
			echo "$_net usb not ready"
			return 1
		}
		if [ -n "$_param" ];then
			_param_f="$_param"
		else
			_param_f="$_info"
		fi

		_vendor=$(echo "$_info"|jsonfilter -e '$["vendor"]')
		_cmdset=$(echo "$_info"|jsonfilter -e '$["cmdset"]')
		_vendor="${_vendor:-generic}"

		_func="command_${_vendor}_${_cmd}${_cmdset}"
		if [ "$#" -gt "$_param_index" ]; then
			shift $_param_index
		else
			shift $#
		fi
		if type "$_func" 2>/dev/null | grep -qs function; then
			if $_func "$_ctl" "$_param_f" "$@"; then
				return 0
			else
				return 1
			fi
		elif [ "$_vendor" != "generic" ]; then
			_func="command_generic_${_cmd}"
			if type "$_func" 2>/dev/null | grep -qs function; then
				if $_func "$_ctl" "$_param_f" "$@"; then
					return 0
				else
					return 1
				fi
			fi
		fi
		echo "$_net does not support function $_cmd"
		return 2
	fi

	return 0
}

format_freq_data(){
	local freq_all="$1"
	local key="$2"
	local freq_mult="$3"
	local freq_tmp=""
	local freqArray=${freq_all//,/ }
	for freq_item in $freqArray
	do
		local freq_data=${freq_item//-/ }
		top_key=$(echo "$freq_data"|awk -F' ' '{print $1}'|xargs -r printf)
		data=$(echo "$freq_data"|awk -F' ' '{print $2}'|xargs -r printf)

		if [ -z "$key" -o "$top_key" = "$key" ];then
			if [ -n "$data" ];then
				freq_tmp="${freq_item}"
			else
				if [ "$freq_mult" == "0" ];then
					freq_tmp="$top_key-0"
				fi
			fi
			break
		fi

	done
	[ -z "$freq_tmp" -a "$freq_mult" == "0" ] && freq_tmp="$key-0"
	echo "$freq_tmp"
}

combine_band_data(){
	local cur_data="$1"
	local combine_data="$2"

	[ -z "$combine_data" ] && echo "$cur_data" && return
	[ -z "$cur_data" ] && echo "$combine_data" && return

	local bandArray=${cur_data//:/ }
	local combine_bandArray=${combine_data//:/ }
	for combine_band_item in $combine_bandArray
	do
		local same_band=0
		for band_item in $bandArray
		do
			if [ "$band_item" == "$combine_band_item" ];then
				same_band=1
				break
			fi
		done
		if [ $same_band -eq 0 ];then
			cur_data="$cur_data:$combine_band_item"
		fi
	done
	echo "$cur_data"
}

skip_band_data(){
	local freq_item="$1"
	local skip_band="$2"
	local target_band=""

	[ -z "$skip_band" ] && echo "$freq_item" && return

	local bandArray=${freq_item//:/ }
	local skip_bandArray=${skip_band//:/ }
	for band_item in $bandArray
	do
		local same_band=0
		for skip_band_item in $skip_bandArray
		do
			if [ "$band_item" == "$skip_band_item" ];then
				same_band=1
				break
			fi
		done
		if [ $same_band -eq 0 ];then
			target_band=${target_band:+${target_band}:}${band_item}
		fi
	done
	echo  "$target_band"
}

get_freq_info(){
	local freq_open=0
	local sim_id="$1"
	local mode=$(uci -q get "cpecfg.${gNet}sim$sim_id.mode")
	local custom_freq=$(uci -q get "cpecfg.${gNet}sim$simIndex.custom_freq")
	local custom_earfcn5=$(uci -q get "cpecfg.${gNet}sim$simIndex.custom_earfcn5")
	local custom_earfcn4=$(uci -q get "cpecfg.${gNet}sim$simIndex.custom_earfcn4")

	local peakhour_status=$(cat $CPETOOLS_PATH/${gNet}/peakhour_$sim_id 2>/dev/null)

	if [ "$peakhour_status" == "1" ];then
		log_info "[time lock]lock ${gNet}-sim$sim_id because peakhour"
		log_info "[time lock] don't unlock ${gNet}-sim$sim_id when peakhour, return 0"
		return $freq_open
	fi

	if [ -n "$mode" -a "$mode" != "auto" ];then
		freq_open=1
	elif [ "$custom_freq" == "1" ] ;then
		freq_open=1
	elif [ "$custom_earfcn5" == "1" ] ;then
		freq_open=1
	elif [ "$custom_earfcn4" == "1" ] ;then
		freq_open=1
	fi
	return $freq_open
}
unlock_freq(){
	local sim_id="$1"

	freq_status=$(cat $CPETOOLS_PATH/${gNet}/$sim_id 2>/dev/null)
	peakhour_status=$(cat $CPETOOLS_PATH/${gNet}/peakhour_$sim_id 2>/dev/null)

	if [ "$peakhour_status" == "1" ];then
		log_info "[time lock]lock ${gNet}-sim$sim_id because peakhour"
		return 2
	elif [ "$freq_status" == "0" ] && ! get_freq_info "$sim_id";then
		log_info "[time lock]unlock ${gNet}-sim$sim_id"
		return 0
	fi

	return 1
}
freq_lock_change(){
	local sim_id="$1"
	local status="$2"
	if ! get_freq_info "$sim_id";then
		log_info "[time lock]change ${gNet}-sim$sim_id to $status"
		return 0
	fi

	return 1
}
update_freq_lock(){
	local sim_id="$1"
	local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
	local support_nr="$(uci -q get network.${gNet}.nrcap)"
	[ -z "$support_nr" ] && return 1

	local status="$gFreqLock"
	[ ! -d "$CPETOOLS_PATH/${gNet}" ] && mkdir -p $CPETOOLS_PATH/${gNet}
	local old_status=$(cat $CPETOOLS_PATH/${gNet}/$sim_id 2>/dev/null) 
	[ -z "$old_status" ] && old_status="1"
	echo -n $status > $CPETOOLS_PATH/${gNet}/$sim_id
	log_info "[time lock]update ${gNet}-sim${sim_id} $status"

	[ "$sim_id" != "$simIndex" ] && return 1
	if [ "$old_status" != "$status" ] && freq_lock_change "$sim_id" "$status" ;then
		ifup ${gNet}
	fi
}

update_peakhour_freq_lock(){
	local sim_id="$1"
	local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
	local support_nr="$(uci -q get network.${gNet}.nrcap)"
	[ -z "$support_nr" ] && return 1

	local peakhour_status="$gFreqLockPeak"
	[ ! -d "$CPETOOLS_PATH/${gNet}" ] && mkdir -p $CPETOOLS_PATH/${gNet}
	local old_peakhour_status=$(cat $CPETOOLS_PATH/${gNet}/peakhour_$sim_id 2>/dev/null)
	[ -z "$old_peakhour_status" ] && old_peakhour_status="1"
	echo -n $peakhour_status > $CPETOOLS_PATH/${gNet}/peakhour_$sim_id
	log_info "[time lock]peakhour update ${gNet}-sim${sim_id} $peakhour_status"

	[ "$sim_id" != "$simIndex" ] && return 1
	if [ "$old_peakhour_status" != "$peakhour_status" ] ;then
		ifup ${gNet}
	fi
}

update_settings() {
	local _mode
	local prefer_do=0
	local _vendor=$(check_soc_vendor)

	if [ -z "$gMode" ];then
		[ ! -f "/etc/config/cpecfg" ] && return 0
		_mode=$(uci get "cpecfg.config.mode")
	else
		_mode="$gMode"
	fi
	local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
	[ -z "$simIndex" ] && simIndex="1"
	echo "sim:$simIndex"
	local roaming=$(uci -q get "cpecfg.${gNet}sim$simIndex.roaming")

	local compatibility=$(uci -q get "cpecfg.${gNet}sim$simIndex.compatibility")
	local freq=$(uci -q get "cpecfg.${gNet}sim$simIndex.freq")
	local custom_freq=$(uci -q get "cpecfg.${gNet}sim$simIndex.custom_freq")

	local custom_earfcn5=$(uci -q get "cpecfg.${gNet}sim$simIndex.custom_earfcn5")
	local earfcn5=$(uci -q get "cpecfg.${gNet}sim$simIndex.earfcn5")
	local pci5=$(uci -q get "cpecfg.${gNet}sim$simIndex.pci5")
	local band5=$(uci -q get "cpecfg.${gNet}sim$simIndex.band5")

	local custom_earfcn4=$(uci -q get "cpecfg.${gNet}sim$simIndex.custom_earfcn4")
	local earfcn4=$(uci -q get "cpecfg.${gNet}sim$simIndex.earfcn4")
	local pci4=$(uci -q get "cpecfg.${gNet}sim$simIndex.pci4")
	local band4=$(uci -q get "cpecfg.${gNet}sim$simIndex.band4")
	local earfreq_mode=$(uci -q get "cpecfg.${gNet}sim$simIndex.earfreq_mode")

	local command_equal=$(uci -q get "network.${gNet}.command_equal")
	local freq_all=$(uci -q get "network.${gNet}.freq_val")
	local freq_multi=$(uci -q get "network.${gNet}.freq_multi")
	local compatibility_work=$(uci -q get "network.${gNet}.compatibility")
	local blacklist_band=$(uci -q get "network.${gNet}.blacklist_band")
	echo "blacklist_band:$blacklist_band compatibility_work:$compatibility_work"
	if [ "$_vendor" = "quectel_ysdk" ]; then
		_info=$(cat "/var/run/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	else
		_info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	fi
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')

	[ -z "$roaming" ] && roaming="0"
	[ -z "$compatibility" ] && compatibility="0"

	unlock_freq "$simIndex"
	local lock_status=$?
	if [ $lock_status -eq 0 ]; then
		custom_freq="0"
		custom_earfcn4="0"
		custom_earfcn5="0"
		_mode="auto"
	elif [ $lock_status -eq 2 ]; then
		custom_freq="0"
		custom_earfcn4="0"
		custom_earfcn5="0"
		_mode="lte"
	fi

	if [ "$custom_freq" = "0" -a "$custom_earfcn5" != "1" ];then
		if [ "$_alias" != "mt5700" -a  "$_alias" != "redcap" ];then
			run_command "$gNet" "freq_unlock" "2"
			if [ $? = "0" ];then
				prefer_do=1
				echo "freq_unlock"
			fi
		fi
	fi
	_mode=${_mode:-auto}
	if [ "$_mode" = "auto" ]; then
		run_command "$gNet" "allmode" "2" || return 1
	elif [ "$_mode" = "lte" ]; then
		run_command "$gNet" "nroff" "2" || return 1
	elif [ "$_mode" = "nsa" ]; then
		run_command "$gNet" "modensa" "2" || return 1
	elif [ "$_mode" = "sa" ]; then
		run_command "$gNet" "modesa" "2" || return 1
	elif [ "$_mode" = "sa_only" ]; then
		run_command "$gNet" "modesa_only" "2" || return 1
	elif [ "$_mode" = "nsa_only" ]; then
		run_command "$gNet" "modensa_only" "2" || return 1
	elif [ "$_mode" = "wcdma" ]; then
		run_command "$gNet" "modewcdma" "2" || return 1
	fi
	run_command "$gNet" "roam" "2" "$roaming" || echo "roam setting error"

	if [ "$compatibility_work" == "1" ];then
		run_command "$gNet" "compatibility" "2" "" "$compatibility" "$blacklist_band"
	else
		run_command "$gNet" "compatibility" "2" "" "1"
	fi

	if [ "$custom_earfcn5" == "1" -a -n "$earfcn5" ] || [  "$custom_earfcn4" == "1" -a -n "$earfcn4"  ];then

		_res=$(_command_private_exec "$1" "NRFREQLOCK" "?")
		[ -z "$_res" ] && {
			if [ -n "$freq_all" ];then
				#if [ "$command_equal" = "1" ];then
				#	freq_all="nr-0,lte-0"
				#fi
				echo "band lock all"
				run_command "$gNet" "freq" "2" "$freq_all" || echo "freq setting error"
			fi
		}

		if [ -z "$earfreq_mode" ];then
			if [ "$custom_earfcn5" == "1" ];then
				echo "earfcn5 lock earfcn5:$earfcn5 pci5:$pci5 band5:$band5"
				run_command "$gNet" "earfcn" "2" "" "NR" "$earfcn5" "$pci5" "$band5"|| echo "earfcn setting error"
			else
				echo "earfcn5 unlock"
				run_command "$gNet" "earfcn" "2" "" "NR" "0"
			fi

			if [ "$custom_earfcn4" == "1" ];then
				echo "earfcn4 lock earfcn4:$earfcn4 pci4:$pci4 band4:$band4"
				run_command "$gNet" "earfcn" "2" "" "LTE" "$earfcn4" "$pci4" "$band4"|| echo "earfcn setting error"
			else
				echo "earfcn4 unlock"
				run_command "$gNet" "earfcn" "2" "" "LTE" "0"
			fi
		else
			if [ "$earfreq_mode" == "earfcn5"  ];then
				if [ "$custom_earfcn4" == "1" ];then
					echo "earfcn4 lock earfcn4:$earfcn4 pci4:$pci4 band4:$band4"
					run_command "$gNet" "earfcn" "2" "" "LTE" "$earfcn4" "$pci4" "$band4"|| echo "earfcn setting error"
				else
					echo "earfcn4 unlock"
					run_command "$gNet" "earfcn" "2" "" "LTE" "0"
				fi
				if [ "$custom_earfcn5" == "1" ];then
					echo "earfcn5 lock earfcn5:$earfcn5 pci5:$pci5 band5:$band5"
					run_command "$gNet" "earfcn" "2" "" "NR" "$earfcn5" "$pci5" "$band5"|| echo "earfcn setting error"
				else
					echo "earfcn5 unlock"
					run_command "$gNet" "earfcn" "2" "" "NR" "0"
				fi
			fi
			if [ "$earfreq_mode" == "earfcn4"  ];then
				if [ "$custom_earfcn4" == "1" ];then
					echo "earfcn4 lock earfcn4:$earfcn4 pci4:$pci4 band4:$band4"
					run_command "$gNet" "earfcn" "2" "" "LTE" "$earfcn4" "$pci4" "$band4"|| echo "earfcn setting error"
				else
					echo "earfcn4 unlock"
					run_command "$gNet" "earfcn" "2" "" "LTE" "0"
				fi
			fi
		fi
	else
		_res=$(_command_private_exec "$1" "NRFREQLOCK" "?")
		[ -z "$_res" -o "$earfreq_mode" != "band" ] && {
			if [ "$_alias" != "mt5700" -a  "$_alias" != "redcap" ];then
				echo "earfcn5 unlock"
				run_command "$gNet" "earfcn" "2" "" "NR" "0"
			fi
		}

		if [ "$_alias" != "mt5700" -a  "$_alias" != "redcap" ];then
			echo "earfcn4 unlock"
			run_command "$gNet" "earfcn" "2" "" "LTE" "0"
		fi

		local skip_band="$blacklist_band"
		local freq_target=""

		if [ "$custom_freq" = "0" ];then
			freq=""
		fi
		local freqArray=${freq_all//,/ }
		local nr_data=""
		for freq_item in $freqArray
		do
			local freq_data=${freq_item//-/ }
			local freq_tmp=""
			local skip=0
			key=$(echo "$freq_data"|awk -F' ' '{print $1}'|xargs -r printf)
			data=$(echo "$freq_data"|awk -F' ' '{print $2}'|xargs -r printf)

			freq_tmp=$(format_freq_data "$freq" "$key" "$freq_multi")
			[ -z "$freq_tmp" ] && {
				if [ "$compatibility_work" == "1" ] && [ "$compatibility" == "0" ] && [ "$key" == "nr" -o "$key" == "sa" -o "$key" == "nsa" ];then
					freq_tmp="$key"-"$(skip_band_data "${data}" "$skip_band")"
				else
					freq_tmp="${freq_item}"
				fi
			}

			#if [ "$command_equal" == "1" ];then
			#	if [ "$key" == "sa" -o "$key" == "nsa" ];then
			#		freq_tmp=${freq_tmp/nsa/nr}
			#		freq_tmp=${freq_tmp/sa/nr}
			#		local tmp_data=$(echo "$freq_tmp"|awk -F'-' '{print $2}'|xargs -r printf)

			#		nr_data=$(combine_band_data "$nr_data" "$tmp_data")
			#		skip=1
			#	fi
			#fi

			[ $skip -eq 0 ] && freq_target=${freq_target:+${freq_target},}${freq_tmp}
		done

		echo "freq_band:$freq_target"
		if [ $prefer_do != "1" -o "$freq_target" != "nr-0" ];then
			[ -z "$freq_target" ] && return 0
			run_command "$gNet" "freq" "2" "$freq_target" || echo "freq setting error"
		fi
	fi
	return 0
}

while getopts "i:rRdkc:t:m:s:l:L:a:f:uhS" opt; do
	case "${opt}" in
		i)
			gNet=${OPTARG}
			gNetDefault=0
			;;
		r)
			gReset=1
			;;
		R)
			gReset=2
			;;
		d)
			gDown=1
			;;
		k)
			gUp=1
			;;
		c)
			gCmd=${OPTARG}
			;;
		t)
			gType=${OPTARG}
			;;
		s)
			gSim=${OPTARG}
			;;
		S)
			gSimgpio=1
			;;
		u)
			gUpdate=1
			;;
		m)
			gMode=${OPTARG}
			;;
		l)
			gFreqLock=${OPTARG}
			;;
		L)
			gFreqLockPeak=${OPTARG}
			;;
		f)
			gProcess=${OPTARG}
			;;
		a)
			gAction=${OPTARG}
			;;			
		h)
			usage
			exit
			;;
		\?)
			usage >&2
			exit 1
			;;
	esac
done

shift $((OPTIND-1))
gExternalParam="$@"

if [ "$(check_soc_vendor)" = "quectel_opsdk" ]; then
	gNetGp="cpe"
else
	gNetGp="$gNet"
fi

gIndex=${gNet##*[A-Za-z]}

if [ "$gIndex" == "0" ];then
	gIndex=""
fi
if [ -n "$gDown" ]; then
	shutdown_power
	exit 0
fi
if [ -n "$gUp" ]; then
	keep_power
	exit 0
fi

if [ -n "$gReset" ]; then
	rst_power "$gReset"
	exit 0
fi

[ ! -d "$CPESEL_PATH" ] && mkdir -p $CPESEL_PATH

CPESEL_FS="${CPESEL_PATH}/cpesel_fs_${gNet}"
CPESEL_AT_OK="${CPESEL_PATH}/cpesel_at_ok_${gNet}"
CPESEL_GPIO_CHANGE="${CPESEL_PATH}/cpesel_gpio_change_${gNet}"
CPE_USIM_FIRST_DELAY="${CPESEL_PATH}/cpesel_usim_fdelay_${gNet}"

if [ -n "$gAction" -a  -n "$gProcess" ]; then
	[ ! -d "$CPETOOLS_PATH/${gNet}" ] && mkdir -p $CPETOOLS_PATH/${gNet}	
	if [ "$gAction" == "exclusive" ];then
		echo -n $gProcess > $CPETOOLS_PATH/${gNet}/exclusive
	else
		rm $CPETOOLS_PATH/${gNet}/exclusive
	fi
	log_info "[process lock]update ${gNet}-${gProcess} $gAction"
	exit 0
fi

if [ -n "$gSim" ]; then
	CPE_SIM_SEL_PID="/var/run/${gNet}_sim_sel.pid"
	if [ -f "$CPE_SIM_SEL_PID" ]; then
		log_info "kill switch sim: $(cat $CPE_SIM_SEL_PID)"
		kill -9 "$(cat $CPE_SIM_SEL_PID)"
		rm -f "$CPE_SIM_SEL_PID"
	fi
	switch_sim "$gSim" &
	echo "$!" > "$CPE_SIM_SEL_PID"
	log_info "switch sim running: $(cat $CPE_SIM_SEL_PID)"
	exit 0
fi

if [ -n "$gCmd" ]; then
	run_command "$gNet" "$gCmd" "$gType" $@ || exit $?
	exit 0
fi

if [ -n "$gUpdate" ]; then
	update_settings || exit 1
	exit 0
fi

if [ -n "$gFreqLock" ]; then
	update_freq_lock "$gExternalParam" || exit 1
	exit 0
fi

if [ -n "$gFreqLockPeak" ]; then
	update_peakhour_freq_lock "$gExternalParam" || exit 1
	exit 0
fi
