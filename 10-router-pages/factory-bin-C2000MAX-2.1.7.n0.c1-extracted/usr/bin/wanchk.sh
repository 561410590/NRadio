#!/bin/ash
. /lib/functions.sh
. /lib/functions/network.sh
. /lib/netifd/netifd-proto.sh
IFUP_WAIT_TIME=10

WANCHK_STATUS_DIR="/var/run/wanchk"
gWait=10
gTable=23
gCellularSpecailTable=1000
dIface="wan"
gIface=$dIface
g6Iface=$dIface
gUbusIface=$dIface
g6UbusIface=$dIface
gName="wanchk"
gSrvs="i.root-servers.net a.root-servers.net"
gPdns1="210.2.4.8"
gPdns2="1.2.4.8"
g6Pdns1="2400:3200:baba::1"
g6Pdns2="2400:3200::1"
gOldRoute=""
gOldL3=""
g6OldRoute=""
g6OldL3=""
gRconnDefault=0
gPdns=""
g6Pdns=""
gPingTimeout=
gPingTry=
gEips=""
g6Eips=""
gNew=up
g6New=up
gOrx=0
gMind=0
gFlowLimit=0
gRcnt=0
g6Rcnt=0
gATtime=0
g6ATtime=0
gRconn=$gRconnDefault
gFirst=1
g6First=1
gNet=""
g6Net=""
gCpe=0
gCpeSoc=0
gMax=3
gMaxP=6
gDnsOpen=1
gPingOpen=1
gV4=""
gV6=""
gV6Renewtime=0
loopCheckMode="normal"
cpeStatus=""
gVsim=0
gLogMode=$(uci -q get logservice.root.mode)
gIPCheck=1

gWan6=$(uci -q get network.globals.default_wan6)
[ -z "$gWan6" ] && gWan6="wan6"

usage() {
	cat <<-EOF
		Usage: $0 OPTION...
		Net link check daemon.

		  -w      wait period, use '$gWait' seconds as default
		  -e      extra ipaddrs to check
		  -E      extra ip6addrs to check
		  -i      interface name, use '$dIface' as default
		  -r      auto restart interface, disable as default
		  -C      whether is a CPE interface, not a CPE as default
		  -d      custom dns server
		  -R      custom dns6 server
		  -t      ping timeout once
		  -c      ping times once
		  -m      max fail before ifup
		  -M      max fail before power reset
		  -D      control dns check
		  -P      control ping check
	EOF
}

trap "loopCheckMode=recovery" USR1
trap "loopCheckMode=pause" USR2

async_sleep() {
        sleep "$1" &
        wait $!
}

log_info() {
	logger -t "$gName" "$gNet: $*"
	if [ "$gLogMode" == "1" ] ;then
		logclient -i $gName  -l 6 -m "$gNet: $*"
	fi
}
log_debug() {
	logger -t "$gName" -p 7 "$gNet: $*"
	if [ "$gLogMode" == "1" ] ;then
		logclient -i $gName  -l 7 -m "$gNet: $*"
	fi
}
check_iface_up() {
	ubus call "network.interface.$1" status|jsonfilter -e '$["up"]'|grep -qsw true
}

get_delta() {
	local _nbyte=$1
	local _obyte=$2
	local _delta=0

	if [ "$_obyte" != "0" ];then
		_delta=$((_nbyte - _obyte))
	fi

	if [ $_delta -lt 0 ];then
		echo "0"
		return
	fi

	echo "$_delta"
}

get_def_route_if() {
	ip route show|grep -sw default|awk '{print $5}'
}

get_l3_device() {
	ubus call "network.interface.$1" status|jsonfilter -e '$["l3_device"]'
}

get_device() {
	ubus call "network.interface.$1" status|jsonfilter -e '$["device"]'
}

get_if_dns() {
	ubus call "network.interface.$1" status|jsonfilter -e '$["dns-server"][0]'
}

get_if_def_route() {
	ubus call "network.interface.$1" status|jsonfilter -e '$["route"][-1]["nexthop"]'
}

check_stats() {
	local _device=
	local _dir=
	local _rxf=
	local _rxb=0
	local _rxd=0
	local _res=1
	local _lim="$2"

	_device=$(get_device "$1")
	_dir="/sys/class/net/$_device/statistics"
	_rxf="$_dir/rx_bytes"

	if [ ! -f "$_rxf" ]; then
		return "$_res"
	fi

	_rxb=$(cat "$_rxf")

	_rxd=$(get_delta "$_rxb" "$gOrx")

	if [ "$_rxd" -ge "$_lim" ]; then
		_res=0
	fi

	gOrx=$_rxb

	return "$_res"
}

check_dns() {
	local _iface="$1"
	local _srv=
	local _dns=
	local _pids=
	local _dns_fail_info="dns check fail"

	if echo "$_iface"|grep -sq "6" ;then
		_dns="$g6Pdns"
		_dns_fail_info="dns6 check fail"
	else
		_dns="$gPdns"
	fi

	[ -z "$_dns" ] && return 1

	_pids=""
	for _srv in $gSrvs; do
		nslookup "$_srv" "$_dns" >$WANCHK_STATUS_DIR/iface_state/dns_check.$_iface.$_srv 2>&1 &
		_pids="$_pids $!"
	done

	for _pid in $_pids; do
		if wait "$_pid"; then
			return 0
		fi
	done

	if cat "$WANCHK_STATUS_DIR/iface_state/dns_check.$_iface.*"|grep -qs "Address 1";then
		log_info "dns check return err,but exsit one ok"
		return 0
	fi

	#log_info "$_dns_fail_info"
	return 1
}

check_ping() {
	local _iface="$1"
	local _l3="$2"
	local _ipaddr=
	local _pids=""
	local _gipaddr=
	local _ping_fail_info="ping check fail"
	local v6="-4"

	if echo "$_iface"|grep -sq "6" ;then
		_gipaddr="$g6Eips"
		_ping_fail_info="ping6 check fail"
		v6="-6"
	else
		_gipaddr="$gEips"
	fi

	[ -z "$_gipaddr" ] && return 0

	for _ipaddr in $_gipaddr; do
		ping $v6 -c$gPingTry -W$gPingTimeout -I "$_l3" "$_ipaddr" >$WANCHK_STATUS_DIR/iface_state/ip_check.$_iface.$_ipaddr &
		_pids="$_pids $!"
	done

	for _pid in $_pids; do
		if wait "$_pid"; then
			return 0
		fi
	done

	if cat "$WANCHK_STATUS_DIR/iface_state/ip_check.$_iface.*"|grep -qs "from";then
		log_info "ip check return err,but exsit one ok"
		return 0
	fi

	if [ "$gCpe" -eq 1 -a -z "$v6" ];then
		log_info $(ifconfig "$_l3")
		log_info $(route -n |grep "$_l3")
		log_info $(cpetools.sh -i "$gNet" -c analysis)
		log_info "$_ping_fail_info"
	fi

	return 1
}

check_all() {
	local _gwif=
	local _limit=
	local _nets="$1"
	local _ifaces="$2"
	local _ifaces_label="$3"
	local _l3="$4"
	local _Ostatus="$5"

	set_route "$_ifaces" "$_ifaces_label" "$_l3"

	if [ "$gDnsOpen" == "0" -a "$gPingOpen" == "0" ]; then
		if check_iface_up "$_ifaces" ;then
			return 0
		else
			return 1
		fi
	fi

	[ -z "$_l3" ] && return 1

	if [ $gCpe -eq 1 ]; then
		_limit=$((gMind*$gWait))
	else
		_limit=$((gMind*$gWait))
	fi

	# Check user RX
	if check_stats "$_ifaces" "$_limit"; then
		return 0
	fi

	if [ $gCpe -eq 1 -a "$gIPCheck" == "1" ]; then
		if [ "$_Ostatus" == "up" ];then
			connstat=$(cpetools.sh -i "$_nets" -c connstat)
			if echo "$_ifaces_label"|grep -sq "6" ;then
				connstat_item=$(echo "$connstat"|jsonfilter -e '$["IPV6"]')
			else
				connstat_item=$(echo "$connstat"|jsonfilter -e '$["IPV4"]')
			fi

			if [ "$connstat_item" == "1" ];then
				if echo "$_ifaces_label"|grep -sq "6" ;then
					g6ATtime=$(((g6ATtime+1)%6))
					if [ $g6ATtime -ne 0 ];then
						return 0
					fi
				else
					gATtime=$(((gATtime+1)%6))
					if [ $gATtime -ne 0 ];then
						return 0
					fi
				fi
			fi
		fi
	fi

	if [ "$gDnsOpen" == "1" ]; then
		# Check dns parallelly
		if check_dns "$_ifaces_label"; then
			return 0
		fi
	fi

	if [ "$gPingOpen" == "1" ]; then
		# Check Ping
		if check_ping "$_ifaces_label" "$_l3"; then
			return 0
		fi
	fi

	return 1
}

power_ctl(){
	local _net="$1"
	status=$(cat $WANCHK_STATUS_DIR/iface_state/"${_net}_power" 2>/dev/null)
	if [ "$status" == "1" ];then
		log_info "ignore power down"
	else
		$(cpetools.sh -i "$_net" -c reset)
		proto_set_available "$_net" 1
	fi
}

restart_iface() {
	local _count=$1
	local _net=$2

	if [ $_count -ge $gMax ]; then
		if [ $gCpe -eq 1 ]; then
			if [ $_count -ge $gMaxP ]; then
				log_info "call failsafe"
				power_ctl "$_net"
				return 0
			fi
		fi
		if [ "$gCpeSoc" = "1" ]; then
			ubus call quec_diagd set_wan "{'action':'down'}"
			sleep 2
			ubus call quec_diagd set_wan "{'action':'up'}"
		else
			ifup "$_net"
		fi
	fi
	return 1
}

sync_mesh_netstatus(){
`lua -e "
	local ca = require \"cloudd.api\"
	ca.sync_controller_netstat()
	"`
}
get_wanchk_state_name(){
	local _iface="$1"
	local _net="${_iface%%_*}"
	if ! echo "$_iface"|grep -sq "_4" ;then
		echo "$_iface"
	else
		echo "$_net"
	fi
}

set_wanchk_state(){
	local state_name="$1"
	local _status="$2"
	echo -n $_status > $WANCHK_STATUS_DIR/iface_state/$state_name
}
set_net_status() {
	local _iface=
	local _status=
	local net_label="wan"
	local net_type="v4"
	_iface="$1"
	_status="$2"

	local state_name="$(get_wanchk_state_name $_iface)"
	if [ $gCpe -eq 1 ];then
		net_label="cellular"
	fi
	if echo "$_ifaces_label"|grep -sq "6" ;then
		net_type="v6"
	fi
	logclient -i custom -m "[net] $net_label $net_type $_status"

	log_info "update $_iface status to $_status"
	set_wanchk_state "$state_name" "$_status"
	ubus -S call "$gName" set "{'name':'$state_name','status':'$_status'}" >/dev/null 2>&1
	sync_mesh_netstatus
}

mwan3_get_iface_id()
{
	config_load mwan3
	local _tmp _iface _iface_count

	_iface="$2"

	mwan3_get_id()
	{
		let _iface_count++
		[ "$1" == "$_iface" ] && _tmp=$_iface_count
	}
	config_foreach mwan3_get_id interface
	export "$1=$_tmp"
}

set_route() {
	local _iface=$1
	local _ifaces_label="$2"
	local _oldroute=""
	local _oldl3=""
	local v6=""
	_l3="$3"
	_route=""

	network_flush_cache
	if echo "$_ifaces_label"|grep -sq "6" ;then
		network_get_gateway6 "_route" "$_iface" 1
		_oldroute=$g6OldRoute
		_oldl3=$g6OldL3
		v6="-6"
		table=$g6Table
	else
		network_get_gateway "_route" "$_iface" 1
		_oldroute=$gOldRoute
		_oldl3=$gOldL3
		table=$gTable
	fi
	#log_info "_iface:$_iface,_l3 $_l3,_oldl3 $_oldl3,_oldroute:$_oldroute"
	if [ -n "$_l3" -a "$_l3" != "$_oldl3" ];then
		ip $v6 rule del pref $((table+100))
		ip $v6 rule add pref $((table+100)) oif "$_l3" table "$table"
		#log_info "_iface:$_iface,ip $v6 rule add pref $((table+100)) iif $_l3 oif $_l3 table $table"
	fi
	if [ -n "$_l3" ];then
		[ "$_l3" != "$_oldl3" -o "$_route" != "$_oldroute" ] && {
			ip $v6 route flush table "$table"
			if [ -n "$_route" -a "$_route" != "::" ];then
				ip $v6 route add table "$table" default via $_route dev $_l3
			else
				ip $v6 route add table "$table" default dev $_l3
			fi
			#log_info "_iface:$_iface,ip $v6 route add table $table default via $_route dev $_l3"
			if echo "$_ifaces_label"|grep -sq "6" ;then
				g6OldL3="$_l3"
				g6OldRoute="$_route"
			else
				gOldL3="$_l3"
				gOldRoute="$_route"
			fi
		}
	fi

	[ -n "$_oldl3" -a -n "$_oldroute" ] && {
		if ! ip $v6 route show table "$table" |grep -sq "$_oldl3";then
			ip $v6 route flush table "$table"
			if [ -n "$_oldroute"  -a "$_oldroute" != "::"  ];then
				ip $v6 route add table "$table" default via $_oldroute dev $_oldl3
			else
				ip $v6 route add table "$table" default dev $_oldl3
			fi
		fi
	}
}
check_vsim(){
	if [ $gVsim -eq 1 ];then
		vsim_active=$(cat "/etc/vsim")
		if [ "$vsim_active" == "0" ];then
			gRconn="0"
			max_dail_time=1
		else
			max_dail_time=6
			if [ "$gRconn" != "$gRconnDefault" ];then
				gRconn="$gRconnDefault"
				log_info "gRconn recovery default $gRconn"
			fi
		fi
	fi
}
init_base_config(){
	gNet="${gIface%%_*}"
	[ -d $WANCHK_STATUS_DIR ] || mkdir -p $WANCHK_STATUS_DIR/iface_state

	if [ $gCpe -eq 1 ];then
		gMind=10240
		g6Iface="${gIface%%_*}_6"
		if [ "$gNet" == "$gIface" ];then
			g6UbusIface="${gIface%%_*}"
		else
			g6UbusIface="${gIface%%_*}_6"
		fi
		[ -f "/bin/serial_atcmd" ] && gCpeSoc=1
		[ -z "$gPdns" ] && gPdns=$gPdns2
		[ -z "$g6Pdns" ] && g6Pdns=$g6Pdns2
		IFUP_WAIT_TIME=40
		[ -z "$gPingTimeout" ] && gPingTimeout=12
		gTable=24
		g6Table=$gTable
		g6Net=$gNet
		gIPCheck=$(uci -q get "network.$gNet.ipcheck")
		[ -z "$gIPCheck" ] && gIPCheck="1"

		nettype=$(uci -q get "network.$gNet.nettype")
		vsim_support=$(uci -q get network.$gNet.vsim)

		if [ "$vsim_support" == "1" -a "$nettype" == "cpe" ]; then
			gVsim=1
		fi
		check_vsim
		[ "$gRconn" == "0" ] && max_dail_time=1
		log_info "ipcheck:$gIPCheck"
	else
		gMind=204800
		g6Table=$gTable
		g6Net="${gWan6}"
		g6Iface=$g6Net
		g6UbusIface=$g6Iface
		[ -z "$gPdns" ] && gPdns=$gPdns1
		[ -z "$g6Pdns" ] && g6Pdns=$g6Pdns1

		[ -z "$gPingTimeout" ] && gPingTimeout=5
	fi

	[ $gFlowLimit -gt 0 ] && gMind=$gFlowLimit
	[ -z "$gPingTry" ] && gPingTry=3
	[ -z "$gEips" ] &&  gEips="$gPdns"
	[ -z "$g6Eips" ] &&  g6Eips="$g6Pdns"
	
	log_info "interval:$gWait"
	log_info "flow:$gMind"
	log_info "check:$gWait"
	log_info "ping[open:$gPingOpen][ip:$gEips,ip6:$g6Eips][times:$gPingTry][timeout:$gPingTimeout]"
	log_info "dns[open:$gDnsOpen][server:$gPdns,server6: $g6Pdns]"
	log_info "do recovery:$gRconn"
	log_info "fail max before restart:$gMax"
	log_info "fail max before power reset:$gMaxP"
	log_info "max_dail_time:$max_dail_time"

	if [ -f "/etc/config/mwan3" ];then
		mwan3_get_iface_id id "$gIface"
		mwan3_get_iface_id id6 "$g6UbusIface"
		[ -n "$id" ] && {
			gTable=$((id))
			ip rule del pref $(($gTable+120))
			ip rule del pref $(($gTable+130))
			ip rule del pref $(($gTable+140))
			[ -n "$gPdns" ] && {
				ip rule add pref $(($gTable+120)) to "$gPdns" iif br-lan lookup main
				ip rule add pref $(($gTable+130)) to "$gPdns" table "$gTable"				
				ip rule add pref $(($gTable+140)) to "$gPdns" unreachable
			}
		}
		[ -n "$id6" ] && {
			g6Table=$((id6))
			ip -6 rule del pref $(($g6Table+120))
			ip -6 rule del pref $(($g6Table+130))
			ip -6 rule del pref $(($g6Table+140))
			[ -n "$g6Pdns" ] && {
				ip -6 rule add pref $(($g6Table+120)) to "$g6Pdns" iif br-lan lookup main
				ip -6 rule add pref $(($g6Table+130)) to "$g6Pdns" table "$g6Table"				
				ip -6 rule add pref $(($g6Table+140)) to "$g6Pdns" unreachable
			}
		}
	else
		ip rule del pref $((gTable+200))
		ip rule add pref $((gTable+200)) to "$gPdns" iif br-lan lookup main
		ip rule del pref $((gTable+300))
		ip rule add pref $((gTable+300)) to "$gPdns" table "$gTable"
		ip rule del pref $((gTable+400))
		ip rule add pref $((gTable+400)) to "$gPdns" unreachable
		ip -6 rule del pref $((gTable+200))
		ip -6 rule add pref $((gTable+200)) to "$g6Pdns" iif br-lan lookup main
		ip -6 rule del pref $((gTable+300))
		ip -6 rule add pref $((gTable+300)) to "$g6Pdns" table "$gTable"
		ip -6 rule del pref $((gTable+400))
		ip -6 rule add pref $((gTable+400)) to "$g6Pdns" unreachable
	fi
	if [ $gCpe -eq 1 ];then
		ip rule del pref $gCellularSpecailTable
		ip rule add pref $gCellularSpecailTable fwmark 6868 unreachable
		ip -6 rule del pref $gCellularSpecailTable
		ip -6 rule add pref $gCellularSpecailTable fwmark 6868 unreachable
	fi
}

check_net_using()
{
	disabled=$(uci -q get network.$1.disabled)
	[ "$disabled" = "1" ] && return 1

	return 0
}
check_net6_using()
{
	ipv6_enabled=$(uci -q get network.$1.ipv6)
	[ "$ipv6_enabled" = "0" ] && return 1
	return 0
}
check_main(){
	_Nstatus="down"
	_nets="$1"
	_ifaces="$2"
	_ifaces_label="$3"
	_Ostatus="$4"
	_first=""
	_failcnt=
	_info=""
	_do_restart=0
	_ip_diff_check=0

	if echo "$_ifaces_label"|grep -sq "6" ;then
		_failcnt=$g6Rcnt
		_info="v6"
		_first="$g6First"
	else
		_failcnt=$gRcnt
		_first="$gFirst"
	fi

	_l3=$(get_l3_device "$_ifaces")

	if [ "$gIPCheck" == "1" ];then
		if  check_net_using "$_nets" &&  [ $gCpe -eq 1 ];then
			if [ -z "$_info" ];then
				check_ip "$_nets" "$_l3"
			else
				check_ip6 "$_nets" "$_l3"
			fi
			_ip_diff_check=$?
		fi
	fi

	if [ $_ip_diff_check -eq 2 -o $_ip_diff_check -eq 1 ];then
		if [ -n "$_info" ];then
			tik=$(awk -F '.' '{print $1}' /proc/uptime)
			local diff_time=$((tik-gV6Renewtime))
			if [ $diff_time -ge 20 ];then
				gV6Renewtime=$tik
				log_info "$_info dhcp renew $_ifaces right now($tik,$diff_time)"
				ubus call network.interface notify_proto "{'interface':'$_ifaces','action':2,'signal':15}"
			fi
		else
			log_info "$_info dhcp renew $_ifaces right now"
			ubus call network.interface notify_proto "{'interface':'$_ifaces','action':2,'signal':15}"
		fi
	fi

	if check_all "$_nets" "$_ifaces" "$_ifaces_label" "$_l3" "$_Ostatus" ; then
		_Nstatus="up"
		_failcnt=0
	fi

	if [ "$_Nstatus" != "$_Ostatus" ]; then
		log_info "link $_ifaces_label -> $_Nstatus"
		set_net_status "$_ifaces_label" "$_Nstatus"
		if [ "$_Nstatus" = "down" -a $_ip_diff_check -eq 0 -a -n "$_info"  ];then
			log_info "$_info dhcp renew $_ifaces right now as for down	"
			ubus call network.interface notify_proto "{'interface':'$_ifaces','action':2,'signal':15}"
		fi
	else
		[ $_first = 1 ] && set_net_status "$_ifaces_label" "$_Nstatus"
	fi

	_Ostatus=$_Nstatus

	if [ "$_Nstatus" = "down" ] && [ "$gRconn" = "1" ]; then
		if check_net_using "$_nets" ;then
			if [ $_ip_diff_check -eq 1 ];then
				_do_restart=1
				log_info "$_info restart iface right now"
				ifup "$_nets"
				async_sleep "$IFUP_WAIT_TIME"
				_failcnt=$((_failcnt+1))
			fi

			if [ $_do_restart -eq 0 ];then
				if [ "$gCpe" -ne 1 ] || [ "$cpeStatus" = "down" ];then
					[ "$_ifaces" != "wisp" ] && {
						_failcnt=$((_failcnt+1))
						if [ "$gCpe" -eq 1 ]; then
							log_info "$_ifaces_label fail times:$_failcnt"
						fi

						if restart_iface "$_failcnt" "$_nets" ;then
							_failcnt=0
							g6Rcnt=0
							gRcnt=0
						fi

						if [ $_failcnt -ge $gMax -o $_failcnt -eq 0 ];then
							log_info "$_info restart iface,sleepTime:$IFUP_WAIT_TIME"
							async_sleep "$IFUP_WAIT_TIME"
						fi
					}
				fi
			fi
		fi
	fi

	if echo "$_ifaces_label"|grep -sq "6" ;then
		g6Rcnt=$_failcnt
		g6First=0
	else
		gRcnt=$_failcnt
		gFirst=0
	fi

	if [ "$_Nstatus" == "up" ];then
		return 0
	fi
	return 1
}

check_ip6(){
	_nets="$1"
	_l3="$2"

	ret=0
	ips="$(cpetools.sh -i "$_nets" -c ips)"
	_ip6="$(echo "$ips"|jsonfilter -e "\$['IPV6']")"

	if [ -n "$_ip6" ];then
		if [ -z "$gV6" ];then
			gV6=$_ip6
			log_info "gV6 set to $_ip6"
		else
			if [ "$_ip6" != "$gV6" ];then
				log_info "gV6 change to $_ip6"
				gV6="$_ip6"
			fi

			ip_info=$(ip address show dev "$_l3"|grep "inet6 "|grep -v "fe80")
			[ -z "$ip_info" ] && return 2
			#first_ip=$(echo "$ip_info"|awk '{print $2}'|sed -n "1p")
			#if ! echo "$first_ip" |grep "$_ip6";then
			#	log_info "first_ip :$first_ip"
			#	ip address del $first_ip dev "$_l3"
			#	log_info "$_l3 has't correct ip[$ip_info][$_ip6]" && return 2
			#fi
		fi
	fi
	return $ret
}


check_ip(){
	_nets="$1"
	_l3="$2"

	ret=0
	ips="$(cpetools.sh -i "$_nets" -c ips)"
	_ip4="$(echo "$ips"|jsonfilter -e "\$['IPV4']")"

	if [ -n "$_ip4" ];then
		if [ -z "$gV4" ];then
			gV4=$_ip4
			log_info "gV4 set to $_ip4"
		else
			if [  "$_ip4" != "$gV4" ];then
				log_info "gV4 change to $_ip4"
				gV4=$_ip4
			fi

			ip_info=$(ip address show dev "$_l3"|grep "inet "|grep -v "${_l3}:1")
			[ -z "$ip_info" ] && log_info "$_l3 has't ip" && return 1
			first_ip=$(echo "$ip_info"|awk '{print $2}'|sed -n "1p")
			if ! echo "$first_ip" |grep "$_ip4";then
				if ! echo "$first_ip" |grep -q "192.168";then
					if [ -f "/usr/sbin/ul_ipsec_recovery.sh" ]; then
						if echo "$first_ip" |grep -q "172.16";then
							return $ret
						fi
					fi
					log_info "first_ip :$first_ip"
					ip address del $first_ip dev "$_l3"
					log_info "$_l3 has't correct ip[$ip_info][$_ip4]" && return 2
				fi
			fi

		fi
	fi

	return $ret
}
while getopts "w:e:t:c:d:i:m:E:R:M:l:P:D:rCh" opt; do
	case "${opt}" in
	w)
		gWait=${OPTARG}
		;;
	e)
		gEips=${OPTARG}
		;;
	E)
		g6Eips=${OPTARG}
		;;
	t)
		gPingTimeout=${OPTARG}
		;;
	m)
		gMax=${OPTARG}
		;;
	M)
		gMaxP=${OPTARG}
		;;
	l)
		gFlowLimit=${OPTARG}
		;;
	d)
		gPdns=${OPTARG}
		;;
	R)
		g6Pdns=${OPTARG}
		;;
	c)
		gPingTry=${OPTARG}
		;;
	i)
		gIface=${OPTARG}
		;;
	P)
		gPingOpen=${OPTARG}
		;;
	D)
		gDnsOpen=${OPTARG}
		;;
	r)
		gRconnDefault=1
		gRconn=$gRconnDefault
		;;
	C)
		gCpe=1
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

redail_times=0
max_dail_time=6
min_dail_time=4

init_base_config

check_one_protocal(){
	_nets="$1"
	_ifaces="$2"
	_ifaces_label="$3"
	_nstatus="$4"
	_ostatus="$_nstatus"
	_check_process=1
	local state_name="$(get_wanchk_state_name $_ifaces_label)"
	if ! check_net_using "$_nets" ;then
		if [ "$_nstatus" != "down" ]; then
			log_info "net disable $_nstatus -> down"
			_nstatus="down"
			_ostatus="$_nstatus"
			set_net_status "$_ifaces_label" "down"
		fi
		if [ "$_nstatus" == "up" ];then
			return 0
		else
			return 1
		fi
	fi
	if  echo "$_ifaces_label"|grep -sq "6" && ! check_net6_using "$_nets" ;then
		return 1
	fi

	status=$(cat $WANCHK_STATUS_DIR/iface_state/"${state_name}_lock" 2>/dev/null)
	#log_info "loopCheckMode $loopCheckMode,status $status"
	if [ "$loopCheckMode" = "pause" -o "$status" = "lock" ];then
		set_wanchk_state "$state_name" "block"
		gV4=""
		gV6=""
		_check_process=0
	elif [ "$loopCheckMode" = "recovery" -o "$status" = "unlock" ];then
		loopCheckMode="normal"
		async_sleep "$gWait"
		rm $WANCHK_STATUS_DIR/iface_state/"${state_name}_lock"
		rm $WANCHK_STATUS_DIR/iface_state/"${state_name}"
		if [ "$loopCheckMode" = "pause" ];then
			redail_times=$((redail_times+1))
			log_info "redail_times $redail_times"
			_check_process=0
			if [ $gCpe -eq 1 ] && check_net_using "$_nets";then
				if [ "$gRconn" == "0" ];then
					if [ $redail_times -gt $max_dail_time ];then
						_nstatus="down"
						redail_times=0
						set_net_status "$_ifaces_label" "down"
					fi
				else
					if [ $redail_times -gt $max_dail_time ];then
						redail_times=0
						proto_block_restart "$_nets"
						log_info "block:$_nets"
					elif [ $redail_times -eq $min_dail_time ];then
						log_info "restart model"
						power_ctl "$_nets"
						async_sleep "$IFUP_WAIT_TIME"
						log_info "restart model over"
					fi
				fi
			fi
		else
			if [ $gCpe -eq 1 ] && ! echo "$_ifaces_label"|grep -sq "6" ;then
				dhcp_result=$(get_if_dns "$_ifaces")
				if [ -z "$dhcp_result" ];then
					async_sleep "$gWait"
				fi
			fi
		fi
		gV4=""
		gV6=""
	fi

	if [ "$_check_process" -eq 1 ];then
		redail_times=0
		if check_main "$_nets" "$_ifaces" "$_ifaces_label" "$_ostatus" ;then
			_nstatus="up"
		else
			_nstatus="down"
		fi

		_ostatus="$_nstatus"
		set_wanchk_state "$state_name" "$_nstatus"
	fi

	if [ "$_nstatus" == "up" ];then
		return 0
	else
		return 1
	fi
}

while true; do
	check_vsim
	if check_one_protocal "$gNet" "$gIface" "$gIface" "$gNew" ;then
		gNew="up"
		cpeStatus="up"
	else
		gNew="down"
	fi

	ipv6="$(uci -q get network.globals.ipv6)"
	if [ "$ipv6" == "1" ];then
		if check_one_protocal "$g6Net" "$g6UbusIface" "$g6Iface" "$g6New" ;then
			g6New="up"
			cpeStatus="up"
		else
			g6New="down"
		fi
	else
		if [ "$g6New" != "down" ]; then
			log_info "net disable $g6New -> down"
			set_net_status "$g6Iface" "down"
		fi

		g6New="down"
	fi

	if [ $gCpe -eq 1 ]; then
		if [ "$g6New" == "up" -o "$gNew" == "up" ];then
			cpeStatus="up"
		else
			cpeStatus="down"
		fi
	fi

	async_sleep "$gWait"
done
