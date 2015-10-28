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
my ($d,$de,$ce,%dir,%coretemp,$name,$ee,$temp,$core,$p,$fl);
$path   = '/sys/devices/platform';
chomp($hostname = `hostname`);
my ($uname,$krev);
chomp($uname = `uname -r`);
$krev = $1 if ($uname =~ /(\d\.\d+)\..*?/);

while (1) {
    printf "\n#### sync:%i\n",time;
    tie %dir, 'IO::Dir', $path;
    foreach $de (sort keys %dir) {
        next if ($de !~ /coretemp/); #skip anything not coretemp relateda
 	if ($krev < 3.18) {
	        $fpath = join('/',$path,$de);
	   }
	  else
	   {
		$fpath = join('/',$path,$de,'hwmon/hwmon2');
	   }
        tie %coretemp, 'IO::Dir', $fpath;
        if ($de =~ /coretemp\.(\d+)/) { $cpu_index = $1; }
        foreach $ce (sort keys %coretemp) {
            next if ($ce !~ /label$/);
            $fl = sprintf('%s/%s',$fpath,$ce);
            $p = &_get_contents($fl);
            next if ($p =~ /Physical\sid/); # skip package
            if ($p =~ /Core\s(\d+)/) {
              $core = $1;
              $fn = $fl;
              $fn =~ s/label$/input/;
              #$fn = sprintf('%s/temp%s_input',$fpath,$core);
              $temp = &_get_contents($fn);
              printf "cputemp,core=%i,machine=%s,socket=%i coretemp=%.1f\n",$core,$hostname,$cpu_index,$temp/1000.0;
            }            
        }
        untie %coretemp;
    }
    untie %dir;
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
