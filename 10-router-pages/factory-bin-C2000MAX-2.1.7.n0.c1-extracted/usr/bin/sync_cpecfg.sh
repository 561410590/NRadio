#!/bin/ash

_cpen=$(uci get oem.feature.cpe)
_capn=$(uci get cpecfg.config.custom_apn)
_apn=$(uci get cpecfg.config.apn)
_usr=$(uci get cpecfg.config.username)
_pwd=$(uci get cpecfg.config.password)

if [ "$_cpen" -lt 1 ]; then
	exit 0
fi

_cpen=$((_cpen-1))

for _i in $(seq 0 $_cpen); do
	_iface="cpe"
	if [ "$_i" != "0" ]; then
		_iface="cpe$_i"
	fi

	if [ "$_capn" = "0" ]; then
		_apn=""
		_usr=""
		_pwd=""
	fi
	
	uci set "network.$_iface.apn=$_apn"
	uci set "network.$_iface.username=$_usr"
	uci set "network.$_iface.password=$_pwd"
done

uci commit network
cpetools.sh -r
