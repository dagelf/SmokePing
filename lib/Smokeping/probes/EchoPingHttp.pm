package Smokeping::probes::EchoPingHttp;

=head1 301 Moved Permanently

This is a Smokeping probe module. Please use the command 

C<smokeping -man Smokeping::probes::EchoPingHttp>

to view the documentation or the command

C<smokeping -makepod Smokeping::probes::EchoPingHttp>

to generate the POD document.

=cut

use strict;
use base qw(Smokeping::probes::EchoPing);
use Carp;

sub pod_hash {
	return {
		name => <<DOC,
Smokeping::probes::EchoPingHttp - an echoping(1) probe for SmokePing
DOC
		overview => <<DOC,
Measures HTTP roundtrip times (web servers and caches) for SmokePing.
DOC
		notes => <<DOC,
You should consider setting a lower value for the C<pings> variable than the
default 20, as repetitive URL fetching may be quite heavy on the server.

The I<fill>, I<size> and I<udp> EchoPing variables are not valid for EchoPingHttp.
DOC
		authors => <<'DOC',
Niko Tyni <ntyni@iki.fi>
DOC
		see_also => <<DOC,
L<Smokeping::probes::EchoPing>, L<Smokeping::probes::EchoPingHttps>
DOC
	}
}

sub _init {
	my $self = shift;
	# HTTP doesn't fit with filling or size
	my $arghashref = $self->features;
	delete $arghashref->{size};
	delete $arghashref->{fill};
}

# tag the port number after the hostname
sub make_host {
	my $self = shift;
	my $target = shift;

	my $host = $self->SUPER::make_host($target);
	my $port = $target->{vars}{port};

	$host .= ":$port" if defined $port;
	return $host;
}

sub proto_args {
	my $self = shift;
	my $target = shift;
	my $url = $target->{vars}{url};

	my @args = ("-h", $url);

	# -A : ignore cache
	my $ignore = $target->{vars}{ignore_cache};
	$ignore = 1 
		if (defined $ignore and $ignore ne "no" 
			and $ignore ne "0");
	push @args, "-A" if $ignore and not exists $self->{_disabled}{A};

	# -a : force cache to revalidate the data
	my $revalidate = $target->{vars}{revalidate_data};
	$revalidate= 1 if (defined $revalidate and $revalidate ne "no" 
		and $revalidate ne "0");
	push @args, "-a" if $revalidate and not exists $self->{_disabled}{a};

	return @args;
}

sub test_usage {
	my $self = shift;
	my $bin = $self->{properties}{binary};
	croak("Your echoping binary doesn't support HTTP")
		if `$bin -h/ 127.0.0.1 2>&1` =~ /(invalid option|not compiled|usage)/i;
	if (`$bin -a -h/ 127.0.0.1 2>&1` =~ /(invalid option|not compiled|usage)/i) {
		carp("Note: your echoping binary doesn't support revalidating (-a), disabling it");
		$self->{_disabled}{a} = undef;
	}

	if (`$bin -A -h/ 127.0.0.1 2>&1` =~ /(invalid option|not compiled|usage)/i) {
		carp("Note: your echoping binary doesn't support ignoring cache (-A), disabling it");
		$self->{_disabled}{A} = undef;
	}

	$self->SUPER::test_usage;
	return;
}

sub ProbeDesc($) {
        return "HTTP pings using echoping(1)";
}

sub targetvars {
	my $class = shift;
	my $h = $class->SUPER::targetvars;
	delete $h->{udp};
	delete $h->{fill};
	delete $h->{size};
	$h->{timeout}{default} = 10;
	$h->{timeout}{example} = 20;
	return $class->_makevars($h, {
		url => {
			_doc => <<DOC,
The URL to be requested from the web server or cache. Can be either relative
(/...) for web servers or absolute (http://...) for caches.
DOC
			_default => '/',
		},
		port => {
			_doc => 'The TCP port to use.',
			_example => 80,
			_re => '\d+',
		},
		ignore_cache => {
			_doc => <<DOC,
The echoping(1) "-A" option: force the proxy to ignore the cache.
Enabled if the value is anything other than 'no' or '0'.
DOC
			_example => 'yes',
		},
		revalidate_data => {
			_doc => <<DOC,
The echoping(1) "-a" option: force the proxy to revalidate data with original 
server. Enabled if the value is anything other than 'no' or '0'.
DOC
			_example => 'no',
		},
	});
}

1;
