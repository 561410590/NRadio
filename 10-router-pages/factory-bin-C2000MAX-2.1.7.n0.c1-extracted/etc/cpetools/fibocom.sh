#!/bin/ash

_command_fibocom_band_convert() {
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

command_fibocom_signal2() {
	local _res

	_res=$(_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCCINFO?")
	[ -z "$_res" ] && return 1
	_command_fibocom_hcsq "$_res"	
}

command_fibocom_cellinfo2() {
	local _res 
	local _ctl="$1"
	_res=$(_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCCINFO?")
	[ -z "$_res" ] && return 1
	_command_fibocom_cellinfo "$_res" 
}

_command_fibocom_nr_rsrp_convert() {
	local _val
	_val="$1"
	[ "$_val" -eq 255 ] && echo -n "255" && return
	[ "$_val" -ge 126 ] && echo -n "-31" && return
	[ "$_val" -eq 0 ] && echo -n "-156" && return
	echo "$_val"|awk '{print -31-(126-$1)}'
}

_command_fibocom_nr_rsrq_convert() {
	local _val
	_val="$1"
	[ "$_val" -eq 255 ] && echo -n "255" && return
	[ "$_val" -ge 127 ] && echo -n "20" && return
	[ "$_val" -eq 0 ] && echo -n "-43" && return
	echo "$_val"|awk '{print 20-(127-$1)*0.5}'
}

_command_fibocom_nr_sinr_convert() {
	local _val
	_val="$1"
	[ "$_val" -eq 255 ] && echo -n "255" && return
	[ "$_val" -ge 127 ] && echo -n "40" && return
	[ "$_val" -eq 0 ] && echo -n "-23" && return
	echo "$_val"|awk '{print 40-(127-$1)*0.5}'
}


_command_fibocom_hcsq() {
	local _cellinfo
	_cellinfo="$1"
	_info=""
	_mode=""
	_nr="$(echo "$_cellinfo"|grep 'NR service cell' -A2|sed -n '2p'|xargs -r printf)"
	_lte="$(echo "$_cellinfo"|grep 'LTE service cell' -A2|sed -n '2p'|xargs -r printf)"
	_nsa="$(echo "$_cellinfo"|grep 'LTE-NR EN-DC service cell' -A2|sed -n '2p'|xargs -r printf)"
	_umts="$(echo "$_cellinfo"|grep 'UMTS service cell' -A2|sed -n '2p'|xargs -r printf)"

	[ -n "$_nr" ] && {
		_mode="NR SA"
		_info="$_nr"
	}
	[ -n "$_nsa" ] && {
		_mode="NR NSA"
		_info="$_nsa"
	}
	[ -n "$_lte" ] && {
		_mode="LTE"
		_info="$_lte"
	}
	[ -n "$_umts" ] && {
		_mode="WCDMA"
		_info="$_umts"
	}

	json_init
	if [ "$_mode" = "WCDMA" ]; then
		json_add_object "$_mode"
		_val="$(echo "$_info"|cut -d, -f4)"
		json_add_int "RSSI" "$(_command_huawei_rssi_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f6)"
		json_add_int "RSCP" "$(_command_huawei_rscp_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f5)"
		json_add_int "ECIO" "$(_command_huawei_ecio_convert "$_val")"
	elif [ "$_mode" = "LTE" ]; then
		json_add_object "$_mode"
		_val="$(echo "$_info"|cut -d, -f4)"
		json_add_int "RSSI" "$(_command_huawei_rssi_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f6)"
		json_add_int "RSRP" "$(_command_huawei_rsrp_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f7)"
		json_add_int "SINR" "$(_command_huawei_sinr_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f5)"
		json_add_int "RSRQ" "$(_command_huawei_rsrq_convert "$_val")"
	elif [ "$_mode" = "NR SA" ]; then
		json_add_object "$_mode"
		_val="$(echo "$_info"|cut -d, -f11)"
		json_add_int "SINR" "$(_command_fibocom_nr_sinr_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f12)"
		json_add_int "RSRP" "$(_command_fibocom_nr_rsrp_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f14)"
		json_add_int "RSRQ" "$(_command_fibocom_nr_rsrq_convert "$_val")"
	elif [ "$_mode" = "NR NSA" ]; then
		json_add_object "$_mode"				
		_val="$(echo "$_info"|cut -d, -f11)"
		json_add_int "RSRP" "$(_command_fibocom_nr_rsrp_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f13)"
		json_add_int "RSRQ" "$(_command_fibocom_nr_rsrq_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f14)"
		json_add_int "SINR" "$(_command_fibocom_nr_sinr_convert "$_val")"
	fi
	json_close_object

	json_add_string "MODE" "$_mode"
	json_dump
	json_cleanup
}

_command_fibocom_cellinfo() {
	local _cellinfo
	_cellinfo="$1"
	_info=""
	_mode=""
	_nr="$(echo "$_cellinfo"|grep 'NR service cell' -A2|sed -n '2p'|xargs -r printf)"
	_lte="$(echo "$_cellinfo"|grep 'LTE service cell' -A2|sed -n '2p'|xargs -r printf)"
	_nsa="$(echo "$_cellinfo"|grep 'LTE-NR EN-DC service cell' -A2|sed -n '2p'|xargs -r printf)"
	_umts="$(echo "$_cellinfo"|grep 'UMTS service cell' -A2|sed -n '2p'|xargs -r printf)"

	[ -n "$_nr" ] && {
		_mode="NR SA"
		_info="$_nr"
	}
	[ -n "$_nsa" ] && {
		_mode="NR NSA"
		_info="$_nsa"
	}
	[ -n "$_lte" ] && {
		_mode="LTE"
		_info="$_lte"
	}
	[ -n "$_umts" ] && {
		_mode="WCDMA"
		_info="$_umts"
	}

	json_init
	_isp="$(echo "$_info"|cut -d, -f3)$(echo "$_info"|cut -d, -f4)"
	json_add_string "ISP" "$_isp"
	json_add_string "MODE" "$_mode"

	if [ "$_mode" = "LTE" ]; then
		pci="$(echo "$_info"|cut -d, -f8)"
		[ -n "$pci" ] && pci=$(printf %d 0x$pci)
		earfcn="$(echo "$_info"|cut -d, -f7)"
		[ -n "$earfcn" ] && earfcn=$(printf %d 0x$earfcn)
		band="$(echo "$_info"|cut -d, -f9)"
		cell="$(echo "$_info"|cut -d, -f6)"
		tac="$(echo "$_info"|cut -d, -f5)"
		json_add_string "CELL" "$cell"
		json_add_int "EARFCN" "$earfcn"
		json_add_string "PCI" "$pci"
		json_add_string "TAC" "$tac"
		json_add_int "BAND" "$band"
		_val="$(echo "$_info"|cut -d, -f11)"
		json_add_int "RSSI" "$(_command_huawei_rssi_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f13)"
		json_add_int "RSRP" "$(_command_huawei_rsrp_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f14)"
		json_add_int "RSRQ" "$(_command_huawei_rsrq_convert "$_val")"
	elif [ "$_mode" = "WCDMA" ]; then
		earfcn="$(echo "$_info"|cut -d, -f7)"
		[ -n "$earfcn" ] && earfcn=$(printf %d 0x$earfcn)
		json_add_string "CELL" "$(echo "$_cellinfo"|cut -d, -f6)"
		json_add_string "LAC" "$(echo "$_cellinfo"|cut -d, -f5)"
		json_add_int "BAND" "$(echo "$_cellinfo"|cut -d, -f9)"
		json_add_int "EARFCN" "$earfcn"
		_val="$(echo "$_info"|cut -d, -f13)"
		json_add_int "RSSI" "$(_command_huawei_rssi_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f11)"
		json_add_int "RSCP" "$(_command_huawei_rscp_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f15)"
		json_add_int "ECIO" "$(_command_huawei_ecio_convert "$_val")"

	elif [ "$_mode" = "NR SA" ]; then
		band="$(echo "$_info"|cut -d, -f9)"
		[ -n "$band" ] && band=$(echo $band|sed -e 's/50//')
		pci="$(echo "$_info"|cut -d, -f8)"
		[ -n "$pci" ] && pci=$(printf %d 0x$pci)
		earfcn="$(echo "$_info"|cut -d, -f7)"
		[ -n "$earfcn" ] && earfcn=$(printf %d 0x$earfcn)
		cell="$(echo "$_info"|cut -d, -f6)"
		tac="$(echo "$_info"|cut -d, -f5)"
		json_add_int "EARFCN" "$earfcn"
		json_add_int "BAND" "$band"
		json_add_string "CELL" "$cell"
		json_add_string "PCI" "$pci"
		json_add_string "TAC" "$tac"

		_val="$(echo "$_info"|cut -d, -f11)"
		json_add_int "SINR" "$(_command_fibocom_nr_sinr_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f12)"
		json_add_int "RSRP" "$(_command_fibocom_nr_rsrp_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f14)"
		json_add_int "RSRQ" "$(_command_fibocom_nr_rsrq_convert "$_val")"
			
	elif [ "$_mode" = "NR NSA" ]; then
		band="$(echo "$_info"|cut -d, -f9)"
		[ -n "$band" ] && band=$(echo $band|sed -e 's/50//')
		pci="$(echo "$_info"|cut -d, -f8)"
		[ -n "$pci" ] && pci=$(printf %d 0x$pci)
		earfcn="$(echo "$_info"|cut -d, -f7)"
		[ -n "$earfcn" ] && earfcn=$(printf %d 0x$earfcn)
		cell="$(echo "$_info"|cut -d, -f6)"
		tac="$(echo "$_info"|cut -d, -f5)"
		json_add_int "EARFCN" "$earfcn"
		json_add_int "BAND" "$band"
		json_add_string "CELL" "$cell"
		json_add_string "PCI" "$pci"
		json_add_string "TAC" "$tac"

		_val="$(echo "$_info"|cut -d, -f11)"
		json_add_int "RSRP" "$(_command_fibocom_nr_rsrp_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f13)"
		json_add_int "RSRQ" "$(_command_fibocom_nr_rsrq_convert "$_val")"
		_val="$(echo "$_info"|cut -d, -f14)"
		json_add_int "SINR" "$(_command_fibocom_nr_sinr_convert "$_val")"
	fi
	json_dump
	json_cleanup
}

command_fibocom_basic2() {
	local _ctl="$1"
	local _info="$2"
	local _res _imei _imsi _iccid _hcsq _mode _model _revision
	local _cmd

	local apn="$(command_fibocom_apn "$_ctl" "$_info"|jsonfilter -e "\$['APN']")"
	_cmd="${AT_GENERIC_PREFIX}CIMI|${AT_GENERIC_PREFIX}ICCID"
	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1

	_imsi="$(echo "$_res"|grep 'CIMI' -A2|sed -n '2p'|xargs -r printf)"	

	_imei="$(uci -q get "cellular_init.$gNet.imei")"
	_model="$(uci -q get "cellular_init.$gNet.model")"
	_revision="$(uci -q get "cellular_init.$gNet.version")"
	_iccid="$(echo "$_res"|grep 'ICCID:'|awk -F' ' '{print $2}')"

	_res=$(_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCCINFO?")
	_cellinfo="$(_command_fibocom_cellinfo "$_res"))"

	json_init
	json_add_string "ISP" "$(echo "$_cellinfo"|jsonfilter -e '$["ISP"]'|awk '$1= $1')"
	json_add_string "CELL" "$(echo "$_cellinfo"|jsonfilter -e '$["CELL"]')"
	json_add_string "PCI" "$(echo "$_cellinfo"|jsonfilter -e '$["PCI"]')"
	json_add_string "TAC" "$(echo "$_cellinfo"|jsonfilter -e '$["TAC"]')"
	json_add_string "EARFCN" "$(echo "$_cellinfo"|jsonfilter -e '$["EARFCN"]')"
	json_add_string "MODE" "$(echo "$_cellinfo"|jsonfilter -e '$["MODE"]')"
	json_add_string "BAND" "$(echo "$_cellinfo"|jsonfilter -e "$['BAND']")"
	json_add_string "RSRP" "$(echo "$_cellinfo"|jsonfilter -e "$['RSRP']")"
	json_add_string "SINR" "$(echo "$_cellinfo"|jsonfilter -e "$['SINR']")"
	json_add_string "RSRQ" "$(echo "$_cellinfo"|jsonfilter -e "$['RSRQ']")"
	json_add_string "RSSI" "$(echo "$_cellinfo"|jsonfilter -e "$['RSSI']")"
	json_add_string "RSCP" "$(echo "$_cellinfo"|jsonfilter -e "$['RSCP']")"
	json_add_string "IMEI" "$(generic_validate_imei "$_imei")"
	json_add_string "IMSI" "$(generic_validate_imsi "$_imsi")"
	json_add_string "ICCID" "$(generic_validate_iccid "$_iccid")"
	json_add_string "MODEL" "$_model"
	json_add_string "REVISION" "$_revision"
	json_add_string "SIMNUMBER" "$(command_generic_number "$1")"
	json_add_string "APN" "$apn"
	json_dump
	json_cleanup
}

command_fibocom_iccid2() {
	local _res _info

	_res=$(_command_generic_exec "$1" "ICCID")
	[ -z "$_res" ] && return 1

	_info="$(echo "$_res"|awk -F' ' '{print $2}')"

	echo "$_info"
}


command_fibocom_nroff2() {
	_command_fibocom_mode "$1" "3"
	if [ $? -eq 0 ];then
		command_generic_reset "$_ctl"
	fi	
}

command_fibocom_modewcdma2() {
	_command_fibocom_mode "$1" "2"
	if [ $? -eq 0 ];then
		command_generic_reset "$_ctl"
	fi	
}


_command_fibocom_mode_pref() {
	local _res _info

	_res=$(_command_generic_exec "$1" "GTRAT" "?")
	[ -z "$_res" ] && return 1

	_info=$(echo "$_res"|awk -F: '{print $2}'|awk '$1= $1'|xargs -r printf)
	echo "$_info"
}

_command_fibocom_mode_pref_set() {
	local _ctl="$1"
	local _mode="$2"

	_command_generic_exec "$_ctl" "GTRAT" "=$_mode"
}

_command_fibocom_mode() {
	local _ctl="$1"
	local _mode="$2"
	local _mode_pref

	_mode_pref=$(_command_fibocom_mode_pref "$_ctl")

	[ -z "$_mode_pref" ] && return 1
	if [ "$_mode_pref" = "$_mode" ]; then
		return 2
	fi

	_command_fibocom_mode_pref_set "$_ctl" "$_mode"

	return 0
}

command_fibocom_allmode2() {
	local _info="$2"
	local _nrcap

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')	
	if [ "$_nrcap" = "1" ]; then
		_command_fibocom_mode "$1" "20,6,3"
		if [ $? -eq 0 ];then
			command_generic_reset "$_ctl"
		fi
	fi
}

command_fibocom_modesa2() {
	local _info="$2"
	local _nrcap

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')

	if [ "$_nrcap" = "1" ]; then
		_command_fibocom_mode "$1" "20,6,3"
		if [ $? -eq 0 ];then
			command_generic_reset "$_ctl"
		fi
	fi
}

command_fibocom_modensa2() {
	local _info="$2"
	local _nrcap

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')

	if [ "$_nrcap" = "1" ]; then
		_command_fibocom_mode "$1" "20,6,3"
		if [ $? -eq 0 ];then
			command_generic_reset "$_ctl"
		fi
	fi
}

command_fibocom_modesa_only2() {
	local _info="$2"
	local _nrcap

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')
	if [ "$_nrcap" = "1" ]; then
		_command_fibocom_mode "$1" "14"
		if [ $? -eq 0 ];then
			command_generic_reset "$_ctl"
		fi
	fi
}

command_fibocom_modensa_only2() {
	local _info="$2"
	local _nrcap

	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')
	if [ "$_nrcap" = "1" ]; then
		_command_fibocom_mode "$1" "14"
		if [ $? -eq 0 ];then
			command_generic_reset "$_ctl"
		fi
	fi
}

command_fibocom_roam2() {
	local _ctl="$1"
	local _mode="$2"
	local _res _info

	_res=$(_command_generic_exec "$1" "GTROAMCFG" "?")
	[ -z "$_res" ] && return 1

	_info=$(echo "$_res"|awk -F' ' '{print $2}'|awk -F',' '{print $1}'|xargs -r printf)

	if [ "$_info" = "$_mode" ]; then
		return 0
	fi
	_command_generic_exec "$_ctl" "GTROAMCFG" "=$_mode"

	return 0
}

command_fibocom_model2() {
	command_huawei_model "$@"
}

command_fibocom_sn2(){
	local _ctl="$1"

	_res=$(_command_generic_exec "$_ctl" "CFSN")
	[ -z "$_res" ] && echo ""

	echo "$_res" | cut -d':' -f2|sed 's/\"//g'|xargs -r printf
}

_command_fibocom_get_freq() {
	local _ctl="$1"
	local _res _info

	_res=$(_command_generic_exec "$1" "GTACT" "?")
	[ -z "$_res" ] && return 1

	_info=$(echo "$_res"|awk -F: '{print $2}'|xargs -r printf)
	echo "$_info"

	return 0
}


_command_fibocom_set_freq() {
	local _ctl="$1"
	local _freq_info="$2"
	local _res

	_res=$(_command_generic_exec "$1" "GTACT" "=$_freq_info")
	[ -z "$_res" ] && return 1
	return 0
}

_command_fibocom_freq_set() {
	local _ctl="$1"
	local _lte_info="$2"
	local _nr_info="$3"
	local _syscfg

	lte_info=$(_command_fibocom_caculate_freq "$_lte_info" 10)
	nr_info=$(_command_fibocom_caculate_freq "$_nr_info" 50)
	_band_info=$(_command_fibocom_get_freq "$_ctl")
	local first_p=$(echo "$_band_info"|awk -F',' '{print $1}'|xargs -r printf)
	local sec_p=$(echo "$_band_info"|awk -F',' '{print $2}'|xargs -r printf)
	local third_p=$(echo "$_band_info"|awk -F',' '{print $3}'|xargs -r printf)

	if [ "$first_p" == "2" ];then
		freq_info="$first_p,$sec_p,$third_p,$lte_info"
	elif [ "$first_p" == "14" ];then
		freq_info="$first_p,$sec_p,$third_p,$nr_info"
	else
		freq_info="$first_p,$sec_p,$third_p,$lte_info,$nr_info"
	fi

	if [ "$freq_info" = "$_band_info" ]; then
		return 2
	fi

	echo "do set freq lte:$lte_info,nr:$nr_info"
	_command_fibocom_set_freq "$_ctl" "$freq_info"

	return 0
}

_command_fibocom_caculate_freq(){	
	local freq_item=$1
	local unit=$2
	local freq_data=""
	dataArray=${freq_item//:/ }
	for key in $dataArray;do
		if [ $unit -eq 10 ];then
			key="$((key+100))"
		else
			key="${unit}${key}"
		fi
		freq_data="${freq_data:+${freq_data},}$key"
	done
	echo "$freq_data"
}

command_fibocom_freq2() {
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
		_command_fibocom_freq_set "$_ctl" "$_lte" "$_nr"
	fi
	return 0
}

_command_fibocom_freq_get() {
	local _res
	local mode="$2"
	local _enable="0"
	local _mode=""
	local _type=""
	local _earfcn=""
	local _pci=""
	local _scs=""
	local _band=""

	_res=$(_command_generic_exec "$1" "GTCELLLOCK" "?"|grep "+GTCELLLOCK:")
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

			if [ "$mode" == "NR" -a "$_mode_tmp" == "1" ] || [ "$mode" == "LTE" -a "$_mode_tmp" == "0" ] ;then
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

_earfcn_fibocom_5glock(){
	local _freqcfg _enable _band
	local _ctl="$1"
	local _info="$2"
	local earfcn="$3"
	local pci="$4"
	local band="$5"
	local scs="0"
	local specail=0

	local model_desc=$(uci -q get "network.cpe${gIndex}.desc")
	if echo "$model_desc"|grep -qs "FM6";then
		specail=1
	fi

	_freqcfg=$(_command_fibocom_freq_get "$_ctl" "NR")
	[ -z "$_freqcfg" ] && return 1
	_enable=$(echo "$_freqcfg"|jsonfilter -e '$["enable"]')

	if [ -z "$earfcn" -o "$earfcn" == "0" ];then
		if [ "$_enable" != "0" ];then
			echo "earfcn5 nr free"
			_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCELLLOCK=0" 4
			if [ $specail -eq 1 ];then	
				command_generic_reset "$_ctl"
			else
				echo "earfcn5 nr power model"
				$(cpetools.sh -r)
			fi
		fi
		return 0
	fi

	if [ "$band" == "1" -o "$band" == "2" -o "$band" == "3" -o "$band" == "5" -o "$band" == "7" -o "$band" == "8" -o "$band" == "12" -o "$band" == "20" -o "$band" == "25" -o "$band" == "28" -o "$band" == "66" -o "$band" == "71" -o "$band" == "75" -o "$band" == "76" ];then
		scs="0"
	elif [ "$band" == "38" -o "$band" == "40" -o "$band" == "41" -o "$band" == "48" -o "$band" == "77" -o "$band" == "78" -o "$band" == "79" ];then
		scs="1"
	elif [ "$band" == "257" -o "$band" == "258" -o "$band" == "260" -o "$band" == "261" ];then
		scs="0"
	fi

	_type=$(echo "$_freqcfg"|jsonfilter -e '$["type"]')
	if [ -z "$pci" -o "$pci" == "0" ];then
		if [ "$_enable" == "1" ];then
			_scs=$(echo "$_freqcfg"|jsonfilter -e '$["scstype"]')
			_earfcn=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')
			if [ "$_type" == "1" ];then
				if [ $specail -eq 1 ];then
					if [ "$earfcn" == "$_earfcn" ];then
						return 2
					fi
				else
					if [ "$earfcn" == "$_earfcn" -a "$scs" == "$_scs" ];then
						return 2
					fi
				fi
			fi	
		fi
		echo "earfcn5 set nr earfcn:$earfcn,old_earfcn:$_earfcn|scs:$scs,old_scs:$_scs"
		[ "$_enable" != "0" ] && _command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCELLLOCK=0" 4
		
		if [ $specail -eq 1 ];then
			if _command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCELLLOCK=1,1,1,$earfcn" 4|grep -qs "OK" ;then
				command_generic_reset "$_ctl"
			fi
		else
			if _command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCELLLOCK=1,1,1,$earfcn,,$scs" 4|grep -qs "OK";then
				echo "earfcn5 nr power model"
				$(cpetools.sh -r)
				return 0
			fi
		fi
	else
		band="50${band}"
		if [ "$_enable" == "1" ];then
			_band=$(echo "$_freqcfg"|jsonfilter -e '$["band"]')
			_earfcn=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')
			_pci=$(echo "$_freqcfg"|jsonfilter -e '$["cellid"]')
			if [ "$_type" == "0" ];then
				if [ $specail -eq 1 ];then
					if [ "$earfcn" == "$_earfcn" -a "$pci" == "$_pci" ];then
						return 2
					fi
				else
					if [ "$earfcn" == "$_earfcn" -a "$band" == "$_band" -a "$pci" == "$_pci" ];then
						return 2
					fi
				fi
			fi
		fi
		echo "earfcn5 set nr earfcn:$earfcn,old_earfcn:$_earfcn|band:$band,old_band:$_band|pci:$pci,old_pci:$_pci"
		
		[ "$_enable" != "0" ] && _command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCELLLOCK=0" 4

		
		if [ $specail -eq 1 ];then
			if _command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCELLLOCK=1,1,0,$earfcn,$pci" 4|grep -qs "OK" ;then
				command_generic_reset "$_ctl"
			fi
		else
			if _command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCELLLOCK=1,1,0,$earfcn,$pci,$scs,$band" 4|grep -qs "OK" ;then
				echo "earfcn5 nr power model"
				$(cpetools.sh -r)
				return 0
			fi
		fi
	fi
	return 1
}

_earfcn_fibocom_5g_4glock(){
	local _freqcfg _enable _band
	local _ctl="$1"
	local _info="$2"
	local earfcn="$3"
	local pci="$4"

	local specail=0

	local model_desc=$(uci -q get "network.cpe${gIndex}.desc")
	if echo "$model_desc"|grep -qs "FM6";then
		specail=1
	fi

	_freqcfg=$(_command_fibocom_freq_get "$_ctl" "LTE")
	[ -z "$_freqcfg" ] && return 1
	_enable=$(echo "$_freqcfg"|jsonfilter -e '$["enable"]')

	if [ -z "$earfcn" -o "$earfcn" == "0" ];then
		if [ "$_enable" != "0" ];then
			echo "earfcn5 lte free"
			_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCELLLOCK=0" 4
			if [ $specail -eq 1 ];then	
				command_generic_reset "$_ctl"
			else
				echo "earfcn5 lte power model"
				$(cpetools.sh -r)
			fi
		fi
		return 0
	fi
	_type=$(echo "$_freqcfg"|jsonfilter -e '$["type"]')
	if [ -z "$pci" -o "$pci" == "0" ];then
		if [ "$_enable" == "1" ];then
			_earfcn=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')
			if [ "$_type" == "1" ];then				
				if [ "$earfcn" == "$_earfcn" ];then
					return 0
				fi
			fi	
		fi
		echo "earfcn5 set lte earfcn:$earfcn,old_earfcn:$_earfcn"
		[ "$_enable" != "0" ] && _command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCELLLOCK=0" 4
		
		if _command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCELLLOCK=1,0,1,$earfcn" 4|grep -qs "OK" ;then
			if [ $specail -eq 1 ];then	
				command_generic_reset "$_ctl"
			else
				echo "earfcn5 lte power model"
				$(cpetools.sh -r)
			fi
		fi
	else
		if [ "$_enable" == "1" ];then
			_earfcn=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')
			if [ "$_type" == "0" ];then				
				_pci=$(echo "$_freqcfg"|jsonfilter -e '$["cellid"]')

				if [ "$earfcn" == "$_earfcn" -a "$pci" == "$_pci" ];then
					return 0
				fi
			fi
		fi
		echo "earfcn5 set lte earfcn:$earfcn,old_earfcn:$_earfcn|pci:$pci,old_pci:$_pci"
		
		[ "$_enable" != "0" ] && _command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCELLLOCK=0" 4
		if _command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}GTCELLLOCK=1,0,0,$earfcn,$pci" 4|grep -qs "OK" ;then
			if [ $specail -eq 1 ];then
				command_generic_reset "$_ctl"
			else
				echo "earfcn5 lte power model"
				$(cpetools.sh -r)
			fi
		fi
	fi
}

command_fibocom_msmpd2(){
	local _ctl="$1"
	local _data
	local _res
	local val="0"
	local target=""

	_res=$(_command_generic_exec "$_ctl" "MSMPD" "?")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		if [ -n "$_data" ];then
			echo  "get gtset MSMPD:$_data"
			target=$(echo "$_data"|awk -F',' '{print $2}'|xargs -r printf)
			if [ "$target" != "$val" ]; then
				echo  "gtset :set $val"
				_command_generic_exec "$_ctl" "MSMPD" "=$val"
				return 0
			fi
		fi
	fi

	return 1
}

command_fibocom_prepare2(){
	local _ctl="$1"

	command_fibocom_msmpd2 "$_ctl"
	return 0
}

command_fibocom_earfcn2() {
	local _ctl="$1"
	local _info="$2"
	local mode="$3"
	local earfcn="$4"
	local pci="$5"
	local band="$6"
	local _res _info

	_res=$(_command_generic_exec "$1" "GTCELLLOCK" "?")
	if [ -z "$_res" ];then
		return 0
	fi
	if [ "$mode" == "NR" ];then
		_earfcn_fibocom_5glock "$_ctl" "$_info" "$earfcn" "$pci" "$band"
	elif [ "$mode" == "LTE" ];then
		_earfcn_fibocom_5g_4glock "$_ctl" "$_info" "$earfcn" "$pci"
	else
		return 0
	fi
}

_common_fibocom_scannr(){
	local _ctl="$1"
	local scan_param="$2"
	local scan_cache="/tmp/infocd/tmp/${gNet}scan_cache"
	local max=16
	local i=0

	json_init
	json_add_array "scanlist"

	$(echo -n "+GTCELLSCAN:" > /tmp/${gNet}scan_async_key)
	_res=$(_command_exec_raw "$_ctl" "AT+GTCELLSCAN"|grep "OK")

	[ -z "$_res" ] && {		
		json_close_array
		json_dump
		json_cleanup
		return 0
	} 

	while true;do		
		if [ -f "$scan_cache" ];then
			_res=$(cat "$scan_cache"|grep "GTCELLSCAN: ")
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
	_res_cimi=$(command_generic_imsi "$_ctl")
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_info="$(echo "$line"|awk -F'GTCELLSCAN: ' '{print $2}')"
			_mode_info=$(echo "$_info"|awk -F, '{print $1}'|xargs -r printf)
			[ "$scan_param" != "$_mode_info" ] && continue
			_mcc=$(echo "$_info"|awk -F, '{print $2}'|xargs -r printf)
			_mnc=$(echo "$_info"|awk -F, '{print $3}'|xargs -r printf)
			[ -z "$_mnc" ] && continue
			_isp="${_mcc}${_mnc}"
			local isp_match=0
			if [ -n "$_res_cimi" ];then
					_isp_len=${#_isp}
					isp=${_res_cimi:0:$_isp_len}
					_scan_company=$(jsonfilter -e '@[@.plmn[@="'$_isp'"]].company' </usr/lib/lua/luci/plmn.json )
					_cur_company=$(jsonfilter -e '@[@.plmn[@="'$isp'"]].company' </usr/lib/lua/luci/plmn.json )
					if [ -n "$_scan_company" -a -n "$_cur_company" ];then
						if [ "$_cur_company" == "$_scan_company" ];then
							isp_match=1
						fi
					else
						isp_match=1
					fi
			fi

			if [ $isp_match -eq 1 ];then
				pci="$(echo "$_info"|awk -F, '{print $5}')"
				earfcn="$(echo "$_info"|awk -F, '{print $4}'|sed -e 's/ //g')"	
				[ -n "$pci" ] && pci=$(printf %d 0x$pci)
				[ -n "$earfcn" ] && earfcn=$(printf %d 0x$earfcn)
				if [ "$scan_param" == "5" ];then
						json_add_object 
						json_add_string "MODE" "NR" 
						json_add_string "EARFCN" "$earfcn"
						json_add_string "PCI" "$pci"
						json_add_string "CELL" "$(echo "$_info"|awk -F, '{print $7}')"
						json_add_string "RSRP" "$(echo "$_info"|awk -F, '{print $8}')"
						json_add_string "RSRQ" "$(echo "$_info"|awk -F, '{print $9}')"
						json_add_string "BAND" "$(echo "$_info"|awk -F, '{print $10}')"
						json_add_string "ISP" "$_isp"

						json_add_object "lockneed"
						json_add_string "MODE" "2"
						json_add_string "EARFCN" "1"
						json_add_string "BAND" "1"
						json_add_string "PCI" "0"
						json_close_object

						json_close_object
				elif [ "$scan_param" == "4" ];then
						json_add_object 
						json_add_string "MODE" "LTE"
						json_add_string "EARFCN" "$earfcn"
						json_add_string "PCI" "$pci"
						json_add_string "CELL" "$(echo "$_info"|awk -F, '{print $7}')"
						json_add_string "RSRP" "$(echo "$_info"|awk -F, '{print $8}')"
						json_add_string "RSRQ" "$(echo "$_info"|awk -F, '{print $9}')"
						json_add_string "BAND" "$(echo "$_info"|awk -F, '{print $10}')"
						json_add_string "ISP" "$_isp"

						json_add_object "lockneed"
						json_add_string "MODE" "4"
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

command_fibocom_scan_x(){
	local _ctl="$1"
	local _model
	local _res
	local i=0
	local max=16
	local scan_param="$2"
	local isp=""
	local scan_cache="/tmp/infocd/tmp/${gNet}scan_cache"
	$(echo -n "+SPFREQSCAN:" > /tmp/${gNet}scan_async_key)
	json_init
	json_add_array "scanlist"

	_res_cimi=$(command_generic_imsi "$_ctl")
	_res=$(_command_exec_raw "$_ctl" "AT+SPFREQSCAN=$scan_param,\"\",\"\""|grep "OK")

	[ -z "$_res" ] && {		
		json_close_array
		json_dump
		json_cleanup
		return 0
	} 

	while true;do		
		if [ -f "$scan_cache" ];then
			_res=$(cat "$scan_cache"|grep "SPFREQSCAN: ")
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

				if [ -n "$_rsrp" ];then 
					_rsrp=$((_rsrp/100))
				fi
				if [ -n "$_rsrq" ];then
					_rsrq=$((_rsrq/100))
				fi
				json_add_object 
				json_add_string "ISP" "$_isp"
				json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $3}')"
				json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $2}')"
				json_add_string "RSRP" "$_rsrp"
				json_add_string "RSRQ" "$_rsrq"
				json_add_string "BAND" "$_last_band"
				if [ "$scan_param" == "3" ];then
					json_add_string "MODE" "LTE"
					json_add_object "lockneed"
					json_add_string "MODE" "4"
					json_add_string "EARFCN" "1"
					json_add_string "PCI" "0"
					json_close_object
				else
					json_add_string "MODE" "NR"
					json_add_object "lockneed"
					json_add_string "MODE" "2"
					json_add_string "EARFCN" "1"
					json_add_string "PCI" "0"
					json_close_object
				fi

				json_close_object
			fi
		fi
	done

	json_close_array
	json_dump
	json_cleanup
	return 0
}


command_fibocom_scan2(){
	local _ctl="$1"
	local _model
	local _res
	local _data
	local scan_param="5"
	local isp=""
	local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
	[ -z "$simIndex" ] && simIndex="1"
	local nr_support=$(uci -q get "network.cpe${gIndex}.nrcap")
	local mode=$(uci -q get "cpecfg.cpe${gIndex}sim$simIndex.mode")
	local model_desc=$(uci -q get "network.cpe${gIndex}.desc")
	local odu_model=$(uci -q get "network.cpe${gIndex}.mode")

	if echo "$model_desc"|grep -qs "FM6";then
		scan_param="4"
	fi

	if [ "$nr_support" == "1" ];then
		if [ "$odu_model" == "odu" ];then
			$(touch /tmp/odu_scan_cpe${gIndex})
		fi

		if [ "$mode" == "sa_only" ];then
			scan_param="5"
			if echo "$model_desc"|grep -qs "FM6";then
				scan_param="4"
			fi
		elif [ "$mode" == "lte" ];then
			scan_param="4"
			if echo "$model_desc"|grep -qs "FM6";then
				scan_param="3"
			fi
		fi

		if echo "$model_desc"|grep -qs "FM6";then			
			[ -n "$scan_param" ] && command_fibocom_scan_x "$_ctl" "$scan_param"
		else			
			[ -n "$scan_param" ] && _common_fibocom_scannr "$_ctl" "$scan_param"
		fi
		
		if [ "$odu_model" == "odu" ];then
			$(rm /tmp/odu_scan_cpe${gIndex})
		fi
	fi
	
	return 0
}

command_fibocom_imei2() {
	local _res _info

	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGSN")
	[ -z "$_res" ] && return 1
	if echo "$_res"|grep -qs ":" ;then
		_info="$(echo "$_res"|grep 'CGSN' -A2|sed -n '2p'|sed -e 's/\"//g'|awk -F':' '{print $2}'|xargs -r printf)"
	else
		_info="$(echo "$_res"|grep 'CGSN' -A2|sed -n '2p'|xargs -r printf)"
	fi
	echo "$_info"
}

command_fibocom_forceims2(){
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


command_fibocom_usim_get2() {
	local _res

	_res=$(_command_generic_exec "$_ctl" "GTDUALSIM" "?")
	[ -z "$_res" ] && echo "none"
	_res=$(echo "$_res" | cut -d' ' -f2| cut -d',' -f1)
	[ -n "$_res" ] && echo $((_res+1))
}

command_fibocom_usim_set2() {
	local _ctl="$1"
	local _new="$2"
	local _old _res

	_old=$(command_fibocom_usim_get2 "$_ctl"|xargs -r printf)

	[ "$_old" = "none" ] && return 1
	[ "$_old" = "$_new" ] && return 0
	local val=$((_new-1))
	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}GTDUALSIM=${val}" "5" "3"|grep "OK")	
	[ -z "$_res" ] && return 1
	return 0
}

command_fibocom_checkpass2(){
	local _ctl="$1"
	local _usbmode="$2"
	local _data
	local _res
	local reset=0
	local set=0

	_res=$(_command_generic_exec "$_ctl" "GTIPPASS" "?")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}')
		if [ -n "$_data" ];then
			
			_enable=$(echo "$_data"|awk -F',' '{print $1}'|awk '$1= $1'|xargs -r printf)
			_mode=$(echo "$_data"|awk -F',' '{print $2}'|awk '$1= $1'|xargs -r printf)
			echo  "get ipass :$_enable|$_mode"
			if [ "$_usbmode" = "17" ]; then
				if [ "$_mode" != "2" ];then
					_val="1,2"
					set=1
				fi
				if [ "$_enable" != "0" -a $set -eq 1 ];then
					reset=1
				fi
			else
				if [ "$_enable" != "1" ];then
					_val="1"
					set=1
				fi
				if [ "$_enable" != "0" -a $set -eq 1 ];then
					reset=1
				fi
			fi

			if [ $reset -eq 1 ]; then
				echo  "ipass :reset"
				_command_generic_exec "$_ctl" "GTIPPASS" "=0"
			fi

			if [ $set -eq 1 ]; then
				echo  "ipass :set $_val"
				_command_generic_exec "$_ctl" "GTIPPASS" "=$_val"
				return 0
			fi
		fi
	fi
	return 1
}

command_fibocom_checkmode2(){
	local _ctl="$1"
	local _val="$2"
	local _data
	local _res

	_res=$(_command_generic_exec "$_ctl" "GTUSBMODE" "?")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		if [ -n "$_data" ];then
			echo  "get usbmode :$_data"
			if [ "$_data" != "$_val" ]; then
				echo  "usbmode :set $_val"
				_command_generic_exec "$_ctl" "GTUSBMODE" "=$_val"
				return 0
			fi
		fi
	fi
	return 1
}


command_fibocom_checkautomatic2(){
	local _ctl="$1"
	local _val="1"
	local _data
	local _res

	_res=$(_command_generic_exec "$_ctl" "GTAUTOCONNECT" "?" "" "5")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		if [ -n "$_data" ];then
			echo  "get automatic :$_data"
			if [ "$_data" != "$_val" ]; then
				echo  "automatic :set $_val"
				_command_generic_exec "$_ctl" "GTAUTOCONNECT" "=$_val"
				return 0
			fi
		fi
	fi
	return 1
}

command_fibocom_preinit2(){
	local res
	local val=1
	local reset=0
	local _info="$2"
	local model_desc=$(uci -q get "network.cpe${gIndex}.desc")
	local work_mode=$(uci -q get "network.$gNet.mode")
	local usbmode="17"
	local _force_ims="0"

	if echo "$model_desc"|grep -qs "FM1";then
		usbmode="17"
	elif echo "$model_desc"|grep -qs "FM6";then
		usbmode="35"
	fi

	if _check_simslot ;then
		_force_ims="1"
	fi

	command_generic_imsreport "$1"
	command_generic_imsfmt "$1"
	if command_generic_imssetstorage "$1" ;then
		/etc/init.d/smsd restart
	fi
	command_fibocom_forceims2 "$1" "$_force_ims"
	command_fibocom_checkautomatic2 "$1"

	local work_mode=$(uci -q get "network.$gNet.mode")
	if [ "$work_mode" != "odu" ];then
		command_fibocom_checkpass2 "$1" "$usbmode"
		if command_fibocom_checkmode2 "$1" "$usbmode" ;then
			reset=1
		fi
	fi
	
	if [ $reset -eq 1 ];then
		cpetools.sh -i "${gNet}" -r
		return 1
	fi
	return 0
}

command_fibocom_earfcn_info2() {
	local _res
	local _enable="0"
	local nr_lock_found=0
	local lte_lock_found=0
	json_init
	json_add_array "earfcn"

	_res=$(_command_generic_exec "$1" "GTCELLLOCK" "?"|grep "+GTCELLLOCK:")
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

				if [ "$_mode_tmp" == "1" ];then
					json_add_string "MODE" "NR"
					nr_lock_found=1
				elif [ "$_mode_tmp" == "0" ];then
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

command_fibocom_apn2(){
	command_fibocom_apn "$@"
}

command_fibocom_apn(){
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


command_fibocom_pdp2(){
	local _ctl="$1"
	local _info="$2"
	#local cid="$3"
	local pdptype="$4"
	local apn="$5"
	local auth="$6"
	local username="$7"
	local password="$8"
	local cid="1"
	local change=0
	
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
				[ -z "$apn" ] && apn="$_cur_apn"
				if [ "$_cur_pdptype" != "$pdptype" -o "$_cur_apn" != "$apn" ];then
					_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGDCONT=$cid,\"$pdptype\"${apn:+,\"$apn\"}"
					change=1
				fi
				break
			fi
		fi
	done

	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}MGAUTH?"|grep "+MGAUTH:")
	[ -z "$_res" ] && return 1
	_cnt=$(echo "$_res"|wc -l)
	i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_data="$(echo "$line"|awk -F: '{print $2}')"
			_cur_cid="$(echo "$_data"|awk -F, '{print $1}'|sed 's/ //g')"
			_cur_auth_type="$(echo "$_data"|awk -F, '{print $2}'|sed 's/"//g')"
			_cur_username="$(echo "$_data"|awk -F, '{print $3}'|sed 's/"//g')"
			_cur_password="$(echo "$_data"|awk -F, '{print $4}'|sed 's/"//g')"

			if [ "$cid" == "$_cur_cid" ];then
				if [ "$_cur_auth_type" != "$auth" -o "$_cur_password" != "$password" -o "$_cur_username" != "$username" ];then
					_command_exec_raw "$1" "${AT_GENERIC_PREFIX}MGAUTH=$cid,$auth,\"$username\",\"$password\""
					#change=1					
				fi
				break
			fi
		fi
	done
	if [ $change -eq 1 ];then
		command_generic_reset "$1"
	fi
}

command_fibocom_analysis2(){
	local _ctl="$1"
	local _info="$2"
	echo $(command_fibocom_basic2 "$_ctl" "$_info")
	echo $(command_generic_ipaddr "$_ctl" "1")
}

command_fibocom_openrgmii2(){
	local _ctl="$1"
	local _code=2

	local model_desc=$(uci -q get "network.cpe${gIndex}.desc")
	local usbmode="17"

	if echo "$model_desc"|grep -qs "FM1";then
		usbmode="17"
	elif echo "$model_desc"|grep -qs "FM6";then
		usbmode="39"
	fi

	nat_info=$(command_fibocom_getrgmii2 "$_ctl")
	_status=$(echo "$nat_info"|jsonfilter -e '$["status"]')
	if [ "$_status" != "open" ];then		
		_res=$(_command_generic_exec_expect "$_ctl" "GTUSBMODE" "=$usbmode" "OK")
		if [ -n "$_res" ];then
			_code=0
		fi
	else
		if [ $_code != 0 ];then
			_code=2
		fi
	fi

	_res=$(_command_generic_exec "$_ctl" "GTIPPASS" "?")
	if [ -n "$_res" ];then
		_enable=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		if [ -n "$_enable" ];then
			if [ "$_enable" != "0" ];then
				_command_generic_exec "$_ctl" "GTIPPASS" "=0"
			fi
		fi
	fi

	json_init
	json_add_int "code" $_code
	json_add_string "model" $(command_fibocom_model2 "$1")
	json_dump
	json_cleanup
}

command_fibocom_getrgmii2(){
	local _ctl="$1"
	local status=""
	local model_desc=$(uci -q get "network.cpe${gIndex}.desc")
	local usbmode="17"

	if echo "$model_desc"|grep -qs "FM1";then
		usbmode="17"
	elif echo "$model_desc"|grep -qs "FM6";then
		usbmode="39"
	fi

	_res=$(_command_generic_exec "$_ctl" "GTUSBMODE" "?")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		_status="$(echo "$_data"|awk -F, '{print $2}'|sed 's/ //g'|sed -e 's/\"//g'|xargs -r printf)"
		if [ "$_status" == "$usbmode" ];then
			status="open"
		else
			status="close"
		fi
	fi

	json_init
	json_add_string "status" $status
	json_add_string "model" $(command_fibocom_model2 "$1")
	json_dump
	json_cleanup
}

