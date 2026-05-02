#!/bin/ash

_command_simcom_mode() {
	local _ctl="$1"
	local _mode="$2"
	local _cur

	_cur=$(_command_generic_exec "$_ctl" "CNMP" "?"|awk -F' ' '{print $2}')
	[ -z "$_cur" ] && return 1
	[ "$_cur" = "$_mode" ] && return 1

	_command_generic_exec "$_ctl" "CNMP" "=$_mode"
}

_command_simcom_get_mode() {
	local _ctl="$1"
	local _info="$2"
	local _nrcap
	local _mode _nrmode

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')

	_mode=$(_command_generic_exec "$_ctl" "CNMP" "?"|awk -F' ' '{print $2}')
	[ -z "$_mode" ] && return 1

	if [ "$_nrcap" = "1" ]; then
		_nrmode=$(_command_generic_exec "$_ctl" "CSYSSEL" "=\"nr5g_disable\""|awk -F',' '{print $2}'|xargs printf)
		[ -z "$_nrmode" ] && return 1
	fi

	json_init
	if [ "$_mode" = "2" ]; then
		_mode="AUTO"
	elif [ "$_mode" = "54" ]; then
		_mode="WCDMA+LTE Only"
	elif [ "$_mode" = "55" ]; then
		_mode="WCDMA+LTE+NR5G"
	fi
	json_add_string "MODE" "$_mode"

	if [ "$_nrcap" = "1" ]; then
		if [ "$_nrmode" = "0" ]; then
			_nrmode="AUTO"
		elif [ "$_nrmode" = "1" ]; then
			_nrmode="NSA"
		elif [ "$_nrmode" = "2" ]; then
			_nrmode="SA"
		fi
		json_add_string "NR" "$_nrmode"
	fi

	json_dump
	json_cleanup
}

_command_simcom_cpsi() {
	local _cpsi _sysmode _rsrp _rsrq _info _mode _nsa _cell _isp _tac _rmode _sinr

	_info="$1"

	_nsa=0
	json_init
	for _cpsi in $_info; do
		_sysmode="$(echo "$_cpsi"|cut -d, -f1)"
		_nsa=$((_nsa+1))
		if [ "$_sysmode" = "LTE" ]; then
			_rmode="$_sysmode"
			_mode="$_sysmode"
			json_add_object "$_sysmode"
			_isp="$(echo "$_cpsi"|cut -d, -f3|sed 's/-//g')"
			json_add_string "ISP" "$_isp"
			_tac="$(echo "$_cpsi"|cut -d, -f4)"
			json_add_string "TAC" "$_tac"
			_cell="$(echo "$_cpsi"|cut -d, -f5)"
			json_add_string "CELL" "$_cell"
			json_add_string "PCI" "$(echo "$_cpsi"|cut -d, -f6)"
			json_add_string "BAND" "$(echo "$_cpsi"|cut -d, -f7)"
			_rsrp="$(echo "$_cpsi"|cut -d, -f12)"
			if [ "$_rsrp" -gt 0 ]; then
				_rsrp=$((_rsrp-140))
			else
				_rsrp=$((_rsrp/10))
			fi
			_rsrq="$(echo "$_cpsi"|cut -d, -f11)"
			if [ "$_rsrq" -lt -1 ]; then
		   		_rsrq=$((_rsrq/10))
			else
				_rsrq=$(((_rsrq-39)/2))
			fi
			json_add_string "RSRP" "$_rsrp"
			json_add_string "RSRQ" "$_rsrq"
			json_add_string "RSSI" "$(echo "$_cpsi"|cut -d, -f13)"
			json_add_string "SINR" "$(echo "$_cpsi"|cut -d, -f14|xargs -r printf)"
		elif [ "$_sysmode" = "NR5G_SA" ]; then
			_rmode="NR SA"
			_mode="NR"
			json_add_object "$_mode"
			json_add_string "ISP" "$(echo "$_cpsi"|cut -d, -f3|sed 's/-//g')"
			json_add_string "TAC" "$(echo "$_cpsi"|cut -d, -f4)"
			json_add_string "CELL" "$(echo "$_cpsi"|cut -d, -f5)"
			json_add_string "PCI" "$(echo "$_cpsi"|cut -d, -f6)"
			json_add_string "BAND" "$(echo "$_cpsi"|cut -d, -f7)"
			_rsrp="$(echo "$_cpsi"|cut -d, -f9)"
			_rsrp=$((_rsrp/10))
			_rsrq="$(echo "$_cpsi"|cut -d, -f10)"
			_rsrq=$((_rsrq/10))
			json_add_string "RSRP" "$_rsrp"
			json_add_string "RSRQ" "$_rsrq"
			_sinr="$(echo "$_cpsi"|cut -d, -f11|xargs -r printf)"
			_sinr=$((_sinr/10))
			json_add_string "SINR" "$_sinr"
		elif [ "$_sysmode" = "NR5G_NSA" ]; then
			json_add_object "NR"
			_rmode="NR NSA"
			_mode="NR"
			json_add_string "ISP" "$_isp"
			json_add_string "TAC" "$_tac"
			json_add_string "CELL" "$_cell"
			json_add_string "PCI" "$(echo "$_cpsi"|cut -d, -f2)"
			json_add_string "BAND" "$(echo "$_cpsi"|cut -d, -f3)"
			_rsrp="$(echo "$_cpsi"|cut -d, -f6)"
			_rsrp=$((_rsrp/10))
			_rsrq="$(echo "$_cpsi"|cut -d, -f5)"
			_rsrq=$((_rsrq/10))
			_sinr="$(echo "$_cpsi"|cut -d, -f7|xargs -r printf)"
			_sinr=$((_sinr/10))
			json_add_string "RSRP" "$_rsrp"
			json_add_string "RSRQ" "$_rsrq"
			json_add_string "SINR" "$_sinr"
		elif [ "$_sysmode" = "WCDMA" ]; then
			_rmode="$_sysmode"
			_mode="$_sysmode"
			json_add_object"$_sysmode"
			json_add_string "ISP" "$(echo "$_cpsi"|cut -d, -f3|sed 's/-//g')"
			json_add_string "LAC" "$(echo "$_cpsi"|cut -d, -f4)"
			json_add_string "CELL" "$(echo "$_cpsi"|cut -d, -f5)"
			json_add_string "BAND" "$(echo "$_cpsi"|cut -d, -f6)"
			json_add_string "RSCP" "$(echo "$_cpsi"|cut -d, -f11)"
			json_add_string "RXLEV" "$(echo "$_cpsi"|cut -d, -f13)"
			json_add_string "EC/IO" "$(echo "$_cpsi"|cut -d, -f10)"
		elif [ "$_sysmode" = "GSM" ]; then
			_rmode="$_sysmode"
			_mode="$_sysmode"
			json_add_object "$_sysmode"
			json_add_string "ISP" "$(echo "$_cpsi"|cut -d, -f3|sed 's/-//g')"
			json_add_string "LAC" "$(echo "$_cpsi"|cut -d, -f4)"
			json_add_string "CELL" "$(echo "$_cpsi"|cut -d, -f5)"
			json_add_string "RXLEV" "$(echo "$_cpsi"|cut -d, -f7)"
		else
			continue
		fi
		json_close_object
	done
	json_add_string "MODE" "$_mode"
	if [ "$_nsa" = "2" ]; then
		json_add_string "RMODE" "$_rmode($_mode)"
	else
		json_add_string "RMODE" "$_rmode"
	fi
	json_dump
	json_cleanup
}

command_simcom_cellinfo() {
	local _res _cpsi

	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CPSI?")
	[ -z "$_res" ] && return 1

	_cpsi="$(echo "$_res"|grep "CPSI:"|cut -d' ' -f2)"
	_command_simcom_cpsi "$_cpsi"
}

command_simcom_signal() {
	command_simcom_cellinfo "$1"
}

command_simcom_basic() {
	local _ctl="$1"
	local _info="$2"
	local _res _imei _imsi _iccid _model _revision _cpsi _mode
	local _cmd

	_cmd="${AT_GENERIC_PREFIX}CPSI?|${AT_GENERIC_PREFIX}SIMEI?|${AT_GENERIC_PREFIX}CIMI|${AT_GENERIC_PREFIX}CICCID|ATI"
	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1

	_cpsi="$(echo "$_res"|grep "CPSI:"|cut -d' ' -f2)"

	_imei="$(echo "$_res"|grep 'SIMEI:'|awk -F' ' '{print $2}'|xargs -r printf)"
	_imsi="$(echo "$_res"|grep 'CIMI' -A2|sed -n '2p'|xargs -r printf)"
	_iccid="$(echo "$_res"|grep 'ICCID:'|awk -F' ' '{print $2}'|xargs -r printf)"
	_model="$(echo "$_res"|grep 'Model:'|awk -F' ' '{print $2}')"
	_revision="$(echo "$_res"|grep 'Revision:'|awk -F' ' '{print $2}')"
	_cpsi=$(_command_simcom_cpsi "$_cpsi")
	_mode="$(echo "$_cpsi"|jsonfilter -e '$["MODE"]')"

	json_init
	json_add_string "IMEI" "$(generic_validate_imei "$_imei")"
	json_add_string "IMSI" "$(generic_validate_imsi "$_imsi")"
	json_add_string "ICCID" "$(generic_validate_iccid "$_iccid")"
	json_add_string "MODEL" "$_model"
	json_add_string "REVISION" "$_revision"
	json_add_string "ISP" "$(echo "$_cpsi"|jsonfilter -e "\$['$_mode']['ISP']")"
	json_add_string "CELL" "$(echo "$_cpsi"|jsonfilter -e "\$['$_mode']['CELL']")"
	json_add_string "PCI" "$(echo "$_cpsi"|jsonfilter -e "\$['$_mode']['PCI']")"
	json_add_string "TAC" "$(echo "$_cpsi"|jsonfilter -e "\$['$_mode']['TAC']")"
	json_add_string "LAC" "$(echo "$_cpsi"|jsonfilter -e "\$['$_mode']['LAC']")"
	json_add_string "MODE" "$(echo "$_cpsi"|jsonfilter -e '$["RMODE"]')"
	json_add_string "BAND" "$(echo "$_cpsi"|jsonfilter -e "\$['$_mode']['BAND']")"
	json_add_string "RSRP" "$(echo "$_cpsi"|jsonfilter -e "\$['$_mode']['RSRP']")"
	json_add_string "SINR" "$(echo "$_cpsi"|jsonfilter -e "\$['$_mode']['SINR']")"
	json_add_string "RSRQ" "$(echo "$_cpsi"|jsonfilter -e "\$['$_mode']['RSRQ']")"
	json_add_string "RSSI" "$(echo "$_cpsi"|jsonfilter -e "\$['$_mode']['RSSI']")"
	json_add_string "RSCP" "$(echo "$_cpsi"|jsonfilter -e "\$['$_mode']['RSCP']")"
	json_add_string "RXLEV" "$(echo "$_cpsi"|jsonfilter -e "\$['$_mode']['RXLEV']")"
	json_dump
	json_cleanup
}

command_simcom_iccid() {
	local _res _info

	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CICCID"|grep 'ICCID:')
	[ -z "$_res" ] && return 1

	_info="$(echo "$_res"|awk -F' ' '{print $2}')"

	echo "$_info"
}

_command_simcom_nr5g_mode() {
	local _ctl="$1"
	local _mode="$2"
	local _cur

	_cur=$(_command_generic_exec "$_ctl" "CSYSSEL" "=\"nr5g_disable\""|awk -F',' '{print $2}'|xargs printf)
	[ -z "$_cur" ] && return 1
	[ "$_cur" = "$_mode" ] && return 0

	_command_generic_exec "$_ctl" "CSYSSEL" "=\"nr5g_disable\",$_mode"
}

command_simcom_nroff() {
	local _info="$2"
	local _nrcap

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')
	[ "$_nrcap" = "1" ] || return 0
	_command_simcom_mode "$1" "54"
}

command_simcom_allmode() {
	local _info="$2"
	local _nrcap

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')
	[ "$_nrcap" = "1" ] || return 0
	_command_simcom_mode "$1" "55"
	_command_simcom_nr5g_mode "$1" "0"
}

command_simcom_modensa() {
	local _info="$2"
	local _nrcap

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')
	[ "$_nrcap" = "1" ] || return 0

	_command_simcom_mode "$1" "55"
	_command_simcom_nr5g_mode "$1" "1"
}

command_simcom_modesa() {
	local _info="$2"
	local _nrcap

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')
	[ "$_nrcap" = "1" ] || return 0

	_command_simcom_mode "$1" "55"
	_command_simcom_nr5g_mode "$1" "2"
}

command_simcom_showmode() {
	_command_simcom_get_mode "$1" "$2"
}

command_simcom_signal2() {
	local _ctl="$1"
	local _info="$2"
	simo_info=$(_command_exec_raw "$_ctl" "get_simo_info")
	if [ -n "$simo_info" ];then
		cur_sim=$(echo "$simo_info"|jsonfilter -e '$["vsim slot"]')
		network_info=$(_command_exec_raw "$_ctl" "get_network_info" "{'sim_slot':'$cur_sim'}")
		if [ -n "$network_info" ];then
			rsrp=$(echo "$network_info"|jsonfilter -e '$["signal dbm"]')
			_mode=$(echo "$network_info"|jsonfilter -e '$["rat"]')
			if [ "$_mode" == "5G" ];then
				_mode="NR"
			elif [ "$_mode" == "4G" ];then
				_mode="LTE"
			elif [ "$_mode" == "3G" ];then
				_mode="WCDMA"
			fi
		fi
	fi
	json_init
	json_add_object "$_mode"
	json_add_int "RSRP" "$rsrp"	
	json_close_object

	json_add_string "MODE" "$_mode"
	json_dump
	json_cleanup

}

command_simcom_basic2() {
	local _ctl="$1"
	local _info="$2"
	local _res _imei _imsi _iccid _model _revision _cpsi _mode
	local _ctl="$1"
	local _info="$2"
	local _res

	simo_info=$(_command_exec_raw "$_ctl" "get_simo_info")

	if [ -n "$simo_info" ];then
		connection_mode_info=$(_command_exec_raw "$_ctl" "get_connection_mode")
		if [ -n "$connection_mode_info" ];then
			connection_mode=$(echo "$connection_mode_info"|jsonfilter -e '$["connection mode"]')
		fi

		if [ "$connection_mode" == "1" ];then
			cur_sim="1"
		else
			cur_sim=$(echo "$simo_info"|jsonfilter -e '$["vsim slot"]')
			cur_sim=$((cur_sim+1))
		fi
		simslot_info=$(_command_exec_raw "$_ctl" "get_simslot_info")
		if [ -n "$simslot_info" ];then
			iccid_list=$(echo "$simslot_info"|jsonfilter -e '$["iccid"]')
			imsi_list=$(echo "$simslot_info"|jsonfilter -e '$["imsi"]')
			imei_list=$(echo "$simslot_info"|jsonfilter -e '$["imei"]')
			simtype_list=$(echo "$simslot_info"|jsonfilter -e '$["sim type"]')
			simnumber_list=$(echo "$simslot_info"|jsonfilter -e '$["sim slot number"]')

			_iccid="$(echo "$iccid_list"|awk -F, '{print $'$cur_sim'}')"
			_imsi="$(echo "$imsi_list"|awk -F, '{print $'$cur_sim'}')"
			_imei="$(echo "$imei_list"|awk -F, '{print $'$cur_sim'}')"
			simtype="$(echo "$simtype_list"|awk -F, '{print $'$cur_sim'}')"
			simnumber="$(echo "$simnumber_list"|awk -F, '{print $'$cur_sim'}')"
		fi

		network_info=$(_command_exec_raw "$_ctl" "get_network_info" "{'sim_slot':'$cur_sim'}")
		if [ -n "$network_info" ];then			
			mcc=$(echo "$network_info"|jsonfilter -e '$["mcc"]')
			mnc=$(echo "$network_info"|jsonfilter -e '$["mnc"]')
			percent=$(echo "$network_info"|jsonfilter -e '$["signal percent"]')
			rsrp=$(echo "$network_info"|jsonfilter -e '$["signal dbm"]')
			mode=$(echo "$network_info"|jsonfilter -e '$["rat"]')
			if [ "$mode" == "5G" ];then
				mode="NR"
			elif [ "$mode" == "4G" ];then
				mode="LTE"
			elif [ "$mode" == "3G" ];then
				mode="WCDMA"
			fi
			simo=$(echo "$network_info"|jsonfilter -e '$["simo status"]')
			number=$(echo "$network_info"|jsonfilter -e '$["sim slot"]')
			band=$(echo "$network_info"|jsonfilter -e '$["band"]')
			channel=$(echo "$network_info"|jsonfilter -e '$["channel id"]')
			cell=$(echo "$network_info"|jsonfilter -e '$["cell id"]')
			lac=$(echo "$network_info"|jsonfilter -e '$["lac"]')
		fi
	fi

	#_imei="$(uci -q get "cellular_init.$gNet.imei")"
	_model="$(uci -q get "cellular_init.$gNet.model")"
	_revision="$(uci -q get "cellular_init.$gNet.version")"

	json_init
	json_add_string "IMEI" "$(generic_validate_imei "$_imei")"
	json_add_string "IMSI" "$_imsi"
	json_add_string "ICCID" "$(generic_validate_iccid "$_iccid")"
	json_add_string "MODEL" "$_model"
	json_add_string "REVISION" "$_revision"
	json_add_string "ISP" "$mcc$mnc"
	json_add_string "CELL" "$cell"
	json_add_string "PCI" ""
	json_add_string "TAC" ""
	json_add_string "LAC" "$lac"
	json_add_string "MODE" "$mode"
	json_add_string "BAND" "$band"
	json_add_string "RSRP" "$rsrp"
	json_add_string "SINR" ""
	json_add_string "RSRQ" ""
	json_add_string "RSSI" ""
	json_add_string "RSCP" ""
	json_add_string "RXLEV" ""
	json_dump
	json_cleanup
}

command_simcom_iccid2() {
	local _ctl="$1"
	local _info="$2"
	local _res _iccid
	local _res

	simo_info=$(_command_exec_raw "$_ctl" "get_simo_info")
	connection_mode_info=$(_command_exec_raw "$_ctl" "get_connection_mode")
	if [ -n "$connection_mode_info" ];then
		connection_mode=$(echo "$connection_mode_info"|jsonfilter -e '$["connection mode"]')
	fi

	if [ -n "$simo_info" ];then
		cur_sim=$(echo "$simo_info"|jsonfilter -e '$["vsim slot"]')
		if [ "$connection_mode" == "1" ];then
			cur_sim="1"
		else
			cur_sim=$(echo "$simo_info"|jsonfilter -e '$["vsim slot"]')
			cur_sim=$((cur_sim+1))
		fi
		simslot_info=$(_command_exec_raw "$_ctl" "get_simslot_info")
		if [ -n "$simslot_info" ];then
			iccid_list=$(echo "$simslot_info"|jsonfilter -e '$["iccid"]')
			_iccid="$(echo "$iccid_list"|awk -F, '{print $'$cur_sim'}')"
		fi
	fi
	echo "$_iccid"
}

command_simcom_sn2(){
	local _ctl="$1"
	local _info="$2"
	local _res
	local _cmd="get_simo_info"

	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1
	data=$(echo "$_res"|jsonfilter -e '$["sn"]')
	echo "$data"
}

command_simcom_model2(){
	echo "SIMO6600"
}

command_simcom_imei2() {
	local _ctl="$1"
	local _info="$2"
	local _res _imei
	local _res

	cur_sim="1"
	simslot_info=$(_command_exec_raw "$_ctl" "get_simslot_info")
	if [ -n "$simslot_info" ];then
		imei_list=$(echo "$simslot_info"|jsonfilter -e '$["imei"]')
		_imei="$(echo "$imei_list"|awk -F, '{print $'$cur_sim'}')"
	fi

	echo "$_imei"
}

command_simcom_version2(){
	local _ctl="$1"
	local _info="$2"
	local _res
	local _cmd="get_simo_info"

	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1
	data=$(echo "$_res"|jsonfilter -e '$["version"]')
	echo "$data"
}

command_simcom_reset2(){
	local _ctl="$1"
	local _info="$2"
	local _res
	local _cmd="modem_reboot"

	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1
	data=$(echo "$_res"|jsonfilter -e '$["result"]')
	echo "$data"
}

command_simcom_reboot2(){
	local _ctl="$1"
	local _info="$2"
	local _res
	local _cmd="system_reboot_device"

	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1
	data=$(echo "$_res"|jsonfilter -e '$["result"]')
	echo "$data"
}

command_simcom_pdp2(){
	local _ctl="$1"
	local _info="$2"
	#local cid="$3"
	local pdptype="$4"
	local apn="$5"
	local auth="$6"
	local username="$7"
	local password="$8"

	[ "$apn" == "\"\"" ] && apn=""
	[ "$auth" == "\"\"" ] && auth=""
	[ "$user" == "\"\"" ] && user=""
	[ "$password" == "\"\"" ] && password=""

	local _res
	local _cmd="set_apn"
	[ -z "$apn" ] && return 0
	_res=$(_command_exec_raw "$_ctl" "$_cmd" "{'apn':'$apn'${username:+",'user':'$username'"}${password:+",'password':'$password'"}${auth:+",'auth_type':'$auth'"}}")
	[ -z "$_res" ] && return 1
	data=$(echo "$_res"|jsonfilter -e '$["result"]')
	if [ "$data" == "0" ];then
		return 0
	fi
	return 1
}

command_simcom_getsimmode2(){
	local _ctl="$1"
	local _info="$2"
	local _res
	local _cmd="get_connection_mode"
	_res=$(_command_exec_raw "$_ctl" "$_cmd")

	[ -z "$_res" ] && return 1
	data=$(echo "$_res"|jsonfilter -e '$["connection mode"]')
	echo "$data"
}

command_simcom_simmode2(){
	local _ctl="$1"
	local _info="$2"
	local _mode="$3"
	local _value=0
	local _res
	local _cmd="set_connection_mode"

	[ "$_mode" != "0" ] && _value=1

	_res=$(_command_exec_raw "$_ctl" "$_cmd" "{'connection_mode':'$_value'}")
	[ -z "$_res" ] && return 1
	data=$(echo "$_res"|jsonfilter -e '$["result"]')
	echo "$data"
}


command_simcom_preinit2(){
	local _ctl="$1"
	local _info="$2"
	local reset=0
	local atsd_reset=0
	local val=1
	local vsim=$(uci -q get "cpesel.sim${gIndex}.vsim")

	local mode=$(command_simcom_getsimmode2)

	if [ "$vsim" == "1" ];then
		if [ "$mode" == "1" ];then
			val=0
			reset=1
		fi
	else
		if [ "$mode" == "0" ];then
			val=1
			reset=1
		fi
	fi

	if [ $reset -eq 1 ];then
		local _res=$(command_simcom_simmode2 "$_ctl" "$_info" "$val" )
		if [ "$data" == "0" ];then
			echo "change simo to $val"
		fi		
	fi

	return 0
}

command_simcom_usim_set2(){
	echo ""
}
command_simcom_usim_get2() {
	echo ""
}
