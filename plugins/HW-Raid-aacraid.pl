#!/opt/scalable/bin/perl

use strict;
use SI::Utils;
my $aacraid;
my (@lines,$line,@fields,$field,@raids,$ctl,@state,@r,$k,$v,$kp,$d,@meta);
my ($slot,$enc);

@raids	= `/opt/scalable/sbin/lsraid.pl --vendor=adaptec`;
foreach $ctl (1 .. ($#raids + 1)) {
 $line = `/opt/scalable/bin/arcconf GETCONFIG $ctl LD`;
 chomp(@r = split(/\n/,$line));
 foreach my $l (@r) {
 	$l =~ s/^\s+//g;
	$l =~ s/\s+$//g;
	next if ( ($l eq "") || ($l =~ /------/) || ($l !~ /:/) );
	# all fields in key : value format now
	($k,$v) = split(":",$l,2);
	$v =~ s/^\s+//;
	$v =~ s/Bytes//;
	if ($k =~ /RAID level/) {
		$v	=~ s/^(.*?)\s+(.*)/$1/;
	}
	$aacraid->{$ctl}->{$k}=$v;
 }
}
foreach $ctl (sort {$a <=> $b} keys %{$aacraid}) {
	foreach $k (sort keys %{$aacraid->{$ctl}}) {
		next if ( ($k =~ /Parity/) || ($k =~ /MaxCache/));
		
		$kp     = $k;
		$kp	=~ s/\s+$//g;
		$kp	=~ s/Status of logical device/status/;
		$kp	=~ s/(\s+|-)/_/g;
		
		if ($kp !~ /Segment/) {
		   if ($kp !~ /Size/i) {
			printf "raid.controller.%i.%s:%s\n",$ctl,$kp,$aacraid->{$ctl}->{$k};
			}
		     else
		       {
			$aacraid->{$ctl}->{$k} =~ s/\s+//;
			# because, you know, KB -> KiB .... UNITS PEOPLE .... UNITS!!!
			$aacraid->{$ctl}->{$k} =~ s/(.)B/$1iB/;
			printf "raid.controller.%i.%s:%s\n",$ctl,$kp,SI::Utils->size_to_bytes($aacraid->{$ctl}->{$k});
		       }
		  } 
 		 else
		  {
			@state	= split(/\s+/,$aacraid->{$ctl}->{$k});
			if ($state[1] =~ /Enclosure:(\d+)/) { $enc = $1; }
			if ($state[1] =~ /Slot:(\d+)/) { $slot = $1; }
			printf "raid.controller.%i.enclosure.%i.disk.%i.serial_number:%s\n",
				$ctl,$enc,$slot,$state[2];
		        printf "raid.controller.%i.enclosure.%i.disk.%i.state:%s\n",
                                $ctl,$enc,$slot,$state[0];			
		  }
		
		
 }
}
