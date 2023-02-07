# RS Jerry Setup

This repository contains setup and reset scripts in preparation to use the R&S Jerry Driver.  

Provided TRex is installed, there is a configuration file as well as a packet file to confirm everything is setup correctly.

## OS Support

All scripts were developed and intended to be used on Linux (Ubuntu 20.04 or newer).

## Preparation

Make sure the Grub command line is set up correctly (/etc/default/grub).
Remember to `sudo update-grub` followed by a reboot after editing `/etc/default/grub`.

    GRUB_CMDLINE_LINUX_DEFAULT="quiet default_hugepagesz=1G hugepagesz=1G hugepages=4"

The `GRUB_CMDLINE_LINUX_DEFAULT` sets persistent options for the default-boot in a system.

In this case:
- `quiet` : suppress kernel logs
- `intel_iommu=off` : turn off IOMMU, which is not supported at the moment
- `default_hugepagesz=1G` : specify the default hugepage size in byte. Hugepages are required for faster allocation when reading big chunks of data from the network card
- `hugepagesz=1G` : specify the hugepage size in byte
- `hugepages=4` : the number of large hugepages to be allocated at boot time
- `vfio.enable_unsafe_noiommu_mode=1` : if there is no IOMMU available on the system, VFIO can still be used, but it has to be loaded with an additional parameter

## x520

The Intel® Ethernet Controller X520 is the required network interface controller (NIC) to run this setup.

The interface-setup script
- reserves hugepages at run time needed by DPDK for the large memory pool allocation used for packet buffers
- creates the VF
- enables Rx ntuple filters and actions for the PF
- updates the classification rule for udp4
- specifies the destination IP address of the incoming packets for udp4
- specifies the value of the destination port field
- specifies the Rx queue to send packets to
- increases the MTU
- binds the VF

in that order.

### Setup
The next step requires you to have DPDK installed.

The interface-setup script requires the PCI-Address of the Physical Function (PF). The PCI-Address can be found by calling `dpdk-devbind.py -s` and is represented by the leftmost digits usually in the form of `0000:00:00.0`.
To simplify the proccess since the IP address of the PF is needed, it is recommended but not required to have a static IP address bound to the PF.

To view information on how to use the interface-setup script:
```
sudo ./x520-setup-interface.sh -h
```

### Result
After executing the setup script, a VF is created and ready to recieve data.
`x520-setup-interface.sh` can be called multiple times to create multiple VFs.
Created VFs can be viewed via `dpdk-devbind.py -s`.

### Reset

It is recommened to execute the reset in the opposite direction of the setup:
First reset all the VFs created by `x520-setup-interface.sh` with `x520-reset-interface.sh`.
Afterwards reset the hugepages with `x520-reset-basic.sh`

The `x520-reset-interface.sh` script allows to remove single VFs without affecting other existing VFs.

To view information on how to reset a specific interface:
```
sudo ./x520-reset-interface.sh -h
```

Resetting hugepages:
```
sudo ./x520-reset-basic.sh
```

## x710

The Intel® Ethernet Controller X710 is the required network interface controller (NIC) to run this setup.

Make sure the latest compatible [i40e Driver](https://www.intel.com/content/www/us/en/download/18026/intel-network-adapter-driver-for-pcie-40-gigabit-ethernet-network-connections-under-linux.html) is installed for your system.
Usually the built-in i40e Driver does **not** suffice.

Additionally `ethtool` should be version 4.11 or later.

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
