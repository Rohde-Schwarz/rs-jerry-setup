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

### Prepare Service Files 
To have the virtual functions created and connected with the vfio-pci driver on startup, requires a service which handles that work.
The files for this can be found in the folder "dell_r640". 
Open the `setup_10G_VF.sh` and replace the wrong interface names with your personal correct ones.
Do the same for the PCIID's as well, note that the PCIID's are the id's of the Virtual Functions created by the script `x710-setup-interfaces.sh`.
Create a folder at `/opt/rohde-schwarz/setup_10g_iq_streamer/` and copy `setup_10G_VF.sh` as well as the files from the x710 folder there.
Copy the `setup_10G_VF.service` to `/etc/systemd/system/` and enable the service.

```
systemctl daemon-reload
systemctl enable setup_10G_VF.service
```

### Final Check
To ensure that everything worked as expected, reboot the server. After the system is back up again run `ip a` and check the interfaces for the correct ip-adresses. 
The result should look similar to the following example. 

```
1: enp101s0f0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 9000 qdisc mq state DOWN group default qlen 1000
    link/ether ################ brd ff:ff:ff:ff:ff:ff
    inet 192.168.10.10/24 brd 192.168.10.255 scope global enp101s0f0
       valid_lft forever preferred_lft forever
2: enp101s0f1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9000 qdisc mq state UP group default qlen 1000
    link/ether ################ brd ff:ff:ff:ff:ff:ff
    inet 192.168.20.10/24 brd 192.168.20.255 scope global enp101s0f1
       valid_lft forever preferred_lft forever
    inet6 fe80::6efe:54ff:fe12:61a1/64 scope link 
       valid_lft forever preferred_lft forever
3: enp179s0f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9000 qdisc mq state UP group default qlen 1000
    link/ether ################ brd ff:ff:ff:ff:ff:ff
    inet 192.168.20.1/24 brd 192.168.20.255 scope global enp179s0f0
       valid_lft forever preferred_lft forever
    inet6 fe80::6efe:54ff:fe3e:6900/64 scope link 
       valid_lft forever preferred_lft forever
4: enp179s0f1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 9000 qdisc mq state DOWN group default qlen 1000
    link/ether ################ brd ff:ff:ff:ff:ff:ff
    inet 192.168.10.1/24 brd 192.168.10.255 scope global enp179s0f1
       valid_lft forever preferred_lft forever

```

Run `lspci | grep Virtual` to check whether the Virtual Functions have been created. If the output looks similar to the following example, everything should be fine.
```
65:02.0 Ethernet controller: Intel Corporation Ethernet Virtual Function 700 Series (rev 02)
65:0a.0 Ethernet controller: Intel Corporation Ethernet Virtual Function 700 Series (rev 02)
b3:02.0 Ethernet controller: Intel Corporation Ethernet Virtual Function 700 Series (rev 02)
b3:0a.0 Ethernet controller: Intel Corporation Ethernet Virtual Function 700 Series (rev 02)
```

# GUI installation

If you need the server to run a GUI, please be aware that many Linux desktops install a standby handler that sends the server into suspend mode after a certain period
of "inactivity". Should you need both access to command line and GUI, it is advised to disable the automatic standby in the Power settings of your desktop environment.
