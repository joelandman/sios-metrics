#!/usr/bin/perl

use strict;
use IO::Dir;
use IO::Handle;
use Fcntl;
 
my ($path,$fpath,$t,$ifh,$fn,$data,$read,$l,$cpu_index);
my ($d,$de,$ce,%dir,%net,$name,$ee,$temp);
$path   = '/sys/class/net/';
tie %dir, 'IO::Dir', $path;

foreach $de (sort keys %dir) {
    next if ($de =~ /(lo|\.{1,2})/); #skip loopback, and other
    # directories that aren't networks
    
    $fpath = join('/',$path,$de);
    # skip any non-network entries
    next if (! -d $fpath);
    tie %net, 'IO::Dir', $fpath;
   
    foreach $ce (qw(
                    carrier speed statistics/rx_bytes
                    statistics/tx_bytes
                    statistics/rx_errors
                    statistics/tx_errors
                    statistics/rx_dropped
                    statistics/rx_crc_errors
                    statistics/tx_dropped
                    statistics/tx_crc_errors
                    statistics/rx_over_errors
                    statistics/tx_over_errors
                   )
                ) {
        
        $fn = join('/',$fpath,$ce);
        $data = lc(&_get_contents($fn));
        $ee = $ce;
        $ee =~ s/\//./g;
        $ee =~ s/statistics/metrics/;
        printf "network.%s.%s:%i\n",$de,$ee,$data;
    }
    untie %net;
}

sub _get_contents {
    my $fname = shift;
    my ($data,$read,$ifh);
    sysopen($ifh, $fname, O_RDONLY);
    $read = sysread $ifh,$data,4096;
    chomp($data);
    return $data;
}
