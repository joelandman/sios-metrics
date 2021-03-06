#!/opt/scalable/bin/perl

# Copyright (c) 2002-2015 Scalable Informatics


use strict;
$|=1;
use IO::Dir;
use SI::Utils;
use Time::HiRes qw(usleep);
use Data::Dumper;

#
my $vers    = "1.5";

# variables
my ($opt,$rc,$version,$thr);
my $debug 			;
my $verbose			;
my $help            ;
my $dir				;
my $system_interval	;
my $block_interval	;
my $done			;
my $timestamp   	;

my ($net,$fh,@devs,$i,@proc,$line,$total,$lower,@dev);
my ($dev_last,$dev_current,$dev_delta,@_tmp,$path,$bldfh,$iopfh,$read,$write);
my ($riop,$wiop,$major,$minor,@vals,$ts,$upper,$tbw,$trbw,$twbw,$triops);
my ($twiops,$tiops,$driver,$firmware,$speed,$carrier,$fn,@_all,$c);
my $wrap		= 2**32;
my $MB			= 1024*1024;
my $interval		= 1;
my ($reads,$writes,$r_iops,$w_iops,$npts,$max_saved_data,$bwf,@stamp);
my ($tiop,$count,$firstpass,@hbwr,@hbww,$out,$ndx);
my @fields = qw(device rx_bytes rx_packets rx_errs rx_drop rx_fifo 
			   rx_frame rx_compressed rx_multicast
			   tx_bytes tx_packets tx_errs tx_drop 
			   tx_fifo tx_collisions tx_carrier_drops
			   tx_compressed
			   );

$firstpass = true; 
undef $dev_last;
do
{    
	sysopen $bldfh,"/proc/net/dev","O_RDONLY" or next;
	sysread $bldfh,$line,1024*1024 or next; # grab 1MB of /proc/net/dev data (never that large)
	close($bldfh);
	@proc 	= split(/\n/,$line);
	$ts	= time;
	$tbw = $trbw = $twbw = $tiops = $triops = $twiops = 0;
	for($i=2; $i<=$#proc;$i++)
	  {
	  	$proc[$i] =~ s/^\s+|\s+$//; # trim leading ...   and trailing spaces
		$proc[$i] =~ s/://;    # remove colons
		@dev      = split(/\s+/,$proc[$i]); # split on spaces
		# structure of each line is
		# device, rx_bytes, rx_packets, rx_errs, rx_drop, rx_fifo, rx_frame, rx_compressed, rx_multicast,
		#         tx_bytes, tx_packets, tx_errs, tx_drop, tx_fifo, tx_collisions, tx_carrier_drops , tx_compressed
	  	for(my $fidx=1;$fidx <= $#fields; $fidx++)
	  		{
	  			$dev_current->{$dev[0]}->{$fields[$fidx]} = $dev[$fidx];
	  		}
	  	if ($firstpass)
	  		{
	  			for(my $fidx=1;$fidx <= $#fields; $fidx++)
			  		{
			  			$dev_last->{$dev[0]}->{$fields[$fidx]} = $dev[$fidx];
			  			$dev_delta->{$dev[0]}->{$fields[$fidx]} = 0;
			  		} 
	  		}	
	  	  else
	  	    {
	  	    	for(my $fidx=1;$fidx <= $#fields; $fidx++)
				   {				    
		    		$dev_last->{$dev[0]}->{$fields[$fidx]} -= $wrap 
		    			if (
		    				$dev_current->{$dev[0]}->{$fields[$fidx]} < 
		    				$dev_last->{$dev[0]}->{$fields[$fidx]}
		    			   ); # Handle 32 bit number wraps

		    		$dev_delta->{$dev[0]}->{$fields[$fidx]} =
		    			$dev_current->{$dev[0]}->{$fields[$fidx]} -
		    			$dev_last->{$dev[0]}->{$fields[$fidx]} ;
				   
				    $dev_last->{$dev[0]}->{$fields[$fidx]} = 
				    	$dev_current->{$dev[0]}->{$fields[$fidx]} ;
				   }
	  	    }
	  	
	 }

 	if (!$firstpass) {	
		printf "\n#### sync:%i\n",time;
		foreach my $k (sort keys %{$dev_delta})
			{
		           $c     = &_get_contents(sprintf '/sys/class/net/%s/carrier',$k);
			   $speed = &_get_contents(sprintf '/sys/class/net/%s/speed',$k);
			   $out = sprintf "network,interface=%s",$k;
			   $out .= sprintf " carrier=%s",($c == 1 ? "T" : "F");
			 
			   $out .= sprintf ",speed=%i,",($speed > 0 ? $speed*1000000 : 0);
			   $ndx = 0;
			   foreach my $f (@fields) {
				 next if ($f =~ /device/);
				 $out .= "," if ($ndx > 0);
				 $out .= sprintf "%s=%s",$f,$dev_delta->{$k}->{$f};
				 $ndx++;
			   }
			   $out .= (sprintf ",rx_ave_bytes_per_packet=%.1f",
				    $dev_delta->{$k}->{rx_bytes}/$dev_delta->{$k}->{rx_packets})
					if ($dev_delta->{$k}->{rx_packets} > 0);  
			   $out .= (sprintf ",tx_ave_bytes_per_packet=%.1f",
				    $dev_delta->{$k}->{tx_bytes}/$dev_delta->{$k}->{tx_packets})
					if ($dev_delta->{$k}->{tx_packets} > 0);		
			   
			   printf "%s\n",$out;
			}
		print "\n\n";
	  }
	
	$firstpass = false;

	sleep(1); 
} until ($done);


sub _get_contents {
    my $fname = shift;
    my ($data,$read,$ifh);
    sysopen($ifh, $fname, "O_RDONLY");
    $read = sysread $ifh,$data,4096;
    chomp($data);
    return $data;
}

