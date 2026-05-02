#!/bin/ash

readonly X86_INFO_FILE="/etc/bdinfo.bin"
readonly UNISOC_INFO_FILE="/bdinfo/bdinfo.bin"

gName="oeminfo_edit"
gDate=$(date +%s)
gDev=$(grep -oE '(bd|oem)info' /proc/mtd)
gMtd=$(grep -E '(bd|oem)info' /proc/mtd|cut -d: -f1|sed 's|^|/dev/|')
gBdev=$(blkid -t PARTLABEL=bdinfo -o device)
gFile="/mnt/app_data/bdinfo"
gDir="/tmp/${gName}_${gDate}"
gTmp="$gDir/mtd"
gSet=

mkdir -p "$gDir"

if [ -f "$gFile" ]; then
	cp -f $gFile $gTmp
elif [ -n "$gDev" ]; then
	dd if="$gMtd" of="$gTmp" bs=$((0x10000)) count=1
elif [ -n "$gBdev" ]; then
	dd if="$gBdev" of="$gTmp" bs=$((0x10000)) count=1
else
	if [ -f "$X86_INFO_FILE" ]; then
		dd if="$X86_INFO_FILE" of="$gTmp"
	elif [ -f "$UNISOC_INFO_FILE" ]; then
		dd if="$UNISOC_INFO_FILE" of="$gTmp"
	else
		echo "No valid bdinfo device or file"
		exit 1
	fi
fi

while IFS='=' read -r _key _val; do
	sed -i "/^$_key = .*/d" "$gTmp"

	if [ -n "$_val" ]; then
		sed -i "/^fac_key = .*/a $_key = $_val" "$gTmp"
	fi

	gSet=1
done

if [ -n "$gSet" ]; then
	if [ -f "$gFile" ]; then
		dd if="$gTmp" of="$gFile" bs=$((0x10000)) count=1 conv=sync
	elif [ -n "$gDev" ]; then
		mtd setrw "$gDev" 1
		dd if="$gTmp" bs=$((0x10000)) count=1|mtd write - "$gDev"
	elif [ -n "$gBdev" ]; then
		dd if="$gTmp" of="$gBdev" bs=$((0x10000)) count=1 conv=sync
	elif [ -f "$X86_INFO_FILE" ]; then
		dd if="$gTmp" bs=$((0x10000)) count=1 of="$X86_INFO_FILE" conv=sync
	elif [ -f "$UNISOC_INFO_FILE" ]; then
		dd if="$gTmp" bs=$((0x10000)) count=1 of="$UNISOC_INFO_FILE" conv=sync
	fi
fi
