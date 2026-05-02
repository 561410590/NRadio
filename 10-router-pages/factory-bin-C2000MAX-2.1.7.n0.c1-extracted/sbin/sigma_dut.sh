#!/bin/sh

usage() {
	echo "Usage: sigma_dut.sh <interface> <port> [options]"
	echo "Options: (param=value)"
	echo "	-d, --debug"
	echo "	-f, --log-file"
	echo "	-c, --ctrl-iface (default: br-lan)"
	echo "	-a, --ca-addr (default: ipaddr of ctrl-iface)"
	echo "	-p, --ca-port (default: 8000)"
}

if [ "$#" -lt 2 ]; then
	usage
	exit 1
fi

DUT_INTF=$1
CTRL_PORT=$2

DEBUG=
LOG_FILE=
CTRL_INTF=br-lan
CA_ADDR=
CA_PORT=8000

for i in "$@"; do
	case $i in
		-d=*|--debug=*)
			DEBUG="${i#*=}"
			;;
		-f=*|--log-file=*)
			LOG_FILE="${i#*=}"
			;;
		-c=*|--ctrl-iface=*)
			CTRL_INTF="${i#*=}"
			;;
		-a=*|--ca-addr=*)
			CA_ADDR="${i#*=}"
			;;
		-p=*|--ca-port=*)
			CA_PORT="${i#*=}"
			;;
		-*|--*)
			echo "Unknown option $1"
			exit 1
			;;
		*)
			;;
	esac
done

if [ -z $CA_ADDR ]; then
	CA_ADDR=$(ip addr show $CTRL_INTF | grep 'inet\b' | awk '{print $2}' | cut -d/ -f1)
fi

killall wfa_dut wfa_ca
sleep 1

wfa_dut $DUT_INTF $CA_PORT $DEBUG $LOG_FILE &
sleep 1

wfa_ca $CTRL_INTF $CTRL_PORT $CA_ADDR $CA_PORT $DEBUG $LOG_FILE &
sleep 1

