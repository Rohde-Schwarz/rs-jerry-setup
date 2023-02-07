# RS Jerry Setup for DELL R640 with two x710

This contains a example guideline for a Dell R640 with x710

## OS Support

All scripts were developed and intended to be used on Linux (Ubuntu 20.04 or newer).

## Preparation

Make sure the Grub command line is set up correctly (/etc/default/grub).
Remember to `sudo update-grub` followed by a reboot after editing `/etc/default/grub`.

    GRUB_CMDLINE_LINUX_DEFAULT="quiet default_hugepagesz=1G hugepagesz=1G hugepages=4"

The `GRUB_CMDLINE_LINUX_DEFAULT` sets persistent options for the default-boot in a system.

In this case:
- `quiet` : suppress kernel logs
- `default_hugepagesz=1G` : specify the default hugepage size in byte. Hugepages are required for faster allocation when reading big chunks of data from the network card
- `hugepagesz=1G` : specify the hugepage size in byte
- `hugepages=4` : the number of large hugepages to be allocated at boot time


## x710
The Intel® Ethernet Controller X710 is the required network interface controller (NIC) to run this setup.

### Prepare BIOS
Boot into BIOS and and enable the Virtual Functions for every x710 Network Card, follow the steps in the gif.

### Install Missing Dependencies
```
# ethtool should be version 4.11 or later.
sudo apt-get install ethtool

# Install Build Essentials
apt-get install build-essential

# Install Kernel Headers
apt-get install linux-headers-$(uname -r)

# Install missing Python packages
sudo apt-get install python3-distutils
sudo apt-get install python3-pyelftools
sudo apt-get install python3-numpy
```

### Update x710 Firmware
Download the latest Firmware from the [Dell Website](https://www.dell.com/support/home/de-de/drivers/driversdetails?driverid=gxj5g), Download the Update Paket for Red Hat Linux and follow the Installation steps further down on the website.
Download and view the "fw_release_x710.txt" and check the NVM Version, in this example 9.00. The Version will be used later to determine the correct DPDK Version.

### Install i40e Driver
Download the latest compatible [i40e Driver](https://www.intel.com/content/www/us/en/download/18026/intel-network-adapter-driver-for-pcie-40-gigabit-ethernet-network-connections-under-linux.html) and install it on the system.
Usually the built-in i40e Driver does **not** suffice.
For the installation follow the steps in the README File of the Downloaded folders. Make sure to install the build-essentials and Linux Kernel Headers beforehand.

### Build & Install DPDK 
Get the correct [DPDK Driver Version](https://core.dpdk.org/download/) from the DPDK Website, check this [Table for x710](http://doc.dpdk.org/guides/nics/i40e.html) to get the correct Version based on Driver and Firmware.   

```
# Load driver
modprobe vfio-pci

# Check for correct driver setup
# vfio-pci should show up somewhere in lsmod 
lsmod 

# Load driver persistent
echo "vfio-pci" | sudo tee -a /etc/modules
```

### Prepare Network and set Adresses for x710
```
# Prepare 10G networks in /etc/network/interfaces
# The following code is an example for two x710 network cards

# 10G Network Interfaces 
auto enp101s0f0
allow-hotplug enp101s0f0
iface enp101s0f0 inet static 
    address 192.168.10.10
    netmask 255.255.255.0
    gateway 192.168.10.1

auto enp101s0f1
allow-hotplug enp101s0f1
iface enp101s0f1 inet static 
    address 192.168.20.10
    netmask 255.255.255.0
    gateway 192.168.20.1

auto enp179s0f0
allow-hotplug enp179s0f0
iface enp179s0f0 inet static 
    address 192.168.20.1
    netmask 255.255.255.0
    gateway 192.168.20.1

auto enp179s0f1
allow-hotplug enp179s0f1
iface enp179s0f1 inet static 
    address 192.168.10.1
    netmask 255.255.255.0
    gateway 192.168.10.1

```


The interface-setup script
- creates the VF
- trust the specified VF such that it can set specific features
- enables Rx ntuple filters and actions for the PF
- updates the classification rule for udp4
- specifies the destination IP address of the incoming packets for udp4
- enable cloud filter to split traffic to PF or VF
- specifies the Rx queue to send packets to
- increases MTU

in that order.

### Setup

DPDK is required to be installed.

Calling `dpdk-devbind.py -s` displays all network devices.
Interface names are usually displayed as `if=<Interface>` and required for the interface-setup script.
To view information on how to use the interface-setup script:
```
cd ./x710
sudo ./x710-setup-interface.sh -h
```

The final call is to `dpdk-devbind.py -s` again which now also displays the newly created VF as well as the other network devices like before.
The VF address is represented by the leftmost digits usually in the form of `0000:00:00.0`.
All VF addresses can also be displayed direclty via:
```
dpdk-devbind.py -s | grep 'Virtual Function' | cut -d" " -f1
```

Bind the displayed new VF address:
```
sudo ./x710-bind-vf.sh <VF address>
```

After binding the VF, `dpdk-devbind.py -s` gets called again. The bound VF should be listed under `Network devices using DPDK-compatible driver`.

### Result
After executing the setup scripts, a VF is created and ready to recieve data.
`x710-setup-interface.sh` can be called multiple times to create multiple VFs.
Created VFs can be viewed via `dpdk-devbind.py -s`.

### Reset

It is recommened to execute the reset in the opposite direction of the setup:
First reset all the VF created by `x710-setup-interface.sh` with `x710-reset-interface.sh`.
Afterwards reset the basic things of `x710-setup-basic.sh` with `x710-reset-basic.sh`

To view information on how to reset a specific interface:
```
sudo ./x710-reset.sh -h
```

## Loopback via TRex (Optional)

Loopback requires the [TRex core](https://github.com/cisco-system-traffic-generator/trex-core) to be build on the system.

The `hrzr_packet.py` generates sin waves according to the HRZR protocol and sends it from a specified VF (related to the IP address of the PF) to a diffrent VF (again, related to the IP address of the PF).

### Setup

```
cd trex-files
```

Edit `trex_cfg.yaml` and insert into `interfaces    : ["xx:xx.x", "dummy"]` the last digits of the VF address you want to send from.

Edit `hrzr_packet.py` and edit the following line:
```
base_pkt =  Ether(dst="ff:ff:ff:ff:ff:ff")/IP(src="xxx.xxx.xx.x", dst="xxx.xxx.xx.x")/UDP(dport=0,sport=1025)/b'\x00\x00\x00\x00\x00\x00\x00\x00'/array#/
```
such that
- `src="xxx.xxx.xx.x"` holds the IP address of the PF you want to send traffic from
- `dst="xxx.xxx.xx.x"` holds the IP address of the PF you want to send traffic to
- `dport=0` holds the port of the PF you want to send traffic to

### Start
_In the trex-core directory of the TRex core repository:_  
Start your scapy server with the edited configuration. Usually via:
```
cd ./scripts
./t-rex-64 -i --cfg <full_path_to>/trex-files/trex_cfg.yaml
```

Wait for the scapy server to load.

In a different console window, open the trex-console. Usually via:
```
cd ./scripts
./trex-console
```

_In the trex-console_  
Start the data generation with the hrzr_packet.py. Usually via:
```
start -f <full_path_to>/trex-files/hrzr_packet.py -m 1000mbps
```
The trex-console can be closed afterwards.

To see the if the VF sends correctly:
```
watch -n 0.5 -d 'ethtool -S <interface> | grep tx | grep -v ": 0"'

```

To see the if the VF receives correctly:
```
watch -n 0.5 -d 'ethtool -S <interface> | grep rx | grep -v ": 0"'
```
