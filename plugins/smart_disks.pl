#!/usr/bin/perl

use strict;
use IO::Dir;
use IO::Handle;
use Fcntl;
 
my ($path,$fpath,$t,$ifh,$fn,$data,$read,$l,$cpu_index);
my ($d,$de,$ce,%dir,%md,$name,$ee,$temp,$ndisks);
my (@lines,$line,$h,$k,$v,@varry,@drives);

$path   = '/sys/block/';
tie %dir, 'IO::Dir', $path;

foreach $de (sort keys %dir) {
    next if ($de !~ /^sd/); 
    
    $fpath = join('/',"/dev",$de);
    next if (! -e $fpath);
    push @drives,$de;
    #printf "de=%s, fpath=%s\n",$de,$fpath;
    chomp(@lines = split(/\n/,`smartctl -a $fpath | grep ":"`));
    foreach $line (@lines) {
	if ($line =~ /^\s{0,}(.*?):\s{0,}(.*?)$/) {
		$k = $1;
		$v = $2;
		map {
	 	     $h->{$de}->{lc($_)} = $v if ($k =~ /^$_$/i)
		    } qw(Vendor Product Revision Compliance);
		if ($k =~ /Logical Unit id/i) {$h->{$de}->{logical_unit_id} = $v }
                if ($k =~ /Serial number/i) {$h->{$de}->{serial} = $v }
                if ($k =~ /Transport protocol/i) {$h->{$de}->{trans} = $v }
                if ($k =~ /SMART Health Status/i) {$h->{$de}->{health} = lc($v) }
		if ($k =~ /Non-medium error count/i) {$h->{$de}->{non_medium_error_count} = $v }
		if ($k =~ /Elements in grown defect list/i) {$h->{$de}->{grown_defect_list} = $v }
                if ($k =~ /Percentage used endurance indicator/i) {
			$v =~ s/\%//g;
			$h->{$de}->{percent_used_endurance} = $v; 
		} 	
		if ($k =~ /Current Drive Temperature/i) {
			my @_r = split(/\s+/,$v);
			$h->{$de}->{temperature} = $_r[0];
		}
		if ($k =~ /read/) {
			my @_r = split(/\s+/,$v);
                        $h->{$de}->{error_read_ecc_corrected_fast} = $_r[0];
                        $h->{$de}->{error_read_ecc_corrected_delayed} = $_r[1];
                        $h->{$de}->{error_read_ecc_corrected_reread} = $_r[2];
                        $h->{$de}->{error_read_ecc_corrected_total} = $_r[3];
                        $h->{$de}->{error_read_correction_algorithm_invocations} = $_r[4];
			$h->{$de}->{read_GB_processed} = $_r[5];
			$h->{$de}->{error_read_uncorrected_total} = $_r[6];
		}
		if ($k =~ /write/) {
                        my @_r = split(/\s+/,$v);
                        $h->{$de}->{error_write_ecc_corrected_fast} = $_r[0];
                        $h->{$de}->{error_write_ecc_corrected_delayed} = $_r[1];
                        $h->{$de}->{error_write_ecc_corrected_rewrite} = $_r[2];
                        $h->{$de}->{error_write_ecc_corrected_total} = $_r[3];
                        $h->{$de}->{error_write_correction_algorithm_invocations} = $_r[4];
                        $h->{$de}->{write_GB_processed} = $_r[5];
                        $h->{$de}->{error_write_uncorrected_total} = $_r[6];
                }
        }
    }
}
untie %dir;

# now loop over all the hash elements and return the values in sorted disk/key order
foreach $de (sort @drives) {
	foreach $d (sort keys %{$h->{$de}}) {
		printf "smart.%s.%s:%s\n",$de,$d,$h->{$de}->{$d};
	}
}


sub _get_contents {
    my $fname = shift;
    my ($data,$read,$ifh);
    sysopen($ifh, $fname, O_RDONLY);
    $read = sysread $ifh,$data,4096;
    chomp($data);
    return $data;
}
