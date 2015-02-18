#!/usr/bin/perl

use strict;
my (@lines,$line,@fields,$field);

@lines= split(/\n/,`fhgfs-ctl --serverstats --history=1 | tail -2`);
foreach $line (@lines) {
 chomp($line);
 next if ($line eq "");
 $line =~ s/^\s+//g;
 @fields = split(/\s+/,$line);
 if (@fields) {
   printf "write_MBps:%.3f\n",$fields[1]/1000.0;
   printf "read_MBps:%.3f\n",$fields[2]/1000.0;
   printf "requests:%i\n",$fields[3];
   printf "qlen:%i\n",$fields[4];
   printf "busy:%i\n",$fields[5];
 }
}
