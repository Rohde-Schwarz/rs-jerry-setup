#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

Help()
{
        # Display Help
        echo "Teardown for dpdk on one port"
        echo
        echo "Syntax: $0 -h | -v xxxx:xx:xx.x | -f name | -r xxxx"
        echo
        echo "options:"
        echo "-h                Print this help."
        echo "-v xxxx:xx:xx.x   VF-Address"
        echo "-f name           Interface"
        echo "-r xxxx   	Rule"
}

VFAddress=""
Interface=""
Rule=""

while getopts ":hv:f:r:" option; do
        case $option in
                h)
                        Help
                        exit;;
                v)
                        VFAddress=$OPTARG;;
                f)
                        Interface=$OPTARG;;
                r)
                        Rule=$OPTARG;;
                \?)
                        echo "Invalid options. -h for help"
                        exit;;
        esac
done

echo "Teardown for dpdk with:"
echo "VF-Adress: $VFAddress"
echo "Interface: $Interface"
echo "Rule: $Rule"

#Unbind VF
dpdk-devbind.py -b none "$VFAddress"

#Reset MTU
ip link set dev "$Interface" mtu 1500

#Remove Rule
ethtool -N "$Interface" delete "$Rule"
ethtool -K "$Interface" ntuple off

#Display packagefilter
ethtool --show-ntuple "$Interface"

#Deactivate PCI Virtual Functions
ip link set dev "$Interface" vf 0 trust off
echo 0 > /sys/class/net/"$Interface"/device/sriov_numvfs

dpdk-devbind.py -s
