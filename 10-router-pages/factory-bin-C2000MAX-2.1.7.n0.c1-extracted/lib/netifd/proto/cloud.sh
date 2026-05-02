#!/bin/sh

[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. ../netifd-proto.sh
	init_proto "$@"
}

proto_cloud_init_config() {
	no_device=1
	available=1
	proto_config_add_string "device:device"
	proto_config_add_string apn
	proto_config_add_string auth
	proto_config_add_string username
	proto_config_add_string password
	proto_config_add_string pincode
	proto_config_add_string delay
	proto_config_add_string mode
	proto_config_add_string pdptype
	proto_config_add_int profile
	proto_config_add_defaults
}

dail_cloud_core(){
	local profile="$1"
	local apn="$2"
	local auth="$3"
	local username="$4"
	local password="$5"
	local pdptype="$6"
	local autoconnect="$7"

	echo "Starting network $interface"

	[ "$pdptype" = "ip" -o "$pdptype" = "ipv6" -o "$pdptype" = "ipv4v6" ] || pdptype="ipv4v6"
	[ -z "$profile" ] && profile="1"
	[ -z "$auth" ] && auth="none"

	setup_apn "$apn" "$profile" "$auth" "$username" "$password" "$pdptype"	
	return 0
}
proto_cloud_setup() {
	local interface="$1"
	local initialize setmode connect finalize devname devpath

	local proto_v4="dhcp"
	local apn auth username password pincode delay mode pdptype profile profile_permanent autoconnect brmode $PROTO_DEFAULT_OPTIONS
	json_get_vars apn auth username password pincode delay mode pdptype profile profile_permanent autoconnect $PROTO_DEFAULT_OPTIONS

	[ "$metric" = "" ] && metric="0"

	[ -n "$profile" ] || profile=1
	[ "$pdptype" = "ip" -o "$pdptype" = "ipv6" -o "$pdptype" = "ipv4v6" ] || pdptype="ipv4v6"

	[ -n "$ifname" ] || {
		echo "The interface could not be found."
		proto_notify_error "$interface" NO_IFACE
		return 1
	}

	echo "Configuring modem"
	[ "$nettype" == "cpe" -a "$vsim_active" == "0" ] || {
		if ! adapt_apn_common "$profile" "$apn" "$auth" "$username" "$password" "$pdptype" "" ;then
			return 
		fi
	}
	echo "Setting up $ifname"
	proto_init_update "$ifname" 1
	proto_add_data
	json_add_string "manufacturer" "$vendor"
	proto_close_data
	proto_send_update "$interface"
	local zone="$(fw3 -q network "$interface" 2>/dev/null)"

	[ "$pdptype" = "ip" -o "$pdptype" = "ipv4v6" ] && {
		json_init
		json_add_string name "${interface}_4"
		json_add_string ifname "@$interface"

		json_add_string proto "dhcp"
		proto_add_dynamic_defaults
		[ -n "$zone" ] && {
			json_add_string zone "$zone"
		}
		json_close_object
		ubus call network add_dynamic "$(json_dump)"
	}

	[ "$pdptype" = "ipv6" -o "$pdptype" = "ipv4v6" ] && {
		json_init
		json_add_string name "${interface}_6"
		json_add_string ifname "@$interface"

		json_add_string proto "dhcpv6"
		json_add_string extendprefix 1
		proto_add_dynamic_defaults
		[ -n "$zone" ] && {
			json_add_string zone "$zone"
		}
		json_close_object
		ubus call network add_dynamic "$(json_dump)"
	}
}

proto_cloud_teardown() {
	local interface="$1"
	return 0
}
[ -n "$INCLUDE_ONLY" ] || {
	add_protocol cloud
}
