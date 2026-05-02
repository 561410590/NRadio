#!/bin/ash

command_quecsoc_signal() {
	command_quectel_signal2 "$@"
}

command_quecsoc_basic() {
	command_quectel_basic2 "$@"
}

command_quecsoc_rstsim() {
	command_generic_reset "NONE"
}

command_quecsoc_iccid() {
	command_quectel_iccid "$@"
}

command_quecsoc_imei() {
	_command_exec_raw "NONE" "${AT_GENERIC_PREFIX}CGSN" | sed -n '2p'|xargs -r printf
}
