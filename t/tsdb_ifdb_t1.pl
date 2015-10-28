#!/opt/scalable/bin/perl


use lib "../lib/";
use strict;
use Scalable::TSDB;
use Data::Dumper;

my $db   = Scalable::TSDB->new({
                                host  => "localhost",
                                port  => 8086,
                                proto => "tcp",
				db    => "mydb",
                                debug => 1
                               });


my $url = $db->_request_url("write");
printf "D[%i] url = %s\n",$$, Dumper($url);

my $data = ["measurement value=12", "measurement value=12 1439587925",
"measurement,foo=bar value=12", "measurement,foo=bar value=12 1439587925",
"measurement,foo=bar,bat=baz value=12,otherval=21 1439587925" ];

$db->_write_data($data);
