#!/usr/bin/perl
#
#
# This script call a REST api on demand to update image list in database
# It's part of provisioning script
# The direct ssh call is deprecated.

# 2014 @A. cristalli
#
#
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
my $f;
my $images;
my @images;
my $image;
my $uname;
my $results;
my $username = 'admin';
my $password = '2elleChap4';
my $uri = "http://x.x.x.204/SPOT/provisioning/api/provisioningimages";
my $list_uri = "http://x.x.x.204/SPOT/provisioning/api/provisioningimageses";
my $req = HTTP::Request->new( 'POST', $uri );
$req->header( 'Content-Type' => 'application/json' );
# set custom HTTP request header fields
#This is the directory where linux images reside
my $lwp = LWP::UserAgent->new;
my $lysis = "/lysis";
my $resp;
my $clonezilla = "/home/partimag";
my $MDT = $clonezilla."/MDT/Control/";
my $Generic = "/var/www";
# check the platform where we run

$uname = `uname`;
my $imageData;
my $system = $uname->stdout;
chomp($system);

switch ($system) {
	case 'AIX'
	{
		# First get all the images and delete them to update with new information

                my $list_def = $list_uri.'?imagetarget=1';
                my $req_get= HTTP::Request->new( 'GET', $list_def);
                $req_get->authorization_basic('admin' => '2elleChap4');
#print $req_get->as_string();
                my $get = LWP::UserAgent->new(
                                requests_redirectable => [],
                                timeout               => 10,
                                agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:12.0)
                                Gecko/20100101 Firefox/12.0"
                                );

                my $datas = $get->request($req_get);
                my $decoded = decode_json($datas->content);
                foreach my $dec (@{ $decoded->{rows} })
                {
#               print Dumper $decoded;
#               print $dec->{imagename};
# Delete all images record and insert after the new ones
                        my $id = $dec->{imagename};
                        my $req_delete =  HTTP::Request->new( 'DELETE', $uri . '/' . $id);
#                       $req_delete->authorization_basic('admin' => '2elleChap4');
                        my $delete = LWP::UserAgent->new(
                                        requests_redirectable => [],
                                        timeout               => 10,
                                        agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:12.0)
                                        Gecko/20100101 Firefox/12.0"
                                        );
                        $resp = $delete->request($req_delete);
                         if ($resp->is_success) {

                                print "\nSuccess on deleting:" .$resp->decoded_content;  # or whatever
                        }
                        else {
                                print  "\nFailed on deleting:" .$resp->status_line;
                        }
#                       print Dumper $resp;

                }

		my $cmd = "/usr/sbin/lsnim -t mksysb | awk '{print \$1}";
		$results = `$cmd`;
#insert installation media type
		@images = split('\n', $results->stdout);
		foreach $image(@images)
		{
			$imageData = '{"imagetarget" : "1", "ostarget" : "NIM : AIX", "imagename" : "'.$image.'"}';
			$req->content($imageData);
			$resp = $lwp->request($req);
		}
	}

	case 'Linux'
	{
# First get all the images and delete them to update with new information

		my $list_def = $list_uri.'?imagetarget=2';
		my $req_get= HTTP::Request->new( 'GET', $list_def);
		$req_get->authorization_basic('admin' => '2elleChap4');
#print $req_get->as_string();
		my $get = LWP::UserAgent->new(
				requests_redirectable => [],
				timeout               => 10,
				agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:12.0) 
				Gecko/20100101 Firefox/12.0"
				);

		my $datas = $get->request($req_get);
		my $decoded = decode_json($datas->content);
		foreach my $dec (@{ $decoded->{rows} })
		{
#		print Dumper $decoded;
#		print $dec->{imagename};
# Delete all images record and insert after the new ones
			my $id = $dec->{imagename};
			my $req_delete =  HTTP::Request->new( 'DELETE', $uri . '/' . $id);
#			$req_delete->authorization_basic('admin' => '2elleChap4');
			my $delete = LWP::UserAgent->new(
					requests_redirectable => [],
					timeout               => 10,
					agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:12.0)
					Gecko/20100101 Firefox/12.0"
					);
			$resp = $delete->request($req_delete);
			 if ($resp->is_success) {

                                print "\nSuccess on deleting:" .$resp->decoded_content;  # or whatever
                        }
                        else {
                                print  "\nFailed on deleting:" .$resp->status_line;
                        }
#			print Dumper $resp;

		}
#	print Dumper  $decoded. $list_uri;
		opendir (DIR, $lysis) or die $!;
		while (my $file = readdir(DIR)) {
# Use a regular expression to ignore files beginning with a period
			next if ($file =~ m/^\./);
# We only want files
			next unless (-f "$lysis/$file");
# Use a regular expression to find files ending in .iso
			next unless ($file =~ m/\.iso$/);

			$imageData = '{"imagetarget" : "2", "ostarget" : "MONDORESTORE : LINUX", "imagename" : "'.$file.'"}';
			$req->content($imageData);
			$resp = $lwp->request($req);
			if ($resp->is_success) {

				print "\nSuccess on inserting:" . $resp->decoded_content;  # or whatever
			}
			else {
				print  "\nFailed on inserting:" .  $resp->status_line;
			}


		}

		closedir (DIR);
		
		opendir (DIR, $Generic) or die $!;
                while (my $file = readdir(DIR)) {
		# Use a regular expression to ignore files beginning with a period
                        next if ($file =~ m/^\./);
			# We only want dir
                        next unless (-d "$Generic/$file");
			next unless ($file =~ m/\.iso$/);
			$imageData = '{"imagetarget" : "2", "ostarget" : "GENERIC : LINUX", "imagename" : "'.$file.'"}';
			$req->content($imageData);
                        $resp = $lwp->request($req);
                        if ($resp->is_success) {

                                print "\nSuccess on inserting:" . $resp->decoded_content;  # or whatever
                        }
                        else {
                                print  "\nFailed on inserting:" .  $resp->status_line;
                        }


		}


                closedir(DIR);

		opendir (DIR, $clonezilla) or die $!;
                while (my $file = readdir(DIR)) {
# Use a regular expression to ignore files beginning with a period
                        next if ($file =~ m/^\./);
# We only want dir
                        next unless (-d "$clonezilla/$file");
			next unless ( -f "$clonezilla/$file/disk");
			next unless ($file =~ "MGT");
			$imageData = '{"imagetarget" : "2", "ostarget" : "CLONEZILLA : WINDOWS", "imagename" : "'.$file.'"}';
                        $req->content($imageData);
                        $resp = $lwp->request($req);
                        if ($resp->is_success) {

                                print "\nSuccess on inserting:" . $resp->decoded_content;  # or whatever
                        }
                        else {
                                print  "\nFailed on inserting:" .  $resp->status_line;
                        }


                }


		closedir(DIR);
		
		opendir (DIR, $MDT) or die $!;
                while (my $file = readdir(DIR)) {
# Use a regular expression to ignore files beginning with a period
                        next if ($file =~ m/^\./);
# We only want dir
                        next unless (-d "$MDT/$file");
			next unless ($file =~ "DEPLOY");
                   #     next unless ($file =~ m/\disk$/);
                        $imageData = '{"imagetarget" : "2", "ostarget" : "MDT : WINDOWS", "imagename" : "'.$file.'"}';
                        $req->content($imageData);
                        $resp = $lwp->request($req);
                        if ($resp->is_success) {

                                print "\nSuccess on inserting:" . $resp->decoded_content;  # or whatever
                        }
                        else {
                                print  "\nFailed on inserting:" .  $resp->status_line;
                        }


                }


                closedir(DIR);

	}

}


#print Dumper $resp;
