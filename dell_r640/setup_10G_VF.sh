#!/bin/bash
set -e
echo "------------------------------------------------------------------------------------------"
echo "Start 10G and DPDK Setup Routine"
echo "------------------------------------------------------------------------------------------"
echo "Interface: enp101s0f0"
echo "------------------------------------------------------------------------------------------"
/opt/rohde-schwarz/setup_10g_iq_streamer/x710-setup-interface.sh -f enp101s0f0 -i 192.168.10.10
/opt/rohde-schwarz/setup_10g_iq_streamer/x710-bind-vf.sh 0000:65:02.0
echo "------------------------------------------------------------------------------------------"
echo "Interface: enp101s0f1"
echo "------------------------------------------------------------------------------------------"
/opt/rohde-schwarz/setup_10g_iq_streamer/x710-setup-interface.sh -f enp101s0f1 -i 192.168.20.10
/opt/rohde-schwarz/setup_10g_iq_streamer/x710-bind-vf.sh 0000:65:0a.0
echo "------------------------------------------------------------------------------------------"
echo "Interface: enp179s0f0"
echo "------------------------------------------------------------------------------------------"
/opt/rohde-schwarz/setup_10g_iq_streamer/x710-setup-interface.sh -f enp179s0f0 -i 192.168.20.1
/opt/rohde-schwarz/setup_10g_iq_streamer/x710-bind-vf.sh 0000:b3:02.0
echo "------------------------------------------------------------------------------------------"
echo "Interface: enp179s0f1"
echo "------------------------------------------------------------------------------------------"
/opt/rohde-schwarz/setup_10g_iq_streamer/x710-setup-interface.sh -f enp179s0f1 -i 192.168.10.1
/opt/rohde-schwarz/setup_10g_iq_streamer/x710-bind-vf.sh 0000:b3:0a.0
echo "------------------------------------------------------------------------------------------"
