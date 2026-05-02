#!/bin/ash

gName="dad_recovery"
gIface="br-lan"

log_info() {
	logger -t "$gName" "$*"
}

is_iface_up() {
	ip a s "$gIface" | grep -q UP
}

is_iface_dad() {
	ip a s "$gIface" | grep -q dadfailed
}

reset_ipv6() {
	for _ip in $(ip a s "$gIface"|grep dadfailed|awk -F' ' '{print $2}'); do
		log_info "reset ipv6 $_ip"
		ip a d "$_ip" dev "$gIface"
		ip a a "$_ip" dev "$gIface"
	done
}

log_info "checking $gIface..."
while true; do
	if is_iface_up; then
		sleep 60
		if is_iface_dad; then
			reset_ipv6
		else
			log_info "ipv6 is normal"
			break
		fi
	fi
done
