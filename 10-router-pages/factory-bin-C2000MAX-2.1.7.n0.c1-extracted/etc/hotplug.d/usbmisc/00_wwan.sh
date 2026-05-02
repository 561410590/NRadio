#!/bin/ash

[ "$ACTION" = add ] || [ "$ACTION" = remove ] || exit 0
[ "${DEVNAME/[0-9]/}" = cdc-wdm ] || exit 0

dname="${DEVPATH##*/}"
ubus send atsd.usb "{'action':'$ACTION','devpath':'$dname','from':'usbmisc'}"
