#!/bin/sh

rm -f /tmp/mtk_dut.txt
killall mtk_dut

count=0
while [ $count -lt 20 ]; do
	echo "Wait $count seconds for WIFI interface up" >> /tmp/mtk_dut.txt

	inf=`ifconfig | grep ra0 | awk '{print $1}' | sed -n 1p`
	if [ "$inf" = "ra0" ]; then
		echo "$inf is up, run mtk_dut" >> /tmp/mtk_dut.txt
		sleep 1
		mtk_dut ap br-lan 9000 -s jedi_hostapd &
		break
	fi
	sleep 1
	count=$((count + 1))
done
