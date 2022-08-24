#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

Help()
{
        # Display Help
        echo "Setup dpdk on one port"
        echo
	echo "Syntax: $0 -h | -f name -i xxx.xxx.xx.xx"
        echo
        echo "options:"
        echo "-h                Print this help."
        echo "-f name           Interface"
        echo "-i xxx.xxx.xx.x   IP-Address"
}

Interface=""
IP=""

while getopts ":hv:f:i:p:" option; do
        case $option in
                h)
                        Help
                        exit;;
                f)
                        Interface=$OPTARG;;
                i)
                        IP=$OPTARG;;
                \?)
                        echo "Invalid options. -h for help"
                        exit;;
        esac
done

echo "Setting up dpdk with:"
echo "Interface: $Interface"
echo "IP: $IP"

# Activate Virtual Functions
echo 1 > /sys/class/net/"$Interface"/device/sriov_numvfs

ip link set dev "$Interface" vf 0 trust on

#Configure packagefilter for DPDK bifurcated flow
ethtool -K "$Interface" ntuple on
ethtool -N "$Interface" flow-type ip4 dst-ip "$IP" user-def 0x8000000000000000 vf 0 queue 0

#Display packagefilter
ethtool --show-ntuple "$Interface"

#Increase MTU
ip link set dev "$Interface" mtu 9000
dpdk-devbind.py -s
