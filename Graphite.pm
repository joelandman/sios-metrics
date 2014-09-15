package Scalable::Graphite;
 
use strict;
use Carp;
use IO::Socket::INET;
use Socket::Class;
use Data::Dumper;

sub new {
    my $this = shift;
    my $args = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub open {
	my ($self,$hinfo) = @_;
	my ($ret,%q,%h,$rc);
	%q 	= %{$hinfo};
	if (1) {
		# IO::Socket::INET
		$h{PeerAddr} 	= defined($q{host})  ? $q{host}  : '127.0.0.1';
		$h{PeerPort}	= defined($q{port})  ? $q{port}  : '2003';
		$h{Proto}		= (defined($q{proto}) ? $q{proto} : 'udp');
		$self->{debug}	= 1 if ($q{debug});
		$self->{db}->{host} = $h{PeerAddr};
		$self->{db}->{port} = $h{PeerPort};
		$self->{db}->{proto} = $h{Proto};
	}
	if (0) {
		# Socket::Class
		$h{remote_addr} 	= defined($q{host})  ? $q{host}  : '127.0.0.1';
		$h{remote_port}		= defined($q{port})  ? $q{port}  : '2003';
		$h{proto}			= (defined($q{proto}) ? $q{proto} : 'udp');
		$self->{debug}	= 1 if ($q{debug});
		$self->{db}->{host} 	= $h{remote_addr};
		$self->{db}->{port} 	= $h{remote_port};
		$self->{db}->{proto} 	= $h{proto};
	}
	printf "D[%i] Scalable::Graphite hinfo = %s\n",$$,Dumper(\%h) if ($self->{debug});


	if (1) {
		$self->{graphite} = IO::Socket::INET->new(%h);
	}
	if (0) {
		$self->{graphite} = Socket::Class->new(%h);
 	}
	if ( !$self->{graphite} ) {
		$ret->{'result'} 		= 'failure';
		if (1) {
			$ret->{'message'}      	= $@;
		}
		if (0) {
			$ret->{'message'}		= Socket::Class->error;
		}
		return $ret;
	}

	$ret->{'result'} 		= 'success';
	return $ret;
}

sub send {
	my ($self,$m) = @_;
	my ($ret,$rc,$msg);
	# {$m -> {metric => ... , value => ... , time => ...}}
	printf "D[%i] Scalable::Graphite m -> %s\n",$$,Dumper($m) if ($self->{debug});
	 
	$msg = join(" ",$m->{metric},$m->{value},$m->{time});
	printf "\n\nD[%i] Scalable::Graphite send +++ %s --- \n\n\n\n",$$,$msg if ($self->{debug});
	$rc = $self->{graphite}->send($msg."\n");
	printf "\n\nD[%i] Scalable::Graphite send complete\n",$$;
	#$rc = `echo $msg | nc $self->{db}->{host} $self->{db}->{port}`; 
	$ret->{'result'} 		= 'success';
	$ret->{'message'}		= $rc;

	return $ret;
}
1;