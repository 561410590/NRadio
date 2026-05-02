#!/bin/sh

. /lib/functions.sh
. ../netifd-proto.sh
init_proto "$@"

INCLUDE_ONLY=1
WANCHK_STATUS_DIR="/var/run/wanchk"
ctl_device=""
dat_device=""
work_mode=""
cloud=0
driver=""
vendor=""
dver=""
ifname=""
nettype=$(uci -q get "network.$interface.nettype")
cloud_cfg=$(uci -q get "network.$interface.cloud")
vsim_active=""
Gimsi=""
interface_prefix="${interface##*[A-Za-z]}"
if [ "$interface_prefix" == "0" ];then
	interface_prefix=""
fi
proto_mbim_setup() { echo "wwan[$$] mbim proto is missing"; }
proto_qmi_setup() { echo "wwan[$$] qmi proto is missing"; }
proto_qmiq_setup() { echo "wwan[$$] qmiq proto is missing"; }
proto_qmim_setup() { echo "wwan[$$] qmim proto is missing"; }
proto_ncm_setup() { echo "wwan[$$] ncm proto is missing"; }
proto_cloud_setup() { echo "wwan[$$] cloud proto is missing"; }
proto_3g_setup() { echo "wwan[$$] 3g proto is missing"; }
proto_directip_setup() { echo "wwan[$$] directip proto is missing"; }

[ -f ./mbim.sh ] && . ./mbim.sh
[ -f ./odu.sh ] && . ./odu.sh
[ -f ./ncm.sh ] && . ./ncm.sh
[ -f ./qmi.sh ] && . ./qmi.sh
[ -f ./qmiq.sh ] && . ./qmiq.sh
[ -f ./qmim.sh ] && . ./qmim.sh
[ -f ./cloud.sh ] &&  . ./cloud.sh
[ -f ./netmanager.sh ] &&  . ./netmanager.sh
[ -f ./3g.sh ] && { . ./ppp.sh; . ./3g.sh; }
[ -f ./directip.sh ] && . ./directip.sh
[ -f ./adapt_apn.sh ] && . ./adapt_apn.sh

proto_wwan_init_config() {
	available=1
	no_device=1

	proto_config_add_string apn
	proto_config_add_string auth
	proto_config_add_string username
	proto_config_add_string password
	proto_config_add_string pincode
	proto_config_add_string delay
	proto_config_add_string modes
	proto_config_add_boolean defaultroute
	if uci -q get oem.feature.cpeth|grep -qE '^1$'; then
		no_device=0
		proto_config_add_string ifname
	fi
}
get_pin_status(){
	echo $(cpetools.sh -i "$interface" -c cpin)
}

get_sim_iccid(){
	echo $(cpetools.sh -i "$interface" -c iccid)
}

get_sim_imsi(){
	local imsi=""
	local i=0
	local max=4
	while [ -z "$imsi" -a $i -lt $max ];do
		imsi=$(cpetools.sh  -i "$interface" -c cimi)
		if echo "$imsi"|grep -qE "^[0-9A-Za-z]{14,15}$";then
			Gimsi="$imsi"
			break
		fi
		sleep 1
		i=$((i+1))
	done
}

get_cfun(){
	echo $(cpetools.sh -i "$interface" -c get_cfun)
}

set_cfun_o(){
	echo $(cpetools.sh -i "$interface" -c cfun_o)
}

set_pin_status(){
	local cur_sim=$(uci -q get "cpesel.sim${interface_prefix}.cur")
	local iccid=$1

	[ -n "$cur_sim" ] || return 1
	local pin_code=$(uci -q get "cpecfg.$iccid.pin")

	[ -n "$pin_code" ] || return 1

	cpetools.sh -t 0 -i "$interface" -c "AT+CPIN=\"$pin_code\""|while read line
	do
		if echo $line |grep "OK" ;then
			return 0
		elif echo $line |grep "ERROR" ;then
			uci -q set "cpecfg.$iccid=iccid"
			uci -q set "cpecfg.$iccid.dail=protect"
			uci -q commit "cpecfg"
			return 1
		fi
	done
}

proto_wwan_init_pin() {
	local sim_pin_state
	local error_code
	local set_result=1
	local max_try=6
	local no_response_try=0
	local error_response_try=0
	local error_response=0
	local nocard_count=0
	if [ "$cloud" == "1" ];then
		return 0
	fi
	while true
	do
		error_response=0
		sim_pin_state=$(get_pin_status)
		error_code=$(echo "$sim_pin_state" |awk -F ' ' '{print $2}')
		sim_pin_state=$(echo "$sim_pin_state" |awk -F ' ' '{print $1}')
		if [ -z "$sim_pin_state" ];then
			sleep 1
			no_response_try=$((no_response_try+1))
			echo  "no_response_try:$no_response_try"
			if [ $no_response_try -gt $max_try ];then
				logclient -i custom -m "[module] sim recognise no ack"
				return 1
			else
				continue
			fi
		fi

		echo "proto_wwan_init_pin get pin status:$sim_pin_state"

		if [ "$sim_pin_state" -eq "1" ];then
			local iccid=$(get_sim_iccid)

			[ -n "$iccid" ] || return 1
			echo "proto_wwan_init_pin iccid:$iccid"
			if uci -q get "cpecfg.$iccid.dail" | grep -qsx "protect";then
				echo "proto_wwan_init_pin pin:protect"
				return 1
			fi
			logclient -i custom -m "[module] sim recognise pin error"
			set_pin_status $iccid
			set_result=$?
			echo "proto_wwan_init_pin set pin:$set_result"
			if [ "$set_result" -eq "0" ];then
					return 0
			fi
		elif [ "$sim_pin_state" -eq "0" ] ;then
			return 0
		elif [ "$sim_pin_state" -eq "3" ] ;then
			echo "proto_wwan_init_pin error_code:$error_code"			
			if [ "$error_code" = "10" ];then
				nocard_count=$((nocard_count+1))
				cfun_status=$(get_cfun)
				if [ "$cfun_status" == "0" ];then
					set_cfun_o
				fi

				if [ $nocard_count -ge 4 ];then
					return 2
				fi
			fi
			error_response=1
			sleep 2
		else
			error_response=1
			sleep 1
		fi

		if [ $error_response -eq 1 ];then
			error_response_try=$((error_response_try+1))
			echo  "error_response_try:$error_response_try"
			if [ $error_response_try -gt $max_try ];then
				cpetools.sh -i "$interface" -c reset
				return 1
			fi
		fi
	done

	return 1
}

generate_config_data(){
	local cfg="$1"
	local driver="$2"
	local rule="${interface}sim$cfg"

	config_load cpecfg
	config_get apn_cfg "$rule" 'apn_cfg'
	config_get mode "$rule" 'mode'
	config_get roaming "$rule" 'roaming' '0'
	config_get custom_apn "$rule" 'custom_apn' '0'
	config_get username "$rule" 'username' ''
	config_get password "$rule" 'password' ''
	config_get auth "$rule" 'auth' ''
	config_get apn "$rule" 'apn' ''
	config_get profile "$rule" 'profile' ''
	config_get profile_permanent "$rule" 'profile_permanent' '0'
	config_get pdptype "$rule" 'pdptype' 'ipv4v6'

	if [ -n "$apn_cfg" ];then
		config_load apn
		config_get username "$apn_cfg" 'username' ''
		config_get password "$apn_cfg" 'password' ''
		config_get auth "$apn_cfg" 'auth' ''
		config_get apn "$apn_cfg" 'apn' ''
		config_get pdptype "$apn_cfg" 'pdptype' 'ipv4v6'
		config_get custom_apn "$apn_cfg" 'custom_apn' '0'
	fi

	if [ "$driver" = "qmi_wwan" ];then
		case $auth in
		0)		auth="none" ;;
		1)		auth="pap" ;;
		2)		auth="chap" ;;
		3)		auth="both" ;;
		esac
	fi

	json_init
	json_add_string mode "$mode"
	json_add_string roaming "$roaming"

	if [ "$custom_apn" = "1" ];then
		json_add_string username "$username"
		json_add_string password "$password"
		json_add_string auth "$auth"
		json_add_string apn "$apn"
		json_add_string profile "$profile"		
		json_add_string profile_permanent "$profile_permanent"
	fi
	json_add_string pdptype "$pdptype"
	json_add_string defaultroute "$defaultroute"
	
	echo "$(json_dump)"
}

send_sig_wanchk(){
	local iface_name=$1
	local sig_type=$2
	local sig_name="SIGUSR2"
	local _status="lock"
	if uci get wanchk.${iface_name}_4 ;then
		wanchk_cpe_pid=$(ps -w|grep wanchk|grep ${iface_name}_4|awk -F ' ' '{print $1}')
	else
		wanchk_cpe_pid=$(ps -w|grep wanchk|grep ${iface_name}|awk -F ' ' '{print $1}')
	fi

	if [ "$sig_type" = "recovery" ];then
		_status="unlock"
	fi
	[ -d $WANCHK_STATUS_DIR ] || mkdir -p $WANCHK_STATUS_DIR/iface_state
	status=$(cat $WANCHK_STATUS_DIR/iface_state/"${iface_name}_lock" 2>/dev/null)
	[ "$status" == "$_status" ] && return
	echo -n "$_status" > $WANCHK_STATUS_DIR/iface_state/${iface_name}_lock
	if [ -n "$wanchk_cpe_pid" ];then
		for pid in $wanchk_cpe_pid
		do
			if [ "$sig_type" = "recovery" ];then
				sig_name="SIGUSR1"
			fi
			echo "delay wanchk kill -$sig_name $pid"
			kill -$sig_name $pid
		done
	fi
}

tag_wanchk_ignore_power(){
	local iface_name=$1
	[ -d $WANCHK_STATUS_DIR ] || mkdir -p $WANCHK_STATUS_DIR/iface_state
	echo -n "1" > $WANCHK_STATUS_DIR/iface_state/${iface_name}_power
	echo "tag wanchk ignore power control"
}

setup_apn(){
	local apn=$1
	local profile=$2
	local auth=$3
	local username=$4
	local password=$5
	local pdptype=$6
	
	[ -z "$profile" ] && return
	[ -z "$pdptype" ] && return
	case $auth in
	"none")		auth="0" ;;
	"pap")		auth="1" ;;
	"chap")		auth="2" ;;
	"both")		auth="3" ;;
	esac
	echo "setup_apn $profile,$pdptype,$apn,$auth,$username,$password"
	cpetools.sh -i "$interface" -c "pdp" "\"\"" "${profile}" "${pdptype}" "${apn:-\"\"}" "${auth:-\"\"}" "${username:-\"\"}" "${password:-\"\"}"
	proto_wwan_init_pin
}

dail_adapt_driver(){
	local profile="$1"
	local apn="$2"
	local auth="$3"
	local username="$4"
	local password="$5"
	local pdptype="$6"
	local autoconnect="$7"
	local driver_alias="$driver"
	case $driver in
	rndis*|cdc_ether|*cdc_ncm)	driver_alias="ncm";;
	esac

	_dail_fun="dail_${driver_alias}_core"
	if type "$_dail_fun" | grep -qs function; then
		if ! $_dail_fun "$profile" "$apn" "$auth" "$username" "$password" "$pdptype" "$autoconnect";then
			return 1
		fi
	else		
		return 1
	fi
	return 0
}

adapt_apn_common(){
	local profile="$1"
	local apn="$2"
	local auth="$3"
	local username="$4"
	local password="$5"
	local pdptype="$6"
	local autoconnect="$7"
	local default_dail=1


	if [ -z "$apn" ];then
		echo "defalut apn is empty,try adapt"
		apn_data=$(init_apn_data "$Gimsi")
		
		if [  -n "$apn_data" ];then
			default_dail=0
			if ! parse_adapt_apn_common "$apn_data" "$autoconnect";then
				return 1
			fi
		fi
	fi

	if [ "$default_dail" = "1" ];then
		if [ "$profile_permanent" = "0" ] && [ ! -f "/tmp/show_profile" ];then
			check_verison_sim "$Gimsi"
			verison_match_result=$?

			if [ $verison_match_result -eq 1 ];then
				profile="3"
				echo "adapt version,use ID $profile"
			else
				echo "use default ID"
			fi
		fi
		echo "use ID $profile"
		local profileid_old=""
		[ -f "/tmp/profileid_${interface}" ] && profileid_old=$(cat /tmp/profileid_${interface})
		[ -z "$profileid_old" ] && profileid_old="1"
		[ -z "$profile" ] && profile="1"
		echo -n "$profile" > /tmp/profileid_${interface}
		if [ "$profile" != "$profileid_old" ];then
			echo "profileid change from $profileid_old to $profile,preinit again"
			cpetools.sh -i "$interface" -c preinit
			return 1
		fi
		if ! dail_adapt_driver "$profile" "$apn" "$auth" "$username" "$password" "$pdptype" "$autoconnect" ;then
			return 1
		fi
	fi
	return 0
}

parse_adapt_apn_common(){
	local self_data=$1
	local self_autoconnect=$2
	local driver=$(uci_get_state network $interface driver)
	if [ -z "$self_data" ];then
		return 1
	fi
	json_set_namespace apn sim_config
	json_init
	json_load "$self_data"
	json_get_var company_item company
	if json_is_a apn array ;then
		json_select apn
		apnindex=1
		dail_result=1
		special_profile=0
		if json_is_a ${apnindex} string ;then
			while json_is_a ${apnindex} string
			do
				json_get_var apn_item ${apnindex}
				apnindex=$(( apnindex + 1 ))
				echo "X1 get adapt apn data:apn:[$apn_item]"
				if dail_adapt_driver "" "$apn_item";then
					return 0
				fi
			done

			dail_adapt_driver 
			dail_result=$?

			return $dail_result
		elif json_is_a ${apnindex} object ;then
			while json_is_a ${apnindex} object
			do
				json_select ${apnindex}
				json_get_var username username
				json_get_var password password
				json_get_var auth auth
				json_get_var pdptype pdptype
				json_get_var profile profile
				json_get_var apn name
				json_select ..
				apnindex=$(( apnindex + 1 ))
				echo "X2 get adapt apn data:username:[$username] password:[$password] auth:[$auth] apn:[$apn] profile:[$profile] pdptype:[$pdptype]"

				if [ -n "$profile" -a "$profile" != "1" ];then
					special_profile=1
				fi

				local profileid_old=""
				[ -f "/tmp/profileid_${interface}" ] && profileid_old=$(cat /tmp/profileid_${interface})
				[ -z "$profileid_old" ] && profileid_old="1"
				[ -z "$profile" ] && profile="1"

				echo -n "$profile" > /tmp/profileid_${interface}
				if [ "$profile" != "$profileid_old" ];then
					echo "profileid2 change from $profileid_old to $profile,preinit again"
					cpetools.sh -i "$interface" -c preinit
					return 1
				fi
				if dail_adapt_driver "$profile" "$apn" "$auth" "$username" "$password" "$pdptype" "$self_autoconnect";then
					return 0
				fi
			done
			if [ $special_profile -eq 0 ];then
				dail_adapt_driver
				dail_result=$?
			fi
			return $dail_result
		fi
		json_select ..
	fi
}


proto_wwan_setup() {
	local pin_check
	json_get_vars defaultroute
	version=$(uci -q get cellular_init.$interface.version)
	work_mode=$(uci -q get "network.$interface.mode")
	odu_model=$(uci -q get "network.$interface.odu_model")

	local part_cloud=0
	dsa=$(uci -q get network.nrswitch.dsa)
	if [ "$dsa" == "1" ];then
		. /lib/network/switch.sh
		_port=$(get_ports "E")
		if [ -n "$_port" ]; then			
			ifname=$(uci -q get network.$interface.ifname)
			if echo "$ifname" |grep -q "port" ;then
				echo "_port:$_port,$_net ifconfig $ifname up"
				ifconfig $ifname up
			fi
			ifname=""
		fi
	fi

	_info=$(ubus call infocd get "{\"name\":\"${interface}_dev\"}"|jsonfilter -e '@.*[@.name="'${interface}'_dev"]["parameter"]')

	[ -n "$_info" ] || {
		echo "$_net usb not ready"
		proto_notify_error "$interface" NO_DEVICE
		sleep 5
		return 1
	}

	[ ! -f "/var/run/cellular_init/$interface/ready" ] && {
		echo "$_net cellular not ready"
		proto_notify_error "$interface" NOT_READY
		sleep 5
		return 1
	}
	cur_sim=$(uci -q get "cpesel.sim${interface_prefix}.cur")
	ctl_device=$(echo "$_info"|jsonfilter -e '$["control"]')
	driver=$(echo "$_info"|jsonfilter -e '$["driver"]')
	[ -z "$ifname" ] && ifname=$(echo "$_info"|jsonfilter -e '$["ifname"]')
	vendor=$(echo "$_info"|jsonfilter -e '$["vendor"]')
	cloud=$(echo "$_info"|jsonfilter -e '$["cloud"]')
	dver=$(echo "$_info"|jsonfilter -e '$["dver"]')
	alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	[ -f "/etc/vsim" ]  && vsim_active=$(cat "/etc/vsim")
	if [ "$odu_model" == "NRFAMILY" ];then
		cloud_cfg="1"
	fi
	if [ "$cloud_cfg" == "1" ];then
		if [ "$nettype" == "cpe" ];then			
			if [ "$vsim_active" == "0" ];then
				cloud="1"
				driver="cloud"
				echo "$interface force vsim dail"
			fi
		else
			cloud="1"
			driver="cloud"
		fi
	fi
	
	if echo "$version" |grep -sq "RW";then
		cloud="1"
		driver="cloud"
		part_cloud=1
	fi

	if [ "$cloud" == "1" ];then
		tag_wanchk_ignore_power "$interface"
	fi

	if [ "$driver" == "cloud" ];then
		uci_revert_state network $interface vendor
		uci_revert_state network $interface driver
		uci_set_state network $interface vendor "$vendor"
		uci_set_state network $interface driver "$driver"
		uci_set_state network $interface ctl_device "$ctl_device"
		uci_set_state network $interface dat_device "$dat_device"
		send_sig_wanchk "$interface" "pause"

			
		data_json=$(generate_config_data "$cur_sim" "$driver" "$defaultroute")

		[ "$nettype" == "cpe" -a "$vsim_active" == "0" ] || {
			if [ -n "$data_json" ];then
				json_set_namespace wwan sim_config
				json_load "$data_json"
				json_select
				json_get_vars mode roaming username password auth apn profile pdptype profile_permanent

				echo "sim setting data:mode:[$mode] roaming:[$roaming] username:[$username] password:[$password] auth:[$auth] apn:[$apn] profile:[$profile] pdptype:[$pdptype] profile_permanent [$profile_permanent]"
			fi

			if [ $part_cloud -eq 0 ];then
				cpetools.sh -i "$interface" -c preinit
			fi
		}

		proto_cloud_setup $@
		send_sig_wanchk "$interface" "recovery"

		if [ -n "$data_json" ];then
			json_set_namespace $sim_config
		fi
		return 0
	fi

	if [ -n "$work_mode" ];then
		if [ -n "$alias" ];then
			vendor="${vendor}_${alias}_${work_mode}"
		else
			vendor="${vendor}_${work_mode}"
		fi
	elif [ -n "$alias" ];then
		if [ "$alias" == "mt5700" -a -z "$dver" ];then
			vendor="${vendor}_${alias}_nophy"
		else
			vendor="${vendor}_${alias}"
		fi
	else
		if [ -n "$dver" ];then
			vendor="${vendor}_${dver}"
		fi
	fi

	dat_device=$(echo "$_info"|jsonfilter -e '$["data"]')
	echo "$ctl_device $driver $dat_device $vendor"

	if [ "$driver" != "odu" ];then
		[ -n "$ctl_device" ] && [ -n "$driver" ] || {
			echo "wwan[$$]" "No valid device was found"
			proto_notify_error "$interface" NO_DEVICE
			sleep 5
			return 1
		}
	fi
	uci_revert_state network $interface vendor
	uci_revert_state network $interface driver
	uci_set_state network $interface vendor "$vendor"
	uci_set_state network $interface driver "$driver"
	uci_set_state network $interface ctl_device "$ctl_device"
	uci_set_state network $interface dat_device "$dat_device"

	local back_mode=$(uci -q get "cpesel.sim${interface_prefix}.back_mode")
	while true
	do
		back_mode=$(uci -q get "cpesel.sim${interface_prefix}.back_mode")
		if [ -z "$back_mode" ] ;then
				break
		fi
		sleep 2
	done
	cpetools.sh -i "$interface" -c prepare
	send_sig_wanchk "$interface" "pause"
	cur_sim=$(uci -q get "cpesel.sim${interface_prefix}.cur")

	local simStype=$(uci -q get "cpesel.sim${interface_prefix}.stype")
	local _stype="0"

	if [ -n "$simStype" ];then
		_stype=$(echo "$simStype"|cut -d, -f "$cur_sim")
	fi
	proto_wwan_init_pin
	pin_check=$?
	echo "pin_check :$pin_check"


	if [ "$pin_check" -eq "0" ];then
		local iccid=$(get_sim_iccid)
		
		if echo "$iccid"|grep -qE "^[0-9A-Za-z]{19,22}$"; then
			echo "iccid:$iccid"
			ubus call combo simslot "{'name':'$interface','iccid':'$iccid'}"
			ubus call cpesel${interface_prefix} set "{'simno':'sim"$cur_sim"', 'iccid':'$iccid'}" > /dev/null
		fi
		get_sim_imsi
		echo  "imsi:$Gimsi"
	fi	
	
	if [ "$pin_check" -eq "1" ];then
		echo "wwan[$$]" "nradio setup failed"
		proto_notify_error "$interface" NRADIO_SETUP
		send_sig_wanchk "$interface" "recovery"		
		sleep 2
		return 1
	elif [ "$pin_check" -eq "2" ];then
		send_sig_wanchk "$interface" "recovery"
		if [ "$cloud" == "1" ];then
			echo "wwan[$$]" "nradio setup failed,no card"
			proto_notify_error "$interface" NRADIO_SETUP
			sleep 2
			return 1
		else
			if [ "$cloud_cfg" != "1" ];then
				ubus call cpesel${interface_prefix} set "{'simno':'sim"$cur_sim"', 'iccid':'none'}" > /dev/null
				if [ "$_stype" == "4" ];then
					echo "wwan[$$]" "nradio setup failed,Embedded sim no card,reset modem"
					cpetools.sh -i "${interface}" -r
				fi
				return 1
			else
				echo "Setting up $ifname"
				proto_init_update "$ifname" 1
				proto_add_data
				json_add_string "manufacturer" "$vendor"
				proto_close_data
				proto_send_update "$interface"
				local zone="$(fw3 -q network "$interface" 2>/dev/null)"
				return 0
			fi
		fi
	fi
	
	
	data_json=$(generate_config_data "$cur_sim" "$driver")

	if [ -n "$data_json" ];then
		json_set_namespace wwan sim_config
		json_load "$data_json"
		json_select
		json_get_vars mode roaming username password auth apn profile pdptype profile_permanent

		echo "sim setting data:mode:[$mode] roaming:[$roaming] username:[$username] password:[$password] auth:[$auth] apn:[$apn] profile:[$profile] pdptype:[$pdptype] profile_permanent [$profile_permanent]"
	fi
	
	if command -v cpetools.sh >/dev/null; then
		cpetools.sh -i "$interface" -c preinit || {
			echo "wwan[$$]" "nradio preinit failed"
			proto_notify_error "$interface" NRADIO_PREINIT
			send_sig_wanchk "$interface" "recovery"
			return 1
		}

		cpetools.sh -i "$interface" -u -m "$mode" || {
			echo "wwan[$$]" "nradio setup failed"
			proto_notify_error "$interface" NRADIO_SETUP
			send_sig_wanchk "$interface" "recovery"
			return 1
		}
	fi
	proto_wwan_init_pin
	setup_result=0
	case $driver in
	odu)			proto_odu_setup $@ ;;
	qmi_wwan)		proto_qmi_setup $@ ;;
	qmi_wwan_q)		proto_qmiq_setup $@ ;;
	qmi_wwan_m)		proto_qmim_setup $@ ;;
	cdc_mbim)		proto_mbim_setup $@ ;;
	sierra_net)		proto_directip_setup $@ ;;
	comgt)			proto_3g_setup $@ ;;
	netmanager)		proto_netmanager_setup $@ ;;
	rndis*|cdc_ether|*cdc_ncm)	proto_ncm_setup $@ ;;
	esac
	setup_result=$?
	send_sig_wanchk "$interface" "recovery"
	cpetools.sh -i "$interface" -c imsreport
	if [ -n "$data_json" ];then
		json_set_namespace $sim_config
	fi

	if [ "$driver" == "netmanager" ];then
		if [ "$setup_result" == "0" ];then
			netmanager_ifconfig "$interface"
		fi
	fi
}

netmanager_ifconfig(){
	INDEX=$(get_index_from_ifname "$ifname")
	support_v6="$(uci get network.globals.ipv6)"
	fail=10
	try_times=0
	while true;do
		connstat=$(cpetools.sh -i "$1" -c connstat)
		ipaddr=$(echo "$connstat"|jsonfilter -e '$["ipaddr"]')
		#gateway=$(echo "$connstat"|jsonfilter -e '$["gateway"]')

		dnsv4_primary=$(echo "$connstat"|jsonfilter -e '$["dns1"]')
		dnsv4_secondary=$(echo "$connstat"|jsonfilter -e '$["dns2"]')

		ip6addr=$(echo "$connstat"|jsonfilter -e '$["ip6addr"]')
		dnsv6_primary=$(echo "$connstat"|jsonfilter -e '$["dns61"]')
		dnsv6_secondary=$(echo "$connstat"|jsonfilter -e '$["dns62"]')
		if echo "$ip6addr"|grep -E "^fe80" ;then
			ip6addr=""
		fi
		if [ -z "$ipaddr" ];then
			try_times=$((try_times+1))
			if [ $try_times -gt $fail ];then
				proto_notify_error "$interface" DHCP_FAILED
				return 1
			fi
			sleep 1
		elif [ -z "$ip6addr" -a "$support_v6" == "1" ];then
			try_times=$((try_times+1))
			if [ $try_times -gt $fail ];then
				echo "get ipv6 error,$ifname"
				break
			fi
			sleep 1
		else
			break
		fi
	done

	echo "Setting up $ifname"
	proto_init_update "$ifname" 1

	[ -n "$dnsv4_primary" ] && proto_add_dns_server $dnsv4_primary
	[ -n "$dnsv4_secondary" ] && proto_add_dns_server $dnsv4_secondary
	[ -n "$dnsv6_primary" ] && proto_add_dns_server $dnsv6_primary
	[ -n "$dnsv6_secondary" ] && proto_add_dns_server $dnsv6_secondary
	[ -z "$gateway" ] && gateway="0.0.0.0"
	if [ -n "$ip6addr" ]; then
		proto_add_ipv6_address "$ip6addr" 128
		proto_add_ipv6_route "::" 0 "::" "0"
		proto_add_ipv6_prefix $(extract_ipv6_prefix_64 $ip6addr)::/64
	fi
	if [ -n "$ipaddr" ];then
		proto_add_ipv4_address "$ipaddr" "32"
		proto_add_ipv4_route "$ipaddr" 32 "" "$ipaddr"
		proto_add_ipv4_route "0.0.0.0" 0 "$gateway"

		#uci set firewall.router$INDEX='redirect'
		#uci set firewall.router$INDEX.name='ROUTER support lan network'
		#uci set firewall.router$INDEX.dest="wan"
		#uci set firewall.router$INDEX.src_ip="$(get_subnet $local_addr $local_netmask)$(IPprefix_by_netmask $local_netmask)"
		#uci set firewall.router$INDEX.src_dip="$ipaddr"
		#uci set firewall.router$INDEX.target='SNAT'
		#uci set firewall.router$INDEX.proto='all'
		#uci commit firewall
		#/etc/init.d/firewall reload
	fi
	proto_add_data
	json_add_string "manufacturer" "$vendor"
	proto_close_data
	proto_send_update "$interface"
}
proto_wwan_teardown() {
	local interface=$1
	local driver=$(uci_get_state network $interface driver)
	ctl_device=$(uci_get_state network $interface ctl_device)
	dat_device=$(uci_get_state network $interface dat_device)
	vendor=$(uci_get_state network $interface vendor)
	send_sig_wanchk "$interface" "recovery"
	version=$(uci -q get cellular_init.$interface.version)
	if echo "$version" |grep -sq "RW";then
		driver="cloud"
	fi
	if [ "$cloud_cfg" == "1" ];then
		if [ "$nettype" == "cpe" ];then
			return
		fi
	fi
	case $driver in
	odu)			proto_odu_teardown $@ ;;
	qmi_wwan)		proto_qmi_teardown $@ ;;
	qmi_wwan_q)		proto_qmiq_teardown $@ ;;
	qmi_wwan_m)		proto_qmim_teardown $@ ;;
	cdc_mbim)		proto_mbim_teardown $@ ;;
	sierra_net)		proto_directip_teardown $@ ;;
	comgt)			proto_3g_teardown $@ ;;
	cloud)			proto_cloud_teardown $@ ;;
	netmanager)		proto_netmanager_teardown $@ ;;
	rndis*|cdc_ether|*cdc_ncm)	proto_ncm_teardown $@ ;;
	esac
}

add_protocol wwan
