#!/bin/bash 

###########################################################
## Copyright (c) 2015 Mycompany SA. All rights reserved.
###########################################################

#@(#)------------------------------------------------------
#@(#) General Information
#@(#)   Name      : network-config-cli
#@(#)   Purpose   : Network configuration for RedHat based platform
#@(#)   Version   : 1.01
#@(#)   Author    : A. Chevalet
#@(#)------------------------------------------------------
#@(#) Usage
#@(#)   Set the machine hostname:
#@(#)     network-config-cli -n <hostname>
#@(#)
#@(#)   Set the domain name and dns:
#@(#)     network-config-cli -o <domain> [-s '<dns_1> <dns_2>']
#@(#)
#@(#)   Configure a single interface in static:
#@(#)     network-config-cli -c <dev> -i <ip> -m <netmask> [-B] [-r] [-e <opts>]
#@(#)
#@(#)   Configure a redundant interface (bond) in dhcp:
#@(#)     network-config-cli -c '<dev_1>..<dev_n>' -D [-N <hostname>] [-P]
#@(#)
#@(#)   Set the default gateway
#@(#)     network-config-cli -g <gateway>
#@(#)
#@(#)   Delete an interface:
#@(#)     network-config-cli -d <dev> [-r]
#@(#)
#@(#)   Restart networking service:
#@(#)     network-config-cli -R
#@(#)
#@(#)   List devices configuration:
#@(#)     network-config-cli -l
#@(#)
#@(#)   List devices available:
#@(#)     network-config-cli -a
#@(#)
#@(#)   All in one example:
#@(#)    network-config-cli -n host1 -o dom1 -s '10.0.15.3 10.0.15.4'
#@(#)    -c 'eno1 eno49' -i 10.1.0.2 -m 255.255.255.0 -g 10.1.0.1 -R
#@(#)
#@(#)------------------------------------------------------
#@(#) Parameters
#@(#)   -n        : Set the hostname
#@(#)   -o        : Set the domain name
#@(#)   -s        : Set DNS server(s)
#@(#)   -c        : Configure a network
#@(#)   -g        : Set the gateway. ' ' to remove
#@(#)   -d        : Delete a network
#@(#)   -R        : Restart network service
#@(#)   -i        : Set the IP address
#@(#)   -m        : Set the netmask
#@(#)   -B        : Do not start on boot
#@(#)   -D        : Use DHCP
#@(#)   -P        : Set PEERDNS=no
#@(#)   -N        : Set DHCP_HOSTNAME (default: $HOSTNAME)
#@(#)   -M        : Set bond mode. 0 to 6 (default: 1)
#@(#)   -e        : Set ethtool options
#@(#)   -r        : Change config file(s) only (no action)
#@(#)   -h        : Display this help
#@(#)   -x        : Debug Mode
#@(#)------------------------------------------------------
#@(#) Exit Codes
#@(#)  255        : Syntax Error
#@(#)    0        : Succeed
#@(#)    1        : Failed
#@(#)------------------------------------------------------

###########################################################
# History :
#   1.00  - 2015.10.07 - Initial version
#   1.01  - 2015.11.16 - Added ethtool options (-e)
#   1.02  - 2016.02.17 - ACS - Added list nics function
###########################################################


###################
# Verify script parameters
CheckParam()
{
   Help() {
     echo $1:; grep "^#@(#)" $1 | sed "s/#@(#)/  /g"
   }

   Error() {
      Help $0; exit $1
   }

   OPTIND=1
   while getopts o:s:c:s:d:i:m:n:g:e:RralxhqDN:PM:B OPTION 2>/dev/null; do
      case $OPTION in
         a) OptionAvailable=1 ;;
         n) Hostname=$OPTARG ;;
         o) Domain=$OPTARG ;;
         s) DnsList=$OPTARG ;;
         c) OptionCreate=1; Devices=$OPTARG ;;
         d) OptionDelete=1; Devices=$OPTARG ;;
         R) OptionRestartNtwk=1;;
         l) OptionList=1;;
         i) IPAddress=$OPTARG ;;
         m) Netmask=$OPTARG ;;
         M) BondMode=$OPTARG ;;
         e) EthOpt=$OPTARG ;;
         r) NoRestart=1 ;;
         g) Gateway=$OPTARG ;;
         D) UseDhcp=1 ;;
         B) OnBoot="no" ;;
         N) DhcpHostname=$OPTARG ;;
         P) PeerDns="no" ;;
         x) set -x ;;
         q) QUIET=1;;
         h) Error 0 ;;
         *) Error 255 ;;
      esac
   done

   shift $(( $OPTIND-1 ))
   (( $# != 0 )) && Error 255

   # Check exclusive options
   case $(( $OptionCreate + $OptionDelete )) in
      0) [[ -z $Hostname$Domain$DnsList$OptionRestartNtwk$OptionList$OptionAvailable$Gateway ]] && Error 255
         [[ -n $IPAddress$Netmask$UseDhcp$BondMode$EthOpt ]] && Error 255
         [[ $OnBoot$PeerDns =~ no ]] && Error 255 ;;
      2) Error 255;;
   esac
   
}


###################
#  Display message on screen and in log file 
#  $1=Msg [$2=echo options]
Print() {
   echo -e $2 "$1"
   echo -e $2 "$( date -u +"%Y-%m-%d %H:%M:%S" ) - $1" >> $LogFile
}


###################
# Verify device exist
IsValidDevice()
{
   typeset Devices=$*

   for Dev in $Devices; do
      ip link show dev $Dev >/dev/null 2>&1
      if (( $? )); then
         Print "ERR: Device '$Dev' does not exist"
         return 1
      fi
   done

   return 0
}


###################
# Verify IP validity
IsValidIp()
{
   typeset AllIp=$*
   
   for Ip in $AllIp; do
      if [[ $Ip == 127.0.0.1 ]]; then Print "ERR: $Ip is reserved for localhost"; return 1; fi
      
      if [[ -z $( echo $Ip | egrep '^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])$' ) ]]; then 
         Print "ERR: '$Ip' is not a valid IP address"
         return 1
      fi
   done
   
   return 0
}


###################
# Return 0 if arg is a slave interface
IsSlave()
{
   typeset Dev=$1
   typeset IfCfg=$CfgPath$Dev
   
   # Check if Dev is in a bond
   ip link show dev $Dev 2>/dev/null | grep -qw "SLAVE" && return  0
   [[ -r $IfCfg ]] && grep -qP '^[ \t]*SLAVE=yes' $IfCfg && return 0
   
   return 1
}


###################
# Return 0 if nic is up
IsNicUp()
{
   ip link show dev $1 2>/dev/null | grep -q "<.*UP.*>"
   return $?
}


###################
# Stop nic only if up
Ifdown()
{
   IsNicUp $1 && ifdown $1 >>$LogFile 2>&1
   return $?
}


###################
# Return master of a slave 
GetMaster()
{
   typeset Dev=$1
   typeset IfCfg=$CfgPath$Dev
   typeset Master
   
   Master=$( ip link show dev $Dev 2>/dev/null | grep -Po '(?<=master\s)[^\s]*' )
   [[ -z $Master ]] && Master=$( awk -F"=" '/^[ \t]*MASTER=/ { print $2 }' $IfCfg 2>/dev/null )
   
   echo ${Master:-unknown}
}


###################
# Return slaves of master 
GetSlaves()
{
   typeset Master=$1
   typeset IfCfg=$CfgPath$Master
   typeset BondCfg="/proc/net/bonding/$Master"
   typeset Slaves

   # check running bond 
   [ -e $BondCfg ] && Slaves=$( awk '/Slave Interface:/ {print $NF}' $BondCfg )
   
   # if down, check in ifcfg
   if [[ -z $Slaves ]]; then
      for file in $( grep -l MASTER=$Master $CfgPath* ); do 
         Slaves="$Slaves $( awk -F"=" '/^[ \t]*DEVICE=/ { print $2 }' $file )"
      done
   fi
   
   echo ${Slaves:-unknown}
}


###################
# Return bootproto 
GetProto()
{
   typeset Dev=$1
   typeset IfCfg=$CfgPath$Dev
   typeset Proto

   if [ -e $IfCfg ]; then 
      if grep -P "^[ \t]*BOOTPROTO=" $IfCfg | grep -q "dhcp"
         then Proto="dhcp"
         else Proto="static"
      fi
   fi
   
   echo ${Proto:-unknown}
}


###################
# Verify interface is not a slave
CheckNoSlave()
{
   typeset Dev=$1
   typeset IfCfg=$CfgPath$Dev

   # Dev is a slave
   if IsSlave $Dev; then
      # get bond name
      Master=$(GetMaster $Dev)
      # error only if a master exist
      if [[ -n $Master ]]; then
         Print "ERR: '$Dev' is slave of bond $Master"
         return 1
      fi
   fi

   return 0
}


###################
# Verify interface is connected
CheckLink()
{
   typeset Dev=$1

   ip link show dev $Dev 2>/dev/null | grep -q "state UP"
   if (( $? )); then
      [[ -n $2 ]] || Print "WAR: Link is not up on $Dev!"
      return 1
   fi
   
   return 0
}


###################
# Set the Hostname
SetHostname()
{
   # Verify hostname syntax
   BadChar=$( echo $Hostname | sed "s:[a-z]*[A-Z]*[0-9]*-*::g" )
   if [[ -n $BadChar ]]; then
      Print "ERR: Following characters are not allowed in the hostname: $BadChar"
      return 1
   fi

   Print "INF: Setting hostname '$Hostname'..."

   # Update hostname
   if [[ $RH =~ ^7\.* ]]; then
      # rh7 
      hostnamectl set-hostname $Hostname || return 1
   else
      # rh6
      sed -i -s "/^[ \t]*HOSTNAME=/d" /etc/sysconfig/network || return 1
      echo "HOSTNAME=$Hostname" >> /etc/sysconfig/network || return 1
      hostname $Hostname || return 1
   fi   
      
   return 0
}


###################
# Set the domain
SetDomain()
{
   # Verify hostname syntax
   BadChar=$( echo "$Domain" | sed "s:[a-z]*[A-Z]*[0-9]*-*\.*::g" )
   if [[ -n $BadChar ]]; then
      Print "ERR: Following characters are not allowed in the domain name: $BadChar"
      return 1
   fi

   Print "INF: Setting domain name '$Domain'..."

   # Change domain
   sed -i -e "/^[ \t]*domain /d" -e "/^[ \t]*search /d" /etc/resolv.conf || return 1 
   echo "search $Domain" >> /etc/resolv.conf || return 1 

   return 0
}


###################
# Set the DNS 
SetDNS()
{
   # clear DNS
   Print "INF: Cleaning up current DNS..."
   sed -i "/^[ \t]*nameserver /d" /etc/resolv.conf || return 1 

   # set DNS
   for Ip in $DnsList; do
      Print "INF: Setting DNS '$Ip'..."
      echo "nameserver $Ip" >> /etc/resolv.conf || return 1
   done
   
   return 0
}


###################
# Set interface config
SetConfig()
{
   typeset Dev=$1
   typeset Mode=$2
   typeset Master=$3
   typeset IfCfg=$CfgPath$Dev
   typeset TmpFile="/tmp/ifcfg-$Dev.$$"
      
   # create cfg file
   echo "DEVICE=$Dev"        > $TmpFile
   echo "TYPE=Ethernet"     >> $TmpFile
   echo "ONBOOT=$OnBoot"    >> $TmpFile
   echo "USERCTL=no"        >> $TmpFile
   echo "NM_CONTROLLED=no"  >> $TmpFile
   echo "IPV6INIT=no"       >> $TmpFile
   
   # set ethtool opt 
   [[ -n $EthOpt ]] && \
   echo "ETHTOOL_OPTS=\"$EthOpt\"" >> $TmpFile

   # slave config
   if [[ $Mode == slave ]]; then
      echo 'SLAVE=yes'      >> $TmpFile
      echo "MASTER=$Master" >> $TmpFile
      # slave ok, apply and exit 
      mv $TmpFile $IfCfg || return 1
      return 0
   fi
   
   # dhcp config
   if (( $UseDhcp )); then 
      echo "BOOTPROTO=dhcp"   >> $TmpFile
      echo "PEERDNS=$PeerDns" >> $TmpFile
      echo "DHCP_HOSTNAME=$DhcpHostname" >> $TmpFile
   # static config
   else
      echo "BOOTPROTO=none"    >> $TmpFile
      [[ -n $IPAddress ]] && \
      echo "IPADDR=$IPAddress" >> $TmpFile
      [[ -n $Netmask ]] && \
      echo "NETMASK=$Netmask"  >> $TmpFile
   fi
   
   # set bond options
   [[ $Mode == bond ]] && \
   echo "BONDING_OPTS='mode=${BondMode:-1} miimon=100'" >> $TmpFile
   
   mv $TmpFile $IfCfg || return 1
   
   return 0
}


###################
# Configure single nic
CreateInterface()
{
   typeset Dev=$1
   typeset Mode
   typeset Slaves

   Print "INF: Configuring network interface '$Dev'..."
   
   # Check if interface is already in a bond
   CheckNoSlave $Dev || return 1
   
   # check if bond 
   if [ -e /proc/net/bonding/$Dev ] || [[ $Dev =~ bond[0-9]+ ]]; then 
      Mode=bond
      Slaves=$(GetSlaves $Dev)
   fi
   
   # stop interface, skip if -r
   (( $NoRestart )) || Ifdown $Dev >>$LogFile 2>&1 
   
   # set slave config if any
   for Slave in $Slaves; do 
      SetConfig $Slave slave $Dev || return 1
   done
   
   # set ifcfg file
   SetConfig $Dev $Mode || return 1
   
   # restart interface with new config, skip if -r
   (( $NoRestart )) || ifup $Dev >>$LogFile 2>&1 

   if (( $? )); then
      Print "ERR: Failed to start interface $Dev"
      return 1
   fi

   # warning if link is not up
   (( $NoRestart )) || CheckLink $Dev

   return 0
}


###################
# Create a bond
CreateBond()
{
   typeset Devices=$@
   typeset Bond=""
   typeset Dev=""
   typeset IfCfg=""
   typeset TmpFile="/tmp/ifcfg.$$"
   typeset -i Id=0
   typeset -i Rc=0

   # Check if interfaces are already in a bond
   for Dev in $Devices; do
      CheckNoSlave $Dev || return 1
   done

   # Find free bond
   while [ -f ${CfgPath}bond${Id} ]; do Id+=1; done
   Bond=bond$Id

   Print "INF: Creating bond '$Bond' with '$Devices'..."

   # configure slaves
   for Dev in $Devices; do
      # stop interface, skip if -r 
      (( $NoRestart )) || Ifdown $Dev >>$LogFile 2>&1
      # set cfg file
      SetConfig $Dev slave $Bond || return 1
   done

   # configure bond
   SetConfig $Bond bond || return 1

   # exit if -r
   (( $NoRestart )) && return 0

   # start the bond
   ifup $Bond >>$LogFile 2>&1
   if (( $? )); then
      Print "ERR: Failed to initialize '$Bond'"
      return 1
   fi

   # warning if link is not up
   for Dev in $Devices; do
      CheckLink $Dev
   done
    
   return 0
}


###################
# Set the default gateway
SetGateway()
{
   typeset NetworkFile="/etc/sysconfig/network"
   
   # Remove current default route
   Print "INF: Removing default route..."
   sed -i "/^[ \t]*GATEWAY=/d" $NetworkFile || return 1
   
   # if gateway is empty (space) just remove it
   [[ -z $( echo $Gateway) ]] && return 0

   # Set new default route
   Print "INF: Setting default route to '$Gateway'..."
   echo "GATEWAY=$Gateway" >> $NetworkFile || return 1

   return 0
}


###################
# Restart networking service
RestartNetwork()
{
   Print "INF: Restarting network service..."
   
   if [[ $RH =~ ^7\.* ]]
      # rh7
      then systemctl restart network >>$LogFile 2>&1
      # rh6
      else service network restart >>$LogFile 2>&1
   fi   

   if (( $? )); then
      Print "ERR: An error occured during network service restart"
      return 1
   fi

   return 0
}


###################
# Delete either single or bond interface
DeleteOperation()
{
   typeset Dev=$1
   typeset IfCfg=$CfgPath$Dev
   typeset Rc=0

   # check if bond or not 
   if [ -e /proc/net/bonding/$Dev ]; then
      # delete bond
      DeleteBond $Dev || return 1 
   else
      # Check if interface is in a bond
      CheckNoSlave $Dev || return 1 
      # delete interface
      DeleteIf $Dev || return 1 
   fi

   return 0
}


###################
# Delete a bond
DeleteBond()
{
   typeset Bond=$1
   typeset Slaves

   Print "INF: Removing bond interface '$Bond'... "

   # get slaves from running bond
   Slaves=$( awk '/Slave Interface:/ { print $NF }' /proc/net/bonding/$Bond )
   # no slaves, check in ifcfg files
   [[ -z $Slaves ]] && Slaves=$( grep -l "MASTER=$Bond" $CfgPath* | sed "s:$CfgPath::g" )
        
   # stop bond
   if (( ! $NoRestart )); then 
      Ifdown $Bond >>$LogFile 2>&1
      echo "-$Bond" > /sys/class/net/bonding_masters 
      # remove bond cfg
      rm -f $CfgPath$Bond
   else
      # if -r keep cfg to allow network to stop it later
      DeleteIf $Bond || return 1
   fi
   
   # Remove bond's slaves
   for Dev in $Slaves; do
      DeleteIf $Dev || return 1
   done
   
   return $?
}


###################
# Delete an Interface
DeleteIf()
{
   typeset Dev=$1
   typeset IfCfg=$CfgPath$Dev
   typeset TmpFile="/tmp/ifcfg-$Dev.$$"

   Print "INF: Removing network interface '$Dev'... "
   
   # if -r clean config only
   if (( $NoRestart )); then 
      echo "DEVICE=$Dev"        > $TmpFile
      echo 'TYPE=Ethernet'     >> $TmpFile
      echo 'ONBOOT=no'         >> $TmpFile
      echo 'USERCTL=no'        >> $TmpFile
      echo 'NM_CONTROLLED=no'  >> $TmpFile
      echo 'IPV6INIT=no'       >> $TmpFile
      echo 'BOOTPROTO=none'    >> $TmpFile
      mv $TmpFile $IfCfg || return 1
   else
      # stop interface
      if IsNicUp $Dev; then
         ifdown $Dev >>$LogFile 2>&1   # on rh7 1st ifdown may fail
         ifdown $Dev >>$LogFile 2>&1
         if (( $? )); then
            Print "ERR: Failed to stop interface '$Dev'"
            return 1
         fi
      fi
      # clean cfg file
      rm -f $IfCfg || return 1
   fi
   
   return 0
}

##################
# Show only nic name, not config 
ListNic()
{
   # list of excluded devices
   typeset ExcludeDev="lo|virbr|ovs|br-|qbr|qvb|qvo|tap"
   # get devices list
   typeset DevList=$( ip link 2>/dev/null | awk -F':' '/^.*: / { print $2 }' | sort | grep -Ev "$ExcludeDev" )
   echo $DevList
}

###################
# Show nic config
ListNetwork()
{
   # list of excluded devices 
   typeset ExcludeDev="lo|virbr|ovs|br-|qbr|qvb|qvo|tap"
   # get devices list
   typeset DevList=$( ip link 2>/dev/null | awk -F':' '/^.*: / { print $2 }' | sort | grep -Ev "$ExcludeDev" )
   typeset DevInfo
   
   # loop on all device
   for Dev in $DevList; do
      Out=""; Proto=""; Slave=""
      IfCfg=$CfgPath$Dev
      
      # get nic state
      if IsNicUp $Dev; then
         State=UP 
         # check link state
         if CheckLink $Dev chut
            then State="$State(+)"
            else State="$State(-)"
         fi      
      else 
         State=DOWN; 
      fi
      
      # build output
      Out="$Dev: $State -"
      
      # check if slave of bond
      if IsSlave $Dev; then
         # get master bond
         bond=$( GetMaster $Dev )
         # dont need more info for slave, print and continue
         echo "$Out slave_${bond:-bond}"; continue
      fi
      
      # nic is up 
      if [[ $State =~ UP ]]; then
         # get ip addr
         Ip=$( ip addr show dev $Dev 2>/dev/null | awk '/^[ \t]+inet[ \t]+/ { print $2; exit}' )
         # state up but no ip, print and continue
         [[ -z $Ip ]] && echo "$Out none" && continue
      else
         # state down, get info from ifcfg
         if [ -e $IfCfg ]; then
            # get ip addr
            Ip=$( awk -F'=' '/^[ \t]*IPADDR=/ { print $2 }' $IfCfg | sed 's:"::g' )
            # get mask 
            Mask=$( awk -F'=' '/^[ \t]*NETMASK=/ { print $2 }' $IfCfg | sed 's:"::g' )
            # compute prefix
            if [[ -n $Ip && -n $Mask ]]; then
               PREFIX=""
               eval $(ipcalc -ps $Ip $Mask 2>/dev/null)
               Ip="$Ip/$PREFIX"
            fi
         else
            # no ifcfg file, print and continue
            echo "$Out not_configured"; continue
         fi
      fi
      
      # get proto
      Proto=$( GetProto $Dev )

      echo "$Out ${Ip:-none} (${Proto:-none})"
   done
}


###################
# Show result and exit
Exit()
{
   typeset -i RC=$1
   typeset red
   typeset green
   typeset reset

   # use color if stdout is a tty
   if [ -t 1 ]; then 
      red="\e[31m"
      green="\e[32m"
      reset="\e[0m"
   fi

   if (( $RC ))
      then echo -e "ERR: ${red}Failed!$reset log file: $LogFile"
      else echo -e "INF: ${green}Success!$reset"
   fi
   
   exit $RC
}


###################
# MAIN
#

   # Global Variables
   typeset LogDir="/usr/share/network-config/log" 
   typeset LogFile="$LogDir/network-config.log" 
   typeset CfgPath="/etc/sysconfig/network-scripts/ifcfg-"
   typeset DhcpHostname="\$HOSTNAME"
   typeset PeerDns="yes"
   typeset OnBoot="yes"
   typeset DnsList=""
   typeset BondMode=""
   typeset Devices=""
   typeset Hostname=""
   typeset Domain=""
   typeset Netmask=""
   typeset Gateway=""
   typeset EthOpt=""
   typeset IPAddress=""
   typeset -i OptionCreate=0
   typeset -i OptionDelete=0
   typeset -i OptionRestartNtwk
   typeset -i OptionList
   typeset -i UseDhcp
   typeset -i NbDev=0
   typeset -i NoRestart=0
   typeset -i ScriptRc=0
   typeset -i OptionAvailable=0

   # Check user
   if [[ $( whoami ) != root ]]; then
      echo "ERR: You must be root to run this program"
      exit 1
   fi
  
   # Verify script parameters
   CheckParam "$@"

   # create log folder
   mkdir -p $LogDir
   
   # print cmd in log file, except for list
   [[ $* != "-l" ||  $* != "-a" ]] && echo -e "\n--- Starting \"$(basename $0) "$*"\" on $(date -u):" >> $LogFile

   # check rh version 
   RH=$( lsb_release -rs ) || Exit 1
   if [[ ! $RH =~ ^6|^7 ]]; then 
      Print "ERR: Unsupported redhat version ($RH). Only support 6.x and 7.x"
      Exit 1
   fi
   
   # Verify ip syntax
   IsValidIp $IPAddress $Netmask $DnsList $Gateway || Exit 1 
   
   # Check Interface validity
   if [[ -n $Devices ]]; then
      IsValidDevice $Devices || Exit 1
      NbDev=$( echo $Devices | wc -w )
   fi
   
   # check bond mode
   if [[ -n $BondMode ]]; then 
      if [[ ! $BondMode =~ ^[0-6]$ ]]; then
         Print "ERR: Unsupported bond mode '$BondMode'"
         Exit 1
      fi
   fi
   
   # run operations 
   [[ -n $Hostname ]] && (SetHostname || ScriptRc=1)
   [[ -n $Domain   ]] && (SetDomain   || ScriptRc=1)
   [[ -n $DnsList  ]] && (SetDNS      || ScriptRc=1)
   [[ -n $Gateway  ]] && (SetGateway  || ScriptRc=1)
      
   # configure nic
   if (( $OptionCreate )); then
      # either create a single or a bond interface
      case $NbDev in
         1) CreateInterface $Devices || ScriptRc=1 ;;
         *) CreateBond      $Devices || ScriptRc=1 ;;
      esac
   fi
   
   # delete nic config
   if (( $OptionDelete )); then
      for Dev in $Devices; do
         DeleteOperation $Dev || ScriptRc=1
      done
   fi
   
   # restart network 
   if (( $OptionRestartNtwk )); then
      RestartNetwork || ScriptRc=1
   fi

   # list network 
   if (( $OptionList )); then
      ListNetwork #| column -t -o" "
      # exit without status
      exit 0
   fi

   # list available nics
   if (( $OptionAvailable )); then
      ListNic
      # exit without status
      exit 0
   fi
   Exit $ScriptRc
