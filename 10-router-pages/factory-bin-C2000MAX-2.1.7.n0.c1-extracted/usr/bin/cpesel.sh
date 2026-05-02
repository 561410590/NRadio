#!/bin/ash
. /lib/netifd/netifd-proto.sh
gName="cpesel"
gWait=15
gMax=
gCur=
gModel=
gMode=
gIndex=
gCpeSoc=0
gRcnt=0
gDownTimes=4
gVDownTimes=8
gVRcnt=0
gCellularRule=""
gSimStat=1
gRegisterCache=0

trap "SimStatus=nocard" USR1
trap "SimStatus=insert" USR2

usage() {
	cat <<-EOF
		usage: $0 OPTION...
		cpe auto select daemon

		  -w      wait period, use '$gWait' seconds as default
		  -m      max sim card number
		  -M      sim switch mode
		  -b      cpe model block
		  -c      current sim card number
	EOF
}
gLogMode=$(uci -q get logservice.root.mode)
log_info() {
	logger -t "$gName Model ${gIndex}" "$*"
	if [ "$gLogMode" == "1" ] ;then
		logclient -i $gName  -l 6 -m "$*"
	fi
}

WANCHK_STATUS_DIR="/var/run/wanchk"
get_wanchk_state()
{
	local _iface=
	_iface=$(uci -q get "network.$1.network_ifname")
	[ -z "$_iface" ] && _iface="$1"

	status=$(cat $WANCHK_STATUS_DIR/iface_state/$_iface 2>/dev/null)

	if [ "$status" == "down" ];then
		if [ -f "$WANCHK_STATUS_DIR/iface_state/${_iface}_6" ];then
			status=$(cat $WANCHK_STATUS_DIR/iface_state/${_iface}_6 2>/dev/null)
		fi
	fi
	
	echo "$status"
}

async_sleep() {
	sleep "$1" &
	wait $!
}
get_signal() {
    local _iface="${gCellularRule}"
	json_init
	json_load "$(ubus call infocd cpestatus |jsonfilter -e '@.*[@.status.name="'${_iface}'"]')"
	json_get_vars up uptime
	json_select "status"
	json_get_vars rsrp
	if [ "$up" == "0" -a $uptime -gt 0 ];then
		echo "$rsrp"
	fi	
}
check_threshold(){
	local _sim=$1
	local _next=$2
	enabled=$(uci -q get cpecfg.${gCellularRule}sim${_sim}.enabled)
	[ "$enabled" == "0" ] && log_info "sim:${_sim} disabled skip,switch" &&  return 1
	threshold_type=$(uci -q get cpecfg.${gCellularRule}sim${_sim}.threshold_type)
	threshold_data=$(uci -q get cpecfg.${gCellularRule}sim${_sim}.threshold_data)
	threshold_date=$(uci -q get cpecfg.${gCellularRule}sim${_sim}.threshold_date)
	threshold_smds=$(uci -q get cpecfg.${gCellularRule}sim${_sim}.threshold_smds)
	threshold_cds=$(uci -q get cpecfg.${gCellularRule}sim${_sim}.threshold_cds)
	threshold_enabled=$(uci -q get cpecfg.${gCellularRule}sim${_sim}.threshold_enabled)
	threshold_percent=$(uci -q get cpecfg.${gCellularRule}sim${_sim}.threshold_percent)
	cross_flow=$(uci -q get cpecfg.${gCellularRule}sim${_sim}.cross_flow)
	cross_datetime=$(uci -q get cpecfg.${gCellularRule}sim${_sim}.cross_datetime)
	
	signal=$(uci -q get cpecfg.${gCellularRule}sim${_sim}.signal)

	if [ "$threshold_enabled" != "0" ];then
		[ -z "$threshold_cds" ] && threshold_cds=0
		[ -z "$threshold_smds" ] && threshold_smds=0

		if [ "$threshold_type" == "1" ];then	
			if [ "$cross_datetime" == "1" ];then
				log_info "sim:${_sim} threshold_date[$threshold_date] cross datetime skip,switch"
				return 1
			fi
			if [ -n "$threshold_data" ];then
				if [ $threshold_data -gt 0 -a "$cross_flow" == "1" ];then
					log_info "sim:${_sim} threshold_cds[$threshold_cds][$threshold_data][$threshold_percent%] overflow skip,switch"
					return 1
				fi
			fi
		else
			if [ -n "$threshold_data" ];then
				if [ $threshold_data -gt 0 -a "$cross_flow" == "1" ];then
					log_info "sim:${_sim} threshold_smds[$threshold_smds][$threshold_data][$threshold_percent%] overflow skip,switch"
					return 1
				fi
			fi
		fi
	fi
	if [ -n "$signal" -a $signal -lt 0 ];then
		[ "$_next" == "1" ] && return 0
		_sig=$(get_signal)
		[ -z "$_sig" ] || [ $_sig -ge 0 ] && return 0
		if [ $_sig -gt $signal ];then
			return 0
		else
			log_info "sig:$_sig,signal:$signal,sig is little then signal,switch"
			return 1
		fi
	fi
	return 0
}
check_sim() {
	local _sim=$1
	local _next=$2
	local threshold=
	local _sig=
	local _cnt=0

	if check_threshold "$_sim" "$_next" ;then
		return 0
	fi
	return 1
}

get_next() {
	local _max=$1
	local _cur=$2
	local _i=
	local error_sim=0

	for _i in $(seq "$((_cur+1))" "$_max") $(seq 1 "$_cur"); do
		if check_sim "$_i" "1"; then
			break
		else
			error_sim=$((error_sim+1))
		fi
	done

	echo "$_i"
}
get_register_info(){
	_info=$(cat "/tmp/infocd/cache/${gCellularRule}_dev" |jsonfilter -e '$["parameter"]["vendor"]')
	if [ -n "$_info" ];then
		_regstat=$(ubus call infocd cpeinfo "{'name':'$gCellularRule'}")
		json_load "$_regstat"
		json_get_vars STAT MODE SIM name CACHE
		if [ "$CACHE" == "1" ];then
			gRegisterCache=1
		elif [ "$CACHE" == "0" ];then
			gRegisterCache=0
		fi
		if [ "$SIM" != "ready" ]; then
			return 1			
		elif [ "$STAT" != "register" ];then
			return 2
		fi
		return 3
	fi
	return 0
}
sel_sim() {
	local _max=$1
	local _cur=$2
	local _chkst=$3
	local _stat=
	local _stat_f=
	local _next=
	local tip_error=0
	local regiser_err=0
	local sim_err=0
	local sim_max=5
	local regiser_max=10
	local sleepTime=3
	local nocard=0
	if [ "$_chkst" == "1" ];then
		if hotplug_check "$_cur" ;then
			nocard=1
		fi
		_stat=$(get_wanchk_state "${gCellularRule}")
		
		if [ "$_stat" = "up" ];then
			gRcnt=0
		else		
			while true;do
				get_register_info
				result=$?
				if [ $gRegisterCache -eq 1 ];then
					sleepTime=10
					regiser_max=4
					sim_max=3
				fi
				
				err_max=0
				if [ $result -eq 1 ];then
					sim_err=$((sim_err+1))
					err_max=$sim_max
					regiser_err=0
					err_cnt=$sim_err
					if [ $nocard -eq 1 ];then
						err_cnt=$err_max
					fi
				elif [ $result -eq 2 ];then
					sim_err=0
					regiser_err=$((regiser_err+1))
					err_max=$regiser_max
					err_cnt=$regiser_err
				else
					break
				fi
				
				if [ $err_cnt -ge $err_max ];then
					tip_error=1
					_stat_f="down"
					gRcnt=0
					if [ $sim_err -gt 0 ];then
						ubus call cpesel${gIndex} set "{'simno':'sim${_cur}', 'iccid':'none'}" > /dev/null
						log_info "sim error,check down"
					else
						log_info "register error,check down"
					fi
					
					break
				fi
				async_sleep $sleepTime
			done
			if [ $tip_error -eq 0 -a "$_stat" = "down" ];then
				gRcnt=$((gRcnt+1))
				log_info "down times,$gRcnt"
				if [ $gRcnt -ge $gDownTimes ]; then
					_stat_f="down"
					gRcnt=0
					log_info "check down"
				fi
			fi
		fi
	fi
	
	if (! check_sim "$_cur") || [ "$_chkst" = "1" -a "$_stat_f" = "down" ]; then
		_next=$(get_next "$_max" "$_cur")
		gCur="${_next:-${_max}}"
		if [ "$_cur" = "$gCur" ];then
			if ! check_sim "$_cur"; then
				log_info "no valid SIM avaliable"
			else
				log_info "restart CPE at SIM$_cur"
				if [ "$gCpeSoc" = "1" ]; then
					ubus call quec_diagd set_wan "{'action':'down'}"
					sleep 2
					ubus call quec_diagd set_wan "{'action':'up'}"
				else
					proto_set_available "${gCellularRule}" 1
					log_info "proto_set_available true"
					ifup "${gCellularRule}"
				fi
			fi
			return 1
		fi
		log_info "switch from $_cur to $gCur"
		uci -q set cpesel.$gModel.cur="$gCur"
		uci commit

		if [ -z "$cellularIndex" -o "$cellularIndex" == "0" ];then
			log_info "notice kpcped.event"
			ubus send kpcped.event
		fi
		logclient -i custom -m "[module] sim switch to $gCur"
		cpetools.sh -s "$gCur" -i "${gCellularRule}"
		return 0
	fi
	return 1
}
restart_tgt(){
	log_info "clean 4ginfo"
	[ -f "/tmp/4ginfo" ] && rm "/tmp/4ginfo"
}

sel_vsim() {
	local _sim="$1"
	local _stat=
	local _stat_f=
	local _next=
	local _vsim=
	local auto=0
	local set_data="1"
	nettype=$(uci -q get "network.${gCellularRule}.nettype")
	vsim_support=$(uci -q get network.${gCellularRule}.vsim)
	if [ "$vsim_support" != "1" -o "$nettype" != "cpe" ]; then
		return 0
	fi

	_vsim=$(uci -q get cpesel.$gModel.vsim)
	if [ "$_vsim" == "2" ];then
		auto=1
	elif [ "$_vsim" == "1" ];then
		set_data="0"
	else
		set_data="1"
	fi
	_vsimstatus=$(cat "/etc/vsim")
	[ -z "$_vsimstatus" ] && _vsimstatus="1" && echo -n "1" > "/etc/vsim" && restart_tgt
	if [ $auto -eq 1 ];then
		set_data="$_vsimstatus"
		_stat=$(get_wanchk_state "${gCellularRule}")
		if [ "$_stat" = "down" ];then
			gVRcnt=$((gVRcnt+1))
			log_info "down times,$gVRcnt"
			if [ $gVRcnt -ge $gVDownTimes ]; then
				_stat_f="down"
				gVRcnt=0
				log_info "check down"
			fi
		elif [ "$_stat" = "up" ];then
			gVRcnt=0
		fi

		if [ "$_stat_f" = "down" ]; then
			if [ "$_vsimstatus" == "0" ];then
				set_data="1"
				log_info "change to Physical SIM"
			elif [ "$_vsimstatus" == "1" ];then
				log_info "change to VSIM"
				set_data="0"
			fi
		fi
	fi
	if [ "$_vsimstatus" != "$set_data" ];then
		echo -n "$set_data" > "/etc/vsim"
		log_info "change to $set_data"
		restart_tgt
	fi	
}
while getopts "w:c:b:m:M:h" opt; do
	case "${opt}" in
		w)
			gWait=${OPTARG}
			;;
		m)
			gMax=${OPTARG}
			;;
		M)
			gMode=${OPTARG}
			;;
		c)
			gCur=${OPTARG}
			;;
		b)
			gModel=${OPTARG}
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
log_info "service start..."

[ -n "$gModel" ] || gModel="sim"
gIndex=${gModel##*[A-Za-z]}
[ -f "/bin/serial_atcmd" ] && gCpeSoc=1

cellular=$(uci -q get network.globals.default_cellular)
[ -z "$cellular" ] && cellular="cpe"
cellularIndex=${cellular##*[A-Za-z]}
if [ "$cellularIndex" == "0" -a -n "$gIndex" ];then
	gCellularRule="${cellular%%[0-9]*}$gIndex"
else
	gCellularRule="${cellular}$gIndex"
fi

gval=$(uci -q get cpesel.$gModel.gval)
[ -n "$gval" ] && cpetools.sh -s "$gCur" -i "$gCellularRule"

get_sim_gpio_val() {
	local _sum="$1"
	local _gval=

	_gval=$(uci -q get cpesel.sim${gIndex}.gval)

	[ -z "$_gval" ] && _gval="01,10,11"

	echo "$_gval"|cut -d, -f "$_sum"
}
hotplug_check(){
	local _cur="$1"
	if [ "$SimStatus" == "nocard" ];then		
		async_sleep 1
	fi
	if [ "$SimStatus" == "insert" ];then
		SimStatus=""
		log_info "hotplug found sim${_cur} insert"
	elif [ "$SimStatus" == "nocard" ];then
		SimStatus=""
		log_info "hotplug found sim${_cur} no card"
		return 0
	fi
	return 1 
}
reset_sim(){
	local _cur="$1"
	if hotplug_check "$_cur" ;then
		cpetools.sh -i "$gCellularRule" -c rstsim
	fi
	get_register_info
	result=$?
	if [ $result -eq 1 ];then
		ubus call cpesel${gIndex} set "{'simno':'sim${_cur}', 'iccid':'none'}" > /dev/null
		cpetools.sh -i "$gCellularRule" -c rstsim
		if [ $gSimStat -eq 1 ];then
			gSimStat=0
			log_info "sim${_cur} no card,ifup $gCellularRule"
			ifup "$gCellularRule"
		fi
	elif [ $result -ne 0 ];then
		if [ $gSimStat -eq 0 ];then
			gSimStat=1
			log_info "sim${_cur} ready,ifup $gCellularRule"
			ifup "$gCellularRule"
		fi
	fi
}

if [ -z "$gMax" -o "$gMode" == "1" ]; then
	while true; do
		check_threshold "$gCur"		
		sel_vsim "$gCur"
		reset_sim "$gCur"
		async_sleep "$gWait"
	done
fi

sel_sim "$gMax" "$gCur" "0"

sel_sim_res=1
while true; do
	if [ $sel_sim_res -eq 1 ];then 
		async_sleep "$gWait"
	else
		async_sleep "3"
	fi
	
	sel_sim "$gMax" "$gCur" "1"
	sel_sim_res=$?
done
