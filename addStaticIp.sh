#!/bin/bash


#!/bin/bash

# add a static IP address to the end of a specific file
addStaticIpToFile() {
    local ipAddress=$1
    local filePath=$2
    local routerAddress="192.168.1.1" # default value
    local dnsServer="1.1.1.1" # default value: cloudflare
    local now=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

    # file exists check
    if [ ! -f "$filePath" ]; then
        echo "Error: File $filePath not found"
        exit 1
    fi

    # not null check
    if [ -z "$ipAddress" ] || [ -z "$filePath" ]; then
        echo "Error: IP address or file path cannot be null"
        exit 1
    fi

    # define and interpolate static IP config
    local staticConfig="\
interface wlan0\n\
static ip_address=$ipAddress/24\n\
static routers=$routerAddress\n\
static domain_name_servers=$dnsServer"

    # tell future self this next block was added by script
    echo -e "\n\n# Static IP configuration for $ipAddress added by automation script on $now" >> "$filePath"

    # Append the static IP configuration block to the file
    echo -e "$staticConfig\n\n" >> "$filePath"
        
    echo -e "last 10 lines of $filePath...\n"

    # show what was just added
    tail -n 10 "$filePath"
}

# Example usage
staticIp="192.168.1.144"  # Change this to your desired static IP address
configFile="/etc/dhcpcd.conf"
addStaticIpToFile "$staticIp" "$configFile"