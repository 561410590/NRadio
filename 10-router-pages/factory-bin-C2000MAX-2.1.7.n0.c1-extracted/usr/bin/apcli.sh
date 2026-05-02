#!/bin/ash

_net=$(uci get wireless.apcli.network)
_frq=$(uci get wireless.apcli.workfreq)
_dis=$(uci get wireless.apcli.disabled)
_wanfw=$(uci show firewall|grep -E 'zone\[[0-9]+\].name=.*wan'|sed 's/name=.*/network/')
_ifn=
_dev=
_tmp=

# update ifname and device
if [ "$_frq" = "1" ]; then
	_dev="radio0"
else
	if uci -q get wireless.radio2; then
		_dev="radio2"
	else
		_dev="radio1"
	fi
fi

if [ -n "$_dev" ]; then
	_tmp=$(uci -q show wireless|grep -E "^wireless.wlan[0-9].device='$_dev'$"|awk -F. '{print $2}')
	_ifn=$(uci -q get "wireless.$_tmp.ifname"|sed 's/ra/apcli/g')
fi

uci -q set wireless.apcli.device="$_dev"
uci -q set wireless.apcli.ifname="$_ifn"
uci -q set wireless.apcli.mode="sta"

if ! uci -q get network.wisp; then
	uci -q set network.wisp=interface
	uci -q set network.wisp.proto="dhcp"
	uci -q set network.wisp.disabled=1
fi

if ! uci -q get wanchk.wisp; then
	uci -q set wanchk.wisp=checker
	uci -q set wanchk.wisp.period="10"
	uci -q set wanchk.wisp.network="wisp"
	uci -q set wanchk.wisp.enable=0
fi

if [ "$_net" = "wisp" ]; then
	uci -q del_list "$_wanfw=wisp"
	uci -q add_list "$_wanfw=wisp"
	uci -q set network.wisp.disabled=0
	uci -q set network.wisp.ifname="$_ifn"
	uci -q set wanchk.wisp.enable=1
	uci -q set dhcp.lan.ignore=0
else
	uci -q del_list "$_wanfw=wisp"
	uci -q set network.wisp.disabled=1
	uci -q set wanchk.wisp.enable=0
	if [ "$_dis" = "0" ]; then
		uci -q set dhcp.lan.ignore=1
	else
		uci -q set dhcp.lan.ignore=0
	fi
fi

if [ "$_dis" = "1" ]; then
	uci -q del_list "$_wanfw=wisp"
	uci -q set network.wisp.disabled=1
	uci -q set wanchk.wisp.enable=0
fi

uci commit "$_wanfw"
uci commit network.wisp
uci commit wanchk.wisp
uci commit dhcp

fw3 reload
/etc/init.d/network reload
/etc/init.d/wanchk restart
/etc/init.d/ledctrl restart
/etc/init.d/dnsmasq restart

brctl show|grep -oiE 'br-[-a-z0-9]+'|while read -r line; do
	brctl delif "$line" "$_ifn"
done

if [ "$_net" = "lan" ] && [ "$_dis" = "0" ]; then
	brctl show|grep -oiE "br-$_net"|while read -r line; do
		brctl addif "$line" "$_ifn"
	done
fi
