#!/usr/bin/perl

use strict;
$|=1;

my ($rc,@f,@g,$i,$ndx,$out);

while (1) {
  $ndx = 0;
  printf "\n#### sync:%i\n",time;
  @f = split(/\n/,`cat /proc/cpuinfo`);
  $out = "cpu_clock ";
  foreach $i (@f) {
    if ($i =~ /cpu MHz\s+\:\s+(\d+\.\d+)/)
      {
        $out .= "," if ($ndx > 0);
        $out .= sprintf "f%i=%.1f",$ndx,$1;
        $ndx++;
      }
  }
  printf "%s\n",$out;
  sleep(5);
}

 
