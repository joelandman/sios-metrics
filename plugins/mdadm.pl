#!/usr/bin/perl

use strict;
use IO::Dir;
use IO::Handle;
use Fcntl;
 
my ($path,$fpath,$t,$ifh,$fn,$data,$read,$l,$cpu_index);
my ($d,$de,$ce,%dir,%md,$name,$ee,$temp,$ndisks);
$path   = '/sys/block/';
tie %dir, 'IO::Dir', $path;

foreach $de (sort keys %dir) {
    next if ($de !~ /^md/); 
    
    $fpath = join('/',$path,$de,"md");    
    next if (! -d $fpath);
    
    tie %md, 'IO::Dir', $fpath;
    $fn = join('/',$fpath,'raid_disks');
    $ndisks = lc(&_get_contents($fn));
    foreach $ce (qw(
                    array_state
                    array_size
                    degraded
                    sync_action
                    raid_disks
                   ) ,
                   ( map { sprintf("rd%i/state",$_) } ( 0 .. $ndisks-1) ),
                   ( map { sprintf("rd%i/errors",$_) } ( 0 .. $ndisks-1) ),
                   ( map { sprintf("rd%i/slot",$_) } ( 0 .. $ndisks-1) ),
                   ( map { sprintf("rd%i/size",$_) } ( 0 .. $ndisks-1) )
                ) {
        
        $fn = join('/',$fpath,$ce);
        $data = lc(&_get_contents($fn));
        $ee = $ce;
        $ee =~ s/\//./g;
        printf "md.%s.%s:%i\n",$de,$ee,$data;
    }
    untie %md;
}
untie %dir;



sub _get_contents {
    my $fname = shift;
    my ($data,$read,$ifh);
    sysopen($ifh, $fname, O_RDONLY);
    $read = sysread $ifh,$data,4096;
    chomp($data);
    return $data;
}
