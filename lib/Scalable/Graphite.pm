package Scalable::Graphite;
 
use strict;
use Carp;
use IO::Socket::INET;
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
		$h{PeerAddr} 	= defined($q{host})  ? $q{host}  : '127.0.0.1';
		$h{PeerPort}	= defined($q{port})  ? $q{port}  : '2003';
		$h{Proto}		= (defined($q{proto}) ? $q{proto} : 'udp');
		$self->{debug}	= 1 if ($q{debug});
		$self->{db}->{host} = $h{PeerAddr};
		$self->{db}->{port} = $h{PeerPort};
		$self->{db}->{proto} = $h{Proto};
	printf "D[%i] Scalable::Graphite hinfo = %s\n",$$,Dumper(\%h) if ($self->{debug});


		$self->{graphite} = IO::Socket::INET->new(%h);
	if ( !$self->{graphite} ) {
		$ret->{'result'} 		= 'failure';
		$ret->{'message'}      	= $@;
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
	printf "\n\nD[%i] Scalable::Graphite send complete\n",$$ if ($self->{debug});
	#$rc = `echo $msg | nc $self->{db}->{host} $self->{db}->{port}`; 
	$ret->{'result'} 		= 'success';
	$ret->{'message'}		= $rc;

	return $ret;
}
1;
