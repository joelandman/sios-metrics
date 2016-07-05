#!/opt/scalable/bin/perl

# Copyright (c) 2012-2014 Scalable Informatics
# This is free software, see the gpl-2.0.txt
# file included in this distribution


use strict;
use English '-no_match_vars';
use Getopt::Lucid qw( :all );
use POSIX qw[strftime];
use SI::Utils;
use lib "lib/";
use Scalable::TSDB::InfluxDB;
use Scalable::TSDB::kdb;

use IPC::Run qw( start pump finish timeout run harness );
use Data::Dumper;
use IO::Handle;
use IO::Dir;
use File::Spec;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
                             clock_gettime clock_getres clock_nanosleep clock
                             stat );
use Config::JSON;
use Digest::SHA  qw(sha256_hex);

use threads;
use threads::shared;

use constant config_path => '/data/tiburon/sios-metrics.json';

#
my $vers    = "1.5";


# variables
my ($opt,$rc,$version,$thr);
my $debug 	      : shared;
my $verbose           : shared;
my $harness           : shared;
my $help;
my $dir               : shared;
my $system_interval   : shared;
my $block_interval    : shared;
my $done              : shared;
my $timestamp         : shared;
my $hostname          : shared;
my $machname	        : shared;
my @list_of_metrics   : shared;
my $run_dir           : shared;
my (@metrics,$metric,$thr_name,$met,$metrics_hash);
my (%mtr,$proto,$port,$mfh,$mstate);
my ($host,$user,$pass,$output,$config_file,$cf_h,$dbs,@tdbns);
my ($config,$c,$_fqpni,$nolog);
my $shared_sig	  : shared;
my $restart	      : shared;
my @plugin_dirs   : shared;
my $pconfig       : shared;
my %pconf 	  ;
my @metric_buffer : shared;
my ($tick,@dbuf,@_mbufk,$db,$tsdb,$_dbrc,$dbtype);

chomp($hostname   = `hostname`);


# signal catcher
# SIGHUP is a graceful exit, SIGKILL and SIGINT are immediate
my (@sigset,@action);
sub sig_handler_any {
	our $out_fh;
	$shared_sig++;
	print STDERR "caught termination signal\n";
  $done   = true;
  close($out_fh) if (defined($out_fh) && $out_fh);
	printf STDERR "Waiting 10 seconds to clean up\n";
  if ($shared_sig == 1) {	sleep 10; }
  die "thread caught termination signal\n";
}

sub sig_handler_reconnect_to_db {

}

sub sig_handler_reread_config_restart_metrics {
	map {$restart->{$_} = true;} @list_of_metrics;
}

$SIG{HUP} = \&sig_handler_reconnect_to_db;
$SIG{KILL} = \&sig_handler_any;
$SIG{INT} = \&sig_handler_any;
$SIG{QUIT} = \&sig_handler_any;
$SIG{USR1} = \&sig_handler_reread_config_restart_metrics;




my @command_line_specs = (
		     Param("config|c"),
                     Switch("help"),
                     Switch("version"),
                     Switch("debug"),
                     Switch("verbose"),
                     Param("run_dir"),
                     Param("plugin_dirs"),
		                 Switch("nolog"),
		                 Param("name")
                     );

# parse all command line options
eval { $opt = Getopt::Lucid->getopt( \@command_line_specs ) };
if ($@)
  {
    print STDERR "$@\n\n" && help() && exit 2 if ref $@ eq 'Getopt::Lucid::Exception::Usage';
    print STDERR "$@\n\n" && help() && exit 3 if ref $@ eq 'Getopt::Lucid::Exception::Spec';
    ref $@ ? $@->rethrow : die "$@\n\n";
  }

# test/set debug, verbose, etc
$debug      = $opt->get_debug   ? true : false;
$verbose    = $opt->get_verbose ? true : false;
$help       = $opt->get_help    ? true : false;
$version    = $opt->get_version ? true : false;
$nolog	    = $opt->get_nolog   ? true : false;
$config_file= $opt->get_config  ? $opt->get_config  : config_path;
$nolog	    = false if ($debug);
$machname	    = $opt->get_name  ? $opt->get_name : $hostname;

$done       	= false;

&help()             if ($help);
&version($vers)     if ($version);

$config 	  = &read_config($config_file);
# run_dir from command line takes precedence over config file
$run_dir    = $opt->get_run_dir ? $opt->get_run_dir :$config->{'config'}->{'global'}->{'run_dir'};
@plugin_dirs= $opt->get_plugin_dirs ? @{$opt->get_plugin_dirs} : @{$config->{'config'}->{'metrics'}->{'plugin_dirs'}};

# initial read of plugin_dirs
%pconf        = %{&read_plugin_configs_from_directory_list(@plugin_dirs)};
$metrics_hash 	= \%pconf;
@metrics	      = keys(%{$metrics_hash});

# initial allocation of metric buffer space for send
#map {$metric_buffer{$_} = 8192 x " " ;} @metrics;



# find metrics through directory list in config file

# loop through all the machines in the config file, and


# set host, port, proto from global
$dbs = $config->{'config'}->{'db'};
foreach my $dbn (keys %{$dbs}) {
  $host           = $dbs->{$dbn}->{'host'}  ;
  $port           = $dbs->{$dbn}->{'port'}  ;
  $proto          = $dbs->{$dbn}->{'proto'}  ;
  $db             = $dbs->{$dbn}->{'db'}    ;
  $dbtype         = $dbs->{$dbn}->{'dbtype'}    ;
  printf STDERR "D[%i] h=%s, p=%s, pr=%s, db=%s, dbt=%s\n",$$,$host,$port,$proto,$db,$dbtype if ($debug);
  if ($dbtype =~ /influxdb/i) {
	$tsdb->{$dbn}   = Scalable::TSDB::InfluxDB->new({
                          host  => $host,
                          port  => $port,
                          proto => $proto,
                          db    => $db,
                          debug => $debug
                         });
     }
    else
     {
	$tsdb->{$dbn}   = Scalable::TSDB::kdb->new({
                          host  => $host,
                          port  => $port,
                          proto => $proto,
                          db    => $db,
                          debug => $debug
                         });
     }
     push @tdbns,$dbn;
}


# start time stamp thread
$thr->{TS}                      = threads->create({'void' => 1},'TS');


foreach $metric (@metrics)
   {
      $met 		= $metrics_hash->{$metric};
      $thr_name 	= sprintf '%s',$metric;
      push @list_of_metrics,File::Spec->catfile($run_dir,$metric);
      $mtr{File::Spec->catfile($run_dir,$metric)} = $metric;
      printf STDERR "D[%i] metric: %s -> \'%s\'\n",$$,$thr_name,Dumper($met) if ($debug);
      $thr->{$thr_name}	= threads->create({'void' => 1},'measure',$met,$thr_name);
   }


# main loop ... sleep for 100k us (0.1 s)
$tick = 0;
do {
    usleep(100000);
    foreach my $meter (@list_of_metrics) {
      if (-e $meter) {
        open($mfh,"<".$meter) or next;
        chomp($mstate = <$mfh>);
        close($mfh);
        if ($mstate =~ /stop/) {
          # terminate that thread
          $thr->{$mtr{$meter}}->join();
          # remove file
          unlink $meter;
        }
      }
    }
   if ($tick == 9) {
	# 1) gather buffers into one large send buffer, and erase shared buffer
	#    for each metric
	# 2) send data to each time series data base

      #### 1
      undef @dbuf ;
      my $_length = $#metric_buffer;
      foreach my $m (0 .. $_length) {
        push @dbuf,$metric_buffer[$m];
      }
      map { delete $metric_buffer[$_]} 0 .. $_length;

      #### 2
      foreach my $_tdbn (@tdbns) {
	$_dbrc = $tsdb->{$_tdbn}->_write_data(\@dbuf);
	printf STDERR "D[%i] send(%s): rc = %s, dt = %.6fs\n\tmessage = \'%s\'\n\tcontent = \'%s\'\n",
        $$,$_tdbn,$_dbrc->{code},$_dbrc->{time},$_dbrc->{message},$_dbrc->{content} if ($debug);
      }

   }
   $tick++;
   $tick=0 if ($tick==10); # wrap around, do the write at 0.9 sec
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

sub send_data {
	#TBD: This will eventually be the code that handles transmitting
	# data to the server.  The problem is we have to setup/test a
	# reasonable IPC mechanism for this.  We may simply have each process
	# accumulate their data for 0.9s, and then copy this to a shared
	# hash that this code then uses to construct the send
	# The advantage of that is that it would be lockless/mutex free
	# The disadvantage is that there may be some very hard to debug
	# performance issues with it.
}

sub measure {
    my ($met,$name)		= @_;
    my ($rec,@c,$db,$ret,$t0,$dt,$si,@frame,$xmit,$nint,$sc,$metname,@kvp);
    my $m;

    $m = $met->{'config'}->{'metric'};
    # need to create an array of open db devices based upon the
    # db array in the config file

    $xmit     = (defined($m->{'xmit'}) ? $m->{'xmit'} : 1); # transmit by default
    return if (!$m->{'enabled'});

    $done	          = false;
    # microseconds to sleep before waking, defaults to 15 seconds
    my $interval    = $m->{interval} * 1000000 || 15000000;
    my $check_interval = 250000; # microseconds to sleep before checking for signal, defaults to 0.25 seconds

    # microseconds for timeout of command, defaults to 5 seconds
    my $timeout     = $m->{timeout}  * 1000000 ||  5000000;

    # persistent or not (e.g. sample output at interval from a plugin that runs continuously)
    my $persistent  = (defined($m->{persistent}) ? $m->{persistent} : 0) ; # defaults to non-persistent

    # grab data from a file at the interval, rather than running code
    my $use_file    = (defined($m->{use_file}) ? $m->{use_file} : 0) ; # defaults to non-file

    # cannot be persisent and use_file simultaneously ... return to caller if this happens
    return if ($persistent && $use_file);

    my ($in,$out,$err,@lines,@times,$ts,$h,$ipmi,@cmd,$out_fh,$out_fn);
    my ($lineout,$r,$mname,$mvalue,$dval,$ndx);

    printf STDERR "D[%i] metric=%s parameters\n\t\tinterval\t= %.2f s\n\t\ttimeout\t\t= %.2f s\n\t\tpersistent\t= %s\n\t\txmit\t\t= %s\n",
    $$,$name,$interval/1000000,$timeout/1000000,($persistent ? "true" : "false"),
    ($xmit ? "true" : "false") if ($debug);


    # all we need to do is to run the command, within a specific timeout,
    # and then report the results

    $out_fn	  = sprintf 'metric.%s.log',$name;
    open($out_fh,">>".$out_fn)  if ((!$nolog) && ($out_fn));

    @cmd			= split(/\s+/,$m->{command});
    $dt       = 0;
    $t0       = [gettimeofday];
    $out        = "";
    $in         = "";
    $err        = "";
    undef $h;

    if ($persistent) {
      printf STDERR "D[%i] TS=%i starting persistent run harness for metric=%s\n",$$,$timestamp,$name if ($debug);
      $h = start \@cmd, \$in, \$out, \$err,  debug=>$debug;
    }

    $ndx = 0;
    do
       {
        if (!$persistent) {
          if (!$use_file) {
              # create the run harness
              $out        = "";
              $in         = "";
              undef $h;
              printf STDERR "D[%i] TS=%i starting run harness for metric=%s\n",$$,$timestamp,$name if ($debug);
              $h = start \@cmd, \$in, \$out, \$err, timeout($timeout), debug=>$debug;
            }
        }
        if (!$use_file) {
          if ($persistent) {
	      #printf STDERR "D[%i]  TS=%i pfs pfs\n",$$,$timestamp;
              eval { $h->pump_nb if ($h->pumpable) };
             }
           else
             {
              eval { $h->pump while ($h->pumpable); $h->finish; };
             }
           }
          else
           {
            eval {
                  my $fn;
                  my $size = (stat($use_file))[7];
                  sysopen($fn,$use_file,"O_RDONLY | O_BINARY");
                  # only read 1st MB of data in if file is greater than 1MB
                  sysread($fn,$out,( $size > 1024*1024 ? 1024*1024 : $size));
                  close($fn);
                 };
           }

	  $done = false;

    if ($out ne "") {
        # output will be 1 or more lines of key:value (single value per line)
        # persistent runs will have a sync line of the form
        #   ^#### sync:timestamp\n
        # where ^ is start of line, sync is the word "sync", : is a colon
        # timestamp is the unix time in seconds since epoch (1-Jan-1970)
        # and \n is the newline character, BEFORE the start of new data.
        # Only the last sync frame will be read for data


        @lines	= split(/\n/,$out);
        chomp(@lines);
        $out    = "";
  	    if (!$nolog) { open($out_fh,">>".$out_fn)   if ($out_fn); }
        my $_ts;
        if ($persistent)
           {
            # scan backwards through lines for the sync frame ...
            undef @frame;
            foreach my $line (reverse @lines)
              {
                if ($line =~ /^####\ssync:(\d+)$/) {
                    $_ts = $1;
                    last;
                }
                # copy only those lines in the most recent sync frame over
                push @frame,$line;
              }
            # truncate any other lines
            @lines = reverse (@frame);
           }
        foreach my $line (@lines)
          {
            # get timestamp data
            if (!$nolog) {
               printf $out_fh "%i %s\n",$timestamp,$line if ($out_fn);
            }
          }

        if (!$nolog) { close($out_fh) if ($output); }

        # send metrics to db
        foreach my $line (@lines)
          {
            #remove leading blanks, trailing \n, and trailing blanks
            chomp($line);
            $line =~ s/^\s+//g;
            $line =~ s/\s+$//g;
	    #printf STDERR "D[%i]  measure: line = %s\n",$$,$line if (($debug) && ($name =~ /pfs/));
            next if ($line eq "");
            next if ($line =~ /^#### sync/);
            $rec = &line_to_structure($line,$timestamp,$machname);
	    #printf STDERR "D[%i]  measure: rec = %s\n",$$,$rec if (($debug) && ($name =~ /pfs/));
            push @metric_buffer,$rec;
            $ndx++;
          }
        }
        $dt = tv_interval ($t0,[gettimeofday])*1000000.0; # interval spent in execution in us
        $si = ( ($interval - $dt) < 0.1* $interval ? $interval : $interval - $dt);

        printf STDERR "D[%i] TS=%i dt = %-.4f\n",$$,$timestamp,$dt if($debug);
        printf STDERR "D[%i] TS=%i sleeping for %-.3f s for metric=%s\n",$$,$timestamp,$si/1000000.0,$name if ($debug);

        # do something morally equivalent to this
        # but waking every check interval until
        # we have equalled or exceeded the sleep interval ($si)
        # this is so we can check for signals and terminate correctly.
        #usleep($si);
        $nint = int($si/$check_interval); #number of check_intervals in the sleep interval
        printf STDERR "D[%i]  si=%.3fs, nint=%i\n",$$,$si/1000000.0,$nint if($debug);
        for($sc = 0; $sc <= $nint; $sc++) {
          usleep($check_interval);
          if (defined($shared_sig))
             {
              $done = true;
              printf STDERR "D[%i] SIGNAL %s at TS=%i caught and killing metric=%s\n",$$,$shared_sig,$timestamp,$name;
              kill_kill $h, grace => 1 ;
             }
        }
        $t0 = [gettimeofday];
      } until ($done);
      eval {kill_kill $h, grace => 1 ;};
      printf STDERR "D[%i] TS=%i exiting measure loop for metric=%s\n",$$,$timestamp,$name if ($debug);
}

sub TS {
    my $sleep_interval  = 250000; # microseconds to sleep before waking
    my $last = 0;
    do {
        $timestamp  = time();
        if ((int($timestamp - $last) >= 1)) {
            #printf STDERR "D[%i] time: %f\n",$$,$timestamp if ($debug);
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
    }
    else
    {
	     die "FATAL ERROR: config file \'$config_file\' does not exist\n";
    }
    return $rc;
}

sub line_to_structure {
  my ($line,$timestamp,$machname) = @_;
  my ($t,$f,$mname,$mvalue,$metname,@kvp,$tag,$field,$out,$k,$ek,$ev,$first,$nfields);
  ($mname,$mvalue)  = split(/\s+/,$line);
  # now if mname is of the form
  #     string,key1=value1,key2=value2,...,keyN=valueN
  # then include those keys value pairs as an array of tags
  @kvp = split(/\,/,$mname);
  if ($#kvp > 0) {
     foreach $tag (@kvp) {
       if ($tag =~ /^(.*?)=(.*?)$/) {
         $t->{$1} = $2;
       }
     }
  }
  $metname = ($#kvp > 0 ? $kvp[0] : $mname);

  # do the same thing for the fields
  @kvp = split(/\,/,$mvalue);
  $nfields = $#kvp;
  if ($#kvp > 0) {
     foreach $field (@kvp) {
       if ($field =~ /^(.*?)=(.*?)$/) {
         $f->{$1} = $2;
       }
     }
  }



  # now start constructing the line in the form
  # metric,sorted_tag1=tvalue1,... sorted_field1=fvalue1,... timestamp
  # and if a tag named "machine" doesn't exist, then insert it
  $out = $metname;
  $t->{machine} = $hostname if (!defined($t->{machine}));
  foreach $k (sort keys %{$t}) {
    # escape key and value if needed
    $ek = $k;
    $ev = $t->{$k};
    $ek =~ s|(\s,\,,=)|\\\1|g;
    $ev =~ s|(\s,\,,=)|\\\1|g;
    $out .= sprintf ",%s=%s",$ek,$ev
  }
  $out .= " ";

  if ($nfields > 0) {
      $first = 1;
      foreach $k (sort keys %{$f}) {
        # escape key and value if needed
        $ek = $k;
        $ek =~ s|(\s,\,,=)|\\\1|g;
        $out .= "," if (!$first);
        $out .= sprintf "%s=%s",$ek,$f->{$k};
        $first = 0;
      }
    }
   else
    {
      $out .= $mvalue;
    }
  $out .= sprintf " %i000000000",$timestamp;
  return $out;
}

sub read_config {
  my $file = shift;
  my $c    = &parse_config_file($file);
  return $c;
}

sub read_plugin_configs_from_directory_list {
  my @paths = @_;
  my (%dir,$plugin,$fn,$pn,$path,%h);

  foreach $path (@paths) {
    printf STDERR "D[%i] read_plugin_configs_from_directory: path = \'%s\'\n",
      $$,$path if ($debug);
      $path =~ s|\/$||; #remove trailing slash
    tie %dir, 'IO::Dir', $path or
      die "FATAL ERROR: unable to open directory $path\n";
    foreach my $de (sort keys %dir) {
      next if ($de !~ /\.json$/);  # skip anything which is not a config file
      $pn = $de;
      $pn =~ s/\.json$//;
      $fn = join('/',$path,$de);
      printf STDERR "D[%i] read_plugin_configs_from_directory: config file = \'%s\'\n",
        $$,$fn if ($debug);
      #undef %h;
      #%h = %{&read_config($fn)};
      $plugin->{$pn} = &read_config($fn);
    }
    untie %dir;
  }
  return $plugin;
}
