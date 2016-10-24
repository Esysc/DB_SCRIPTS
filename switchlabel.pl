#!/usr/bin/perl
# switchLabel.pl - 5/10/2011 (dirty 30 minute hack version)
# label ports on an HP Procurve switch with their boxes MAC address (easy to lookup)
# and even their hostnames! --nick@fmpub.net
 
# configs
$debugMode = 1;
 
# code dont touch
if ( $#ARGV < 1 ) {
       print "usage: switchLabel.pl [switch IP/hostname] [community]\n";
       die("Please specify a switch IP and a valid r/w community string!\n");
} 
 
sub debug
{
        use vars qw($debugMode);
        if ($debugMode == 1) {
                print $_[0];
        }
}
 
my $switchIP = $ARGV[0];
my $snmpCommunity = $ARGV[1];
 
my $numPorts = 48; # after this is trunks and vlans, which we're going to ignore
                                  # label them manually kthx
                                  # change me for big chassis switches
                                  # could become another (optional) config variable
 
my @snmpWalk = `snmpwalk -On -c $snmpCommunity -v2c $switchIP 1.3.6.1.2.1.17.4.3.1.2`;
my %switchPorts = ();
 
foreach (@snmpWalk) {
 	$_ =~ s/.1.3.6.1.2.1.17.4.3.1.2.//; # lazy ass formating
	$_ =~ s/ = INTEGER: / /;
	chomp;
	($decMac, $port) = split(/ /, $_);
	if ($port <= $numPorts && $port > 0) {
		my @macOctets = split(/\./, $decMac);
		my $hexMac = "";
		foreach (@macOctets) {
			$_ = sprintf("%0.2X", $_);
		}
		$hexMac = join(':', @macOctets);
		debug("[found] $hexMac @ $switchIP: port $port\n");
 
		# put code in here to map MACs back to boxnames
		# or leave a MAC for now...
		my $machineName = $hexMac;
 
		if (!$switchPorts{$port}) {
			$switchPorts{$port} = $machineName;
		} else {
			$switchPorts{$port} .= ", " . $machineName;
		}
	}
}
 
for ($i = 1; $i <= $numPorts; $i++) {
	if ($switchPorts{$i}) {
		my $portName = $switchPorts{$i};
		if (length($portName) > 64) {
			$portName = substr($portName, 0, 61) . "...";
		}
		print $i  $portName;
                 #the above line was broken in half for awful wordpress formatting
	}
}


my @snmpWalk = `snmpwalk -On -c $snmpCommunity -v2c $switchIP 1.3.6.1.4.1.11.2.3.7.11.17.7.1.1`;
my %switchPorts = ();

foreach (@snmpWalk) {
        $_ =~ s/1.3.6.1.4.1.11.2.3.7.11.17.7.1.1.//; # lazy ass formating
        $_ =~ s/ = INTEGER: / /;
        chomp;
        ($decMac, $port) = split(/ /, $_);
        if ($port <= $numPorts && $port > 0) {
                my @macOctets = split(/\./, $decMac);
                my $hexMac = "";
                foreach (@macOctets) {
                        $_ = sprintf("%0.2X", $_);
                }
                $hexMac = join(':', @macOctets);
                debug("[found] $hexMac @ $switchIP: port $port\n");

                # put code in here to map MACs back to boxnames
                # or leave a MAC for now...
                my $machineName = $hexMac;

                if (!$switchPorts{$port}) {
                        $switchPorts{$port} = $machineName;
                } else {
                        $switchPorts{$port} .= ", " . $machineName;
                }
        }
}






for ($i = 1; $i <= $numPorts; $i++) {
        if ($switchPorts{$i}) {
                my $portName = $switchPorts{$i};
                if (length($portName) > 64) {
                        $portName = substr($portName, 0, 61) . "...";
                }
                print $i  $portName;
                 #the above line was broken in half for awful wordpress formatting
        }
}

