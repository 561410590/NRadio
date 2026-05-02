#!/bin/ash

_command_spreadtrum_iccid() {
	local _res _info

	_res=$(_command_generic_exec "$1" "CCID")
	[ -z "$_res" ] && return 1

	_info="$(echo "$_res"|awk -F'\"' '{print $2}')"

	echo "$_info"
}

_command_spreadtrum_cesq() {
	local _cesq
	local _rsrq _rsrp
	_cesq="$1"

	json_init
	_rsrq="$(echo "$_cesq"|cut -d, -f5)"
	_rsrp="$(echo "$_cesq"|cut -d, -f6)"
	_rsrp=$((_rsrp-140))
	_rsrq=$(((_rsrq-39)/2))
	json_add_int "RSRP" "$_rsrp"
	json_add_int "RSRQ" "$_rsrq"
	json_dump
	json_cleanup
}

_command_spreadtrum_cced() {
	local _cced
	local _mnc _mcc _cellid
	_cced="$1"

	_mcc="$(echo "$_cced"|cut -d, -f1)"
	_mnc="$(echo "$_cced"|cut -d, -f2)"
	_cellid="$(echo "$_cced"|cut -d, -f3)"
	json_init
	json_add_int "MCC" "$_mcc"
	json_add_int "MNC" "$_mnc"
	json_add_string "CELL" "$_cellid"
	json_dump
	json_cleanup
}

command_spreadtrum_iccid() {
	_command_spreadtrum_iccid "$1"
}

command_spreadtrum_basic() {
	local _ctl="$1"
	local _info="$2"
	local _res _imei _imsi _iccid _cesq _model _revision _cced _cops
	local _cmd

	_cmd="${AT_GENERIC_PREFIX}CESQ|${AT_GENERIC_PREFIX}CCID|${AT_GENERIC_PREFIX}|${AT_GENERIC_PREFIX}CCED=0,1|${AT_GENERIC_PREFIX}CGMR|${AT_GENERIC_PREFIX}COPS?"

	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1

	_cesq="$(echo "$_res"|grep 'CESQ:'|cut -d: -f2)"
	_model="$(echo "$_res"|grep 'Modem Model:'|cut -d: -f2|xargs -r printf)"
	_revision="$(echo "$_res"|grep 'Software Version:'|cut -d: -f2|xargs -r printf)"
	_cced="$(echo "$_res"|grep 'CCED:'|cut -d: -f2)"
	_cops="$(echo "$_res"|grep "COPS:"|awk -F: '{print $2}')"
	_iccid="$(echo "$_res"|grep "CCID:"|awk -F'"' '{print $2}')"

	_cesq=$(_command_spreadtrum_cesq "$_cesq")
	_cced=$(_command_spreadtrum_cced "$_cced")
	_cops=$(generic_convert_cops "$_cops")

	_imsi=$(_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}CIMI"|grep -E "^[0-9]"|xargs -r printf)
	_imei=$(_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}CGSN"|grep -E "^[0-9]"|xargs -r printf)

	json_init
	json_add_string "MODE" "$(echo "$_cops"|jsonfilter -e '$["ACT"]')"
	json_add_string "ISP" "$(echo "$_cops"|jsonfilter -e '$["OPER"]')"
	json_add_int "RSRP" "$(echo "$_cesq"|jsonfilter -e '$["RSRP"]')"
	json_add_int "RSRQ" "$(echo "$_cesq"|jsonfilter -e '$["RSRQ"]')"
	json_add_int "CELL" "$(echo "$_cced"|jsonfilter -e '$["CELL"]')"
	json_add_string "IMEI" "$_imei"
	json_add_string "IMSI" "$_imsi"
	json_add_string "ICCID" "$_iccid"
	json_add_string "MODEL" "$_model"
	json_add_string "REVISION" "$_revision"
	json_dump
	json_cleanup
}

command_spreadtrum_signal() {
	local _ctl="$1"
	local _res _cesq _cops
	local _cmd

	_cmd="${AT_GENERIC_PREFIX}CESQ|${AT_GENERIC_PREFIX}COPS?"

	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1

	_cesq="$(echo "$_res"|grep 'CESQ:'|cut -d: -f2)"
	_cops="$(echo "$_res"|grep "COPS:"|awk -F: '{print $2}')"
	_cesq=$(_command_spreadtrum_cesq "$_cesq")
	_cops=$(generic_convert_cops "$_cops")

	json_init
	json_add_string "MODE" "$(echo "$_cops"|jsonfilter -e '$["ACT"]')"
	json_add_object "$(echo "$_cops"|jsonfilter -e '$["ACT"]')"
	json_add_int "RSRP" "$(echo "$_cesq"|jsonfilter -e '$["RSRP"]')"
	json_add_int "RSRQ" "$(echo "$_cesq"|jsonfilter -e '$["RSRQ"]')"
	json_close_object
	json_dump
	json_cleanup
}

command_spreadtrum_preinit() {
	return 0
}


command_spreadtrum_pdp(){
	local _ctl="$1"
	local _info="$2"
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

	echo "setup_apn $cid,$pdptype,$apn,$auth,$username,$password"

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
				[ -z "$apn" ] && apn="$_cur_apn"
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
	if [ $change -eq 1 ];then
		command_generic_reset "$1"
	fi
}
