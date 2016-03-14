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
echo "Usage: set_ilo.sh ILO_ip ILO_nm ILO_gw ILO_pwd ILO_hostname"
exit 0
fi

ipmitool mc reset cold   # reset ILO interface
for i in {1..30}
	do
	sleep 1
	TIME=$((30-i))
	echo  "Waiting for ilo to come back.... try to connect in $TIME seconds"
done
module=$(lsmod | grep -c ipmi)
if [ $module -ne 3 ]; then

modprobe ipmi_devintf
modprobe ipmi_si
modprobe ipmi_msghandler
fi
ILO_ip=$1
ILO_mask=$2
ILO_gw=$3
ILO_pwd=$4
ILO_hostname=$5


# This script set ILO IP configuration on proliant
# find the LAN number
LAN=$(for i in {0..15}; do ipmitool lan print $i 2>/dev/null | grep -q ^Set && echo Channel $i; done | awk '{print $2}')
if [[ ! -z "$LAN" ]]; then
echo "channel is: $LAN"

ipmitool lan set $LAN ipsrc static
ipmitool lan set $LAN ipaddr $ILO_ip
ipmitool lan set $LAN netmask $ILO_mask
ipmitool lan set $LAN defgw ipaddr $ILO_gw
ipmitool user set password 1 $ILO_pwd
ipmitool -I lan set hostname $ILO_hostname
ipmitool mc reset cold   # reset ILO interface
else
echo "no channel found"
exit 1
fi
