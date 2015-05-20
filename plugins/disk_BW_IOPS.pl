#!/opt/scalable/bin/perl

# Copyright (c) 2002-2015 Scalable Informatics


use strict;
use Getopt::Lucid qw( :all );
use POSIX qw[strftime];
use SI::Utils;
use Time::HiRes qw(usleep);
use Data::Dumper;

#
my $vers    = "0.5";

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

my ($blockdev,$fh,$bwfh,$iofh,@devs,@dev_list,$i,@proc,$line,$total,$lower);
my ($dev_last,$dev_current,$dev_delta,@_tmp,$path,$bldfh,$iopfh,$read,$write);
my ($riop,$wiop,$major,$minor,@vals,$ts,$upper,$tbw,$trbw,$twbw,$triops);
my ($twiops,$tiops);
my $sector_size	= 512;
my $wrap		= 2**32;
my $MB			= 1024*1024;
my $DEVICES		= `/bin/ls /sys/block`;
my $interval		= 1;
my ($reads,$writes,$r_iops,$w_iops,$npts,$max_saved_data,$bwf,@stamp);
my ($tiop,$count,$firstpass,@hbwr,@hbww);

$firstpass = true; 
undef $dev_last;
do
{    
	open ($bldfh,"< /proc/diskstats") or next;
	chomp(@proc	= <$bldfh>);
	close($bldfh);
	$ts	= time;
	$tbw = $trbw = $twbw = $tiops = $triops = $twiops = 0;
	foreach $line (@proc)
	 {
	  $line =~ s/^\s+//;
	  ($major,$minor,$blockdev,@vals) = split(/\s+/,$line);
	  next if ($blockdev =~ /\S+\d+/);
	  for($i=0;$i<11;$i++)
	   {
	    $dev_current->{$blockdev}->{$i+1} = $vals[$i];
	    $dev_last->{$blockdev}->{$i+1} -= $wrap if ($dev_current->{$blockdev}->{$i+1} < $dev_last->{$blockdev}->{$i+1} ); 
	    # handle the case of 32 bit numbers wrapping
	   }
	  for($i=1;$i<=11;$i++)
	   {
	    $dev_delta->{$blockdev}->{$i}=($dev_current->{$blockdev}->{$i}-$dev_last->{$blockdev}->{$i});
	   }
	 }

	$dev_last=$dev_current;
	undef $dev_current;
 	if (!$firstpass) {	
	printf "\n#### sync:%i\n",time;
	foreach $blockdev (sort keys %{$dev_delta})
	 {
		$read		= $dev_delta->{$blockdev}->{3}*$sector_size/$interval;
		$write		= $dev_delta->{$blockdev}->{7}*$sector_size/$interval;
		$riop 		= ($dev_delta->{$blockdev}->{1}+$dev_delta->{$blockdev}->{2})/$interval; 
		$wiop 		= ($dev_delta->{$blockdev}->{5}+$dev_delta->{$blockdev}->{6})/$interval; 
		$trbw		+= $read;
		$twbw		+= $write;
		$triops		+= $riop;
		$twiops		+= $wiop;
		printf "disk.read_BW.%s:%f\ndisk.write_BW.%s:%f\ndisk.total_BW.%s:%f\ndisk.read_IOP.%s:%f\ndisk.write_IOP.%s:%f\n",
		$blockdev,$read/$MB,
		$blockdev,$write/$MB,
		$blockdev,($read+$write)/$MB,
		$blockdev,$riop,
		$blockdev,$wiop;
	 }
	
	printf "disk.read_BW.total:%f\ndisk.write_BW.total:%f\ndisk.read_IOP.total:%f\ndisk.write_IOP.total:%f\n\n",
		$trbw/$MB,$twbw/$MB,$triops,$twiops;
	}
	
	$firstpass = false;

	sleep(1); 
} until ($done);

