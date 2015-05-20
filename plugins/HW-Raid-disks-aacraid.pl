#!/opt/scalable/bin/perl

use strict;
use SI::Utils;
use Data::Dumper;

my $aacraid;
my (@lines,$line,@fields,$field,@raids,$ctl,@state,@r,$k,$v,$kp,$d,@meta);
my ($slot,$enc,@m,$nonline,$nready,$nraw,$nfail,$nseq);

@raids	= `/opt/scalable/sbin/lsraid.pl --vendor=adaptec`;
foreach $ctl (1 .. ($#raids + 1)) {
 $line = `/opt/scalable/bin/arcconf GETCONFIG $ctl PD`;
 chomp(@r = split(/\n/,$line));
 $d=-1; # sentinel value
 foreach my $l (@r) {
 	$l =~ s/^\s+//g;
	$l =~ s/\s+$//g;
	next if ( ($l eq "") || ($l =~ /------/) || ($l !~ /(:|#)/) );
	# all fields in key : value format now with separators of Device\s#\d+
	if ($l =~ /Device\s+\#(\d+)/) { $d = $1; }
	# of course, can't just split these on ":" thanks to the choices
	# made by the application writers, so have to do more regex things
	if ($l =~ /^(.*?)\s\:\s(.*?)$/) {
	 $k = $1; $v = $2;
	}
	next if ($k =~ /Reported\sESD\(T\:L\)/);
	#($k,$v) = split(":",$l,2);
	$k =~ s/\.//g;
	$v =~ s/^\s+//;
	$v =~ s/Bytes//;
	if ($k =~ /Reported\sChannel\,Device\(T\:L\)/) {
		$v =~ s/\(.*?\)$//;
		@m = split(",",$v);
		$aacraid->{$ctl}->{$d}->{'enclosure'}=$m[0];
		$aacraid->{$ctl}->{$d}->{'slot'}=$m[1];
	   }
	elsif ( $k =~ /Transfer\sSpeed/) {
		@m = split(" ",$v,2);
		$aacraid->{$ctl}->{$d}->{'interface'}=$m[0];
		$aacraid->{$ctl}->{$d}->{'speed'}=$m[1];
	   }
	elsif ( $k =~ /Write\sCache/ ) {
		@m = split(" ",$v,2);
		$m[1] =~ s/(\(|\))//g;
		$aacraid->{$ctl}->{$d}->{'write_cache_state'} = $m[0];
		$aacraid->{$ctl}->{$d}->{'write_cache_mode'}  = $m[1];
	   }
	else {
		$aacraid->{$ctl}->{$d}->{$k}=$v;
	}
 }
}
#printf "Dump : %s\n",Dumper($aacraid);
#exit;

foreach $ctl (sort {$a <=> $b} keys %{$aacraid}) {
	$nseq = $nonline = $nready = $nraw = $nfail = 0;
	foreach $d (sort {$a <=> $b} keys %{$aacraid->{$ctl}}) {
		foreach $k (sort keys %{$aacraid->{$ctl}->{$d}}) {
			next if ( ($k =~ /Parity/) || ($k =~ /MaxCache/));
			$kp     = $k;
			$kp	=~ s/\s+$//g;
			$kp	=~ s/(\s+|-)/_/g;
		        if ($kp !~ /Size/i) {
				printf "raid.controller.%i.disk.%i.%s:%s\n",
					$ctl,$d,$kp,$aacraid->{$ctl}->{$d}->{$k};
				if ($kp =~ /State/) {
				 $nonline++   if ($aacraid->{$ctl}->{$d}->{$k} =~ /Online/);
				 $nready++    if ($aacraid->{$ctl}->{$d}->{$k} =~ /Ready/);
				 $nraw++      if ($aacraid->{$ctl}->{$d}->{$k} =~ /Raw/);
				 $nfail++     if ($aacraid->{$ctl}->{$d}->{$k} =~ /Fail/);	
				}
				if ($kp =~ /slot/) {
				 $nseq++      if ($aacraid->{$ctl}->{$d}->{$kp} != $d);
				}
			   }
		     	 else
		           {
				$aacraid->{$ctl}->{$k} =~ s/\s+//;
				# because, you know, KB -> KiB .... UNITS PEOPLE .... UNITS!!!
				$aacraid->{$ctl}->{$d}->{$k} =~ s/(.)B/$1iB/;
				printf "raid.controller.%i.disk.%i.%s:%s\n",
					$ctl,$d,$kp,SI::Utils->size_to_bytes($aacraid->{$ctl}->{$d}->{$k});
		       }
		}
	 
  	}
  	printf "raid.controller.%i.disks_online:%i\n"	,$ctl,$nonline;
	printf "raid.controller.%i.disks_ready:%i\n"	,$ctl,$nready;
	printf "raid.controller.%i.disks_raw:%i\n"	,$ctl,$nraw;	
	printf "raid.controller.%i.disks_failed:%i\n"	,$ctl,$nfail;	
	#printf "raid.controller.%i.out_of_sequence:%i\n",$ctl,$nseq;
}
