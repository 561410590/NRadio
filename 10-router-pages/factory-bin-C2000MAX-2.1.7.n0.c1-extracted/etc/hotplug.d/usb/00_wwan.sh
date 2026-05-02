#!/bin/ash

[ "$ACTION" = add ] || [ "$ACTION" = remove ] && [ "$DEVTYPE" = usb_device ] || exit 0

dname="${DEVPATH##*/}"

ubus send atsd.usb "{'action':'$ACTION','devpath':'$dname','from':'usb'}"

exit 0
