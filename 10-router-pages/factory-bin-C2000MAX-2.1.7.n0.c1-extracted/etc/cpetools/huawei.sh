#!/bin/ash

_command_huawei_mode_convert() {
	local _mode _res
	_mode="$1"
	_res="Unknown"
	case "$_mode" in
		"1")
			_res="GSM"
			;;
		"2")
			_res="CDMA"
			;;
		"3")
			_res="WCDMA"
			;;
		"4")
			_res="TD-SCDMA"
			;;
		"6")
			_res="LTE"
			;;
		"7")
			_res="NR"
			;;
	esac
	echo "$_res"
}

_command_huawei_rsrp_convert() {
	local _val
	_val="$1"
	[ "$_val" -eq 255 ] && echo -n "255" && return
	[ "$_val" -gt 97 ] && echo -n "-44" && return
	[ "$_val" -eq 0 ] && echo -n "-140" && return
	echo "$_val"|awk '{print -44-(97-$1)}'
}

_command_huawei_sinr_convert() {
	local _val
	_val="$1"
	[ "$_val" -eq 255 ] && echo -n "255" && return
	[ "$_val" -gt 251 ] && echo -n "30" && return
	[ "$_val" -eq 0 ] && echo -n "-20" && return
	echo "$_val"|awk '{print 30-(251-$1)*0.2}'
}

_command_huawei_rsrq_convert() {
	local _val
	_val="$1"
	[ "$_val" -eq 255 ] && echo -n "255" && return
	[ "$_val" -gt 34 ] && echo -n "-3" && return
	[ "$_val" -eq 0 ] && echo -n "-19.5" && return
	echo "$_val"|awk '{print -3-(34-$1)*0.5}'
}

_command_huawei_rssi_convert() {
	local _val
	_val="$1"
	[ "$_val" -eq 255 ] && echo -n "255" && return
	[ "$_val" -gt 96 ] && echo -n "-25" && return
	[ "$_val" -eq 0 ] && echo -n "-120" && return
	echo "$_val"|awk '{print -25-(96-$1)}'
}

_command_huawei_ecio_convert() {
	local _val
	_val="$1"
	[ "$_val" -eq 255 ] && echo -n "255" && return
	[ "$_val" -gt 65 ] && echo -n "0" && return
	[ "$_val" -eq 0 ] && echo -n "-32" && return
	echo "$_val"|awk '{print 0-(65-$1)*0.5}'
}

_command_huawei_rscp_convert() {
	local _val
	_val="$1"
	[ "$_val" -eq 255 ] && echo -n "255" && return
	[ "$_val" -gt 96 ] && echo -n "-25" && return
	[ "$_val" -eq 0 ] && echo -n "-120" && return
	echo "$_val"|awk '{print -25-(96-$1)}'
}

_command_huawei_hfreqinfo() {
	local _hfreq _sysmode
	local nr_index=0
	local nr_buffer=""
	local basic_index=3
	local step=7
	_hfreq="$1"

	_cnt=$(echo "$_hfreq"|wc -l)
	json_init
	for _line in $_hfreq; do
		local loop=0

		nr_buffer=""
		_sysmode="$(echo "$_line"|cut -d, -f2)"
		_mode=$(_command_huawei_mode_convert "$_sysmode")

		if [ $nr_index -ge 1 -a "$_mode" == "NR" ];then
			nr_buffer="$nr_index"
		fi

		while true;do
			local next_index=$((basic_index+step*loop))
			local band_index=$((next_index))
			local band="$(echo "$_line"|cut -d, -f$band_index)"

			[ -z "$band" ] && break
			local dlearfcn_index=$((next_index+1))
			local dlfreq_index=$((next_index+2))
			local dlbandwidth_index=$((next_index+3))
			local ulearfcn_index=$((next_index+4))
			local ulfreq_index=$((next_index+5))
			local ulbandwidth_index=$((next_index+6))

			if [ $loop -ge 1 ];then
				nr_index=$((nr_index+1))
				nr_buffer="$nr_index"
			fi

			json_add_object "${_mode}${nr_buffer}"
			json_add_string "BAND" "$band"
			json_add_int "EARFCN" "$(echo "$_line"|cut -d, -f$dlearfcn_index)"
			json_add_int "DL_FREQ" "$(echo "$_line"|cut -d, -f$dlfreq_index)"
			json_add_int "DL_BANDWIDTH" "$(echo "$_line"|cut -d, -f$dlbandwidth_index)"
			json_add_int "UL_FCN" "$(echo "$_line"|cut -d, -f$ulearfcn_index)"
			json_add_int "UL_FREQ" "$(echo "$_line"|cut -d, -f$ulfreq_index)"
			json_add_int "UL_BANDWIDTH" "$(echo "$_line"|cut -d, -f$ulbandwidth_index)"
			json_close_object
			loop=$((loop+1))
		done

		if [ "$_mode" == "NR" ];then
			nr_index=$((nr_index+1))
		fi

	done
	json_add_int nr_count $nr_index
	json_dump
	json_cleanup
}

_command_huawei_hcsq() {
	local _hcsq _val
	_hcsq="$1"
	_monsc="$3"
	_hfreq="$4"

	json_init
	for _line in $_hcsq; do
		_mode="$(echo "$_line"|cut -d, -f1|sed 's/\"//g')"
		if [ "$_mode" = "GSM" ]; then
			json_add_object "$_mode"
			_val="$(echo "$_line"|cut -d, -f2)"
			json_add_int "RSSI" "$(_command_huawei_rssi_convert "$_val")"
		elif [ "$_mode" = "WCDMA" ]; then
			json_add_object "$_mode"
			_val="$(echo "$_line"|cut -d, -f2)"
			json_add_int "RSSI" "$(_command_huawei_rssi_convert "$_val")"
			_val="$(echo "$_line"|cut -d, -f3)"
			json_add_int "RSCP" "$(_command_huawei_rscp_convert "$_val")"
			_val="$(echo "$_line"|cut -d, -f4)"
			json_add_int "ECIO" "$(_command_huawei_ecio_convert "$_val")"
		elif [ "$_mode" = "LTE" ]; then
			json_add_object "$_mode"
			_val="$(echo "$_line"|cut -d, -f2)"
			json_add_int "RSSI" "$(_command_huawei_rssi_convert "$_val")"
			_val="$(echo "$_line"|cut -d, -f3)"
			rsrp="$(_command_huawei_rsrp_convert "$_val")"
			_val="$(echo "$_line"|cut -d, -f4)"
			sinr="$(_command_huawei_sinr_convert "$_val")"
			if [ "$_alias" == "mt5700" ];then
				ant_signal="$(_command_huawei_signal_ant "$_ctl")"
				ant_rsrp="$(echo "$ant_signal"|jsonfilter -e '$["RSRP"]')"
				ant_sinr="$(echo "$ant_signal"|jsonfilter -e '$["SINR"]')"
				if [ -n "$rsrp" -a -n "$ant_rsrp" ];then
					if [ $ant_rsrp -gt $rsrp ];then
						rsrp="$ant_rsrp"
					fi
				fi
				if [ -n "$sinr" -a -n "$ant_sinr" ];then
					if [ $ant_sinr -gt $sinr ];then
						sinr="$ant_sinr"
					fi
				fi
			fi
			json_add_int "RSRP" "$rsrp"
			json_add_int "SINR" "$sinr"
			_val="$(echo "$_line"|cut -d, -f5)"
			json_add_int "RSRQ" "$(_command_huawei_rsrq_convert "$_val")"
			if [ -n "$_monsc" ];then
				json_add_string "CELL" "$(echo "$_monsc"|jsonfilter -e '$["CELL"]')"
				json_add_string "PCI" "$(echo "$_monsc"|jsonfilter -e '$["PCI"]')"
				json_add_string "TAC" "$(echo "$_monsc"|jsonfilter -e '$["TAC"]')"
				json_add_string "EARFCN" "$(echo "$_monsc"|jsonfilter -e '$["EARFCN"]')"
			fi
			if [ -n "$_hfreq" ]; then
				json_add_string "BAND" "$(echo "$_hfreq"|jsonfilter -e "\$['$_mode']['BAND']")"
			fi
		elif [ "$_mode" = "NR" ]; then
			json_add_object "$_mode"
			_val="$(echo "$_line"|cut -d, -f2)"
			rsrp="$(_command_huawei_rsrp_convert "$_val")"
			_val="$(echo "$_line"|cut -d, -f3)"
			sinr="$(_command_huawei_sinr_convert "$_val")"

			if [ "$_alias" == "mt5700" ];then
				ant_signal="$(_command_huawei_signal_ant "$_ctl")"
				ant_rsrp="$(echo "$ant_signal"|jsonfilter -e '$["RSRP"]')"
				ant_sinr="$(echo "$ant_signal"|jsonfilter -e '$["SINR"]')"
				if [ -n "$rsrp" -a -n "$ant_rsrp" ];then
					if [ $ant_rsrp -gt $rsrp ];then
						rsrp="$ant_rsrp"
					fi
				fi
				if [ -n "$sinr" -a -n "$ant_sinr" ];then
					if [ $ant_sinr -gt $sinr ];then
						sinr="$ant_sinr"
					fi
				fi
			fi
			json_add_int "RSRP" "$rsrp"
			json_add_int "SINR" "$sinr"
			_val="$(echo "$_line"|cut -d, -f4)"
			json_add_int "RSRQ" "$(_command_huawei_rsrq_convert "$_val")"
			if [ -n "$_monsc" ];then
				json_add_string "CELL" "$(echo "$_monsc"|jsonfilter -e '$["CELL"]')"
				json_add_string "PCI" "$(echo "$_monsc"|jsonfilter -e '$["PCI"]')"
				json_add_string "TAC" "$(echo "$_monsc"|jsonfilter -e '$["TAC"]')"
				json_add_string "EARFCN" "$(echo "$_monsc"|jsonfilter -e '$["EARFCN"]')"
			fi
			if [ -n "$_hfreq" ]; then
				json_add_string "BAND" "$(echo "$_hfreq"|jsonfilter -e "\$['$_mode']['BAND']")"
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

_command_huawei_monsc() {
	local _monsc
	_monsc="$1"

	json_init
	_mode="$(echo "$_monsc"|cut -d, -f1|sed 's/ //g')"
	_isp="$(echo "$_monsc"|cut -d, -f2)$(echo "$_monsc"|cut -d, -f3)"
	json_add_string "ISP" "$_isp"
	json_add_string "MODE" "$_mode"
	if [ "$_mode" = "LTE" ]; then
		json_add_string "CELL" "$(echo "$_monsc"|cut -d, -f5)"
		pci="$(echo "$_monsc"|cut -d, -f6)"
		pci=$(printf %d 0x$pci)
		json_add_string "PCI" "$pci"
		json_add_string "TAC" "$(echo "$_monsc"|cut -d, -f7)"
		json_add_int "RSRP" "$(echo "$_monsc"|cut -d, -f8)"
		json_add_int "RSRQ" "$(echo "$_monsc"|cut -d, -f9)"
		json_add_int "RXLEV" "$(echo "$_monsc"|cut -d, -f10)"
		json_add_int "EARFCN" "$(echo "$_monsc"|cut -d, -f4)"
	elif [ "$_mode" = "WCDMA" ]; then
		json_add_string "CELL" "$(echo "$_monsc"|cut -d, -f6)"
		json_add_string "LAC" "$(echo "$_monsc"|cut -d, -f7)"
		json_add_int "RSCP" "$(echo "$_monsc"|cut -d, -f8)"
		json_add_int "RXLEV" "$(echo "$_monsc"|cut -d, -f9)"
		json_add_int "ECNO" "$(echo "$_monsc"|cut -d, -f10)"
	elif [ "$_mode" = "TD-SCDMA" ]; then
		json_add_string "CELL" "$(echo "$_monsc"|cut -d, -f7)"
		json_add_string "LAC" "$(echo "$_monsc"|cut -d, -f8)"
		json_add_int "RSCP" "$(echo "$_monsc"|cut -d, -f9)"
		json_add_string "RAC" "$(echo "$_monsc"|cut -d, -f11)"
	elif [ "$_mode" = "GSM" ]; then
		json_add_int "BAND" "$(echo "$_monsc"|cut -d, -f4)"
		json_add_string "CELL" "$(echo "$_monsc"|cut -d, -f7)"
		json_add_string "LAC" "$(echo "$_monsc"|cut -d, -f8)"
		json_add_int "RXLEV" "$(echo "$_monsc"|cut -d, -f9)"
		json_add_int "RXQUALITY" "$(echo "$_monsc"|cut -d, -f10)"
	elif [ "$_mode" = "NR" ]; then
		pci=$(echo "$_monsc"|cut -d, -f7)
		pci=$(printf %d 0x$pci)
		json_add_string "CELL" "$(echo "$_monsc"|cut -d, -f6)"
		json_add_string "PCI" "$pci"
		json_add_string "TAC" "$(echo "$_monsc"|cut -d, -f8)"
		json_add_int "RSRP" "$(echo "$_monsc"|cut -d, -f9)"
		json_add_int "RSRQ" "$(echo "$_monsc"|cut -d, -f10)"
		json_add_int "SINR" "$(echo "$_monsc"|cut -d, -f11)"
		json_add_int "EARFCN" "$(echo "$_monsc"|cut -d, -f4)"
	fi
	json_dump
	json_cleanup
}

_command_huawei_syscfgex_get() {
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
	json_dump
	json_cleanup
}

_command_huawei_syscfgex_set() {
	local _ctl="$1"
	local _syscfgex="$2"
	local _key="$3"
	local _val="$4"
	local _param _tmp
	local _keys="ACQORDER BAND ROAM SRVDOMAIN LTEBAND"

	json_load "${_syscfgex:-{}}"
	json_add_string "$_key" "$_val"
	for _key in $_keys; do
		json_get_var _tmp "$_key"
		_param="$_param$_tmp,"
	done
	json_cleanup
	_param="$_param,"
	_command_private_exec "$_ctl" "SYSCFGEX" "=$_param"
}

_command_huawei_syscfgex_set_acqorder() {
	local _ctl="$1"
	local _val="$2"

	_command_private_exec "$_ctl" "SYSCFGEX=" "$_val"
}


_command_huawei_c5goption() {
	local _ctl="$1"
	local _val="$2"
	local _option
	local _res


	_res=$(_command_private_exec "$_ctl" "C5GOPTION" "?")
	[ -z "$_res" ] && return 1

	_option=$(echo "$_res"|awk -F' ' '{print $2}')
	echo  "get C5GOPTION :$_option"
	if [ "$_option" = "$_val" ]; then
		return 2
	fi

	echo "do set C5GOPTION $_val"
	_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}C5GOPTION=$_val"

	return 0
}

_command_huawei_mode() {
	local _ctl="$1"
	local _val="$2"
	local _nrcap="$3"
	local _alias="$4"
	local _syscfg
	local _acqorder
	local max=3
	local i=0

	if [ "$_nrcap" = "1" ];then
		while true;do
			_syscfg=$(_command_huawei_syscfgex_get "$_ctl")
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
			if [ "$_alias" == "redcap" -o "$_alias" == "mt5700" ];then
				_command_huawei_syscfgex_set "$_ctl" "$_syscfg" "ACQORDER" "\"$_val\""
			else
				_command_huawei_syscfgex_set_acqorder "$_ctl" "\"$_val\""
			fi

			i=$((i+1))
			if [ $i -ge $max ];then
				echo  "set syscfg error"
				return 1
			fi
			sleep 1
		done
	else
		_syscfg=$(_command_huawei_syscfgex_get "$_ctl")
		_acqorder=$(echo "$_syscfg"|jsonfilter -e '$["ACQORDER"]')
		[ -z "$_acqorder" ] && return 1
		if [ "$_acqorder" = "\"$_val\"" ]; then
			return 2
		fi
		_command_huawei_syscfgex_set "$_ctl" "$_syscfg" "ACQORDER" "\"$_val\""
	fi

	return 0
}

command_huawei_signal() {
	local _res _mode _hcsq
	_info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	local _alias=$(echo "$_info"|jsonfilter -e '$["alias"]')

	_cmd="${AT_PRIVATE_PREFIX}MONSC|${AT_PRIVATE_PREFIX}HFREQINFO?|${AT_PRIVATE_PREFIX}HCSQ?"
	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1
	_monsc="$(echo "$_res"|grep 'MONSC:'|awk -F: '{print $2}')"
	_hfreq="$(echo "$_res"|grep 'HFREQINFO:'|awk -F: '{print $2}')"
	_hcsq="$(echo "$_res"|grep 'HCSQ:'|awk -F: '{print $2}')"

	_monsc="$(_command_huawei_monsc "$_monsc")"
	_hfreq="$(_command_huawei_hfreqinfo "$_hfreq")"
	_command_huawei_hcsq "$_hcsq" "$_alias" "$_monsc" "$_hfreq"
}

_command_huawei_caculate_band(){
	local band=$1
	local len=${#band}
	local index=0
	local base_all=0
	while [ $index -lt $len ];do
		bit=${band:$index:1}
		bit_int=$(printf %d 0x$bit)
		[ $bit_int -gt 0 ] && {
			last_bit=1
			while [ $((bit_int/2)) -ge 1 ];do
				last_bit=$((last_bit+1))
				bit_int=$((bit_int/2))
			done
			base=$((4*(len-1)))
			base_all=$((base+last_bit+base_all))
		}

		index=$((index+1))
	done
	echo $base_all
}

_common_huawei_scan4g(){
	local _ctl="$1"
	local scan_param="$2"
	local _model
	local _res
	local _data

	json_init
	json_add_array "scanlist"
	_res=$(_command_exec_raw "$_ctl" "AT^MONNC" 20|grep "\^MONNC:")
	_cnt=$(echo "$_res"|wc -l)
	i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_info="$(echo "$line"|awk -F: '{print $2}')"
			if [ "$scan_param" == "2" ];then
					json_add_object
					json_add_string "MODE" "LTE"
					json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $2}'|sed -e 's/ //g')"
					json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $3}')"
					json_add_string "RSRP" "$(echo "$_info"|awk -F, '{print $4}')"
					json_add_string "RSRQ" "$(echo "$_info"|awk -F, '{print $5}')"
					json_add_object "lockneed"
					json_add_string "MODE" "1"
					json_add_string "EARFCN" "1"
					json_add_string "PCI" "0"
					json_close_object
					json_close_object

			elif [ "$scan_param" == "1" ];then
					json_add_object
					json_add_string "MODE" "WCDMA"
					json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $2}'|sed -e 's/ //g')"
					json_add_string "RSCP" "$(echo "$_info"|awk -F, '{print $4}')"
					json_add_string "ECNO" "$(echo "$_info"|awk -F, '{print $5}')"
					json_close_object
			fi
		fi
	done

	json_close_array
	json_dump
	json_cleanup
	return 0
}
_common_huawei_scannr(){
	local _ctl="$1"
	local scan_param="$2"
	local _res=""

	_res_cimi=$(command_generic_imsi "$_ctl")
	
	json_init
	json_add_array "scanlist"

	if  [ "$scan_param" == "3" ];then
		_res=$(_command_exec_raw "$_ctl" "AT^NETSCAN=8,-120,$scan_param" 120)
		if echo "$_res" |grep -qs "ERROR" ;then
			_res=$(_command_exec_raw "$_ctl" "AT^NETSCAN=8,-120,4" 120|grep "\^NETSCAN:")
		fi
	else
		_res=$(_command_exec_raw "$_ctl" "AT^NETSCAN=8,-120,$scan_param" 120|grep "\^NETSCAN:")
	fi

	_cnt=$(echo "$_res"|wc -l)
	i=0
	
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			_info="$(echo "$line"|awk -F: '{print $2}')"
			_rxlev="$(echo "$_info"|awk -F, '{print $8}'|xargs -r printf)"
			_isp=$(echo "$_info"|awk -F, '{print $5}')$(echo "$_info"|awk -F, '{print $6}')
			_band=$(_command_huawei_caculate_band "$(echo "$_info"|awk -F, '{print $10}')")
			[ -z "$_rxlev" ] && continue

			if [ -n "$_res_cimi" ];then
				_isp_len=${#_isp}
				isp=${_res_cimi:0:$_isp_len}
				_scan_company=$(jsonfilter -e '@[@.plmn[@="'$_isp'"]].company' </usr/lib/lua/luci/plmn.json )
				_cur_company=$(jsonfilter -e '@[@.plmn[@="'$isp'"]].company' </usr/lib/lua/luci/plmn.json )

				if [ -n "$_scan_company" -a -n "$_cur_company" -a "$_cur_company" != "$_scan_company" ];then
					continue
				fi
			fi

			if [ "$scan_param" == "3" -o "$scan_param" == "4"  ];then
					json_add_object
					json_add_string "MODE" "NR"
					json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $1}'|sed -e 's/ //g')"
					json_add_string "LAC" "$(echo "$_info"|awk -F, '{print $4}')"
					json_add_string "ISP" "$_isp"
					json_add_string "CELL" "$(echo "$_info"|awk -F, '{print $9}')"
					json_add_string "BAND" "$_band"
					json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $12}')"
					json_add_string "RSRP" "$(echo "$_info"|awk -F, '{print $14}')"
					json_add_string "RSRQ" "$(echo "$_info"|awk -F, '{print $15}')"
					json_add_string "SINR" "$(echo "$_info"|awk -F, '{print $16}')"

					json_add_object "lockneed"
					json_add_string "MODE" "1"
					json_add_string "EARFCN" "1"
					json_add_string "BAND" "1"
					json_add_string "PCI" "0"
					json_close_object

					json_close_object
			elif [ "$scan_param" == "2" ];then
					json_add_object
					json_add_string "MODE" "LTE"
					json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $1}'|sed -e 's/ //g')"
					json_add_string "LAC" "$(echo "$_info"|awk -F, '{print $4}')"
					json_add_string "ISP" "$_isp"
					json_add_string "RXLEV" "$(echo "$_info"|awk -F, '{print $8}')"
					json_add_string "CELL" "$(echo "$_info"|awk -F, '{print $9}')"
					json_add_string "BAND" "$_band"
					json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $12}')"

					json_add_object "lockneed"
					json_add_string "MODE" "1"
					json_add_string "EARFCN" "1"
					json_add_string "PCI" "0"
					json_close_object

					json_close_object

			elif [ "$scan_param" == "1" ];then
					json_add_object
					json_add_string "MODE" "WCDMA"
					json_add_string "EARFCN" "$(echo "$_info"|awk -F, '{print $1}'|sed -e 's/ //g')"
					json_add_string "LAC" "$(echo "$_info"|awk -F, '{print $4}')"
					json_add_string "ISP" "$_isp"
					json_add_string "RXLEV" "$(echo "$_info"|awk -F, '{print $8}')"
					json_add_string "CELL" "$(echo "$_info"|awk -F, '{print $9}')"
					json_add_string "BAND" "$_band"
					json_add_string "PCI" "$(echo "$_info"|awk -F, '{print $12}')"
					json_close_object
			fi
		fi
	done

	json_close_array
	json_dump
	json_cleanup

}

_format_nr_freq(){
    local _freq="$1"
    local _freq_g=5
    local _freq_off=0
    local _nfreq_off=0
    if [ $_freq -lt 3000000 ];then
        _freq_g=0.005
        _freq_off=0
        _nfreq_off=0
    elif [ $_freq -lt 24250000 ];then
        _freq_g=0.015
        _freq_off=3000
        _nfreq_off=600000
    elif [ $_freq -lt 100000000 ];then
        _freq_g=0.06
        _freq_off=24250.08
        _nfreq_off=2016667
    fi
	earfcn=$(echo $_freq $_freq_off $_freq_g $_nfreq_off|awk '{printf "%d",($1-$2*1000)/($3*1000)+$4}')
    echo "$earfcn"
}

_format_lte_freq(){
    local _freq="$1"
    local _band="$2"
    local _freq_dl=2110
    local _nfreq_dl=0
    if [ "$_band" == "1" ];then
        _freq_dl=2110
        _nfreq_dl=0
    elif [ "$_band" == "3" ];then
        _freq_dl=1805
        _nfreq_dl=1200
    elif [ "$_band" == "5" ];then
        _freq_dl=869
        _nfreq_dl=2400
    elif [ "$_band" == "8" ];then
        _freq_dl=925
        _nfreq_dl=3450
    elif [ "$_band" == "34" ];then
        _freq_dl=2010
        _nfreq_dl=36200
    elif [ "$_band" == "38" ];then
        _freq_dl=2570
        _nfreq_dl=37750
    elif [ "$_band" == "39" ];then
        _freq_dl=1880
        _nfreq_dl=38250
    elif [ "$_band" == "40" ];then
        _freq_dl=2300
        _nfreq_dl=38650
    elif [ "$_band" == "41" ];then
        _freq_dl=2496
        _nfreq_dl=39650
    elif [ "$_band" == "59" ];then
        _freq_dl=1785
        _nfreq_dl=54200
    elif [ "$_band" == "62" ];then
        _freq_dl=1785
        _nfreq_dl=64736
    fi
	earfcn=$(echo $_freq $_freq_dl $_nfreq_dl|awk '{printf "%d",($1-$2*10)+$3}')
    echo "$earfcn"
}
_common_huawei_scan_redcap(){
	local _ctl="$1"
	local scan_param="$2"
	local _res=""
	_info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	_res_cimi=$(command_generic_imsi "$_ctl")
	_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}LTEFREQLOCK=0" 2 > /dev/null
	_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRFREQLOCK=0" 2 > /dev/null
	json_init
	json_add_array "scanlist"
	if [ "$_alias" == "redcap" ];then
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NDISDUP=1,0" 2 > /dev/null
		sleep 12
	elif [ "$_alias" == "mt5700" ];then
		_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}CGATT=0" 2 > /dev/null
		sleep 8
	else
		ubus call atserver set '{"mod": "switchdata", "enabled": false}' > /dev/null
		sleep 15
	fi

	_res=$(_command_exec_raw "$_ctl" "AT^CELLSCAN=$scan_param" 120|grep "\^CELLSCAN:")

	_cnt=$(echo "$_res"|wc -l)
	i=0
	
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			##^CELLSCAN: <rat>,<plmn>,<freq>,[pci],<band>,<lac>,<cid>,[rxlev],[bsic],[psc],[5GSCS], [5GRSRP],[5GRSRQ],[5GSINR],[5GREDCAP],[LTERSINR]
			_info="$(echo "$line"|awk -F: '{print $2}')"

			_rat=$(echo "$_info"|awk -F, '{print $1}'|sed 's/ //g')
			_isp=$(echo "$_info"|awk -F, '{print $2}'|sed 's/"//g')
			_freq=$(echo "$_info"|awk -F, '{print $3}'|sed 's/"//g')
			_pci=$(echo "$_info"|awk -F, '{print $4}')
			_band="$(echo "$_info"|awk -F, '{print $5}')"
			[ -n "$_band" ] && _band=$(printf %d 0x$_band)
			_lac=$(echo "$_info"|awk -F, '{print $6}')
			_cid=$(echo "$_info"|awk -F, '{print $7}')
			_rxlev=$(echo "$_info"|awk -F, '{print $8}')
			_rsrp=$(echo "$_info"|awk -F, '{print $12}')
			_rsrq=$(echo "$_info"|awk -F, '{print $13}')
			[ -n "$_rsrq" ] && _rsrq=$((_rsrq/2))
			_sinr=$(echo "$_info"|awk -F, '{print $14}')
			[ -n "$_sinr" ] && _sinr=$((_sinr/2))
			if [ "$_alias" == "mt5700" ];then
				_ltesinr=$(echo "$_info"|awk -F, '{print $15}')
			else
				_nrredcap=$(echo "$_info"|awk -F, '{print $15}')
				_ltesinr=$(echo "$_info"|awk -F, '{print $16}')
			fi
			if [ -n "$_ltesinr" ] && [ "$_alias" != "redcap" ];then
				_ltesinr=$((_ltesinr/8))
			fi

			if [ -n "$_res_cimi" ];then
				_isp_len=${#_isp}
				isp=${_res_cimi:0:$_isp_len}
				_scan_company=$(jsonfilter -e '@[@.plmn[@="'$_isp'"]].company' </usr/lib/lua/luci/plmn.json )
				_cur_company=$(jsonfilter -e '@[@.plmn[@="'$isp'"]].company' </usr/lib/lua/luci/plmn.json )

				if [ -n "$_scan_company" -a -n "$_cur_company" -a "$_cur_company" != "$_scan_company" ];then
					continue
				fi
			fi

			if [ "$_rat" == "3" ];then
				[ "$_nrredcap" == "1" ] && continue
				if [ "$_alias" == "redcap" -o "$_alias" == "mt5700" ];then
					_earfcn=$(_format_nr_freq "$_freq")
				else
					_param_cnt=$(echo "$_info"|grep -o ','|wc -l)
					_param_cnt=$((_param_cnt+1))
					_earfcn=$(echo "$_info"|awk -F, '{print $'$_param_cnt'}'|xargs -r printf)
				fi
				json_add_object
				json_add_string "MODE" "NR"
				json_add_string "EARFCN" "$_earfcn"
				json_add_string "LAC" "$_lac"
				json_add_string "ISP" "$_isp"
				json_add_string "CELL" "$_cid"
				json_add_string "BAND" "$_band"
				json_add_string "PCI" "$_pci"
				json_add_string "RSRP" "$_rsrp"
				json_add_string "RSRQ" "$_rsrq"
				json_add_string "SINR" "$_sinr"
				json_add_object "lockneed"
				json_add_string "MODE" "2"
				json_add_string "EARFCN" "1"
				json_add_string "BAND" "1"
				json_add_string "PCI" "1"
				json_close_object
				json_close_object
			elif [ "$_rat" == "2" ];then

				if [ "$_alias" == "redcap" -o "$_alias" == "mt5700" ];then
					_earfcn=$(_format_lte_freq "$_freq" "$_band")
				else
					_param_cnt=$(echo "$_info"|grep -o ','|wc -l)
					_param_cnt=$((_param_cnt+1))
					_earfcn=$(echo "$_info"|awk -F, '{print $'$_param_cnt'}'|xargs -r printf)
				fi

				json_add_object
				json_add_string "MODE" "LTE"
				json_add_string "EARFCN" "$_earfcn"
				json_add_string "LAC" "$_lac"
				json_add_string "ISP" "$_isp"
				json_add_string "CELL" "$_cid"
				json_add_string "BAND" "$_band"
				json_add_string "PCI" "$_pci"
				json_add_string "SINR" "$_ltesinr"
				json_add_string "RSRP" "$_rxlev"

				json_add_object "lockneed"
				json_add_string "MODE" "2"
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
	if [ "$_alias" == "redcap" ];then
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NDISDUP=1,1" 2 > /dev/null
	elif [ "$_alias" == "mt5700" ];then
		local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
		[ -z "$simIndex" ] && simIndex="1"
		local mode=$(uci -q get "cpecfg.${gNet}sim$simIndex.mode")
		cpetools.sh -i "$gNet" -u -m "$mode" > /dev/null
		command_generic_reset "$1" > /dev/null
	else
		ubus call atserver set '{"mod": "switchdata", "enabled": true}' > /dev/null
	fi
}
command_huawei_scan(){
	local _ctl="$1"
	local _info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	local _model
	local _res
	local _data
	local mode="$2"
	local isp=""
	local scan_param="3"

	local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
	[ -z "$simIndex" ] && simIndex="1"
	local nr_support=$(uci -q get "network.${gNet}.nrcap")
	local odu_model=$(uci -q get "network.${gNet}.mode")
	[ -z "$mode" ] && mode=$(uci -q get "cpecfg.${gNet}sim$simIndex.mode")
	if [ "$nr_support" == "1" ];then
		if [ "$mode" == "lte" ];then
			scan_param="2"
		fi
		_vendor=$(check_soc_vendor)
		if [ "$odu_model" == "odu" ];then
			$(touch /tmp/odu_scan_${gNet})
		fi
	
		if [ "$_vendor" == "tdtech" ];then
			_common_huawei_scan_redcap "$_ctl" "$scan_param"
		else
			_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
			if [ "$_alias" == "redcap" -o "$_alias" == "mt5700" ];then
				_common_huawei_scan_redcap "$_ctl" "$scan_param"
			else
				_common_huawei_scannr "$_ctl" "$scan_param"
			fi
		fi
		
		if [ "$odu_model" == "odu" ];then
			$(rm /tmp/odu_scan_${gNet})
		fi
	else
		if [ "$mode" == "wcdma" ];then
			scan_param="1"
		else
			scan_param="2"
		fi
		_common_huawei_scan4g "$_ctl" "$scan_param"
	fi

	return 0
}
command_huawei_neighbour(){
	local _ctl="$1"
	local _model
	local _res
	local _data

	_res=$(_command_private_exec "$1" "MONNC")
	_cnt=$(echo "$_res"|wc -l)
	i=0
	json_init
	json_add_array "neighbour"
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			##LTE ^MONNC: <ARFCN>,<PCI>,<RSRP>,<RXLEV>
			##NR  ^MONNC: <ARFCN>,<PCI>,<RSRP>,<SINR>
			_info="$(echo "$line"|awk -F: '{print $2}')"
			_rsrp=$(echo "$_info"|awk -F, '{print $4}')
			if [ -z "$_rsrp" -o "$_rsrp" -lt "-120" ];then
				continue
			fi
			_mode=$(echo "$_info"|awk -F, '{print $1}'|xargs -r printf)
			_earfcn=$(echo "$_info"|awk -F, '{print $2}')
			_pci=$(echo "$_info"|awk -F, '{print $3}')
			[ -n "$_pci" ] && _pci=$(printf %d 0x$_pci)
			
			_rsrq=$(echo "$_info"|awk -F, '{print $5}')
			_sinr=$(echo "$_info"|awk -F, '{print $6}')

			if [ "$_mode" == "NR" ];then
				json_add_object
				json_add_string "MODE" "NR"
				json_add_string "EARFCN" "$_earfcn"
				json_add_string "BAND" "$_band"
				json_add_string "PCI" "$_pci"
				json_add_string "RSRP" "$_rsrp"
				json_add_string "RSRQ" "$_rsrq"
				json_add_string "SINR" "$_sinr"
				json_add_object "lockneed"
				json_add_string "MODE" "2"
				json_add_string "EARFCN" "1"
				json_add_string "BAND" "1"
				json_add_string "PCI" "1"
				json_close_object
				json_close_object
			elif [ "$_mode" == "LTE" ];then
				json_add_object
				json_add_string "MODE" "LTE"
				json_add_string "EARFCN" "$_earfcn"
				json_add_string "BAND" "$_band"
				json_add_string "PCI" "$_pci"
				json_add_string "SINR" "$_ltesinr"
				json_add_string "RSRP" "$_rxlev"
				json_add_string "RSRQ" "$_rsrq"
				json_add_object "lockneed"
				json_add_string "MODE" "2"
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

command_huawei_cellinfo() {
	local _res _monsc _hfreq _hcsq _nsa

	_res=$(_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}MONSC|${AT_PRIVATE_PREFIX}HFREQINFO?|${AT_PRIVATE_PREFIX}HCSQ?")
	[ -z "$_res" ] && return 1

	_monsc="$(echo "$_res"|grep 'MONSC:'|awk -F: '{print $2}')"
	_hfreq="$(echo "$_res"|grep 'HFREQINFO:'|awk -F: '{print $2}')"
	_hcsq="$(echo "$_res"|grep 'HCSQ:'|awk -F: '{print $2}')"
	_monsc="$(_command_huawei_monsc "$_monsc")"
	_mode_cur="$(echo "$_monsc"|jsonfilter -e '$["MODE"]')"
	_earfcn="$(echo "$_monsc"|jsonfilter -e '$["EARFCN"]')"
	_hfreq="$(_command_huawei_hfreqinfo "$_hfreq")"
	_hcsq="$(_command_huawei_hcsq "$_hcsq")"

	if echo "$_hfreq"|jsonfilter -e '$["NR"]' > /dev/null && echo "$_hfreq"|jsonfilter -e '$["LTE"]' > /dev/null; then
		_nsa=1
	else
		_nsa=0
	fi

	if [ "$_nsa" -eq 0 ]; then
		echo "$_monsc"
		return
	fi

	json_init
	json_add_string "MODE" "NR NSA"
	json_add_string "ISP" "$(echo "$_monsc"|jsonfilter -e '$["ISP"]')"
	json_add_string "CELL" "$(echo "$_monsc"|jsonfilter -e '$["CELL"]')"
	json_add_string "PCI" "$(echo "$_monsc"|jsonfilter -e '$["PCI"]')"
	json_add_string "TAC" "$(echo "$_monsc"|jsonfilter -e '$["TAC"]')"
	json_add_string "RSRP" "$(echo "$_hcsq"|jsonfilter -e '$["NR"]["RSRP"]')"
	json_add_string "SINR" "$(echo "$_hcsq"|jsonfilter -e '$["NR"]["SINR"]')"
	json_add_string "RSRQ" "$(echo "$_hcsq"|jsonfilter -e '$["NR"]["RSRQ"]')"
	json_add_string "BAND" "$(echo "$_hfreq"|jsonfilter -e '$["NR"]["BAND"]')"
	json_add_string "EARFCN" "$(echo "$_hfreq"|jsonfilter -e '$["NR"]["EARFCN"]')"
	json_add_string "DL_FREQ" "$(echo "$_hfreq"|jsonfilter -e '$["NR"]["DL_FREQ"]')"
	json_dump
	json_cleanup
}

_command_huawei_signal_ant() {
	local _res _info

	_res=$(_command_private_exec "$1" "ANTRSSI" "?")
	[ -z "$_res" ] && return 1
	_info=$(echo "$_res"|awk -F: '{print $2}')
	_mode=$(echo "$_info"|awk -F, '{print $1}'|xargs -r printf)
	_num=$(echo "$_info"|awk -F, '{print $2}')
	[ -z "$_num" -o -z "$_mode" ] && return
	if [ "$_mode" == "0" ];then
		_mode="GSM"
	elif [ "$_mode" == "1" ];then
		_mode="WCDMA"
	elif [ "$_mode" == "2" ];then
		_mode="LTE"
	elif [ "$_mode" == "6" ];then
		_mode="NR"
	else
		return
	fi

	_base_index=2
	_rsrp=0
	_sinr=0
	i=0
	while [ $i -lt $_num ];do
		local tmp_rsrp=""
		local tmp_sinr=""
		i=$((i+1))
		local index=$((_base_index+i))
		local index_sinr=$((_base_index+i+4))
		tmp_rsrp=$(echo "$_info"|awk -F, '{print $'$index'}')
		tmp_sinr=$(echo "$_info"|awk -F, '{print $'$index_sinr'}')
		if [ -n "$tmp_rsrp" -a "$tmp_rsrp" != "0x7fff" -a "$tmp_rsrp" != "32767" ];then
			[ $_rsrp -lt $tmp_rsrp -o $_rsrp -eq 0  ] && _rsrp=$tmp_rsrp
		fi
		if [ -n "$tmp_sinr" -a "$tmp_sinr" != "0x7fff" -a "$tmp_sinr" != "32767" ];then
			[ $_sinr -lt $tmp_sinr -o $_sinr -eq 0 ] && _sinr=$tmp_sinr
		fi
	done
	_rsrp=$((_rsrp/8))
	_sinr=$((_sinr/8))
	json_init
	json_add_string "MODE" "$_mode"
	json_add_string "RSRP" "$_rsrp"
	json_add_string "SINR" "$_sinr"

	json_dump
	json_cleanup
}
command_huawei_basic() {
	local _ctl="$1"
	local _info="$2"
	local _res _imei _imsi _iccid _monsc _hfreq _hcsq _mode _model _revision _cpin
	local _cmd
	local cid="2"
	local qci=""
	local nr5g_ambr_dl=""
	local nr5g_ambr_ul=""
	local dver=$(echo "$_info"|jsonfilter -e '$["dver"]')

	local apn="$(command_huawei_apn "$_ctl" "$_info"|jsonfilter -e "\$['APN']")"
	_cmd="${AT_PRIVATE_PREFIX}MONSC|${AT_PRIVATE_PREFIX}HFREQINFO?|${AT_PRIVATE_PREFIX}HCSQ?|${AT_PRIVATE_PREFIX}ICCID?"
	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1

	_monsc="$(echo "$_res"|grep 'MONSC:'|awk -F: '{print $2}')"
	_hfreq="$(echo "$_res"|grep 'HFREQINFO:'|awk -F: '{print $2}')"
	_hcsq="$(echo "$_res"|grep 'HCSQ:'|awk -F: '{print $2}')"
	_iccid="$(echo "$_res"|grep 'ICCID:'|awk -F' ' '{print $2}')"

	_res=$(_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CIMI" 5)
	[ -n "$_res" ] && _imsi="$(echo "$_res"|grep 'CIMI' -A2|grep -E '^[0-9].*$'|xargs -r printf)"

	_monsc="$(_command_huawei_monsc "$_monsc")"
	_mode_cur="$(echo "$_monsc"|jsonfilter -e '$["MODE"]')"
	_earfcn="$(echo "$_monsc"|jsonfilter -e '$["EARFCN"]')"

	_imei="$(uci -q get "cellular_init.$gNet.imei")"
	_model="$(uci -q get "cellular_init.$gNet.model")"
	_revision="$(uci -q get "cellular_init.$gNet.version")"

	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	_hfreq="$(_command_huawei_hfreqinfo "$_hfreq")"
	_hcsq="$(_command_huawei_hcsq "$_hcsq" "$_alias")"
	
	_isp="$(echo "$_monsc"|jsonfilter -e '$["ISP"]')"
	if [ "$_isp" != "000000" ];then
		_isp="$(echo "$_isp"|awk '$1= $1')"
	fi
	_temp="$(command_huawei_temp "$_ctl")"
	_cpin="$(command_generic_cpin "$_ctl")"
	json_init
	if [ -n "$_temp" ];then
		json_add_string "MODEL_TEMP" "$_temp"
	fi
	json_add_string "ISP" "$_isp"
	json_add_string "CELL" "$(echo "$_monsc"|jsonfilter -e '$["CELL"]')"
	json_add_string "PCI" "$(echo "$_monsc"|jsonfilter -e '$["PCI"]')"
	json_add_string "TAC" "$(echo "$_monsc"|jsonfilter -e '$["TAC"]')"

	

	_vendor=$(check_soc_vendor)
	if [ "$_vendor" == "tdtech" ];then
		cid="7"
	else
		[ "$_alias" == "redcap" ] && cid=1
		[ "$_alias" == "mt5700" ] && cid=8
		[ "$_alias" == "mt5700" ] && [ -z "$dver" ] && cid=1
	fi

	if [ "$_alias" == "redcap" -o "$_alias" == "mt5700" ];then
		_res=$(_command_private_exec "$1" "DSAMBR" "=$cid")
		if [ -n "$_res" ];then
			nr5g_ambr_dl=$(echo "$_res"|awk -F',' '{print $2}'|xargs -r printf|sed -e 's/ //g')
			nr5g_ambr_ul=$(echo "$_res"|awk -F',' '{print $3}'|xargs -r printf|sed -e 's/ //g')
		fi

		_res=$(_command_generic_exec "$1" "CGEQOSRDP" "=$cid")
		if [ -n "$_res" ];then
			qci=$(echo "$_res"|awk -F',' '{print $2}'|xargs -r printf|sed -e 's/ //g')
		fi
		if [ -z "$qci" ];then
			_res=$(_command_generic_exec "$1" "C5GQOSRDP" "=$cid")
			if [ -n "$_res" ];then
				qci=$(echo "$_res"|awk -F',' '{print $2}'|xargs -r printf|sed -e 's/ //g')
			fi
		fi
	elif [ "$_vendor" == "tdtech" ];then
		_res=$(_command_generic_exec "$1" "C5GQOSRDP" "=$cid")
		if [ -n "$_res" ];then
			qci=$(echo "$_res"|awk -F',' '{print $2}'|xargs -r printf|sed -e 's/ //g')
			nr5g_ambr_dl=$(echo "$_res"|awk -F',' '{print $7}'|xargs -r printf|sed -e 's/ //g')
			nr5g_ambr_ul=$(echo "$_res"|awk -F',' '{print $8}'|xargs -r printf|sed -e 's/ //g')
		fi
	fi
	if echo "$_hfreq"|jsonfilter -e '$["NR"]' > /dev/null; then
		_mode="NR"
		nr_count="$(echo "$_hfreq"|jsonfilter -e '$["nr_count"]')"
		i=0
		while [ $i -lt $nr_count ];do
			index=""
			if [ $i -gt 0 ];then
				index="$i"
			fi
			if echo "$_hfreq"|jsonfilter -e '$["NR'$index'"]' > /dev/null; then
				[ $i -gt 0 ] && json_add_string "BAND$index" "$(echo "$_hfreq"|jsonfilter -e "\$['NR$index']['BAND']")"
				json_add_string "DL_FCN$index" "$(echo "$_hfreq"|jsonfilter -e "\$['NR$index']['EARFCN']")"
				json_add_string "UL_FCN$index" "$(echo "$_hfreq"|jsonfilter -e "\$['NR$index']['UL_FCN']")"
				json_add_string "DLBW$index" "$(echo "$_hfreq"|jsonfilter -e "\$['NR$index']['DL_BANDWIDTH']")"
				json_add_string "ULBW$index" "$(echo "$_hfreq"|jsonfilter -e "\$['NR$index']['UL_BANDWIDTH']")"
			fi
			i=$((i+1))
		done

		if echo "$_hfreq"|jsonfilter -e '$["LTE"]' > /dev/null; then
			json_add_string "MODE" "NR NSA"
			json_add_string "BAND1" "$(echo "$_hfreq"|jsonfilter -e "\$['LTE']['BAND']")"
			json_add_string "DL_FCN1" "$(echo "$_hfreq"|jsonfilter -e "\$['LTE']['EARFCN']")"
			json_add_string "UL_FCN1" "$(echo "$_hfreq"|jsonfilter -e "\$['LTE']['UL_FCN']")"
			json_add_string "DLBW1" "$(echo "$_hfreq"|jsonfilter -e "\$['LTE']['DL_BANDWIDTH']")"
			json_add_string "ULBW1" "$(echo "$_hfreq"|jsonfilter -e "\$['LTE']['UL_BANDWIDTH']")"
		else
			json_add_string "MODE" "NR SA"
		fi

		if [ "$_alias" == "redcap" -o "$_alias" == "mt5700" ];then
			json_add_string "EARFCN" "$(echo "$_monsc"|jsonfilter -e '$["EARFCN"]')"
		else
			json_add_string "EARFCN" "$(echo "$_hfreq"|jsonfilter -e "\$['$_mode']['EARFCN']")"
		fi
		json_add_string "DL_FREQ" "$(echo "$_hfreq"|jsonfilter -e "\$['$_mode']['DL_FREQ']")"
	elif echo "$_hfreq"|jsonfilter -e '$["LTE"]' > /dev/null; then
		_mode="LTE"
		json_add_string "MODE" "$_mode"
		json_add_string "EARFCN" "$(echo "$_hfreq"|jsonfilter -e "\$['$_mode']['EARFCN']")"
		json_add_string "DL_FREQ" "$(echo "$_hfreq"|jsonfilter -e "\$['$_mode']['DL_FREQ']")"
	else
		_mode="$(echo "$_monsc"|jsonfilter -e '$["MODE"]')"
		json_add_string "MODE" "$_mode"
		json_add_string "EARFCN" "$(echo "$_monsc"|jsonfilter -e '$["EARFCN"]')"
		json_add_string "DL_FREQ" "$(echo "$_monsc"|jsonfilter -e '$["DL_FREQ"]')"
	fi

	if [ "$_mode" = "NR" ] || [ "$_mode" = "LTE" ]; then
		json_add_string "BAND" "$(echo "$_hfreq"|jsonfilter -e "\$['$_mode']['BAND']")"
	else
		json_add_string "BAND" "$(echo "$_monsc"|jsonfilter -e "\$['$_mode']['BAND']")"
	fi
	rsrp="$(echo "$_hcsq"|jsonfilter -e "\$['$_mode']['RSRP']")"
	sinr="$(echo "$_hcsq"|jsonfilter -e "\$['$_mode']['SINR']")"

	json_add_string "RSRP" "$rsrp"
	json_add_string "SINR" "$sinr"
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
	json_add_string "CPIN" "$_cpin"
	if [ -n "$qci" ];then
		json_add_string "CQI" "$qci"
	fi
	json_add_string "NR5G_AMBR_DL" "$nr5g_ambr_dl"
	json_add_string "NR5G_AMBR_UL" "$nr5g_ambr_ul"
	json_dump
	json_cleanup
}

command_huawei_nroff() {
	local _info="$2"
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	_command_huawei_mode "$1" "03" "" "$_alias"
	if [ $? -eq 0 ];then
		command_generic_reset "$1"
	fi
}
command_huawei_modewcdma() {
	local _info="$2"
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	_command_huawei_mode "$1" "02" "" "$_alias"
	if [ $? -eq 0 ];then
		command_generic_reset "$1"
	fi
}
command_huawei_allmode() {
	local _info="$2"
	local _nrcap
	local reset=0
	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	if [ "$_alias" == "mt5700" ];then
		_command_huawei_mode "$1" "080302" "$_nrcap" "$_alias"	
	else
		_command_huawei_mode "$1" "00" "$_nrcap" "$_alias"
	fi
	if [ $? -eq 0 ];then
		reset=1
	fi

	if [ "$_nrcap" = "1" ]; then
		_command_huawei_c5goption "$1" "1,1,1"
		if [ $? -eq 0 ];then
			reset=1
		fi
	fi
	if [ $reset -eq 1 ];then
		command_generic_reset "$1"
	fi
}

command_huawei_modesa() {
	local _info="$2"
	local _nrcap
	local reset=0
	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')

	if [ "$_alias" == "mt5700" ];then
		_command_huawei_mode "$1" "080302" "$_nrcap" "$_alias"
	else
		_command_huawei_mode "$1" "00" "$_nrcap" "$_alias"
	fi
	if [ $? -eq 0 ];then
		reset=1
	fi

	if [ "$_nrcap" = "1" ]; then
		_command_huawei_c5goption "$1" "1,0,1"
		if [ $? -eq 0 ];then
			reset=1
		fi
	fi
	if [ $reset -eq 1 ];then
		command_generic_reset "$1"
	fi
}

command_huawei_modensa() {
	local _info="$2"
	local _nrcap
	local reset=0
	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')

	if [ "$_alias" == "mt5700" ];then
		_command_huawei_mode "$1" "080302" "$_nrcap" "$_alias"
	else
		_command_huawei_mode "$1" "00" "$_nrcap" "$_alias"
	fi
	if [ $? -eq 0 ];then
		reset=1
	fi

	if [ "$_nrcap" = "1" ]; then
		_command_huawei_c5goption "$1" "0,1,0"
		if [ $? -eq 0 ];then
			reset=1
		fi
	fi
	if [ $reset -eq 1 ];then
		command_generic_reset "$1"
	fi
}

command_huawei_modesa_only() {
	local _info="$2"
	local _nrcap
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')
	if [ "$_nrcap" = "1" ]; then
		_command_huawei_c5goption "$1" "1,1,1"
	fi
	_command_huawei_mode "$1" "08" "$_nrcap" "$_alias"
	if [ $? -eq 0 ];then
		echo  "syscfg change cfun"
		command_generic_reset "$1"
	fi
}

command_huawei_modensa_only() {
	command_huawei_modensa "$1" "$2"
}

_command_huawei_freq_get() {
	local _res _info

	_res=$(_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}NRFREQLOCK?")
	nrfreq=$(echo "$_res" | grep "NRFREQLOCK:")
	[ -z "$nrfreq" ] && return 1

	_info=$(echo "$nrfreq"|awk -F: '{print $2}')
	_change_info=$(echo "$_info"|xargs -r printf)

	json_init
	if [ "$_change_info" = "0" ];then
		json_add_string "enable" "$_change_info"
	else
		json_add_string "enable" "$(echo "$_info"|awk -F, '{print $1}'|xargs -r printf|awk '$1= $1')"
	fi

	if [ "$_change_info" == "2" -o  "$_change_info" == "1" -o "$_change_info" == "3"  ];then
		_info=$(echo "$_res"|sed -n "4p")
		_flag=$(echo "$_res"|sed -n "3p")
		json_add_string "mobility" "$(echo "$_flag"|awk -F, '{print $1}'|xargs -r printf)"
		json_add_string "band" "$(echo "$_info"|awk -F, '{print $1}'|xargs -r printf)"
		json_add_string "arfcn" "$(echo "$_info"|awk -F, '{print $2}'|xargs -r printf)"
		json_add_string "scstype" "$(echo "$_info"|awk -F, '{print $3}'|xargs -r printf)"
		json_add_string "cellid" "$(echo "$_info"|awk -F, '{print $4}'|xargs -r printf)"
	else
		json_add_string "scstype" "$(echo "$_info"|awk -F, '{print $2}')"
		json_add_string "band" "$(echo "$_info"|awk -F, '{print $3}'|xargs -r printf)"
		json_add_string "arfcn" "$(echo "$_info"|awk -F, '{print $4}'|xargs -r printf)"
		json_add_string "cellid" "$(echo "$_info"|awk -F, '{print $5}'|xargs -r printf)"
	fi

	json_dump
	json_cleanup
}
_command_huawei_freq() {
	local _freqcfg _enable _band
	_ctl=$1
	key=$2
	if [ "$key" = "NRFREQLOCK" ];then
		_freqcfg=$(_command_huawei_freq_get "$_ctl")
		[ -z "$_freqcfg" ] && return 1
		_enable=$(echo "$_freqcfg"|jsonfilter -e '$["enable"]')
		_band=$(echo "$_freqcfg"|jsonfilter -e '$["band"]')

		if [ "$_enable" = "3" ];then
			echo "$_band"
		elif [ "$_enable" = "0" ];then
			echo "$_enable"
		else
			echo "999"
		fi
	fi
}

_command_huawei_freq_set() {
	local _ctl="$1"
	local key="$2"
	local freq="$3"
	_info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')

	if [ "$_alias" == "redcap" -o "$_alias" == "mt5700" ];then
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRFREQLOCK=3,0,1,\"$freq\"" 2
	else
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRFREQLOCK=3,1,$freq" 2
	fi
}
command_huawei_freq_unlock(){
	local _freqcfg _enable _band
	_ctl=$1
	local res=""
	local code=0

	_freqcfg=$(_command_huawei_freq_get "$_ctl")
	[ -z "$_freqcfg" ] && return 1
	_enable=$(echo "$_freqcfg"|jsonfilter -e '$["enable"]')
	_band=$(echo "$_freqcfg"|jsonfilter -e '$["band"]')
	echo  "get NRFREQLOCK $_enable"

	if [ "$_enable" != "0" ];then
		echo "do set NRFREQLOCK 0"
		command_generic_cfun_c
		res=$(_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRFREQLOCK=0" 2)
		command_generic_cfun_o
		echo "res:$res"
	fi

	return $code
}
command_huawei_freq() {
	local _ctl="$1"
	local freq="$2"
	local _freq=""
	local _key=""
	local _set=0
	_info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')

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
			_key="NRFREQLOCK"
		elif [ "$label" = "nsa" ];then
			_key="NRFREQLOCK"
		elif [ "$label" = "nr" ];then
			_key="NRFREQLOCK"
		elif [ "$label" = "lte" ];then
			_key="LTEFREQLOCK"
		elif [ "$label" = "wcdma" ];then
			_key=""
		fi
		if [ -n "$_key" ];then
			if [ "$_alias" == "redcap" -o "$_alias" == "mt5700" ];then
				if [ "$_key" == "LTEFREQLOCK" ];then
					_command_huawei_lte "$_ctl" "$_key" "$freq_data"
				else
					_command_huawei_nr "$_ctl" "$_key" "$freq_data"
				fi
			else
				[ "$_key" == "LTEFREQLOCK" ] && continue
				if [ -z "$freq_data" ];then
					freq_data="0"
				fi
				_freq=$(_command_huawei_freq "$_ctl" "$_key")
				if [ "$_freq" = "$freq_data" ]; then
					continue
				fi
				command_generic_cfun_c
				_command_huawei_freq_set "$_ctl" "$_key" "$freq_data"
				command_generic_cfun_o
				_set=1
			fi
		fi
	done

	return 0
}

command_huawei_showmode() {
	_command_huawei_syscfgex_get "$1"
}

command_huawei_iccid() {
	local _res _info

	_res=$(_command_private_exec "$1" "ICCID" "?")
	[ -z "$_res" ] && return 1

	_info="$(echo "$_res"|awk -F' ' '{print $2}')"

	echo "$_info"
}

_command_huawei_roam() {
	_val=$2
	_alias="$3"
	_syscfg=$(_command_huawei_syscfgex_get "$1")
	_acqorder=$(echo "$_syscfg"|jsonfilter -e '$["ACQORDER"]')
	_band=$(echo "$_syscfg"|jsonfilter -e '$["BAND"]')
	_roam=$(echo "$_syscfg"|jsonfilter -e '$["ROAM"]')

	[ -z "$_acqorder" ] && return 1
	[ -z "$_band" ] && return 1

	if [ "$_roam" = "$_val" ]; then
		return 0
	fi
	echo "set roam"
	if [ "$_alias" == "redcap" -o "$_alias" == "mt5700" ];then
		_command_huawei_syscfgex_set "$_ctl" "$_syscfg" "ROAM" "$_val"
	else
		_command_private_generic_exec "$_ctl" "SYSCFGEX" "=$_acqorder,$_band,$_val"
	fi
}

command_huawei_roam() {
	_info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	local roam=""
	if [ "$2" = "0" ];then		
		if [ "$_alias" == "redcap" -o "$_alias" == "mt5700" ];then
			roam="0"
		else
			roam="3"
		fi
		_command_huawei_roam "$1" "$roam" "$_alias"
	else
		if [ "$_alias" == "redcap" -o "$_alias" == "mt5700" ];then
			roam="$2"
		else
			roam="0"
		fi
		_command_huawei_roam "$1" "$roam" "$_alias"
	fi
}

command_huawei_model(){
	local _ctl="$1"
	local _info="$2"
	local _res _model
	local _cmd
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')

	if [ "$_alias" == "mt5700" ];then
		echo "MT5700M-CN"
		return
	fi

	_cmd="ATI"

	_res=$(_command_exec_raw "$_ctl" "$_cmd")
	[ -z "$_res" ] && return 1

	_model="$(echo "$_res"|grep 'Model:'|awk -F' ' '{print $2}')"
	echo "$_model"
}

command_huawei_sn(){
	local _ctl="$1"
	echo "tdtech0000000000"
}

command_huawei_checkethen(){
	local _ctl="$1"
	local _val="1,1"
	local _option
	local _res

	if ! _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}ETHEN=?"| grep "OK" ;then
		return 0
	fi
	echo  "support ETHEN"
	_res=$(_command_private_exec "$_ctl" "ETHEN" "?")
	[ -z "$_res" ] && return 1

	_option=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
	echo  "get ETHEN :$_option"
	if [ "$_option" = "$_val" ]; then
		return 0
	fi

	echo "do set ETHEN $_val"
	_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}ETHEN=$_val"
	return 2
}

command_huawei_checkmode(){
	local _ctl="$1"
	local _val="1"
	local _option
	local _res

	if ! _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}SETMODE=?"| grep "OK" ;then
		return 0
	fi

	echo  "support SETMODE"
	_res=$(_command_private_exec "$_ctl" "SETMODE" "?")
	[ -z "$_res" ] && return 1

	_option=$(echo "$_res"|awk -F' ' '{print $2}')
	echo  "get SETMODE :$_option"
	if [ "$_option" = "$_val" ]; then
		return 0
	fi

	echo "do set setmode $_val"
	_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}SETMODE=$_val"
	return 2
}

command_huawei_imssetstorage(){
	local _ctl="$1"
	local _data
	local _res
	local _val_cmgf="\"ME\",\"ME\",\"ME\""
	local max_try=5
	local error_response=0
	local match_key="SM"
	local _info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')

	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	
	if [ "$_alias" == "redcap" ];then
		_val_cmgf="\"SM\",\"SM\",\"SM\""
		match_key="ME"
	fi
	
	while true;do
		_res=$(_command_generic_exec "$_ctl" "CPMS" "?")
		if [ -n "$_res" ];then
			_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf|sed -e 's/ //g')
			if [ -n "$_data" ];then
				echo  "get CPMS :$_data"
				if echo "$_data" |grep -qEw "$match_key"; then
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

command_huawei_forceims(){
	local _ctl="$1"
	local val="$2"
	local ceus_val="1"
	local _data
	local _res
	local _ims_apn=""

	[ -z "$val" ] && val="1"
	[ "$val" == "1" ] && ceus_val="0" && _ims_apn="ims"
	local _val_forceims="$val,$val,$val"

	_info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')

	if [ "$_alias" == "redcap" -o "$_alias" == "mt5700" ];then
		_command_exec_raw "$1" "${AT_GENERIC_PREFIX}CGDCONT=5,\"IPV4V6\",\"$_ims_apn\",\"\",0,0,0,0,1,1,1"
	fi

	_res=$(_command_generic_exec "$_ctl" "CEUS" "?")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf|sed -e 's/ //g')
		if [ -n "$_data" ];then
			echo  "get ceus :$_data"
			if [ "$_data" != "$ceus_val" ]; then
				echo  "ceus :set $ceus_val"
				_command_generic_exec "$_ctl" "CEUS" "=$ceus_val"
			fi
		fi
	fi

	_res=$(_command_private_exec "$_ctl" "IMSSWITCH" "?")
	if [ -n "$_res" ];then
		_data=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf|sed -e 's/ //g')
		if [ -n "$_data" ];then
			echo  "get ims :$_data"
			if [ "$_data" != "$_val_forceims" ]; then
				echo  "ims :set $val"
				_command_private_exec "$_ctl" "IMSSWITCH" "=$_val_forceims"
				return 0
			fi
		fi
	fi

	return 1
}

command_huawei_check_pciephy(){
	local _ctl="$1"
	local _val="$2"
	local _option
	local _res

	if ! _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}TDPCIELANCFG=?"| grep "OK" ;then
		return 0
	fi
	echo  "support TDPCIELANCFG"
	_res=$(_command_private_exec "$_ctl" "TDPCIELANCFG" "?")
	[ -z "$_res" ] && return 1

	_option=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
	echo  "get TDPCIELANCFG :$_option"
	if [ "$_option" = "$_val" ]; then
		return 0
	fi

	echo "do set TDPCIELANCFG $_val"
	_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}TDPCIELANCFG=$_val"
	return 2
}

command_huawei_check_pciephytdp(){
	local _ctl="$1"
	local _val="1,0,0,0"
	local _option
	local _res

	if ! _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}TDPMCFG=?"| grep "OK" ;then
		return 0
	fi
	echo  "support TDPMCFG"
	_res=$(_command_private_exec "$_ctl" "TDPMCFG" "?")
	[ -z "$_res" ] && return 1

	_option=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
	echo  "get TDPMCFG :$_option"
	if [ "$_option" = "$_val" ]; then
		return 0
	fi

	echo "do set TDPMCFG $_val"
	_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}TDPMCFG=$_val"
	return 2
}

command_huawei_check_TDCFGMode(){
	local _ctl="$1"
	local _val="$2"
	local _option
	local _res
	local max_try=5
	local error_response=0

	while true;do
		_res=$(_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}TDCFG?")
		if [ -n "$_res" ];then
			_option=$(echo "$_res"|grep "Mode:"|awk -F':' '{print $2}'|xargs -r printf)
			if [ -n "$_option" ];then
				echo  "get TDCFG Mode:$_option"
				if [ "$_option" = "$_val" ]; then
					return 0
				else
					echo "do set TDCFG Mode $_val"
					_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}TDCFG="infcfg","mode",$_val"
					return 2
				fi
			fi			
		fi
		echo  "TDCFG :get error $error_response"
		error_response=$((error_response+1))
		if [ $error_response -gt $max_try ];then
			break
		fi
		sleep 1
	done
	return 1
}

command_huawei_check_autodail(){
	local _ctl="$1"	
	local dver="$2"
	local _val="1,2"
	local _option
	local _res

	if [ -z "$dver" ];then
		_val="0"
	fi
	if ! _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}SETAUTODIAL=?"| grep "OK" ;then
		return 0
	fi
	echo  "support SETAUTODIAL"
	_res=$(_command_private_exec "$_ctl" "SETAUTODIAL" "?")
	[ -z "$_res" ] && return 1

	_option=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
	if [ -z "$dver" ];then
		_data="$(echo "$_option"|awk -F',' '{print $1}')"
	else
		_data="$(echo "$_option"|awk -F',' '{print $1}'),$(echo "$_option"|awk -F',' '{print $2}')"
	fi
	echo  "$_data"
	if [ "$_data" = "$_val" ]; then
		return 0
	fi

	echo "do set SETAUTODIAL $_val"
	_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}SETAUTODIAL=$_val"
	return 2
}

command_huawei_check_nrrc(){
	local _ctl="$1"
	local _val="$2"
	local _option
	local _res

	_res=$(_command_private_exec "$_ctl" "NRRCCAPQRY" "=3")
	[ -z "$_res" ] && return 1

	_data=$(echo "$_res"|awk -F',' '{print $2}'|xargs -r printf)
	echo  "NRRCCAPQRY:$_data"
	if [ "$_data" = "$_val" ]; then
		return 0
	fi

	echo "do set NRRCCAPCFG $_val"
	_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRRCCAPCFG=3,$_val"
	return 2
}


command_huawei_preinit(){
	local model_autorestart=0
	local res
	local reset=0
	local _phycap=$(uci -q get network.${gNet}.phycap)
	local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
	[ -z "$simIndex" ] && simIndex="1"
	local ippass="0"
	local nrrc=$(uci -q get "cpecfg.${gNet}sim$simIndex.nrrc")
	if uci -q get "network.$gNet.ippass"|grep -qs "1";then
		ippass=$(uci -q get "cpecfg.${gNet}sim$simIndex.ippass")
	fi
	
	_info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	_driver=$(echo "$_info"|jsonfilter -e '$["driver"]')
	local dver=$(echo "$_info"|jsonfilter -e '$["dver"]')

	local _force_ims="0"
	if _check_simslot ;then
		_force_ims="1"
	fi
	[ -z "$nrrc" ] && nrrc="1"
	[ -z "$_phycap" ] && _phycap=0
	[ -z "$ippass" ] && ippass=0
	if [ $_phycap -lt 1000 ];then
		ippass=0
	fi
	command_generic_imsreport "$1"
	if command_huawei_imssetstorage "$1" ;then
		/etc/init.d/smsd restart
	fi

	command_generic_imsfmt "$1"
	
	if command_huawei_forceims "$1" "$_force_ims" ;then
		model_autorestart=1
	fi

	if [ "$_alias" == "mt5700" ];then
		if [ "$ippass" == "1" ];then
			command_huawei_check_TDCFGMode "$1" "3"
			res=$?
		else
			command_huawei_check_TDCFGMode "$1" "1"
			res=$?
		fi
		if [ $res -eq 2 ];then
			reset=1
		elif [ $res -eq 1 ];then
			return 1
		fi
		command_huawei_check_nrrc "$1" "$nrrc"
		res=$?
		if [ $res -eq 2 ];then
			model_autorestart=1
		elif [ $res -eq 1 ];then
			return 1
		fi
		if [ "$_driver" != "odu" ];then
			local pciephy=1
			if [ $_phycap -ge 2500 ];then
				pciephy=2
			fi
			command_huawei_check_pciephy "$1" "$pciephy"
			res=$?
			if [ $res -eq 2 ];then
				reset=1
			fi
			command_huawei_check_pciephytdp "$1"
			res=$?
			if [ $res -eq 2 ];then
				reset=1
			fi
			command_huawei_check_autodail "$1" "$dver"
			res=$?
			if [ $res -eq 2 ];then
				reset=1
			fi
		fi
	fi

	if [ -z "$_alias"  ];then
		command_huawei_checkethen "$1"
		res=$?
		if [ $res -eq 2 ];then
			reset=1
		elif [ $res -eq 1 ];then
			return 1
		fi

		command_huawei_checkmode "$1"
		res=$?
		if [ $res -eq 2 ];then
			model_autorestart=1
		fi
	fi

	if [ $reset -eq 1 ];then
		cpetools.sh -i "${gNet}" -r
		return 1
	fi

	if [ $model_autorestart -eq 1 ];then
		command_generic_reset "$1"
	fi

	return 0
}

command_huawei_usim_reset() {
	local _res
	local _ctl="$1"
	local _info="$2"

	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')

	if [ "$_alias" == "redcap" ];then
		_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}HVSST=1,0" "5"
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}SIMSWITCH=0,1" "5"
		_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}HVSST=1,1" "5"
		return 0
	elif [ "$_alias" == "mt5700" ];then
		_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}SCICHG=0,1" "5"
		return 0
	fi
	_res=$(command_huawei_model "$1" "$_info")
	if [ "$_res" == "MH5000-82M" ];then
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}SIMSWITCH=0" "5"
	fi
	return 0
}
command_huawei_usim_get() {
	local _ctl="$1"
	local _info="$2"

	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')

	[ "$_alias" != "redcap" -a "$_alias" != "mt5700" ] && return 1

	if [ "$_alias" == "mt5700" ];then
		_res=$(_command_private_exec "$_ctl" "SCICHG" "?")
		[ -z "$_res" ] && return 1
		_option=$(echo "$_res"|awk -F':' '{print $2}'|awk -F' ' '{print $1}')
		_option=$(echo "$_option"|awk -F',' '{print $1}'|awk -F' ' '{print $1}')
	else
		_res=$(_command_private_exec "$_ctl" "SIMSWITCH" "?")
		[ -z "$_res" ] && return 1
		_option=$(echo "$_res"|awk -F':' '{print $2}'|awk -F' ' '{print $1}')
	fi

	[ -n "$_option" ] && echo $((_option+1))
}

command_huawei_usim_set() {
	local _ctl="$1"
	local _new="$2"
	local _res

	_info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')

	if [ "$_alias" == "redcap" ];then
		local val=$((_new-1))
		$(_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}HVSST=1,0" "5")
		_res=$(_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}SIMSWITCH=${val},1" "5")
		$(_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}HVSST=1,1" "5")
	elif [ "$_alias" == "mt5700" ];then
		local val=$((_new-1))
		local val2="1"
		if [ $val == "1" ];then
			val2="0"
		fi
		_res=$(_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}SCICHG=$val,$val2" "5")
		_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}HVSST=1,0" "5"
		_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}HVSST=1,1" "5"
	else
		_res=$(_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}SIMSWITCH=${_new}" "5")
	fi
	echo  "command_huawei_usim_set $_res"
	[ -z "$_res" ] && return 1
	if echo "$_res"|grep "OK" ;then
		command_generic_reset "$_ctl"
		echo  "command_huawei_usim_set command_generic_reset"
		return 0
	fi
	echo  "command_huawei_usim_set error"
	return 1
}

command_huawei_rstsim() {
	local _ctl="$1"
	_info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	_vendor=$(check_soc_vendor)
	if [ "$_vendor" == "tdtech" -o "$_alias" == "mt5700" -o "$_alias" == "redcap" ];then
		_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}HVSST=1,0" "5"
		_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}HVSST=1,1" "5"
		return 0
	fi
	return 1
}

command_huawei_apn(){
	local _ctl="$1"
	local _info="$2"
	local cid="2"
	local apn=""
	local dver=$(echo "$_info"|jsonfilter -e '$["dver"]')
	_vendor=$(check_soc_vendor)
	if [ "$_vendor" == "tdtech" ];then
		cid="7"
	else
		_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
		
		[ "$_alias" == "redcap" ] && cid=1
		[ "$_alias" == "mt5700" ] && cid=8
		[ "$_alias" == "mt5700" ] && [ -z "$dver" ] && cid=1
	fi

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

command_huawei_dnn(){
	local _ctl="$1"
	local _info="$2"
	local cid="7"
	local cid2="8"
	local apn=""
	local apn2=""
	_vendor=$(check_soc_vendor)
	if [ "$_vendor" == "tdtech" ];then
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
				elif [ "$cid2" == "$_cur_cid" ];then
					apn2="$_cur_apn"
				fi
			fi
		done
	fi

	json_init
	json_add_array "APN"
	json_add_string "" "$apn"
	json_add_string "" "$apn2"
	json_dump
	json_cleanup
}

command_huawei_ips(){
	local _ctl="$1"
	local _info="$2"
	local dver=$(echo "$_info"|jsonfilter -e '$["dver"]')
	_vendor=$(check_soc_vendor)
	if [ "$_vendor" == "tdtech" ];then
		echo $(command_generic_ipaddr "$_ctl" "7")
	else
		_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
		if [ "$_alias" == "redcap" ];then
			echo $(command_generic_ipaddr "$_ctl" "1")
		elif [ "$_alias" == "mt5700" ];then
			if [ -z "$dver" ];then
				echo $(command_generic_ipaddr "$_ctl" "1")
			else
				echo $(command_generic_ipaddr "$_ctl" "8")
			fi
		else
			echo $(command_generic_ipaddr "$_ctl" "2")
		fi
	fi
}

command_huawei_pdp(){
	local _ctl="$1"
	local _info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	local dver=$(echo "$_info"|jsonfilter -e '$["dver"]')
	#local cid="$3"
	local pdptype="$4"
	local apn="$5"
	local auth="$6"
	local username="$7"
	local password="$8"
	local cid="2"
	local change=0
	local found=0
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')

	[ "$apn" == "\"\"" ] && apn=""
	[ "$auth" == "\"\"" ] && auth=""
	[ "$username" == "\"\"" ] && username=""
	[ "$password" == "\"\"" ] && password=""
	
	[ "$_alias" == "redcap" ] && cid=1
	[ "$_alias" == "mt5700" ] && cid=8
	[ "$_alias" == "mt5700" ] && [ -z "$dver" ] && cid=1
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
				if [ -z "$apn" ];then
					apn="$_cur_apn"
					if check_apn_disable ;then
						apn=""
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
	if [ $change -eq 1 ];then
		command_generic_reset "$1"
	fi
}
get_mobility_cfg(){
	local simIndex=$(uci -q get "cpesel.sim${gIndex}.cur")
	[ -z "$simIndex" ] && simIndex="1"
	local mobility=$(uci -q get "cpecfg.${gNet}sim$simIndex.mobility")
	[ -z "$mobility" ] && mobility="1"
	echo "$mobility"
}
_earfcn_huawei_5glock(){
	local _freqcfg _enable _band
	local _ctl="$1"
	local _info="$2"
	local earfcn="$3"
	local pci="$4"
	local band="$5"
	local scs=1
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	_freqcfg=$(_command_huawei_freq_get "$_ctl")
	[ -z "$_freqcfg" ] && return 1
	_enable=$(echo "$_freqcfg"|jsonfilter -e '$["enable"]')	

	if [ -z "$earfcn" -o "$earfcn" == "0" -o  -z "$band" -o "$band" == "0" ];then
		if [ "$_enable" != "0" ];then
			echo "earfcn5 nr free"
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRFREQLOCK=0" 2
		fi
		return 0
	fi

	if [ "$band" == "1" -o "$band" == "2" -o "$band" == "3" -o "$band" == "5" -o "$band" == "7" -o "$band" == "8" -o "$band" == "12" -o "$band" == "20" -o "$band" == "25" -o "$band" == "28" -o "$band" == "66" -o "$band" == "71" -o "$band" == "75" -o "$band" == "76" ];then
		scs=0
	elif [ "$band" == "38" -o "$band" == "40" -o "$band" == "41" -o "$band" == "48" -o "$band" == "77" -o "$band" == "78" -o "$band" == "79" ];then
		scs=1
	elif [ "$band" == "257" -o "$band" == "258" -o "$band" == "260" -o "$band" == "261" ];then
		scs=3
	fi
	local mobility="0"
	_scs=$(echo "$_freqcfg"|jsonfilter -e '$["scstype"]')
	if [ -z "$pci" ];then
		if [ "$_enable" == "1" ];then
			_band=$(echo "$_freqcfg"|jsonfilter -e '$["band"]')
			_earfcn=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')
			_mobility=$(echo "$_freqcfg"|jsonfilter -e '$["mobility"]')

			if [ -z "$_mobility" -o "$mobility" == "$_mobility" ];then
				if [ "$earfcn" == "$_earfcn" -a "$band" == "$_band" -a "$scs" == "$_scs" ];then
					return 0
				fi
			fi
		fi
		echo "earfcn5 set nr earfcn:$earfcn,old_earfcn:$_earfcn|band:$band,old_band:$_band|scs:$scs,old_scs:$_scs|mobility:$mobility,old_mobility:$_mobility"
		command_generic_cfun_c
		[ "$_enable" != "0" ] && _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRFREQLOCK=0" 2

		if [ "$_alias" == "redcap" -o "$_alias" == "mt5700" ];then
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRFREQLOCK=1,$mobility,1,\"$band\",\"$earfcn\",\"$scs\"" 2
		else
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRFREQLOCK=1,$scs,$band,$earfcn" 2
		fi
		command_generic_cfun_o
	else
		if [ "$_enable" == "2" ];then
			_band=$(echo "$_freqcfg"|jsonfilter -e '$["band"]')
			_earfcn=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')
			_pci=$(echo "$_freqcfg"|jsonfilter -e '$["cellid"]')
			_mobility=$(echo "$_freqcfg"|jsonfilter -e '$["mobility"]')

			if [ -z "$_mobility" -o "$mobility" == "$_mobility" ];then
				if [ "$earfcn" == "$_earfcn" -a "$band" == "$_band" -a "$pci" == "$_pci" -a "$scs" == "$_scs" ];then
					return 0
				fi
			fi
		fi
		echo "earfcn5 set nr earfcn:$earfcn,old_earfcn:$_earfcn|band:$band,old_band:$_band|pci:$pci,old_pci:$_pci|scs:$scs,old_scs:$_scs|mobility:$mobility,old_mobility:$_mobility"
		command_generic_cfun_c
		[ "$_enable" != "0" ] && _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRFREQLOCK=0" 2
		if [ "$_alias" == "redcap" -o "$_alias" == "mt5700" ];then
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRFREQLOCK=2,$mobility,1,\"$band\",\"$earfcn\",\"$scs\",\"$pci\"" 2
		else
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRFREQLOCK=2,$scs,$band,$earfcn,$pci" 2
		fi
		command_generic_cfun_o
	fi
}

_command_huawei_earfcn_get() {
	local _res _info
	local _enable=""
	local _mode=""
	local _arfcn=""
	local _band=""
	local _cellid=""
	local _alias="$2"

	if [ "$_alias" == "redcap" -o "$_alias" == "mt5700"  ];then
		local _res _info

		_res=$(_command_exec_raw "$1" "${AT_PRIVATE_PREFIX}LTEFREQLOCK?")
		nrfreq=$(echo "$_res" | grep "LTEFREQLOCK:")
		[ -z "$nrfreq" ] && return 1

		_info=$(echo "$nrfreq"|awk -F: '{print $2}')
		_change_info=$(echo "$_info"|xargs -r printf)

		json_init
		if [ "$_change_info" = "0" ];then
			json_add_string "enable" "$_change_info"
		else
			json_add_string "enable" "1"
		fi

		if [ "$_change_info" == "2" -o  "$_change_info" == "1" -o "$_change_info" == "3"  ];then
			_info=$(echo "$_res"|sed -n "4p")
			_flag=$(echo "$_res"|sed -n "3p")
			json_add_string "mode" "04"
			json_add_string "band" "$(echo "$_info"|awk -F, '{print $1}'|xargs -r printf)"
			json_add_string "arfcn" "$(echo "$_info"|awk -F, '{print $2}'|xargs -r printf)"
			json_add_string "cellid" "$(echo "$_info"|awk -F, '{print $3}'|xargs -r printf)"
			json_add_string "mobility" "$(echo "$_flag"|awk -F, '{print $1}'|xargs -r printf)"
		fi

		json_dump
		json_cleanup
		return 0
	fi

	_res=$(_command_private_exec "$1" "FREQLOCK" "?"|grep "\^FREQLOCK:")
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
			_arfcn_tmp="$(echo "$_data"|awk -F, '{print $3}')"
			_band_tmp="$(echo "$_data"|awk -F, '{print $4}')"
			_pci_tmp="$(echo "$_data"|awk -F, '{print $6}'|xargs -r printf)"

			if [ $_cnt -gt 1 ];then
				if [ "$_mode_tmp" == "04" ];then
					_enable="$_enable_tmp"
					_mode="$_mode_tmp"
					_arfcn="$_arfcn_tmp"
					_band="$_band_tmp"
					_cellid="$_pci_tmp"
					break
				fi
			else
				if [ "$_mode_tmp" == "04" ];then
					_enable="$_enable_tmp"
					_mode="$_mode_tmp"
					_arfcn="$_arfcn_tmp"
					_band="$_band_tmp"
					_cellid="$_pci_tmp"
				else
					_enable="0"
				fi
			fi
		fi
	done

	json_init
	json_add_string "enable" "$_enable"
	json_add_string "mode" "$_mode"
	json_add_string "arfcn" "$_arfcn"
	json_add_string "band" "$_band"
	json_add_string "cellid" "$_cellid"
	json_dump
	json_cleanup
}


_command_huawei_earfcn4g_get() {
	local _res _info

	_res=$(_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}FREQLOCK?"|grep "\^FreqLock")
	[ -z "$_res" ] && return 1
	_info=$(echo "$_res"|awk -F: '{print $2}')
	_change_info=$(echo "$_info"|xargs -r printf)

	json_init
	if [ "$_change_info" = "0" ];then
		json_add_string "enable" "$_change_info"
	else
		json_add_string "enable" "$(echo "$_info"|awk -F, '{print $1}'|xargs -r printf|awk '$1= $1')"
	fi

	json_add_string "mode" "$(echo "$_info"|awk -F, '{print $2}'|sed 's/"//g')"
	json_add_string "arfcn" "$(echo "$_info"|awk -F, '{print $3}'|xargs -r printf)"
	json_dump
	json_cleanup
}


_command_huawei_earfcncell4g_get() {
	local _res _info

	_res=$(_command_private_exec "$1" "CELLLOCK" "?")
	[ -z "$_res" ] && return 1
	_info=$(echo "$_res"|awk -F: '{print $2}')
	_change_info=$(echo "$_info"|xargs -r printf)

	json_init
	if [ "$_change_info" = "0" ];then
		json_add_string "enable" "$_change_info"
	else
		json_add_string "enable" "$(echo "$_info"|awk -F, '{print $1}'|xargs -r printf|awk '$1= $1')"
	fi
	_pci="$(echo "$_info"|awk -F, '{print $5}'|xargs -r printf|sed -e 's/^0*//g')"
	[ -n "$_pci" ] && {
		_pci=$(printf %d 0x$_pci)
	}

	json_add_string "mode" "$(echo "$_info"|awk -F, '{print $2}'|sed 's/"//g')"
	json_add_string "arfcn" "$(echo "$_info"|awk -F, '{print $4}'|xargs -r printf)"
	json_add_string "cellid" "$_pci"
	json_dump
	json_cleanup
}



_earfcn_huawei_4glock(){
	local _freqcfg _cellcfg _enable _band
	local _ctl="$1"
	local _info="$2"
	local earfcn="$3"
	local pci="$4"

	_freqcfg=$(_command_huawei_earfcn4g_get "$_ctl")
	_cellcfg=$(_command_huawei_earfcncell4g_get "$_ctl")
	[ -z "$_freqcfg" ] && return 1
	_enable=$(echo "$_freqcfg"|jsonfilter -e '$["enable"]')
	_enable_cell=$(echo "$_cellcfg"|jsonfilter -e '$["enable"]')

	if [ -z "$earfcn" -o "$earfcn" == "0" ];then
		if [ "$_enable" != "0" ];then
			echo "earfcn4 free freqlock"
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}FREQLOCK=0" 2
		fi
		if [ "$_enable_cell" != "0" ];then
			echo "earfcn4 free celllock"
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}CELLLOCK=0" 2
		fi

		return 0
	fi
	if [ -z "$pci" ];then
		if [ "$_enable_cell" == "1" ];then
			echo "earfcn4 free celllock"
			 _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}CELLLOCK=0" 2
		fi
		if [ "$_enable" == "1" ];then
			_mode=$(echo "$_freqcfg"|jsonfilter -e '$["mode"]')
			_earfcn=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')

			if [ "$_mode" == "04" -a "$earfcn" == "$_earfcn" ];then
				return 0
			fi
		fi
	else
		if [ "$_enable" == "1" ];then
			echo "earfcn4 free freqlock"
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}FREQLOCK=0" 2
		fi
		if [ "$_enable_cell" == "1" ];then
			_mode=$(echo "$_cellcfg"|jsonfilter -e '$["mode"]')
			_earfcn=$(echo "$_cellcfg"|jsonfilter -e '$["arfcn"]')
			_pci=$(echo "$_cellcfg"|jsonfilter -e '$["cellid"]')

			if [ "$_mode" == "04" -a "$earfcn" == "$_earfcn" -a "$_pci" == "$pci" ];then
				return 0
			fi
		fi
	fi
	[ "$_enable" != "0" ] && _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}FREQLOCK=0" 2
	[ "$_enable_cell" != "0" ] && _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}CELLLOCK=0" 2
	[ -n "$pci" ] && {
		pci=$(printf %x $pci)
		pci=$(echo $pci | tr '[a-z]' '[A-Z]')
	}
	echo "earfcn4 set earfcn:$earfcn pci:$pci"
	command_generic_cfun_c
	if [ -z "$pci" ];then
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}FREQLOCK=1,\"04\",$earfcn" 2
	else
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}CELLLOCK=1,\"04\",,$earfcn,$pci" 2
	fi
	command_generic_cfun_o
}

_earfcn_huawei_5g_4glock(){
	local _freqcfg _enable _band
	local _ctl="$1"
	local _info="$2"
	local earfcn="$3"
	local pci="$4"
	local band="$5"

	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	_freqcfg=$(_command_huawei_earfcn_get "$_ctl" "$_alias")
	[ -z "$_freqcfg" ] && return 1
	_enable=$(echo "$_freqcfg"|jsonfilter -e '$["enable"]')
	local mobility="0"

	if [ -z "$earfcn" -o "$earfcn" == "0" ];then
		if [ "$_enable" != "0" ];then
			_mode=$(echo "$_freqcfg"|jsonfilter -e '$["mode"]')
			if [ "$_mode" == "04" ];then
				echo "earfcn5 lte free"
				if [ "$_alias" == "redcap"  -o "$_alias" == "mt5700" ];then
					_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}LTEFREQLOCK=0" 2
				else
					_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}FREQLOCK=0" 2
				fi
			fi
		fi
		return 0
	fi

	if [ "$_enable" == "1" ];then
		_mode=$(echo "$_freqcfg"|jsonfilter -e '$["mode"]')
		_earfcn=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')
		_band=$(echo "$_freqcfg"|jsonfilter -e '$["band"]')
		_pci=$(echo "$_freqcfg"|jsonfilter -e '$["cellid"]')
		_mobility=$(echo "$_freqcfg"|jsonfilter -e '$["mobility"]')

		if [ "$_mode" == "04" ];then
			if [ -z "$pci" ];then
				if [ -z "$_mobility" -o "$mobility" == "$_mobility" ];then
					if [ "$earfcn" == "$_earfcn" -a -z "$_pci" ];then
						return 0
					fi
				fi
			else
				if [ -z "$_mobility" -o "$mobility" == "$_mobility" ];then
					if [ "$earfcn" == "$_earfcn" -a "$_pci" == "$pci" -a "$_band" == "$band" ];then
						return 0
					fi
				fi
			fi
		fi
	fi
	echo "earfcn5 old lte $_enable earfcn:$_earfcn pci:$_pci band:$_band mobility:$_mobility"
	echo "earfcn5 set lte earfcn:$earfcn pci:$pci band:$band mobility:$mobility"

	if [ "$_alias" == "redcap"  -o "$_alias" == "mt5700" ];then
		[ "$_enable" != "0" ] && _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}LTEFREQLOCK=0" 2
		command_generic_cfun_c
		if [ -z "$pci" ];then
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}LTEFREQLOCK=1,$mobility,1,\"$band\",\"$earfcn\"" 2
		else
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}LTEFREQLOCK=2,$mobility,1,\"$band\",\"$earfcn\",\"$pci\"" 2
		fi
		command_generic_cfun_o
	else
		[ "$_enable" != "0" ] && _command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}FREQLOCK=0" 2
		command_generic_cfun_c
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}FREQLOCK=1,\"04\",$earfcn,,,$pci" 2
		command_generic_cfun_o
	fi
}

command_huawei_earfcn() {
	local _ctl="$1"
	local _info="$2"
	local mode="$3"
	local earfcn="$4"
	local pci="$5"
	local band="$6"
	local _res _info
	
	_res=$(_command_private_exec "$1" "NRFREQLOCK" "?")

	if [ "$mode" == "NR" ];then
		if [ -z "$_res" ];then
			return 0
		else
			_earfcn_huawei_5glock "$_ctl" "$_info" "$earfcn" "$pci" "$band"
		fi
	elif [ "$mode" == "LTE" ];then
		if [ -z "$_res" ];then
			_earfcn_huawei_4glock "$_ctl" "$_info" "$earfcn" "$pci"
		else
			_earfcn_huawei_5g_4glock "$_ctl" "$_info" "$earfcn" "$pci" "$band"
		fi
	else
		return 0
	fi
}

command_huawei_earfcn_info() {
	local _ctl="$1"
	local _info="$2"
	local _res _info
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	_res=$(_command_private_exec "$1" "NRFREQLOCK" "?")
	if [ -n "$_res" ];then
		_freqcfg=$(_command_huawei_earfcn_get "$_ctl" "$_alias")
		[ -n "$_freqcfg" ] && {
			_enable=$(echo "$_freqcfg"|jsonfilter -e '$["enable"]')
			_mode=$(echo "$_freqcfg"|jsonfilter -e '$["mode"]')
			_band=$(echo "$_freqcfg"|jsonfilter -e '$["band"]')
			_earfcn=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')
			_pci=$(echo "$_freqcfg"|jsonfilter -e '$["cellid"]')
			_mobility=$(echo "$_freqcfg"|jsonfilter -e '$["mobility"]')
		}

		_freqcfg=$(_command_huawei_freq_get "$_ctl")
		[ -n "$_freqcfg" ] && {
			_enable5=$(echo "$_freqcfg"|jsonfilter -e '$["enable"]')
			_band5=$(echo "$_freqcfg"|jsonfilter -e '$["band"]')
			_earfcn5=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')
			_pci5=$(echo "$_freqcfg"|jsonfilter -e '$["cellid"]')
			_mobility5=$(echo "$_freqcfg"|jsonfilter -e '$["mobility"]')
		}

		json_init
		json_add_array "earfcn"
		json_add_object

		if [ "$_enable5" = "0" ];then
			json_add_string "status" "0"
		else
			json_add_string "status" "1"
			json_add_string "BAND" "$_band5"
			json_add_string "EARFCN" "$_earfcn5"
			json_add_string "PCI" "$_pci5"
			json_add_string "MOBILITY" "$_mobility5"
		fi
		json_add_string "MODE" "NR"

		json_close_object
		json_add_object
		if [ "$_enable" = "0" ];then
			json_add_string "status" "0"
		else
			json_add_string "status" "1"
			json_add_string "EARFCN" "$_earfcn"
			json_add_string "BAND" "$_band"
			json_add_string "PCI" "$_pci"
			json_add_string "MOBILITY" "$_mobility"
		fi
		json_add_string "MODE" "LTE"
		json_close_object
		json_close_array
		json_dump
		json_cleanup
	else
		_cellcfg=$(_command_huawei_earfcncell4g_get "$_ctl")
		if [ -n "$_cellcfg" ];then
			_enable=$(echo "$_cellcfg"|jsonfilter -e '$["enable"]')
			_mode=$(echo "$_cellcfg"|jsonfilter -e '$["mode"]')
			_earfcn=$(echo "$_cellcfg"|jsonfilter -e '$["arfcn"]')
			_pci=$(echo "$_cellcfg"|jsonfilter -e '$["cellid"]')
		fi
		_freqcfg=$(_command_huawei_earfcn4g_get "$_ctl")
		if [ -n "$_freqcfg" ];then
			_enable1=$(echo "$_freqcfg"|jsonfilter -e '$["enable"]')
			_mode1=$(echo "$_freqcfg"|jsonfilter -e '$["mode"]')
			_earfcn1=$(echo "$_freqcfg"|jsonfilter -e '$["arfcn"]')
			if [ "$_enable1" == "1" ];then
				_enable="$_enable1"
			fi
			if [  -n "$_mode1" ];then
				_mode="$_mode1"
			fi
			if [ -n "$_earfcn1" ];then
				_earfcn="$_earfcn1"
			fi
			_pci1=$(echo "$_freqcfg"|jsonfilter -e '$["cellid"]')
		fi

		json_init
		json_add_array "earfcn"

		json_add_object
		if [ "$_enable" = "0" ];then
			json_add_string "status" "0"
		else
			json_add_string "status" "1"
			json_add_string "EARFCN" "$_earfcn"
			json_add_string "PCI" "$_pci"
		fi
		json_add_string "MODE" "LTE"
		json_close_object
		json_close_array
		json_dump
		json_cleanup
	fi
}

command_huawei_analysis(){
	local _ctl="$1"
	local _info="$2"
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	local dver=$(echo "$_info"|jsonfilter -e '$["dver"]')

	echo $(command_huawei_basic "$_ctl" "$_info")
	_vendor=$(check_soc_vendor)
	if [ "$_vendor" == "tdtech" ];then
		echo $(command_generic_ipaddr "$_ctl" "7")
	else
		if [ "$_alias" == "redcap" ];then
			echo $(command_generic_ipaddr "$_ctl" "1")
		elif  [ "$_alias" == "mt5700" ];then
			if [ -z "$dver" ];then
				echo $(command_generic_ipaddr "$_ctl" "1")
			else
				echo $(command_generic_ipaddr "$_ctl" "8")
			fi
		else
			echo $(command_generic_ipaddr "$_ctl" "2")
		fi
	fi
}
command_huawei_compatibility(){
	local _ctl="$1"
	local _info="$2"
	local compatibility="$3"
	local blacklist_band="$4"
	local band_skip=""
	local black_list=""
	local black_count=0
	local _res _info
	_nrcap=$(echo "$_info"|jsonfilter -e '$["nrcap"]')
	[ -z "$blacklist_band" ] && return 1
	[ "$_nrcap" != "1" ] && return 1

	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	if  [ "$_alias" == "mt5700" ];then
		return 1
	fi

	_res=$(_command_private_exec "$1" "NRBANDBLACKLIST" "?")
	[ -z "$_res" ] && return 1
	_data=$(echo "$_res"|awk -F: '{print $2}'|xargs -r printf)
	local _data_list=${_data//,/ }
	band_skip=${blacklist_band//:/,}
	echo "blacklist_band:$band_skip"
	local todo_data_list=${band_skip//,/ }
	for todo_band_item in $todo_data_list
	do
		black_count=$((black_count+1))
	done

	local index=0
	for band_item in $_data_list
	do
		index=$((index+1))
		if [ $index -ge 3 ];then
			black_list="${black_list:+$black_list,}$band_item"
		fi
	done

	if [ "$compatibility" == "0" -a "$black_list" != "$band_skip" ];then
		echo "compatibility blacklist $black_count:$band_skip"
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRBANDBLACKLIST=3,$black_count,\"$band_skip\""
		command_generic_reset "$_ctl"
	fi
	if [ "$compatibility" == "1" -a $index -ge 3 ];then
		local count=1
		[ $index -ge 3 ] && count=$((index-2))
		echo "compatibility erase blacklist $count:$black_list"
		_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRBANDBLACKLIST=2,$count,\"$black_list\""
		command_generic_reset "$_ctl"
	fi
}

_command_huawei_nr(){
	local _ctl="$1"
	local freq="$3"
	local lock_list=""
	local freq_count=0
	local _res
	local _freq_lock_cnt=""
	local _freq_lock_type=""
	local _freq_mobility=""
	_res=$(_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRFREQLOCK?" )
	[ -z "$_res" ] && return 1
	local mobility=$(get_mobility_cfg)
	_cnt=$(echo "$_res"|wc -l)
	i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			if echo "$line"|grep -q "OK" ;then
				break
			fi

			if [ "$_freq_lock_type" == "3" ];then
				if [ -n "$_freq_lock_cnt" ];then
					lock_list="${lock_list:+$lock_list,}$line"
				fi

				if echo "$line"|grep -q "," ;then
					_freq_lock_cnt=$(echo "$line"|awk -F, '{print $2}'|xargs -r printf)
					_freq_mobility=$(echo "$line"|awk -F, '{print $1}'|xargs -r printf)
				fi
			elif [ "$_freq_lock_type" == "2" -o "$_freq_lock_type" == "1" ];then
				lock_list="-"
			fi
			if echo "$line"|grep -q "NRFREQLOCK:" ;then
				_freq_lock_type="$(echo "$line"|awk -F: '{print $2}'|xargs -r printf)"
			fi
		fi
	done

	local _data_list=${_data//,/ }
	band_list=${freq//:/,}
	echo "band_list:$band_list"
	echo "lock_list:$lock_list"
	echo "band mobility:$_freq_mobility"
	echo "lock mobility:$mobility"

	local todo_data_list=${band_list//,/ }
	for todo_band_item in $todo_data_list
	do
		freq_count=$((freq_count+1))
	done

	if [ "$lock_list" != "$band_list" -o "$_freq_mobility" != "$mobility" ];then
		echo "compatibility freq $freq_count $freq"
		if [ "$freq_count" == "1" ];then
			mobility="0"
		fi
		command_generic_cfun_c
		if [ -z "$band_list" ];then
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRFREQLOCK=0"
		else
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}NRFREQLOCK=3,$mobility,$freq_count,\"$band_list\""
		fi
		command_generic_cfun_o
	fi
}

_command_huawei_lte(){
	local _ctl="$1"
	local freq="$3"
	local lock_list=""
	local freq_count=0
	local _res
	local _freq_lock_cnt=""
	local _freq_lock_type=""
	local _freq_mobility=""
	_res=$(_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}LTEFREQLOCK?" )
	[ -z "$_res" ] && return 1
	local mobility=$(get_mobility_cfg)
	_cnt=$(echo "$_res"|wc -l)
	i=0
	while [ $i -lt $_cnt ];do
		i=$((i+1))
		line=$(echo "$_res" |sed -n "${i}p")
		if [ -n "$line" ];then
			if echo "$line"|grep -q "OK" ;then
				break
			fi

			if [ "$_freq_lock_type" == "3" ];then

				if [ -n "$_freq_lock_cnt" ];then
					lock_list="${lock_list:+$lock_list,}$line"
				fi

				if echo "$line"|grep -q "," ;then
					_freq_lock_cnt=$(echo "$line"|awk -F, '{print $2}'|xargs -r printf)
					_freq_mobility=$(echo "$line"|awk -F, '{print $1}'|xargs -r printf)
				fi
			elif [ "$_freq_lock_type" == "2" -o "$_freq_lock_type" == "1" ];then
				lock_list="-"
			fi
			if echo "$line"|grep -q "LTEFREQLOCK:" ;then
				_freq_lock_type="$(echo "$line"|awk -F: '{print $2}'|xargs -r printf)"
			fi
		fi
	done

	local _data_list=${_data//,/ }
	band_list=${freq//:/,}
	echo "lte band_list:$band_list"
	echo "lte lock_list:$lock_list"
	echo "lte band mobility:$_freq_mobility"
	echo "lte lock mobility:$mobility"

	local todo_data_list=${band_list//,/ }
	for todo_band_item in $todo_data_list
	do
		freq_count=$((freq_count+1))
	done

	if [ "$lock_list" != "$band_list" -o "$_freq_mobility" != "$mobility" ];then
		echo "lte compatibility freq $freq_count $freq"
		if [ "$freq_count" == "1" ];then
			mobility="0"
		fi
		command_generic_cfun_c
		if [ -z "$band_list" ];then
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}LTEFREQLOCK=0"
		else
			_command_exec_raw "$_ctl" "${AT_PRIVATE_PREFIX}LTEFREQLOCK=3,$mobility,$freq_count,\"$band_list\""
		fi

		command_generic_cfun_o
	fi
}

command_huawei_recovery_cgatt(){
	local _ctl="$1"
	while true;do
		_res=$(_command_exec_raw "$_ctl" "${AT_GENERIC_PREFIX}CGATT?" 2)
		if [ -n "$_res" ];then
			_info="$(echo "$_res"|awk -F: '{print $2}'|sed 's/ //g'|xargs -r printf)"
			if [ "$_info" != "1" ];then
				_command_generic_exec "$_ctl" "CGATT" "=1" > /dev/null
			else
				break
			fi
		fi

		sleep 1
	done
}

_command_huawei_getrgmii(){
	local _ctl="$1"
	local _pci_val="2"
	local _option
	local _res
	local match_data=0
	local _pmcfg_val="1,0,0,0"
	local _auto_val="1,2"
	json_init
	_res=$(_command_private_exec "$_ctl" "TDPCIELANCFG" "?")
	[ -n "$_res" ] && {
		_option=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		if [ "$_option" = "$_pci_val" ]; then
			match_data=$((match_data+1))
		fi
	}

	_res=$(_command_private_exec "$_ctl" "TDPMCFG" "?")
	[ -n "$_res" ] && {
		_option=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		if [ "$_option" = "$_pmcfg_val" ]; then
			match_data=$((match_data+1))
		fi
	}

	_res=$(_command_private_exec "$_ctl" "SETAUTODIAL" "?")
	[ -n "$_res" ] && {
		_option=$(echo "$_res"|awk -F':' '{print $2}'|xargs -r printf)
		_data="$(echo "$_option"|awk -F',' '{print $1}'),$(echo "$_option"|awk -F',' '{print $2}')"

		if [ "$_data" = "$_auto_val" ]; then
			match_data=$((match_data+1))
		fi
	}

	if [ $match_data -eq 3 ];then
		json_add_string "status" "open"
	else
		json_add_string "status" "close"
	fi

	json_dump
	json_cleanup
}

command_huawei_getrgmii(){
	local _ctl="$1"
	local _info="$2"

	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	if  [ "$_alias" == "mt5700" ];then
		_data=$(_command_huawei_getrgmii "$_ctl")
		_status=$(echo "$_data"|jsonfilter -e '$["status"]')
	fi

	json_init
	json_add_string "status" $_status
	json_add_string "model" $(command_huawei_model "$1" "$_info")
	json_dump
	json_cleanup
}

command_huawei_openrgmii(){
	local _ctl="$1"
	local _info="$2"
	local _code=2

	_data=$(command_huawei_getrgmii "$_ctl" "$_info")
	_status=$(echo "$_data"|jsonfilter -e '$["status"]')
	if [ "$_status" != "open" ];then
		_data=$(command_huawei_check_pciephy "$1" "2")
		_data=$(command_huawei_check_pciephytdp "$1")
		_data=$(command_huawei_check_autodail "$1")
		_code=0
	fi

	json_init
	json_add_int "code" $_code
	json_add_string "model" $(command_huawei_model "$1" "$_info")
	json_dump
	json_cleanup
}

command_huawei_connstat(){
	local _ctl="$1"
	local _info="$2"
	local _cid="2"
	local dver=$(echo "$_info"|jsonfilter -e '$["dver"]')
	local _vendor=$(check_soc_vendor)
	if [ "$_vendor" == "tdtech" ];then
		_cid="7"
	else
		_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
		if [ "$_alias" == "redcap" ];then
			_cid="1"
		elif [ "$_alias" == "mt5700" ];then
			if [ -z "$dver" ];then
				_cid="1"
			else
				_cid="8"
			fi
		else
			_cid="2"
		fi
	fi
	_res=$(_command_private_exec "$1" "NDISSTATQRY" "=$_cid")
	[ -z "$_res" ] && return 1
	_res=$(echo "$_res"|awk -F: '{print $2}')
	[ -z "$_res" ] && return 1
	_stat=$(echo "$_res"|awk -F, '{print $1}'|sed 's/\"//g'|xargs -r printf)
	_type=$(echo "$_res"|awk -F, '{print $4}'|sed 's/\"//g'|xargs -r printf)

	_stat2=$(echo "$_res"|awk -F, '{print $5}'|sed 's/\"//g'|xargs -r printf)
	_type2=$(echo "$_res"|awk -F, '{print $8}'|sed 's/\"//g'|xargs -r printf)

	json_init
	[ -n "$_stat" ] && json_add_string "$_type" "$_stat"
	[ -n "$_stat2" ] && json_add_string "$_type2" "$_stat2"
	json_dump
	json_cleanup
	return 0
}


command_huawei_temp(){
	local _ctl="$1"
	_vendor=$(check_soc_vendor)
	_info=$(cat "/tmp/infocd/cache/${gNet}_dev" |jsonfilter -e '$["parameter"]')
	_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
	_res=$(_command_private_exec "$_ctl" "CHIPTEMP" "?")
	[ -z "$_res" ] && return 1
	_res="$(echo "$_res"|awk -F: '{print $2}'|sed 's/"//g'|sed 's/ //g')"
		
	if [ "$_alias" == "redcap" -o "$_vendor" == "tdtech" ];then
		_cur_type="$(echo "$_res"|awk -F, '{print $1}'|sed 's/"//g')"
		echo "$_cur_type"|awk '{printf "%d",$1/10}'
	else
		_cur_type="$(echo "$_res"|awk -F, '{print $8}'|sed 's/"//g')"
		echo "$_cur_type"|awk '{printf "%d",$1/10}'
	fi
}

command_huawei_dnsv6(){
	local _ctl="$1"
	local _info="$2"
	local cid=""
	local dver=$(echo "$_info"|jsonfilter -e '$["dver"]')
	_vendor=$(check_soc_vendor)
	if [ "$_vendor" == "tdtech" ];then
		cid="7"
	else
		_alias=$(echo "$_info"|jsonfilter -e '$["alias"]')
		if [ "$_alias" == "redcap" ];then
			cid="1"
		elif [ "$_alias" == "mt5700" ];then
			if [ -z "$dver" ];then
				cid="1"
			else
				cid="8"
			fi
		else
			cid="2"
		fi
	fi

	_res=$(_command_private_exec "$_ctl" "DHCPV6" "=$cid")
	[ -z "$_res" ] && return 1
	_dnsv6_1="$(echo "$_res"|awk -F, '{print $5}')"
	_dnsv6_2="$(echo "$_res"|awk -F, '{print $6}')"

	json_init
	[ -n "$_dnsv6_1" ] && json_add_string "dns1" "$_dnsv6_1"
	[ -n "$_dnsv6_2" ] && json_add_string "dns2" "$_dnsv6_2"
	json_dump
	json_cleanup
}
