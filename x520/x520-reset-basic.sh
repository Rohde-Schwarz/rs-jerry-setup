#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

#Reset Hugepages
echo 4 > /proc/sys/vm/nr_hugepages
