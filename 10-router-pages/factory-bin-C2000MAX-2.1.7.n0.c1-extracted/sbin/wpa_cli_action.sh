#!/bin/sh

case "$2" in
	SCAN_RESULTS)
		echo "EVENT_SCAN_RESULTS";
		;;
	CONNECTED)
		echo "EVENT_CONNECTION";
		;;
	DISCONNECTED)
		echo "EVENT_DISCONNECT";
		;;
esac
