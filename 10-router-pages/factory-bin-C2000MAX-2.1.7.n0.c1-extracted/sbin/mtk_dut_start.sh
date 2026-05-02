#!/bin/sh

rm -f /tmp/mtk_dut.txt
killall mtk_dut

wifi_detect=5
all_system_detect=30
count=0
band_cnt=0
inf1_exist=0
inf2_exist=0
inf3_exist=0
inf1_up=0
inf2_up=0
inf3_up=0

if [ -d /sys/class/net/ra0 ]; then
	inf1_exist=1
	band_cnt=$((band_cnt + 1))
	echo "ra0 is exist!" > /tmp/mtk_dut.txt
fi

if [ -d /sys/class/net/rai0 ]; then
	inf2_exist=1
	band_cnt=$((band_cnt + 1))
	echo "rai0 is exist!" > /tmp/mtk_dut.txt
fi

if [ -d /sys/class/net/rax0 ]; then
	inf3_exist=1
	band_cnt=$((band_cnt + 1))
	echo "rax0 is exist!" > /tmp/mtk_dut.txt
fi

echo "Total band count: $band_cnt" > /tmp/mtk_dut.txt

while (true); do
		if [ $count -ge $all_system_detect ]; then
			echo "Detect too long time for wifi ready ! Stop!" >> /tmp/mtk_dut.txt
			break
		fi

		inf1=`ifconfig -a | grep ra0 | awk '{print $1}' | sed -n 1p`
		if [ $count -ge $wifi_detect ] && [ -z $inf1 ]; then
			echo "Can't detect wifi up! Stop!" >> /tmp/mtk_dut.txt
			break
		fi

		if [ "$inf1" = "ra0" ]; then
			echo "$inf1 is up!" >> /tmp/mtk_dut.txt
			inf1_up=1
		fi

		inf2=`ifconfig | grep rai0 | awk '{print $1}' | sed -n 1p`
		if [ "$inf2" = "rai0" ]; then
			echo "$inf2 is up!" >> /tmp/mtk_dut.txt
			inf2_up=1
		fi

		inf3=`ifconfig | grep rax0 | awk '{print $1}' | sed -n 1p`
		if [ "$inf3" = "rax0" ]; then
			echo "$inf3 is up!" >> /tmp/mtk_dut.txt
			inf3_up=1
		fi

		hostapd_status=`hostapd_cli status | grep "state" | cut -d '=' -f2`

		if [ $band_cnt -eq 2 ]; then
			if ([ $inf1_up -eq 1 ] && [ $inf2_up -eq 1 ]) || ([ $inf1_up -eq 1 ] && [ $inf3_up -eq 1 ]); then
				if [ "$hostapd_status" = "ENABLED" ]; then
					echo "All ready, run mtk_dut!" >> /tmp/mtk_dut.txt
					mtk_dut ap br-lan 9000 -l mtk_dut.log -s hostapd &
					break
				fi
			fi
		fi

		if [ $band_cnt -eq 3 ]; then
			if [ $inf1_up -eq 1 ] && [ $inf2_up -eq 1 ] && [ $inf3_up -eq 1 ]; then
				if [ "$hostapd_status" = "ENABLED" ]; then
					echo "All ready, run mtk_dut!" >> /tmp/mtk_dut.txt
					mtk_dut ap br-lan 9000 -l mtk_dut.log -s hostapd &
					break
				fi
			fi
		fi

		sleep 1
		count=$((count + 1))
		echo "Wait $count seconds for hostapd WIFI status up!" >> /tmp/mtk_dut.txt
done
