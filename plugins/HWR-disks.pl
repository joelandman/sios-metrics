#!/opt/scalable/bin/perl

use SI::Utils;
use strict;
my (@lines,$line,@fields,$field,@raids,$raid,$ctl,$state,@cards,$card);
my ($size,$usage,$model,$slot,$binding,$drv,$free,$failed);
#  hardware raid disks 
@raids	= `/opt/scalable/sbin/lsraid.pl`;
foreach $ctl (1 .. ($#raids + 1)) {
 $card = `/opt/scalable/bin/cli64 ctrl=$ctl disk info | grep "SLOT "`;
 @lines = split(/\n/,$card);
 $free = 0 ; $failed = 0;
 foreach $line (@lines) {
 	$line =~ s/^\s+//g;
        #printf "line = %s\n",$line;
 	if ($line =~ /\s{0,}(\d+)\s+(\d+)\s+SLOT\s+(\d+)\s+(.*?)\s+(\d+\.{0,1}\d{0,}GB)\s+(\S+)/) {
 		$drv 	= $1;
		$slot	= $3;
		$model 	= $4;
		$size	= SI::Utils->size_to_bytes($5);
		$binding= $6;
		$binding= "none" if ($binding =~ /N.A./);
		$free++ 	if ($binding =~ /free/i);
		$failed++	if ($binding =~ /fail/i);
 		printf "raid.oem.areca.controller.%i.slot_%i.drv:%i\n",$ctl,$slot,$drv;
		printf "raid.oem.areca.controller.%i.slot_%i.size:%i\n",$ctl,$slot,$size;
		printf "raid.oem.areca.controller.%i.slot_%i.model:%i\n",$ctl,$slot,$model;
		printf "raid.oem.areca.controller.%i.slot_%i.binding:%i\n",$ctl,$slot,$binding;
 	}
 printf "raid.oem.areca.controller.%i.free:%i\n",$ctl,$free;
 printf "raid.oem.areca.controller.%i.failed:%i\n",$ctl,$failed;
 }
}
