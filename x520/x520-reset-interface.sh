#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

Help()
{
        # Display Help
        echo "Teardown for dpdk on one port"
        echo
        echo "Syntax: $0 -h | -a xxxx:xx:xx.x -v xxxx:xx:xx.x"
        echo
        echo "options:"
        echo "-h                Print this help."
        echo "-a xxxx:xx:xx.x   PCI-Address"
	echo "-v xxxx:xx:xx.x	VF-Adress"
}

PCIAddress=""
VFAddress=""

while getopts ":ha:v:" option; do
        case $option in
                h)
                        Help
                        exit;;
                a)
                        PCIAddress=$OPTARG;;
		v)
			VFAddress=$OPTARG;;
                \?)
                        echo "Invalid options. -h for help"
                        exit;;
        esac
done

Interface=$(grep PCI_SLOT_NAME /sys/class/net/*/device/uevent | grep "$PCIAddress" | cut -d/ -f 5)
Rule=$(ethtool --show-ntuple "$Interface" | grep Filter | cut -d: -f 2)

#VFAddress=$(grep PCI_SLOT_NAME /sys/class/net/*/device/uevent | grep "$Interface"v0 | cut -d/ -f 7 | cut -d= -f 2)

echo "Teardown for dpdk with:"
echo "PCI-Address: $PCIAddress"
echo "VF-Adress: $VFAddress"
echo "Interface: $Interface"
echo "Rule: $Rule"

#Unbind VF
dpdk-devbind.py -b none "$VFAddress"

#Reset MTU
ifconfig "$Interface" mtu 1500 #down

#Remove Rule
ethtool -N "$Interface" delete "$Rule"
ethtool -K "$Interface" ntuple off

#Display packagefilter
ethtool --show-ntuple "$Interface"

#Deactivate PCI Virtual Functions
cd /sys/bus/pci/devices/"$PCIAddress"
echo 0 > sriov_numvfs

dpdk-devbind.py -s
