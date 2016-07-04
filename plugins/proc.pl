#!/opt/scalable/bin/perl

use strict;
use IO::Dir;
use IO::Handle;
use Fcntl;
use SI::Utils;

### this next line is ABSOLUTELY CRITICAL for correct functionality
$| = 1;
### Yes, it tells Perl not to buffer IO.
### otherwise the pipeing to stdio/stderr doesn't work correctly
### and this whole effort fails to generate any output


my ($path,$fpath,$hostname,$statm,$status,@lines,$line,$k,$v);
my ($d,$de,$ce,%dir,$name,$ee,$temp,$core,$p,$fl,$ps,$proc);
$path   = '/proc';
chomp($hostname = `hostname`);

while (1) {
    printf "\n#### sync:%i\n",time;
    tie %dir, 'IO::Dir', $path;
    foreach $de (sort keys %dir) {
        next if ($de !~ /\d+/); #skip anything not specifically a process ID
        $fpath = join('/',$path,$de);
        $fl = sprintf('%s/%s',$fpath,'status');
        undef $ps;
        $status = &_get_contents($fl);
        foreach $line (split(/\n/,$status)) {
            if ($line =~ /^(.*?):\s+(.*)/) {
                $k=$1;
                $v=$2;
                $ps->{$k}=$v;
            }
        }
        foreach $k (qw(Name State Pid PPid Uid Gid Threads)) {
            $proc->{$de}->{$k} = $ps->{$k};
        }
        foreach $k (qw(VmPeak VmSize)) {
            $proc->{$de}->{$k} = SI::Utils->size_to_bytes($ps->{$k});
        }
        
    }                
    untie %dir;
    sleep(1);
}
printf "done\n";


sub _get_contents {
    my $fname = shift;
    my ($data,$read,$ifh);
    sysopen($ifh, $fname, O_RDONLY);
    $read = sysread $ifh,$data,4096;
    chomp($data);
    close($ifh);
    return $data;
}
