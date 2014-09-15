#!/opt/scalable/bin/perl


use lib "../lib/";
use strict;
use Scalable::Graphite;
use Data::Dumper;

my $db   = Scalable::Graphite->new();

my $out		= $db->open({host => '192.168.5.117', port => 2003, proto => 'udp' , debug => 1 });
my $rc;

printf "output: %s\n",Dumper($out);
my $time = time;
my $hn=`hostname`;
chomp($hn);
$rc = $db->send({metric => $hn.".test_2", value => (sprintf "%-.4f",rand 64), time => time});
printf "D[%i] send results = %s\n",$$, Dumper($rc);
$rc = $db->send({metric => "test", value => (sprintf "%-.8f",rand 64) , time => time});
 printf "D[%i] send results = %s\n",$$, Dumper($rc);