#!/opt/scalable/bin/perl

use strict;
use IO::Dir;
use IO::Handle;
use Fcntl;

### this next line is ABSOLUTELY CRITICAL for correct functionality
$| = 1;
### Yes, it tells Perl not to buffer IO.
### otherwise the pipeing to stdio/stderr doesn't work correctly
### and this whole effort fails to generate any output


my ($path,$fpath,$t,$ifh,$fn,$data,$read,$l,$cpu_index,$hostname);
my ($d,$de,$ce,%dir,%coretemp,$name,$ee,$temp,$core,$p,$fl,@cpu,$e);
$path   = '/sys/devices/platform';

# process:
#  1) Generate a hash of all the file names, socket numbers, and core indexes
#  2) loop over this hash to read what we need to return the actual temp

chomp($hostname = `hostname`);
my ($uname,$krev);
chomp($uname = `uname -r`);
$krev = $1 if ($uname =~ /(\d\.\d+)\..*?/);

tie %dir, 'IO::Dir', $path;
# only use the coretemp.\d+ entries
foreach $de (sort keys %dir) {
  next if ($de !~ /coretemp/); #skip anything not coretemp related
  $cpu_index = $1 if ($de =~ /coretemp\.(\d+)/);
  $fpath = (
            $krev < 3.18 ?
            join('/',$path,$de) :
            join('/',$path,$de,(sprintf 'hwmon/hwmon%i',$cpu_index+1))
           );
  # yeah, that whole $cpu_index + 1 thing is because the /sys/devices/platform
  # heirarchy is not as predictably named as one might like
  tie %coretemp, 'IO::Dir', $fpath;
  foreach $ce (sort keys %coretemp) {
    next if ($ce !~ /label$/);
    $fl = sprintf('%s/%s',$fpath,$ce);
    $p = &_get_contents($fl);
    next if ($p =~ /Physical\sid/);
    if ($p =~ /Core\s(\d+)/) {
              $core = $1;
              $fn = $fl;
              $fn =~ s/label$/input/;
              push @cpu,{'file' => $fn, 'socket' => $cpu_index, 'core' => $core};
    }
  }
  untie %coretemp;
}
untie %dir;


while (1) {
    printf "\n#### sync:%i\n",time;
    # loop over all the elements in the @cpu array, reading file contents as
    # needed
    foreach $e (@cpu) {
      $temp = &_get_contents($e->{'file'});
      printf "cputemp,core=%i,machine=%s,socket=%i coretemp=%.1f\n",
        $e->{'core'},
        $hostname,
        $e->{'socket'},
        $temp/1000.0;
    }
    sleep(1);
}

sub _get_contents {
    my $fname = shift;
    my ($data,$read,$ifh);
    sysopen($ifh, $fname, O_RDONLY);
    $read = sysread $ifh,$data,4096;
    chomp($data);
    close($ifh);
    return $data;
}
