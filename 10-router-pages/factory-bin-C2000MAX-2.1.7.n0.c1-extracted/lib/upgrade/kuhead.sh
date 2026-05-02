#!/bin/ash

KUHEAD_MAGIC="KuHeAdEr"
KUHEAD_IMAGE_MFILE="/tmp/kufirmware.img"
KUHEAD_IMAGE_XMIT="filexmit"
KUHEAD_IMAGE_CPATH="/var/$KUHEAD_IMAGE_XMIT"
KUHEAD_IMAGE_CFILE="$KUHEAD_IMAGE_CPATH/next.img"

kuhead_has_magic() {
	if ! dd if="$1" bs=1 count=8 2>/dev/null|hexdump -C|grep -qs "$KUHEAD_MAGIC"; then
		echo "Not kuhead image!"
		return 1
	fi

	return 0
}

kuhead_upgrade_cboard() {
	local oldfile="/tmp/${1##*/}"
	local newfile=$2
	local rommd5=
	local ip6addr=
	local mboard=
	local header=
	local romver=
	local length=
	local allcnt=
	local newcnt=
	local keep=
	local i=

	if type cloudd_cmd >/dev/null; then
		# Check version
		mboard=$(uci get oem.board.id|tr -d :)
		header=$(head -n1 "$newfile")
		romver=$(echo "$header"|cut -d, -f6)
		length=$(echo "$header"|cut -d, -f8)
		allcnt=$(ubus call cloudd client|grep -w '"oid":'|grep -csw "$mboard")
		newcnt=$(ubus call cloudd client|grep -wE '"(oid|sversion)":'|sed '/--/d;N;s/\n//'|grep -sw "$mboard"|grep -csw "$romver")

		if [ -z "$romver" ]; then
			echo "Cboard version not specified, skip it!"
			return 0
		fi

		if [ "$allcnt" = "$newcnt" ]; then
			echo "Cboard is up to date!"
			return 0
		fi

		if ubus call cloudd client|grep -wE '"(oid|sversion)":'|sed '/--/d;N;s/\n//'|grep -sw "$mboard"|grep -qsE '"1\.5\.'; then
			echo "Doesn't Compatible with 1.5!"
			return 1
		else
			if [ ! -d "/www/$KUHEAD_IMAGE_XMIT" ]; then
				ln -sn /tmp/$KUHEAD_IMAGE_XMIT /www/
			fi
			# Xmit image
			ip6addr=$(ip -6 addr show br-lan|grep -oE 'fe80[:0-9a-f]+'|head -n1)
			cloudd_cmd -o "$mboard" "curl -g http://[$ip6addr%br-lan]/$KUHEAD_IMAGE_XMIT/${newfile##*/} -o $oldfile"
		fi

		# Calc md5
		rommd5=$(md5sum "$newfile"|head -c 32)
		for i in $(seq 180); do
			sleep 1
			# Check image md5
			if cloudd_cmd -r -t 1 -o "$mboard" "md5sum $oldfile|grep -qs $rommd5;echo \$?"|grep -cE ": 0"|grep -qsE "^$allcnt$"; then
				break
			fi

			if [ "$i" -eq 180 ]; then
				echo "Cboard rom xmit error!"
				return 2
			fi
		done

		# Upgrade image
		[ "$SAVE_CONFIG" -eq 0 ] && keep="-n"
		cloudd_cmd -o "$mboard" "/sbin/sysupgrade $keep $oldfile"

		# Wait ready
		sleep 90
		for i in $(seq 120); do
			if ubus call cloudd client|grep -wE '"(oid|sversion)":'|sed '/--/d;N;s/\n//'|grep -sw "$mboard"|grep -csw "$romver"|grep -qsE "^$allcnt$"; then
				echo "Cboard rom upgrade success!"
				return 0
			fi
			sleep 1
		done
	fi

	echo "Cboard rom upgrade error!"
	return 4
}

kuhead_cboard_icheck() {
	local file=$1
	local mboard=
	local allcnt=
	local output=
	local board=
	local model=
	local bl2_len=
	local fip_off=
	local sys_off=
	local hdr_off=
	local media="SPI"
	local header=
	local hdrlen=
	local length=
	local firstl=
	local soft_ver=
	local vendor=$(bdinfo -g oem_vendor)
	local verify_level=1

	# Analysis header
	header=$(head -n1 "$file")
	hdrlen=${#header}
	length=$(echo "$header"|cut -d, -f8)

	if type cloudd_cmd >/dev/null; then
		mboard=$(uci get oem.board.id|tr -d :)
		allcnt=$(ubus call cloudd client|grep -w '"oid":'|grep -csw "$mboard")

		[ -n "$vendor" ] || vendor="nradio"
		if [ "$vendor" != "nradio" ]; then
			verify_level=2
		fi

		# Get cboard info
		for i in $(seq 10); do
			output=$(cloudd_cmd -r -t 1 -o "$mboard" "cat /tmp/sysinfo/board_name|tr '\n' ' ';cat /tmp/sysinfo/model|tr '\n' ' ';cat /etc/openwrt_version|tr '\n' ' '")
			if [ -n "$output" ] && echo "$output"|wc -l|grep -qsE "^$allcnt$"; then
				break
			fi
			sleep 1

			if [ "$i" -eq 10 ]; then
				echo "Failed to get cboard info"
				return 3
			fi
		done

		firstl=$(echo "$output"|head -n1)
		board=$(echo "$firstl"|awk '{print $2}')
		model=$(echo "$firstl"|awk '{print $3}'|cut -d '-' -f2)
		soft_ver=$(softver "$(echo "$firstl"|awk '{print $4}')")
		bl2_len=$(eval "echo \${KP_BL2_LEN_$media}")
		fip_off=$(eval "echo \${KP_FIP_OFF_$media}")
		sys_off=$(eval "echo \${KP_SYS_OFF_$media}")
		hdr_off=$(eval "echo \${KP_HDR_OFF_$media}")

		if ! icheck -b "$board" -a "$bl2_len" -o "$hdr_off" -u "$fip_off" -s "$sys_off" -f "$file" -w "$model" -v "$soft_ver" -c "$verify_level" -t "$((hdrlen+1))" -S "$length"; then
		   echo "Cboard icheck failed"
		   return 1
		fi
	fi

	return 0
}

kuhead_check_image() {
	local file=$1
	local board=$2
	local header=
	local next=
	local force=
	local romver=
	local length=
	local hdrlen=
	local bl2_len=
	local fip_off=
	local sys_off=
	local hdr_off=
	local media=
	local model=$(model_name|cut -d '-' -f2)
	local soft_ver=$(softver)
	local vendor=$(bdinfo -g oem_vendor)
	local verify_level=1

	# Analysis header
	header=$(head -n1 "$file")
	hdrlen=${#header}
	next=$(echo "$header"|cut -d, -f3)
	length=$(echo "$header"|cut -d, -f8)

	# Perform cboard
	if [ "${next:-0}" -eq 1 ]; then
		echo "Perform cboard check!"
		mkdir -p "$KUHEAD_IMAGE_CPATH"
		tail -c "+$((length + 1 + hdrlen + 1))" "$file" >"$KUHEAD_IMAGE_CFILE"

		if ! kuhead_cboard_icheck "$KUHEAD_IMAGE_CFILE"; then
			echo "Cboard check failed!"
			return 1
		fi
	fi

	# Check mboard
	[ -n "$vendor" ] || vendor="nradio"
	if [ "$vendor" != "nradio" ]; then
		verify_level=2
	fi

	media="$(kp_get_media_type)"
	if [ "$media" = "EMMC" ]; then
		bl2_len=$(eval "echo \${KP_BL2_LEN_$media}")
		fip_off=$(kp_get_blockdev_offset "fip"|xargs printf "0x%x")
		sys_off=$(kp_get_blockdev_offset "kernel"|xargs printf "0x%x")
		hdr_off=$(kp_get_blockdev_offset "u-boot-env"|xargs printf "0x%x")
	else
		bl2_len=$(eval "echo \${KP_BL2_LEN_$media}")
		fip_off=$(eval "echo \${KP_FIP_OFF_$media}")
		sys_off=$(eval "echo \${KP_SYS_OFF_$media}")
		hdr_off=$(eval "echo \${KP_HDR_OFF_$media}")
	fi
	icheck -b "$board" -a "$bl2_len" -o "$hdr_off" -u "$fip_off" -s "$sys_off" -f "$file" -w "$model" -v "$soft_ver" -c "$verify_level" -t "$((hdrlen+1))" -S "$length"
}

kuhead_pre_upgrade() {
	local file=$ARGV
	local header=
	local next=
	local force=
	local romver=
	local length=
	local hdrlen=

	if ! kuhead_has_magic "$file"; then
		return 0
	fi

	# Analysis header
	header=$(head -n1 "$file")
	hdrlen=${#header}
	next=$(echo "$header"|cut -d, -f3)
	force=$(echo "$header"|cut -d, -f4)
	romver=$(echo "$header"|cut -d, -f6)
	length=$(echo "$header"|cut -d, -f8)

	# Upgrade cboard
	if [ "${next:-0}" -eq 1 ]; then
		echo "Perform cboard upgrade!"
		if [ ! -f "$KUHEAD_IMAGE_CFILE" ]; then
			echo "$KUHEAD_IMAGE_CFILE not exist, cboard upgrade failed!"
			exit 1
		fi
		if ! kuhead_upgrade_cboard "$file" "$KUHEAD_IMAGE_CFILE"; then
			echo "Cboard upgrade failed!"
			exit 1
		fi
		rm -f "$KUHEAD_IMAGE_CFILE"
	fi

	if grep -qsE "^$romver$" /etc/openwrt_version && [ "${force:-0}" -eq 0 ]; then
		echo "Mboard is up to date!"
		exit 0
	fi

	# Get real image
	tail -c "+$((hdrlen + 1 + 1))" "$file"|head -c"$length" >"$KUHEAD_IMAGE_MFILE"
	echo "Get kuhead real image!"
	set -- "$KUHEAD_IMAGE_MFILE"
	export ARGV="$*"
	export ARGC="$#"

	return 0
}

append sysupgrade_pre_upgrade kuhead_pre_upgrade
