#!/usr/bin/perl

use strict;
use File::Temp;
use File::Spec;
use File::Path qw(make_path remove_tree);
$|=1;

my ($line,@mounts,$mount,$fs,$path,$temp,$h,$de,$d);
my (@mrec,$test,$fh,$fname,$nread,$nwrite,$in,$dev,@d);
my ($tdir,@time_array,$nseek,$rcrc,$_d,$out,$first);

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
    next if ($line =~ /^cgroup/);
    next if ($line =~ /rpc_pipefs/);
    next if ($line =~ /binfmt_misc/);
    next if ($line =~ /gvfsd/);
    next if ($line =~ /autofs/);
    next if ($line =~ /securityfs/);
    next if ($line =~ /debugfs/);
    next if ($line =~ /^none/);
    
    @mrec=split(/\s+/,$line);
    next if ($mrec[1] =~ /^\/$/);
    $h->{$mrec[0]}->{mountpoint}=sprintf '"%s"',$mrec[1];
    $h->{$mrec[0]}->{fstype}=sprintf '"%s"',$mrec[2];
    #$h->{$mrec[0]}->{options}=sprintf '"%s"',$mrec[3];
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
        $h->{$mrec[0]}->{make_directory} = "F";
	next;
    }
    $h->{$mrec[0]}->{make_directory} = "T";
    eval {
           ($fh,$fname) = $test->tempfile("rw_monitoring.XXXXXXXX",
					  DIR=>$tdir,
					  SUFFIX=>".test"
					 );
	 };
    if ($@) {
        $h->{$mrec[0]}->{make_temp_file} = "F";
        next;
    }
    $h->{$mrec[0]}->{make_temp_file} = "T" ;

    $h->{$mrec[0]}->{write_test} 	= "T";
    $h->{$mrec[0]}->{seek_test} 	= "T";
    $h->{$mrec[0]}->{read_test} 	= "T";
    eval {
           local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
           alarm $timeout;
           $nwrite = syswrite $fh, $buffer, $size;
           $h->{$mrec[0]}->{write_bytes} = $nwrite;
           alarm 0;
         };
    if ($@) {
	$h->{$mrec[0]}->{write_test} = "F";
        next;
    }
    eval {
           local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
           alarm $timeout;
           $nseek = sysseek $fh, 0, 0;
           $h->{$mrec[0]}->{seek_after_write} = ($nseek =~ /0 but true/ ? "T" : "F");
           alarm 0;
         };
    if ($@) {
        $h->{$mrec[0]}->{seek_test} = "F";
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
        $h->{$mrec[0]}->{read_test} = "F";
        next;
    }
    # check crc32 against what we calculated previously for the buffer.  If they
    # match add a "crc = T"
    $h->{$mrec[0]}->{crc} = "F";
    $rcrc = &crc32($in);
    if ($rcrc == $crc) {$h->{$mrec[0]}->{crc} = "T"; }
    undef $test;
    eval {
          unlink($fname) if (-e $fname);
         };
    if ($@) {
        $h->{$mrec[0]}->{remove_temp_file} = "F";
        next;
    }
    $h->{$mrec[0]}->{remove_temp_file} = "T";

    eval {
          remove_tree($tdir) if (-d $tdir);
         };
    if ($@) {
        $h->{$mrec[0]}->{remove_temp_directory} = "F";
        next;
    }
    $h->{$mrec[0]}->{remove_temp_directory} = "T";
}

# now loop over all the hash elements and return the values in sorted disk/key order
foreach $de (sort keys %{$h}) {
  @d=split(/\//,$de);
  $dev = pop @d;
  $out = sprintf "fs,dev=%s,fstype=%s,mountpoint=%s ",
    $dev,
    $h->{$de}->{fstype},
    $h->{$de}->{mountpoint},;
  delete $h->{$de}->{fstype};
  delete $h->{$de}->{mountpoint};
  $first = 1;
  foreach $_d (sort keys %{$h->{$de}})
  {
    $out .= "," if (!$first);
    $out .= (sprintf "%s=%s",$_d,$h->{$de}->{$_d});
    $first = 0;
  }
	printf "%s\n",$out;
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
