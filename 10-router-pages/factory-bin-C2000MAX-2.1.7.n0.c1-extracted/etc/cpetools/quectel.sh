#!/bin/ash

_command_quectel_iccid() {
	local _res _info

	_res=$(_command_generic_exec "$1" "QCCID")
	[ -z "$_res" ] && return 1

	_info="$(echo "$_res"|awk -F' ' '{print $2}')"

	echo "$_info"
}
_command_quectel_dl() {
	local _data _res
	_data="$1"
	_res=""
	case "$_data" in
		"0")
			_res="5000"
			;;
		"1")
			_res="10000"
			;;
		"2")
			_res="15000"
			;;
		"3")
			_res="20000"
			;;
		"4")
			_res="25000"
			;;
		"5")
			_res="30000"
			;;
		"6")
			_res="40000"
			;;
		"7")
			_res="50000"
			;;
		"8")
			_res="60000"
			;;
		"9")
			_res="70000"
			;;
		"10")
			_res="80000"
			;;
		"11")
			_res="90000"
			;;
		"12")
			_res="100000"
			;;
		"13")
			_res="200000"
			;;
		"14")
			_res="400000"
			;;
		"15")
			_res="35000"
			;;
		"16")
			_res="45000"
			;;
	esac
	echo "$_res"
}

_command_quectel_servingcell() {
	local _servingcell _mmode
	_servingcell="$1"

	_state="$(echo "$_servingcell"|cut -d, -f2|sed 's/\"//g'|head -n1)"
	if [ "$_state" = "SEARCH" ]; then
		echo "{}"
	fi
	json_init
	for _line in $_servingcell; do
		_mode="$(echo "$_line"|cut -d, -f3|sed 's/\"//g')"
		json_add_object "$_mode"
		if [ "$_mode" = "GSM" ];then
			[ -z "$_mmode" ] && _mmode=$_mode
			json_add_int "RXLEV" "$(echo "$_line"|cut -d, -f11)"
			json_add_string "LAC" "$(echo "$_line"|cut -d, -f6)"
			json_add_string "CELL" "$(echo "$_line"|cut -d, -f7)"
			json_add_string "ISP" "$(echo "$_line"|cut -d, -f4)$(echo "$_line"|cut -d, -f5)"
		elif [ "$_mode" = "WCDMA" ];then
			[ -z "$_mmode" ] && _mmode=$_mode
			json_add_int "RSCP" "$(echo "$_line"|cut -d, -f11)"
			json_add_int "ECIO" "$(echo "$_line"|cut -d, -f12)"
			json_add_string "LAC" "$(echo "$_line"|cut -d, -f6)"
			json_add_string "CELL" "$(echo "$_line"|cut -d, -f7)"
			json_add_string "ISP" "$(echo "$_line"|cut -d, -f4)$(echo "$_line"|cut -d, -f5)"
		elif [ "$_mode" = "LTE" ];then
			_mmode=$_mode
			json_add_int "RSRP" "$(echo "$_line"|cut -d, -f14)"
			json_add_int "RSRQ" "$(echo "$_line"|cut -d, -f15)"
			json_add_int "SRXLEV" "$(echo "$_line"|cut -d, -f17)"
			json_add_string "TAC" "$(echo "$_line"|cut -d, -f13)"
			json_add_string "PCI" "$(echo "$_line"|cut -d, -f8)"
			json_add_string "EARFCN" "$(echo "$_line"|cut -d, -f9)"
			json_add_string "CELL" "$(echo "$_line"|cut -d, -f7)"
			json_add_string "ISP" "$(echo "$_line"|cut -d, -f5)$(echo "$_line"|cut -d, -f6)"
		fi
		json_close_object
	done
	json_add_string "MODE" "$_mmode"
	json_dump
	json_cleanup
}

_command_quectel_servingcell2() {
	local _qeng _cnt _sid _mode _cell _tac _mmode _tmp _rmode _sinr _ifs
	_qeng="$1"
	model_desc="$2"
	_cnt=$(echo "$_qeng"|grep -c "QENG:")
	_ifs="$IFS"
	IFS=$'\n'

	json_init
	for _line in $_qeng; do
		_info=$(echo "$_line"|cut -d: -f2)
		_cnt=$(echo "$_info"|awk -F, '{print NF}')
		if [ "$_cnt" -le 2 ]; then
			continue
		fi
		if echo "$_info"|grep -qEw "servingcell"; then
			_mode="$(echo "$_info"|cut -d, -f2|sed 's/^[ \t]*//g'|sed 's/\"//g')"
			if [ "$_mode" != "LTE" ] && \
				   [ "$_mode" != "WCDMA" ] && \
				   [ "${_mode:0:2}" != "NR" ]; then
				_sid=3
			else
				_sid=2
			fi
		else
			_sid=1
		fi
		_mode="$(echo "$_info"|cut -d, -f$_sid|sed 's/^[ \t]*//g'|sed 's/\"//g')"
		if [ -z "$_rmode" ]; then
			_rmode="$_mode"
		fi
		if [ "$_mode" = "WCDMA" ];then
			if [ "$_mmode" != "NR" ]; then
				_mmode=$_mode
			fi
			json_add_object "$_mode"
			json_add_string "ISP" "$(echo "$_info"|cut -d, -f$((_sid+1)))""$(echo "$_info"|cut -d, -f$((_sid+2)))"
		elif [ "$_mode" = "LTE" ];then
			if [ "$_mmode" != "NR" ]; then
				_mmode=$_mode
			fi
			json_add_object "$_mode"
			json_add_string "ISP" "$(echo "$_info"|cut -d, -f$((_sid+2)))""$(echo "$_info"|cut -d, -f$((_sid+3)))"
			_cell="$(echo "$_info"|cut -d, -f$((_sid+4)))"
			_tac="$(echo "$_info"|cut -d, -f$((_sid+10)))"
			json_add_string "CELL" "$_cell"
			json_add_string "PCI" "$(echo "$_info"|cut -d, -f$((_sid+5)))"
			json_add_string "EARFCN" "$(echo "$_info"|cut -d, -f$((_sid+6)))"
			json_add_string "BAND" "$(echo "$_info"|cut -d, -f$((_sid+7)))"
			json_add_string "TAC" "$_tac"
			json_add_int "RSRP" "$(echo "$_info"|cut -d, -f$((_sid+11)))"
			json_add_int "RSRQ" "$(echo "$_info"|cut -d, -f$((_sid+12)))"
			json_add_int "RSSI" "$(echo "$_info"|cut -d, -f$((_sid+13)))"
			json_add_int "SINR" "$(echo "$_info"|cut -d, -f$((_sid+14)))"
		elif [ "$_mode" = "NR5G-NSA" ] ;then
			json_add_object "NR"
			_rmode="NR NSA"
			_tmp="$(echo "$_info"|cut -d, -f$((_sid+1)))"
			_rsrp="$(echo "$_info"|cut -d, -f$((_sid+4)))"
			if [ "$_tmp" != "0" ] && [ "$_rsrp" -gt -1000 ]; then
				_mmode="NR"
			fi
			json_add_string "ISP" "$(echo "$_info"|cut -d, -f$((_sid+1)))""$(echo "$_info"|cut -d, -f$((_sid+2)))"
			json_add_string "PCI" "$(echo "$_info"|cut -d, -f$((_sid+3)))"
			json_add_int "RSRP" "$(echo "$_info"|cut -d, -f$((_sid+4)))"
			json_add_int "SINR" "$(echo "$_info"|cut -d, -f$((_sid+5)))"
			json_add_int "RSRQ" "$(echo "$_info"|cut -d, -f$((_sid+6)))"
			json_add_int "EARFCN" "$(echo "$_info"|cut -d, -f$((_sid+7)))"
			json_add_string "BAND" "$(echo "$_info"|cut -d, -f$((_sid+8)))"
		elif [ "$_mode" = "NR5G" ] ;then
			json_add_object "NR"
			_rmode="NR"
			_mmode="NR"
			json_add_string "ISP" "$(echo "$_info"|cut -d, -f$((_sid+1)))""$(echo "$_info"|cut -d, -f$((_sid+2)))"
			json_add_string "PCI" "$(echo "$_info"|cut -d, -f$((_sid+3)))"
			json_add_int "RSRP" "$(echo "$_info"|cut -d, -f$((_sid+4)))"
			json_add_int "SINR" "$(echo "$_info"|cut -d, -f$((_sid+6)))"
			json_add_int "RSRQ" "$(echo "$_info"|cut -d, -f$((_sid+5)))"
		elif [ "$_mode" = "NR5G-SA" ] ;then
			json_add_object "NR"
			_rmode="NR SA"
			_mmode="NR"
			dl_data="$(echo "$_info"|cut -d, -f$((_sid+9)))"
			if echo "$model_desc"|grep -qs "00U";then
				DLBW="$((dl_data*1000))"
			else
				DLBW="$(_command_quectel_dl "$dl_data")"
			fi
			json_add_string "ISP" "$(echo "$_info"|cut -d, -f$((_sid+2)))""$(echo "$_info"|cut -d, -f$((_sid+3)))"
			_cell="$(echo "$_info"|cut -d, -f$((_sid+4)))"
			_tac="$(echo "$_info"|cut -d, -f$((_sid+6)))"
			json_add_string "CELL" "$_cell"
			json_add_string "PCI" "$(echo "$_info"|cut -d, -f$((_sid+5)))"
			json_add_string "EARFCN" "$(echo "$_info"|cut -d, -f$((_sid+7)))"
			json_add_string "BAND" "$(echo "$_info"|cut -d, -f$((_sid+8)))"
			json_add_string "DLBW" "$DLBW"
			json_add_string "TAC" "$_tac"
			json_add_int "RSRP" "$(echo "$_info"|cut -d, -f$((_sid+10)))"
			json_add_int "SINR" "$(echo "$_info"|cut -d, -f$((_sid+12)))"
			json_add_int "RSRQ" "$(echo "$_info"|cut -d, -f$((_sid+11)))"
		else
			continue
		fi
		json_close_object
	done
	IFS="$_ifs"
	json_add_string "MODE" "$_mmode"
	if [ "$_rmode" = "NR NSA" ]; then
		json_add_string "RMODE" "$_rmode($_mmode)"
	else
		json_add_string "RMODE" "$_rmode"
	fi
	json_add_string "CELL" "$_cell"
	json_add_string "TAC" "$_tac"
	json_dump
	json_cleanup
}

_command_quectel_qnwinfo() {
	local _qnwinfo _line _act _oper _band _channel _ifs

	_qnwinfo="$1"
	_ifs="$IFS"
	IFS=$'\n'
	json_init
	for _line in $_qnwinfo; do
		_act="$(echo "$_line"|cut -d, -f1|sed 's/\"//g')"
		_oper="$(echo "$_line"|cut -d, -f2)"
		_band="$(echo "$_line"|cut -d, -f3|sed 's/5G//g'|grep -Eo '[0-9]+')"
		_channel="$(echo "$_line"|cut -d, -f4)"
		if echo "$_act"|grep -qEw "LTE"; then
			_act="LTE"
		elif echo "$_act"|grep -qE "NR"; then
			_act="NR"
		fi
		json_add_object "$_act"
		json_add_string "ISP" "$_oper"
		json_add_string "BAND" "$_band"
		json_add_string "CHANNEL" "$_channel"
		json_close_object
	done
	IFS="$_ifs"
	json_dump
	json_cleanup
}

_command_quectel_qcsq() {
	local _qcsq _sinr
	_qcsq="$1"

	json_init
	for _line in $_qcsq; do
		_mode="$(echo "$_line"|cut -d, -f1|sed 's/\"//g')"
		if [ "$_mode" = "GSM" ]; then
			json_add_object "$_mode"
			json_add_int "RSSI" "$(echo "$_line"|cut -d, -f2)"
		elif [ "$_mode" = "WCDMA" ] || [ "$_mode" = "TDSCDMA" ]; then
			json_add_object "$_mode"
			json_add_int "RSSI" "$(echo "$_line"|cut -d, -f2)"
			json_add_int "RSCP" "$(echo "$_line"|cut -d, -f3)"
			json_add_int "ECIO" "$(echo "$_line"|cut -d, -f4)"
		elif [ "$_mode" = "LTE" ]; then
			json_add_object "$_mode"
			json_add_int "RSSI" "$(echo "$_line"|cut -d, -f2)"
			json_add_int "RSRP" "$(echo "$_line"|cut -d, -f3)"
			json_add_int "SINR" "$(echo "$_line"|cut -d, -f4)"
			_sinr="$(echo "$_line"|cut -d, -f4)"
			_sinr=$((_sinr/5-20))
			json_add_int "SINR" "$_sinr"
			json_add_int "RSRQ" "$(echo "$_line"|cut -d, -f5)"
		else
			continue
		fi
		json_close_object
	done
	json_add_string "MODE" "$_mode"
	json_dump
	json_cleanup
}

_command_quectel_mode_pref() {
	local _res _info

	_res=$(_command_generic_exec "$1" "QNWPREFCFG" "=\"mode_pref\"")
	[ -z "$_res" ] && return 1

	_info=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)
	echo "$_info"
}

_command_quectel_mode_pref_set() {
	local _ctl="$1"
	local _mode="$2"

	_command_generic_exec "$_ctl" "QNWPREFCFG" "=\"mode_pref\",$_mode"
}

_command_quectel_nrmode() {
	local _res _info

	_res=$(_command_generic_exec "$1" "QNWPREFCFG" "=\"nr5g_disable_mode\"")
	[ -z "$_res" ] && return 1

	_info=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)
	echo "$_info"
}


_command_quectel_nrmode_set() {
	local _ctl="$1"
	local _mode="$2"
	local _nrmode

	_nrmode=$(_command_quectel_nrmode "$_ctl")
	[ -z "$_nrmode" ] && return 1

	if [ "$_nrmode" = "$_mode" ]; then
		return 0
	fi

	_command_generic_exec "$_ctl" "QNWPREFCFG" "=\"nr5g_disable_mode\",$_mode"

	return 0
}

_command_quectel_mode() {
	local _ctl="$1"
	local _mode="$2"
	local _mode_pref

	_mode_pref=$(_command_quectel_mode_pref "$_ctl")

	[ -z "$_mode_pref" ] && return 1
	if [ "$_mode_pref" = "$_mode" ]; then
		return 0
	fi

	_command_quectel_mode_pref_set "$_ctl" "$_mode"

	return 0
}

_command_quectel_get_nwscanseq() {
	local _res _info

	_res=$(_command_generic_exec "$1" "QCFG" "=\"nwscanseq\"")
	[ -z "$_res" ] && return 1

	_info=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)
	echo "$_info"
}

_command_quectel_set_nwscanseq() {
	local _ctl="$1"
	local _mode="$2"

	_command_generic_exec "$_ctl" "QCFG" "=\"nwscanseq\",$_mode"
}

command_quectel_signal() {
	local _res
	_res=$(_command_generic_exec "$1" "QCSQ")
	[ -z "$_res" ] && return 1

	_command_quectel_qcsq "$_res"
}

command_quectel_signal2() {
	command_quectel_cellinfo2 "$1"
}

command_quectel_cellinfo() {
	local _res _servingcell

	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}QENG=\"servingcell\"")
	[ -z "$_res" ] && return 1

	_servingcell="$(echo "$_res"|grep 'QENG:'|cut -d: -f2)"
	_command_quectel_servingcell "$_servingcell"
}

command_quectel_cellinfo2() {
	local _res _servingcell

	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}QENG=\"servingcell\"")
	[ -z "$_res" ] && return 1

	_servingcell="$(echo "$_res"|grep 'QENG:')"
	_command_quectel_servingcell2 "$_servingcell"
}

command_quectel_basic() {
	local _ctl="$1"
	local _info="$2"
	local _res _imei _imsi _iccid _servingcell _qnwinfo _qcsq _mode _model _revision _cpin
	local _cmd
	local apn="$(command_quectel_apn "$_ctl" "$_info"|jsonfilter -e "\$['APN']")"
	_cmd="${AT_GENERIC_PREFIX}QENG=\"servingcell\"|${AT_GENERIC_PREFIX}QNWINFO|${AT_GENERIC_PREFIX}QCSQ|${AT_GENERIC_PREFIX}CIMI|${AT_GENERIC_PREFIX}QCCID"

	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1

	_servingcell="$(echo "$_res"|grep 'QENG:'|cut -d: -f2)"
	_qnwinfo="$(echo "$_res"|grep 'QNWINFO:'|awk -F: '{print $2}')"
	_qcsq="$(echo "$_res"|grep 'QCSQ:'|awk -F: '{print $2}')"
	_imsi="$(echo "$_res"|grep 'CIMI' -A2|sed -n '2p'|xargs -r printf)"
	_imei="$(uci -q get "cellular_init.$gNet.imei")"
	_model="$(uci -q get "cellular_init.$gNet.model")"
	_revision="$(uci -q get "cellular_init.$gNet.version")"
	_iccid="$(echo "$_res"|grep 'QCCID:'|awk -F' ' '{print $2}')"

	_servingcell="$(_command_quectel_servingcell "$_servingcell")"
	_mode="$(echo "$_servingcell"|jsonfilter -e '$["MODE"]')"
	_qnwinfo="$(_command_quectel_qnwinfo "$_qnwinfo")"
	_qcsq="$(_command_quectel_qcsq "$_qcsq")"
	_isp="$(echo "$_servingcell"|jsonfilter -e "\$['$_mode']['ISP']"|awk '$1= $1')"

	_temp="$(command_quectel_temp "$_ctl")"
	_cpin="$(command_generic_cpin "$_ctl")"
	json_init
	if [ -n "$_temp" ];then
		json_add_string "MODEL_TEMP" "$_temp"
	fi
	json_add_string "ISP" "$_isp"
	json_add_string "CELL" "$(echo "$_servingcell"|jsonfilter -e "\$['$_mode']['CELL']")"
	json_add_string "PCI" "$(echo "$_servingcell"|jsonfilter -e "\$['$_mode']['PCI']")"
	json_add_string "EARFCN" "$(echo "$_servingcell"|jsonfilter -e "\$['$_mode']['EARFCN']")"
	json_add_string "TAC" "$(echo "$_servingcell"|jsonfilter -e "\$['$_mode']['TAC']")"
	json_add_string "IMEI" "$(generic_validate_imei "$_imei")"
	json_add_string "IMSI" "$(generic_validate_imsi "$_imsi")"
	json_add_string "ICCID" "$(generic_validate_iccid "$_iccid")"
	json_add_string "MODE" "$_mode"
	json_add_string "BAND" "$(echo "$_qnwinfo"|jsonfilter -e "\$['$_mode']['BAND']")"
	json_add_string "RSRP" "$(echo "$_qcsq"|jsonfilter -e "\$['$_mode']['RSRP']")"
	json_add_string "SINR" "$(echo "$_qcsq"|jsonfilter -e "\$['$_mode']['SINR']")"
	json_add_string "RSRQ" "$(echo "$_qcsq"|jsonfilter -e "\$['$_mode']['RSRQ']")"
	json_add_string "RSSI" "$(echo "$_qcsq"|jsonfilter -e "\$['$_mode']['RSSI']")"
	json_add_string "RSCP" "$(echo "$_qcsq"|jsonfilter -e "\$['$_mode']['RSCP']")"
	json_add_string "MODEL" "$_model"
	json_add_string "REVISION" "$_revision"
	json_add_string "SIMNUMBER" "$(command_generic_number "$1")"
	json_add_string "APN" "$apn"
	json_add_string "CPIN" "$_cpin"
	json_dump
	json_cleanup
}

command_quectel_basic2() {
	local _ctl="$1"
	local _info="$2"
	local _res _imei _imsi iccid _servingcell _mode _model _revision _qnwinfo _cpin
	local _cmd
	local nr5g_ambr_dl=""
	local nr5g_ambr_ul=""
	local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
	local vsim_active=""
	local _hfreq=""
	local vendor=$(check_soc_vendor)
	local nettype=$(uci -q get "network.$gNet.nettype")
	_imei="$(uci -q get "cellular_init.$gNet.imei")"
	_model="$(uci -q get "cellular_init.$gNet.model")"
	_revision="$(uci -q get "cellular_init.$gNet.version")"
	[ -f "/etc/vsim" ] && vsim_active=$(cat "/etc/vsim")
	if [ "$nettype" == "cpe" ];then
		local tgt_device_info="$(cat /etc/tgt_device_info)"
		[ -n "$tgt_device_info" ] && {
			json_init
			json_load "$tgt_device_info"
			json_select
			json_get_vars sn baseBoardApp_version hostBoard_version extBoard_version
			json_cleanup
		}
	fi
	if [ "$nettype" == "cpe" -a "$vsim_active" == "0" ];then
		local model_info="$(cat /tmp/4ginfo)"
		[ -n "$model_info" ] && {
			json_init
			json_load "$model_info"
			json_select
			json_get_vars iccid apn pin isp cell pci earfcn tac imsi nwmode band rsrp sinr rsrq nr5g_ambr_dl nr5g_ambr_ul
			if [ "$nwmode" == "NR5G-SA" ];then
				mode="NR SA"
			elif [ "$nwmode" == "NR5G-NSA" ];then
				mode="NR NSA"
			elif [ "$nwmode" = "NR5G" ] ;then
				mode="NR"
			else
				mode="$nwmode"
			fi
			json_cleanup
		}
	else
		local model_desc=$(uci -q get "network.${gNet}.desc")
		local apn="$(command_quectel_apn "$_ctl" "$_info"|jsonfilter -e "\$['APN']")"
		_cmd="${AT_GENERIC_PREFIX}QENG=\"servingcell\"|${AT_GENERIC_PREFIX}QNWINFO|${AT_GENERIC_PREFIX}CIMI|${AT_GENERIC_PREFIX}QCCID"
		_res=$(_command_exec_raw "$_ctl" "$_cmd")
		[ -z "$_res" ] && return 1

		imsi="$(echo "$_res"|grep 'CIMI' -A2|sed -n '2p'|xargs -r printf)"
		iccid="$(echo "$_res"|grep 'QCCID:'|awk -F' ' '{print $2}')"

		_qnwinfo="$(_command_quectel_qnwinfo "$(echo "$_res"|grep 'QNWINFO:'|awk -F: '{print $2}')")"
		_servingcell="$(_command_quectel_servingcell2 "$(echo "$_res"|grep 'QENG:')" "$model_desc")"
		_mode="$(echo "$_servingcell"|jsonfilter -e '$["MODE"]')"

		if echo "$model_desc"|grep -qs "00U";then
			_signing_info="$(_command_quectel_signing_rateunisoc2 "$_ctl")"
			[ -n "$_signing_info" ] && {
				nr5g_ambr_dl="$(echo "$_signing_info"|jsonfilter -e "\$['NR5G_AMBR_DL']"|awk '$1= $1')"
				nr5g_ambr_ul="$(echo "$_signing_info"|jsonfilter -e "\$['NR5G_AMBR_UL']"|awk '$1= $1')"
				qci="$(echo "$_signing_info"|jsonfilter -e "\$['CQI']"|awk '$1= $1')"
			}
		else
			_signing_info="$(_command_quectel_signing_rate2 "$_ctl")"
			[ -n "$_signing_info" ] && {
				nr5g_ambr_dl="$(echo "$_signing_info"|jsonfilter -e "\$['NR5G_AMBR_DL']"|awk '$1= $1')"
				nr5g_ambr_ul="$(echo "$_signing_info"|jsonfilter -e "\$['NR5G_AMBR_UL']"|awk '$1= $1')"
			}

			_qci_info="$(_command_quectel_signing_qci2 "$_ctl" "$_mode")"
			[ -n "$_qci_info" ] && {
				qci="$(echo "$_qci_info"|jsonfilter -e "\$['QCI']"|awk '$1= $1')"
			}
		fi

		isp="$(echo "$_servingcell"|jsonfilter -e "\$['$_mode']['ISP']"|awk '$1= $1')"
		cell="$(echo "$_servingcell"|jsonfilter -e "\$['CELL']")"
		pci="$(echo "$_servingcell"|jsonfilter -e "\$['$_mode']['PCI']")"
		earfcn="$(echo "$_servingcell"|jsonfilter -e "\$['$_mode']['EARFCN']")"
		if [ "$vendor" = "quectel_opsdk" ]; then
			tac="$(printf %x $(echo "$_servingcell"|jsonfilter -e "\$['TAC']"))"
		else
			tac="$(echo "$_servingcell"|jsonfilter -e "\$['TAC']")"
		fi
		mode="$(echo "$_servingcell"|jsonfilter -e '$["RMODE"]')"
		band="$(echo "$_qnwinfo"|jsonfilter -e "\$['$_mode']['BAND']")"
		rsrp="$(echo "$_servingcell"|jsonfilter -e "\$['$_mode']['RSRP']")"
		sinr="$(echo "$_servingcell"|jsonfilter -e "\$['$_mode']['SINR']")"
		rsrq="$(echo "$_servingcell"|jsonfilter -e "\$['$_mode']['RSRQ']")"
		rssi="$(echo "$_servingcell"|jsonfilter -e "\$['$_mode']['RSSI']")"
		rscp="$(echo "$_servingcell"|jsonfilter -e "\$['$_mode']['RSCP']")"
		dlbw="$(echo "$_servingcell"|jsonfilter -e "\$['$_mode']['DLBW']")"
		simnumber="$(command_generic_number "$1")"
		_hfreq="$(command_quectel_qcainfo2 "$1")"
	fi
	_temp="$(command_quectel_temp2 "$_ctl")"
	_cpin="$(command_generic_cpin "$_ctl")"
	json_init
	if [ -n "$_temp" ];then
		json_add_string "MODEL_TEMP" "$_temp"
	fi
	json_add_string "ISP" "$isp"
	json_add_string "CELL" "$cell"
	json_add_string "PCI" "$pci"
	json_add_string "EARFCN" "$earfcn"
	json_add_string "TAC" "$tac"
	json_add_string "IMEI" "$(generic_validate_imei "$_imei")"
	json_add_string "IMSI" "$(generic_validate_imsi "$imsi")"
	json_add_string "ICCID" "$(generic_validate_iccid "$iccid")"
	json_add_string "MODE" "$mode"
	json_add_string "BAND" "$band"
	json_add_string "RSRP" "$rsrp"
	json_add_string "SINR" "$sinr"
	json_add_string "RSRQ" "$rsrq"
	json_add_string "RSSI" "$rssi"
	json_add_string "RSCP" "$rscp"
	json_add_string "MODEL" "$_model"
	json_add_string "REVISION" "$_revision"
	json_add_string "SIMNUMBER" "$simnumber"
	json_add_string "APN" "$apn"
	json_add_string "CPIN" "$_cpin"
	json_add_string "DLBW" "$dlbw"
	json_add_string "CQI" "$qci"
	json_add_string "NR5G_AMBR_DL" "$nr5g_ambr_dl"
	json_add_string "NR5G_AMBR_UL" "$nr5g_ambr_ul"
	if echo "$mode"|grep -q "NR" ; then
		nr_count="$(echo "$_hfreq"|jsonfilter -e '$["nr_count"]')"
		i=0
		while [ $i -lt $nr_count ];do
			index=""
			if [ $i -gt 0 ];then
				index="$i"
			fi
			if echo "$_hfreq"|jsonfilter -e '$["NR'$index'"]' > /dev/null; then
				if [ $i -gt 0 ] ;then
					json_add_string "BAND$index" "$(echo "$_hfreq"|jsonfilter -e "\$['NR$index']['BAND']")"
					json_add_string "DLBW$index" "$(echo "$_hfreq"|jsonfilter -e "\$['NR$index']['DL_BANDWIDTH']")"
				fi
			fi
			i=$((i+1))
		done
	fi

	if [ "$nettype" == "cpe" ];then
		json_add_string "ext_sn" "$sn"
		json_add_string "ext_host_version" "$hostBoard_version"
		json_add_string "ext_app_version" "$baseBoardApp_version"
		json_add_string "ext_model_version" "$extBoard_version"
	fi
	json_dump
	json_cleanup
}

command_quectel_nroff2() {
	_command_quectel_mode "$1" "LTE"
}

command_quectel_allmode2() {
	local _nrmode

	_nrmode=$(_command_quectel_nrmode "$1")
	if [ -z "$_nrmode" ]; then
		_command_quectel_mode "$1" "AUTO"
	else
		_command_quectel_mode "$1" "AUTO"
		_command_quectel_nrmode_set "$1" 0
	fi
}

command_quectel_modesa_only2() {
	local _nrmode
	_model="$(uci -q get "cellular_init.$gNet.model")"

	_nrmode=$(_command_quectel_nrmode "$1")
	if [ -z "$_nrmode" ]; then
		if [ "$_model" == "RM500Q-CNS" ];then
			_command_quectel_mode "$1" "NR5G"
		else
			_command_quectel_mode "$1" "NR5G-SA"
		fi
	else
		_command_quectel_mode "$1" "NR5G"
		_command_quectel_nrmode_set "$1" 2
	fi
}

command_quectel_modensa_only2() {
	local _nrmode
	_model="$(uci -q get "cellular_init.$gNet.model")"

	_nrmode=$(_command_quectel_nrmode "$1")
	if [ -z "$_nrmode" ]; then
		if [ "$_model" == "RM500Q-CNS" ];then
			_command_quectel_mode "$1" "NR5G"
		else
			_command_quectel_mode "$1" "NR5G-NSA"
		fi
	else
		_command_quectel_mode "$1" "NR5G"
		_command_quectel_nrmode_set "$1" 1
	fi
}

command_quectel_modensa2() {
	local _nrmode
	_model="$(uci -q get "cellular_init.$gNet.model")"
	_nrmode=$(_command_quectel_nrmode "$1")

	if [ -z "$_nrmode" ]; then
		if [ "$_model" == "RM500Q-CNS" ];then
			_command_quectel_mode "$1" "AUTO"
		else
			_command_quectel_mode "$1" "NR5G-NSA:LTE:WCDMA"
		fi
	else
		_command_quectel_mode "$1" "AUTO"
		_command_quectel_nrmode_set "$1" 1
	fi
}

command_quectel_modesa2() {
	local _nrmode
	_model="$(uci -q get "cellular_init.$gNet.model")"
	_nrmode=$(_command_quectel_nrmode "$1")
	if [ -z "$_nrmode" ]; then
		if [ "$_model" == "RM500Q-CNS" ];then
			_command_quectel_mode "$1" "AUTO"
		else
			_command_quectel_mode "$1" "NR5G-SA:LTE:WCDMA"
		fi
	else
		_command_quectel_mode "$1" "AUTO"
		_command_quectel_nrmode_set "$1" 2
	fi
}

command_quectel_modewcdma2() {
	_command_quectel_mode "$1" "WCDMA"
}


command_quectel_showmode2() {
	_command_quectel_mode_pref "$1"
}

command_quectel_rstsim2() {
	command_generic_reset "$1"
	return 0
}

command_quectel_rstsim() {
	command_quectel_rstsim2 "$1"
	return 0
}

_command_quectel_freq() {
	local _res _info

	_res=$(_command_generic_exec "$1" "QNWPREFCFG" "=\"$2\"")
	[ -z "$_res" ] && return 1

	_info=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)
	echo "$_info"
}

_command_quectel_freq_set() {
	local _ctl="$1"
	local key="$2"
	local freq="$3"

	_command_generic_exec_expect "$_ctl" "QNWPREFCFG" "=\"$key\",$freq" "OK"
}


_command_quectel_caculate_freq(){	
	local freq_item=$1
	local datanum
	local datanumh
	local datatotal=0
	local datatotalh=0
	local freq_data=""
	dataArray=${freq_item//:/ }
	for key in $dataArray;do
		if [ "$key" -lt "65" ];then
			datanum=$((2**(key-1)))
			datatotal=$((datatotal+datanum))
		elif [ "$key" -lt "129" ];then
			datanumh=$((2**(key-65)))
			datatotalh=$((datatotalh+datanumh))
		fi
	done
	datatotal=$(printf %x $datatotal)
	datatotal=$(echo $datatotal | tr '[a-z]' '[A-Z]')
	datatotalh=$(printf %x $datatotalh)
	datatotalh=$(echo $datatotalh | tr '[a-z]' '[A-Z]')
	echo "$datatotal $datatotalh"
}


command_quectel_freq2() {
	local _ctl="$1"
	local freq="$2"
	local _freq=""
	local _key=""
	freqArray=${freq//,/ }
	for freq_item in $freqArray
	do
		local index=0
		local label=""
		local freq_data=""
		dataArray=${freq_item//-/ }
		for key in $dataArray;do
			if [ "$index" = "0" ];then
					label=$key
			else
					freq_data=$key
			fi
			index=$((index+1))
		done
		echo "mode $label,band $freq_data"
		if [ "$label" = "sa" ];then
			_key="nr5g_band"
		elif [ "$label" = "nsa" ];then
			_key="nsa_nr5g_band"
		elif [ "$label" = "nr" ];then
			_key="nr5g_band"
		elif [ "$label" = "lte" ];then
			_key="lte_band"
		elif [ "$label" = "wcdma" ];then
			_key="gw_band"
		fi
		if [ -n "$_key" ];then
			[  -z "$freq_data" ] && {
				freq_data="0"
			 }
			_freq=$(_command_quectel_freq "$_ctl" "$_key")
			[ -z "$_freq" ] && continue

			_tmp_freq=$(_command_quectel_caculate_freq "$_freq")
			_tmp_data=$(_command_quectel_caculate_freq "$freq_data")
			echo "freq_cur:$_tmp_freq"
			echo "freq_next:$_tmp_data"
			if [ "$_tmp_freq" = "$_tmp_data" ]; then
				continue
			fi
			
			_command_quectel_freq_set "$_ctl" "$_key" "$freq_data"
		fi
	done
}

_command_quectel_mode_qcfg_set() {
	local _ctl="$1"
	local _mode="$2"

	_command_generic_exec "$_ctl" "QCFG" "=\"nwscanmode\",$_mode"
}

_command_quectel_mode_qcfg() {
	local _res _info

	_res=$(_command_generic_exec "$1" "QCFG" "=\"nwscanmode\"")
	[ -z "$_res" ] && return 1

	_info=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)
	echo "$_info"
}

command_quectel_mode_qcfg() {
	local _ctl="$1"
	local _mode="$2"
	local _mode_pref

	_mode_pref=$(_command_quectel_mode_qcfg "$_ctl")

	[ -z "$_mode_pref" ] && return 1
	if [ "$_mode_pref" = "$_mode" ]; then
		return 0
	fi
	_command_quectel_mode_qcfg_set "$_ctl" "$_mode"

	return 0
}

command_quectel_nroff() {
	command_quectel_mode_qcfg "$1" "3"
}

command_quectel_allmode() {
	command_quectel_mode_qcfg "$1" "0"
}

command_quectel_modewcdma() {
	command_quectel_mode_qcfg "$1" "2"
}


_command_quectel_roam_qcfg() {
	local _res _info

	_res=$(_command_generic_exec "$1" "QCFG" "=\"roamservice\"")
	[ -z "$_res" ] && return 1

	_info=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)
	echo "$_info"
}


_command_quectel_roam_qcfg_set() {
	local _ctl="$1"
	local _mode="$2"

	_command_generic_exec "$_ctl" "QCFG" "=\"roamservice\",$_mode,1"
}


command_quectel_roam_qcfg(){
	local _ctl="$1"
	local _mode="$2"
	local _mode_pref

	_mode_pref=$(_command_quectel_roam_qcfg "$_ctl")

	[ -z "$_mode_pref" ] && return 1
	if [ "$_mode_pref" = "$_mode" ]; then
		return 0
	fi
	_command_quectel_roam_qcfg_set "$_ctl" "$_mode"

	return 0
}
command_quectel_roam() {
	if [ "$2" = "0" ];then
		command_quectel_roam_qcfg "$1" "1"
	else
		command_quectel_roam_qcfg "$1" "2"
	fi
}

_command_quectel_roam_qnwcfg() {
	local _res _info

	_res=$(_command_generic_exec "$1" "QNWCFG" "=\"data_roaming\"")
	[ -z "$_res" ] && return 1

	_info=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)
	echo "$_info"
}

_command_quectel_roam_qnwcfg_set() {
	local _ctl="$1"
	local _mode="$2"
	_command_generic_exec "$_ctl" "QNWCFG" "=\"data_roaming\",$_mode"
}


command_quectel_roam_qnwcfg(){
	local _ctl="$1"
	local _mode="$2"
	local _mode_pref

	_mode_pref=$(_command_quectel_roam_qnwcfg "$_ctl")
	[ -z "$_mode_pref" ] && return 1
	if [ "$_mode_pref" = "$_mode" ]; then
		return 0
	fi
	_command_quectel_roam_qnwcfg_set "$_ctl" "$_mode"

	return 0
}
command_quectel_roam2() {
	if [ "$2" = "0" ];then
		command_quectel_roam_qnwcfg "$1" "1"
	else
		command_quectel_roam_qnwcfg "$1" "0"
	fi
}

command_quectel_iccid() {
	_command_quectel_iccid "$1"
}

command_quectel_iccid2() {
	_command_quectel_iccid "$1"
}

command_quectel_smsnum2() {
	command_generic_smsnum "$1"
}

command_quectel_smsstorage2() {
	command_generic_smsstorage "$1"
}

command_quectel_modelte() {
	local _scanmode
	local _info="$2"
	local _hwid

	_hwid=$(echo "$_info"|jsonfilter -e '$["hwid"]')

	[ "$_hwid" != "2c7c:6005" ] && return

	_scanmode=$(_command_quectel_get_nwscanseq "$1")
	if [ "$_scanmode" != "12" ]; then
		_command_quectel_set_nwscanseq "$1" "12"
	fi
}

command_quectel_read_modelte() {
	local _scanmode

	_scanmode=$(_command_quectel_get_nwscanseq "$1")
	echo "$_scanmode"
}

command_quectel_model(){
	local _ctl="$1"
	local _res _model
	local _cmd

	_cmd="ATI"

	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1

	_model="$(echo "$_res"|grep 'ATI' -A4|sed -n '3p'|xargs -r printf)"
	_revision="$(echo "$_res"|grep 'Revision:'|awk -F' ' '{print $2}')"
	if echo "$_revision" |grep -q "RM500QCNSAR" ;then
		echo "${_model}S"
	else
		echo "$_model"
	fi
}

command_quectel_model2(){
	command_quectel_model "$@"
}

command_quectel_sn(){
	local _ctl="$1"

	_res=$(_command_generic_exec "$_ctl" "EGMR" "=0,5")
	[ -z "$_res" ] && echo ""

	echo "$_res" | cut -d':' -f2|sed 's/\"//g'|xargs -r printf
}

command_quectel_sn2(){
	command_quectel_sn "$@"
}

command_quectel_usim_get2() {
	local _res

	_res=$(_command_generic_exec "$_ctl" "QUIMSLOT" "?")
	[ -z "$_res" ] && echo "none"

	echo "$_res" | cut -d' ' -f2
}

command_quectel_usim_set2() {
	local _ctl="$1"
	local _new="$2"
	local _old _res

	_old=$(command_quectel_usim_get2 "$_ctl"|xargs -r printf)

	[ "$_old" = "none" ] && return 1
	[ "$_old" = "$_new" ] && return 0

	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}QUIMSLOT=${_new}" "9" "3"|grep "OK")
	[ -z "$_res" ] && return 1
	return 0
}

command_quectel_checkmpdn2(){
	local _ctl="$1"
	local val="$2"
	local _automatic="$3"
	local profileid=""
	local _val_empty="MPDN_RULE,0,0,0,0,0"
	local _data
	local _res
	local profile="1"
	local auto_connect="0"
	[ -f "/tmp/profileid_${gNet}" ] && profileid=$(cat /tmp/profileid_${gNet})
	[ -z "$_automatic" ] && _automatic="1"
	[ -n "$profileid" ] && profile="$profileid"
	[ "$_automatic" == "1" ] && auto_connect="1"
	local _val="MPDN_RULE,0,$profile,0,1,$auto_connect"
	local _val_set="=\"mPDN_rule\",0,$profile,0,1,$auto_connect,\"FF:FF:FF:FF:FF:FF\""

	if [ "$val" == "0" ];then
		_val_empty="MPDN_RULE,0,$profile,0,1,$auto_connect"
		_val="MPDN_RULE,0,0,0,0,0"
		_val_set="=\"mPDN_rule\",0"
	fi

	_res=$(_command_generic_exec "$_ctl" "QMAP" "=\"mPDN_rule\"" "" 6)
	[ -z "$_res" ] && return 1

	_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
	[ -z "$_data" ] && return 1
	_data=$(echo "$_data"|tr '[a-z]' '[A-Z]')
	_cur_profileid=$(echo "$_data"|awk -F',' '{print $3}')
	[ "$_cur_profileid" == "0" ] && _cur_profileid="$profileid"
	[ ! -f "/tmp/profileid_${gNet}" ] && echo -n "$_cur_profileid" > /tmp/profileid_${gNet}
	echo  "get mPDN_rule :$_data[$_val],$val,$_automatic"
	if [ "$_data" = "$_val" ]; then
		echo  "mPDN_rule :right"
		return 1
	elif [ "$_data" = "$_val_empty" ]; then
		echo  "mPDN_rule :set"
		_command_generic_exec "$_ctl" "QMAP" "$_val_set" "" 5
	else
		if [ "$val" != "0" ];then
			_command_generic_exec "$_ctl" "QMAP" "=\"mPDN_rule\",0" "" 8
		fi
		_command_generic_exec "$_ctl" "QMAP" "$_val_set" "" 5
		echo  "mPDN_rule :reset,$_val_set"
	fi

	return 0
}

command_quectel_checkpcie2(){
	local _ctl="$1"
	local val="$2"
	local _val_pcie="pcie/mode,$val"
	local _data
	local _res

	_res=$(_command_generic_exec "$_ctl" "QCFG" "=\"pcie/mode\"")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		if [ -n "$_data" ];then
			echo  "get pcie/mode :$_data"
			if [ "$_data" != "$_val_pcie" ]; then
				echo  "pcie/mode :set $val"
				_command_generic_exec "$_ctl" "QCFG" "=\"pcie/mode\",$val"
				return 0
			fi
		fi
	fi
	return 1
}

command_quectel_checkethdriver2(){
	local _ctl="$1"
	local _val_eth_driver="eth_driver,r8125,0"
	local _data
	local _res

	_res=$(_command_generic_exec "$_ctl" "QETH" "=\"eth_driver\"")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		if [ -n "$_data" ];then
			echo  "get eth_driver :$_data"
			if [ "$_data" = "$_val_eth_driver" ]; then
				echo  "eth_driver :set"
				_command_generic_exec "$_ctl" "QETH" "=\"eth_driver\",\"r8125\""
				return 0
			fi
		fi
	fi
	return 1
}

command_quectel_imsfmt2(){
	command_generic_imsfmt "$1"
}

command_quectel_imsreport2(){
	command_generic_imsreport "$1"
}

_command_forceims_set(){
	local _ctl="$1"
	local _data
	local _res
	local _val="$2"
	local max_try=5
	local error_response=0

	while true;do
		_res=$(_command_generic_exec_expect "$_ctl" "QCFG" "=\"ims\",$val" "OK")
		if [ -n "$_res" ];then
			return 0
		fi
		echo  "ims set error $error_response"
		error_response=$((error_response+1))
		if [ $error_response -gt $max_try ];then
			break
		fi
		sleep 1
	done

	return 1
}

command_quectel_forceims2(){
	local _ctl="$1"
	local val="$2"
	local _data
	local _res

	[ -z "$val" ] && val="1"
	_res=$(_command_generic_exec "$_ctl" "QCFG" "=\"ims\"")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F',' '{print $2}')
		if [ -n "$_data" ];then
			echo  "get ims :$_data"
			if [ "$_data" != "$val" ]; then
				echo  "ims :set $val"
				_command_forceims_set "$_ctl" "$val"
				return 0
			fi
		fi
	fi

	return 1
}

command_quectel_checkinterface2(){
	local _ctl="$1"
	local val="$2"
	local _val_data_interface="data_interface,$val,0"
	local _data
	local _res

	_res=$(_command_generic_exec "$_ctl" "QCFG" "=\"data_interface\"")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		if [ -n "$_data" ];then
			echo  "get data_interface :$_data"
			if [ "$_data" != "$_val_data_interface" ]; then
				echo  "data_interface :set $val"
				_command_generic_exec "$_ctl" "QCFG" "=\"data_interface\",$val,0"
			fi
		fi
	fi

	return 0
}

command_quectel_getversion2(){
	local _ctl="$1"
	local _model
	local _version

	_model="$(uci -q get "cellular_init.$gNet.model")"
	_version="$(uci -q get "cellular_init.$gNet.version")"
	if echo "$_model"|grep  -qs "RM5";then
		return 0
	fi

	if [ -n "$_version" -a -n "$_model" ];then
		_model=$(echo "$_model"|sed -e "s/-//g")
		if echo "$_version"|grep -q "RM500QCNAAR" ;then
			_version=$(echo "$_version"|sed -e "s/[$_model]//g"|tr '[a-z]' '[A-Z]'|sed -e "s/[A-Z]/ /g"|awk -F' ' '{print $1}')
			if [ $_version -lt 13 ];then
				return 1
			fi
		fi
	fi

	return 0
}

command_quectel_scan(){
	local _ctl="$1"
	local mode="$2"
	local _res
	local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
	[ -z "$simIndex" ] && simIndex="1"
	[ -z "$mode" ] && mode=$(uci -q get "cpecfg.${gNet}sim$simIndex.mode")
	_res=$(command_quectel_model "$1")
	special_flag=0
	if [ "$_res" == "EC25" ];then
		special_flag=1
	fi

	json_init
	json_add_array "scanlist"

	_res=$(_command_exec_raw "$_ctl" "AT+QENG=\"neighbourcell\"" 20|grep "+QENG:")
	_cnt=$(echo "$_res"|wc -l)
	i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_info="$(echo "$line"|awk -F: '{print $2}')"
			_rsrq="$(echo "$_info"|awk -F, '{print $6}'|xargs -r printf)"
			_mode=$(echo "$_info"|awk -F, '{print $2}'|sed -e 's/\"//g'|sed -e 's/ //g')
			if [ "$_mode" == "NR" -a "$mode" != "lte" ];then
				if [ -n "$_rsrq" ] ;then
					json_add_object
					json_add_string "MODE" "$_mode"
					json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $3}')"
					json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $4}')"
					json_add_string "RSRP" "$(echo "$_info"|awk -F, '{print $5}')"
					json_add_string "RSRQ" "$(echo "$_info"|awk -F, '{print $6}')"
					json_add_string "SINR" "$(echo "$_info"|awk -F, '{print $7}')"

					json_add_object "lockneed"
					json_add_string "MODE" "1"
					json_add_string "EARFCN" "1"
					json_add_string "PCI" "1"
					json_close_object

					json_close_object
				fi
			fi
			if [ "$_mode" == "LTE" -a "$mode" != "wcdma" ];then
				if [ -n "$_rsrq" ] ;then
					json_add_object
					json_add_string "MODE" "$_mode"
					json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $3}')"
					json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $4}')"
					if [ $special_flag -eq 1 ];then
						json_add_string "RSRQ" "$(echo "$_info"|awk -F, '{print $5}')"
						json_add_string "RSRP" "$(echo "$_info"|awk -F, '{print $6}')"
					else
						json_add_string "RSRP" "$(echo "$_info"|awk -F, '{print $5}')"
						json_add_string "RSRQ" "$(echo "$_info"|awk -F, '{print $6}')"
					fi

					json_add_string "RSSI" "$(echo "$_info"|awk -F, '{print $7}')"
					json_add_string "SINR" "$(echo "$_info"|awk -F, '{print $8}')"

					json_add_object "lockneed"
					json_add_string "MODE" "1"
					json_add_string "EARFCN" "1"
					json_add_string "PCI" "1"
					json_close_object

					json_close_object
				fi
			fi
			if [ "$_mode" == "WCDMA" -a "$mode" == "wcdma" ];then
				if [ -n "$_rsrq" ] ;then
					json_add_object
					json_add_string "MODE" "$_mode"
					json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $3}')"
					json_add_string "RSCP" "$(echo "$_info"|awk -F, '{print $6}')"
					json_add_string "ECNO" "$(echo "$_info"|awk -F, '{print $7}')"
					json_add_string "RXLEV" "$(echo "$_info"|awk -F, '{print $10}')"
					json_close_object
				fi
			fi
		fi
	done

	json_close_array
	json_dump
	json_cleanup
	return 0
}

command_quectel_scan_x(){
	local _ctl="$1"
	local _model
	local _res
	local i=0
	local max=16
	local scan_param="2"
	local mode="$2"
	local isp=""
	local vendor=$(check_soc_vendor)
	local scan_cache="/tmp/infocd/tmp/cpescan_cache"
	local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
	[ -z "$simIndex" ] && simIndex="1"
	local nr_support=$(uci -q get "network.${gNet}.nrcap")
	[ -z "$mode" ] && mode=$(uci -q get "cpecfg.${gNet}sim$simIndex.mode")
	if [ "$nr_support" == "1" ] && [ "$mode" == "lte" ];then
		scan_param="1"
	fi
	_res_cimi=$(command_generic_imsi "$_ctl")

	if [ "$vendor" = "quectel_ysdk" ]; then
		scan_cache="/var/run/infocd/tmp/cpescan_cache"
	elif [ "$vendor" = "quectel_opsdk" ]; then
		local open_isp=""
		if [ -n "$_res_cimi" ];then
			open_isp=${_res_cimi:0:5}
		fi

		if [ "$mode" == "lte" ]; then
			qscan -m 2 -I "$open_isp" > /tmp/wan0scan_cache &
		else
			qscan -m 4 -I "$open_isp" > /tmp/wan0scan_cache &
		fi
		return 0
	fi
	_res=$(command_quectel_freq2 "$_ctl" "sa-,nsa-,lte-")
	_res=$(_earfcn2_unisoc "$_ctl" "" "LTE" "0")
	_res=$(_earfcn2_unisoc "$_ctl" "" "NR" "0")
	_res=$(_command_exec_raw "$_ctl" "AT+COPS=2")
	
	json_init
	json_add_array "scanlist"
	
	_res=$(_command_exec_raw "$_ctl" "AT+QSCAN=$scan_param"|grep "OK")

	[ -z "$_res" ] && {
		json_close_array
		json_dump
		json_cleanup
		return 0
	}

	while true;do
		if [ -f "$scan_cache" ];then
			_res=$(cat "$scan_cache"|grep "QSCAN: ")
			_res=$(echo "$_res"|sed -e 's/\([^,]\)-/\1\r\n-/g')
			rm "$scan_cache"
			break
		else
			i=$((i+1))
			if [ $i -lt $max ];then
				sleep 10
			else
				json_close_array
				json_dump
				json_cleanup
				return 0
			fi
		fi
	done

	_cnt=$(echo "$_res"|wc -l)
	i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_info="$line"
			_last_band="$(echo "$_info"|awk -F, '{print $12}'|xargs -r printf)"
			_mcc=$(echo "$_info"|awk -F, '{print $6}')
			_mnc=$(echo "$_info"|awk -F, '{print $7}')
			if [ ${#_mnc} == 1 ];then
				_mnc="0$_mnc"
			fi
			_isp="${_mcc}${_mnc}"
			if [ -n "$_res_cimi" ];then
				_isp_len=${#_isp}
				isp=${_res_cimi:0:$_isp_len}
				_scan_company=$(jsonfilter -e '@[@.plmn[@="'$_isp'"]].company' </usr/lib/lua/luci/plmn.json )
				_cur_company=$(jsonfilter -e '@[@.plmn[@="'$isp'"]].company' </usr/lib/lua/luci/plmn.json )

				if [ -n "$_scan_company" -a -n "$_cur_company" -a "$_cur_company" != "$_scan_company" ];then
					continue
				fi
			fi

			if [ -n "$_last_band" ] ;then
				_rsrp="$(echo "$_info"|awk -F, '{print $4}')"
				_rsrq="$(echo "$_info"|awk -F, '{print $5}')"
				_lac="$(echo "$_info"|awk -F, '{print $9}')"
				_cid="$(echo "$_info"|awk -F, '{print $1}'|awk -F'-' '{print $2}')"
				_sinr="$(echo "$_info"|awk -F, '{print $13}')"
				if [ -n "$_rsrp" ];then
					_rsrp=$((_rsrp/100))
				fi
				if [ -n "$_rsrq" ];then
					_rsrq=$((_rsrq/100))
				fi
				if [ -n "$_sinr" ];then
					_sinr=$((_sinr/100))
				fi
				json_add_object
				if [ "$scan_param" == "1" ];then
					json_add_string "MODE" "LTE"
				else
					json_add_string "MODE" "NR"
				fi
				json_add_string "SINR" "$_sinr"
				json_add_string "CELL" "$(printf %x $_cid| tr 'a-z' 'A-Z')"
				json_add_string "LAC" "$(printf %x $_lac)"
				json_add_string "ISP" "$_isp"
				json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $3}')"
				json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $2}')"
				json_add_string "RSRP" "$_rsrp"
				json_add_string "RSRQ" "$_rsrq"
				json_add_string "BAND" "$_last_band"

				json_add_object "lockneed"
				json_add_string "MODE" "1"
				json_add_string "EARFCN" "1"
				json_add_string "PCI" "1"
				json_close_object

				json_close_object
			fi
		fi
	done

	json_close_array
	json_dump
	json_cleanup
	return 0
}


command_quectel_scan2(){
	local _ctl="$1"
	local _model
	local _res
	local scan_param="2"
	local isp=""
	local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
	local mode="$2"

	[ -z "$simIndex" ] && simIndex="1"
	local nr_support=$(uci -q get "network.${gNet}.nrcap")
	local odu_model=$(uci -q get "network.${gNet}.mode")
	[ -z "$mode" ] && mode=$(uci -q get "cpecfg.${gNet}sim$simIndex.mode")
	if [ "$nr_support" == "1" ] && [ "$mode" == "lte" ];then
		scan_param="1"
	fi

	if [ "$odu_model" == "odu" ];then
		$(touch /tmp/odu_scan_${gNet})
	fi
	_res_cimi=$(command_generic_imsi "$_ctl")
	_res=$(_command_exec_raw "$_ctl" "ATI")
	if [ -n "$_res" ];then
		_model=$(echo "$_res"|sed -n '3p'| sed -e 's/-//g')
		if echo "$_model"|grep  -qs "00U";then
			command_quectel_scan_x "$1" "$mode" 

			if [ "$odu_model" == "odu" ];then
				$(rm /tmp/odu_scan_${gNet})
			fi

			return 0
		fi
	fi

	json_init
	json_add_array "scanlist"

	if [ "$odu_model" != "odu" ];then
		if echo "$_model"|grep  -qs "RM500Q";then
			_res=$(_earfcn2_qualcomm "$_ctl" "" "LTE" "0")
			_res=$(_earfcn2_qualcomm "$_ctl" "" "NR" "0")
		else
			_res=$(command_quectel_freq2 "$_ctl" "sa-,nsa-,lte-")
			_res=$(_earfcn2_qualcomm "$_ctl" "" "LTE" "0")
			_res=$(_earfcn2_qualcomm "$_ctl" "" "NR" "0")
			_res=$(_command_exec_raw "$_ctl" "AT+COPS=2")
		fi
	fi
	_res=$(_command_exec_raw "$_ctl" "AT+QSCAN=$scan_param,1" 180|grep "+QSCAN:")
	_cnt=$(echo "$_res"|wc -l)
	i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_info="$(echo "$line"|awk -F: '{print $2}')"
			_last_band="$(echo "$_info"|awk -F, '{print $13}'|xargs -r printf)"
			_isp=$(echo "$_info"|awk -F, '{print $2}')$(echo "$_info"|awk -F, '{print $3}')
			if [ -n "$_res_cimi" ];then
				_isp_len=${#_isp}
				isp=${_res_cimi:0:$_isp_len}
				_scan_company=$(jsonfilter -e '@[@.plmn[@="'$_isp'"]].company' </usr/lib/lua/luci/plmn.json )
				_cur_company=$(jsonfilter -e '@[@.plmn[@="'$isp'"]].company' </usr/lib/lua/luci/plmn.json )

				if [ -n "$_scan_company" -a -n "$_cur_company" -a "$_cur_company" != "$_scan_company" ];then
					continue
				fi
			fi

			json_add_object
			json_add_string "MODE" "$(echo "$_info"|awk -F, '{print $1}'|sed -e 's/\"//g'|sed -e 's/ //g')"
			json_add_string "ISP" "$_isp"
			json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $4}')"
			json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $5}')"
			json_add_string "RSRP" "$(echo "$_info"|awk -F, '{print $6}')"
			json_add_string "RSRQ" "$(echo "$_info"|awk -F, '{print $7}')"
			json_add_string "CELL" "$(echo "$_info"|awk -F, '{print $10}'| tr 'a-z' 'A-Z')"
			json_add_string "LAC" "$(echo "$_info"|awk -F, '{print $11}')"
			json_add_string "SINR" "$(echo "$_info"|awk -F, '{print $14}')"
			if [ -n "$_last_band" ] ;then
				json_add_string "BAND" "$_last_band"
				json_add_object "lockneed"
				json_add_string "MODE" "1"
				json_add_string "EARFCN" "1"
				json_add_string "BAND" "1"
				json_add_string "PCI" "1"
				json_close_object
				json_close_object
			else
				json_add_object "lockneed"
				json_add_string "MODE" "1"
				json_add_string "EARFCN" "1"
				json_add_string "BAND" "0"
				json_add_string "PCI" "1"
				json_close_object
				json_close_object
			fi
		fi
	done

	json_close_array
	json_dump
	json_cleanup

	if [ "$odu_model" == "odu" ];then
		$(rm /tmp/odu_scan_${gNet})
	else
		_res=$(command_generic_reset "$1")
		$(ifup "$gNet" "$1" > /dev/null)
	fi

	return 0
}
command_quectel_neighbour2(){
	local _ctl="$1"
	local _model
	local _res
	local _data

	_res=$(_command_generic_exec "$1" "QENG" "=\"neighbourcell\"")
	_cnt=$(echo "$_res"|wc -l)
	i=0
	json_init
	json_add_array "neighbour"
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_info="$(echo "$line"|awk -F: '{print $2}')"
			_rsrq="$(echo "$_info"|awk -F, '{print $6}'|xargs -r printf)"
			_mode=$(echo "$_info"|awk -F, '{print $2}'|sed -e 's/\"//g'|sed -e 's/ //g')
			if [ -z "$_rsrp" -o "$_rsrp" -lt "-120" ];then
				continue
			fi
			if [ "$_mode" == "NR" -a "$mode" != "lte" ];then
				json_add_object
				json_add_string "MODE" "$_mode"
				json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $3}')"
				json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $4}')"
				json_add_string "RSRP" "$(echo "$_info"|awk -F, '{print $5}')"
				json_add_string "RSRQ" "$(echo "$_info"|awk -F, '{print $6}')"
				json_add_string "SINR" "$(echo "$_info"|awk -F, '{print $7}')"

				json_add_object "lockneed"
				json_add_string "MODE" "1"
				json_add_string "EARFCN" "1"
				json_add_string "PCI" "1"
				json_close_object
				json_close_object				
			fi
			if [ "$_mode" == "LTE" -a "$mode" != "wcdma" ];then
				json_add_object
				json_add_string "MODE" "$_mode"
				json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $3}')"
				json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $4}')"
				if [ $special_flag -eq 1 ];then
					json_add_string "RSRQ" "$(echo "$_info"|awk -F, '{print $5}')"
					json_add_string "RSRP" "$(echo "$_info"|awk -F, '{print $6}')"
				else
					json_add_string "RSRP" "$(echo "$_info"|awk -F, '{print $5}')"
					json_add_string "RSRQ" "$(echo "$_info"|awk -F, '{print $6}')"
				fi

				json_add_string "RSSI" "$(echo "$_info"|awk -F, '{print $7}')"
				json_add_string "SINR" "$(echo "$_info"|awk -F, '{print $8}')"

				json_add_object "lockneed"
				json_add_string "MODE" "1"
				json_add_string "EARFCN" "1"
				json_add_string "PCI" "1"
				json_close_object
				json_close_object
				
			fi
			if [ "$_mode" == "WCDMA" -a "$mode" == "wcdma" ];then
				json_add_object
				json_add_string "MODE" "$_mode"
				json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $3}')"
				json_add_string "RSCP" "$(echo "$_info"|awk -F, '{print $6}')"
				json_add_string "ECNO" "$(echo "$_info"|awk -F, '{print $7}')"
				json_add_string "RXLEV" "$(echo "$_info"|awk -F, '{print $10}')"
				json_close_object				
			fi
		fi
	done

	json_close_array
	json_dump
	json_cleanup
	return 0
}

command_quectel_checkpreffreq(){
	local _ctl="$1"
	local _val_pref_freq="0"
	local _data
	local _res

	_res=$(_command_generic_exec "$_ctl" "QNWCFG" "=\"nr5g_pref_freq_list\"")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		_status="$(echo "$_data"|awk -F, '{print $2}'|sed 's/ //g')"
		if [ -n "$_status" ];then
			echo  "get nr5g_pref_freq_list :$_status"
			if [ "$_status" != "$_val_pref_freq" ]; then
				echo  "nr5g_pref_freq_list :set $_val_pref_freq"
				_command_generic_exec "$_ctl" "QNWCFG" "=\"nr5g_pref_freq_list\",$_val_pref_freq"
				return 0
			fi
		fi
	fi

	return 1
}

command_quectel_openrgmii2(){
	local _ctl="$1"
	local _code=1
	local model_desc=$(uci -q get "network.${gNet}.desc")

	if echo "$model_desc"|grep -qs "00U";then
		_code=$(command_quectel_openrgmiiunisoc2 "$_ctl" "odu")
	else
		_code=$(command_quectel_openrgmiiqualcomm2 "$_ctl" "odu")
	fi
	json_init
	json_add_int "code" $_code
	json_add_string "model" $(command_quectel_model "$1")
	json_dump
	json_cleanup
}

command_quectel_getrgmii2(){
	local _ctl="$1"
	local _info=""
	local _status=""
	local model_desc=$(uci -q get "network.${gNet}.desc")

	if echo "$model_desc"|grep -qs "00U";then
		_info=$(command_quectel_getrgmiiunisoc2 "$_ctl")
		_status=$(echo "$_info"|jsonfilter -e '$["status"]')

		if [ "$_status" == "open" ];then
			nat_info=$(command_quectel_getrnatunisoc2 "$_ctl")
			_status=$(echo "$nat_info"|jsonfilter -e '$["status"]')
		fi
	else
		_info=$(command_quectel_getrgmiiqualcomm2 "$_ctl")
		_status=$(echo "$_info"|jsonfilter -e '$["status"]')
	fi
	json_init
	json_add_string "status" $_status
	json_add_string "model" $(command_quectel_model "$1")
	json_dump
	json_cleanup
}

command_quectel_openrgmiiqualcomm2(){
	local _ctl="$1"
	local work_mode="$2"
	local _code=1
	local _val_expect="enable"
	local _automatic=$(uci -q get cpecfg.config.automatic)

	rgmii_info=$(command_quectel_getrgmiiqualcomm2 "$_ctl")
	_status=$(echo "$rgmii_info"|jsonfilter -e '$["status"]')

	if [ "$_status" != "open" ];then
		_status="disable"
	else
		_status="enable"
	fi

	if [ "$_status" != "$_val_expect" ];then
		_res=$(_command_generic_exec_expect "$_ctl" "QETH" "=\"eth_at\",\"$_val_expect\"" "OK")
		if [ -n "$_res" ];then
			_code=0
		fi
	else
		_code=2
	fi

	if [ "$work_mode" == "odu" ];then
		$(command_quectel_checkethdriver2 "$1" > /dev/null)
		$(command_quectel_checkinterface2 "$1" "1" > /dev/null)
		$(command_quectel_checkpcie2 "$1" "1" > /dev/null)
		$(command_quectel_checkmpdn2 "$1" "1" "$_automatic" > /dev/null)
	fi
	echo $_code
}

command_quectel_getrgmiiqualcomm2(){
	local _ctl="$1"
	json_init
	_res=$(_command_generic_exec "$_ctl" "QETH" "=\"eth_at\"")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		_status="$(echo "$_data"|awk -F, '{print $2}'|sed 's/ //g'|sed -e 's/\"//g')"
		if [ "$_status" == "enable" ];then
			json_add_string "status" "open"
		elif [ "$_status" == "disable" ];then
			json_add_string "status" "close"
		fi
	fi
	json_dump
	json_cleanup
}

command_quectel_setrurcunisoc2(){
	local _ctl="$1"
	_res=$(_command_generic_exec "$_ctl" "QURCCFG" "=\"urcport\"")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		_status="$(echo "$_data"|awk -F, '{print $2}'|sed 's/ //g'|sed -e 's/\"//g')"
		if [ "$_status" != "all"  ];then
			$(_command_generic_exec_expect "$_ctl" "QURCCFG" "=\"urcport\",\"all\"" "OK")
		fi
	fi
}

command_quectel_closergmii2(){
	local _ctl="$1"
	local _code=2
	local _val_expect="close"
	local _model=$(command_quectel_model2 "$1")
	local model_desc=$(uci -q get "network.${gNet}.desc")
	if echo "$model_desc"|grep -qs "00U";then
		nat_info=$(command_quectel_getrnatunisoc2 "$_ctl")
		_status=$(echo "$nat_info"|jsonfilter -e '$["status"]')
		if [ "$_status" != "$_val_expect" ];then
			_res=$(_command_generic_exec_expect "$_ctl" "QCFG" "=\"nat\",0" "OK")
			if [ -n "$_res" ];then
				_code=0
				$(cpetools.sh -r)
			fi
		else
			if [ $_code != 0 ];then
				_code=2
			fi
		fi
	fi

	json_init
	json_add_int "code" $_code
	json_add_string "model" "$_model"
	json_dump
	json_cleanup
}

command_quectel_openrgmiiunisoc2(){
	local _ctl="$1"
	local work_mode="$2"
	local _code=1
	local _val_expect="open"
	command_quectel_setrurcunisoc2 "$_ctl"
	rgmii_info=$(command_quectel_getrgmiiunisoc2 "$_ctl")
	_status=$(echo "$rgmii_info"|jsonfilter -e '$["status"]')

	if [ "$_status" != "$_val_expect" ];then
		_res=$(_command_generic_exec_expect "$_ctl" "QCFG" "=\"eth_at\",1" "OK")
		if [ -n "$_res" ];then
			_code=0
		fi
	else
		_code=2
	fi

	if [ "$work_mode" == "odu" ];then
		nat_info=$(command_quectel_getrnatunisoc2 "$_ctl")
		_status=$(echo "$nat_info"|jsonfilter -e '$["status"]')
		if [ "$_status" != "$_val_expect" ];then
			_res=$(_command_generic_exec_expect "$_ctl" "QCFG" "=\"nat\",1" "OK")
			if [ -n "$_res" ];then
				_code=0
			fi
		else
			if [ $_code != 0 ];then
				_code=2
			fi
		fi
	fi
	echo $_code
}

command_quectel_getrgmiiunisoc2(){
	local _ctl="$1"
	json_init
	_res=$(_command_generic_exec "$_ctl" "QCFG" "=\"eth_at\"")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		_status="$(echo "$_data"|awk -F, '{print $2}'|sed 's/ //g'|sed -e 's/\"//g'|xargs -r printf)"
		if [ "$_status" == "1" ];then
			json_add_string "status" "open"
		elif [ "$_status" == "0" ];then
			json_add_string "status" "close"
		fi
	fi

	json_dump
	json_cleanup
}

command_quectel_getrnatunisoc2(){
	local _ctl="$1"
	json_init
	_res=$(_command_generic_exec "$_ctl" "QCFG" "=\"nat\"")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		_status="$(echo "$_data"|awk -F, '{print $2}'|sed 's/ //g'|sed -e 's/\"//g'|xargs -r printf)"
		if [ "$_status" == "1" -o "$_status" == "2"  ];then
			json_add_string "status" "open"
		elif [ "$_status" == "0" ];then
			json_add_string "status" "close"
		fi
	fi
	json_dump
	json_cleanup
}


command_quectel_checkrgmii2(){
	local _ctl="$1"
	local _code=1
	local work_mode=$(uci -q get "network.$gNet.mode")
	local model_desc=$(uci -q get "network.${gNet}.desc")
	if echo "$model_desc"|grep -qs "00U";then
		_code=$(command_quectel_openrgmiiunisoc2 "$_ctl" "$work_mode")
	else
		_code=$(command_quectel_openrgmiiqualcomm2 "$_ctl" "$work_mode")
	fi

	return $_code
}

_command_quectel_signing_rate2(){
	local _ctl="$1"
	local unit_map="1 4 16 64 256 1024 4096 16384 65536 262144 1048576 4194304 16777216 67108864 268435456"

	_res=$(_command_generic_exec "$1" "QNWCFG" "=\"nr5g_ambr\"")
	[ -z "$_res" ] && return 1

	_cnt=$(echo "$_res"|wc -l)

	local i=0
	local j=1
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_apn=$(echo "$line"|awk -F, '{print $2}'|sed 's/\"//g'|xargs -r printf)
			if [ "$_apn" == "IMS" -o "$_apn" == "ims" ];then
				continue
			fi
			_uint_DL=$(echo "$line"|awk -F, '{print $3}'|sed 's/\"//g'|xargs -r printf)
			_session_DL=$(echo "$line"|awk -F, '{print $4}'|sed 's/\"//g'|xargs -r printf)
			_uint_UL=$(echo "$line"|awk -F, '{print $5}'|sed 's/\"//g'|xargs -r printf)
			_session_UL=$(echo "$line"|awk -F, '{print $6}'|sed 's/\"//g'|xargs -r printf)

			j=1
			local dl_speed=""
			local ul_speed=""

			for key in $unit_map;do
				if [ "$j" == "$_uint_DL" ];then
					dl_speed=$((_session_DL*key/1024*1000))
				fi
				if [ "$j" == "$_uint_UL" ];then
					ul_speed=$((_session_UL*key/1024*1000))
				fi
				j=$((j+1))
			done
			break
		fi
	done

	json_init
	json_add_string "NR5G_AMBR_DL" "$dl_speed"
	json_add_string "NR5G_AMBR_UL" "$ul_speed"
	json_dump
	json_cleanup
	return 0
}

_command_quectel_signing_qci2(){
	local _ctl="$1"
	local _mode="$2"
	local qos_index=5
	if [ "$_mode" == "NR" ];then
		_res=$(_command_generic_exec "$1" "QNWCFG" "=\"nr5g_qos\"")
	elif [ "$_mode" == "LTE" ];then
		_res=$(_command_generic_exec "$1" "QNWCFG" "=\"lte_qos\"")
		qos_index=4
	else
		return 1
	fi
	[ -z "$_res" ] && return 1

	_cnt=$(echo "$_res"|wc -l)
	_qci=""
	local i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_apn=$(echo "$line"|awk -F, '{print $3}'|sed 's/\"//g'|xargs -r printf)
			if [ "$_apn" == "IMS" -o "$_apn" == "ims" ];then
				continue
			fi

			_qci=$(echo "$line"|awk -F, '{print $'$qos_index'}'|sed 's/\"//g'|xargs -r printf)
			break
		fi
	done

	json_init
	json_add_string "QCI" "$_qci"
	json_dump
	json_cleanup
	return 0
}

_command_quectel_signing_rateunisoc2(){
	local _ctl="$1"

	_res=$(_command_generic_exec "$1" "C5GQOSRDP" "=1")
	[ -z "$_res" ] && return 1
	_res=$(echo "$_res"|awk -F: '{print $2}')
	[ -z "$_res" ] && return 1
	qci=$(echo "$_res"|awk -F',' '{print $2}'|xargs -r printf|sed -e 's/ //g')
	nr5g_ambr_dl=$(echo "$_res"|awk -F',' '{print $7}'|xargs -r printf|sed -e 's/ //g')
	nr5g_ambr_ul=$(echo "$_res"|awk -F',' '{print $8}'|xargs -r printf|sed -e 's/ //g')
	json_init
	json_add_string "CQI" "$qci"
	json_add_string "NR5G_AMBR_DL" "$nr5g_ambr_dl"
	json_add_string "NR5G_AMBR_UL" "$nr5g_ambr_ul"
	json_dump
	json_cleanup
	return 0
}

_quectel_checkippnat(){
	local _ctl="$1"
	local ippnat_check_file="/tmp/${gNet}_ignore_ip_abnormal"
	local _data
	local _res

	_res=$(_command_generic_exec "$_ctl" "QMAP" "=\"IPPT_NAT\"")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		if [ -n "$_data" ];then
			echo  "get IPPT_NAT:$_data"
			if [ "$_data" == "IPPT_NAT,0" ]; then
				_res=$(_command_generic_exec "$_ctl" "QMAP" "=\"IPPT_NAT\",1")
				echo  "set IPPT_NAT 1"
			elif [ "$_data" == "IPPT_NAT,1" ]; then
				if [ -f $ippnat_check_file ];then
					rm $ippnat_check_file
				fi
			fi
		fi
	fi
	return 0
}

command_quectel_imssetstorage2(){
	command_generic_imssetstorage "$1"
}


command_quectel_prepare2(){
	local _ctl="$1"
	local match=0
	local diff=0
	local enabled=$(uci -q get cpeoptimizes.cpeoptimizes.enabled)
	[ -z "$enabled" ] && return 
	_imei=""
	while [ -z "$_imei" ];do
		_imei="$(uci -q get "cellular_init.$gNet.imei")"
		sleep 1
	done
	while true;do
		_imei_cur=$(command_generic_imei "$_ctl")
		if [ -n "$_imei_cur" ] && echo "$_imei_cur"|grep -v " not ";then
			break
		fi
		sleep 1
	done
	echo "_imei:$_imei,_imei_cur:$_imei_cur"
	checker_optimize() {
		config_get check "$1" check
		config_get name "$1" name
		local reg_max=4
		local reg_error=0

		if [ $match -eq 1 ];then
			return
		fi

		if [ "$name" != "$gNet" ];then
			return
		fi

		#if [ "$check" == "2" ];then
		#	return
		#fi

		match=1
		if [ "$_imei_cur" != "$1" ];then
			_command_generic_exec_expect "$_ctl" "EGMR" "=1,7,\"$1\"" "OK"
			echo "change to:$1"
			command_generic_reset "$_ctl"			
		fi

		#while true;do
		#	local _regstat=$(ubus call infocd cpeinfo "{'name':'$gNet'}")
		#	echo "_regstat:$_regstat"
		#	json_load "$_regstat"
		#	json_get_vars STAT MODE SIM
		
		#	if [ "$STAT" = "register" ]; then
		#		echo "prepare check:register ok"
		#		break
		#	else
				
		#		reg_error=$((reg_error+1))
		#		echo "prepare check:Failed to register($reg_error)"
		#		if [ $reg_error -ge $reg_max ];then
		#			uci set cpeoptimizes.$1.check="2"
		#			match=0
		#			diff=1
		#			break
		#		fi
		#		sleep 2
		#	fi
		#done
	}

	if [ "$enabled" == "1" ];then
		config_load "cpeoptimizes"
		config_foreach checker_optimize rule
	fi

	if [ $diff -eq 1 ];then
		uci commit cpeoptimizes
	fi
	if [ $match -eq 0 ];then
		if [ "$_imei_cur" != "$_imei" ];then
			_command_generic_exec_expect "$_ctl" "EGMR" "=1,7,\"$_imei\"" "OK"
			echo "change to2:$_imei"
			command_generic_reset "$1"			
		fi
	fi
}

command_quectel_prepare(){
	local _ctl="$1"
	local _info="$2"
	local cf_background=$(uci -q get network.$gNet.background)
	if [ "$cf_background" == "1" ];then
		_res=$(_command_generic_exec "$_ctl" "QCFG" "=\"nat\"")
		if [ -n "$_res" ];then
			_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
			_status="$(echo "$_data"|awk -F, '{print $2}'|sed 's/ //g'|sed -e 's/\"//g'|xargs -r printf)"
			if [ "$_status" == "1" -o "$_status" == "2"  ];then
				_res=$(_command_generic_exec_expect "$_ctl" "QCFG" "=\"nat\",0" "OK")
				if [ -n "$_res" ];then
					echo "reset modem as for nat"
					cpetools.sh -i "${gNet}" -r
					return 0
				fi
			fi
		fi
	fi

	command_quectel_prepare2 "$_ctl" "$_info"
}

command_quectel_checkdet2(){
	local _ctl="$1"
	local val="$2,0"
	local _data
	local _res

	_res=$(_command_generic_exec "$_ctl" "QSIMDET" "?")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		if [ -n "$_data" ];then
			echo  "get QSIMDET :$_data"
			if [ "$_data" != "$val" ]; then
				echo  "set QSIMDET:$val"
				command_generic_cfun_c "$1"
				_command_generic_exec "$_ctl" "QSIMDET" "=$val"
				command_generic_cfun_o "$1"
				return 0
			fi
		fi
	fi
	return 1
}


command_quectel_preinit2(){
	local _ctl="$1"
	local cpe_info="$2"
	local reset=0
	local atsd_reset=0
	local val=1
	local _phycap=$(uci -q get network.${gNet}.phycap)
	local _ifname=$(uci -q get network.${gNet}.ifname)
	local _automatic=$(uci -q get cpecfg.config.automatic)
	local work_mode=$(uci -q get "network.${gNet}.mode")
	local version=$(uci -q get cellular_init.${gNet}.version)
	local _force_ims="0"
	local vendor=$(check_soc_vendor)
	if _check_simslot ;then
		_force_ims="1"
	fi

	[ -z "$_phycap" ] && _phycap=0
	[ -z "$cpe_info" ] && return 0

	if [ -z "$version" ];then
		return 1
	fi

	if echo "$version" |grep -sq "RW";then
		return 0
	fi

	command_generic_imsreport "$1"
	command_quectel_imsfmt2 "$1"
	#if command_quectel_checkrgmii2 "$1" ;then
	#	reset=1
	#	atsd_reset=1
	#fi

	local _qmapmac=$(_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}QMAPWAC=?")
	if ! echo "$_qmapmac"| grep "OK" ;then
		[ -z "$_qmapmac" ] && return 1		
		command_quectel_forceims2 "$1" "$_force_ims"
		ims_result=$?
		if [ "$vendor" = "quectel_opsdk" -a "$ims_result" == "0" ]; then
			reset=1
		fi
		if [ "$_force_ims" == "1" ] && command_quectel_imssetstorage2 "$1" ;then
			/etc/init.d/smsd restart
		fi

		if [ $atsd_reset -eq 1 ];then
			cpetools.sh -i "${gNet}" -r
			/etc/init.d/atsd restart
			return 1
		else
			if [ $reset -eq 1 ];then
				cpetools.sh -i "${gNet}" -r
				return 1
			fi
		fi

		return 0
	fi

	echo  "support QMAPWAC"
	if command_quectel_imssetstorage2 "$1" ;then
		/etc/init.d/smsd restart
	fi

	if command_quectel_forceims2 "$1" "$_force_ims" ;then
		reset=1
	fi

	if [ -z "$_phycap" -o $_phycap -lt 2500 ];then
		val=0
	else
		command_quectel_getversion2 "$1"
		result=$?
		echo  "version check,$result"
		if [ $result -eq 1 ];then
			val=0
		fi
	fi

	if [ "$work_mode" == "odu" ];then
		val=1
	fi

	if command_quectel_checkethdriver2 "$1" ;then
		[ $val -eq 1 ] && reset=1
	fi

	command_quectel_checkinterface2 "$1" "$val"
	if command_quectel_checkpcie2 "$1" "$val" ;then
		reset=1
	fi

	if command_quectel_checkmpdn2 "$1" "$val" "$_automatic";then
		command_generic_reset "$1"
	fi

	#if command_quectel_checkpreffreq "$1" ;then
	#	reset=1
	#fi

	if [ $val -eq 1 ];then
		_quectel_checkippnat "$1"
	fi

	if [ $val -eq 0 -a -n "$_ifname" ];then
		uci -q delete network.${gNet}.ifname
		uci commit network
		atsd_reset=1
		reset=1
	fi

	if [ $atsd_reset -eq 1 ];then
		cpetools.sh -i "${gNet}" -r
		/etc/init.d/atsd restart
		return 1
	else
		if [ $reset -eq 1 ];then
			cpetools.sh -i "${gNet}" -r
			return 1
		fi
	fi

	return 0
}


command_quectel_apn2(){
	command_quectel_apn "$@"
}
command_quectel_apn(){
	local _ctl="$1"
	local _info="$2"
	local apn=""
	local profileid=""
	local profile="1"
	[ -f "/tmp/profileid_${gNet}" ] && profileid=$(cat /tmp/profileid_${gNet})
	[ -n "$profileid" ] && profile="$profileid"
	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}QICSGP?")

	if echo "$_res"| grep -sq "OK" ;then
		_res=$(echo "$_res"|grep "+QICSGP:")
		_cnt=$(echo "$_res"|wc -l)
		i=0
		while [ $i -lt $_cnt ];do
			i=$((i+1))
			line=$(echo "$_res" |sed -n "${i}p")
			if [ -n "$line" ];then
				_data="$(echo "$line"|awk -F: '{print $2}')"
				_cur_cid="$(echo "$_data"|awk -F, '{print $1}'|sed 's/ //g')"
				_cur_apn="$(echo "$_data"|awk -F, '{print $3}'|sed 's/"//g'|xargs -r printf)"
				if [ "$profile" == "$_cur_cid" ];then
					apn="$_cur_apn"
					break
				fi
			fi
		done
	else
		_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGDCONT?"|grep "+CGDCONT:")
		_cnt=$(echo "$_res"|wc -l)
		i=0
		while [ $i -lt $_cnt ];do
			i=$((i+1))
			line=$(echo "$_res" |sed -n "${i}p")
			if [ -n "$line" ];then
				_data="$(echo "$line"|awk -F: '{print $2}')"
				_cur_cid="$(echo "$_data"|awk -F, '{print $1}'|sed 's/ //g')"
				_cur_apn="$(echo "$_data"|awk -F, '{print $3}'|sed 's/"//g'|xargs -r printf)"

				if [ "$profile" == "$_cur_cid" ];then
					apn="$_cur_apn"
					break
				fi
			fi
		done
	fi
	json_init
	json_add_string "APN" "$apn"
	json_dump
	json_cleanup
}

command_quectel_pdp2(){
	command_quectel_pdp "$@"
}

command_quectel_pdp(){
	local _ctl="$1"
	local _info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	local cid="$3"
	local pdptype="$4"
	local apn="$5"
	local auth="$6"
	local username="$7"
	local password="$8"
	local change=0
	local found=0

	[ "$apn" == "\"\"" ] && apn=""
	[ "$auth" == "\"\"" ] && auth=""
	[ "$username" == "\"\"" ] && username=""
	[ "$password" == "\"\"" ] && password=""

	[ -z "$cid" ] && cid="1"

	_res=$(_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}QICSGP?")
	if echo "$_res"| grep -sq "OK" ;then
		_res=$(echo "$_res"|grep "+QICSGP:")
		[ -z "$_res" ] && return 1
		pdptype=$(echo $pdptype | tr 'a-z' 'A-Z')
		[ -z "$auth" ] && auth="0"
		_cnt=$(echo "$_res"|wc -l)
		i=0
		while [ $i -lt $_cnt ];do
			i=$((i+1))
			line=$(echo "$_res" |sed -n "${i}p")
			if [ -n "$line" ];then
				_data="$(echo "$line"|awk -F: '{print $2}')"
				_cur_cid="$(echo "$_data"|awk -F, '{print $1}'|sed 's/ //g')"
				_cur_pdptype="$(echo "$_data"|awk -F, '{print $2}'|sed 's/"//g')"
				case $pdptype in
					"IP")		pdptype=1 ;;
					"IPV6")		pdptype=2 ;;
					"IPV4V6")	pdptype=3 ;;
				esac

				_cur_apn="$(echo "$_data"|awk -F, '{print $3}'|sed 's/"//g'|xargs -r printf)"
				_cur_username="$(echo "$_data"|awk -F, '{print $4}'|sed 's/"//g')"
				_cur_password="$(echo "$_data"|awk -F, '{print $5}'|sed 's/"//g')"

				if [ "$cid" == "$_cur_cid" ];then
					found=1
					if [ -z "$apn" ];then
						apn="$_cur_apn"
						if check_apn_disable ;then
							apn=""
						fi
					fi 
					if [ "$_cur_pdptype" != "$pdptype" -o "$_cur_apn" != "$apn" -o "$_cur_username" != "$username"  -o "$_cur_password" != "$password" ];then
						_command_exec_raw "$1" "${AT_GENERIC_PREFIX}QICSGP=$cid,$pdptype,\"$apn\",\"$username\",\"$password\",$auth"
						change=1
					fi
					break
				fi
			fi
		done
	else
		_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGDCONT?"|grep "+CGDCONT:")
		[ -z "$_res" ] && return 1
		pdptype=$(echo $pdptype | tr 'a-z' 'A-Z')
		[ -z "$auth" ] && auth="0"
		_cnt=$(echo "$_res"|wc -l)
		i=0
		while [ $i -lt $_cnt ];do
			i=$((i+1))
			line=$(echo "$_res" |sed -n "${i}p")
			if [ -n "$line" ];then
				_data="$(echo "$line"|awk -F: '{print $2}')"
				_cur_cid="$(echo "$_data"|awk -F, '{print $1}'|sed 's/ //g')"
				_cur_pdptype="$(echo "$_data"|awk -F, '{print $2}'|sed 's/"//g')"
				_cur_apn="$(echo "$_data"|awk -F, '{print $3}'|sed 's/"//g'|xargs -r printf)"
				_cur_pdptype=$(echo $_cur_pdptype | tr 'a-z' 'A-Z')
				if [ "$cid" == "$_cur_cid" ];then
					found=1
					if [ -z "$apn" ];then
						apn="$_cur_apn"
						if check_apn_disable ;then
							apn=""
						fi
					fi 
					if [ -n "$username" -o -n "$password" ];then
						case $pdptype in
							"IP")		pdptype=1 ;;
							"IPV6")		pdptype=2 ;;
							"IPV4V6")	pdptype=3 ;;
						esac
						_command_exec_raw "$1" "${AT_GENERIC_PREFIX}QICSGP=$cid,$pdptype,\"$apn\",\"$username\",\"$password\",$auth"
						change=1
					else
						if [ "$_cur_pdptype" != "$pdptype" -o "$_cur_apn" != "$apn" ];then
							_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGDCONT=$cid,\"$pdptype\"${apn:+,\"$apn\"}"
							change=1
						fi
					fi
					break
				fi
			fi
		done
	fi

	if [ $found -eq 0 ];then
		_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGDCONT=$cid,\"$pdptype\"${apn:+,\"$apn\"}"
		change=1
	fi

	if [ $change -eq 1 ];then
		command_generic_reset "$1"
	fi
}

_earfcn2_qualcomm(){
	local _ctl="$1"
	local _info="$2"
	local mode="$3"
	local earfcn="$4"
	local pci="$5"
	local band="$6"
	local cmd_core="common/5g"
	local action=""
	local scs=

	[ "$mode" == "LTE" ] && cmd_core="common/4g"

	_res=$(_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}QNWLOCK=\"$cmd_core\""| grep "QNWLOCK")
	[ -z "$_res" ] && return 1
	action=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)
	[ "$mode" == "LTE" ] && _pci=$(echo "$_res"|awk -F, '{print $4}'|xargs -r printf)
	[ "$mode" == "NR" ] && _pci=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)

	if [ -z "$pci" ];then
		if [ "$action" != "0" ];then
			echo "earfcn mode:$mode free earfcn"
			if _command_generic_exec_expect "$_ctl" "QNWLOCK" "=\"$cmd_core\",0" "OK" ;then
				_command_generic_exec_expect "$_ctl" "QNWLOCK" "=\"save_ctrl\",1,1" "OK"
			else
				return 1
			fi
		fi
		return 0
	fi

	if [ "$band" == "1" -o "$band" == "2" -o "$band" == "3" -o "$band" == "5" -o "$band" == "7" -o "$band" == "8" -o "$band" == "12" -o "$band" == "20" -o "$band" == "25" -o "$band" == "28" -o "$band" == "66" -o "$band" == "71" -o "$band" == "75" -o "$band" == "76" ];then
		scs=15
	elif [ "$band" == "38" -o "$band" == "40" -o "$band" == "41" -o "$band" == "48" -o "$band" == "77" -o "$band" == "78" -o "$band" == "79" ];then
		scs=30
	elif [ "$band" == "257" -o "$band" == "258" -o "$band" == "260" -o "$band" == "261" ];then
		scs=120
	fi

	_earfcn=$(echo "$_res"|awk -F, '{print $3}'|xargs -r printf)

	if [ "$mode" == "NR" ];then
		_band=$(echo "$_res"|awk -F, '{print $5}'|xargs -r printf)
		_scs=$(echo "$_res"|awk -F, '{print $4}'|xargs -r printf)
		if [ "$_earfcn" != "$earfcn" -o "$_pci" != "$pci" -o "$_band" != "$band"  -o "$_scs" != "$scs" ];then
			echo "earfcn mode:$mode set earfcn:$earfcn pci:$pci scs:$scs band:$band|old earfcn:$_earfcn _pci:$_pci band:$_band scs:$_scs"
			if _command_generic_exec_expect "$_ctl" "QNWLOCK" "=\"$cmd_core\",$pci,$earfcn,$scs,$band" "OK" ;then
				_command_generic_exec_expect "$_ctl" "QNWLOCK" "=\"save_ctrl\",1,1" "OK"
			else
				return 1
			fi
		fi
	elif [ "$mode" == "LTE" ];then
		if [ "$_earfcn" != "$earfcn" -o "$_pci" != "$pci" ];then
			echo "earfcn mode:$mode set earfcn:$earfcn pci:$pci|old earfcn:$_earfcn pci:$_pci "
			if _command_generic_exec_expect "$_ctl" "QNWLOCK" "=\"$cmd_core\",1,$earfcn,$pci" "OK" ;then
				_command_generic_exec_expect "$_ctl" "QNWLOCK" "=\"save_ctrl\",1,1" "OK"
			else
				return 1
			fi
		fi
	else
		return 0
	fi
}

_earfcn2_unisoc(){
	local _ctl="$1"
	local _info="$2"
	local mode="$3"
	local earfcn="$4"
	local pci="$5"
	local cmd_core="common/5g"

	[ "$mode" == "LTE" ] && cmd_core="common/lte"

	_res=$(_command_generic_exec "$_ctl" "QNWLOCK" "=\"$cmd_core\"")
	[ -z "$_res" ] && return 1
	_action=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)

	if [ -z "$pci" -o -z "$earfcn" -o "$earfcn" == "0" ];then
		if [ -n  "$_action" -a "$_action" != "0" ];then
			echo "earfcn mode:$mode free earfcn"
			_command_generic_exec_expect "$_ctl" "QNWLOCK" "=\"$cmd_core\",0" "OK"
		fi
		return 0
	fi

	_earfcn=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)
	_pci=$(echo "$_res"|awk -F, '{print $3}'|xargs -r printf)
	if [ "$_earfcn" != "$earfcn" -o "$_pci" != "$pci" ];then
		echo "earfcn mode:$mode set earfcn:$earfcn pci:$pci"
		[ -n "$earfcn" ] && _command_generic_exec_expect "$_ctl" "QNWLOCK" "=\"$cmd_core\",0" "OK"
		_command_generic_exec_expect "$_ctl" "QNWLOCK" "=\"$cmd_core\",1,$earfcn,$pci" "OK"
	else
		return 0
	fi
}

command_quectel_earfcn2() {
	local _ctl="$1"
	local _info="$2"
	local mode="$3"
	local earfcn="$4"
	local pci="$5"
	local band="$6"

	local cmd_core="common/5g"
	local vendor_class="qualcomm"
	_res=$(command_quectel_model "$1")
	if echo "$_res"|grep -qs "00U";then
		vendor_class="unisoc"
	fi
	echo "$_res vendor_class:$vendor_class"
	if [ "$vendor_class" == "unisoc" ];then
		_earfcn2_unisoc "$_ctl" "$_info" "$mode" "$earfcn" "$pci"
	elif [ "$vendor_class" == "qualcomm" ];then
 		_earfcn2_qualcomm "$_ctl" "$_info" "$mode" "$earfcn" "$pci" "$band"
	else
		return 0
	fi
}

command_quectel_earfcn() {
	local _ctl="$1"
	local _info="$2"
	local mode="$3"
	local earfcn="$4"
	local pci="$5"

	cmd_core="common/4g"
	[ "$mode" == "NR" ] && return 0
	_res=$(_command_generic_exec "$_ctl" "QNWLOCK" "=\"$cmd_core\"")
	[ -z "$_res" ] && return 1
	_action=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)

	if [ -z "$earfcn" -o "$earfcn" == "0" ];then
		if [ -n  "$_action" -a "$_action" != "0" ];then
			echo "earfcn mode:$mode free earfcn"
			_command_generic_exec_expect "$_ctl" "QNWLOCK" "=\"$cmd_core\",0" "OK"
		fi
		return 0
	fi

	_earfcn=$(echo "$_res"|awk -F, '{print $3}'|xargs -r printf)
	_pci=$(echo "$_res"|awk -F, '{print $4}'|xargs -r printf)
	[ -z "$pci" ] && pci=0
	if [ "$_earfcn" != "$earfcn" -o "$_pci" != "$pci" ];then
		echo "earfcn mode:$mode set earfcn:$earfcn pci:$pci"
		[ -n "$earfcn" ] && _command_generic_exec_expect "$_ctl" "QNWLOCK" "=\"$cmd_core\",0" "OK"
		sleep 2
		_command_generic_exec_expect "$_ctl" "QNWLOCK" "=\"$cmd_core\",1,$earfcn,$pci" "OK"
	else
		return 0
	fi
}

_command_quectel_get_qmap_wwan(){
	local _ctl="$1"
	_res=$(_command_generic_exec "$_ctl" "QMAP" "=\"WWAN\"")
	[ -z "$_res" ] && return 1

	v4_line==$(echo "$_res"|sed -n '1p')
	v6_line==$(echo "$_res"|sed -n '2p')

	_pdptype4=$(echo "$v4_line"|awk -F, '{print $4}'|xargs -r printf)
	_ip4=$(echo "$v4_line"|awk -F, '{print $5}'|xargs -r printf)

	_pdptype6=$(echo "$v6_line"|awk -F, '{print $4}'|xargs -r printf)
	_ip6=$(echo "$v6_line"|awk -F, '{print $5}'|xargs -r printf)

	json_init
	json_add_string "IPV4" "$_ip4"
	json_add_string "IPV6" "$_ip6"
	json_dump
	json_cleanup
}
command_quectel_check_qmap_dail2(){
	local _ctl="$1"
	local _info="$(_command_quectel_get_qmap_wwan "$_ctl")"
	local _ip4="$(echo "$_info"|jsonfilter -e "\$['IPV4']")"
	local _ip6="$(echo "$_info"|jsonfilter -e "\$['IPV6']")"

	echo "qmap wwan ip4:$_ip4"
	echo "qmap wwan ip6:$_ip6"

	if [ "$_ip4" != "0.0.0.0" -o "$_ip6" != "0:0:0:0:0:0:0:0" ];then
		return 0
	fi
	return 1
}

command_quectel_analysis2(){
	local _ctl="$1"
	local _info="$2"
	local profile="1"
	[ -f "/tmp/profileid_${gNet}" ] && profileid=$(cat /tmp/profileid_${gNet})
	[ -n "$profileid" ] && profile="$profileid"

	echo $(_command_quectel_get_qmap_wwan "$_ctl")
	echo $(command_quectel_basic2 "$_ctl" "$_info")
	echo $(command_generic_ipaddr "$_ctl" "$profile")
}

command_quectel_analysis(){
	local _ctl="$1"
	local _info="$2"
	local profile="1"
	[ -f "/tmp/profileid_${gNet}" ] && profileid=$(cat /tmp/profileid_${gNet})
	[ -n "$profileid" ] && profile="$profileid"

	echo $(command_quectel_basic "$_ctl" "$_info")
	echo $(command_generic_ipaddr "$_ctl" "$profile")
}

command_quectel_ips(){
	local _ctl="$1"
	local profile="1"
	[ -f "/tmp/profileid_${gNet}" ] && profileid=$(cat /tmp/profileid_${gNet})
	[ -n "$profileid" ] && profile="$profileid"
	echo $(command_generic_ipaddr "$_ctl" "$profile")
}

command_quectel_ips2(){
	command_quectel_ips "$1"
}

command_quectel_earfcn_info() {
	local _ctl="$1"
	local _ctl="$1"
	local cmd_core="common/5g"

	json_init
	json_add_array "earfcn"

	_res=$(_command_generic_exec "$_ctl" "QNWLOCK" "=\"$cmd_core\"")
	[ -n "$_res" ] && {
		_action=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)

		json_add_object
		if [ "$_action" == "0" ];then
			json_add_string "status" "0"
		else
			_earfcn=$(echo "$_res"|awk -F, '{print $3}'|xargs -r printf)
			_pci=$(echo "$_res"|awk -F, '{print $4}'|xargs -r printf)
			json_add_string "status" "1"

			json_add_string "EARFCN" "$_earfcn"
			json_add_string "PCI" "$_pci"
		fi
		json_add_string "MODE" "NR"
		json_close_object
	}
	cmd_core="common/4g"
	_res=$(_command_generic_exec "$_ctl" "QNWLOCK" "=\"$cmd_core\"")
	[ -n "$_res" ] && {
		_action=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)

		json_add_object
		if [ "$_action" == "0" ];then
			json_add_string "status" "0"
		else
			_earfcn=$(echo "$_res"|awk -F, '{print $3}'|xargs -r printf)
			_pci=$(echo "$_res"|awk -F, '{print $4}'|xargs -r printf)
			json_add_string "status" "1"
			json_add_string "EARFCN" "$_earfcn"
			json_add_string "PCI" "$_pci"
		fi
		json_add_string "MODE" "LTE"

		json_close_object
	}

	json_dump
	json_cleanup
}

command_quectel_sms_new2(){
	local _ctl="$1"
	command_generic_sms_new "$_ctl"
}

command_quectel_sms2(){
	local _ctl="$1"
	command_generic_sms "$_ctl"
}

command_quectel_sms_read2(){
	local _ctl="$1"
	local _read_ids="$2"

	command_generic_sms_read "$_ctl" "$_read_ids"
}

command_quectel_sms_del2(){
	local _ctl="$1"
	local _del_ids="$2"

	command_generic_sms_del "$_ctl" "$_del_ids"
}

command_quectel_sms_sendm2(){
	local _ctl="$1"
	local _sendid="$2"
	command_generic_sms_sendm "$_ctl" "$_sendid"
}

command_quectel_sms_send2(){
	local _ctl="$1"
	local _sendmsg_len="$2"
	local _sendmsg="$3"

	command_generic_sms_send "$_ctl" "$_sendmsg_len" "$_sendmsg"
}

command_quectel_earfcn_info2() {
	local _ctl="$1"
	local cmd_core="common/5g"
	local vendor_class="qualcomm"
	_res=$(command_quectel_model "$1")
	if echo "$_res"|grep -qs "00U";then
		vendor_class="unisoc"
	fi

	json_init
	json_add_array "earfcn"

	if [ "$vendor_class" == "unisoc" ];then
		_res=$(_command_generic_exec "$_ctl" "QNWLOCK" "=\"$cmd_core\"")
		[ -n "$_res" ] && {
			_action=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)


			json_add_object
			if [ "$_action" == "0" ];then
				json_add_string "status" "0"
			else
				_earfcn=$(echo "$_res"|awk -F, '{print $3}'|xargs -r printf)
				_pci=$(echo "$_res"|awk -F, '{print $4}'|xargs -r printf)
				json_add_string "status" "1"
				json_add_string "EARFCN" "$_earfcn"
				json_add_string "PCI" "$_pci"
			fi
			json_add_string "MODE" "NR"

			json_close_object
		}
		cmd_core="common/lte"
		_res=$(_command_generic_exec "$_ctl" "QNWLOCK" "=\"$cmd_core\"")
		[ -n "$_res" ] && {
			_action=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)

			json_add_object
			if [ "$_action" == "0" ];then
				json_add_string "status" "0"
			else
				_earfcn=$(echo "$_res"|awk -F, '{print $3}'|xargs -r printf)
				_pci=$(echo "$_res"|awk -F, '{print $4}'|xargs -r printf)
				json_add_string "status" "1"
				json_add_string "EARFCN" "$_earfcn"
				json_add_string "PCI" "$_pci"
			fi
			json_add_string "MODE" "LTE"

			json_close_object
		}
	else
		cmd_core="common/5g"
		_res=$(_command_generic_exec "$_ctl" "QNWLOCK" "=\"$cmd_core\"")
		[ -n "$_res" ] && {
			_action=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)
			json_add_object
			if [ "$_action" == "0" ];then
				json_add_string "status" "0"
			else
				_earfcn=$(echo "$_res"|awk -F, '{print $3}'|xargs -r printf)
				_band=$(echo "$_res"|awk -F, '{print $5}'|xargs -r printf)
				_pci="$_action"
				json_add_string "status" "1"
				json_add_string "BAND" "$_band"
				json_add_string "EARFCN" "$_earfcn"
				json_add_string "PCI" "$_pci"
			fi
			json_add_string "MODE" "NR"
			json_close_object
		}
		cmd_core="common/4g"
		_res=$(_command_generic_exec "$_ctl" "QNWLOCK" "=\"$cmd_core\"")
		[ -n "$_res" ] && {
			_action=$(echo "$_res"|awk -F, '{print $2}'|xargs -r printf)

			json_add_object
			if [ "$_action" == "0" ];then
				json_add_string "status" "0"
			else
				_earfcn=$(echo "$_res"|awk -F, '{print $3}'|xargs -r printf)
				_pci=$(echo "$_res"|awk -F, '{print $4}'|xargs -r printf)
				json_add_string "status" "1"
				json_add_string "EARFCN" "$_earfcn"
				json_add_string "PCI" "$_pci"
			fi
			json_add_string "MODE" "LTE"
			json_close_object
		}
	fi

	json_dump
	json_cleanup
}

_command_quectel_connstat2(){
	local _ctl="$1"
	_res=$(_command_generic_exec "$_ctl" "QMAP" "=\"WWAN\"")
	[ -z "$_res" ] && return 1
	_res=$(echo "$_res"|awk -F: '{print $2}')
	[ -z "$_res" ] && return 1
	line==$(echo "$_res"|sed -n '1p')
	line2==$(echo "$_res"|sed -n '2p')

	_pdptype=$(echo "$line"|awk -F, '{print $4}'|xargs -r printf)
	_stat=$(echo "$line"|awk -F, '{print $2}'|xargs -r printf)

	_pdptype2=$(echo "$line2"|awk -F, '{print $4}'|xargs -r printf)
	_stat2=$(echo "$line2"|awk -F, '{print $2}'|xargs -r printf)

	json_init
	[ -n "$_stat" ] && json_add_string "$_pdptype" "$_stat"
	[ -n "$_stat2" ] && json_add_string "$_pdptype2" "$_stat2"
	json_dump
	json_cleanup
}

_command_quectel_connstatunisoc2(){
	local _ctl="$1"
	_res=$(_command_generic_exec "$_ctl" "QNETDEVSTATUS" "=1")
	[ -z "$_res" ] && return 1
	_res=$(echo "$_res"|awk -F"QNETDEVSTATUS:" '{print $2}')
	[ -z "$_res" ] && return 1

	_ipv4=$(echo "$_res"|awk -F, '{print $1}'|xargs -r printf)
	_gateway=$(echo "$_res"|awk -F, '{print $3}'|xargs -r printf)
	_dns1=$(echo "$_res"|awk -F, '{print $5}'|xargs -r printf)
	_dns2=$(echo "$_res"|awk -F, '{print $6}'|xargs -r printf)
	_ipv6=$(echo "$_res"|awk -F, '{print $7}'|xargs -r printf)
	_dns61=$(echo "$_res"|awk -F, '{print $11}'|xargs -r printf)
	_dns62=$(echo "$_res"|awk -F, '{print $12}'|xargs -r printf)
	json_init
	[ -n "$_ipv4" ] && json_add_string "IPV4" "1"
	[ -n "$_ipv6" ] && json_add_string "IPV6" "1"
	[ -n "$_ipv4" ] && json_add_string "ipaddr" "$_ipv4"
	[ -n "$_gateway" ] && json_add_string "gateway" "$_gateway"
	[ -n "$_dns1" ] && json_add_string "dns1" "$_dns1"
	[ -n "$_dns2" ] && json_add_string "dns2" "$_dns2"
	[ -n "$_ipv6" ] && json_add_string "ip6addr" "$_ipv6"
	[ -n "$_dns61" ] && json_add_string "dns61" "$_dns61"
	[ -n "$_dns62" ] && json_add_string "dns62" "$_dns62"
	json_dump
	json_cleanup
}

command_quectel_connstat2(){
	local _ctl="$1"
	local model_desc=$(uci -q get "network.${gNet}.desc")

	if echo "$model_desc"|grep -qs "00U";then
		_command_quectel_connstatunisoc2 "$1"
	else
		_command_quectel_connstat2 "$1"
	fi
}

_command_quectel_qcainfounisoc2(){
	local _ctl="$1"
	local nr_index=0
	_res=$(_command_generic_exec "$_ctl" "QCAINFO")
	[ -z "$_res" ] && return 1
	_hfreq=$(echo "$_res"|awk -F: '{print $2}')
	[ -z "$_hfreq" ] && return 1

	_cnt=$(echo "$_hfreq"|wc -l)
	json_init
	i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		_line=$(echo "$_hfreq" |sed -n "${i}p")
		nr_buffer=""
		_sysmode="$(echo "$_line"|awk -F, '{print $4}')"
		_mode="$(echo "$_sysmode"|cut -d' ' -f1)"
		band="$(echo "$_sysmode"|cut -d' ' -f2| tr -d 'a-zA-Z')"

		if echo "$_mode"|grep -q "NR";then
			_mode="NR"
		fi

		if [ $nr_index -ge 1 -a "$_mode" == "NR" ];then
			nr_buffer="$nr_index"
		fi

		[ -z "$band" ] && break
		earfcn="$(echo "$_line"|cut -d, -f2)"
		bandwidth="$(echo "$_line"|cut -d, -f3)"
		[ -n "$bandwidth" ] && bandwidth=$((bandwidth*1000))
		json_add_object "${_mode}${nr_buffer}"
		json_add_string "BAND" "$band"
		json_add_int "EARFCN" $earfcn
		json_add_int "DL_BANDWIDTH" "$bandwidth"
		json_close_object

		if [ "$_mode" == "NR" ];then
			nr_index=$((nr_index+1))
		fi

	done
	json_add_int nr_count $nr_index
	json_dump
	json_cleanup

}


_command_quectel_qcainfo2(){
	local _ctl="$1"
	local nr_index=0
	_res=$(_command_generic_exec "$_ctl" "QCAINFO")
	[ -z "$_res" ] && return 1
	_hfreq=$(echo "$_res"|awk -F: '{print $2}')
	[ -z "$_hfreq" ] && return 1

	_cnt=$(echo "$_hfreq"|wc -l)
	json_init
	i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		_line=$(echo "$_hfreq" |sed -n "${i}p")
		nr_buffer=""
		_sysmode="$(echo "$_line"|awk -F, '{print $4}')"
		_mode="$(echo "$_sysmode"|cut -d' ' -f1)"
		band="$(echo "$_sysmode"|cut -d' ' -f3|sed 's/"//g')"

		if echo "$_mode"|grep -q "NR";then
			_mode="NR"
		fi

		if [ $nr_index -ge 1 -a "$_mode" == "NR" ];then
			nr_buffer="$nr_index"
		fi

		[ -z "$band" ] && break
		earfcn="$(echo "$_line"|cut -d, -f2)"
		bandwidth="$(echo "$_line"|cut -d, -f3)"
		[ -n "$bandwidth" ] && bandwidth=$(_command_quectel_dl "$bandwidth")
		json_add_object "${_mode}${nr_buffer}"
		json_add_string "BAND" "$band"
		json_add_int "EARFCN" $earfcn
		json_add_int "DL_BANDWIDTH" "$bandwidth"
		json_close_object

		if [ "$_mode" == "NR" ];then
			nr_index=$((nr_index+1))
		fi

	done
	json_add_int nr_count $nr_index
	json_dump
	json_cleanup

}
command_quectel_qcainfo2(){
	local _ctl="$1"
	local model_desc=$(uci -q get "network.${gNet}.desc")

	if echo "$model_desc"|grep -qs "00U";then
		_command_quectel_qcainfounisoc2 "$1"
	else
		_command_quectel_qcainfo2 "$1"
	fi
}

command_quectel_temp2(){
	local _ctl="$1"
	local _model_temp="0"
	local _key="aoss-0-usr"
	local model_desc=$(uci -q get "network.${gNet}.desc")
	if echo "$model_desc"|grep -qs "00U";then
		_key="soc-thermal"
	fi
	_res=$(_command_generic_exec "$_ctl" "QTEMP" )
	_cnt=$(echo "$_res"|wc -l)
	i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_data="$(echo "$line"|awk -F: '{print $2}')"
			_cur_type="$(echo "$_data"|awk -F, '{print $1}'|sed 's/ //g'|sed 's/"//g')"
			_cur_temp="$(echo "$_data"|awk -F, '{print $2}'|sed 's/"//g'|xargs -r printf)"
			if [ -n "$_cur_temp" -a "$_cur_temp" -gt 0 ];then
				if [ "$_key" == "$_cur_type" ];then
					_model_temp="$_cur_temp"
				fi
			fi
		fi
	done
	echo "$_model_temp"
}

command_quectel_temp(){
	local _ctl="$1"
	_res=$(_command_generic_exec "$_ctl" "QTEMP" )
	[ -z "$_res" ] && return 1
	_res="$(echo "$_res"|awk -F: '{print $2}'|sed 's/"//g'|sed 's/ //g')"
	_cur_type="$(echo "$_res"|awk -F, '{print $1}'|sed 's/"//g')"
	echo "$_cur_type"
}