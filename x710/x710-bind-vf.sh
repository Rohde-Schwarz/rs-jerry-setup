#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

#Binding
dpdk-devbind.py --force -b vfio-pci $1
dpdk-devbind.py -s
