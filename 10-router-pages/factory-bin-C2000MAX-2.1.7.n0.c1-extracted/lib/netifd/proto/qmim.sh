#!/bin/sh

[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. ../netifd-proto.sh
	init_proto "$@"
}

proto_qmim_init_config() {
	available=1
	no_device=1
	proto_config_add_string "device:device"
	proto_config_add_string apn
	proto_config_add_string auth
	proto_config_add_string username
	proto_config_add_string password
	proto_config_add_string pincode
	proto_config_add_int delay
	proto_config_add_string modes
	proto_config_add_string pdptype
	proto_config_add_int profile
	proto_config_add_boolean dhcp
	proto_config_add_boolean dhcpv6
	proto_config_add_boolean autoconnect
	proto_config_add_int plmn
	proto_config_add_int timeout
	proto_config_add_int mtu
	proto_config_add_defaults
}

dail_qmi_wwan_m_core(){
	local profile="$1"
	local apn="$2"
	local auth="$3"
	local username="$4"
	local password="$5"
	local pdptype="$6"
	local autoconnect="$7"
	local pdpopt=""
	cid_4=
	pdh_4=
	cid_6=
	pdh_6=
	
	pdptype=$(echo "$pdptype" | awk '{print tolower($0)}')
	[ "$pdptype" = "ip" -o "$pdptype" = "ipv6" -o "$pdptype" = "ipv4v6" ] || pdptype="ipv4v6"

	if [ "$pdptype" = "ipv4v6" ]; then
		pdpopt="-4 -6"
	elif [ "$pdptype" = "ipv6" ]; then
		pdpopt="-6"
	else
		pdpopt="-4"
	fi

	[ -z "$profile" ] && profile="1"
	[ -z "$auth" ] && auth="none"
	[ -z "$ifname" ] && ifname="$(ls /sys/class/net/ | grep -e wwan | tail -n1)"

	[ -n "$apn" ] && netprovopt="-s $apn${username:+ $username}${password:+ $password}${auth:+ $auth}"
	#setup_apn "$apn" "$profile" "" "" "" "$pdptype"
	echo "setup_apn \"$apn\" \"$profile\" \"$auth\" \"$username\" \"$password\" \"$pdptype\""

	rm -rf /tmp/rmnet_*
	meig-cm -n 1 $pdpopt $netprovopt &

	connected="0"
	for i in $(seq 15); do
		echo "waiting for $ifname rmnet config file..."
		[ -f "/tmp/rmnet_${ifname}_ipv4config" ] || [ -f "/tmp/rmnet_${ifname}_ipv6config" ] && {
			connected="1"
			break
		}
		sleep 3
	done

	[ "$connected" = "0" ] && {
		return 1
	}
	echo "Setting up $interface"

	local zone="$(fw3 -q network "$interface" 2>/dev/null)"
	cfgfile="/tmp/rmnet_${ifname}_ipv6config"
	if [ "$pdptype" = "ipv4v6" ] || [ "$pdptype" = "ipv6" ] && [ -f "$cfgfile" ]; then
		local ip_6 subnet_6 gateway_6 dns1_6 dns2_6 ip_prefix_length

		ifname="$(grep IFNAME $cfgfile|cut -d'"' -f2)"
		ip_6="$(grep PUBLIC_IP $cfgfile|cut -d'"' -f2)"
		subnet_6="$(grep NETMASK $cfgfile|cut -d'"' -f2)"
		gateway_6="$(grep GATEWAY $cfgfile|cut -d'"' -f2)"
		dns1_6="$(grep DNSSERVERS $cfgfile|cut -d'"' -f2|cut -d' ' -f1)"
		dns2_6="$(grep DNSSERVERS $cfgfile|cut -d'"' -f2|cut -d' ' -f2)"
		dns2_6="$(grep PrefixLength $cfgfile|cut -d'"' -f2|cut -d' ' -f2)"

		proto_init_update "$ifname" 1
		proto_set_keep 1
		proto_add_ipv6_address "$ip_6" "128"
		proto_add_ipv6_prefix "${ip_6}/${ip_prefix_length}"
		proto_add_ipv6_route "$gateway_6" "128"
		[ "$defaultroute" = 0 ] || proto_add_ipv6_route "::0" 0 "$gateway_6" "" "" "${ip_6}/${ip_prefix_length}"
		[ "$peerdns" = 0 ] || {
			proto_add_dns_server "$dns1_6"
			proto_add_dns_server "$dns2_6"
		}
		[ -n "$zone" ] && {
			proto_add_data
			json_add_string zone "$zone"
			proto_close_data
		}
		proto_send_update "$interface"

		json_init
		json_add_string name "${interface}_6"
		json_add_string ifname "@$interface"
		json_add_string proto "dhcpv6"
		[ -n "$ip6table" ] && json_add_string ip6table "$ip6table"
		proto_add_dynamic_defaults
		[ -n "$zone" ] && json_add_string zone "$zone"
		json_close_object
		ubus call network add_dynamic "$(json_dump)"
	fi

	cfgfile="/tmp/rmnet_${ifname}_ipv4config"
	if [ "$pdptype" = "ipv4v6" ] || [ "$pdptype" = "ip" ] && [ -f "$cfgfile" ]; then
		local ip_4 subnet_4 gateway_4 dns1_4 dns2_4

		ifname="$(grep IFNAME $cfgfile|cut -d'"' -f2)"
		ip_4="$(grep PUBLIC_IP $cfgfile|cut -d'"' -f2)"
		subnet_4="$(grep NETMASK $cfgfile|cut -d'"' -f2)"
		gateway_4="$(grep GATEWAY $cfgfile|cut -d'"' -f2)"
		dns1_4="$(grep DNSSERVERS $cfgfile|cut -d'"' -f2|cut -d' ' -f1)"
		dns2_4="$(grep DNSSERVERS $cfgfile|cut -d'"' -f2|cut -d' ' -f2)"
		proto_init_update "$ifname" 1
		proto_set_keep 1
		proto_add_ipv4_address "$ip_4" "$subnet_4"
		proto_add_ipv4_route "$gateway_4" "128"
		[ "$defaultroute" = 0 ] || proto_add_ipv4_route "0.0.0.0" 0 "$gateway_4"
		[ "$peerdns" = 0 ] || {
			proto_add_dns_server "$dns1_4"
			proto_add_dns_server "$dns2_4"
		}
		[ -n "$zone" ] && {
			proto_add_data
			json_add_string zone "$zone"
			proto_close_data
		}
		json_dump
		proto_send_update "$interface"

		json_init
		json_add_string name "${interface}_4"
		json_add_string ifname "@$interface"
		json_add_string proto "dhcp"
		json_add_string extendprefix 1
		[ -n "$ip4table" ] && json_add_string ip4table "$ip4table"
		proto_add_dynamic_defaults
		[ -n "$zone" ] && json_add_string zone "$zone"
		json_close_object
		json_dump
		ubus call network add_dynamic "$(json_dump)"
	fi
	return 0
}

proto_qmim_setup() {
	local interface="$1"
	local dataformat connstat plmn_mode mcc mnc
	local device apn auth username password pincode delay modes pdptype
	local profile dhcp dhcpv6 autoconnect plmn timeout mtu $PROTO_DEFAULT_OPTIONS
	local ip4table ip6table
	local pdpopt cfgfile netprovopt connected

	json_get_vars device apn auth username password pincode delay modes
	json_get_vars pdptype profile dhcp dhcpv6 autoconnect plmn ip4table
	json_get_vars ip6table timeout mtu $PROTO_DEFAULT_OPTIONS

	echo "Starting network $interface"
	if ! adapt_apn_common "$profile" "$apn" "$auth" "$username" "$password" "$pdptype" "$autoconnect" ;then
		return 
	fi
}

proto_qmim_teardown() {
	echo "Stopping network $interface"
	killall meig-cm
	rm -rf /tmp/rmnet_*

	proto_init_update "*" 0
	proto_send_update "$interface"
}

[ -n "$INCLUDE_ONLY" ] || {
	add_protocol qmim
}
