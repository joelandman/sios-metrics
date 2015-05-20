#!/usr/bin/perl
use strict;
my ($fh,$line,@la);
while (1) {
   sleep 1;
   printf "\n#### sync:%i\n",time;
   sysopen $fh,"/proc/loadavg","O_RDONLY" || die "FATAL ERROR: unable to open loadavg file\n";
   $line =<$fh>;
   @la = split(/\s+/,$line);
   printf "system.load.1m:%f\nsystem.load.5m:%f\nsystem.load.15m:%f\n",$la[0],$la[1],$la[2];
}
