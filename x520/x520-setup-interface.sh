#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

Help()
{
	# Display Help
	echo "Setup dpdk on one port"
	echo
	echo "Syntax: $0 -h | -a xxxx:xx:xx.x -i xxx.xxx.xx.x -p xxxx"
	echo
	echo "options:"
	echo "-h		Print this help."
	echo "-a xxxx:xx:xx.x	PCI-Address"
	echo "-i xxx.xxx.xx.x	IP-Address"
	echo "-p xxxx		Port"
}

PCIAddress=""
IP=""
Port=""

while getopts ":ha:i:p:" option; do
	case $option in
		h)
			Help
			exit;;
		a)
			PCIAddress=$OPTARG;;
		i)
			IP=$OPTARG;;
		p)
			Port=$OPTARG;;
		\?)
			echo "Invalid options. -h for help"
         		exit;;
	esac
done

# get interface name from PCI bus address
Interface=$(grep PCI_SLOT_NAME /sys/class/net/*/device/uevent | grep "$PCIAddress" | cut -d/ -f 5)

# get virtual function bus address
iter=10
counter=$iter
while ! VFAddress=$(grep PCI_SLOT_NAME /sys/class/net/*/device/uevent | grep "$Interface"v0 | cut -d/ -f 7 | cut -d= -f 2) ; do
        if [ $counter -le 0 ] ; then
                echo "Unable to find virtual function for provided interface." >&2
                exit 1
        fi
        sleep 1 

        if [ $counter -eq $iter ] ; then
                #Activate PCI Virtual Functions
                #echo 1 > "/sys/class/net/$Interface/device/sriov_numvfs"

                echo 1 > "/sys/bus/pci/devices/$PCIAddress/sriov_numvfs"

                echo "Virtual function created." >&2
        fi

        counter=$((counter-1))
done

echo "Setting up dpdk with:"
echo "PCI-Address: $PCIAddress"
echo "VF-Adress: $VFAddress"
echo "Interface: $Interface"
echo "IP: $IP"
echo "Port: $Port"

#Allocate Hugepages
echo 1024 > /proc/sys/vm/nr_hugepages

#Configure packagefilter for DPDK bifurcated flow
ethtool -K "$Interface" ntuple on

ethtool -N "$Interface" flow-type udp4 dst-ip "$IP" dst-port "$Port" action 0x100000000

#Display packagefilter
ethtool --show-ntuple "$Interface"

#Increase MTU
ifconfig "$Interface" mtu 9000 up

#Bind VF
dpdk-devbind.py -b vfio-pci "$VFAddress"
dpdk-devbind.py -s
