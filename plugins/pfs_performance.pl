#!/opt/scalable/bin/perl

use strict;
use IPC::Run qw(harness);
use Time::HiRes qw(usleep);
my (@lines,$line,@fields,$field);
my (@cmd,$in,$out,$err,$h);
use IO::Handle;
STDERR->autoflush(1);
STDOUT->autoflush(1);
$|=1;

@cmd 	= split(/\s/,'beegfs-ctl --serverstats --history=1 --interval=1');
$in 	= "";
$out	= "";
$err	= "";

$h = harness \@cmd, \$in, \$out, \$err;
$h->start;

while ($h->pumpable) {
 $h->pump_nb;
 if (length($out) == 0) {
  usleep(250000); # sleep for 1/4 second (250000 microseconds) and then loop
  next;
 }
 
 chomp(@lines = split(/\n/,$out));
 $out = "";
 #foreach $line (reverse @lines) {
 # next if ($line eq "");
 # printf "line=%s\n",$line;
 #}
 $line = pop @lines;
 $line =~ s/^\s+//g;
 @fields = split(/\s+/,$line);
 printf "\n#### sync:%i\n",time;
  if (@fields) {
   printf "pfs write_bw=%.3f,read_bw=%.3f,reqs=%i,qlen=%i,busy=%i\n",$fields[1]*1000.0,$fields[2]*1000.0,$fields[3],$fields[4],$fields[5];
  }
}
$h->finish;
usleep(2000000); # sleep for 2 seconds, then issue a kill and clean up
$h->kill_kill;
usleep(2000000);
undef $h;
