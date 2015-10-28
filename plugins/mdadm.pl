#!/usr/bin/perl

use strict;
use IO::Dir;
use IO::Handle;
use Fcntl;
 
my ($path,$fpath,$t,$ifh,$fn,$data,$read,$l,$cpu_index);
my ($d,$de,$ce,%dir,%md,$name,$ee,$temp,$ndisks,$out);
$path   = '/sys/block/';
tie %dir, 'IO::Dir', $path;

foreach $de (sort keys %dir) {
    next if ($de !~ /^md/); 
    
    $fpath = join('/',$path,$de,"md");    
    next if (! -d $fpath);
    
    tie %md, 'IO::Dir', $fpath;
    $fn = join('/',$fpath,'raid_disks');
    $ndisks = lc(&_get_contents($fn));
    $out = sprintf 'raid,type=software,driver=mdadm name="%s"',$de;
    foreach $ce (qw(
                    array_state
                    degraded
                    sync_action
                    raid_disks
                    level
                   ) ,
                   ( map { sprintf("rd%i/state",$_) } ( 0 .. $ndisks-1) ),
                   ( map { sprintf("rd%i/errors",$_) } ( 0 .. $ndisks-1) ),
                   ( map { sprintf("rd%i/slot",$_) } ( 0 .. $ndisks-1) ),
                   ( map { sprintf("rd%i/size",$_) } ( 0 .. $ndisks-1) )
                ) {
        
        $fn = join('/',$fpath,$ce);
        $data = lc(&_get_contents($fn));
        $ee = $ce;
        $ee =~ s/\//_/g;
        if ( $ee =~ /degraded/ ) {
            $out .= (sprintf ",%s=%s","normal",($data == 0 ? "T" : "F" ) );
            $out .= (sprintf ",%s=%s","n_failed",$data );
        }
        $data = ($data == 0 ? "F" : "T" ) if ($ee =~ /degraded/);
        if ($ee =~ /_state$/) {
            $data = '"'.$data.'"';
        }
        if ($ee =~ /level/) {
            $data =~ s/raid//ig;
        }
        if ($ee =~ /_action$/) {
            $data = '"'.$data.'"';
        }
        $out .= (sprintf ",%s=%s",$ee,$data );
        
        
    }
    printf "%s\n",$out;
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
