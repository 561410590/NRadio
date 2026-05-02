#!/bin/ash
. /lib/functions.sh

readonly IPSET_ACCESS_SET="nradio-access-list"
readonly IPSET_ACCESS_SET_MAC="nradio-access-mac-list"
readonly IPSET_ACCESS_SET6="nradio-access-list6"
readonly IPT_FORWARD_CHAIN="nradio_forward_rule"
readonly IPT_FORWARD_MAC_CHAIN="nradio_forward_mac_rule"
readonly IPT_FORWARD_WHITE_CHAIN="nradio_forward_white_rule"
readonly DNSMASQ_IPSET_CONF="/tmp/dnsmasq.d/nradio-access-list.conf"

readonly IPSET_DIVIDING_SET_MAC="nradio-dividing-mac-"
readonly IPSET_DIVIDING_SET="nradio-dividing-"
readonly IPSET_DIVIDING_SET6="nradio-dividing6-"
readonly DNSMASQ_IPSET_DIVIDING_CONF="/tmp/dnsmasq.d/nradio-dividing-list.conf"
readonly IPT_FORWARD_DNS_CHAIN="nradio_forward_dns"

readonly IPSET_CLOUD_ACCESS_SET="cloud-access-list"
readonly IPSET_CLOUD_ACCESS_SET6="cloud-access-list6"
readonly IPSET_HIDE_ACCESS_SET="hide-access-list"
readonly IPSET_HIDE_ACCESS_SET6="hide-access-list6"

gFORWARD_DNS=0
gMac=""
gAction=""
gRefresh=
gResolve=0
gLogMode=$(uci -q get logservice.root.mode)

[ ! -d "/tmp/dnsmasq.d/" ] && mkdir -p /tmp/dnsmasq.d/

usage() {
	cat <<-EOF
		usage: $0 OPTION...
		NRadio network access control

		  -m	  client mac
		  -a	  client network access action
		  -r	  refresh access control, 0: client control, 1: access rule
		  -u	  nslookup domain and update ipset

	EOF
}

while getopts "m:a:r:h:u" opt; do
	case "${opt}" in
		m)
			gMac=${OPTARG}
			;;
		a)
			gAction=${OPTARG}
			;;
		r)
			gRefresh=${OPTARG}
			;;
		u)
			gResolve=1
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

log_info() {
	logger -t "access_ctl" "$*"
	if [ "$gLogMode" == "1" ] ;then
		logclient -i access_ctl  -l 6 -m "$*"
	fi
}

client_action(){
	local mac="$(echo "$1"| tr 'A-Z' 'a-z')"
	local action="$2"
	local timestart="$3"
	local timestop="$4"
	local mac_info="$(iptables -v -n -L internet_access --line-numbers |grep -i "$mac"|awk -F' ' '{print $1}')"
	if [ -n "$mac_info" ];then
		_cnt=$(echo "$mac_info"|wc -l)
		i=0
		while [ $i -lt $_cnt ];do
			i=$((i+1))
			line=$(echo "$mac_info" |sed -n "1p")
			if [ -n "$line" ];then
				iptables -D internet_access $line
			fi
		done		
	fi
	local mac_info6="$(ip6tables -v -n -L internet_access --line-numbers |grep -i "$mac"|awk -F' ' '{print $1}')"
	if [ -n "$mac_info6" ];then		
		_cnt=$(echo "$mac_info6"|wc -l)
		i=0
		while [ $i -lt $_cnt ];do
			i=$((i+1))
			line=$(echo "$mac_info6" |sed -n "1p")
			if [ -n "$line" ];then
				ip6tables -D internet_access $line
			fi
		done
	fi

	if [ "$action" == "0" ];then
		if [ -n "$timestart" -a -n "$timestop" ];then
			iptables -A internet_access -m mac --mac-source "$mac" -m time --timestart $timestart --timestop $timestop --kerneltz -j DROP
			ip6tables -A internet_access -m mac --mac-source "$mac" -m time --timestart $timestart --timestop $timestop --kerneltz -j DROP
		else
			iptables -A internet_access -m mac --mac-source "$mac" -j DROP
			ip6tables -A internet_access -m mac --mac-source "$mac" -j DROP
		fi

		_res="$(ip neighbor|grep $mac| awk -F ' ' '{print $1}')"
		_cnt=$(echo "$_res"|wc -l)
		i=0
		while [ $i -lt $_cnt ];do
			i=$((i+1))
			line=$(echo "$_res" |sed -n "${i}p")
			if [ -n "$line" ];then
				conntrack -D  -s $line
			fi
		done

	fi
}

reset_hard_acceleration(){
	if [ -f "/usr/sbin/atcmd" ]; then
		echo "type=switch switch=off action=set" > /sys/devices/pfa_cmd/pfa_cmd
	elif [ -f "/usr/bin/qlnet" ]; then
		echo 0 > /proc/net/sfp/enable
	else
		mtkhnat -b
	fi

	if [ -f "/usr/sbin/atcmd" ]; then
		echo "type=switch switch=on action=set" > /sys/devices/pfa_cmd/pfa_cmd
	elif [ -f "/usr/bin/qlnet" ]; then
		echo 1 > /proc/net/sfp/enable
	else
		mtkhnat -r
	fi	
}

chain_exsit()
{
	local table_name="$1"
	local chain="$2"
	local v6="$3"
	local cmd="iptables"

	if [ -n "$v6" ];then
		cmd="ip6tables"
	fi
	if [ -z "$chain" -o -z "$table_name" ];then
		return 0
	fi
	local _res="$($cmd -v -n -x -t $table_name -L $chain 2>/dev/null)"
	if [ -z "$_res" ];then
		return 1
	fi
	_cnt=$(echo "$_res"|wc -l)
	i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if echo "$line" |grep  -q "$chain";then
			return 0
		fi
		break
	done
}

execute()
{
	local cmd="$1"
	local max=$2
	local sleeptime="$3"
	local fail=1

	while true
	do
		if $cmd ;then
			return 0
		else
			log_info "execution failed: $cmd,failed times:$fail"
			if [ -z "$max" -o $fail -ge $max ];then 
				return 1
			else
				fail=$((fail + 1))
				if [ -n "$sleeptime" ];then
					sleep $sleeptime
				else
					sleep 0.3
				fi				
			fi
		fi
	done
}

iptables_longdo_command(){
	local cmd="$1"
	execute "$cmd" 4 3
}

checker_client() {
	local mac=
	local switch="1"

	config_get mac "$1" mac
	config_get switch "$1" switch
	config_get timestart "$1" timestart
	config_get timestop "$1" timestop
	
	[ -z "$mac" ] && return

	client_action "$mac" "$switch" "$timestart" "$timestop"
}

init_iptables_chain()
{
	local table="$1"
	local chain="$2"
	local v6="$3"
	local cmd="iptables"

	[ -n "$v6" ] && cmd="ip6tables"
	if chain_exsit "$table" "$chain" "$v6";then
		$cmd -F $chain -t $table
	else
		iptables_longdo_command "$cmd -N $chain -t $table"
	fi
}

init_ipxtables_both_chain()
{
	local table="$1"
	local chain="$2"
	init_iptables_chain "$table" "$chain"
	init_iptables_chain "$table" "$chain" "V6"
}

init_client_list() {
	init_ipxtables_both_chain "filter" "internet_access"
	init_ipxtables_both_chain "filter" "internet_block_access"

	iptables -D FORWARD -j internet_access
	ip6tables -D FORWARD -j internet_access
	iptables -D internet_access -j internet_block_access
	ip6tables -D internet_access -j internet_block_access
	
	iptables_longdo_command "iptables -I FORWARD -j internet_access"
	iptables_longdo_command "ip6tables -I FORWARD -j internet_access"
	iptables_longdo_command "iptables -I internet_access -j internet_block_access"
	iptables_longdo_command "ip6tables -I internet_access -j internet_block_access"
	
	touch "/tmp/internet_block_access"
	config_load "access_ctl"
	config_foreach checker_client client
}

init_forward_dns(){
	local on="$1"
	_lan=$(uci -q get network.globals.default_lan)
	[ -z "$_lan" ] && _lan="lan"
	lanip=$(uci -q get network.$_lan.ipaddr)

	lanip6=$(uci -q get network.globals.ula_prefix |awk -F/ '{print $1}')

	init_ipxtables_both_chain "nat" "$IPT_FORWARD_DNS_CHAIN"
	iptables -D PREROUTING -t nat -j $IPT_FORWARD_DNS_CHAIN
	ip6tables -D PREROUTING -t nat -j $IPT_FORWARD_DNS_CHAIN
	
	iptables_longdo_command "iptables -I PREROUTING -t nat -j $IPT_FORWARD_DNS_CHAIN"
	iptables_longdo_command "ip6tables -I PREROUTING -t nat -j $IPT_FORWARD_DNS_CHAIN"

	if [ "$on" == "1" ];then
		iptables_longdo_command "iptables -t nat -I $IPT_FORWARD_DNS_CHAIN  -p tcp  --dport 53 -j DNAT --to-destination $lanip"
		iptables_longdo_command "iptables -t nat -I $IPT_FORWARD_DNS_CHAIN  -p udp  --dport 53 -j DNAT --to-destination $lanip"
		if [ -n "$lanip6" ];then
			iptables_longdo_command "ip6tables -t nat -I $IPT_FORWARD_DNS_CHAIN  -p tcp  --dport 53 -j DNAT --to-destination ${lanip6}1"
			iptables_longdo_command "ip6tables -t nat -I $IPT_FORWARD_DNS_CHAIN  -p udp  --dport 53 -j DNAT --to-destination ${lanip6}1"
		fi
	fi
}

dividing_client_action(){
	local members="$1"
	local iface="$2"
	[ -z "$members" ] && return

	for member in $members; do
		if echo "$member"|grep -Eq "^([0-9a-fA-F][02468aceACE])(([:]([0-9a-fA-F]{2})){5})$";then
			ipset add ${IPSET_DIVIDING_SET_MAC}${iface} $member
		elif echo "$member"|grep -qE "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"; then
			ipset add ${IPSET_DIVIDING_SET}${iface} $member
		elif echo "$member"|grep -qE "([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4}" ;then
			ipset add ${IPSET_DIVIDING_SET6}${iface} $member
		else
			echo "ipset=/$member/${IPSET_DIVIDING_SET}${iface},${IPSET_DIVIDING_SET6}${iface}" >> $DNSMASQ_IPSET_DIVIDING_CONF
		fi
	done
}

checker_dividing_client() {
	local mac="$1"

	config_get dividing_default "$1" dividing_default

	[ -z "$mac" ] && return

	mac=$(echo "$mac"|sed -e 's/_/:/g')
	dividing_client_action "$mac" "$dividing_default"
}

checker_dividing_protocol() {
	local iface="$1"

	config_get address "$1" address

	[ -z "$iface" ] && return
	dividing_client_action "$address" "$iface"
}


init_dividing_rule(){
	[ -f $DNSMASQ_IPSET_DIVIDING_CONF ] && rm -f $DNSMASQ_IPSET_DIVIDING_CONF

	dividing=$(uci -q get network.globals.dividing)
	dividing_default=$(uci -q get network.globals.dividing_default)

	_cpenu=$(uci -q get oem.feature.cpe)
	_cpenu="${_cpenu:-0}"
	local ifaces="wan"
	for _i in $(seq 1 "${_cpenu:-0}"); do
		iface="cpe$((_i-1))"
		[ "$_i" -eq 1 ] && iface="cpe"
		ifaces="$ifaces $iface"
	done
	for iface in ${ifaces}; do
		if ipset list ${IPSET_DIVIDING_SET_MAC}${iface} > /dev/null 2&>1; then
			ipset flush ${IPSET_DIVIDING_SET_MAC}${iface}
			ipset destroy ${IPSET_DIVIDING_SET_MAC}${iface}		
		fi
		if [ "$dividing" == "client" ];then
			ipset create ${IPSET_DIVIDING_SET_MAC}${iface} hash:mac
		fi

		
		if ipset list ${IPSET_DIVIDING_SET}${iface} > /dev/null 2&>1; then
			ipset flush ${IPSET_DIVIDING_SET}${iface}
			ipset destroy ${IPSET_DIVIDING_SET}${iface}
		fi

		if ipset list ${IPSET_DIVIDING_SET6}${iface} > /dev/null 2&>1; then
			ipset flush ${IPSET_DIVIDING_SET6}${iface}
			ipset destroy ${IPSET_DIVIDING_SET6}${iface}
		fi
		if [ "$dividing" == "protocol" ];then
			ipset create ${IPSET_DIVIDING_SET}${iface} hash:ip
			ipset create ${IPSET_DIVIDING_SET6}${iface} hash:ip family inet6
		fi
	done
	config_load "dividing"
	if [ "$dividing" == "client" ];then
		config_foreach checker_dividing_client client
	fi
	if [ "$dividing" == "protocol" ];then
		config_foreach checker_dividing_protocol protocol
		gFORWARD_DNS=1
	fi
	
	conntrack -F
	/etc/init.d/dnsmasq restart
}

init_access_hide() {
	if ! ipset list $IPSET_HIDE_ACCESS_SET > /dev/null 2&>1; then
		ipset create $IPSET_HIDE_ACCESS_SET hash:ip
	fi
		
	if ! ipset list $IPSET_HIDE_ACCESS_SET6 > /dev/null 2&>1; then
		ipset create $IPSET_HIDE_ACCESS_SET6 hash:ip family inet6
	fi
	
	members=$(uci -q get access_ctl.config.hidelist)
	for member in $members; do
		if echo "$member"|grep -qE "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"; then
			ipset add $IPSET_HIDE_ACCESS_SET $member
		else
			echo "ipset=/$member/$IPSET_HIDE_ACCESS_SET,$IPSET_HIDE_ACCESS_SET6" >> $DNSMASQ_IPSET_CONF
		fi
	done
}

init_access_cloud() {
	if ! ipset list $IPSET_CLOUD_ACCESS_SET > /dev/null 2&>1; then
		ipset create $IPSET_CLOUD_ACCESS_SET hash:ip
	fi
		
	if ! ipset list $IPSET_CLOUD_ACCESS_SET6 > /dev/null 2&>1; then
		ipset create $IPSET_CLOUD_ACCESS_SET6 hash:ip family inet6
	fi
	
	members=$(uci -q get access_ctl.config.cloudlist)
	for member in $members; do
		if echo "$member"|grep -qE "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"; then
			ipset add $IPSET_CLOUD_ACCESS_SET $member
		else
			echo "ipset=/$member/$IPSET_CLOUD_ACCESS_SET,$IPSET_CLOUD_ACCESS_SET6" >> $DNSMASQ_IPSET_CONF
		fi
	done
}

init_access_rule() {
	local disabled=$(uci -q get access_ctl.config.disabled)
	local mode=$(uci -q get access_ctl.config.mode)
	local members=
	local member=

	init_ipxtables_both_chain "filter" "$IPT_FORWARD_CHAIN"
	init_ipxtables_both_chain "filter" "$IPT_FORWARD_MAC_CHAIN"
	init_ipxtables_both_chain "filter" "$IPT_FORWARD_WHITE_CHAIN"

	iptables -D forwarding_rule -j $IPT_FORWARD_CHAIN
	iptables -D forwarding_rule -i br-lan -j $IPT_FORWARD_MAC_CHAIN
	iptables -D forwarding_rule -i br-lan -j $IPT_FORWARD_WHITE_CHAIN	

	ip6tables -D forwarding_rule -j $IPT_FORWARD_CHAIN
	ip6tables -D forwarding_rule -i br-lan -j $IPT_FORWARD_MAC_CHAIN
	ip6tables -D forwarding_rule -i br-lan -j $IPT_FORWARD_WHITE_CHAIN

	if ipset list $IPSET_ACCESS_SET > /dev/null 2&>1; then
		ipset flush $IPSET_ACCESS_SET
		ipset destroy $IPSET_ACCESS_SET
	fi

	if ipset list $IPSET_ACCESS_SET_MAC > /dev/null 2&>1; then
		ipset flush $IPSET_ACCESS_SET_MAC
		ipset destroy $IPSET_ACCESS_SET_MAC
	fi

	if ipset list $IPSET_ACCESS_SET6 > /dev/null 2&>1; then
		ipset flush $IPSET_ACCESS_SET6
		ipset destroy $IPSET_ACCESS_SET6
	fi

	if [ "$disabled" = "1" ]; then
		return
	fi
	
	iptables_longdo_command "iptables -I forwarding_rule -i br-lan -j $IPT_FORWARD_WHITE_CHAIN"
	iptables_longdo_command "ip6tables -I forwarding_rule -i br-lan -j $IPT_FORWARD_WHITE_CHAIN"

	iptables_longdo_command "iptables -I forwarding_rule -j $IPT_FORWARD_CHAIN"
	iptables_longdo_command "ip6tables -I forwarding_rule -j $IPT_FORWARD_CHAIN"

	iptables_longdo_command "iptables -I forwarding_rule -i br-lan -j $IPT_FORWARD_MAC_CHAIN"
	iptables_longdo_command "ip6tables -I forwarding_rule -i br-lan -j $IPT_FORWARD_MAC_CHAIN"


	ipset create $IPSET_ACCESS_SET_MAC hash:mac
	ipset create $IPSET_ACCESS_SET hash:ip
	ipset create $IPSET_ACCESS_SET6 hash:ip family inet6

	if [ "$mode" = "0" ]; then
		# apply blacklist
		members=$(uci -q get access_ctl.blacklist.member)
		iptables_longdo_command "iptables -I $IPT_FORWARD_CHAIN -m set --match-set $IPSET_ACCESS_SET dst -j DROP"
		iptables_longdo_command "iptables -I $IPT_FORWARD_MAC_CHAIN -m set --match-set $IPSET_ACCESS_SET_MAC src -j DROP"
		iptables_longdo_command "ip6tables -I $IPT_FORWARD_MAC_CHAIN -m set --match-set $IPSET_ACCESS_SET_MAC src -j DROP"
		iptables_longdo_command "ip6tables -I $IPT_FORWARD_CHAIN -m set --match-set $IPSET_ACCESS_SET6 dst -j DROP"
	elif [ "$mode" = "1" ]; then
		# apply whitelist
		members=$(uci -q get access_ctl.whitelist.member)
		iptables_longdo_command "iptables -I $IPT_FORWARD_WHITE_CHAIN  -j DROP"
		iptables_longdo_command "ip6tables -I $IPT_FORWARD_WHITE_CHAIN  -j DROP"

		iptables_longdo_command "iptables -I $IPT_FORWARD_CHAIN -m set  --match-set $IPSET_ACCESS_SET dst -j ACCEPT"
		iptables_longdo_command "iptables -I $IPT_FORWARD_MAC_CHAIN -m set  --match-set $IPSET_ACCESS_SET_MAC src -j ACCEPT"
		iptables_longdo_command "ip6tables -I $IPT_FORWARD_MAC_CHAIN -m set  --match-set $IPSET_ACCESS_SET_MAC src -j ACCEPT"
		iptables_longdo_command "ip6tables -I $IPT_FORWARD_CHAIN -m set  --match-set $IPSET_ACCESS_SET6 dst -j ACCEPT"
	fi

	for member in $members; do
		if echo "$member"|grep -Eq "^([0-9a-fA-F][02468aceACE])(([:]([0-9a-fA-F]{2})){5})$";then
			ipset add $IPSET_ACCESS_SET_MAC $member
		elif echo "$member"|grep -qE "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"; then
			ipset add $IPSET_ACCESS_SET $member
		elif echo "$member"|grep -qE "([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4}" ;then
			ipset add $IPSET_ACCESS_SET6 $member
		else
			echo "ipset=/$member/$IPSET_ACCESS_SET,$IPSET_ACCESS_SET6" >> $DNSMASQ_IPSET_CONF
			gFORWARD_DNS=1
		fi
	done

}

init_access_list(){
	init_client_list
	init_access_rule
}

loop_update_domain(){
	local type="$1"
	local domain_file="$DNSMASQ_IPSET_DIVIDING_CONF $DNSMASQ_IPSET_CONF"
	if [ "$type"  ==  "1" ];then
		domain_file="$DNSMASQ_IPSET_CONF"
	elif [ "$type"  ==  "2" ];then
		domain_file="$DNSMASQ_IPSET_DIVIDING_CONF"
	fi
	for file in $domain_file;do
		if [ -f "$file" ];then
			local data_info=$(cat $file)
			_cnt=$(echo "$data_info"|wc -l)
			i=0
			while [ $i -lt $_cnt ];do
				i=$((i+1))
				line=$(echo "$data_info" |sed -n "${i}p")
				if [ -n "$line" ];then
					_info="$(echo "$line"|awk -F/ '{print $2}')"
					nslookup "$_info"  >/dev/null 2>&1
				fi
			done
		fi
	done
}

if [ $gResolve -ne 1 ];then
	rm -f $DNSMASQ_IPSET_CONF
	init_access_cloud
	init_access_hide
fi

if [ -z "$*" ]; then
	init_dividing_rule
	init_access_list
	if [ $gFORWARD_DNS -eq 1 ] ;then
		init_forward_dns "1"
	else
		init_forward_dns "0"
	fi
	conntrack -F
	/etc/init.d/dnsmasq restart
	loop_update_domain
	exit
elif [ -n "$gMac" -a -n "$gAction" ];then
	tmp_timestart=""
	tmp_timestop=""
	config_load "access_ctl"
	checker_client_extra()
	{
		config_get _timestart $1 timestart ""
		config_get _timestop $1 timestop ""
		config_get _mac $1 mac ""
		if [ "$gMac" == "$_mac" ]; then
			tmp_timestart=$_timestart
			tmp_timestop=$_timestop
		fi
	}
	echo "$tmp_timestart $tmp_timestop"
	config_foreach checker_client_extra client
	client_action "$gMac" "$gAction" "$tmp_timestart" "$tmp_timestop"
	if [ ! -f "/tmp/hardware_acceleration" ];then
		reset_hard_acceleration
	fi
else
	if [ "$gRefresh" = "1" ]; then
		init_access_rule
	elif [ "$gRefresh" = "0" ]; then
		init_client_list
	elif [ "$gRefresh" = "2" ]; then
		init_dividing_rule		
	fi
	if [ -n "$gRefresh" ];then
		if [ $gFORWARD_DNS -eq 1 ] ;then
			init_forward_dns "1"
		else
			init_forward_dns "0"
		fi
	fi
	if [ ! -f "/tmp/hardware_acceleration" ];then
		reset_hard_acceleration
	fi
	conntrack -F
	/etc/init.d/dnsmasq restart

	if [ $gResolve -eq 1 -o "$gRefresh" == "1" -o "$gRefresh" == "2" ];then
		loop_update_domain "$gRefresh"
	fi
fi


