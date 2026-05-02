#!/bin/sh

[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. ../netifd-proto.sh
	init_proto "$@"
}

proto_odu_init_config() {
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

dail_odu_core(){
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


	echo "Checking register status"
	local reg_max=3
	local reg_error=0
	while true;do
		local _regstat=$(ubus call infocd cpeinfo "{'name':'$interface'}")
		echo "_regstat:$_regstat"
		STAT=$(echo "$_regstat"|jsonfilter -e '$["STAT"]')
		SIM=$(echo "$_regstat"|jsonfilter -e '$["SIM"]')
		MODE=$(echo "$_regstat"|jsonfilter -e '$["MODE"]')
	
		if [ "$STAT" = "register" ]; then
			echo "register ok"
			break
		else
			
			reg_error=$((reg_error+1))
			echo "Failed to register($reg_error)"
			if [ $reg_error -ge $reg_max ];then
				return 1
			fi				
			$(proto_notify_error "$interface" CONNECT_FAILED)
			sleep 5
		fi			
	done
	
	local _automatic=$(uci -q get cpecfg.config.automatic)
	[ -z "$_automatic" ] && _automatic="1"
	local automatic_support=$(uci -q get "network.$interface.automatic")

	if [ "$_automatic" != "1" -o "$automatic_support" != "1" ];then
		echo "Connecting modem"
		eval cpetools.sh -t 1 -i "$interface" -c "$autoconnect" || {
			echo "Failed to connect"
			$(proto_notify_error "$interface" CONNECT_FAILED)
			return 1
		}
	fi
	return 0
}
proto_odu_setup() {
	local interface="$1"
	local pdptype_alia
	local initialize setmode connect finalize devname devpath

	local _mode=$(uci -q get network.${interface}.mode)
	local apn auth username password pincode delay mode pdptype profile profile_permanent autoconnect  brmode $PROTO_DEFAULT_OPTIONS
	json_get_vars apn auth username password pincode delay mode pdptype profile profile_permanent autoconnect $PROTO_DEFAULT_OPTIONS

	brmode=$(uci -q get cpebr.config.enable)
	[ -n "$brmode" ] || brmode=0

	[ "$metric" = "" ] && metric="0"

	[ -n "$profile" ] || profile=1

	[ "$pdptype" = "ip" -o "$pdptype" = "ipv6" -o "$pdptype" = "ipv4v6" ] || pdptype="ipv4v6"

	[ -n "$ifname" ] || {
		echo "The interface could not be found."
		proto_notify_error "$interface" NO_IFACE
		return 1
	}

	json_load "$(cat /etc/gcom/ncm.json)"
	json_select "$vendor"
	[ $? -ne 0 ] && {
		echo "Unsupported modem"
		proto_notify_error "$interface" UNSUPPORTED_MODEM
		return 1
	}

	json_get_values initialize initialize
	for i in $initialize; do
		if echo "$i" |grep -qs "ethernet" ;then
			cf_ifname=$(uci -q get network.$interface.ifname)
			if [ -z "$cf_ifname" ];then
				i=$(echo "$i"|sed "s/,1/,0/g")
			fi
		fi

		eval cpetools.sh -t 1 -i "$interface" -c "$i" || {
			echo "Failed to initialize modem"
			proto_notify_error "$interface" INITIALIZE_FAILED
			return 1
		}
	done

	json_get_values configure configure
	json_get_vars connect finalize
	echo "Configuring modem"
	for i in $configure; do
		eval cpetools.sh -t 1 -i "$interface"  -c "$i" || {
			echo "Failed to configure modem"
			proto_notify_error "$interface" CONFIGURE_FAILED
			return 1
		}
	done

	if ! adapt_apn_common "$profile" "$apn" "$auth" "$username" "$password" "$pdptype" "$connect" ;then
		return 
	fi


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

		if [ "$brmode" = "0" ]; then
			json_add_string proto "dhcp"
		else
			json_add_string proto "none"
		fi

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

		if [ "$brmode" = "0" ]; then
			json_add_string proto "dhcpv6"
		else
			json_add_string proto "none"
		fi

		json_add_string extendprefix 1
		proto_add_dynamic_defaults
		[ -n "$zone" ] && {
			json_add_string zone "$zone"
		}
		json_close_object
		ubus call network add_dynamic "$(json_dump)"
	}

	[ -n "$finalize" ] && {		
		eval cpetools.sh -t 1 -i "$interface" -c "$finalize" || {
			echo "Failed to configure modem"
			proto_notify_error "$interface" FINALIZE_FAILED
			return 1
		}
	}
}

proto_odu_teardown() {
	local interface="$1"
	local _automatic=$(uci -q get cpecfg.config.automatic)
	local automatic_support=$(uci -q get "network.$interface.automatic")
	local work_mode=$(uci -q get "network.$interface.mode")
	
	local disconnect
	local profileid=""
	local profile
	[ -f "/tmp/profileid_${interface}" ] && profileid=$(cat /tmp/profileid_${interface})
	json_get_vars profile
	[ -n "$profileid" ] && profile="$profileid"
	[ -n "$profile" ] || profile=1
	[ -z "$_automatic" ] && _automatic="1"
	echo "Stopping network $interface"

	json_load "$(cat /etc/gcom/ncm.json)"
	json_select "$vendor" || {
		echo "Unsupported modem"
		proto_notify_error "$interface" UNSUPPORTED_MODEM
		return 1
	}

	if [ "$_automatic" != "1" -o "$automatic_support" != "1" ];then
		json_get_vars disconnect	
		[ -n "$disconnect" ] && {
			eval cpetools.sh -t 1 -i "$interface" -c "$disconnect" || {
				echo "Failed to disconnect"
				proto_notify_error "$interface" DISCONNECT_FAILED
				return 1
			}
		}
	fi

	proto_init_update "*" 0
	proto_send_update "$interface"
}
[ -n "$INCLUDE_ONLY" ] || {
	add_protocol odu
}
