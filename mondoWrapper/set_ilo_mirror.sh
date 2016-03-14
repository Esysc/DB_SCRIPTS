#!/bin/bash 
#added reset at the very beginning, otherwise I can't find the LAN channel
#Added the mirror part directly here
#Set uefi to legacy
if [ $# -ne 5 ]; then
echo "***************************************************************"
echo "***************************************************************"

echo "No arguments provided, the actual ILO and smart controller configuration will be printed"
echo
echo "***************************************************************"
echo "***************************************************************"

ipmitool lan print
echo
echo "***************************************************************"
echo "***************************************************************"
hpssacli ctrl all show config

echo
echo "***************************************************************"
echo "***************************************************************"
echo
echo "Usage: set_ilo_mirror.sh ILO_ip ILO_nm ILO_gw ILO_pwd ILO_hostname"
exit 0
fi

declare -i Disks
declare -i LogDisks

Disks=$(hpssacli ctrl all  show config | grep -c "physicaldrive")
LogDisks=$(hpssacli ctrl all  show config | grep -c "logicaldrive")
#LogDisks=$(fdisk -l)
if [[ $LogDisks -eq 0 ]]; then
	if [[ $Disks -eq 2 ]]; then
		echo "Found $Disks not configured on the system"
		#Proceeding on raid creation
		Raid=$(hpssascripting -reset -i /home/partimag/HPRAIDTEMPLATES/hpssascripting1.ini)
		if [ $? -ne 0 ]; then
			echo "The first applied template gives an error . I'm going to apply the second one....."
			Raid=$(hpssascripting -reset -i /home/partimag/HPRAIDTEMPLATES/hpssascripting2.ini)
			if [ $? -ne 0 ]; then
			echo "I have two physical disks, but I could'nt build a mirror as asked. I'm exit right now"
			exit 1
			fi
		fi
	fi
	echo "Mirroring Successfull! $Raid"
else
	echo "The logical volume is already present, No need to create array"
fi
 
ILOReset () {
	SECTOWAIT=60
	ipmitool mc reset cold   # reset ILO interface
	
	for i in {1..60}
	do
		sleep 1
		TIME=$((SECTOWAIT-i))
		echo  -ne "Waiting for ilo to come back.... try to connect in $TIME seconds"\\r
	done
	echo
}

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
ILOReset
#add default route for later connection on ilo ip
route add default gw 10.0.129.149
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
echo "Setting the boot mode to legacy and  hostname to $ILO_hostname ....."
xml='<RIBCL VERSION="2.0">
 <LOGIN USER_LOGIN="administrator" PASSWORD="***REMOVED***">
 <SERVER_INFO MODE="write">
 <SET_PENDING_BOOT_MODE VALUE="LEGACY"/>
  <SERVER_NAME value ="'$ILO_hostname'"/>
 </SERVER_INFO>
 </LOGIN>
</RIBCL>'
echo "$xml" | hponcfg -i
ILOReset
echo 0
else
echo "no channel found"
exit 1
fi

