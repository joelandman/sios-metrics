package Scalable::TSDB::kdb;

use Moose;
use Time::HiRes qw( gettimeofday tv_interval );
use LWP::UserAgent;
use MIME::Base64;

use List::MoreUtils qw(first_index);


has 'host' => ( is => 'rw', isa => 'Str');
has 'port' => ( is => 'rw', isa => 'Int');
has 'user' => ( is => 'rw', isa => 'Str');
has 'pass' => ( is => 'rw', isa => 'Str');
has 'db'   => ( is => 'rw', isa => 'Str');
has 'ssl'  => ( is => 'rw', isa => 'Bool');
has 'debug'=> ( is => 'rw', isa => 'Bool');
has 'suppress_id'=> ( is => 'rw', isa => 'Bool');
has 'suppress_seq'=> ( is => 'rw', isa => 'Bool');
 
use constant true 	=> (1==1);
use constant false 	=> (1==0);


sub connect_db {
	my $self 	= shift;
	return true;
}

sub _request_url {
	my ($self,$endpoint)	= @_;
	my ($url,$scheme,$destination,$query,$q,$p,$type,$form,$content);

	# take arguments of the form $endpoint

	$q = $endpoint;
	# for now, post and get types.  Will need to add more eventually
	$type = (($q =~ /write/) ? 'post' : 'get') ;

	# database is stored in each object
	$q .= '?db='.uri_escape($self->db()) if ($self->db()) ;


	# scheme
	$scheme 	= ($self->ssl() ? "https" : "http");

	# destination (host + port if defined).  localhost is used if host not defined
	$destination  = $self->host() || 'localhost';
	$destination .= ":".$self->port() if ($self->port());

	# specific to InfluxDB.  Change for any others
	$url 		= sprintf '%s://%s/%s',
					$scheme,
					$destination,
					$q;
	printf STDERR "D[%i]  Scalable::TSDB::_request; url = \'%s\'\n",$$,$url if ($self->debug());
	return $url;
}

sub _write_data {
	my ($self,$d) = @_;
	my ($ret,$rc,$output,$res,$h,$return);
	my ($url,$ua,$data,$t0,$tf,%form);

	$url 		= $self->_request_url('write');
	$ua 		= LWP::UserAgent->new('agent' => "Scalable::TSDB::_write_data");

	# data coming in as a simple array reference of strings
	$data = join("\n",@{$d});
	$data .= "\n" if ($data);  # append a \n if we provide data

	printf STDERR "D[%i]  Scalable::TSDB::_write_data; url = \'%s\'\n\t\t\t\tdata = \'%s\'\n",$$,$url,$data if ($self->debug());

	# add user from object into query

	$form{'Authorization'} = join(" ",
					"Basic",
					encode_base64(join(":",$self->user(),$self->pass()))
				     ) if (($self->user()) && ($self->pass()));

	$t0 	= [gettimeofday];
	if (%form) {
		  $ret 	= $ua->post($url,\%form,Content => $data);
	   }
	  else
	   {
		  $ret 	= $ua->post($url,Content => $data);
	   }


	$tf 	= [gettimeofday];
	$return->{content} = $ret->{_content};
	$return->{message} = $ret->{_msg};
	$return->{code}    = $ret->{_rc};
	$return->{time}	   = tv_interval($t0,$tf);

	return $return;
}

__PACKAGE__->meta->make_immutable;

1;
