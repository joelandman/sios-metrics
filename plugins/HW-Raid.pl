#!/usr/bin/perl

use strict;
my (@lines,$line,@fields,$field,@raids,$raid,$ctl,$state);
@raids	= `/opt/scalable/sbin/lsraid.pl`;
foreach $ctl (1 .. ($#raids + 1)) {
 chomp($line = `/opt/scalable/bin/cli64 ctrl=$ctl vsf info | grep jr`);
 $line =~ s/^\s+//g;
 @fields = split(/\s+/,$line);
 $state = -1; # defaults to failed
 $state =  1 if ($fields[6] =~ /Normal/);
 $state =  0 if ($fields[6] =~ /Degraded/);
 printf "controller_%i.%s.state:%s\n",$ctl,$fields[1],$state;
}
