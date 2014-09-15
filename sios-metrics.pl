#!/usr/bin/perl

# Copyright (c) 2012-2014 Scalable Informatics
# This is free software, see the gpl-2.0.txt 
# file included in this distribution


use strict;
use English '-no_match_vars';
use Getopt::Lucid qw( :all );
use POSIX qw[strftime];
use SI::Utils;
use lib "lib/";
use Scalable::Graphite;
use IPC::Run qw( start pump finish timeout run harness );
use Data::Dumper;
use IO::Handle;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
                             clock_gettime clock_getres clock_nanosleep clock
                             stat );
use Config::JSON;
use Digest::SHA  qw(sha256_hex);

use threads;
use threads::shared;

use constant config_path => '/data/tiburon/metrics.json';

#
my $vers    = "0.8";


# variables
my ($opt,$rc,$version,$thr);
my $debug 		        : shared;
my $verbose           : shared;
my $help;
my $dir               : shared;
my $system_interval	  : shared;
my $block_interval    : shared;
my $done              : shared;
my $timestamp         : shared;
my $hostname          : shared;
my (@metrics,$metric,$thr_name,$met,$metrics_hash,$proto,$port);
my ($host,$user,$pass,$output,$config_file,$cf_h,$config,$c);

$hostname   = `hostname`;
chomp($hostname);


# signal catcher
# SIGHUP is a graceful exit, SIGKILL and SIGINT are immediate
my (@sigset,@action);
foreach (0 .. 2 ) { $sigset[$_] = POSIX::SigSet->new() };
$action[0] = POSIX::SigAction->new('sig_handler_graceful' ,$sigset[0],&POSIX::SA_NODEFER);
$action[1] = POSIX::SigAction->new('sig_handler_immediate',$sigset[1],&POSIX::SA_NODEFER);
$action[2] = POSIX::SigAction->new('sig_handler_immediate',$sigset[2],&POSIX::SA_NODEFER);
POSIX::sigaction(&POSIX::SIGHUP,  $action[0]);
POSIX::sigaction(&POSIX::SIGKILL, $action[1]);
POSIX::sigaction(&POSIX::SIGINT,  $action[2]);

sub sig_handler_graceful {
	our $out_fh;
	print STDERR "caught graceful termination signal\n";
	$done	= true;
        close($out_fh) if (defined($out_fh) && $out_fh);
	# exit gracefully
}

sub sig_handler_immediate {
	our $out_fh;
	print STDERR "caught immediate termination signal\n";
	$done	= true;
        close($out_fh) if (defined($out_fh) && $out_fh);
	# exit -1;
	# exit immediately
	die "thread caught termination signal\n";
}



 
my @command_line_specs = (
		     Param("config|c"),
                     Switch("help"),
                     Switch("version"),
                     Switch("debug"),
                     Switch("verbose"),
                     );

# parse all command line options
eval { $opt = Getopt::Lucid->getopt( \@command_line_specs ) };
if ($@) 
  {
    #print STDERR "$@\n" && help() && exit 1 if ref $@ eq 'Getopt::Lucid::Exception::ARGV';
    print STDERR "$@\n\n" && help() && exit 2 if ref $@ eq 'Getopt::Lucid::Exception::Usage';
    print STDERR "$@\n\n" && help() && exit 3 if ref $@ eq 'Getopt::Lucid::Exception::Spec';
    #printf STDERR "FATAL ERROR: netmask must be in the form x.y.z.t where x,y,z,t are from 0 to 255" if ($@ =~ /Invalid parameter netmask/);
    ref $@ ? $@->rethrow : die "$@\n\n";
  }

# test/set debug, verbose, etc
$debug      = $opt->get_debug   ? true : false;
$verbose    = $opt->get_verbose ? true : false;
$help       = $opt->get_help    ? true : false;
$version    = $opt->get_version ? true : false;
$config_file= $opt->get_config  ? $opt->get_config  : config_path;

$done       	= false;

&help()             if ($help);
&version($vers)     if ($version);

$config 	= &parse_config_file($config_file);


# start time stamp thread
$thr->{TS}                      = threads->create({'void' => 1},'TS');

# loop through all the machines in the config file, and
$metrics_hash 	= $config->{'config'}->{'metrics'};
@metrics	= keys(%{$metrics_hash});

# set host, port, proto from global
$host           = $config->{'config'}->{'db'}->{'host'} || '127.0.0.1';
$port           = $config->{'config'}->{'db'}->{'port'} || '2003';
$proto          = $config->{'config'}->{'db'}->{'proto'} || 'udp';


foreach $metric (@metrics)
   {
      $met 		= $metrics_hash->{$metric};
      $thr_name 	= sprintf 'metric.%s',$metric;
      $thr->{$thr_name}	= threads->create({'void' => 1},'measure',$met,$metric,$host,$port,$proto);
   }


# main loop ... sleep for 100k us (0.1 s)
do {
    usleep(100000);
} until ($done);


exit 0;

 
sub help {
printf<<EOH;
new.pl :   matrics.pl does this stuff


EOH

exit 0;
}

sub version {
    my $V = shift;
    print "new.pl version $V\n";
    exit 0;
}

sub measure {
    my ($sys,$name,$host,$port,$proto)		= @_;
    my ($rec,@c,$db,$ret,$t0,$dt,$si);

    $host     = $met->{'host'}    if ($met->{'host'});
    $port     = $met->{'port'}    if ($met->{'port'});
    $proto    = $met->{'proto'}   if ($met->{'proto'});

    # connect to the graphite DB
    $db       = Scalable::Graphite->new();
    $ret = $db->open({host => $host, port => $port, proto => $proto , debug => $debug });  
    printf "D[%i]  Graphite open returned \'%s\'\n",$$,$ret->{result};


    $done	          = false;
    # microseconds to sleep before waking, defaults to 15 seconds
    my $interval    = $sys->{interval} * 1000000 || 15000000; 

    # microseconds for timeout of command, defaults to 5 seconds
    my $timeout     = $sys->{timeout}  * 1000000 ||  5000000;

    my ($in,$out,$err,@lines,@times,$ts,$h,$ipmi,@cmd,$out_fh,$out_fn);
    my ($lineout,$r,$mname,$mvalue,$dval);
    
    # all we need to do is to run the command, within a specific timeout,
    # and then report the results
    
    $out_fn	  = sprintf '%s.log',$name;
    open($out_fh,">>".$out_fn)   if ($out_fn);
    @cmd			= split(/\s+/,$sys->{command});
    $dt       = 0;
    $t0       = [gettimeofday];
    do
       {

        # create the run harness
        $out        = "";
        $in         = "";
        undef $h;
	printf "D[%i] TS=%i starting run harness for metric=%s\n",$$,$timestamp,$name if ($debug);
        $h = start \@cmd, '<pty<', \$in, '>pty>', \$out, timeout($timeout), debug=>$debug;
        printf "time: %f\n",$timestamp if (false);  
        $h->pump while ($h->pumpable);

        $h->finish;
	      $done = false;
        
        if ($out ne "")
           {
            # output will be 1 or more lines of key:value (single value per line)
            @lines	= split(/\n/,$out);
	          chomp(@lines);
            $out    = "";
	          open($out_fh,">>".$out_fn)   if ($out_fn);
		  
            foreach my $line (@lines) 
              {
                # get timestamp data
                printf $out_fh "%i %s\n",$timestamp,$line if ($out_fn);                   
                printf "D[%i] %i ++++ %s ----\n",$$,$timestamp,$line if ($debug);
              }                        
	          close($out_fh) if ($output);

            # send metrics to db
            foreach my $line (@lines) 
              {
                ($mname,$mvalue)  = split(/\:/,$line);

                # I can't find where this bug is, but the last character of mvalue is wrong ...
                @c =split(//, $mvalue);
                pop @c;
                $mvalue = join('',@c);
                # ... so lop it off
                $mname = join(".",$hostname,$mname);
                $rec->{metric}  = $mname;
                $rec->{value}   = $mvalue;
                $rec->{time}    = $timestamp;
		            printf "D[%i] : TS=%i, mname=%s, mvalue=%s\n\n",$$,$timestamp,$mname,$mvalue if ($debug);
                $rc = $db->send($rec);
		            printf "D[%i] TS=%i send results = %s\n\n",$$,$timestamp,Dumper($rc);
              }
          }
        $dt = tv_interval ($t0,[gettimeofday])*1000000.0; # interval spent in execution in us
        $si = ( ($interval - $dt) < 0.1* $interval ? $interval : $interval - $dt);
         
        printf "D[%i] TS=%i dt = %-.4f\n",$$,$timestamp,$dt;
	      printf "D[%i] TS=%i sleeping for %-.3f s for metric=%s\n",$$,$timestamp,$si/1000000.0,$name if ($debug);                   
        usleep($si);    
        $t0 = [gettimeofday];
       } until ($done);
       undef $db;
       printf "D[%i] TS=%i exiting measure loop for metric=%s\n",$$,$timestamp,$name if ($debug);
}

sub TS {
    my $sleep_interval  = 250000; # microseconds to sleep before waking
    my $last = 0;
    do {
        $timestamp  = time();
        if ((int($timestamp - $last) >= 1)) {
            #printf "D[%i] time: %f\n",$$,$timestamp if ($debug);
            $last = $timestamp;
        }
        
        usleep($sleep_interval);    
    } until ($done);
}

sub parse_config_file {
    my $file	= shift;
    my $rc;
    if (-e $file) {
	if (-r $file) {
		$rc = Config::JSON->new($file);		
	}
	else
	{
		die "FATAL ERROR: config file \'$config_file\' exists but is unreadable by this userid\n";
	}
	
	#code
    }
    else
    {
	die "FATAL ERROR: config file \'$config_file\' does not exist\n";
    }
    return $rc;
}