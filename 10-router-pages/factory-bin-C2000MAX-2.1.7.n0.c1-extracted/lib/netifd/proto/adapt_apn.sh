#!/bin/sh
. /usr/share/libubox/jshn.sh
. /lib/functions.sh

mcc_bit=3
loop_apn() {
	local msid
	local imsi=$1
	local mnc_bit=$2
	msid=${imsi:0:$((mnc_bit+mcc_bit))}
	local apn_data=$(jsonfilter -e '@.*[@.code="'$msid'"]' </etc/apn.json )
	if [ -n "$apn_data" ];then
		echo "interface:$interface" >> /tmp/adapt_apn.log
		echo $apn_data
	fi

	return 1
}

init_apn_data(){
	data_json=$(loop_apn $1 3)
	if [ -n "$data_json" ];then
		echo  $data_json
	else 
		data_json=$(loop_apn $1 2)
		if [ -n "$data_json" ];then
			echo  $data_json
		fi
	fi
}


loop_plmn() {
	local msid
	local imsi=$1
	local mnc_bit=$2
	msid=${imsi:0:$((mnc_bit+mcc_bit))}
	local company_data=$(jsonfilter -e '@[@.plmn[@="'$msid'"]].company' </usr/lib/lua/luci/plmn.json )
	if [ -n "$company_data" ];then
		echo $company_data
	fi
	return 1
}

check_verison_sim(){
	imsi="$1"
	if [ -z "$imsi" ];then		
		return 0
	fi
	
	company_data=$(loop_plmn $imsi 3)
	if [ -z "$company_data" ];then
		company_data=$(loop_plmn $imsi 2)
		if [ -z "$company_data" ];then
			return 0
		fi
	fi
	echo  "company:$company_data"
	if [ "$company_data" = "Verizon" ];then
		return 1
	fi

	return 0
}