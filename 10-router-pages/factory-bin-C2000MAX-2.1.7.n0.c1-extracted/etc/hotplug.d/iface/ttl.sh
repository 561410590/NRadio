#!/bin/sh

[ "$ACTION" = ifup ] || exit 0
INTERFACE_PREFIX="${INTERFACE%%_*}"
proto=$(uci -q get network.$INTERFACE_PREFIX.proto)
[ "$proto" == "wwan" -o "$proto" == "tdmi" ] || exit 0

logger -t ttl "Reloading ttl due to $ACTION of $INTERFACE ($DEVICE)"

ttl_set_4(){
	local ifname="$1"

	ttl_ipv4=$(uci -q get ttl.ttl.ipv4)

	#iptables -t mangle -N ttl_chain_pre
	#iptables -t mangle -N ttl_chain_post
	#iptables -t mangle -F ttl_chain_pre
	#iptables -t mangle -F ttl_chain_post
	#iptables -t mangle -D PREROUTING -i "$ifname"  -j ttl_chain_pre
	#iptables -t mangle -D POSTROUTING -o "$ifname"  -j ttl_chain_post
	#iptables -t mangle -I PREROUTING -i "$ifname"  -j ttl_chain_pre
	#iptables -t mangle -I POSTROUTING -o "$ifname"  -j ttl_chain_post

	sed -i '/iptables .*-j TTL/d' /etc/firewall.user
	if [ -n "$ttl_ipv4" -a -n "$ifname" ];then
		sed -i "/net.ipv4.ip_default_ttl/d" /etc/sysctl.conf
		sed -i '$a net.ipv4.ip_default_ttl='${ttl_ipv4} /etc/sysctl.conf
		sysctl -w -p /etc/sysctl.conf
		#iptables -t mangle -I ttl_chain_pre -j TTL --ttl-set $ttl_ipv4
		#iptables -t mangle -I ttl_chain_post -j TTL --ttl-set $ttl_ipv4
	else
		sed -i '/net.ipv4.ip_default_ttl/d' /etc/sysctl.conf
		sed -i '$a net.ipv4.ip_default_ttl=64' /etc/sysctl.conf
		sysctl -w -p /etc/sysctl.conf
	fi
}

ttl_set_6(){
	local ifname="$1"

	ttl_ipv6=$(uci -q get ttl.ttl.ipv6)
	#ip6tables -t mangle -N ttl_chain_pre
	#ip6tables -t mangle -N ttl_chain_post
	#ip6tables -t mangle -F ttl_chain_pre
	#ip6tables -t mangle -F ttl_chain_post
	#ip6tables -t mangle -D PREROUTING -i "$ifname"  -j ttl_chain_pre
	#ip6tables -t mangle -D POSTROUTING -o "$ifname"  -j ttl_chain_post
	#ip6tables -t mangle -I PREROUTING -i "$ifname"  -j ttl_chain_pre
	#ip6tables -t mangle -I POSTROUTING -o "$ifname"  -j ttl_chain_post

	sed -i '/ip6tables .*-j HL/d' /etc/firewall.user
	if [ -n "$ttl_ipv6" -a -n "$ifname" ];then
		sed -i '/net.ipv6.conf.'$ifname'.hop_limit/d' /etc/sysctl.conf
		sed -i '$a net.ipv6.conf.'$ifname'.hop_limit='$ttl_ipv6 /etc/sysctl.conf
		sysctl -w -p /etc/sysctl.conf
		#ip6tables -t mangle -I ttl_chain_pre -p tcp -j HL --hl-set $ttl_ipv6
		#ip6tables -t mangle -I ttl_chain_post -p tcp  -j HL --hl-set $ttl_ipv6
		#ip6tables -t mangle -I ttl_chain_pre -p udp -j HL --hl-set $ttl_ipv6
		#ip6tables -t mangle -I ttl_chain_post -p udp  -j HL --hl-set $ttl_ipv6
	else
		sed -i '/net.ipv6.conf.'$ifname'.hop_limit/d' /etc/sysctl.conf
		sed -i '$a net.ipv6.conf.'$ifname'.hop_limit=64' /etc/sysctl.conf
		sysctl -w -p /etc/sysctl.conf
	fi
}

if echo "$INTERFACE"|grep -sq "6" ;then
	ttl_set_4 "$DEVICE"
elif echo "$INTERFACE"|grep -sq "4" ;then
	ttl_set_6 "$DEVICE"
else
	ttl_set_4 "$DEVICE"
	ttl_set_6 "$DEVICE"
fi
