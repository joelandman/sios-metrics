#!/usr/bin/perl
use strict;
$|=1;

my ($fh,$line,@la,@l);
my $cpu;
@l = split(/\n/,`/usr/bin/lscpu`);
foreach my $_l (@l) {
  if ($_l =~ /^CPU\(s\):\s+(\d+)/ ) {
    $cpu = $1;
    last;
  }
}

while (1) {
   sleep 1;
   printf "\n#### sync:%i\n",time;
   sysopen $fh,"/proc/loadavg","O_RDONLY | O_BINARY" || die "FATAL ERROR: unable to open loadavg file\n";
   $line =<$fh>;
   @la = split(/\s+/,$line);
   if ($cpu) {
      printf "load,cpu=%i load1m=%.2f,load5m=%.2f,load15m=%.2f,frac_load1m=%.4f,frac_load5m=%.4f,frac_load15m=%.4f\n",
        $cpu,$la[0],$la[1],$la[2],$la[0]/$cpu,$la[1]/$cpu,$la[2]/$cpu;
    }
    else
    {
      printf "load  load1m=%.2f,load5m=%.2f,load15m=%.2f\n",
        $la[0],$la[1],$la[2];
    }
}
