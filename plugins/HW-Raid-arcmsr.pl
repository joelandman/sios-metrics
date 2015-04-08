#!/usr/bin/perl

use strict;
my (@lines,$line,@fields,$field,@raids,$raid,$ctl,$state,@r);
@raids	= `/opt/scalable/sbin/lsraid.pl --vendor=areca`;
foreach $ctl (1 .. ($#raids + 1)) {
 $line = `/opt/scalable/bin/cli64 ctrl=$ctl vsf info`;
 chomp(@r = split(/\n/,$line));
 foreach my $l (@r) {
 	$l =~ s/^\s+//g;
 	next if ($l =~ /======/);
 	next if ($l =~ /Ch\/Id\/Lun/);
	next if ($l =~ /GuiErrMsg/i);
 	@fields = split(/\s+/,$l);
#	printf "f: %s\n",join(",",@fields);
 	$state = -1; # defaults to failed
 	$state =  1 if ($fields[6] =~ /Normal/i);
 	$state =  0 if ($fields[6] =~ /Degraded/);
 	printf "controller_%i.%s.state:%s\n",$ctl,$fields[1],$state;
 }
}
