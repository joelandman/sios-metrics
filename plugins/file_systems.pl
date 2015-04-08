#!/usr/bin/perl

use strict;
use File::Temp;
use File::Spec;
use File::Path qw(make_path remove_tree);

my ($line,@mounts,$mount,$fs,$path,$temp,$h,$de,$d);
my (@mrec,$test,$fh,$fname,$nread,$nwrite,$in,$dev,@d);
my ($tdir,@time_array,$nseek,$rcrc);

my $buffer = " " x (1024*1024) ;  # 1MB of spaces
my $crc    = &crc32($buffer);     # calculate crc
my $size   = length($buffer);
my $timeout= 30;

chomp(@mounts = split(/\n/,`cat /proc/mounts`));

foreach $line (sort @mounts) {
    next if ($line =~ /^tmpfs/);
    next if ($line =~ /^rootfs/);
    next if ($line =~ /^nfsd/);
    next if ($line =~ /^udev/); 
    next if ($line =~ /^devpts/);
    next if ($line =~ /^proc/);
    next if ($line =~ /^sys/);
    next if ($line =~ /^dev/);
    next if ($line =~ /\sys\/\fs\/cgroup/);
    next if ($line =~ /tmpfs/);
    next if ($line =~ /^fusectl/);
    next if ($line =~ /cifs/);
    next if ($line =~ /rpc_pipefs/);
    next if ($line =~ /binfmt_misc/);

    @mrec=split(/\s+/,$line);
    $h->{$mrec[0]}->{mountpoint}=$mrec[1];
    $h->{$mrec[0]}->{fstype}=$mrec[2];
    $h->{$mrec[0]}->{options}=$mrec[3];
    $test = File::Temp->new();
    $test->unlink_on_destroy(1);
    @time_array = localtime(time);
    $tdir = File::Spec->catfile(
				$mrec[1],
				"SIOS",
				(sprintf "%i%i%i",($time_array[5]+1900),$time_array[4]+1,$time_array[3])
			       );
    eval {
          make_path($tdir) if (! -d $tdir);
         };
    if ($@) {
        $h->{$mrec[0]}->{make_directory} = "failed";
	next;
    }
    $h->{$mrec[0]}->{make_directory} = "passed";
    eval {
           ($fh,$fname) = $test->tempfile("rw_monitoring.XXXXXXXX",
					  DIR=>$tdir,
					  SUFFIX=>".test"
					 );
	 };
    if ($@) {
        $h->{$mrec[0]}->{make_temp_file} = "failed";
        next;
    }
    $h->{$mrec[0]}->{make_temp_file} = "passed" ;
    
    $h->{$mrec[0]}->{write_test} 	= "passed";    
    $h->{$mrec[0]}->{seek_test} 	= "passed";
    $h->{$mrec[0]}->{read_test} 	= "passed";
    eval {
           local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
           alarm $timeout;
           $nwrite = syswrite $fh, $buffer, $size;
           $h->{$mrec[0]}->{write_bytes} = $nwrite;
           alarm 0;
         };
    if ($@) {
	$h->{$mrec[0]}->{write_test} = "failed";
        next;
    }
    eval {
           local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
           alarm $timeout;
           $nseek = sysseek $fh, 0, 0;
           $h->{$mrec[0]}->{seek_after_write} = ($nseek =~ /0 but true/ ? "passed" : "failed");
           alarm 0;
         };
    if ($@) {
        $h->{$mrec[0]}->{seek_test} = "failed";
	next;
    }
    eval {
           local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
           alarm $timeout;
           $nread = sysread $fh, $in, $size;
	   $h->{$mrec[0]}->{read_bytes} = $nread;
           alarm 0;
         };
    if ($@) {
        $h->{$mrec[0]}->{read_test} = "failed";
        next;
    } 
    # check crc32 against what we calculated previously for the buffer.  If they
    # match add a "crc = passed" 
    $h->{$mrec[0]}->{crc} = "failed";
    $rcrc = &crc32($in);
    if ($rcrc == $crc) {$h->{$mrec[0]}->{crc} = "passed"; }
    undef $test;
    eval {
          unlink($fname) if (-e $fname);
         };
    if ($@) {
        $h->{$mrec[0]}->{remove_temp_file} = "failed";
        next;
    }
    $h->{$mrec[0]}->{remove_temp_file} = "passed";

    eval {
          remove_tree($tdir) if (-d $tdir);
         };
    if ($@) {
        $h->{$mrec[0]}->{remove_temp_directory} = "failed";
        next;
    }   
    $h->{$mrec[0]}->{remove_temp_directory} = "passed";
}    

# now loop over all the hash elements and return the values in sorted disk/key order
foreach $de (sort keys {%$h}) {
	foreach $d (sort keys %{$h->{$de}}) {
		@d=split(/\//,$de);
		$dev = pop @d;
		printf "mount.%s.%s:%s\n",$dev,$d,$h->{$de}->{$d};
	}
}

# from http://billauer.co.il/blog/2011/05/perl-crc32-crc-xs-module/
sub crc32 {
my ($input, $init_value, $polynomial) = @_;

 $init_value = 0 unless (defined $init_value);
 $polynomial = 0xedb88320 unless (defined $polynomial);

 my @lookup_table;

 for (my $i=0; $i<256; $i++) {
   my $x = $i;
   for (my $j=0; $j<8; $j++) {
     if ($x & 1) {
       $x = ($x >> 1) ^ $polynomial;
     } else {
       $x = $x >> 1;
     }
   }
   push @lookup_table, $x;
 }

 my $crc = $init_value ^ 0xffffffff;

 foreach my $x (unpack ('C*', $input)) {
   $crc = (($crc >> 8) & 0xffffff) ^ $lookup_table[ ($crc ^ $x) & 0xff ];
 }

 $crc = $crc ^ 0xffffffff;

 return $crc;
}
