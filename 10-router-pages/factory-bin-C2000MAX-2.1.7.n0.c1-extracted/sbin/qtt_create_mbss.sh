#!/bin/bash
# Check if the correct number of arguments is provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <create> <band> <device_name>"
    exit 1
fi

# Assign arguments to variables
command=$1
band=$2
device_name=$3

common_mbss_cmd() {
	vif=$(uci add wireless wifi-iface)
}


# Function to handle the start command
qtt_create_mbss() {
	common_mbss_cmd
	
    case $band in
 		"2GHz")
			#Create 2G band interface
			uci rename wireless.$vif=ra1
			uci set wireless.ra1.device=$device_name
			uci set wireless.ra1.network=lan
			uci set wireless.ra1.mode=ap
			uci set wireless.ra1.disabled=0
			uci set wireless.ra1.vifidx=2
			uci set wireless.ra1.encryption=none
			uci set wireless.ra1.ssid=qtt-2g-open
            ;;
        "5GHz")
            #Create 5G band interface
			uci rename wireless.$vif=rai1
			uci set wireless.rai1.device=$device_name
			uci set wireless.rai1.network=lan
			uci set wireless.rai1.mode=ap
			uci set wireless.rai1.disabled=0
			uci set wireless.rai1.vifidx=2
			uci set wireless.rai1.encryption=none
			uci set wireless.rai1.ssid=qtt-5g-open
            ;;
		"6GHz")
			#Create 6G band interface
			uci rename wireless.$vif=rax1
			uci set wireless.rax1.device=$device_name
			uci set wireless.rax1.network=lan
			uci set wireless.rax1.mode=ap
			uci set wireless.rax1.disabled=0
			uci set wireless.rax1.vifidx=2
			uci set wireless.rax1.encryption=sae
			uci set wireless.rax1.ssid=qtt-6g-sae
			uci set wireless.rax1.ieee80211w=2
			uci set wireless.rax1.key=12345678
			;;
        *)
            echo "Unknown band: $band"
            exit 1
            ;;
    esac
}

# Execute the appropriate function based on the command
case $command in
    "create")
        qtt_create_mbss
        ;;
    *)
        echo "Unknown command: $command"
        exit 1
        ;;
esac
