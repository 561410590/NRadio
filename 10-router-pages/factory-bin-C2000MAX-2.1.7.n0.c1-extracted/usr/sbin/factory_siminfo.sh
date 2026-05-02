#!/bin/ash

. /lib/functions.sh
. /lib/network/switch.sh
. /usr/share/libubox/jshn.sh

gLedStatus="hc:blue:status"
gTries=0
gCard_num=0
gCard_id=
gSim_all=
gCpe_all=
gRecheck=$(uci -q get factory_check.cpe.recheck) || gRecheck=5

set_led() {
	local dev=$1
	local status=$2
	local delay=100
	local color=
	local mode=

	color=$(echo "$dev"|cut -d':' -f2)
	mode=$(echo "$dev"|cut -d':' -f3)

	case "$status" in
		on)
			setled on "$color" "$mode"
			;;
		off)
			setled off "$color" "$mode"
			;;
		timer)
			setled timer "$color" "$mode" "$delay" "$delay"
			;;
	esac
}

all_leds_action() {
	for led in $(find /sys/class/leds/ -maxdepth 1 -mindepth 1); do
		set_led "$led" "$1"
	done
}
check_iccid(){
	local sim_iccid=$1
	local iccid_min=19
	local iccid_max=22
	local check_case=
	local iccid_case=
	local check_top=

	check_top=$(echo "${sim_iccid}"|cut -c1-2)
	if [ "$check_top" != "89" ]; then
		return 1
	fi

	if generic_validate_char_len $sim_iccid $iccid_min $iccid_max; then
		if [ $gCard_num -ge 1 ]; then
			for iccid_case in $gCard_id; do
				check_case=$(uci get "factory_check.cpe.${iccid_case}_iccid")
				if [ "$sim_iccid"x = "$check_case"x ]; then
					return 1
				fi
			done
		fi
	else
		return 1
	fi

}
generic_validate_char_len() {
	local _str=$1
	local _min=$2
	local _max=$3

	if ! echo "$_str"|grep -E "^[0-9A-Za-z]{$_min,$_max}$"; then
		return 1
	fi
}

cpe_check(){
	local imei_max=17
	local imei_min=15
	local sim_max=
	local sim_stype=
	local sim_card_stype=
	local card_iccid=
	local sim_idx=
	local imei_identity=
	local wait_time=
	local sim_cur=
	local sim=
	local cpe=
	local wait=
	local tries=
	local imei=
	local existing_imei=
	local select_id=
	local result=0
	
	wait=$(uci get factory_check.cpe.wait)

	for sim in ${gSim_all}; do
		cpe=$(echo ${sim} | sed 's/sim/cpe/g')
		imei=$(echo ${sim} | sed 's/sim/imei/g')

		existing_imei=$(uci -q get "factory_check.cpe.${imei}")
		if ! generic_validate_char_len "$existing_imei" "$imei_min" "$imei_max"; then
			tries=0
			uci set "factory_check.cpe.${imei}="
			while [ "$tries" -lt 20 ]; do
				cpetools.sh -t 0 -c "ATE1" -i ${cpe}
				imei_identity=$(cpetools.sh -c imei -i ${cpe})
				if generic_validate_char_len $imei_identity $imei_min $imei_max; then
					uci set "factory_check.cpe.${imei}=${imei_identity}"
					break
				else
					tries=$((tries+1))
				fi
			done
			if [ "$tries" -ge 20 ]; then
				result=1
				return $result
			fi
		fi

		sim_max=$(uci get cpesel.${sim}.max)
		sim_stype=$(uci get cpesel.${sim}.stype)
		sim_cur=$(uci get cpesel.${sim}.cur)

		for sim_idx in ${sim_cur} $(seq 1 "${sim_max:-1}"|sed "s/${sim_cur}//g"); do
			sim_card_stype=$(echo "$sim_stype"|cut -d, -f"$sim_idx")
			select_id="${sim}${sim_idx}"
			if [ "${sim_card_stype:-0}"x != "0"x ]; then
				uci set "factory_check.cpe.${select_id}_iccid="
				uci commit factory_check
				cpetools.sh -s "$sim_idx" -i ${cpe}
				sleep 2
				wait_time=0
				while [ "$wait_time" -le "$wait" ]; do
					card_iccid=$(cpetools.sh -c iccid -i ${cpe})
					if check_iccid $card_iccid ; then
						break
					fi
					wait_time=$((wait_time+1))
					sleep 1
				done

				if [ "$wait_time" -gt "$wait" ]; then
					result=1
					continue
				fi

				uci set "factory_check.cpe.${select_id}_iccid=$card_iccid"
				uci commit factory_check
				gCard_num=$((gCard_num+1))
				gCard_id="$gCard_id ${select_id}"
			fi
		done
	done

	return $result
}

get_cpe_all(){
	local sim_num=
	local sim_id=
	local sim_case=
	local sim_all=
	local sim_ignore=
	local flag=
	local all_case=
	local ignore_case=

	sim_all="sim"
	sim_num=$(uci show cpesel|grep -c "=cpesel")

	sim_ignore=$(uci get factory_check.cpe.ignore)

	if [ "${sim_num}" -gt "1" ]; then
		sim_num=$((sim_num-1))
		for sim_id in $(seq 1 "${sim_num}"); do
			sim_case="sim${sim_id}"
			sim_all="${sim_all} ${sim_case}"
		done
	fi

	for all_case in $sim_all; do
		flag=0
		for ignore_case in $sim_ignore; do
			if [ "$all_case" == "$ignore_case" ]; then
				flag=1
				break
			fi
		done
		
		if [ $flag -eq 0 ]; then
			gSim_all="$gSim_all $all_case"
		fi
	done
		
	gCpe_all=$(echo ${gSim_all} | sed 's/sim/cpe/g')
}


pre_init(){
	local result_case
	local cpe_case

	/etc/init.d/ledctrl stop
	/etc/init.d/wanchk stop
	/etc/init.d/cpesel stop
	/etc/init.d/wanswd stop

	for cpe_case in ${gCpe_all} ; do
		uci set network.${cpe_case}.disabled=1
	done
	uci commit

	ubus call network reload

	sleep 1
}

factory_check(){
	local disabled

	local result=1
	local cpe_case
	
	get_cpe_all
	pre_init

	if ! cpe_check; then
		result=0
		uci set "factory_check.factest.result"=0

		gTries=$((gTries+1))
		if [ "$gTries" -lt "$gRecheck" ]; then
			result=1
			gCard_num=0
			gCard_id=
			factory_check
		else
			for cpe_case in ${gCpe_all} ; do
				uci set network.${cpe_case}.disabled=0
			done

			uci set factory_check.factest.result="$result"
			uci commit factory_check

			all_leds_action "on"
			sync
			exit 1
		fi
		
	fi

	for cpe_case in ${gCpe_all} ; do
		uci set network.${cpe_case}.disabled=0
	done

	uci set factory_check.factest.result="$result"
	uci commit factory_check

	sync
}

if [ "$(uci -q get factory_check.factest.result)" != "1" ]; then
	all_leds_action "off"
	sleep 1
	set_led "$gLedStatus" "timer"
	factory_check
	all_leds_action "on"
else
	sleep 1
	all_leds_action "on"
fi
