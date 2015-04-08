#!/opt/scalable/bin/perl

use SI::Utils;
use strict;
my (@lines,$line,@fields,$field,@raids,$raid,$ctl,$state,@cards,$card);
my ($size,$usage,$model,$slot,$binding,$drv,$free,$failed,$state);
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
		printf "controller_%i.drv_%i.size:%i\n",$ctl,$drv,$size;
		printf "controller_%i.drv_%i.slot:%i\n",$ctl,$drv,$slot;
		printf "controller_%i.drv_%i.model:%i\n",$ctl,$drv,$model;
		printf "controller_%i.drv_%i.state:%s\n",$ctl,$drv,$binding;
 	}
 }
 printf "controller_%i.free:%i\n",$ctl,$free;
 printf "controller_%i.failed:%i\n",$ctl,$failed;
}
