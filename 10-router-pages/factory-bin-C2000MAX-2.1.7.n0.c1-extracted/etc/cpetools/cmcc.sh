#!/bin/ash

_command_cmcc_convert_mode() {
	local _mode="$1"

	if [ "$_mode" = "1" ];then
		echo "WCDMA"
	elif [ "$_mode" = "3" ]; then
		echo "LTE"
	elif [ "$_mode" = "4" ]; then
		echo "TDSCDMA"
	elif [ "$_mode" = "6" ]; then
		echo "NR"
	else
		echo "Unknown"
	fi
}

_command_cmcc_qcr() {
	local _info="$1"

	json_init
	json_add_string "CELL" "$(echo "$_info"|cut -d, -f1)"
	json_add_string "EARFCN" "$(echo "$_info"|cut -d, -f2)"
	json_add_string "VALUE" "$(echo "$_info"|cut -d, -f3|tr -d '"')"
	json_dump
	json_cleanup
}

_command_cmcc_wtrsrp() {
    local _info="$1"

    json_init
    json_add_object "NR"
    json_add_int "VALUE" "$(echo "$_info"|cut -d, -f1|cut -d: -f2)"
    json_close_object
    json_add_object "LTE"
    json_add_int "VALUE" "$(echo "$_info"|cut -d, -f2|cut -d: -f2)"
    json_close_object
    json_dump
    json_cleanup
}

_command_cmcc_wtnsaui() {
	local _info="$1"
	local _val

	json_init
	_val="$(echo "$_info"|awk -F' ' '{print $2}')"
	json_add_string "MODE" "$(_command_cmcc_convert_mode "$_val")"
	json_dump
	json_cleanup
}

_command_cmcc_reg() {
	local _info="$1"
	local _val

	json_init
	json_add_string "LAC" "$(echo "$_info"|cut -d, -f3|tr -d '"')"
	json_add_string "CELL" "$(echo "$_info"|cut -d, -f4|tr -d '"')"
	json_dump
	json_cleanup
}

command_cmcc_signal() {
	local _res
	local _qcrsrq _wtrsrp _wtnsaui _csq _mode

	_res=$(_command_exec_raw "$1" "AT@WTNSAUI?|AT+CSQ|AT\$QCRSRQ?|AT@WTRSRP?")
	[ -z "$_res" ] && return 1

	_qcrsrq="$(echo "$_res"|grep "QCRSRQ:"|awk -F: '{print $2}')"
	_wtrsrp="$(echo "$_res"|grep "WTRSRP ")"
	_csq="$(echo "$_res"|grep "CSQ:"|awk -F: '{print $2}')"
	_wtnsaui="$(echo "$_res"|grep "WTNSAUI:"|awk -F: '{print $2}')"

	_qcrsrq=$(_command_cmcc_qcr "$_qcrsrq")
	_wtrsrp=$(_command_cmcc_wtrsrp "$_wtrsrp")
	_csq=$(generic_convert_csq "$_csq")
	_wtnsaui=$(_command_cmcc_wtnsaui "$_wtnsaui")

	json_init
	_mode="$(echo "$_wtnsaui"|jsonfilter -e '$["MODE"]')"
	json_add_object "$_mode"
	json_add_int "RSRP" "$(echo "$_wtrsrp"|jsonfilter -e "\$['$_mode']['VALUE']")"
	json_add_int "RSRQ" "$(echo "$_qcrsrq"|jsonfilter -e '$["VALUE"]')"
	json_add_int "RSSI" "$(echo "$_csq"|jsonfilter -e '$["RSSI"]')"
	json_close_object
	json_dump
	json_cleanup
}

command_cmcc_cellinfo() {
	local _res
	local _wtnsaui _wtrsrp _qcrsrq _csq _mode

	_res=$(_command_exec_raw "$1" "AT@WTNSAUI?|AT+CSQ|AT\$QCRSRQ?|AT@WTRSRP?")
	[ -z "$_res" ] && return 1

	_wtnsaui="$(echo "$_res"|grep "WTNSAUI:"|awk -F: '{print $2}')"
	_qcrsrp="$(echo "$_res"|grep "QCRSRP:"|awk -F: '{print $2}')"
	_wtrsrp="$(echo "$_res"|grep "WTRSRP ")"
	_csq="$(echo "$_res"|grep "CSQ:"|awk -F: '{print $2}')"

	_wtnsaui=$(_command_cmcc_wtnsaui "$_wtnsaui")
	_qcrsrq=$(_command_cmcc_qcr "$_qcrsrq")
	_wtrsrp=$(_command_cmcc_wtrsrp "$_wtrsrp")
	_csq=$(generic_convert_csq "$_csq")

	json_init
	_mode="$(echo "$_wtnsaui"|jsonfilter -e '$["MODE"]')"
	json_add_object "$_mode"
	json_add_int "RSRP" "$(echo "$_wtrsrp"|jsonfilter -e "\$['$_mode']['VALUE']")"
	json_add_int "RSRQ" "$(echo "$_qcrsrq"|jsonfilter -e '$["VALUE"]')"
	json_add_int "RSSI" "$(echo "$_csq"|jsonfilter -e '$["RSSI"]')"
	json_add_string "CELL" "$(echo "$_qcrsrp"|jsonfilter -e '$["CELL"]')"
	json_add_string "DL_FCN" "$(echo "$_qcrsrq"|jsonfilter -e '$["EARFCN"]')"
	json_close_object
	json_dump
	json_cleanup
}

command_cmcc_basic() {
	local _ctl="$1"
	local _info="$2"
	local _res _imei _imsi _iccid _mode _model _revision _wtnsaui _wtrsrp _qcrsrq _csq _creg _cereg _cops
	local _cmd

	_cmd="AT+COPS?|AT+CEREG?|AT+CREG?|AT@WTNSAUI?|AT+CSQ|AT\$QCRSRQ?|AT@WTRSRP?|${AT_GENERIC_PREFIX}CGSN|${AT_GENERIC_PREFIX}CIMI|${AT_GENERIC_PREFIX}ICCID|ATI"
	_imei=$(echo "$_info"|jsonfilter -e '$["imei"]')
	_imsi=$(echo "$_info"|jsonfilter -e '$["imsi"]')
	_iccid=$(echo "$_info"|jsonfilter -e '$["iccid"]')
	_model=$(echo "$_info"|jsonfilter -e '$["model"]')
	_revision=$(echo "$_info"|jsonfilter -e '$["revision"]')


	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1

	_wtnsaui="$(echo "$_res"|grep "WTNSAUI:"|awk -F: '{print $2}')"
	_wtrsrp="$(echo "$_res"|grep "WTRSRP ")"
	_qcrsrq="$(echo "$_res"|grep "QCRSRQ:"|awk -F: '{print $2}')"
	_csq="$(echo "$_res"|grep "CSQ:"|awk -F: '{print $2}')"
	_creg="$(echo "$_res"|grep "CREG:"|awk -F: '{print $2}')"
	_cereg="$(echo "$_res"|grep "CEREG:"|awk -F: '{print $2}')"
	_cops="$(echo "$_res"|grep "COPS:"|awk -F: '{print $2}')"

	_wtnsaui=$(_command_cmcc_wtnsaui "$_wtnsaui")
	_qcrsrq=$(_command_cmcc_qcr "$_qcrsrq")
	_wtrsrp=$(_command_cmcc_wtrsrp "$_wtrsrp")
	_csq=$(generic_convert_csq "$_csq")
	_creg=$(_command_cmcc_reg "$_creg")
	_cereg=$(_command_cmcc_reg "$_cereg")
	_cops=$(generic_convert_cops "$_cops")

	_imsi="$(echo "$_res"|grep 'CIMI' -A2|sed -n '2p'|xargs -r printf)"
	_imei="$(echo "$_res"|grep 'CGSN' -A2|sed -n '2p'|xargs -r printf)"
	_iccid="$(echo "$_res"|grep 'ICCID:'|awk -F' ' '{print $2}')"
	_model="$(echo "$_res"|grep 'Model:'|awk -F' ' '{print $2}')"
	_revision="$(echo "$_res"|grep 'Revision:'|awk -F' ' '{print $2}')"

	json_init
	_mode="$(echo "$_wtnsaui"|jsonfilter -e '$["MODE"]')"
	json_add_string "MODE" "$_mode"
	json_add_int "RSRP" "$(echo "$_wtrsrp"|jsonfilter -e "\$['$_mode']['VALUE']")"
	json_add_int "RSRQ" "$(echo "$_qcrsrq"|jsonfilter -e '$["VALUE"]')"
	json_add_int "RSSI" "$(echo "$_csq"|jsonfilter -e '$["RSSI"]')"
	if echo "$_cereg"|jsonfilter -e '$["LAC"]' > /dev/null; then
		json_add_string "LAC" "$(echo "$_cereg"|jsonfilter -e '$["LAC"]')"
		json_add_string "CELL" "$(echo "$_cereg"|jsonfilter -e '$["CELL"]')"
	else
		json_add_string "LAC" "$(echo "$_creg"|jsonfilter -e '$["LAC"]')"
		json_add_string "CELL" "$(echo "$_creg"|jsonfilter -e '$["CELL"]')"
	fi
	json_add_string "ISP" "$(echo "$_cops"|jsonfilter -e '$["OPER"]')"
	json_add_string "DL_FCN" "$(echo "$_qcrsrq"|jsonfilter -e '$["EARFCN"]')"
	json_add_string "IMEI" "$(generic_validate_imei "$_imei")"
	json_add_string "IMSI" "$(generic_validate_imsi "$_imsi")"
	json_add_string "ICCID" "$(generic_validate_iccid "$_iccid")"
	json_add_string "MODEL" "$_model"
	json_add_string "REVISION" "$_revision"
	json_dump
	json_cleanup
}
