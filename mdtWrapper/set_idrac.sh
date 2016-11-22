#!/bin/bash
#added reset at the very beginning, otherwise I can't find the LAN channel
if [ $# -ne 5 ]; then
echo "***************************************************************"
echo "***************************************************************"

echo "no arguments provided, the actual configuration will be printed"
echo
echo "***************************************************************"
echo "***************************************************************"

ipmitool lan print
echo "***************************************************************"
echo "***************************************************************"

echo
echo "***************************************************************"
echo "***************************************************************"
echo
echo "Usage: $0 iDrac_ip iDrac_nm iDrac_gw iDrac_pwd iDrac_hostname"
exit 0
fi

module=$(lsmod | grep -c ipmi)
if [ $module -ne 3 ]; then

modprobe ipmi_devintf
modprobe ipmi_si
modprobe ipmi_msghandler
fi
iDrac_ip=$1
iDrac_mask=$2
iDrac_gw=$3
iDrac_pwd=$4
iDrac_hostname=$5


# This script set iDrac IP configuration on proliant
# find the LAN number
#LAN=$(for i in {0..15}; do ipmitool lan print $i 2>/dev/null | grep -q ^Set && echo Channel $i; done | awk '{print $2}')
LAN=1
echo "channel is: $LAN"

ipmitool lan set $LAN ipsrc static
ipmitool lan set $LAN ipaddr $iDrac_ip
ipmitool lan set $LAN netmask $iDrac_mask
ipmitool lan set $LAN defgw ipaddr $iDrac_gw
ipmitool user set password 2 $iDrac_pwd
ipmitool -I lan set hostname $iDrac_hostname
ipmitool mc reset cold   # reset iDrac interface
