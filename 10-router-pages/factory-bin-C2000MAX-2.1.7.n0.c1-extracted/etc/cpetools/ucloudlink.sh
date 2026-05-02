#!/bin/ash

_command_ucloudlink_set_card() {
    local _ctl="$1"
    local _num="$2"
    local _res _cmd _card
    local _tries=5
    local first_match=1

    while [ "$_card" != "$_num" ]; do
        _tries=$((_tries-1))

        [ "$_tries" = "0" ] && return 1

        _cmd="${AT_GENERIC_PREFIX}SPACTCARD?"
        _res=$(_command_exec_raw "$_ctl" "$_cmd" "1")

        [ -z "$_res" ] && continue
        _card="$(echo "$_res"|grep '+SPACTCARD:'|cut -d' ' -f2|xargs -r printf)"

        if [ "$_card" != "$_num" ]; then
            _cmd="${AT_GENERIC_PREFIX}SPACTCARD=${_num}"
            _res=$(_command_exec_raw "$_ctl" "$_cmd" "1")
            [ -z "$_res" ] && continue
        else
            if [ $first_match -eq 1 ];then
                return 2
            fi
        fi
        first_match=0
    done

    return 0
}
_command_ucloudlink_sinr() {
    local _sinr

    _sinr="$1"

    json_init
    json_add_string "SINR" "$(echo "$_sinr"|cut -d, -f1)"
    json_add_int "BER" "$(echo "$_sinr"|cut -d, -f2)"

    json_dump
    json_cleanup
}
_command_ucloudlink_qcrsrq() {
    local _qcrsrq

    _qcrsrq="$1"

    json_init
    json_add_string "PCI" "$(echo "$_qcrsrq"|cut -d, -f1)"
    json_add_int "RSRQ" "$(echo "$_qcrsrq"|cut -d, -f3|sed 's/\"//g')"
    json_add_int "EARFCN" "$(echo "$_qcrsrq"|cut -d, -f2)"

    json_dump
    json_cleanup
}

_command_ucloudlink_qcrsrp() {
    local _qcrsrp

    _qcrsrp="$1"

    json_init
    json_add_string "PCI" "$(echo "$_qcrsrp"|cut -d, -f1)"
    json_add_int "RSRP" "$(echo "$_qcrsrp"|cut -d, -f3|sed 's/\"//g')"
    json_add_int "DL_FREQ" "$(echo "$_qcrsrp"|cut -d, -f2)"

    json_dump
    json_cleanup
}

_command_ucloudlink_cops() {
    local _cops _mode

    _cops="$1"
    _mode="$(echo "$_cops"|cut -d, -f4)"

    json_init
    if [ "$_mode" -le 3 ]; then
        json_add_string "MODE" "GSM"
    elif [ "$_mode" -lt 7 ] ; then
        json_add_string "MODE" "WCDMA"
    elif [ "$_mode" -eq 7 ] || [ "$_mode" -eq 15 ]; then
        json_add_string "MODE" "LTE"
    else
        json_add_string "MODE" "UNKNOWN"
    fi
    json_add_string "ISP" "$(echo "$_cops"|cut -d, -f3|sed 's/\"//g')"

    json_dump
    json_cleanup
}

command_ucloudlink_basic() {
    local _ctl="$1"
    local _info="$2"
    local _res _imsi _iccid _mode _model _revision _qcrsrp _cops
    local _cmd

    _cmd="AT\$QCRSRP?|AT\$QCRSRQ?|AT+CSQ|${AT_GENERIC_PREFIX}COPS=3,2|${AT_GENERIC_PREFIX}COPS?|${AT_GENERIC_PREFIX}CIMI|${AT_GENERIC_PREFIX}ICCID"
    _res=$(_command_exec_raw "$_ctl" "$_cmd")
    [ -z "$_res" ] && return 1
    _imsi="$(echo "$_res"|grep 'CIMI' -A2|sed -n '2p'|xargs -r printf)"
    _iccid="$(echo "$_res"|grep 'ICCID:'|awk -F' ' '{print $2}')"
    _qcrsrp="$(echo "$_res"|grep "QCRSRP:"|cut -d' ' -f2)"
    _cops="$(echo "$_res"|grep "COPS:"|cut -d' ' -f2)"

    _qcrsrp=$(_command_ucloudlink_qcrsrp "$_qcrsrp")
    _cops=$(_command_ucloudlink_cops "$_cops")

    _qcrsrq="$(echo "$_res"|grep "QCRSRQ:"|cut -d' ' -f2)"
    _qcrsrq=$(_command_ucloudlink_qcrsrq "$_qcrsrq")
    
    _sinr="$(echo "$_res"|grep "CSQ:"|cut -d' ' -f2)"
    _sinr=$(_command_ucloudlink_sinr "$_sinr")

    _imei="$(uci -q get "cellular_init.$gNet.imei")"
    _model="$(uci -q get "cellular_init.$gNet.model")"
    _revision="$(uci -q get "cellular_init.$gNet.version")"
    
    json_init
    json_add_string "MODE" "$(echo "$_cops"|jsonfilter -e '$["MODE"]')"
    json_add_string "ISP" "$(echo "$_cops"|jsonfilter -e '$["ISP"]'|awk '$1= $1')"
    json_add_string "PCI" "$(echo "$_qcrsrp"|jsonfilter -e '$["PCI"]')"
    json_add_string "RSRP" "$(echo "$_qcrsrp"|jsonfilter -e '$["RSRP"]')"
    json_add_string "SINR" "$(echo "$_sinr"|jsonfilter -e '$["SINR"]')"
    json_add_string "RSRQ" "$(echo "$_qcrsrq"|jsonfilter -e '$["RSRQ"]')"
    json_add_string "DL_FREQ" "$(echo "$_qcrsrp"|jsonfilter -e '$["DL_FREQ"]')"
    json_add_string "IMEI" "$_imei"
    json_add_string "IMSI" "$_imsi"
    json_add_string "ICCID" "$_iccid"
    json_add_string "MODEL" "$_model"
    json_add_string "REVISION" "$_revision"
    json_dump
    json_cleanup
}

command_ucloudlink_signal() {
    local _res
    local _qcrsrp

    _res=$(_command_exec_raw "$1" "AT\$QCRSRP?|${AT_GENERIC_PREFIX}COPS=3,2|${AT_GENERIC_PREFIX}COPS?")
    [ -z "$_res" ] && return 1

    _qcrsrp="$(echo "$_res"|grep "QCRSRP:"|cut -d' ' -f2)"
    _cops="$(echo "$_res"|grep "COPS:"|cut -d' ' -f2)"

    _cops=$(_command_ucloudlink_cops "$_cops")
    _qcrsrp=$(_command_ucloudlink_qcrsrp "$_qcrsrp")

    json_init
    json_add_string "MODE" "$(echo "$_cops"|jsonfilter -e '$["MODE"]')"
    json_add_object "$(echo "$_cops"|jsonfilter -e '$["MODE"]')"
    json_add_string "RSRP" "$(echo "$_qcrsrp"|jsonfilter -e '$["RSRP"]')"
    json_close_object
    json_dump
    json_cleanup
}

command_ucloudlink_preinit() {
    local _ctl="$1"
    local _info="$2"
    local _gateway=

    _res=$(_command_exec_raw "$_ctl" "AT#SETHOSTNAME=\"C9\"")
    # modify gateway IP for Indonesia customer
    if [ -f "/usr/sbin/ul_ipsec_recovery.sh" ]; then
        _res=$(_command_exec_raw "$_ctl" "AT#GATEWAY?")
        [ -z "$_res" ] && return 1
        _gateway=$(echo "$_res"|grep "^#GATEWAY:"|awk -F' ' '{print $2}')
        if echo "${_gateway}"|grep -q "192.168"; then
            _gateway=$(echo "$_gateway"|sed 's/192.168/172.16/')
            _res=$(_command_exec_raw "$_ctl" "AT#GATEWAY=${_gateway}")
            cpetools.sh -i "${gNet}" -r
            return 1
        fi
    fi

    return 0
}


command_ucloudlink_cpin() {
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

_command_ucloudlink_imei(){
    local _res _data

    _res=$(_command_exec_raw "$1" "AT#UCIMEI?"|grep "#UCIMEI:")
    [ -z "$_res" ] && return
    _data=$(echo "$_res"|awk -F: '{print $2}'|sed 's/ //g'|xargs -r printf)
    echo "$_data"
}

command_ucloudlink_imei(){
    local _ctl="$1"
    local _info="$2"
    local _res _imei _card
    local _cmd
    local _cur=$(uci -q get "cpesel.sim.cur")
    local _gval=$(uci -q get cpesel.sim.gval)
    local _uval=""

    [ -z "$_cur" ] && _cur="1"
    if [ -n "$_gval" ];then
        local _cur_gval=$(echo "$_gval"|cut -d, -f "$_cur")
        if [ -n "$_cur_gval" ];then
            _uval=$(echo "$_cur_gval"|awk -F'-' '{print $2}')
        fi
    fi
    _command_ucloudlink_set_card "$_ctl" "1"
    result=$?

    if [ $result -eq 0 ];then
        _imei=$(_command_ucloudlink_imei "$_ctl")
        if [ -z "$_uval" -o "$_uval" == "1" ] && ! _command_ucloudlink_set_card "$_ctl" "0"; then
            return 1
        fi
    elif [ $result -eq 2 ];then
        _imei=$(_command_ucloudlink_imei "$_ctl")
        if [ "$_uval" == "1" ] && ! _command_ucloudlink_set_card "$_ctl" "0"; then
            return 1
        fi
    else
        return 1
    fi

    [ -z "$_imei" ] && return 1
    echo "$_imei"
}
command_ucloudlink_model(){
    local _ctl="$1"
    local _info="$2"
    local _res _model
    local _cmd

    _cmd="ATI"

    _res=$(_command_exec_raw "$_ctl" "$_cmd" "1")
    _model="$(echo "$_res"|grep 'UKELINK' -A2|sed -n '2p'|xargs -r printf)"
    echo "$_model"
}

command_ucloudlink_version(){
    local _ctl="$1"
    local _info="$2"
    local _res _revision
    local _cmd
    _cmd="ATI"

    _res=$(_command_exec_raw "$_ctl" "$_cmd" "1")
    _revision="$(echo "$_res"|grep 'UKELINK' -A2|sed -n '3p'|xargs -r printf)"

    echo "$_revision"
}


command_ucloudlink_sn(){
    local _ctl="$1"
    echo "ucloudlink000000"
}

command_ucloudlink_usim_get() {
    local _res _data

    _res=$(_command_exec_raw "$1" "AT#UDEVMODE?"|grep "#UDEVMODE:")
    [ -z "$_res" ] && return
    _data=$(echo "$_res"|awk -F: '{print $2}'|sed 's/ //g'|xargs -r printf)
    echo "$_data"
}

command_ucloudlink_usim_set() {
    local _ctl="$1"
    local _new="$2"
    local _card="1"
    local _res
    local reset=0
    if [ "$_new" == "1" ];then
        _card="0"
    fi
    _old=$(command_ucloudlink_usim_get "$_ctl")

    if [ "$_old" != "$_new" ];then
        _res=$(_command_exec_raw "$1" "AT#UDEVMODE=${_new}" "5" "3"|grep "OK") 
        [ -z "$_res" ] && return 1
        reset=1
    fi
    if _command_ucloudlink_set_card "$1" "$_card" ;then
        reset=1
    fi

    if [ $reset -eq 1 ];then
        command_generic_reset "$_ctl"
    fi
    return 0
}

