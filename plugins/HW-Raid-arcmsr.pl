#!/usr/bin/perl

use strict;
use SI::Utils;
$|=1;
my (@lines,$line,@fields,$field,@raids,$raid,$ctl,$state,@r,$rl,$lun);
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
  $rl = $fields[3];
  $rl =~ s/Raid//ig;
  $lun = $fields[1];
 	printf "raid,type=hardware,driver=arcmsr,controller=%i,lun=%i name=\"%s\",level=%s,size=%i,normal=%s,degraded=%s,failed=%s\n",
    $ctl,
    $lun,
    $fields[1],
    $rl,
    SI::Utils->size_to_bytes($fields[4]),
    ($fields[6] =~ /Normal/i ? "T" : "F"),
    ($fields[6] =~ /Degraded/i ? "T" : "F"),
    ($fields[6] =~ /Failed/i ? "T" : "F"),
    ;
 }
}
