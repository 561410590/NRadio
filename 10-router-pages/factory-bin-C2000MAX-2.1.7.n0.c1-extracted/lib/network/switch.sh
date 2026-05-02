#!/bin/ash
# Copyright (C) 2009 OpenWrt.org

. /lib/functions/system.sh

readonly SWITCH_LAN_PORT_TYPES="MLSN"
readonly SWITCH_VALID_LAN_PORT_TYPES="MLS"
readonly SWITCH_WAN_PORT_TYPES="W"
readonly SWITCH_MSW_PORT_TYPES="E"
readonly SWITCH_CPU_PORT_TYPES="C"
readonly SWITCH_HNAT_PORT_TYPES="H"
readonly GMAC1_PHY_PORT=7
readonly GMAC2_PHY_PORT=8
gWANCount=0

_cpecnt=$(uci -q get oem.feature.cpe)
_cpecnt=${_cpecnt:-0}

setup_macs() {
	local _lan_mac=""
	local _wan_mac=""
	local _cpe_mac=""
	local _port=""
	local _ports=""
	local _ifname=""
	local index=1

	local _port_prefix=
	local _no_switch=$(uci -q get "network.nrswitch.no_switch")

	if [ "${_no_switch}" = "1" ]; then
		_port_prefix="eth"
	else
		_port_prefix="port"
	fi

	_ports=$(get_ports "${SWITCH_VALID_LAN_PORT_TYPES}${SWITCH_MSW_PORT_TYPES}${SWITCH_WAN_PORT_TYPES}${SWITCH_HNAT_PORT_TYPES}")
	for _port in $_ports; do
		if [ "$_port" = "$GMAC1_PHY_PORT" ]; then
			_ifname="eth1"
		elif [ "$_port" = "$GMAC2_PHY_PORT" ]; then
			_ifname="eth2"
		else
			_ifname="${_port_prefix}$_port"
		fi
		if ! uci -q get "network.$_ifname"; then
			uci -q set "network.$_ifname=device"
			uci -q set "network.$_ifname.name=$_ifname"
		fi
	done

	_lan_mac=$(uci -q get oem.board.id|tr A-F a-f)


	_ports=$(get_ports "${SWITCH_VALID_LAN_PORT_TYPES}${SWITCH_HNAT_PORT_TYPES}")
	for _port in $_ports; do
		if [ "$_port" = "$GMAC1_PHY_PORT" ]; then
			_ifname="eth1"
		elif [ "$_port" = "$GMAC2_PHY_PORT" ]; then
			_ifname="eth2"
		else
			_ifname="${_port_prefix}$_port"
		fi
		uci -q set "network.${_ifname}.macaddr=$_lan_mac"
	done

	_port=$(get_ports "$SWITCH_MSW_PORT_TYPES")
	if [ -n "$_port" ];then
		_cpe_mac=$(macaddr_add $_lan_mac $index)
		if [ "$_port" = "$GMAC1_PHY_PORT" ]; then
			_ifname="eth1"
		elif [ "$_port" = "$GMAC2_PHY_PORT" ]; then
			_ifname="eth2"
		else
			_ifname="${_port_prefix}$_port"
		fi
		uci -q set "network.${_ifname}.macaddr=$_cpe_mac"
		index=$((index+1))
	fi

	_ports=$(get_ports "$SWITCH_WAN_PORT_TYPES")
	for _port in $_ports; do
		_wan_mac=$(macaddr_add $_lan_mac $index)
		index=$((index+1))
		if [ "$_port" = "$GMAC1_PHY_PORT" ]; then
			_ifname="eth1"
		elif [ "$_port" = "$GMAC2_PHY_PORT" ]; then
			_ifname="eth2"
		else
			_ifname="${_port_prefix}$_port"
		fi
		uci -q set "network.${_ifname}.macaddr=$_wan_mac"
		uci -q set "network.${_ifname}.ipv6=1"
		ifconfig port$_port hw ether $_wan_mac
	done
}

set_switch_lan() {
	local _name="@switch_vlan[0]"
	local _lan_ports=
	local _cpu_ports=
	local _type=
	local _switch=

	_switch=$(uci -q get network."$_name".device)
	_type=$(get_switch_type "$_switch")

	if has_extsw && [ "$_type" = "intsw" ]; then
		# hard code temporary
		_cpu_ports="5t 6t"
	else
		_lan_ports=$(get_ports "$SWITCH_LAN_PORT_TYPES")
		_cpu_ports=$(get_ports "$SWITCH_CPU_PORT_TYPES" | sed -E 's/[0-9]+/&t/g')
	fi

	uci -q set "network.$_name.ports=$_lan_ports $_cpu_ports"
	uci -q set "network.$_name.vlan=1"
}

set_switch_lan_dsa() {
	local _name="@device[0]"
	local _lan_ports=
	local _port=
	local _ports=""
	local _first=1
	local _port_prefix=
	local _no_switch=$(uci -q get "network.nrswitch.no_switch")
	local _ifname=

	_cur_ports=$(uci -q get "network.$_name.ports")
	_lan_ports=$(get_ports "${SWITCH_VALID_LAN_PORT_TYPES}${SWITCH_HNAT_PORT_TYPES}")

	if [ "${_no_switch}" = "1" ]; then
		_port_prefix="eth"
	else
		_port_prefix="port"
	fi

	for _port in $_lan_ports; do
		if [ "$_port" = "$GMAC1_PHY_PORT" ]; then
			_ifname="eth1"
		elif [ "$_port" = "$GMAC2_PHY_PORT" ]; then
			_ifname="eth2"
		else
			_ifname="${_port_prefix}$_port"
		fi

		if [ "$_first" = "1" ]; then
			_ports="$_ifname"
			_first=0
		else
			_ports="$_ports $_ifname"
		fi
	done

	if [ "$_ports" = "$_cur_ports" ]; then
		return
	fi

	uci -q delete "network.$_name.ports"
	for _port in $_ports; do
		uci -q add_list "network.$_name.ports=${_port}"
	done
}

set_switch_wan() {
	local _name="@switch_vlan[1]"
	local _wan_ports=
	local _cpu_ports=
	local _switch=

	_switch=$(uci -q get network."$_name".device)
	_type=$(get_switch_type "$_switch")

	if has_extsw && [ "$_type" = "intsw" ]; then
		# hard code temporary
		_cpu_ports="5t 6t"
	else
		_wan_ports=$(get_ports "$SWITCH_WAN_PORT_TYPES")
		_cpu_ports=$(get_ports "$SWITCH_CPU_PORT_TYPES" | sed -E 's/[0-9]+/&t/g')
	fi

	uci -q set "network.$_name.ports=$_wan_ports $_cpu_ports"
	uci -q set "network.$_name.vlan=2"
}

set_switch_wan_dsa() {
	local _wan_port=
	local _no_switch=$(uci -q get "network.nrswitch.no_switch")
	local _port_prefix=
	local _ifname=

	if [ "${_no_switch}" = "1" ]; then
		_port_prefix="eth"
	else
		_port_prefix="port"
	fi

	_wan_port=$(get_ports "$SWITCH_WAN_PORT_TYPES")

	if [ -z "$_wan_port" ]; then
		_wan_port=$(get_ports "M")
		uci -q set "network.wan.disabled=1"
		uci -q set "network.wan6.disabled=1"
		if [ "$_wan_port" = "$GMAC1_PHY_PORT" ]; then
			_ifname="eth1"
		elif [ "$_wan_port" = "$GMAC2_PHY_PORT" ]; then
			_ifname="eth2"
		else
			_ifname="${_port_prefix}${_wan_port}"
		fi

		if [ -n "$_wan_port" ]; then
			uci -q set "network.wan.device=${_ifname}"
			uci -q set "network.wan6.device=${_ifname}"
		fi
	else
		if uci -q get network.nrswitch.disable_wan| grep -qsx '1' ;then
			uci -q set "network.wan.disabled=1"
			uci -q set "network.wan6.disabled=1"
		else
			uci -q set "network.wan.disabled=0"
			uci -q set "network.wan6.disabled=0"
		fi
		for _port in $_wan_port; do
			if [ "$_port" = "$GMAC1_PHY_PORT" ]; then
				_ifname="eth1"
			elif [ "$_port" = "$GMAC2_PHY_PORT" ]; then
				_ifname="eth2"
			else
				_ifname="${_port_prefix}${_port}"
			fi
			uci -q set "network.wan.device=${_ifname}"
			uci -q set "network.wan6.device=${_ifname}"
			break
		done
	fi
}

set_switch_msw() {
	local _name="@switch_vlan[2]"
	local _msw_ports=
	local _cpu_ports=

	if uci -N show network."$_name"|head -n1|grep -qE "^network.vlan[0-9+]"; then
		return
	fi

	_msw_ports=$(get_ports "$SWITCH_MSW_PORT_TYPES")
	_cpu_ports=$(get_ports "$SWITCH_CPU_PORT_TYPES" | sed -E 's/[0-9]+/&t/g')

	uci -q set "network.$_name.ports=$_msw_ports $_cpu_ports"
}

set_switch_msw_dsa() {
	local _msw_port=
	_msw_port=$(get_ports "$SWITCH_MSW_PORT_TYPES")
}

get_ports() {
	local _type=$1
	local _index=0
	local _vlan=
	local _port=
	local _output=

	_vlan=$(uci get network.nrswitch.nvlan | sed 's/./& /g')

	for _port in $_vlan; do
		if echo "$_type" | grep -qs "$_port"; then
			_output="$_output $_index"
		fi
		_index=$((_index + 1))
	done

	echo "$_output" | sed "s/^[ \t]*//"
}

has_extsw() {
	uci -q get network.nrswitch.extsw | grep -qEw "switch[0-9]+"
}

get_switch_type() {
	local _switch=$1
	local _type="intsw"
	local _extsw=

	_extsw=$(uci -q get network.nrswitch.extsw)
	if [ "$_switch" = "$_extsw" ]; then
		_type="extsw"
	fi

	echo "$_type"
}

delete_switch_vlan() {
	local _name=$1

	if echo "$_name" | grep -qE "^vlan[0-9]+$"; then
		uci delete network."$_name"
	fi
}

set_switch_vlan() {
	local _name=$1
	local _vlan=
	local _lan_ports=
	local _cpu_ports=

	_lan_ports=$(get_ports "$SWITCH_LAN_PORT_TYPES" | sed -E 's/[0-9]+/&t/g')
	_cpu_ports=$(get_ports "$SWITCH_CPU_PORT_TYPES" | sed -E 's/[0-9]+/&t/g')

	if echo "$_name" | grep -qE "^lan[0-9]+$"; then
		_vlan=${_name##lan}

		uci set network.vlan"$_vlan"=switch_vlan
		uci set network.vlan"$_vlan".device=switch0
		uci set network.vlan"$_vlan".vlan="$_vlan"
		uci set "network.vlan$_vlan.ports=$_lan_ports $_cpu_ports"
	fi
}

check_switch_config() {
	local _switch=$1

	if ! echo "$_switch" | grep -qEw "switch[0-9]+"; then
		return 0
	fi

	if ! uci show network | grep -qEw "$_switch"; then
		return 1
	fi

	return 0
}

gen_default_switch_config() {
	local _switch=$1

	uci -q add network switch
	uci -q set network.@switch[-1].name="$_switch"
	uci -q set network.@switch[-1].reset='1'
	uci -q set network.@switch[-1].enable_vlan='1'
	uci -q add network switch_vlan
	uci -q set network.@switch_vlan[-1].device="$_switch"
	uci -q set network.@switch_vlan[-1].vlan='1'
	uci -q add network switch_vlan
	uci -q set network.@switch_vlan[-1].device="$_switch"
	uci -q set network.@switch_vlan[-1].vlan='2'
}

detect_switch() {
	local _switch=
	local _swlist=
	local _swnum=0
	local _line=
	local _oldifs=$IFS

	_swlist=$(swconfig list)

	IFS=$'\n'
	for _line in $_swlist; do
		_swnum=$((_swnum + 1))
		_switch=$(echo "$_line" | cut -d' ' -f2)
		if ! check_switch_config "$_switch"; then
			gen_default_switch_config "$_switch"
		fi
		if [ "$_swnum" -eq 2 ]; then
			uci set network.nrswitch.extsw="$_switch"
		fi
	done
	IFS=$_oldifs
}

wan_vlan_fixup() {
	local _wvlan _vlans _mvlan

	_wvlan=$(uci -q get network.@switch_vlan[1].vlan)

	if ! uci show network|grep -qE "network.vlan[0-9]+"; then
		return
	fi

	_vlans=$(uci show network| \
			   grep -E "=switch_vlan$"| \
			   cut -d= -f1| \
			   grep -vE "switch_vlan\[[01\]"| \
			   sed 's/$/\.vlan/g'| \
			   xargs -n1 uci -q get| \
			   sort -n)

	[ -z "$_wvlan" ] || [ -z "$_vlans" ] && return

	if ! echo "$_vlans"|grep -qE "^${_wvlan}$"; then
		uci -q set network.wan.ifname="eth0.${_wvlan}"
		return
	fi

	_mvlan=$(echo -n "$_vlans"|tail -n 1)

	_wvlan=$((_mvlan+1))
	if [ "$_wvlan" -gt 4095 ]; then
		_wvlan=$((_mvlan-1))
		while echo "$_vlans"|grep -qE "^${_wvlan}$"; do
			_wvlan=$((_wvlan-1))
		done
	fi
	uci -q set network.@switch_vlan[1].vlan="${_wvlan}"
	uci -q set network.wan.ifname="eth0.${_wvlan}"
}
gExsit_nbpce=0
gExsit_celluar=0
check_nbcpe_cellular(){
	local _name="$1"
	config_get proto "$_name" proto
	config_get mode "$_name" mode
	config_get disabled "$_name" disabled
	if [ "$proto" == "wwan" -a "$disabled" != "1" ];then
		if [ "$mode" == "odu" ];then
			gExsit_nbpce=1
		else
			gExsit_celluar=1
		fi
	fi
}
gen_switch_config() {
	local _port=
	local _tvlan=
	local _ovlan=
	local _def_lan=
	local _def_wan=
	local _dsa=

	detect_switch

	_ovlan=$(uci get network.nrswitch.ovlan)
	_nbcpe=$(uci get network.globals.nbcpe)
	_tvlan="$_ovlan"
	local disable_wan=0
	if uci -q get network.nrswitch.disable_wan | grep -qsx '1';then
		disable_wan=1
	fi

	if [ "$_nbcpe" == "1" ];then
		if [ $disable_wan -eq 0 ];then
			if [ $gExsit_nbpce -eq 1 ] ;then
				_tvlan="$(echo "$_ovlan" | sed 's/[M|m]/W/g')"
			else
				_tvlan="$(echo "$_ovlan" | sed 's/M/W/g')"
			fi
		else
			if [ $gExsit_nbpce -eq 1 ] ;then
				_tvlan="$(echo "$_ovlan" | sed 's/M/W/g')"
			fi
		fi
	else
		if [ $disable_wan -eq 0 ];then
			_tvlan="$(echo "$_ovlan" | sed 's/M/W/g')"
		fi
	fi
	_tvlan="$(echo "$_tvlan" | sed 's/m/L/g')"

	if uci -q get oem.board.ptype | grep -vqsE '^(ac|rt)$'; then
		_tvlan="$(echo "$_ovlan" | sed 's/W/L/g')"
	fi

	if uci -q get auto_adapt.mode.en | grep -qsx '1'; then
		_port="$(uci -q get auto_adapt.mode.port)"
		_tvlan="$(echo "$_tvlan" | sed 's/W/L/g')"
		if [ -n "$_port" ]; then
			_tvlan="$(echo "$_tvlan" | sed "s/./W/$((_port + 1))")"
		fi
	fi

	# Agent in AP mode
	if uci -q get mesh.config.enabled | grep -qsx '1' && \
			uci -q get mesh.config.role | grep -qsx '1' && \
			uci -q get luci.main.first | grep -qsx '0'; then
		_tvlan="$(echo "$_tvlan" | sed 's/W/L/g')"
	fi

	uci set network.nrswitch.nvlan="$_tvlan"

	_dsa_mode=$(uci -q get network.nrswitch.dsa)

	if [ "$_dsa_mode" != "1" ]; then
		config_load "network"
		config_foreach delete_switch_vlan switch_vlan
		config_foreach set_switch_vlan interface
		set_switch_wan
		set_switch_msw
		set_switch_lan

		_def_lan=$(uci get network.lan.def_ifname)
		_def_wan=$(uci get network.wan.def_ifname)
		uci set network.lan.ifname="$_def_lan"
		uci set network.wan.ifname="$_def_wan"

		if uci show network.nrswitch.nvlan | grep -qs W && ! uci -q get network.nrswitch.disable_wan| grep -qsx '1'; then
			uci set network.wan.disabled='0'
			uci set network.wan6.disabled='0'
		else
			uci set network.wan.disabled='1'
			uci set network.wan6.disabled='1'
		fi

		wan_vlan_fixup
	else
		set_switch_lan_dsa
		set_switch_wan_dsa
		set_switch_msw_dsa
		setup_macs
	fi

	uci commit network
}

setup_switch_dev() {
	local name
	config_get name "$1" name
	name="${name:-$1}"
	[ -d "/sys/class/net/$name" ] && ip link set dev "$name" up
	swconfig dev "$name" load network
}

get_wan_count(){
	local _name=$1
	config_get proto "$_name" proto
	config_get disabled "$_name" disabled

	if [ "$disabled" != "1" ];then
		if [ "$proto" == "wwan" -a $_cpecnt -le 0 ]; then
			return
		fi

		if [ "$proto" == "wwan" -o "$_name" == "wan" ];then
			gWANCount=$((gWANCount+1))
		fi
	fi
}

set_defaultroute(){
	local _name=$1

	config_get proto "$_name" proto
	config_get disabled "$_name" disabled
	config_get background "$_name" background

	if [ "$proto" == "wwan" -o "$_name" == "wan" -o "$_name" == "wan6" ];then
		if [ "$disabled" != "1" -a "$gWANCount" -le "1" ] || [ "$background" == "1" ];then
			uci set network.$_name.defaultroute="1"
		else
			uci set network.$_name.defaultroute="0"
		fi
	fi
}

setup_switch() {
	local _port=

	config_load network
	config_foreach check_nbcpe_cellular interface
	gen_switch_config

	config_load network
	config_foreach setup_switch_dev switch
	config_foreach get_wan_count interface
	config_foreach set_defaultroute interface
	uci commit network

	ubus send infocdp.event "{'basic':'switch'}"
	_port=$(get_ports "$SWITCH_MSW_PORT_TYPES")
	if [ "$_port" != "$GMAC1_PHY_PORT" ]; then
		ifconfig port$_port up
	fi
}
