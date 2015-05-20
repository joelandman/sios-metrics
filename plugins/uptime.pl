#!/usr/bin/perl

use strict;
my ($rc,$u,$n);

chomp($rc = `cat /proc/uptime`);
if ($rc =~ /(\d+\.\d+)\s+(\d+\.\d+)/) {
   printf "system.uptime:%.2f\n",$1;
}
