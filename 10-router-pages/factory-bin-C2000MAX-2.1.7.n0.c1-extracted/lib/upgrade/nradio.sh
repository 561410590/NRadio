#!/bin/ash

. /lib/functions/system.sh
. /lib/nradio/layout.sh

kp_get_media_type() {
	local media="SPI"

	if grep -qE "^HCMT.*-N" /tmp/sysinfo/board_name; then
		media="NAND"
	elif grep -qE "^HCMT.*-E" /tmp/sysinfo/board_name; then
		media="EMMC"
	fi

	echo "$media"
}

kp_get_blockdev() {
	if [ "$1" != "PMBR" ]; then
		blkid -t PARTLABEL=$1 -o device
	else
		blkid -t PTTYPE=$1 -o device
	fi
}

kp_get_blockdev_size() {
	blockdev --getsize64 $1
}

kp_get_blockdev_size_by_name() {
	local sector_start=
	local sector_end=

	sector_start=$(fdisk -l|grep $1|head -n 1|awk -F ' ' '{print $2}')
	sector_end=$(fdisk -l|grep $1|head -n 1|awk -F ' ' '{print $3}')

	echo $(((sector_end-sector_start+1)*512))
}

kp_get_blockdev_offset() {
	local sector=
	sector=$(fdisk -l|grep $1|head -n 1|awk -F ' ' '{print $2}')

	echo $((sector*512))
}

kp_get_uboot_size() {
	mtd_get_part_size "${KP_UBOOT_NAME:-FIP}"
}

kp_get_uboot_ver() {
	local base=256
	local file=$1
	local media=
	local offset=
	local voffset=
	local dev=$2

	media=$(kp_get_media_type)
	if [ "$dev" -eq 1 ]; then
		offset=0
	else
		if [ "$media" = "EMMC" ]; then
			offset=$(kp_get_blockdev_offset "fip")
		else
			offset=$(eval "echo \${KP_FIP_OFF_$media}")
		fi
	fi
	voffset=$(eval "echo \${KP_FIP_VER_OFF_$media}")
	offset=$((offset+voffset))

	dd if="$file" bs="$base" count=1 skip="$((offset/base))" 2>/dev/null \
		|strings \
		|grep 'U_BOOT' \
		|awk '{print $2}'
}

kp_get_gpt() {
	local base=512
	local size=$((0x4400))

	dd if="$1" bs="$base" count="$((size/base))" 2>/dev/null
}

kp_get_uboot() {
	local base=512
	local media=
	local size=
	local offset=
	local fip_dev=

	media=$(kp_get_media_type)
	if [ "$media" = "EMMC" ]; then
		fip_dev=$(kp_get_blockdev "fip")
		size=$(kp_get_blockdev_size "${fip_dev}")
		offset=$(kp_get_blockdev_offset "fip")
	else
		size=$(kp_get_uboot_size | xargs printf "%d")
		offset=$(eval "echo \${KP_FIP_OFF_$media}")
	fi

	dd if="$1" bs="$base" skip="$((offset/base))" count="$((size/base))" 2>/dev/null
}

kp_get_sysup() {
	local base=512
	local media=
	local offset=

	media=$(kp_get_media_type)
	offset=$(eval "echo \${KP_SYS_OFF_$media}")

	dd if="$1" bs="$base" skip="$((offset/base))" 2>/dev/null
}

kp_get_kernel() {
	local base=512
	local size=
	local kernel_dev=
	local offset=

	kernel_dev=$(kp_get_blockdev "kernel")
	size=$(kp_get_blockdev_size "${kernel_dev}")
	offset=$(kp_get_blockdev_offset "kernel")

	dd if="$1" bs="$base" skip="$((offset/base))" count="$((size/base))" 2>/dev/null
}

kp_get_rootfs() {
	local base=512
	local offset=

	offset=$(kp_get_blockdev_offset "rootfs")

	dd if="$1" bs="$base" skip="$((offset/base))" 2>/dev/null
}

kp_update_uboot() {
	local img=
	local cur=
	local dev=

	dev=$(find_mtd_part "${KP_UBOOT_NAME:-FIP}")

	if [ -z "$dev" ]; then
		dev=$(kp_get_blockdev "fip")
		[ -n "$dev" ] || return 1
	fi

	img=$(kp_get_uboot_ver "$1" 0)
	cur=$(kp_get_uboot_ver "${dev}" 1)

	v "UBOOT VER: $img, $cur"

	[ "${img:-0}" -gt "${cur:-0}" ]
}

kp_update_gpt() {
	local dev=$2
	local img=
	local cur=

	if [ -z "$dev" ]; then
		dev=$(kp_get_blockdev "PMBR")
		[ -n "$dev" ] || return 1
	fi

	cur=$(md5sum "$dev"|cut -d' ' -f1)
	img=$(kp_get_gpt "$1"|md5sum|cut -d' ' -f1)

	v "GPT MD5: $img, $cur"
	[ "${img:-0}" != "${cur:-0}" ]
}

kp_do_mtd_upgrade() {
	local media=$2
	local mtd_part=
	local conf_tar="/tmp/sysupgrade.tgz"

	v "KP do upgrade..."

	mtd_part=$(eval "echo \${KP_SYS_MTD_PART_$media}")

	sync
	if kp_update_uboot "$1"; then
		v "Update KP Uboot..."
		kp_get_uboot "$1" | mtd write - "${KP_UBOOT_NAME:-FIP}"
	fi

	if [ -f "$conf_tar" ]; then
		kp_get_sysup "$1" | mtd -j "$conf_tar" write - "${mtd_part}"
		sync
		if [ "$media" = "NAND" ]; then
			local mtdnum

			mtdnum="$( find_mtd_index "$CI_UBIPART" )"
			ubidetach -m "$mtdnum"
			sync
			ubiattach -m "$mtdnum"
			sync
			nand_restore_config "$conf_tar"
			# sleep to wait flash sync
			sleep 3
		fi
	else
		kp_get_sysup "$1" | mtd write - "${mtd_part}"
	fi
	sync
}

kp_do_mmc_upgrade() {
	local base=512
	local media=$2
	local gpt_dev=
	local fip_dev=
	local rootfs_dev=
	local kernel_dev=
	local kernel_length=
	local fip_length=
	local rootfs_length=
	local gpt_length=
	local need_backup_bdinfo=0

	v "KP do emmc upgrade..."

	rootfs_dev=$(kp_get_blockdev "rootfs")
	kernel_dev=$(kp_get_blockdev "kernel")
	fip_dev=$(kp_get_blockdev "fip")
	gpt_dev=$(kp_get_blockdev "PMBR")

	if [ -z "${rootfs_dev}" ] || [ -z "${kernel_dev}" ] || [ -z "${fip_dev}" ]; then
		v "Cannot find partition rootfs or kernel"
		return 1
	fi

	if kp_update_gpt "$1" "$gpt_dev"; then
		v "Update GPT..."
		need_backup_bdinfo=1
		gpt_length=$(kp_get_blockdev_size ${gpt_dev})
		kp_get_gpt "$1" | dd of=$gpt_dev bs=${base} count=$((gpt_length/base)) conv=sync 2> /dev/null
	fi

	if kp_update_uboot "$1"; then
		v "Update KP Uboot..."
		fip_length=$(kp_get_blockdev_size ${fip_dev})
		kp_get_uboot "$1" | dd of=$fip_dev bs=${base} count=$((fip_length/base)) conv=sync 2> /dev/null
	fi

	losetup --detach-all || {
		v "Failed to detach all loop devices."
		sleep 10
		reboot -f
	}

	kernel_length=$(kp_get_blockdev_size ${kernel_dev})
	rootfs_length=$(kp_get_rootfs "$1" | wc -c) 2> /dev/null

	kp_get_kernel "$1" | dd of=$kernel_dev bs=${base} count=$((kernel_length/base)) conv=sync 2> /dev/null
	kp_get_rootfs "$1" | dd of=$rootfs_dev bs=${base} count=$((rootfs_length/base)) 2> /dev/null

	local rootfs_dev_size=$(kp_get_blockdev_size_by_name "rootfs")
	[ $? -ne 0 ] && return 1

	local rootfs_data_offset=$(((rootfs_length+ROOTDEV_OVERLAY_ALIGN-1)&~(ROOTDEV_OVERLAY_ALIGN-1)))
	local rootfs_data_size=$((rootfs_dev_size-rootfs_data_offset))

	local loopdev="$(losetup -f)"
	losetup -o $rootfs_data_offset $loopdev $rootfs_dev || {
		v "Failed to mount looped rootfs_data."
		return 1
	}

	local fstype=ext4
	local mkfs_arg="-q -L rootfs_data"
	local sectors=""
	[ "${rootfs_data_size}" -gt "${F2FS_MINSIZE}" ] && {
		fstype=f2fs
		mkfs_arg="-q -l rootfs_data"
		sectors=$((rootfs_data_size/512))
	}

	v "Format new rootfs_data at position ${rootfs_data_offset}."
	mkfs.${fstype} ${mkfs_arg} ${loopdev} ${sectors}
	[ $? -ne 0 ] && return 1

	[ -n "$UPGRADE_BACKUP" -o "$need_backup_bdinfo" = "1" ] && {
		mkdir -p /tmp/new_root
		mount -t ${fstype} ${loopdev} /tmp/new_root && {
			[ -n "$UPGRADE_BACKUP" ] && {
				v "Saving config to rootfs_data at position ${rootfs_data_offset}."
				mv "$UPGRADE_BACKUP" "/tmp/new_root/$BACKUP_FILE"
			}
			[ "$need_backup_bdinfo" = "1" -a -n "/tmp/appdata.tgz" ] && {
				v "Saving bdinfo from app_data to rootfs_data at position ${rootfs_data_offset}."
				mv "/tmp/appdata.tgz" "/tmp/new_root/appdata.tgz"
			}
			umount /tmp/new_root
		}
	}

	# Cleanup
	losetup -d ${loopdev} >/dev/null 2>&1
	sync

	return 0
}

kp_do_upgrade() {
	local media=

	media=$(kp_get_media_type)

	if [ "$media" != "EMMC" ]; then
		kp_do_mtd_upgrade $1 $media
	else
		kp_do_mmc_upgrade $1
	fi
}

kp_check_image() {
	local board=$1
	local file=$2
	local bl2_len=
	local fip_off=
	local sys_off=
	local hdr_off=
	local media=
	local model=$(model_name|cut -d '-' -f2)
	local soft_ver=$(softver)
	local vendor=$(bdinfo -g oem_vendor)
	local verify_level=1

	if kuhead_has_magic "$file"; then
		kuhead_check_image "$file" "$board" "$size"
	else
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

		icheck -b "$board" -a "$bl2_len" -o "$hdr_off" -u "$fip_off" -s "$sys_off" -f "$file" -w "$model" -v "$soft_ver" -c "$verify_level"
	fi
}
