if [ $# -eq 0 ];
then
echo "usage: $0 [interface to delete] [interface(s) to use] [ip] [netmask] [netname] [all other option if any ( refers to Networking.sh script usage)]"
exit 0
fi
del=$1
shift
cre=$1
shift
ip=$1
shift
mask=$1
shift
name=$1
shift
alloptions=$@

netcmd="nohup /soft/nsesoft/nse1/PlatformCustomization/current/bin/Networking.sh"

#go for it!!!!

echo "$netcmd -d $del && $netcmd -c '$cre' -i $ip -m $mask -n $name $alloptions"
