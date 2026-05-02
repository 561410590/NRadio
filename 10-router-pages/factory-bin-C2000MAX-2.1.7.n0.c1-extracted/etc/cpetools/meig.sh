#!/bin/ash

_command_meig_band_convert() {
	local _band _res
	_band="$1"
	_res="Unknown"
	case "$_band" in
		"120")
			_res="1"
			;;
		"122")
			_res="3"
			;;
		"126")
			_res="7"
			;;
		"157")
			_res="38"
			;;
		"156")
			_res="39"
			;;
		"159")
			_res="40"
			;;
		"160")
			_res="41"
			;;
	esac
	echo "$_res"
}

_command_meig_mode_convert() {
	local _mode _res
	_mode="$1"
	_res="Unknown"
	case "$_mode" in
		"0")
			_res="No Serivce"
			;;
		"1")
			_res="GSM"
			;;
		"2")
			_res="GPRS"
			;;
		"3")
			_res="EDGE"
			;;
		"4")
			_res="WCDMA"
			;;
		"5")
			_res="HSDPA"
			;;
		"6")
			_res="HSUPA"
			;;
		"7")
			_res="HSUPA_HSDPA"
			;;
		"8")
			_res="TD-SCDMA"
			;;
		"9")
			_res="LTE"
			;;
		"10")
			_res="LTE"
			;;
		"11")
			_res="LTE"
			;;
	esac
	echo "$_res"
}

command_meig_signal() {
	local _res _val _isp _mode

	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}SGCELLINFO")
	[ -z "$_res" ] && return 1

	json_init
	_val="$(echo "$_res"|grep "CURR_MODE"|awk -F: '{print $2}'|xargs -r printf)"
	_mode="$(_command_meig_mode_convert "$_val")"
	json_add_object "$_mode"
	json_add_int "RSRP" "$(echo "$_res"|grep "RSRP"|awk -F: '{print $2}'|xargs -r printf)"
	json_add_int "RSRQ" "$(echo "$_res"|grep "RSRQ"|awk -F: '{print $2}'|xargs -r printf)"
	json_add_int "SINR" "$(echo "$_res"|grep "SINR"|awk -F: '{print $2}'|xargs -r printf)"
	if [ "$_mode" != "LTE" ] && [ "$_mode" != "NR" ]; then
		json_add_int "RSSI" "$(echo "$_res"|grep "RSSI"|awk -F: '{print $2}'|xargs -r printf)"
	fi
	json_close_object
	json_dump
	json_cleanup
}

command_meig_signal2() {
	local _res _mode _hcsq

	_cmd="${AT_PRIVATE_PREFIX}CELLINFO=1|${AT_PRIVATE_PREFIX}HCSQ?"
	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1
	_cellinfo="$(echo "$_res"|grep 'CELLINFO:'|awk -F: '{print $2}')"
	_cellinfo="$(_command_meig_cellinfo "$_cellinfo" "$_mode")"
	_hcsq="$(echo "$_res"|grep 'HCSQ:'|awk -F: '{print $2}')"
	_command_meig_hcsq "$_hcsq"	"$_cellinfo"
}

command_meig_cellinfo() {
	local _res _val _isp _mode

	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}SGCELLINFO")
	[ -z "$_res" ] && return 1

	json_init
	json_add_string "LAC" "$(echo "$_res"|grep "LAC_ID"|awk -F: '{print $2}'|xargs -r printf)"
	json_add_string "CELL" "$(echo "$_res"|grep "CELL_ID"|awk -F: '{print $2}'|xargs -r printf)"
	json_add_int "RSRP" "$(echo "$_res"|grep "RSRP"|awk -F: '{print $2}'|xargs -r printf)"
	json_add_int "RSRQ" "$(echo "$_res"|grep "RSRQ"|awk -F: '{print $2}'|xargs -r printf)"
	json_add_int "SINR" "$(echo "$_res"|grep "SINR"|awk -F: '{print $2}'|xargs -r printf)"
	_val="$(echo "$_res"|grep "BAND"|awk -F: '{print $2}'|xargs -r printf)"
	json_add_string "BAND" "$(_command_meig_band_convert "$_val")"
	_val="$(echo "$_res"|grep "CURR_MODE"|awk -F: '{print $2}'|xargs -r printf)"
	_mode="$(_command_meig_mode_convert "$_val")"
	json_add_string "MODE" "$_mode"
	if [ "$_mode" != "LTE" ] && [ "$_mode" != "NR" ]; then
		json_add_int "RSSI" "$(echo "$_res"|grep "RSSI"|awk -F: '{print $2}'|xargs -r printf)"
	fi
	json_add_int "CHANNEL" "$(echo "$_res"|grep "CHANNEL"|awk -F: '{print $2}'|xargs -r printf)"
	_isp="$(echo "$_res"|grep "CGI"|awk -F: '{print $2}'|xargs -r printf)"
	[ -z "$_isp" ] && _isp="$(echo "$_res"|grep "MCC"|awk -F: '{print $2}'|xargs -r printf)$(echo "$_res"|grep "MNC"|awk -F: '{print $2}'|xargs -r printf)"
	json_add_int "ISP" "$_isp"
	json_dump
	json_cleanup
}

command_meig_cellinfo2() {
	local _res _val _mode
	_res=$(_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}CELLINFO=1|${AT_PRIVATE_PREFIX}HCSQ?")
	[ -z "$_res" ] && return 1
	_hcsq="$(echo "$_res"|grep 'HCSQ:'|awk -F: '{print $2}')"
	_hcsq="$(_command_meig_hcsq "$_hcsq")"
	_mode="$(echo "$_hcsq"|jsonfilter -e '$["MODE"]')"
	_cellinfo="$(echo "$_res"|grep 'CELLINFO:'|awk -F: '{print $2}')"
	_command_meig_cellinfo "$_cellinfo" "$_mode"
}

command_meig_basic() {
	local _ctl="$1"
	local _info="$2"
	local _res _val _isp _mode _imei _imsi _iccid _model _revision _cpin
	local _cmd
	local apn="$(command_meig_apn "$_ctl" "$_info"|jsonfilter -e "\$['APN']")"
	_cmd="${AT_GENERIC_PREFIX}SGCELLINFO|${AT_GENERIC_PREFIX}CIMI|${AT_GENERIC_PREFIX}ICCID"
	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1

	_imsi="$(echo "$_res"|grep 'CIMI' -A2|sed -n '2p'|xargs -r printf)"
	_iccid="$(echo "$_res"|grep 'ICCID:'|awk -F' ' '{print $2}')"

	_imei="$(uci -q get "cellular_init.$gNet.imei")"
	_model="$(uci -q get "cellular_init.$gNet.model")"
	_revision="$(uci -q get "cellular_init.$gNet.version")"

	_cpin="$(command_generic_cpin "$_ctl")"
	json_init
	json_add_string "LAC" "$(echo "$_res"|grep "LAC_ID"|awk -F: '{print $2}'|xargs -r printf)"
	json_add_string "CELL" "$(echo "$_res"|grep "CELL_ID"|awk -F: '{print $2}'|xargs -r printf)"
	_val="$(echo "$_res"|grep "BAND"|awk -F: '{print $2}'|xargs -r printf)"
	json_add_string "BAND" "$(_command_meig_band_convert "$_val")"
	_val="$(echo "$_res"|grep "CURR_MODE"|awk -F: '{print $2}'|xargs -r printf)"
	_mode="$(_command_meig_mode_convert "$_val")"
	json_add_string "MODE" "$_mode"
	json_add_int "CHANNEL" "$(echo "$_res"|grep "CHANNEL"|awk -F: '{print $2}'|xargs -r printf)"
	_isp="$(echo "$_res"|grep "CGI"|awk -F: '{print $2}'|xargs -r printf)"
	[ -z "$_isp" ] && _isp="$(echo "$_res"|grep "MCC"|awk -F: '{print $2}'|xargs -r printf)$(echo "$_res"|grep "MNC"|awk -F: '{print $2}'|xargs -r printf)"
	json_add_int "ISP" "$(echo "$_isp"|awk '$1= $1')"
	json_add_int "RSRP" "$(echo "$_res"|grep "RSRP"|awk -F: '{print $2}'|xargs -r printf)"
	json_add_int "RSRQ" "$(echo "$_res"|grep "RSRQ"|awk -F: '{print $2}'|xargs -r printf)"
	json_add_int "SINR" "$(echo "$_res"|grep "SINR"|awk -F: '{print $2}'|xargs -r printf)"
	if [ "$_mode" != "LTE" ] && [ "$_mode" != "NR" ]; then
		json_add_int "RSSI" "$(echo "$_res"|grep "RSSI"|awk -F: '{print $2}'|xargs -r printf)"
	fi
	json_add_string "IMEI" "$(generic_validate_imei "$_imei")"
	json_add_string "IMSI" "$(generic_validate_imsi "$_imsi")"
	json_add_string "ICCID" "$(generic_validate_iccid "$_iccid")"
	json_add_string "MODEL" "$_model"
	json_add_string "REVISION" "$_revision"
	json_add_string "SIMNUMBER" "$(command_generic_number "$1")"
	json_add_string "APN" "$apn"
	json_add_string "CPIN" "$_cpin"
	json_dump
	json_cleanup
}

_command_meig_nr_rsrp_convert() {
	local _val
	_val="$1"
	[ "$_val" -eq 255 ] && echo -n "255" && return
	[ "$_val" -ge 126 ] && echo -n "-31" && return
	[ "$_val" -eq 0 ] && echo -n "-156" && return
	echo "$_val"|awk '{print -31-(126-$1)}'
}

_command_meig_nr_rsrq_convert() {
	local _val
	_val="$1"
	[ "$_val" -eq 255 ] && echo -n "255" && return
	[ "$_val" -ge 127 ] && echo -n "20" && return
	[ "$_val" -eq 0 ] && echo -n "-43" && return
	echo "$_val"|awk '{print 20-(127-$1)*0.5}'
}

_command_meig_nr_sinr_convert() {
	local _val
	_val="$1"
	[ "$_val" -eq 255 ] && echo -n "255" && return
	[ "$_val" -ge 127 ] && echo -n "40" && return
	[ "$_val" -eq 0 ] && echo -n "-23" && return
	echo "$_val"|awk '{print 40-(127-$1)*0.5}'
}


_command_meig_hcsq() {
	local _hcsq _val
	_hcsq="$1"
	_cellinfo="$2"
	json_init
	for _line in $_hcsq; do
		_mode="$(echo "$_line"|cut -d, -f3|sed 's/\"//g')"
		if [ "$_mode" = "GSM" ]; then
			json_add_object "$_mode"
			_val="$(echo "$_line"|cut -d, -f4)"
			json_add_int "RSSI" "$(_command_huawei_rssi_convert "$_val")"
		elif [ "$_mode" = "WCDMA" ]; then
			json_add_object "$_mode"
			_val="$(echo "$_line"|cut -d, -f4)"
			json_add_int "RSSI" "$(_command_huawei_rssi_convert "$_val")"
			_val="$(echo "$_line"|cut -d, -f6)"
			json_add_int "RSCP" "$(_command_huawei_rscp_convert "$_val")"
			_val="$(echo "$_line"|cut -d, -f5)"
			json_add_int "ECIO" "$(_command_huawei_ecio_convert "$_val")"
		elif [ "$_mode" = "LTE" ]; then
			json_add_object "$_mode"
			_val="$(echo "$_line"|cut -d, -f4)"
			json_add_int "RSSI" "$(_command_huawei_rssi_convert "$_val")"
			_val="$(echo "$_line"|cut -d, -f6)"
			json_add_int "RSRP" "$(_command_huawei_rsrp_convert "$_val")"
			_val="$(echo "$_line"|cut -d, -f7)"
			json_add_int "SINR" "$(_command_huawei_sinr_convert "$_val")"
			_val="$(echo "$_line"|cut -d, -f5)"
			json_add_int "RSRQ" "$(_command_huawei_rsrq_convert "$_val")"
			if [ -n "$_cellinfo" ];then
				json_add_string "CELL" "$(echo "$_cellinfo"|jsonfilter -e '$["CELL"]')"
				json_add_string "PCI" "$(echo "$_cellinfo"|jsonfilter -e '$["PCI"]')"
				json_add_string "TAC" "$(echo "$_cellinfo"|jsonfilter -e '$["TAC"]')"
				json_add_string "EARFCN" "$(echo "$_cellinfo"|jsonfilter -e '$["EARFCN"]')"
				json_add_string "BAND" "$(echo "$_cellinfo"|jsonfilter -e "$['BAND']")"
			fi
		elif [ "$_mode" = "NR5G" ]; then
			_val="$(echo "$_line"|cut -d, -f8)"
			if [ "$_val" ];then
				if [ "$_val" == "-" ];then
					_mode="LTE"
					json_add_object "$_mode"
					_val="$(echo "$_line"|cut -d, -f4)"
					json_add_int "RSSI" "$(_command_huawei_rssi_convert "$_val")"
					_val="$(echo "$_line"|cut -d, -f6)"
					json_add_int "RSRP" "$(_command_huawei_rsrp_convert "$_val")"
					_val="$(echo "$_line"|cut -d, -f7)"
					json_add_int "SINR" "$(_command_huawei_sinr_convert "$_val")"
					_val="$(echo "$_line"|cut -d, -f5)"
					json_add_int "RSRQ" "$(_command_huawei_rsrq_convert "$_val")"
				else
					_mode="NR NSA"
					json_add_object "$_mode"
					json_add_int "RSRQ" "$(_command_meig_nr_rsrq_convert "$_val")"
					_val="$(echo "$_line"|cut -d, -f9)"
					json_add_int "RSRP" "$(_command_meig_nr_rsrp_convert "$_val")"
					_val="$(echo "$_line"|cut -d, -f10)"
					json_add_int "SINR" "$(_command_meig_nr_sinr_convert "$_val")"
				fi
			else
				_mode="NR SA"
				json_add_object "$_mode"
				_val="$(echo "$_line"|cut -d, -f5)"
				json_add_int "RSRP" "$(_command_meig_nr_rsrp_convert "$_val")"
				_val="$(echo "$_line"|cut -d, -f6)"
				json_add_int "SINR" "$(_command_meig_nr_sinr_convert "$_val")"
				_val="$(echo "$_line"|cut -d, -f4)"
				json_add_int "RSRQ" "$(_command_meig_nr_rsrq_convert "$_val")"
			fi
			if [ -n "$_cellinfo" ];then
				json_add_string "CELL" "$(echo "$_cellinfo"|jsonfilter -e '$["CELL"]')"
				json_add_string "PCI" "$(echo "$_cellinfo"|jsonfilter -e '$["PCI"]')"
				json_add_string "TAC" "$(echo "$_cellinfo"|jsonfilter -e '$["TAC"]')"
				json_add_string "EARFCN" "$(echo "$_cellinfo"|jsonfilter -e '$["EARFCN"]')"
				json_add_string "BAND" "$(echo "$_cellinfo"|jsonfilter -e "$['BAND']")"
			fi
		else
			continue
		fi
		json_close_object
	done
	json_add_string "MODE" "$_mode"
	json_dump
	json_cleanup
}


_command_meig_cellinfo() {
	local _cellinfo
	_cellinfo="$1"
	_mode_out="$2"
	echo "$_cellinfo"|grep -qs "NO SERVICE" && return
	json_init
	_mode="$(echo "$_cellinfo"|cut -d, -f2)"
	[ -n "$_mode_out" ] && _mode="$_mode_out"
	_isp="$(echo "$_cellinfo"|cut -d, -f3)$(echo "$_cellinfo"|cut -d, -f4)"
	json_add_string "ISP" "$_isp"
	json_add_string "MODE" "$_mode"
	if echo "$_mode" |grep -q "LTE"; then
		cell="$(echo "$_cellinfo"|cut -d, -f8)"
		tac="$(echo "$_cellinfo"|cut -d, -f9)"
		[ -n "$cell" ] && cell=$(printf %x $cell)
		[ -n "$tac" ] && tac=$(printf %x $tac)
		json_add_string "CELL" "$cell"
		json_add_int "EARFCN" "$(echo "$_cellinfo"|cut -d, -f12)"
		json_add_string "PCI" "$(echo "$_cellinfo"|cut -d, -f6)"
		json_add_string "TAC" "$tac"
		json_add_int "BAND" "$(echo "$_cellinfo"|cut -d, -f10)"
	elif [ "$_mode" = "WCDMA" ]; then
		json_add_string "CELL" "$(echo "$_cellinfo"|cut -d, -f7)"
		json_add_string "LAC" "$(echo "$_cellinfo"|cut -d, -f8)"
		json_add_int "BAND" "$(echo "$_cellinfo"|cut -d, -f9)"
		json_add_int "EARFCN" "$(echo "$_cellinfo"|cut -d, -f10)"
	elif [ "$_mode" = "NR SA" ] || echo "$_mode" |grep -q "NR5G"; then
		cell="$(echo "$_cellinfo"|cut -d, -f5)"
		tac="$(echo "$_cellinfo"|cut -d, -f7)"
		dlbw="$(echo "$_cellinfo"|cut -d, -f9)"
		[ -n "$dlbw" ] && dlbw=$((dlbw*1000))
		[ -n "$cell" ] && cell=$(printf %x $cell)
		[ -n "$tac" ] && tac=$(printf %x $tac)
		json_add_int "EARFCN" "$(echo "$_cellinfo"|cut -d, -f12)"
		json_add_int "BAND" "$(echo "$_cellinfo"|cut -d, -f8)"
		json_add_string "DLBW" "$dlbw"
		json_add_string "CELL" "$cell"
		json_add_string "PCI" "$(echo "$_cellinfo"|cut -d, -f6)"
		json_add_string "TAC" "$tac"
	elif [ "$_mode" = "NR NSA" ]; then
		cell="$(echo "$_cellinfo"|cut -d, -f8)"
		tac="$(echo "$_cellinfo"|cut -d, -f9)"
		[ -n "$cell" ] && cell=$(printf %x $cell)
		[ -n "$tac" ] && tac=$(printf %x $tac)
		json_add_int "EARFCN" "$(echo "$_cellinfo"|cut -d, -f12)"
		json_add_int "BAND" "$(echo "$_cellinfo"|cut -d, -f10)"
		json_add_string "CELL" "$cell"
		json_add_string "PCI" "$(echo "$_cellinfo"|cut -d, -f6)"
		json_add_string "TAC" "$tac"
	fi
	json_dump
	json_cleanup
}

command_meig_basic2() {
	local _ctl="$1"
	local _info="$2"
	local _res _imei _imsi _iccid _hcsq _mode _model _revision
	local _cmd
	local nr5g_ambr_dl=""
	local nr5g_ambr_ul=""
	local qci=""

	local apn="$(command_meig_apn "$_ctl" "$_info"|jsonfilter -e "\$['APN']")"
	_cmd="${AT_PRIVATE_PREFIX}CELLINFO=1|${AT_PRIVATE_PREFIX}HCSQ?|${AT_GENERIC_PREFIX}CIMI|${AT_GENERIC_PREFIX}ICCID"
	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1

	_cellinfo="$(echo "$_res"|grep 'CELLINFO:'|awk -F: '{print $2}')"
	_hcsq="$(echo "$_res"|grep 'HCSQ:'|awk -F: '{print $2}')"
	_imsi="$(echo "$_res"|grep 'CIMI' -A2|sed -n '2p'|xargs -r printf)"	

	_imei="$(uci -q get "cellular_init.$gNet.imei")"
	_model="$(uci -q get "cellular_init.$gNet.model")"
	_revision="$(uci -q get "cellular_init.$gNet.version")"

	_iccid="$(echo "$_res"|grep 'ICCID:'|awk -F' ' '{print $2}')"
	_hcsq="$(_command_meig_hcsq "$_hcsq")"
	_mode="$(echo "$_hcsq"|jsonfilter -e '$["MODE"]')"
	_cellinfo="$(_command_meig_cellinfo "$_cellinfo" "$_mode")"
	_res=$(_command_generic_exec "$1" "CGEQOSRDP" "=1")
	if [ -n "$_res" ];then
		qci=$(echo "$_res"|awk -F',' '{print $2}'|xargs -r printf|sed -e 's/ //g')
		nr5g_ambr_dl=$(echo "$_res"|awk -F',' '{print $7}'|xargs -r printf|sed -e 's/ //g')
		nr5g_ambr_ul=$(echo "$_res"|awk -F',' '{print $8}'|xargs -r printf|sed -e 's/ //g')
	fi
	_temp="$(command_meig_temp2 "$_ctl")"
	json_init
	if [ -n "$_temp" ];then
		json_add_string "MODEL_TEMP" "$_temp"
	fi
	json_add_string "ISP" "$(echo "$_cellinfo"|jsonfilter -e '$["ISP"]'|awk '$1= $1')"
	json_add_string "CELL" "$(echo "$_cellinfo"|jsonfilter -e '$["CELL"]')"
	json_add_string "PCI" "$(echo "$_cellinfo"|jsonfilter -e '$["PCI"]')"
	json_add_string "TAC" "$(echo "$_cellinfo"|jsonfilter -e '$["TAC"]')"
	json_add_string "EARFCN" "$(echo "$_cellinfo"|jsonfilter -e '$["EARFCN"]')"
	json_add_string "MODE" "$_mode"
	json_add_string "BAND" "$(echo "$_cellinfo"|jsonfilter -e "$['BAND']")"
	json_add_string "DLBW" "$(echo "$_cellinfo"|jsonfilter -e "$['DLBW']")"
	json_add_string "RSRP" "$(echo "$_hcsq"|jsonfilter -e "\$['$_mode']['RSRP']")"
	json_add_string "SINR" "$(echo "$_hcsq"|jsonfilter -e "\$['$_mode']['SINR']")"
	json_add_string "RSRQ" "$(echo "$_hcsq"|jsonfilter -e "\$['$_mode']['RSRQ']")"
	json_add_string "RSSI" "$(echo "$_hcsq"|jsonfilter -e "\$['$_mode']['RSSI']")"
	json_add_string "RSCP" "$(echo "$_hcsq"|jsonfilter -e "\$['$_mode']['RSCP']")"
	json_add_string "IMEI" "$(generic_validate_imei "$_imei")"
	json_add_string "IMSI" "$(generic_validate_imsi "$_imsi")"
	json_add_string "ICCID" "$(generic_validate_iccid "$_iccid")"
	json_add_string "MODEL" "$_model"
	json_add_string "REVISION" "$_revision"
	json_add_string "SIMNUMBER" "$(command_generic_number "$1")"
	json_add_string "APN" "$apn"
	json_add_string "CQI" "$qci"
	json_add_string "NR5G_AMBR_DL" "$nr5g_ambr_dl"
	json_add_string "NR5G_AMBR_UL" "$nr5g_ambr_ul"
	json_dump
	json_cleanup
}

command_meig_iccid2() {
	local _res _info

	_res=$(_command_generic_exec "$1" "ICCID")
	[ -z "$_res" ] && return 1

	_info="$(echo "$_res"|awk -F' ' '{print $2}')"

	echo "$_info"
}

_command_meig_syscfgex_get() {
	local _res _info

	_res=$(_command_private_exec "$1" "SYSCFGEX" "?")
	[ -z "$_res" ] && return 1

	_info=$(echo "$_res"|awk -F: '{print $2}')
	json_init
	json_add_string "ACQORDER" "$(echo "$_info"|awk -F, '{print $1}'|awk '$1= $1')"
	json_add_string "BAND" "$(echo "$_info"|awk -F, '{print $2}')"
	json_add_string "ROAM" "$(echo "$_info"|awk -F, '{print $3}')"
	json_add_string "SRVDOMAIN" "$(echo "$_info"|awk -F, '{print $4}')"
	json_add_string "LTEBAND" "$(echo "$_info"|awk -F, '{print $5}'|xargs -r printf)"
	json_add_string "LTEBANDH" "$(echo "$_info"|awk -F, '{print $6}'|xargs -r printf)"
	json_add_string "NRBAND" "$(echo "$_info"|awk -F, '{print $7}'|xargs -r printf)"
	json_add_string "NRBANDH" "$(echo "$_info"|awk -F, '{print $8}'|xargs -r printf)"
	json_add_string "DURATION" "$(echo "$_info"|awk -F, '{print $9}'|xargs -r printf)"
	json_dump
	json_cleanup
}

_command_meig_syscfgex_set() {
	local _ctl="$1"
	local _syscfgex="$2"
	local _key="$3"
	local _val="$4"
	local _param _tmp
	local _keys="ACQORDER BAND ROAM SRVDOMAIN LTEBAND LTEBANDH NRBAND NRBANDH DURATION"

	json_load "${_syscfgex:-{}}"
	json_add_string "$_key" "$_val"
	for _key in $_keys; do
		json_get_var _tmp "$_key"
		if [ "$_key" = "ACQORDER" ];then
			_param="$_param$_tmp"
		else
			_param="$_param,$_tmp"
		fi
	done
	json_cleanup
	_command_private_generic_exec "$_ctl" "SYSCFGEX=" "$_param"
}

_command_meig_mode() {
	local _ctl="$1"
	local _val="$2"
	local _nrcap="$3"
	local _syscfg
	local _acqorder
	local max=3
	local i=0

	if [ "$_nrcap" = "1" ];then
		while true;do
			_syscfg=$(_command_meig_syscfgex_get "$_ctl")
			_acqorder=$(echo "$_syscfg"|jsonfilter -e '$["ACQORDER"]')
			echo  "get acqorder:$_acqorder"
			[ -z "$_acqorder" ] && return 1

			if [ "$_acqorder" = "\"$_val\"" ]; then
				if [ $i -gt 0 ];then
					return 0
				else
					return 2
				fi
			fi
			echo "do set syscfg $_val,$i"
			_command_huawei_syscfgex_set_acqorder "$_ctl" "\"$_val\""
			i=$((i+1))
			if [ $i -ge $max ];then
				echo  "set syscfg error"
				return 1
			fi
			sleep 1
		done
	else
		_syscfg=$(_command_meig_syscfgex_get "$_ctl")
		_acqorder=$(echo "$_syscfg"|jsonfilter -e '$["ACQORDER"]')
		[ -z "$_acqorder" ] && return 1
		if [ "$_acqorder" = "\"$_val\"" ]; then
			return 2
		fi
		_command_meig_syscfgex_set "$_ctl" "$_syscfg" "ACQORDER" "\"$_val\""
	fi

	return 0
}

command_meig_nroff2() {
	_command_meig_mode "$1" "03"
	if [ $? -eq 0 ];then
		echo  "syscfg change cfun"
		command_generic_reset "$1"
	fi
}

command_meig_modewcdma2() {
	_command_meig_mode "$1" "02"
}

_command_meig_nwcfg_nr() {
	local _ctl="$1"
	local _val="$2"
	local _option
	local _res

	_res=$(_command_private_exec "$_ctl" "NWCFG" "=\"nr5g_disable_mode\"")
	[ -z "$_res" ] && return 1

	_option=$(echo "$_res"|awk -F',' '{print $2}'|xargs -r printf)
	echo  "get nr5g_disable_mode :$_option"
	if [ "$_option" = "$_val" ]; then
		return 2
	fi

	echo "do set nr5g_disable_mode $_val"
	_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NWCFG=\"nr5g_disable_mode\",$_val"

	return 0
}

command_meig_allmode2() {
	local _info="$2"
	local _nrcap

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')

	_command_meig_mode "$1" "00" "$_nrcap"
	if [ "$_nrcap" = "1" ]; then
		_command_meig_nwcfg_nr "$1" "0"
		if [ $? -eq 0 ];then
			command_generic_reset "$_ctl"
		fi
	fi
}

command_meig_modesa2() {
	local _info="$2"
	local _nrcap

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')

	_command_meig_mode "$1" "00" "$_nrcap"
	if [ "$_nrcap" = "1" ]; then
		_command_meig_nwcfg_nr "$1" "2"
		if [ $? -eq 0 ];then
			command_generic_reset "$_ctl"
		fi
	fi
}

command_meig_modensa2() {
	local _info="$2"
	local _nrcap

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')

	_command_meig_mode "$1" "00" "$_nrcap"
	if [ "$_nrcap" = "1" ]; then
		_command_meig_nwcfg_nr "$1" "1"
		if [ $? -eq 0 ];then
			command_generic_reset "$_ctl"
		fi
	fi
}

command_meig_modesa_only2() {
	local _info="$2"
	local _nrcap

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')
	if [ "$_nrcap" = "1" ]; then
		_command_meig_nwcfg_nr "$1" "2"
	fi
	_command_meig_mode "$1" "04" "$_nrcap"
	if [ $? -eq 0 ];then
		echo  "syscfg change cfun"
		command_generic_reset "$_ctl"
	fi
}

command_meig_modensa_only2() {
	local _info="$2"
	local _nrcap

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')
	if [ "$_nrcap" = "1" ]; then
		_command_meig_nwcfg_nr "$1" "1"
	fi
	_command_meig_mode "$1" "04" "$_nrcap"
	if [ $? -eq 0 ];then
		echo  "syscfg change cfun"
		command_generic_reset "$_ctl"
	fi
}

_command_meig_roam() {
	_val=$2
	_syscfg=$(_command_meig_syscfgex_get "$_ctl")
	_roam=$(echo "$_syscfg"|jsonfilter -e '$["ROAM"]')
	[ -z "$_roam" ] && return 1

	if [ "$_roam" = "$_val" ]; then
		return 0
	fi
	echo "set roam"
	_command_meig_syscfgex_set "$_ctl" "$_syscfg" "ROAM" "$_val"
}

command_meig_roam2() {
	if [ "$2" = "0" ];then
		_command_meig_roam "$1" "3"
	else
		_command_meig_roam "$1" "0"
	fi
}

command_meig_model2() {
	command_huawei_model "$@"
}

command_meig_sn(){
	local _ctl="$1"

	_res=$(_command_generic_exec "$_ctl" "LCTSN" "=0,5")
	[ -z "$_res" ] && echo ""

	echo "$_res" | cut -d':' -f2|sed 's/\"//g'|xargs -r printf
}

command_meig_sn2(){
	command_meig_sn "$@"
}

_command_meig_syscfgex_set_freq() {
	local _ctl="$1"
	local _syscfgex="$2"
	local _lte="$3"
	local _lteh="$4"
	local _nr="$5"
	local _nrh="$6"	
	local _param _tmp
	local _keys="ACQORDER BAND ROAM SRVDOMAIN LTEBAND LTEBANDH NRBAND NRBANDH DURATION"

	json_load "${_syscfgex:-{}}"
	for _key in $_keys; do
		json_get_var _tmp "$_key"
		if [ "$_key" = "ACQORDER" ];then
			_param="$_param$_tmp"
		elif [ "$_key" = "LTEBAND" ];then
			_param="$_param,$_lte"
		elif [ "$_key" = "LTEBANDH" ];then
			_param="$_param,$_lteh"
		elif [ "$_key" = "NRBAND" ];then
			_param="$_param,$_nr"
		elif [ "$_key" = "NRBANDH" ];then
			_param="$_param,$_nrh"
		else
			_param="$_param,$_tmp"
		fi
	done
	json_cleanup
	_command_private_generic_exec "$_ctl" "SYSCFGEX=" "$_param"
}

_command_meig_freq_set() {
	local _ctl="$1"
	local _lte_info="$2"
	local _nr_info="$3"
	local _syscfg
	local model_desc=$(uci -q get "network.${gNet}.desc")
	lte_info=$(_command_meig_caculate_freq "$_lte_info")
	nr_info=$(_command_meig_caculate_freq "$_nr_info")
	_syscfg=$(_command_meig_syscfgex_get "$_ctl")
	[ -z "$_syscfg" ] && return 1
	_lteband=$(echo "$_syscfg"|jsonfilter -e '$["LTEBAND"]')
	_ltehband=$(echo "$_syscfg"|jsonfilter -e '$["LTEBANDH"]')
	_nrband=$(echo "$_syscfg"|jsonfilter -e '$["NRBAND"]')
	_nrhband=$(echo "$_syscfg"|jsonfilter -e '$["NRBANDH"]')

	if [ "$_lteband $_ltehband" = "$lte_info" -a "$nr_info" = "$_nrband $_nrhband" ]; then
		return 0
	fi

	echo "do set syscfg lte:$lte_info,nr:$nr_info"

	_lte=$(echo "$lte_info"|awk -F' ' '{print $1}')
	_lteh=$(echo "$lte_info"|awk -F' ' '{print $2}')
	_nr=$(echo "$nr_info"|awk -F' ' '{print $1}')
	_nrh=$(echo "$nr_info"|awk -F' ' '{print $2}')
	_command_meig_syscfgex_set_freq "$_ctl" "$_syscfg" "$_lte" "$_lteh" "$_nr" "$_nrh"

	if ! echo "$model_desc"|grep -qs "MeiG" ;then
		command_generic_reset "$1"
	fi
	return 0
}

_command_meig_caculate_freq(){	
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

command_meig_freq2() {
	local _ctl="$1"
	local freq="$2"
	local _freq=""
	local _key=""
	local _set=0
	local _lte=""
	local _nr=""
	local _freqcfg _lteband _ltehband _nrband _nrhband lte_info nr_info

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
		if [ "$label" = "nr" ];then
			_nr="$freq_data"
		elif [ "$label" = "lte" ];then
			_lte="$freq_data"
		fi
	done
	if [ -n "$_lte" -a -n "$_nr" ];then
		_command_meig_freq_set "$_ctl" "$_lte" "$_nr"
	fi
	return 0
}

_command_meig_sim_slot2() {
	local _ctl="$1"
	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}MGCFGEX=\"sim_slot_cfg\""|grep "+MGCFGEX:")
	[ -z "$_res" ] && return 2
	_cnt=$(echo "$_res"|wc -l)
	i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_data="$(echo "$line"|awk -F: '{print $2}')"
			_cur_id="$(echo "$_data"|awk -F, '{print $2}')"
			_cur_enable="$(echo "$_data"|awk -F, '{print $3}')"
			if [ "$_cur_id" == "2" ];then
				if [ "$_cur_enable" == "1" ];then
					echo "sim_slot_cfg support sim2"
					return 0
				fi
				break
			fi
		fi
	done
	echo "sim_slot_cfg not support sim2"
	return 1
}

_command_meig_sim_slot_set2() {
	local _ctl="$1"
	_command_generic_exec_expect "$_ctl" "MGCFGEX" "=\"sim_slot_cfg\",2,1" "OK"
}

command_meig_usim_get2() {
	local _res
	local _ctl="$1"
	_res=$(_command_private_exec "$_ctl" "SIMSLOT" "?")
	[ -z "$_res" ] && echo "none"

	local data=$(echo "$_res" | cut -d',' -f2)
	if [ "$data" == "1" ];then
		echo "1"
	else
		echo "2"
	fi
}

command_meig_usim_set2() {
	local _ctl="$1"
	local _new="$2"
	local _old _res

	_command_meig_sim_slot2 "$_ctl"
	if [ "$?" == "1" ];then		
		_command_meig_sim_slot_set2 "$_ctl"
		#_command_generic_exec "$1" "reset"
		cpetools.sh -i "${gNet}" -r
		return 1
	fi
	_old=$(command_meig_usim_get2 "$_ctl"|xargs -r printf)

	[ "$_old" = "none" ] && return 1

	if [ "$_new" == "1" -a "$_old" == "1" ];then
		return 0
	fi

	_res=$(_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}SIMSLOT=${_new}" "5"|grep "OK")

	[ -z "$_res" ] && return 1

	command_generic_reset "$_ctl"
	return 0
}

_command_meig_freq_get() {
	local _res
	local mode="$2"
	local _enable="0"
	local _mode=""
	local _type=""
	local _earfcn=""
	local _pci=""
	local _scs=""
	local _band=""

	_res=$(_command_private_exec "$1" "CELLLOCK" "?"|grep "\^CELLLOCK:")
	[ -z "$_res" ] && return 1
	_cnt=$(echo "$_res"|wc -l)
	i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_data="$(echo "$line"|awk -F: '{print $2}')"

			_enable_tmp="$(echo "$_data"|awk -F, '{print $1}'|sed 's/ //g'|xargs -r printf)"
			_mode_tmp="$(echo "$_data"|awk -F, '{print $2}'|sed 's/"//g')"
			_type_tmp="$(echo "$_data"|awk -F, '{print $3}')"
			_earfcn_tmp="$(echo "$_data"|awk -F, '{print $4}'|xargs -r printf)"
			_pci_tmp="$(echo "$_data"|awk -F, '{print $5}'|xargs -r printf)"
			_scs_tmp="$(echo "$_data"|awk -F, '{print $6}'|xargs -r printf)"
			_band_tmp="$(echo "$_data"|awk -F, '{print $7}'|xargs -r printf)"

			if [ "$mode" == "NR" -a "$_mode_tmp" == "4" ] || [ "$mode" == "LTE" -a "$_mode_tmp" == "3" ] ;then
				_enable=$_enable_tmp
				_scs=$_scs_tmp
				_band=$_band_tmp
				_earfcn=$_earfcn_tmp
				_pci=$_pci_tmp
				_type=$_type_tmp

				break
			fi
		fi
	done

	json_init
	json_add_string "enable" "$_enable"
	json_add_string "type" "$_type"
	json_add_string "scstype" "$_scs"
	json_add_string "band" "$_band"
	json_add_string "arfcn" "$_earfcn"
	json_add_string "cellid" "$_pci"
	json_dump
	json_cleanup
}

_earfcn_meig_5glock(){
	local _freqcfg _enable _band
	local _ctl="$1"
	local _info="$2"
	local earfcn="$3"
	local pci="$4"
	local band="$5"
	local scs=

	_freqcfg=$(_command_meig_freq_get "$_ctl" "NR")
	[ -z "$_freqcfg" ] && return 1
	_enable=$(echo "$_freqcfg"|jsonfilter -e '$["enable"]')

	if [ -z "$earfcn" -o "$earfcn" == "0" ];then
		if [ "$_enable" != "0" ];then
			echo "earfcn5 nr free"
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}CELLLOCK=0,4" 2
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

	_type=$(echo "$_freqcfg"|jsonfilter -e '$["type"]')
	if [ -z "$pci" ];then
		if [ "$_enable" == "1" ];then
			_scs=$(echo "$_freqcfg"|jsonfilter -e '$["scstype"]')
			_earfcn=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')
			if [ "$_type" == "0" ];then
				if [ "$earfcn" == "$_earfcn" -a "$scs" == "$_scs" ];then
					return 0
				fi
			fi	
		fi
		echo "earfcn5 set nr earfcn:$earfcn,old_earfcn:$_earfcn|scs:$scs,old_scs:$_scs"
		[ "$_enable" != "0" ] && _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}CELLLOCK=0,4" 2
		command_generic_cfun_c
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}CELLLOCK=1,4,0,$earfcn,,$scs" 2		
		command_generic_cfun_o
	else
		if [ "$_enable" == "1" ];then
			_band=$(echo "$_freqcfg"|jsonfilter -e '$["band"]')
			_earfcn=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')
			_pci=$(echo "$_freqcfg"|jsonfilter -e '$["cellid"]')
			if [ "$_type" == "1" ];then
				if [ "$earfcn" == "$_earfcn" -a "$band" == "$_band" -a "$pci" == "$_pci" ];then
					return 0
				fi
			fi
		fi
		echo "earfcn5 set nr earfcn:$earfcn,old_earfcn:$_earfcn|band:$band,old_band:$_band|pci:$pci,old_pci:$_pci"
		
		[ "$_enable" != "0" ] && _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}CELLLOCK=0,4" 2

		command_generic_cfun_c
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}CELLLOCK=1,4,1,$earfcn,$pci,$scs,$band" 2
		command_generic_cfun_o
	fi
}

_earfcn_meig_5g_4glock(){
	local _freqcfg _enable _band
	local _ctl="$1"
	local _info="$2"
	local earfcn="$3"
	local pci="$4"

	_freqcfg=$(_command_meig_freq_get "$_ctl" "LTE")
	[ -z "$_freqcfg" ] && return 1
	_enable=$(echo "$_freqcfg"|jsonfilter -e '$["enable"]')

	if [ -z "$earfcn" -o "$earfcn" == "0" ];then
		if [ "$_enable" != "0" ];then
			echo "earfcn5 lte free"
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}CELLLOCK=0,3" 2
		fi
		return 0
	fi
	_type=$(echo "$_freqcfg"|jsonfilter -e '$["type"]')
	if [ -z "$pci" ];then
		if [ "$_enable" == "1" ];then
			_earfcn=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')
			if [ "$_type" == "0" ];then				
				if [ "$earfcn" == "$_earfcn" ];then
					return 0
				fi
			fi	
		fi
		echo "earfcn5 set lte earfcn:$earfcn,old_earfcn:$_earfcn"
		[ "$_enable" != "0" ] && _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}CELLLOCK=0,3" 2
		command_generic_cfun_c
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}CELLLOCK=1,3,0,$earfcn" 2		
		command_generic_cfun_o
	else
		if [ "$_enable" == "1" ];then
			_earfcn=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')
			if [ "$_type" == "1" ];then				
				_pci=$(echo "$_freqcfg"|jsonfilter -e '$["cellid"]')

				if [ "$earfcn" == "$_earfcn" -a "$pci" == "$_pci" ];then
					return 0
				fi
			fi
		fi
		echo "earfcn5 set lte earfcn:$earfcn,old_earfcn:$_earfcn|pci:$pci,old_pci:$_pci"
		
		[ "$_enable" != "0" ] && _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}CELLLOCK=0,3" 2
		command_generic_cfun_c
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}CELLLOCK=1,3,1,$earfcn,$pci" 2
		command_generic_cfun_o
	fi
}

command_meig_earfcn2() {
	local _ctl="$1"
	local _info="$2"
	local mode="$3"
	local earfcn="$4"
	local pci="$5"
	local band="$6"
	local _res _info

	_res=$(_command_private_exec "$1" "CELLLOCK" "?")
	if [ -z "$_res" ];then
		return 0
	fi

	if [ "$mode" == "NR" ];then
		_earfcn_meig_5glock "$_ctl" "$_info" "$earfcn" "$pci" "$band"
	elif [ "$mode" == "LTE" ];then
		_earfcn_meig_5g_4glock "$_ctl" "$_info" "$earfcn" "$pci"
	else
		return 0
	fi
}


_common_meig_scannr(){
	local _ctl="$1"
	local scan_param="$2"
	_res_cimi=$(command_generic_imsi "$_ctl")
	json_init
	json_add_array "scanlist"
	_res=$(_command_exec_raw "$_ctl" "AT^NETSCAN=$scan_param" 60|grep "\^NETSCAN:")
	_cnt=$(echo "$_res"|wc -l)
	i=0
	
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_info="$(echo "$line"|awk -F'NETSCAN:' '{print $2}')"
			_isp=$(echo "$_info"|awk -F, '{print $5}'|xargs -r printf)
			local isp_match=0
			if [ -n "$_res_cimi" ];then

				local _ispArray=${_isp//:/ }
				
				for isp_item in $_ispArray
				do
					_isp_len=${#isp_item}
					isp=${_res_cimi:0:$_isp_len}
					_scan_company=$(jsonfilter -e '@[@.plmn[@="'$isp_item'"]].company' </usr/lib/lua/luci/plmn.json )
					_cur_company=$(jsonfilter -e '@[@.plmn[@="'$isp'"]].company' </usr/lib/lua/luci/plmn.json )
					if [ -n "$_scan_company" -a -n "$_cur_company" ];then
						if [ "$_cur_company" == "$_scan_company" ];then
							isp_match=1
						fi
					else
						isp_match=1
					fi
				done
			fi
			_lac="$(echo "$_info"|awk -F, '{print $7}')"
			if [ $isp_match -eq 1 ];then
				if [ "$scan_param" == "4" ];then
						json_add_object 
						json_add_string "MODE" "NR" 
						json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $1}'|sed -e 's/ //g')"					
						json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $2}')"
						json_add_string "CELL" "$(echo "$_info"|awk -F, '{print $3}')"
						json_add_string "RSRP" "$(echo "$_info"|awk -F, '{print $4}')"
						json_add_string "BAND" "$(echo "$_info"|awk -F, '{print $11}')"
						json_add_string "LAC" "$(printf %x $_lac)"
						json_add_string "ISP" "$_isp"

						json_add_object "lockneed"
						json_add_string "MODE" "1"
						json_add_string "EARFCN" "1"
						json_add_string "BAND" "1"
						json_add_string "PCI" "0"
						json_close_object

						json_close_object
				elif [ "$scan_param" == "3" ];then
						json_add_object 
						json_add_string "MODE" "LTE"
						json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $1}'|sed -e 's/ //g')"					
						json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $2}')"
						json_add_string "CELL" "$(echo "$_info"|awk -F, '{print $3}')"
						json_add_string "RSRP" "$(echo "$_info"|awk -F, '{print $4}')"
						json_add_string "BAND" "$(echo "$_info"|awk -F, '{print $11}')"
						json_add_string "LAC" "$(printf %x $_lac)"
						json_add_string "ISP" "$_isp"

						json_add_object "lockneed"
						json_add_string "MODE" "1"
						json_add_string "EARFCN" "1"
						json_add_string "PCI" "0"
						json_close_object

						json_close_object
				fi
			fi

		fi
	done

	json_close_array
	json_dump
	json_cleanup

}

command_meig_scan2(){
	local _ctl="$1"
	local mode="$2"
	local _model
	local _res
	local _data
	local scan_param="4"
	local isp=""
	local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
	[ -z "$simIndex" ] && simIndex="1"
	local nr_support=$(uci -q get "network.${gNet}.nrcap")
	[ -z "$mode" ] &&  mode=$(uci -q get "cpecfg.${gNet}sim$simIndex.mode")
	local odu_model=$(uci -q get "network.${gNet}.mode")

	if [ "$nr_support" == "1" ];then
		if [ "$mode" == "sa_only" ];then
			scan_param="4"
		elif [ "$mode" == "lte" ];then
			scan_param="3"
		fi
		
		[ -n "$scan_param" ] && {
			if [ "$odu_model" == "odu" ];then
				$(touch /tmp/odu_scan_${gNet})
			fi
			
			_common_meig_scannr "$_ctl" "$scan_param"

			if [ "$odu_model" == "odu" ];then
				$(rm /tmp/odu_scan_${gNet})
			fi
		}
	fi
	
	return 0
}
command_meig_neighbour2(){
	local _ctl="$1"
	local _model
	local _res
	local _data

	_res=$(_command_private_exec "$1" "CELLINFO" "=2")
	_cnt=$(echo "$_res"|wc -l)
	i=0
	json_init
	json_add_array "neighbour"
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_info="$(echo "$line"|awk -F: '{print $2}')"
			_mode=$(echo "$_info"|awk -F, '{print $2}'|sed -e 's/\"//g'|sed -e 's/ //g')
			_rsrp="$(echo "$_info"|awk -F, '{print $5}')"
			if [ -z "$_rsrp" -o "$_rsrp" -lt "-120" ];then
				continue
			fi

			if [ "$_mode" == "5G" ];then
				local sinr="$(echo "$_info"|awk -F, '{print $8}')"
				if [ -n "$sinr" -a "$sinr" != "-" ];then
					sinr=$(_command_huawei_sinr_convert "$sinr")
				fi
				json_add_object
				json_add_string "MODE" "NR"
				json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $3}')"
				json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $4}')"
				json_add_string "RSRP" "$_rsrp"
				json_add_string "RSRQ" "$(echo "$_info"|awk -F, '{print $6}')"
				json_add_string "SINR" "$sinr"
				json_add_object "lockneed"
				json_add_string "MODE" "1"
				json_add_string "EARFCN" "1"
				json_add_string "BAND" "1"
				json_add_string "PCI" "0"
				json_close_object
				json_close_object
			fi
			if [ "$_mode" == "LTE" ];then
				json_add_object
				json_add_string "MODE" "$_mode"
				json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $3}')"
				json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $4}')"
				json_add_string "RSRP" "$_rsrp"
				json_add_string "RSRQ" "$(echo "$_info"|awk -F, '{print $6}')"
				
				json_add_object "lockneed"
				json_add_string "MODE" "1"
				json_add_string "EARFCN" "1"
				json_add_string "PCI" "0"
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

command_meig_checkethen(){
	local _ctl="$1"
	local _val="$2"
	local _option
	local _res
	local _val_data="IPPASS,$_val"
	local try_max=5
	local i=0
	_val_data=$(echo "$_val_data"|sed -e 's/\"//g')

	while [ $i -lt $try_max ];do
		_res=$(_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}MAPCFG=\"IPPASS\"")
		[ -z "$_res" ] && return 1

		if echo "$_res"|grep "Error" || echo "$_res"|grep "ERROR";then
			sleep 10
			i=$((i+1))
		elif echo "$_res"|grep "OK";then
			break
		fi
	done

	_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
	echo  "get IPPASS :$_data"
	echo  "_val_data :$_val_data"
	if [ "$_data" = "$_val_data" ]; then
		return 0
	fi

	echo "do set IPPASS $_val"
	_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}MAPCFG=\"IPPASS\",$_val"
	
	return 2
}

command_meig_imei2() {
	local _res _info

	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGSN")
	[ -z "$_res" ] && return 1
	if echo "$_res"|grep -qs ":" ;then
		_info="$(echo "$_res"|grep 'CGSN' -A2|sed -n '2p'|sed -e 's/\"//g'|awk -F':' '{print $2}'|xargs -r printf)"
	else
		_info="$(echo "$_res"|grep 'CGSN' -A2|sed -n '2p'|xargs -r printf)"
		if [ -z "$_info" ];then
			_info="$(echo "$_res"|grep 'CGSN' -A3|sed -n '3p'|xargs -r printf)"
			_info="$(generic_validate_imei "$_info")"
			if [ "$_info" == "none" ];then
				_info=""
			fi
		fi
	fi
	echo "$_info"
}

command_meig_checkmode(){
	local _ctl="$1"
	local _val="$2"
	local _imei="$3"
	local _option
	local _res
	local try_max=5
	local i=0
	
	while [ $i -lt $try_max ];do
		_res=$(_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}SER?")
		[ -z "$_res" ] && return 1

		if echo "$_res"|grep "Error";then
			sleep 10
			i=$((i+1))
		elif echo "$_res"|grep "OK";then
			break
		fi
	done

	[ -n "$_imei" ] && {
		uci -q set "network.${gNet}.imei=$_imei"
		uci commit network
	}

	_option=$(echo "$_res"|grep "+SER"|awk -F':' '{print $2}'|awk -F' ' '{print $1}'|xargs -r printf)
	echo  "get SER :$_option"
	if [ -z "$_option" -o "$_option" = "$_val" ]; then
		return 2
	fi

	echo "do set SER $_val"
	_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}SER=$_val,1"	
	return 1
}

command_meig_getversion2(){
	local _ctl="$1"

	_version="$(uci -q get "cellular_init.$gNet.version")"
	if [ -n "$_revision" ];then
		_revision="$(echo "$_revision"|awk -F'_' '{print $2}')"
		_revision="$(echo "$_revision"|sed -e "s/\.//g")"
		if [ $_revision -ge 608 ];then
			return 0
		else
			return 1
		fi
	fi
	return 0
}

command_meig_checketh2(){
	local _ctl="$1"
	local _val="$2"
	local _option
	local _res
	local _val_data="ETH_SWITCH,$_val"
	local try_max=5
	local i=0
	_val_data=$(echo "$_val_data"|sed -e 's/\"//g')

	while [ $i -lt $try_max ];do
		_res=$(_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}MGCFGEX=\"ETH_SWITCH\"")
		[ -z "$_res" ] && return 1

		if echo "$_res"|grep "Error" || echo "$_res"|grep "ERROR";then
			sleep 2
			i=$((i+1))
		elif echo "$_res"|grep "OK";then
			break
		else
			sleep 1
			i=$((i+1))
		fi
	done

	_data=$(echo "$_res"|grep  "+MGCFGEX"|awk -F':' '{print $2}'|xargs -r printf)
	echo  "get ETH_SWITCH :$_data"
	echo  "_val_data :$_val_data"
	if [ "$_data" = "$_val_data" ]; then
		return 2
	fi

	echo "do set ETH_SWITCH $_val"
	_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}MGCFGEX=\"ETH_SWITCH\",$_val"
	
	return 0
}


command_meig_checkauto2(){
	local _ctl="$1"
	local _val="$2"
	local _option
	local _res
	local _val_data="\"AUTODIAL\",$_val,1"
	local try_max=5
	local i=0
	_val_data=$(echo "$_val_data"|sed -e 's/\"//g')

	while [ $i -lt $try_max ];do
		_res=$(_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}DIALCFG=\"AUTODIAL\"")
		if echo "$_res"|grep "Error" || echo "$_res"|grep "ERROR";then
			sleep 2
			i=$((i+1))
		elif echo "$_res"|grep "OK";then
			break
		else
			sleep 1
			i=$((i+1))
		fi
	done

	_data=$(echo "$_res"|grep "+DIALCFG"|awk -F':' '{print $2}'|xargs -r printf)
	echo  "get DIALCFG AUTODIAL:$_data"
	if [ -z "$_data" ]; then
		return 1
	fi
	echo  "_val_data :$_val_data"
	if [ "$_data" = "$_val_data" ]; then
		return 2
	fi

	echo "do set DIALCFG $_val"
	_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}DIALCFG=\"AUTODIAL\",$_val,1"
	
	return 0
}

command_meig_checkauto_conn2(){
	local _ctl="$1"
	local _val="$2"
	local _option
	local _res
	local _val_data="\"AUTO_RECONN\",$_val"
	local try_max=5
	local i=0
	_val_data=$(echo "$_val_data"|sed -e 's/\"//g')

	while [ $i -lt $try_max ];do
		_res=$(_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}DIALCFG=\"AUTO_RECONN\"")
		[ -z "$_res" ] && return 1

		if echo "$_res"|grep "Error" || echo "$_res"|grep "ERROR";then
			sleep 2
			i=$((i+1))
		elif echo "$_res"|grep "OK";then
			break
		else
			sleep 1
			i=$((i+1))
		fi
	done

	_data=$(echo "$_res"|grep "+DIALCFG"|awk -F':' '{print $2}'|xargs -r printf)
	echo  "get DIALCFG AUTO_RECONN:$_data"
	echo  "_val_data :$_val_data"
	if [ "$_data" = "$_val_data" ]; then
		return 2
	fi

	echo "do set DIALCFG AUTO_RECONN $_val"
	_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}DIALCFG=\"AUTO_RECONN\",$_val"
	
	return 0
}

command_meig_rstsim2() {
	command_generic_reset "$1"
	return 0
}

command_meig_forceims2(){
	local _ctl="$1"
	local val="$2"
	local _data
	local _res

	[ -z "$val" ] && val="1"

	_res=$(_command_generic_exec "$_ctl" "CAVIMS" "?")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		if [ -n "$_data" ];then
			echo  "get ims :$_data"
			if [ "$_data" != "$val" ]; then
				echo  "ims :set $val"
				_command_generic_exec "$_ctl" "CAVIMS" "=$val"
				return 0
			fi
		fi
	fi

	return 1
}

command_meig_preinit2(){
	local res
	local val=1
	local reset=0
	local _phycap=$(uci -q get network.${gNet}.phycap)
	local _imei_history=$(uci -q get network.${gNet}.imei)
	local _ifname=$(uci -q get network.${gNet}.ifname)
	local model_desc=$(uci -q get "network.${gNet}.desc")
	local work_mode=$(uci -q get "network.$gNet.mode")
	local phy_cap=$(echo "$2"|jsonfilter -e '$["dver"]')
	command_generic_imsreport "$1"
	command_generic_imsfmt "$1"
	if command_generic_imssetstorage "$1" ;then
		/etc/init.d/smsd restart
	fi
	if ! echo "$model_desc"|grep -qs "MeiG" ;then
		local eth_val=1
		local _force_ims="0"
		if _check_simslot ;then
			_force_ims="1"
		fi
		if [ "$phy_cap" != "eth" -a "$work_mode" != "odu" ];then
			eth_val=0
		fi
		if command_meig_checkrgmii2 "$1" "$work_mode";then
			reset=1
		fi
		
		command_meig_forceims2 "$1" "$_force_ims"

		if command_meig_checkmode "$1" "$val" "" ;then
			reset=1
		fi

		if command_meig_checketh2 "$_ctl" "$eth_val" ;then
			reset=1
		fi

		if command_meig_checkauto2 "$_ctl" "$val" ;then
			reset=1
		fi

		if command_meig_checkauto_conn2 "$_ctl" "$val" ;then
			reset=1
		fi

		if [ $reset -eq 1 ];then
			cpetools.sh -i "${gNet}" -r
			return 1
		fi

		return 0
	fi

	[ -z "$_phycap" ] && _phycap=0
	if [ $_phycap -ge 2500 ] ;then
		command_meig_getversion2 "$1"
		result=$?
		echo  "version check,$result"
		if [ $result -eq 1 ];then
			val=1
		elif [ $result -eq 2 ];then
			return 1
		else
			val=3
		fi
	fi

	_imei=$(command_meig_imei2 "$_ctl")
	echo "imei:$_imei,_imei_history:$_imei_history,val:$val"
	if [ -z "$_imei_history" -o "$_imei" != "$_imei_history" ];then
		if [ "$val" == "1" ];then
			command_meig_checkethen "$1" "0"
		else
			local mac=$(bdinfo -m)		
			mac_int=$(echo "$mac"|tr -d :)
			mac_int=$(printf %d 0x$mac_int)
			mac_int=$((mac_int+2))
			mac_int=$(printf %x $mac_int)
			mac_int=$(echo $mac_int | tr '[a-z]' '[A-Z]')

			mac_int=$(echo "$mac_int" | sed -r  -e 's/(..)/\1-/g'|cut -c -17)
			_val="1,2,\"${mac_int}\""
			command_meig_checkethen "$1" "$_val"
		fi

		command_meig_checkmode "$1" "$val" "$_imei"
		if [ $val -eq 1 -a -n "$_ifname" ];then
			uci -q delete network.${gNet}.ifname
			uci commit network
			reset=1
			/etc/init.d/atsd restart
		fi
	fi

	return 0
}

command_meig_earfcn_info2() {
	local _res
	local _enable="0"
	local nr_lock_found=0
	local lte_lock_found=0
	json_init
	json_add_array "earfcn"

	_res=$(_command_private_exec "$1" "CELLLOCK" "?"|grep "\^CELLLOCK:")
	[ -n "$_res" ] && {
		_cnt=$(echo "$_res"|wc -l)
		i=0
		while [ $i -lt $_cnt ];do
			i=$((i+1))
			line=$(echo "$_res" |sed -n "${i}p")
			if [ -n "$line" ];then
				_data="$(echo "$line"|awk -F: '{print $2}')"

				_enable_tmp="$(echo "$_data"|awk -F, '{print $1}'|sed 's/ //g'|xargs -r printf)"
				_mode_tmp="$(echo "$_data"|awk -F, '{print $2}'|sed 's/"//g')"
				_type_tmp="$(echo "$_data"|awk -F, '{print $3}')"
				_earfcn_tmp="$(echo "$_data"|awk -F, '{print $4}'|xargs -r printf)"
				_pci_tmp="$(echo "$_data"|awk -F, '{print $5}'|xargs -r printf)"
				_scs_tmp="$(echo "$_data"|awk -F, '{print $6}'|xargs -r printf)"
				_band_tmp="$(echo "$_data"|awk -F, '{print $7}'|xargs -r printf)"


				if [ $_cnt -eq 1 ];then
					if [ "$_enable_tmp" == "0" ];then
						break
					fi
				fi

				json_add_object
				json_add_string "status" "$_enable_tmp"

				if [ "$_mode_tmp" == "4" ];then
					json_add_string "MODE" "NR"
					nr_lock_found=1
				elif [ "$_mode_tmp" == "3" ];then
					json_add_string "MODE" "LTE"
					lte_lock_found=1
				fi
				if [ "$_enable_tmp" == "1" ];then
					json_add_string "BAND" "$_band_tmp"
					json_add_string "EARFCN" "$_earfcn_tmp"
					json_add_string "PCI" "$_pci_tmp"
				fi
				json_close_object
							
			fi
		done
		if [ $nr_lock_found -eq 0 ];then
				json_add_object
				json_add_string "status" "0"
				json_add_string "MODE" "NR"
				json_close_object
		fi
		if [ $lte_lock_found -eq 0 ];then
				json_add_object
				json_add_string "status" "0"
				json_add_string "MODE" "LTE"
				json_close_object
		fi
	}

	json_dump
	json_cleanup
}

command_meig_apn2(){
	command_meig_apn "$@"
}

command_meig_apn(){
	local _ctl="$1"
	local _info="$2"
	local cid="1"
	local apn=""
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')

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
				apn="$_cur_apn"
				break
			fi
		fi
	done
	json_init
	json_add_string "APN" "$apn"
	json_dump
	json_cleanup
}


command_meig_pdp2(){
	local _ctl="$1"
	local _info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	#local cid="$3"
	local pdptype="$4"
	local apn="$5"
	local auth="$6"
	local username="$7"
	local password="$8"
	local cid="1"
	local change=0
	local found=0

	[ "$apn" == "\"\"" ] && apn=""
	[ "$auth" == "\"\"" ] && auth=""
	[ "$username" == "\"\"" ] && username=""
	[ "$password" == "\"\"" ] && password=""

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
						apn=" "
					fi
				fi 
				if [ "$_cur_pdptype" != "$pdptype" -o "$_cur_apn" != "$apn" ];then
					_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGDCONT=$cid,\"$pdptype\"${apn:+,\"$apn\"}"
					change=1
				fi
				break
			fi
		fi
	done

	if [ $found -eq 0 ];then
		_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGDCONT=$cid,\"$pdptype\"${apn:+,\"$apn\"}"
		change=1
	fi

	_res=$(_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}AUTHDATA?"|grep "\^AUTHDATA:")
	if [ -z "$_res" ];then
		_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGPCO?"|grep "CGPCO:")
		[ -z "$_res" ] && return 1
		_cnt=$(echo "$_res"|wc -l)
		i=0
		while [ $i -lt $_cnt ];do
			i=$((i+1))
			line=$(echo "$_res" |sed -n "${i}p")
			if [ -n "$line" ];then
				_data="$(echo "$line"|awk -F: '{print $2}')"			
				_cur_username="$(echo "$_data"|awk -F, '{print $2}'|sed 's/"//g')"
				_cur_password="$(echo "$_data"|awk -F, '{print $3}'|sed 's/"//g')"
				_cur_cid="$(echo "$_data"|awk -F, '{print $4}'|sed 's/ //g')"
				_cur_auth_type="$(echo "$_data"|awk -F, '{print $5}'|sed 's/"//g')"

				if [ "$cid" == "$_cur_cid" ];then
					if [ "$_cur_auth_type" != "$auth" -o "$_cur_password" != "$password" -o "$_cur_username" != "$username" ];then
						_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGPCO=0,\"$username\",\"$password\",$cid,$auth"
						change=1					
					fi
					break
				fi
			fi
		done
	else
		_cnt=$(echo "$_res"|wc -l)
		i=0
		while [ $i -lt $_cnt ];do
			i=$((i+1))
			line=$(echo "$_res" |sed -n "${i}p")
			if [ -n "$line" ];then
				_data="$(echo "$line"|awk -F: '{print $2}')"
				_cur_cid="$(echo "$_data"|awk -F, '{print $1}'|sed 's/ //g')"
				_cur_auth_type="$(echo "$_data"|awk -F, '{print $2}'|sed 's/"//g')"
				_cur_password="$(echo "$_data"|awk -F, '{print $3}'|sed 's/"//g')"
				_cur_username="$(echo "$_data"|awk -F, '{print $4}'|sed 's/"//g')"

				if [ "$cid" == "$_cur_cid" ];then
					if [ "$_cur_auth_type" != "$auth" -o "$_cur_password" != "$password" -o "$_cur_username" != "$username" ];then
						_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}AUTHDATA=$cid,$auth,\"\",\"$password\",\"$username\""
						#change=1					
					fi
					break
				fi
			fi
		done
	fi
	if [ $change -eq 1 ];then
		command_generic_reset "$1"
	fi
}

command_meig_analysis(){
	local _ctl="$1"
	local _info="$2"
	echo $(command_meig_basic "$_ctl" "$_info")
}

command_meig_analysis2(){
	local _ctl="$1"
	local _info="$2"
	echo $(command_meig_basic2 "$_ctl" "$_info")
	echo $(command_generic_ipaddr "$_ctl" "1")
}

command_meig_openrgmii2(){
	local _ctl="$1"
	local _code=2

	nat_info=$(command_meig_getrgmii2 "$_ctl")
	_status=$(echo "$nat_info"|jsonfilter -e '$["status"]')
	if [ "$_status" != "open" ];then		
		_res=$(_command_generic_exec_expect "$_ctl" "DIALCFG" "=\"DIALMODE\",1" "OK")
		info=$(command_meig_checketh2 "$_ctl" "1")
		info=$(command_meig_checkmode "$_ctl" "1" "")
		if [ -n "$_res" ];then
			_code=0
		fi
	else
		if [ $_code != 0 ];then
			_code=2
		fi
	fi
	
	json_init
	json_add_int "code" $_code
	json_add_string "model" $(command_meig_model2 "$1")
	json_dump
	json_cleanup
}

command_meig_closergmii2(){
	local _ctl="$1"
	local _code=2

	nat_info=$(command_meig_getrgmii2 "$_ctl")
	_status=$(echo "$nat_info"|jsonfilter -e '$["status"]')
	if [ "$_status" != "close" ];then		
		_res=$(_command_generic_exec_expect "$_ctl" "DIALCFG" "=\"DIALMODE\",0" "OK")
		if [ -n "$_res" ];then
			_code=0
		fi
	else
		if [ $_code != 0 ];then
			_code=2
		fi
	fi
	
	json_init
	json_add_int "code" $_code
	json_add_string "model" $(command_meig_model2 "$1")
	json_dump
	json_cleanup
}

command_meig_getrgmii2(){
	local _ctl="$1"
	local status=""

	_res=$(_command_generic_exec "$_ctl" "DIALCFG" "=\"DIALMODE\"")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		_status="$(echo "$_data"|awk -F, '{print $2}'|sed 's/ //g'|sed -e 's/\"//g'|xargs -r printf)"
		if [ "$_status" == "1" ];then
			status="open"
		elif [ "$_status" == "0" ];then
			status="close"
		fi
	fi

	json_init
	json_add_string "status" $status
	json_add_string "model" $(command_meig_model2 "$1")
	json_dump
	json_cleanup
}


command_meig_checkrgmii2(){
	local _ctl="$1"
	local _code=1
	local work_mode="$2"
	if [ "$work_mode" == "odu" ];then
		_info=$(command_meig_openrgmii2 "$_ctl")
		_code_rs=$(echo "$_info"|jsonfilter -e '$["code"]')

		if [ -n "$_code_rs" -a "$_code_rs" == "0" ];then
			_code=0
		fi
	else
		_info=$(command_meig_closergmii2 "$_ctl")
		_code_rs=$(echo "$_info"|jsonfilter -e '$["code"]')

		if [ -n "$_code_rs" -a "$_code_rs" == "0" ];then
			_code=0
		fi
	fi
	return $_code
}

command_meig_connstat2(){
	local _ctl="$1"

	_res=$(_command_private_exec "$1" "NDISDUP" "?")
	[ -z "$_res" ] && return 1
	_res=$(echo "$_res"|awk -F: '{print $2}')
	[ -z "$_res" ] && return 1
	_stat=$(echo "$_res"|awk -F, '{print $2}'|sed 's/\"//g'|xargs -r printf)
	_type=$(echo "$_res"|awk -F, '{print $3}'|sed 's/\"//g'|xargs -r printf)

	_stat2=$(echo "$_res"|awk -F, '{print $4}'|sed 's/\"//g'|xargs -r printf)
	_type2=$(echo "$_res"|awk -F, '{print $5}'|sed 's/\"//g'|xargs -r printf)

	json_init
	[ -n "$_stat" ] && json_add_string "$_type" "$_stat"
	[ -n "$_stat2" ] && json_add_string "$_type2" "$_stat2"
	json_dump
	json_cleanup
	return 0
}

command_meig_temp2(){
	local _ctl="$1"
	local _model_temp="0"
	_res=$(_command_generic_exec "$_ctl" "TEMP" )
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
				if [ "cluster0-thmzone" == "$_cur_type" ];then
					_model_temp="$_cur_temp"
				fi
			fi
		fi
	done
	echo "$_model_temp"|awk '{printf "%d",$1/1000}'
}