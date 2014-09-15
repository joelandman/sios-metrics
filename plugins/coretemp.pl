#!/usr/bin/perl

use strict;
use IO::Dir;
use IO::Handle;
use Fcntl;
 
my ($path,$fpath,$t,$ifh,$fn,$data,$read,$l,$cpu_index);
my ($d,$de,$ce,%dir,%coretemp,$name,$ee,$temp);
$path   = '/sys/devices/platform/';
tie %dir, 'IO::Dir', $path;

foreach $de (sort keys %dir) {
    next if ($de !~ /coretemp/); #skip anything not coretemp related
    $fpath = join('/',$path,$de);
    tie %coretemp, 'IO::Dir', $fpath;
    if ($de =~ /coretemp\.(\d+)/) { $cpu_index = $1; }
    foreach $ce (sort keys %coretemp) {
        next if ($ce !~ /label$/);
        $fn = join('/',$fpath,$ce);
        $name = lc(&_get_contents($fn));
        $name =~ s/physical\sid/cpu/;
        $name =~ s/\s//g;
        $ee = $ce;
        $ee =~ s/label$/input/;
        $fn = join('/',$fpath,$ee);
        $temp = &_get_contents($fn);
        $l->{$name} = $temp/1000.0;
        printf "cputemp.p%i.%s:%.3f\n",$cpu_index,$name,$temp/1000.0;
    }
    untie %coretemp;
}

sub _get_contents {
    my $fname = shift;
    my ($data,$read,$ifh);
    sysopen($ifh, $fname, O_RDONLY);
    $read = sysread $ifh,$data,4096;
    chomp($data);
    return $data;
}
