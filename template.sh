#!/usr/bin/ksh
#title          :nimWrapper
#description    :Boot a POWER server and configure SMS to boot from network.
#               Start server nim to install nim client
#               Require serial cyclades connection.
#author         :ACS
#date           :20160303
#version        :2.3
#usage          :./nimWrapper
#notes          :
#ksh_version    :Version M-11/16/88f
#============================================================================

#@(#)------------------------------------------------------
#@(#) General Information
#@(#)   Name      : nimWrapper
#@(#)   Purpose   : Aim to manage nim jobs
#@(#)   Version   : 2.3
#@(#)   Author    : A. Cristalli
#@(#)------------------------------------------------------
#@(#) Usage
#@(#)   Basic usage to restore a mksysb:
#@(#)     nimWrapper  -a [aixtz] -c [nimclient] -i [image name]
#@(#)
#@(#)   Check if a nim client exists and is connected to serial console:
#@(#)     nimWrapper -c [nimclient]
#@(#)
#@(#)   Boot in maintenance or diag mode:
#@(#)     nimWrapper -c nimclient -i [diag|maint_boot] -spot [spot name]|[if empty return a list of spots]
#@(#)
#@(#)
#@(#)   Complete example of usage
#@(#)     nimWrapper -a [aixtz] -c [nimclient] -d [disksize(GB)] -g [default gateway] -h [hostname] -i [image name] -ip [ip address] -m [mirror:0|1] -n [netmask] -p [paging size] -s [sales order number] -boot [normal|factory]  -nocheck (for VMs or delayed tasks)

#@(#)
#@(#)
#@(#)------------------------------------------------------
#@(#) Parameters
#@(#)   -a        : Define the time zone to apply (POSIX)
#@(#)   -c        : Define the nim client hostname
#@(#)   -d        : Define the disk (rootvg) capacity (GB)              (optional)
#@(#)   -g        : Define the gateway to apply                         (optional)
#@(#)   -h        : Define the hostname to apply                        (optional)
#@(#)   -i        : Set the mksysb image to use
#@(#)   -ip       : Define the final ip to set                          (optional)
#@(#)   -m        : Decide if mirror rootvg or not 0->not 1-> yes       (optional)      default "do nothing"
#@(#)   -n        : Define  the netmask to apply                        (optional)
#@(#)   -p        : Define the paging size to apply (GB)                (optional)
#@(#)   -s        : Set the sales order this client belong to           (optional)
#@(#)   -boot     : Auto Poweron SMS config normal/factory              (optional)      default "do nothing"
#@(#)   -nocheck  : Check if the nim client is exists andconnected      (optional)      default "do nothing"
#@(#)   -H        : Display this help
#@(#)   -x        : Debug Mode
#@(#)------------------------------------------------------
#@(#) Exit Codes
#@(#)  255        : Syntax Error
#@(#)    0        : Succeed
#@(#)    1        : Failed
#@(#)------------------------------------------------------

typeset PROGNAME=${0##*/}
typeset VERSION="0.1"

typeset APISERVER="spmgt.my.comp.ltd"
typeset EXPECT="/usr/bin/expect"
typeset LSNIM=$(which lsnim)
typeset expectserver="spmgt.my.comp.ltd"
typeset hostsFile="$(cat /data/backup/hosts)"
typeset ID=$(echo $PROGNAME | awk -F "_" '{print $3}')
export ID
export TERM=vt100

#Log function


log() {
 level=${1?}
 shift
 line="[$(date '+%F %T')] $level: $*"
 if [ -t 2 ]
 then
        case "$level" in
                INFO) code=32 ;;
                DEBUG) code=35 ;;
                WARN) code=33 ;;
                ERROR) code=31 ;;
                *) code=0 ;;
        esac
        echo "\033[${code}m${line}\033[0m"
 else
        echo "$line"
 fi >&2



#LOG to web services


 if [[ "$ID" == "" ]]; then
    REST='{"title":"'"$PROGNAME"'","content":"'$line'","userid":"'$(whoami)'","date":"'$(date)'"}'
    URI="http://$APISERVER/SPOT/provisioning/api/events"
    METHOD="POST"
  else
    REST='{"returnstdout" : "|'"$nimclient"'| '"$line"'"}'
    URI="http://$APISERVER/SPOT/provisioning/api/logWrapper/$ID"
    METHOD="POST"
    COMMANDURI="<button class='btn btn-mini command' url='/SPOT/provisioning/api/remotecommands/$ID'>Details..</button> "

 fi
    line="$line<p>$COMMANDURI</p>"

 (
perl - "$URI" "$REST"  "$METHOD" <<'_HERE_'
use integer;
use POSIX qw(strftime);
use Backticks;
use Data::Dumper;
use Sys::Hostname;
use Socket;
use LWP::UserAgent;
use LWP::Simple;
use strict;
use warnings;
use integer;
use Switch;
use JSON ;
use feature qw(switch);
use HTTP::Cookies;
use HTTP::Request;
use LWP;
use File::Path qw{mkpath};
my $uri = shift;
my $REST = shift;
my $METHOD = shift;
my $lwp = LWP::UserAgent->new(
                        timeout               => 10,
);
my $req = HTTP::Request->new( "$METHOD", "$uri" );
$req->content($REST);
my $resp = $lwp->request($req);
print $req->as_string;
#print Dumper $resp;
_HERE_
  )  >/dev/null 2>&1


if [[ ! -z $salesOrder && ! -z $nimclient ]]; then
PK="["$salesOrder"]["$nimclient"]"
URI="http://$APISERVER/SPOT/provisioning/api/provisioningnotifications/$PK"
        REST="{
        \"notifid\":\"$PK\",
        \"hostname\":\"$hostname\",
        \"installationip\":\"$INSTALLATIONIP\",
        \"configuredip\":\"$ipaddress\",
        \"status\":\"<b>$line</b>\",
        \"progress\":\"$PROGRESS\",
        \"image\":\"$image\",
        \"firmware\":\"IBM OpenFirmware\",
        \"ram\":\"N/D\",
        \"cpu\":\"N/D\",
        \"diskscount\":\"N/D\",
        \"netintcount\":\"N/D\",
        \"model\":\"N/D\",
        \"serial\":\"N/D\",
        \"os\":\"$SPOT\"
        }"

        # Write monitoring infos to web service
SEND >/dev/null 2>&1

fi

}

SEND () {


perl -e '
use integer;
use POSIX qw(strftime);
use Data::Dumper;
use Socket;
use LWP::UserAgent;
use LWP::Simple;
use strict;
use warnings;
use integer;
use Switch;
use HTTP::Cookies;
use HTTP::Request;
use LWP;
my $REST = shift;
my $uri = shift;
my $lwp = LWP::UserAgent->new(
                        timeout               => 10,
);
my $req = HTTP::Request->new( "PUT", "$uri" );
$req->content($REST);
my $resp = $lwp->request($req);
print $req->as_string;
#print Dumper $resp;
exit;
' "$REST" "$URI"


}

CheckParam() {

   Help() {
     log WARN "$(echo $1:; grep "^#@(#)" $1 | sed "s/#@(#)/  /g")"
   }

   Error() {
      Help $0; exit $1
   }
 [ $# -eq 0 ] && Error 255
 while [ $# -gt 0 ] ; do
    case "$1" in
        -a )
          aixtz="$2" # You may want to check validity of $2
          shift 2
          ;;
        -c )
          nimclient="$2"   # You may want to check validity of $2
          shift 2
          ;;
        -d )
          disk="$2" # You may want to check validity of $2
          shift 2
          ;;
        -g )
          gateway="$2"   # You may want to check validity of $2
          shift 2
          ;;
        -h )
          hostname="$2"   # You may want to check validity of $2
          shift 2
          ;;
        -i )
          image="$2"
          shift 2
          ;;
        -ip )
          ipaddress="$2"
          shift 2
          ;;
        -m )
          mirror="$2"
          shift 2
          ;;
        -n )
          netmask="$2" # You may want to check validity of $2
          shift 2
          ;;
        -p )
          paging="$2" # You may want to check validity of $2
          shift 2
          ;;
        -s )
          salesOrder="$2" # You may want to check validity of $2
          shift 2
          ;;
        -boot )
          bootClient=$2
          shift 2
          ;;
        -nocheck )
          nocheck=1
          shift 1
          ;;
        -spot )
          spot=$2
          shift 2
          ;;
        -x )
          set -x
          shift 1
          ;;
        -H )
          Error 0
          shift 1
          ;;
        *) Error 255 ;;
          esac
 done
 [ $# -ne 0 ] && Error 255
 ([[ -z $aixtz$disk$gateway$hostname$image$ipaddress$mirror$netmask$paging$salesOrder$bootClient$spot ]] && [[ ! -z $nimclient ]] ) && getEnv && checkRack && exit $RET
 [[ ! -z $spot ]] && bootSpecial && exit $RET

}


# Verify script parameters
   CheckParam "$@"



# Base library  for all scripts
# This is an example taken from nimwrapper, please chenge it
