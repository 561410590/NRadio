#!/bin/ash

# shellcheck source=/dev/null
. /lib/functions.sh

oem_file_config="/etc/config/oem"

get_def_config() {
	local _key=$1

	bdinfo -g "$_key"
}

get_def_mac() {
	local _mac=

	_mac=$(get_def_config fac_mac|tr a-f A-F)
	echo "${_mac:-00:66:88:00:00:00}"
}

get_def_code() {
	local _code=
	_code=$(get_def_config device_code)
	echo "$_code"
}

get_def_console() {
	get_def_config console
}

get_def_country() {
	get_def_config country
}

get_def_board() {
	local _board=
	_board=$(get_def_config board)
	if [ -z "$_board" ]; then
		_board=$(cat /tmp/sysinfo/model 2>/dev/null|cut -d'-' -f2)
	fi
	echo "$_board"
}

oem_chk_init() {
	uci -q get oem.board.keep|grep -qsE '^1$'
}

oem_set_init() {
	uci set oem.board.keep=1
	uci commit oem
}

custom_iccid_fixup() {
	local iccid="$(get_def_config iccid)"
	local iccid1="$(get_def_config iccid1)"
	local iccid2="$(get_def_config iccid2)"
	local cpe1iccid1="$(get_def_config cpe1iccid1)"
	local cpe1iccid2="$(get_def_config cpe1iccid2)"
	local fixup_model_iccid=""
	local fixup_model1_iccid=""
	local cmd=""
	local cmd1=""
	local last_cmd=""
	if [ -n "$cpe1iccid1" ];then
		fixup_model1_iccid=$cpe1iccid1
		cmd="cpe1iccid1="
		if [ -n "$cpe1iccid2" ];then
			fixup_model1_iccid="${fixup_model1_iccid},${cpe1iccid2}"
			cmd="${cmd}\ncpe1iccid2="
		fi
	fi
	if [ -n "$fixup_model1_iccid" ];then
		cmd="${cmd}\niccid1=$fixup_model1_iccid"
		last_cmd=$cmd
	fi

	if [ -n "$iccid1" ];then
		fixup_model_iccid=$iccid1
		[ -z "$last_cmd" ] && cmd1="iccid1="
		if [ -n "$iccid2" ];then
			fixup_model_iccid="${fixup_model_iccid},${iccid2}"
			cmd1="${cmd1}\niccid2="
		else
			if [ -n "$iccid" ];then
				#normal
				fixup_model_iccid=""
				cmd1=""
			fi
		fi
	fi

	if [ -n "$fixup_model_iccid" ];then
		cmd1="${cmd1}\niccid=$fixup_model_iccid"
		last_cmd="${last_cmd:+$last_cmd\n}$cmd1"
	fi
	[ -n "$last_cmd" ] && echo -e "$last_cmd"|bdinfo_edit.sh
}

oem_cfg_fixup() {
	touch "$oem_file_config"
	uci set oem.board='system'
	uci set oem.board.id="$(get_def_mac)"
	uci set oem.board.device_code="$(get_def_code)"
	uci set oem.board.imei="$(get_def_config imei)"
	uci set oem.board.iccid="$(get_def_config iccid)"
	uci set oem.board.simid="$(get_def_config simid)"
	uci set oem.board.hardware_version="$(get_def_config hardware_version)"
	local nobat="$(get_def_config nobattery)"
	local iccid1="$(get_def_config iccid1)"
	local imei1="$(get_def_config imei1)"
	local simid1="$(get_def_config simid1)"
	[ -n "$nobat" ] && uci set oem.board.nobattery="$nobat"
	[ -n "$iccid1" ] && uci set oem.board.iccid1="$iccid1"
	[ -n "$imei1" ] && uci set oem.board.imei1="$imei1"
	[ -n "$simid1" ] && uci set oem.board.simid1="$simid1"
	uci set oem.feature='system'
	uci commit oem
}

oem_pre_file() {
	local _name=$1

	if [ "X$_name" != "X" ] && [ -e "/oem/$_name/files" ]; then
		cp -Hrf "/oem/$_name/files"/* / >/dev/null 2>&1
	fi
}

oem_pre_service() {
	local _name=$1

	[ ! -f "/oem/$_name/package" ] && return 1

	local _srv=
	local _cmd=

	while IFS=, read -r _srv _cmd
	do
		/etc/init.d/"$_srv" "${_cmd:-enable}"
	done < "/oem/$_name/package"

	return 0
}

checker_wanchk_instance() {
	uci set wanchk.$1.pingopen=0
	uci set wanchk.$1.dnsopen=0
}
checker_cellular_instance() {
	config_get proto "$1" proto

	if [ "$proto" == "wwan" -o "$proto" == "tdmi" ];then
		uci set network.$1.disabled=1
	fi
}
oem_authmode(){
	local _authmode=$(get_def_config authmode)
	
	[ -z "$_authmode" ] && return 0
	uci set firewall.ssh.target=ACCEPT
	config_load "wanchk"
	config_foreach checker_wanchk_instance checker
	if [ "$_authmode" == "0" ];then
		uci set authmodule.config.cellular_dial=0
		config_load "network"
		config_foreach checker_cellular_instance interface
	else
		uci set authmodule.config.cellular_dial=1
	fi

	if uci get adbd.service ;then
		uci set adbd.service.enable=1
	fi
	if uci get network.cpe1 && uci get network.cpe1.root_ifname ;then
		uci delete network.cpe1
	fi
	/etc/init.d/combo disable
	/etc/init.d/combo stop
}

oem_cpeoptimizes(){
	[ ! -f "/etc/config/cpeoptimizes" ] && return 0
	local _cpeoptimizes=$(get_def_config cpeoptimizes)
	
	if [ "$_cpeoptimizes" == "1" ];then
		uci set cpeoptimizes.cpeoptimizes.enabled='1'
		uci commit cpeoptimizes
		lua -e 'local nr = require "luci.nradio" nr.genarate_cpeoptimizes_cfg(false)'
	else
		uci set cpeoptimizes.cpeoptimizes.enabled='0'
		uci commit cpeoptimizes
	fi	
}

oem_pre_config() {
	local _name=$1

	echo "oem: apply custom configs" >>/dev/kmsg

	# Apply default config
	if [ -e "/oem/default/config" ]; then
		find -L "/oem/default/config" -type f|sort|xargs -n 1 sh
	fi

	# Apply ptype config
	/etc/ptype.d/init "$(uci -q get oem.board.ptype)"

	# Apply board config
	if [ -e "/oem/$_name/config" ]; then
		find -L "/oem/$_name/config" -type f|sort|xargs -n 1 sh
	fi

	# Apply product config
	if [ -e "/oem/product/config" ]; then
		find -L "/oem/product/config" -type f|sort|xargs -n 1 sh
	fi

	# Apply bdinfo config
	if [ -e "/oem/bdinfo/config" ]; then
		find -L "/oem/bdinfo/config" -type f|sort|xargs -n 1 sh
	fi
	oem_authmode
	oem_cpeoptimizes
	# Save uci changes
	uci commit
}

oem_set_name() {
	local _name=$1

	[ "X$_name" = "X" ] && return 0

	uci set oem.board.name="$_name"
	uci commit oem.board
}

oem_set_country() {
	local _country=$1

	uci set oem.board.country="${_country:-CN}"
	uci commit oem.board
}

oem_override_board() {
	local _pname=
	local _ptype=
	local _vendor=
	local _domain=

	if uci -q get oem.board.override|grep -qx 0; then
		return 0
	fi

	_pname=$(get_def_config "oem_pname")
	_ptype=$(get_def_config "oem_ptype")
	_vendor=$(get_def_config "oem_vendor")
	_domain=$(get_def_config "oem_domain")

	[ -n "$_pname" ] && uci set oem.board.pname="$_pname"
	[ -n "$_ptype" ] && uci set oem.board.ptype="$_ptype"
	uci set oem.board.vendor="${_vendor:=nradio}"
	uci set oem.custom=system
	if [ "$_vendor" = "neutral" ]; then
		find /www/luci-static/nradio/images -name "*logo.png" -exec rm {} \;
		uci set oem.custom.ssid=SSID
		uci set oem.custom.com=" "
		uci set oem.custom.domain=router.in
	elif [ "$_vendor" != "nradio" ]; then
		uci set oem.custom.com="$_vendor"
		uci set luci.main.overlap_dividing='0'
	fi
	[ -n "$_domain" ] && uci set oem.custom.domain="$_domain"

	uci commit oem
}
