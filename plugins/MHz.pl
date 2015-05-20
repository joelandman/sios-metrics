#!/usr/bin/perl

use strict;
my ($rc,@f,$i);

chomp($rc = `cat /proc/cpuinfo | grep MHz | cut -d":" -f2`);
@f = split(/\n/,$rc);
foreach $i (0 ..$#f) {
 $f[$i] =~ s/^\s+//; # trim leading spaces
 printf "system.cpu.frequency.processor.%i:%s\n",$i,$f[$i];
}
