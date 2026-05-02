#!/bin/ash


UPGRADE_STATUS="init"
CUR_VERSION=""
TARGET_VERSION=""
FOTA_URL=""
gNet="$(uci -q get network.globals.default_cellular)"
gName="fota"
gLogMode=$(uci -q get logservice.root.mode)
gForce=0
[ -z "$gNet" ] && gNet="cpe"

log_info() {
	logger -t "$gName $$" "$*"
	if [ "$gLogMode" == "1" ] ;then
		logclient -i "$gName $$"  -l 6 -m "$*"
	fi
}


usage() {
	cat <<-EOF
		Usage: $0 OPTION...
		Fota daemon.
		  -i      network interface, $gNet as default
		  -s      orignal version
		  -t      target version
		  -f      1 used to upgrade immediately,0 need wait for no terminal connected or 2:00-5:00 am,0 as default
		  -H      Fota URL
	EOF
}
while getopts "i:s:t:H:h:f" opt; do
	case "${opt}" in
		i)
			gNet=${OPTARG}
			;;
		s)
			CUR_VERSION=${OPTARG}
			;;
		t)
			TARGET_VERSION=${OPTARG}
			;;
		f)
			gForce=1
			;;
		H)
			FOTA_URL=${OPTARG}
			;;
		h)
			usage
			exit
			;;
		\?)
			usage >&2
			exit 1
			;;
	esac
done

get_fota_status(){
	local info=$(cpetools.sh -t0 -c 'AT+FOTADL?'|grep "+FOTADL") ##NU313 FOTA CMD
	[ -z "$info" ] && return 1
	local status="$(echo "$info"|awk -F: '{print $2}'|sed 's/"//g'|xargs -r printf)"
	local msg="$status"
	local code=""
	if echo "$status"|grep ",";then
		msg="$(echo "$status"|awk -F, '{print $1}')"
		code="$(echo "$status"|awk -F, '{print $2}')"
	fi
	log_info "msg:$msg,code:$code"
	if [ "$msg" == "FTPSTART" -o "$msg" == "HTTPSTART" -o "$msg" == "DOWNLOADING" ];then
		UPGRADE_STATUS="downloading"
	elif [ "$msg" == "FTPEND" -o "$msg" == "HTTPEND" -o "$msg" == "START" -o "$msg" == "99" ];then
		UPGRADE_STATUS="upgrading"
	elif [ "$msg" == "END" -o "$msg" == "100"  ];then
		UPGRADE_STATUS="done"
	elif [ "$msg" == "101"  ];then
		UPGRADE_STATUS="valid"
	elif [ "$msg" == "0" ];then
		UPGRADE_STATUS="init"
	fi
	return 0
}
upgrade_loop(){
	while true; do
		if [ "$UPGRADE_STATUS" == "init" ]; then
			local version="$(cpetools.sh -c version)"
			if [ "$version" == "$TARGET_VERSION" ]; then
				UPGRADE_STATUS="noneed"
				log_info "UPGRADE_STATUS:$UPGRADE_STATUS,already new ver"
				break
			fi
			if [ "$version" == "$CUR_VERSION" ]; then
				UPGRADE_STATUS="prepare"
				log_info "UPGRADE_STATUS:$UPGRADE_STATUS"			
			elif [ -n "$version" ] && echo "$version"|grep -qv "usb not ready"; then
				UPGRADE_STATUS="valid"
				log_info "UPGRADE_STATUS:$UPGRADE_STATUS,ver $version[$CUR_VERSION,$TARGET_VERSION] not match"
			fi
		elif [ "$UPGRADE_STATUS" == "prepare" ]; then
			if check_modem_up ;then
				local status=$(cpetools.sh -t0 -c 'AT+FOTADL="'$FOTA_URL'",1')  ##NU313 FOTA CMD
				if echo "$status"|grep -q "OK";then
					UPGRADE_STATUS="download"
					log_info "UPGRADE_STATUS:$UPGRADE_STATUS"
				fi
			fi
		elif [ "$UPGRADE_STATUS" == "download" -o "$UPGRADE_STATUS" == "downloading" -o "$UPGRADE_STATUS" == "upgrading" ]; then
			get_fota_status
		elif [ "$UPGRADE_STATUS" == "done" -o "$UPGRADE_STATUS" == "valid" ]; then
			log_info "UPGRADE_STATUS:$UPGRADE_STATUS"
			if [ "$UPGRADE_STATUS" == "done" ];then
				/etc/init.d/atsd start
				/etc/init.d/cellular_init start
				log_info "wait modem up"
				while true; do
					local version_cfg=$(uci -q get "cellular_init.${gNet}.version")
					local version="$(cpetools.sh -c version)"
					if [ "$version_cfg" == "$version" ];then
						UPGRADE_STATUS="over"
						log_info "UPGRADE_STATUS:$UPGRADE_STATUS"
						break;
					fi
					sleep 5
				done
			fi
			break
		fi
		sleep 1
	done
}


log_info "FOTA upgrade start"
log_info "gNet:$gNet"
log_info "CUR_VERSION:$CUR_VERSION"
log_info "TARGET_VERSION:$TARGET_VERSION"
log_info "FOTA_URL:$FOTA_URL"
log_info "gForce:$gForce"

check_no_terminal(){
	local no_terminal_tiptime=""
	local uptime=""
	
	local count=$(ubus call infocd terminal|jsonfilter -qe "$['count']"|xargs -r printf)
	if [ "$count" == "0" ];then
		if [ -z "$no_terminal_tiptime" ];then
			no_terminal_tiptime="$(cat /proc/uptime|awk -F' ' '{print $1}'|awk -F'.' '{print $1}'|xargs -r printf)"
		else
			uptime="$(cat /proc/uptime|awk -F' ' '{print $1}'|awk -F'.' '{print $1}'|xargs -r printf)"
			diff=$((uptime-no_terminal_tiptime))
			if [ $diff -ge 60 ];then
				return 0
			fi
		fi
	else
		[ -n "$count" ] && no_terminal_tiptime=""
	fi
	return 1
}

check_schedule_time(){
	local ymd_s=$(date +%Y-%m-%d)
	local now_t=$(date +%s)
	local starttime
	local endtime
	local cfg_start_time="$1"
	local cfg_end_time="$2"

	if [ -n "$cfg_start_time" ];then
		starttime="${cfg_start_time}:00"
	else
		starttime="00:00:00"
	fi
	starttime_s=$(date -d "$ymd_s $starttime" +%s)
	if [ -n "$cfg_end_time" ];then
		endtime="${cfg_end_time}:00"
	else
		endtime="00:00:00"
	fi
	endtime_s=$(date -d "$ymd_s $endtime" +%s)

	if [ $starttime_s -ge $endtime_s ];then
		if [ $now_t -lt $endtime_s ];then
			return 0
		fi
		endtime_s=$((endtime_s+86400))
	fi

	if [ $now_t -gt $starttime_s -a $now_t -lt $endtime_s ];then
		return 0
	fi
	return 1
}

check_modem_up(){
	local connstat=$(cpetools.sh -i "$gNet" -c connstat)
	[ -z "$connstat" ] && return 1
	local connstat_item=$(echo "$connstat"|jsonfilter -qe '$["IPV4"]')
	[ -z "$connstat_item" ] && return 1
	if [ "$connstat_item" == "1" ];then
		return 0
	fi
	return 1
}

if [ $gForce -eq 0 ];then
	while (! check_no_terminal) && (! check_schedule_time "2:00" "5:00"); do
		sleep 10
	done
fi

while ! get_fota_status; do
	sleep 1
done

if [ "$UPGRADE_STATUS" == "done" -o "$UPGRADE_STATUS" == "valid" ];then
	UPGRADE_STATUS="init"
fi
if [ -z "$CUR_VERSION" -o -z "$TARGET_VERSION" -o -z "$FOTA_URL" ];then
	log_info "CUR_VERSION,TARGET_VERSION,FOTA_URL must not be empty"
	exit 0
fi

log_info "UPGRADE_STATUS:$UPGRADE_STATUS"
upgrade_loop
