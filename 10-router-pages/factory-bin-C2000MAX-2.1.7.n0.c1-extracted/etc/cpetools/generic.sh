#!/bin/ash

waitfor=0
sleep_pid="/tmp/cpetools_tmp_wait_pid"
subwait(){
	sleep $waitfor &
	commandwaitpid=$!
	echo "$commandwaitpid" > $sleep_pid
	commandpid=$1
	wait $commandwaitpid
	[ -d "/proc/$commandpid" ] && kill -9 $commandpid >/dev/null 2>&1
}

do_job(){
	local _lockf="${CPE_LOCK_PATH}/${gName}_${gNet}.lock"
	lock "$_lockf"
	$command &
	commandpid=$!
	$(subwait "$commandpid")&
	wait $commandpid >/dev/null 2>&1
	commandwaitpid=$(cat $sleep_pid)
	[ -n "$commandwaitpid" -a -d "/proc/$commandwaitpid" ] && kill -9 $commandwaitpid  >/dev/null 2>&1
	rm  $sleep_pid
	lock -u "$_lockf"
}

job_timeout()
{
	command=$*
	echo_str=$(do_job)
	echo "$echo_str"
}

check_soc_vendor() {
	if [ -f "/usr/sbin/atcmd" ]; then
		echo "tdtech"
	elif [ -f "/bin/serial_atcmd" ]; then
		echo "quectel_ysdk"
	elif [ -f "/usr/bin/qlnet" ]; then
		echo "quectel_opsdk"
	else
		mode=$(uci -q get network.$gNet.mode)
		if [ "$mode" == "cloud" ];then
			echo "simcom"
		else
			echo "nradio"
		fi
	fi
}

_command_atcmd_nradio() {
	/usr/sbin/atsd_cli -i "$1" -c "$2" ${3:+-w "$3"} ${4:+-W "$4"}
}

_command_atcmd_quectel() {
	atsd_cli -i "$1" -c "$2" ${3:+-w "$3"} ${4:+-W "$4"}
	# local _cmds="$2"
	# local _cmd

	# for _cmd in $(echo "$_cmds"|sed 's/|/ /g'); do
	# 	/bin/serial_atcmd "$_cmd"
	# done
}

_command_atcmd_tdtech() {
	local _cmds="$2"
	local _timeout="$3"
	local _cmd

	for _cmd in $(echo "$_cmds"|sed 's/|/ /g'); do
		if [ -n "$_timeout" ];then
			ubus -t$_timeout call atcmd exec "{\"atcmd\": \"$_cmd\",\"timeout\": $_timeout}" | jsonfilter -e '@.result'
		else
			atsh "$_cmd"
		fi
	done

}

_command_atcmd_simcom() {
	if ! echo "$2"|grep -E "^AT+"; then
		/usr/sbin/simcom_http_cli -i "$1" -c "$2" ${3:+-p "$3"}
	fi
}

_command_exec_raw() {
	local _tty
	local _cmd
	local _res
	local _exec
	local _vendor

	_tty="$1"
	_cmd="$2"
	_lto="$3"
	_block="$4"

	_vendor=$(check_soc_vendor)
	_exec="_command_atcmd_${_vendor%%_*}"

	if [ -n "$_lto" ]; then
		if [ "$_vendor" == "tdtech" ];then
			_res=$("$_exec" "$gNet" "$_cmd" $_lto "$_block")
		else
			if [ "$_vendor" == "simcom" ];then
				_res=$("$_exec" "$gNet" "$_cmd" "$_lto")
			else
				_res=$("$_exec" "$gNet" "$_cmd" $((_lto*1000)) "$_block")
			fi
		fi
	else
		local odu_model=$(uci -q get network.${gNet}.odu_model)
		if [ "$odu_model" != "NRFAMILY" ];then
			_res=$("$_exec" "$gNet" "$_cmd" "" "$_block")
		fi
	fi

	echo "$_res"|tr -s '\n\n' '\r\n'|tr -s '\r\n\r\n' '\r\n'
}

_command_exec() {
	if [ -n "$5" ];then
		_command_exec_raw "$1" "$3$2$4" "$6"| grep "$5"
	else
		_command_exec_raw "$1" "$3$2$4" "$6"| grep "$2:"
	fi
}


_command_generic_exec_expect() {
	_command_exec "$1" "$2" "$AT_GENERIC_PREFIX" "$3" "$4"
}

_command_generic_exec() {
	_command_exec "$1" "$2" "$AT_GENERIC_PREFIX" "$3" "" "$5"
}

_command_private_exec() {
	_command_exec "$1" "$2" "$AT_PRIVATE_PREFIX" "$3"
}

_command_private_generic_exec() {
	_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}$2$3" | grep "OK"
}

_command_convert_rssi() {
	local _rssi="$1"

	if [ "$_rssi" -eq 99 ]; then
		echo "Unknown"
	else
		echo $((-113+_rssi*2))
	fi
}

_command_convert_access_technology() {
	local _act="$1"

	if [ "$_act" -lt 4 ]; then
		echo "GSM"
	elif [ "$_act" -lt 7 ]; then
		echo "WCDMA"
	elif [ "$_act" -eq 7 ]; then
		echo "LTE"
	elif [ "$_act" -eq 13 ]; then
		echo "NR"
	else
		echo "Unknown"
	fi
}

_command_convert_ber() {
	echo "$1"
}

_command_generic_cereg() {
	local _ctl="$1"
	local _info="$2"
	local _n _stat _act

	[ -z "$_info" ] && echo "{}" && return 0
	_n="$(echo "$_info"|cut -d, -f1|xargs -r printf)"
	_stat="$(echo "$_info"|cut -d, -f2|xargs -r printf)"

	if [ "$_n" != "2" ]; then
		_command_generic_exec "$_ctl" "CEREG" "=2"
	fi

	json_init
	if [ "$_stat" = "1" ] || [ "$_stat" = "5" ] || [ "$_stat" = "4" ]; then
		json_add_string "STAT" "register"
		if [ "$_stat" != "4" ]; then
			_act="$(echo "$_info"|cut -d, -f5)"
			if [ "$_act" -ge 10 ] && [ "$_act" -lt 15 ]; then
				json_add_string "MODE" "NR"
			elif [ "$_act" -ge 4 ] && [ "$_act" -le 7 ] || [ "$_act" -ge 15 ]; then
				json_add_string "MODE" "LTE"
			fi
		fi
	else
		json_add_string "STAT" "unregister"
	fi
	json_dump
	json_cleanup
}

_command_generic_c5greg() {
	local _info="$1"
	local _stat _act

	[ -z "$_info" ] && echo "{}" && return 0
	_stat="$(echo "$_info"|cut -d, -f2|xargs -r printf)"

	json_init
	if [ "$_stat" = "1" ] || [ "$_stat" = "5" ]; then
		json_add_string "STAT" "register"
	else
		json_add_string "STAT" "unregister"
	fi
	json_dump
	json_cleanup
}

generic_convert_csq() {
	local _info="$1"

	json_init
	json_add_string "RSSI" "$(_command_convert_rssi "$(echo "$_info"|cut -d, -f1)")"
	json_add_string "BER" "$(_command_convert_ber "$(echo "$_info"|cut -d, -f2)")"
	json_dump
	json_cleanup
}

generic_convert_cops() {
	local _info="$1"

	json_init
	json_add_string "OPER" "$(echo "$_info"|cut -d, -f3|tr -d '"')"
	json_add_string "ACT" "$(_command_convert_access_technology "$(echo "$_info"|cut -d, -f4)")"
	json_dump
	json_cleanup
}

command_generic_signal() {
	local _res _info

	_res=$(_command_generic_exec "$1" "CSQ")
	[ -z "$_res" ] && return 1

	_info="$(echo "$_res"|awk -F: '{print $2}')"

	generic_convert_csq "$_info"
}

command_generic_number() {
	local _res _info

	_res=$(_command_generic_exec "$1" "CNUM")
	[ -z "$_res" ] && return 1

	_info="$(echo "$_res"|awk -F: '{print $2}')"

	echo "$_info"|cut -d, -f2|sed 's/"//g'
}


command_generic_network() {
	local _res _info

	_res=$(_command_generic_exec "$1" "COPS" "?")
	[ -z "$_res" ] && return 1

	_info="$(echo "$_res"|awk -F: '{print $2}')"

	json_init
	json_add_int "CONTROL" "$(echo "$_info"|cut -d, -f1)"
	json_add_int "FORMAT" "$(echo "$_info"|cut -d, -f2)"
	json_add_string "INFO" "$(echo "$_info"|cut -d, -f3)"
	json_add_int "MODE" "$(echo "$_info"|cut -d, -f4)"
	json_dump
	json_cleanup
}

generic_validate_number_len() {
	local _str=$1
	local _min=$2
	local _max=$3

	if ! echo "$_str"|grep -E "^[0-9]{$_min,$_max}$"; then
		echo "none"
	fi
}

generic_validate_char_len() {
	local _str=$1
	local _min=$2
	local _max=$3

	if ! echo "$_str"|grep -E "^[0-9A-Za-z]{$_min,$_max}$"; then
		echo "none"
	fi
}

generic_validate_imsi() {
	generic_validate_number_len "$1" 14 15
}

generic_validate_imei() {
	generic_validate_number_len "$1" 15 15
}

generic_validate_iccid() {
	generic_validate_char_len "$1" 19 22
}

command_generic_imsi() {
	local _res

	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CIMI")
	[ -z "$_res" ] && return 1

	echo "$_res"|grep "CIMI" -A2|grep -E '^[0-9].*$'|xargs -r printf
}

command_generic_imei() {
	local _res

	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGSN")
	[ -z "$_res" ] && return 1

	echo "$_res"|grep "CGSN" -A2|grep -E '^[0-9].*$'|xargs -r printf
}

command_generic_iccid() {
	local _res _info

	_res=$(_command_generic_exec "$1" "ICCID")
	[ -z "$_res" ] && return 1

	_info="$(echo "$_res"|awk -F: '{print $2}')"

	echo "$_info"|xargs -r printf
}

command_generic_imsfmt(){
	local _ctl="$1"
	local _data
	local _res
	local _val_cmgf="0"

	_res=$(_command_generic_exec "$_ctl" "CMGF" "?")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf|sed -e 's/ //g')
		if [ -n "$_data" ];then
			echo  "get CMGF :$_data"
			if [ "$_data" != "$_val_cmgf" ]; then
				echo  "CMGF :set"
				_command_generic_exec "$_ctl" "CMGF" "=$_val_cmgf"
				return 0
			fi
		fi
	fi
	return 1
}

command_generic_imsreport(){
	local _ctl="$1"
	local _data
	local _res
	local _val_cmgf="2,1,2,2,0"

	_res=$(_command_generic_exec "$_ctl" "CNMI" "?")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf|sed -e 's/ //g')
		if [ -n "$_data" ];then
			echo  "get CNMI :$_data"
			if [ "$_data" != "$_val_cmgf" ]; then
				echo  "CNMI :set $_val_cmgf"
				_command_generic_exec "$_ctl" "CNMI" "=$_val_cmgf"
				return 0
			fi
		fi
	fi
	return 1
}

command_generic_imssetstorage(){
	local _ctl="$1"
	local _data
	local _res
	local _val_cmgf="\"ME\",\"ME\",\"ME\""
	local max_try=5
	local error_response=0
	while true;do
		_res=$(_command_generic_exec "$_ctl" "CPMS" "?")
		if [ -n "$_res" ];then
			_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf|sed -e 's/ //g')
			if [ -n "$_data" ];then
				echo  "get CPMS :$_data"
				if echo "$_data" |grep -qEw "SM"; then
					echo  "CPMS :set $_val_cmgf"
					_res=$(_command_generic_exec "$_ctl" "CPMS" "=$_val_cmgf")
					if [ -n "$_res" ];then
						return 0
					fi
				fi
			fi
			break
		fi
		echo  "CPMS :get error $error_response"
		error_response=$((error_response+1))
		if [ $error_response -gt $max_try ];then
			break
		fi
		sleep 1
	done

	return 1
}

command_generic_cleanims(){
	local _ctl="$1"
	local _data
	local _res
	local _val_cmgf="\"ME\",\"ME\",\"ME\""

	_res=$(_command_generic_exec "$_ctl" "CPMS" "?")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf|sed -e 's/ //g')
		if [ -n "$_data" ];then
			echo  "get CPMS :$_data"
			if echo "$_data" |grep -qEw "SM"; then
				echo  "CPMS :set $_val_cmgf"
				_res=$(_command_generic_exec "$_ctl" "CPMS" "=$_val_cmgf")
			fi
			_res=$(_command_generic_exec "$_ctl" "CMGD" "=1,4")
		fi
	fi
	return 0
}

command_generic_cleancurims(){
	local _res
	local _code=-2
	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CMGD=1,4")
	if echo "$_res"|grep -qEw "OK"; then
		_code=0
	fi

	json_init
	json_add_int "code" $_code

	json_dump
	json_cleanup
	return $_code
}

_check_simslot(){
	local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
	local simStype=$(uci -q get "cpesel.sim${gIndex}.stype")
	local _force_ims=$(uci -q get cpecfg.${gNet}sim${simIndex}.force_ims)
	local _stype="0"

	if [ -n "$simStype" ];then
		_stype=$(echo "$simStype"|cut -d, -f "$simIndex")
	fi
	echo  "simtype:$_stype,_force_ims:$_force_ims"
	if [ "$_stype" == "0" ];then
		if [ "$_force_ims" == "1" ];then
			return 0
		elif [ "$_force_ims" == "0" ];then
			return 1
		fi

		return 1
	fi
	return 1
}

command_generic_smsnum() {
	local _res _info

	_res=$(_command_generic_exec "$1" "CSCA" "?")
	[ -z "$_res" ] && return 1
	_info="$(echo "$_res"|awk -F: '{print $2}'|xargs -r printf)"
	_info="$(echo "$_info"|awk -F',' '{print $1}'|sed -e 's/\"//g'|sed -e 's/ //g')"

	echo -n "$_info"
}

command_generic_smsstorage() {
	local _res _info
	json_init

	_res=$(_command_generic_exec "$1" "CPMS" "?")
	if [ -n "$_res" ];then
		_info="$(echo "$_res"|awk -F: '{print $2}'|xargs -r printf)"
		_type="$(echo "$_info"|awk -F',' '{print $1}'|sed -e 's/\"//g'|sed -e 's/ //g')"
		_used="$(echo "$_info"|awk -F',' '{print $2}')"
		_total="$(echo "$_info"|awk -F',' '{print $3}'|sed -e 's/\"//g'|sed -e 's/ //g')"
		if [ "$_type" == "ME" -o "$_type" == "MT" ];then
			_type="ME"
		fi
		json_add_string "type" "$_type"
		json_add_string "used" "$_used"
		json_add_string "total" "$_total"
	fi

	json_dump
	json_cleanup
	return 0
}

command_generic_sms_send(){
	local _ctl="$1"
	local _sendmsg_len="$2"
	local _sendmsg="$3"
	local _raw_res=""
	local _index=""
	local _code=1
	_info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	_driver=$(echo "$_info"|jsonfilter -e '$["driver"]')
	_revision="$(uci -q get "cellular_init.$gNet.version")"
	json_init
	#send immediately
	#_command_generic_exec "$1" "CMGS" "=$_sendmsg_len>$_sendmsg"

	#write ,then send
	_vendor=$(check_soc_vendor)
	if [ "$_vendor" == "tdtech" ] || [ "$_alias" == "mt5700" -a "$_driver" != "odu" ] || [ "$_alias" == "mt5700" -a "$_revision" != "21C20B563S000C000" ];then
		_raw_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CMGW=$_sendmsg_len\r$_sendmsg")
	else
		_raw_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CMGW=$_sendmsg_len>$_sendmsg")
	fi
	[ -n "$_raw_res" ] && {
		if echo "$_raw_res"|grep -qEw "322"; then
			_code=2
		else
			if echo "$_raw_res"|grep -qEw "OK"; then
				_index=$(echo "$_raw_res"|awk -F: '{print $2}'|xargs -r printf)
			fi
		fi
	}
	if [ -n "$_index" ];then
		_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CMSS=$_index")
		if echo "$_res"|grep -qEw "OK"; then
			_code=0
		fi
	fi
	json_add_int "code" $_code
	json_add_string "index" "$_index"
	json_dump
	json_cleanup
}

command_generic_sms_sendm(){
	local _ctl="$1"
	local _sendid="$2"
	local _res=""
	local _code=1

	json_init
	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CMSS=$_sendid")
	if echo "$_res"|grep -qEw "OK"; then
		_code=0
	fi

	json_add_string "index" "$_sendid"
	json_add_int "code" $_code

	json_dump
	json_cleanup
}

command_generic_sms_del(){
	local _ctl="$1"
	local _del_file="$2"
	local _res=""
	local _code=0

	json_init
	json_add_array "smsdel"
	local _del_ids=$(cat $_del_file)
	local _del_ids_array=${_del_ids//,/ }
	for id in $_del_ids_array
	do
		local code=1
		if [ -n "$id" ];then
			_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CMGD=$id")
			if echo "$_res"|grep -qEw "OK"; then
				code=0
			elif echo "$_res"|grep -qEw "321"; then
				code=2
			else
				_code=1
			fi
			json_add_object
			json_add_string "index" "$id"
			json_add_int "code" $code
			json_close_object
		fi
	done
	json_close_array
	json_add_int "code" $_code

	json_dump
	json_cleanup

	return 0
}

command_generic_sms_read(){
	local _ctl="$1"
	local _read_ids="$2"
	local _res=""

	json_init
	json_add_array "smsread"
	local _read_ids_array=${_read_ids//,/ }
	for _id in $_read_ids_array
	do
		if [ -n "$_id" ];then
			_raw_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CMGR=$_id")
			_cnt=$(echo "$_raw_res"|wc -l)
			i=0

			while [ $i -lt $_cnt ];do
				i=$((i+1))
				line=$(echo "$_raw_res" |sed -n "${i}p")
				if [ -n "$line" ];then
					if echo "$line"|grep -q "+CMGR:" ;then
						i=$((i+1))
						sms_info="$(echo "$line"|awk -F: '{print $2}')"
						stat="$(echo "$sms_info"|awk -F, '{print $1}'|sed 's/ //g')"
						alpha="$(echo "$sms_info"|awk -F, '{print $2}'|sed 's/ //g')"
						length="$(echo "$sms_info"|awk -F, '{print $3}'|sed 's/ //g'|xargs -r printf)"
						sms_data=$(echo "$_raw_res" |sed -n "${i}p"|xargs -r printf)
						json_add_object
						json_add_string "index" "$_id"
						json_add_string "stat" "$stat"
						json_add_string "length" "$length"
						json_add_string "sms_data" "$sms_data"
						json_close_object
					fi
				fi
			done
		fi
	done
	json_close_array
	json_dump
	json_cleanup

	return 0
}

_command_generic_sms(){
	local _ctl="$1"
	local _raw_res=""
	local type="$2"
	local _code=-1

	json_init

	_raw_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CMGL=$type" 8)

	_cnt=$(echo "$_raw_res"|wc -l)
	if echo "$_raw_res"|grep -q "OK" ;then
		_code=0
	fi

	json_add_array "smslist"
	i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_raw_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			if echo "$line"|grep -q "+CMGL:" ;then
				i=$((i+1))
				sms_info="$(echo "$line"|awk -F: '{print $2}')"
				index="$(echo "$sms_info"|awk -F, '{print $1}'|sed 's/ //g')"
				stat="$(echo "$sms_info"|awk -F, '{print $2}'|sed 's/ //g')"
				alpha="$(echo "$sms_info"|awk -F, '{print $3}'|sed 's/ //g')"
				length="$(echo "$sms_info"|awk -F, '{print $4}'|sed 's/ //g'|xargs -r printf)"
				sms_data=$(echo "$_raw_res" |sed -n "${i}p"|xargs -r printf)
				if [ -z "$sms_data" ];then
					i=$((i+1))
					sms_data=$(echo "$_raw_res" |sed -n "${i}p"|xargs -r printf)
				fi
				_code=0
				json_add_object
				json_add_string "index" "$index"
				json_add_string "stat" "$stat"
				json_add_string "length" "$length"
				json_add_string "sms_data" "$sms_data"
				json_close_object
			fi
		fi
	done

	json_close_array
	json_add_int "code" $_code
	json_dump
	json_cleanup
	return 0
}

command_generic_sms_new(){
	local _ctl="$1"
	_command_generic_sms "$_ctl" "0"
}

command_generic_sms(){
	local _ctl="$1"
	_command_generic_sms "$_ctl" "4"
}

command_generic_basic() {
	local _ctl="$1"
	local _info="$2"
	local _res _imei _imsi _iccid _mode _model _revision
	local _cmd

	_model="$(uci -q get "cellular_init.$gNet.model")"
	_revision="$(uci -q get "cellular_init.$gNet.version")"
	_imei="$(uci -q get "cellular_init.$gNet.imei")"

	_cmd="${AT_GENERIC_PREFIX}CIMI|${AT_GENERIC_PREFIX}ICCID"

	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1
	_imsi="$(echo "$_res"|grep 'CIMI' -A2|sed -n '2p'|xargs -r printf)"
	_iccid="$(echo "$_res"|grep 'ICCID:'|awk -F' ' '{print $2}')"


	json_init
	json_add_string "MODE" "$_mode"
	json_add_string "IMEI" "$_imei"
	json_add_string "IMSI" "$_imsi"
	json_add_string "ICCID" "$_iccid"
	json_add_string "MODEL" "$_model"
	json_add_string "REVISION" "$_revision"
	json_dump
	json_cleanup
}

command_generic_nroff() {
	return 0
}

command_generic_allmode() {
	return 0
}

command_generic_register() {
	local _ctl="$1"
	local _res _cereg _c5greg
	local _cmd

	_res=$(command_generic_cpin "$_ctl")
	if echo "$_res"|grep -qEw "3"; then
		echo "SIM NOT READY"
		return 1
	fi

	_cmd="${AT_GENERIC_PREFIX}CEREG?|${AT_GENERIC_PREFIX}C5GREG?"

	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1

	_cereg="$(_command_generic_cereg "$_ctl" "$(echo "$_res"|grep "CEREG:"|awk -F: '{print $2}')")"
	_c5greg="$(_command_generic_c5greg "$(echo "$_res"|grep "C5GREG:"|awk -F: '{print $2}')")"

	if [ "$(echo "$_c5greg"|jsonfilter -e "\$['STAT']")" = "register" ]; then
		echo "register, NR"
	elif [ "$(echo "$_cereg"|jsonfilter -e "\$['MODE']")" = "NR" ]; then
		echo "register, NR"
	elif [ "$(echo "$_cereg"|jsonfilter -e "\$['MODE']")" = "LTE" ]; then
		echo "register, LTE"
	else
		echo "unregister"
	fi

	return 0
}

command_generic_cpin() {
	local _res
	local _code
	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CPIN?" "1")
	[ -z "$_res" ] && return 1

	echo "$_res" |while read line
	do
		if echo "$line" |grep -q "READY" ;then
			echo 0
		elif echo "$line"  |grep -q "SIM PIN" ;then
			echo 1
		elif echo "$line"  |grep -q "SIM PUK" ;then
			echo 2
		elif echo "$line"  |grep -q "ERROR" ; then
			_code=$(echo "$line" |awk -F ' ' '{print $3}')
			echo "3 $_code"
		fi
	done
}

command_generic_qpinc() {
	local _res
	local _pin_left
	local _puk_left
	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}QPINC?")
	[ -z "$_res" ] && return 1

	echo "$_res" |while read line
	do
		if echo "$line" |grep -q "SC" ;then
			_pin_left=$(echo "$line" |awk -F ',' '{print $2}')
			_puk_left=$(echo "$line" |awk -F ',' '{print $3}')
			echo "$_pin_left $_puk_left"
		fi
	done
}

command_generic_clck() {
	local _res _info
	_res=$(_command_generic_exec "$1" "CLCK" "=\"SC\",2")
	[ -z "$_res" ] && return 1

	_info="$(echo "$_res"|awk -F: '{print $2}')"
	echo $_info
}

command_generic_preinit() {
    return 0
}

command_generic_pdptype(){
	local cid="$2"
	local pdptype="$3"
	[ -z "$cid" ] && return
	[ -z "$pdptype" ] && return
	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGDCONT?")
	[ -z "$_res" ] && return 1
	pdptype=$(echo $pdptype | tr 'a-z' 'A-Z')
	echo "$_res" |while read line
	do
		if echo "$line" |grep -q "+CGDCONT:" ;then
			_info="$(echo "$line"|awk -F: '{print $2}')"
			_cur_cid="$(echo "$_info"|awk -F, '{print $1}'|sed 's/ //g')"
			_cur_pdptype="$(echo "$_info"|awk -F, '{print $2}'|sed 's/"//g')"
			_cur_pdptype=$(echo $_cur_pdptype | tr 'a-z' 'A-Z')
			if [ "$cid" == "$_cur_cid" ];then
				if [ "$_cur_pdptype" != "$pdptype" ];then
					_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGDCONT=$cid,\"$pdptype\""
					command_generic_reset "$1"
				fi
				break
			fi
		fi
	done
}
_command_format_ip(){
	_ip="$1"
	_ip_len=0
	[ -n "$_ip" ] && _ip_len=${#_ip}

	if [ $_ip_len -gt 15 ] && echo "$_ip"|grep -sq "\.";then
		local ipArray=${_ip//./ }
		for ip_item in $ipArray
		do
			_odd=$((_odd+1))
			if [ -n "$ip_hex" -a $((_odd%2)) -eq 1 ];then
				ip_hex="${ip_hex}:$(printf %x $ip_item)"
			else
				ip_hex="${ip_hex}$(printf %02x $ip_item)"
			fi
		done	
		_ip="$ip_hex"
	fi
	echo "$_ip"
}
command_generic_ipaddr(){
	local cid="$2"
	[ -z "$cid" ] && return 1

	_res=$(_command_generic_exec "$1" "CGPADDR" "=$cid")
	[ -z "$_res" ] && return 1

	_ip=$(echo "$_res"|awk -F, '{print $2}'|sed 's/\"//g'|xargs -r printf)
	_ip6=$(echo "$_res"|awk -F, '{print $3}'|sed 's/\"//g'|xargs -r printf)
	
	_odd=0
	ip_hex=""
	
	_ip=$(_command_format_ip "$_ip")
	_ip6=$(_command_format_ip "$_ip6")
	if echo "$_ip"|grep -sq ":";then
		_ip6="$_ip"
		_ip=""
	fi
	json_init
	json_add_string "IPV4" "$_ip"
	json_add_string "IPV6" "$_ip6"
	json_dump
	json_cleanup
	return 0
}
command_generic_ips(){
	local _ctl="$1"
	echo $(command_generic_ipaddr "$_ctl" "1")
}

command_generic_cimi() {
	local _res
	local _code=0
	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CIMI")
	[ -z "$_res" ] && return 1
	echo "$_res" |while read line
	do
		if echo "$line" |grep -q "CIMI" ;then
			_code=$((_code+1))
		elif [ $_code -gt 0 ];then
			echo $line
			break
		fi
	done
}

command_generic_reboot(){
	_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CFUN=1,1" 2
}

command_generic_reset(){
	sleep 1
	_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CFUN=0" 7
	err_cnt=0
	while true;do
		sleep 1
		_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CFUN=1" 2)
		echo "$_res"
		if echo "$_res"|grep -sq "OK";then
			break
		else
			if [ -n "$_res" ];then
				err_cnt=$((err_cnt+1))
				if [ $err_cnt -ge 10 ];then
					cpetools.sh -R -i $gNet
					break
				fi
			fi
		fi
	done
}

command_generic_ate1(){
	while true;do
		sleep 1
		_res=$(_command_exec_raw "$1" "ATE1" 2)
		echo "$_res"
		if echo "$_res"|grep -sq "OK";then
			break
		fi
	done
}
command_generic_cfun_c(){
	sleep 1
	_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CFUN=0" 2
}

command_generic_cfun_o(){
	err_cnt=0
	while true;do
		sleep 1
		_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CFUN=1" 2)
		echo "$_res"
		if echo "$_res"|grep -sq "OK";then
			break
		else
			if [ -n "$_res" ];then
				err_cnt=$((err_cnt+1))
				if [ $err_cnt -ge 10 ];then
					cpetools.sh -R -i $gNet
					break
				fi
			fi
		fi
	done
}

command_generic_get_cfun(){
	local _res _info
	_res=$(_command_generic_exec "$1" "CFUN" "?")
	[ -z "$_res" ] && return 1

	_info="$(echo "$_res"|awk -F: '{print $2}'|sed 's/ //g'|xargs -r printf)"
	echo $_info
	return 0
}


command_generic_version(){
	local _ctl="$1"
	local _model
	local _res
	local _cmd="ATI"

	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1
	_revision="$(echo "$_res"|grep 'Revision:'|awk -F' ' '{print $2}')"

	echo "$_revision"
}
command_generic_recovery_cops(){
	local res=""
	while true;do
		res=$(command_generic_network)
		if [ -n "$_res" ];then
			control=$(echo "$res"|jsonfilter -e "\$['CONTROL']")
			if [ "$control" != "0" ];then
				_command_generic_exec "$1" "COPS" "=0"
			else
				break
			fi
		fi
		sleep 1
	done
}

check_apn_disable()
{
	local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
	[ -z "$simIndex" ] && simIndex="1"
	local apn_cfg=$(uci -q get "cpecfg.${gNet}sim$simIndex.apn_cfg")
	if [ -n "$apn_cfg" ];then
		local custom_apn=$(uci -q get "apn.$apn_cfg.custom_apn")
		if [ "$custom_apn" != "1" ];then
			return 0
		fi
	else
		local custom_apn=$(uci -q get "cpecfg.${gNet}sim$simIndex.custom_apn")
		local apn=$(uci -q get "cpecfg.${gNet}sim$simIndex.apn")
		if [ "$custom_apn" != "1" -a -n "$apn" ];then
			return 0
		fi
		if [ -f "/tmp/${gNet}sim${simIndex}_remove_apn" ];then
			rm "/tmp/${gNet}sim${simIndex}_remove_apn"
			return 0
		fi
	fi
	return 1
}
