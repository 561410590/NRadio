#!/bin/ash
. /lib/functions/network.sh
dWait=3
gWait=$dWait
dDWan="wan"
gDWan=$dDWan
dBWan="cpe"
gBWan=$dBWan

cellular=$(uci -q get network.globals.default_cellular)
[ -z "$cellular" ] && cellular="cpe"


resolv_priority="/tmp/resolv.conf.auto"
[ -d "/tmp/resolv.conf.d" ] && resolv_priority="/tmp/resolv.conf.d/resolv.conf.auto"
gName="wanswd"
g6=0
gV6F=""
gVendor=$(uci -q get network.nrswitch.vendor)
gLogMode=$(uci -q get logservice.root.mode)
usage() {
	cat <<-EOF
		usage: $0 OPTION...
		Auto wan switch daemon.

		  -w      wait period, use '$dWait' seconds as default
		  -i      default wan interface, use '$dDWan' as default
		  -b      backup wan interface,  use '$dBWan' as default
	EOF
}

log_info() {
	logger -t "$gName" "$*"
	if [ "$gLogMode" == "1" ] ;then
		logclient -i $gName  -l 6 -m "$*"
	fi
}

chk_iface_up() {
	local _wan="$1"
	if [ $g6 -eq 1 ];then
		_wan=$(echo "$1"|sed 's/^'${cellular}'$/'${cellular}'_6/')
	fi
	ubus call wanchk get "{'name':'$_wan'}"|jsonfilter -e "\$['$_wan']"|grep -qsx up
}

get_def_route_if() {
	if [ "$gVendor" = "tdtech" ] && [ -n "$gV6F" ]; then
		ip $gV6F route show|tail -n +3|grep -sw default|grep -v from|sed 's/.*dev //'|awk '{print $1}'|tail -n 1
	else
		ip $gV6F route show|grep -sw default|grep -v from|sed 's/.*dev //'|awk '{print $1}'|tail -n 1
	fi
}

get_l3_device() {
	ubus call "network.interface.$1" status|jsonfilter -e '$["l3_device"]'
}

get_gw_ip() {
	ubus call "network.interface.$1" status|jsonfilter -e '$["route"][-1]["nexthop"]'
}

set_default_wan() {
	local _wan="$1"
	local _gwip=
	local _proto=$(uci -q get network.${_wan}.proto)
	log_info "change default wan to $1"
	network_flush_cache

	if [ $g6 -eq 0 ];then
		if ubus list|grep -q "$1"_4 ;then
			_wan=$(echo "$1"|sed 's/^'$1'$/'$1'_4/')
		fi
		network_get_gateway "_gwip" "$_wan" 1
	else
		if ubus list|grep -q "$1"_6 ;then
			_wan=$(echo "$1"|sed 's/^'$1'$/'$1'_6/')
		fi
		network_get_gateway6 "_gwip" "$_wan" 1
	fi

	if [ -n "$_gwip" ]; then
		log_info "change default gateway to $_gwip"
		ip $gV6F route del default
		if [ -n "$3" ];then
			if [ "$_gwip" != "0.0.0.0" -a "$_gwip" != "::" ];then
				ip $gV6F route add default via "$_gwip" dev "$3"
			else
				ip $gV6F route add default dev "$3"
			fi
		else
			ip $gV6F route add default via "$_gwip"
		fi
	elif [ "$_proto" = "tdmi" ]; then
		ip $gV6F route del default
		ip $gV6F route add default dev "$3"
	else
		log_info "cannot get gateway ip"
	fi
	keep_dns_priority "$1" "$2"
}

keep_dns_priority(){
	local priority=0
	local second=0
	local priority_deal=0
	local second_deal=0
	local back_resolv_priority="/tmp/resolv.conf.auto.$1"
	local back_resolv_second="/tmp/resolv.conf.auto.$2"

	if [ $g6 -eq 1 ];then
		return
	fi

	cat $resolv_priority | while read line
	do
		if echo "${line}" |grep -qEs "$1$";then
			priority=1
			[ $priority_deal == 0 ] && echo -n "" > $back_resolv_priority && priority_deal=1
			echo ${line} >> $back_resolv_priority
		else
			if [ "$priority" = "1" ];then
				if echo "${line}" |grep -qs "#" ;then
					priority=0
				fi
			fi
			if [ "$priority" = "0" ];then
				if echo "${line}" |grep -qEs "$2$";then
					second=1
					[ $second_deal == 0 ] && echo -n "" > $back_resolv_second && second_deal=1
					echo ${line} >> $back_resolv_second
				elif [ "$second" = "1" ];then
					if echo "${line}" |grep -qs "#" ;then
						second=0
					else
						echo ${line} >> $back_resolv_second
					fi
				fi

			else
				echo ${line} >> $back_resolv_priority
			fi
		fi
	done
	back_resolv=$(md5sum $back_resolv_priority |cut -b -32)
	priority_resolv=$(md5sum $resolv_priority |cut -b -32)

	if [ "$back_resolv" !=  "$priority_resolv" ];then
		cp $back_resolv_priority $resolv_priority
	fi
}

check_dns_priority() {
	local priority_name=$1
	local after_name=$2
	local reset_dns=0
	if ! cat $resolv_priority |grep -qs "$priority_name$";then
		reset_dns=1
	fi

	if [ "$priority_name" != "$after_name" ];then
		if cat $resolv_priority |grep -qs "$after_name";then
			reset_dns=1
		fi
	fi
	if [ "$reset_dns" = "1" ];then
		keep_dns_priority "$1" "$2"
	fi
}

chk_wan() {
	local _cur=
	local _def=
	local _bak=

	_cur=$(get_def_route_if)
	_def=$(get_l3_device "$gDWan")

	if chk_iface_up "$gDWan"; then
		if [ "$_cur" != "$_def" ]; then
			set_default_wan "$gDWan" "$gBWan" "$_def"
		else
			check_dns_priority "$gDWan" "$gBWan"
		fi
	elif [ "$gDWan" != "$gBWan" ] && chk_iface_up "$gBWan"; then
		_bak=$(get_l3_device "$gBWan")
		if [ "$_cur" != "$_bak" ]; then
			set_default_wan "$gBWan" "$gDWan" "$_bak"
		else
			check_dns_priority "$gBWan" "$gDWan"
		fi
	fi
}

while getopts "w:i:b:h" opt; do
	case "${opt}" in
	w)
		gWait=${OPTARG}
		;;
	i)
		gDWan=${OPTARG}
		;;
	b)
		gBWan=${OPTARG}
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

if echo "$gDWan"|grep -sq "6" || echo "$gBWan"|grep -sq "6";then
	gV6F="-6"
	g6=1
fi

while true; do
	sleep "$gWait"

	chk_wan
done
