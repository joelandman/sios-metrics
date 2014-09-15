sios-metrics.pl
===========

Gather metrics from a system and send to a graphite or InfluxDB database 


Dependencies:
-------------

*  Perl 5.10 or higher
*  several Perl modules ([Config::JSON](http://search.cpan.org/~rizen/Config-JSON-1.5100/lib/Config/JSON.pm), [IPC::Run](http://search.cpan.org/~toddr/IPC-Run-0.92/lib/IPC/Run.pm), [Getopt::Lucid](http://search.cpan.org/~dagolden/Getopt-Lucid-1.05/lib/Getopt/Lucid.pm),

    
Installing dependencies:
------------------------

We will simplify this in the future with an installer, and likely snapshots of the relevant modules and dependencies, or use PAR::Dist.

*  Perl:  Should be included in your distribution/OS.  If not, your options are 
*  Linux:    Included in distribution
*  MacOSX:   Included in distribution
*  Windows:  
  *  [ActiveState Perl](http://www.activestate.com/activeperl/downloads)
  *  [StrawBerry Perl](http://strawberryperl.com/)
  *  [Cygwin](https://www.cygwin.com/) and installing the Perl components


### OS ReadLine library ###

Should be included in your distribution/OS
*    Linux:    Included in distribution, make sure the /readline/i packages (library/development) are installed
*    MacOSX:   Included in distribution, make sure the /readline/i packages (library/development) are installed
*    Windows:  Cygwin or http://gnuwin32.sourceforge.net/packages/readline.htm 

### Perl modules ###
Some of these modules are not included in the package manager distributions, so you will need to use CPAN to install (let it autoconfigure for you, and use the sudo mechanism)
   
* Linux and MacOSX

  `sudo cpan   Getopt::Lucid Config::JSON IPC::Run `

  
* Windows:  ActiveState has ppm, Cygwin and StrawBerry Perl have cpan, so use the same approach for Linux here.


[Scalable Informatics](https://scalableinformatics.com) supplies a pre-built stack with all the dependencies and Perl 5.18.2 or 5.20.0 installed on our appliances, located in the /opt/scalable/ pathway.  If you would like to be able to use this, please contact us.  We may use this path in the usage examples below.

Installation
------------
   * copy the `sios-metrics.pl` and `lib/` to a path where you will access it from, either in your search path, or at a fixed location that you will always use.

    `sudo cp sios-metrics.pl $PATH`

   and `perl -V | tail 20` , look for the @INC, and place your lib/ directory into one of the include directories (call it $INC)

    `sudo cp -r lib/Scalable $INC`

   * copy the etc directory to a reasonable location.  We use 

    `/opt/scalable/etc`

    but you can use anything that makes sense for your installation. Call this path `$PATH_TO_CONFIG_FILE/`


Usage
-----

    /opt/scalable/bin/sios-metrics.pl \
        --config $PATH_TO_CONFIG_FILE/sios-metrics.conf
  
  
    
where sios-metrics.conf might look something like this:

    # config-file-type: JSON 1
    {
      "global" : {
        "log_to_file" : "1",
        "log_name" : "/tmp/metrics-$system.log",
      },
      
      "db" : {
        "host"    : "a.b.c.d",
        "port"    : "2003",
        "proto"   : "tcp"
      },
      
      "metrics" : {      
        
        "uptime" : {
          "command"   : "$path_to_plugins/uptime.pl",
          "interval"  : 5,
          "timeout"   : 2                
        },
        
        "MHz" : {
          "command"   : "$path_to_plugins/MHz.pl",
          "interval"  : 4,
          "timeout"   : 2                
        },
      } 
    }

The host -> a.b.c.d is either the ip address or DNS name of the host.  We'd recommend using the IP address as it saves a lookup upon opening the port.  The port is the receiving port of the database, and the proto is either tcp or udp.

You may set up a listener on a remote server to capture this data as it comes in, rather than dump it to a database.  

      nc -k -l a.b.c.d $port

running in a console will show you what sios-metrics.pl sends over the wire.  This is very useful for debugging and testing.

Each metric is given a name, and the underlying JSON block specifies 3 items:
  * command to run to return the metric
  * interval in seconds between runs of the command
  * a timeout value indicating the maximum amount of time that should be alloted to running the command.  No metric is returned if a timeout occurs.

You may also, on a per metric basis, specify a host, port, and proto for that metric.  That is, you can have different metrics go to different destinations.

The metrics will return a very simple structure of 

      key:value\n

where key will be sent to the graphite or influxdb with a 'hostname.' prepended to it, a timestamp appended to it, and the value can be anything.  The '\n' is a newline character.  If you send a string as data, it would be advisable to enclose it in quotes.

You may write the metric plugins in any language available on the platform, as long as they return data as indicated.

Once data starts being collected and sent to the database, if a time series of name 'hostname.key' does not exist, it will be created, and the data will be stored in that time series.


Theory of operation
-------------------

Each metric is given its own process, its own timer, and its own network apparatus.  Each metric is a small plugin code that runs and provides values.  It is up to the user to decide what constitutes meaningful and valid data.  Several example plugins are provided, and you may use these as the basis to write your own.  A curated plugin repository will be created.

The beauty of this architecture is that you can debug plugins before deploying them, by running them on the command line.  Plugins are designed to do one thing, and do it well.  They do not need to be complex.

Internally a microsecond timer is used, and a first order correction for transit through each processes loop body is measured and accounted for.  A second order correction will be calculated to account for timer drift versus time of day clock, but this is not yet implemented.  Currently the drift rates vary on a platform basis, to about 10 milliseconds per hour after the first order correction.

The plugins do not need to run with elevated priveleges unless you need them to acquire priveleged data.  You may use sudo for this in an appropriately configured manner, or work out a priveleged proxy that the plugin can obtain data from.  



Limitations:

  A number of features not yet implemented.   


Plans:
  * an installer
  * config files via URI/URL/http[s] 
  * plugin metrics via URI/URL/http[s]
  * continuous execution of plugins, so that the startup cost is paid once, and the plugin handles the sleep/waking interval, and writes to a pipe/output
  * reporting failures/faults in plugins
  * security audit/hardening
  * encryption of results over the wire (not simply SSL)
  * broad/multi-cast of results to several different databases
  * more intelligent signal handling (HUP ->  restart and reread config files, STOP -> pause metrics, START -> continue collection, )


Bugs:

  

TODO
--------

Everything else


AUTHOR
=======

Joe Landman (landman@scalableinformatics.com)


COPYRIGHT
=========
2012-2014 Scalable Informatics Inc


LICENSE
=======
GPL v2 only.