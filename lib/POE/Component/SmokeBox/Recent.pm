package POE::Component::SmokeBox::Recent;

use strict;
use warnings;
use Carp;
use POE qw(Component::SmokeBox::Recent::HTTP Component::SmokeBox::Recent::FTP);
use URI;
use HTTP::Request;
use File::Spec;
use vars qw($VERSION);

$VERSION = '1.16';

sub recent {
  my $package = shift;
  my %opts = @_;
  $opts{lc $_} = delete $opts{$_} for keys %opts;
  croak "$package requires a 'url' argument\n" unless $opts{url};
  croak "$package requires an 'event' argument\n" unless $opts{event};
  my $options = delete $opts{options};
  my $self = bless \%opts, $package;
  $self->{uri} = URI->new( $self->{url} );
  croak "url provided is of an unsupported scheme\n" 
	unless $self->{uri}->scheme and $self->{uri}->scheme =~ /^(ht|f)tp$/;
  $self->{session_id} = POE::Session->create(
	object_states => [
	   $self => [ qw(_start _process_http _process_ftp _recent) ],
	   $self => { 
		      http_sockerr  => '_get_connect_error',
		      http_timeout  => '_get_connect_error',
		      http_response => '_http_response',
		      ftp_sockerr   => '_get_connect_error',
		      ftp_error     => '_get_error',
		      ftp_data      => '_get_data',
		      ftp_done      => '_get_done', },
	],
	heap => $self,
	( ref($options) eq 'HASH' ? ( options => $options ) : () ),
  )->ID();
  return $self;
}

sub _start {
  my ($kernel,$sender,$self) = @_[KERNEL,SENDER,OBJECT];
  $self->{session_id} = $_[SESSION]->ID();
  if ( $kernel == $sender and !$self->{session} ) {
	croak "Not called from another POE session and 'session' wasn't set\n";
  }
  my $sender_id;
  if ( $self->{session} ) {
    if ( my $ref = $kernel->alias_resolve( $self->{session} ) ) {
	$sender_id = $ref->ID();
    }
    else {
	croak "Could not resolve 'session' to a valid POE session\n";
    }
  }
  else {
    $sender_id = $sender->ID();
  }
  $kernel->refcount_increment( $sender_id, __PACKAGE__ );
  $kernel->detach_myself();
  $self->{sender_id} = $sender_id;
  $kernel->yield( '_process_' . $self->{uri}->scheme );
  return;
}

sub _recent {
  my ($kernel,$self,$type) = @_[KERNEL,OBJECT,ARG0];
  my $target = delete $self->{sender_id};
  my %reply;
  $reply{recent} = delete $self->{recent} if $self->{recent};
  $reply{error} = delete $self->{error} if $self->{error};
  $reply{context} = delete $self->{context} if $self->{context};
  $reply{url} = delete $self->{url};
  my $event = delete $self->{event};
  $kernel->post( $target, $event, \%reply );
  $kernel->refcount_decrement( $target, __PACKAGE__ );
  return;
}

sub _process_http {
  my ($kernel,$self) = @_[KERNEL,OBJECT];
  $self->{uri}->path( File::Spec::Unix->catfile( $self->{uri}->path(), 'RECENT' ) );
  POE::Component::SmokeBox::Recent::HTTP->spawn(
	uri => $self->{uri},
  );
  return;
}

sub _http_response {
  my ($kernel,$self,$response) = @_[KERNEL,OBJECT,ARG0];
  if ( $response->code() == 200 ) {
    for ( split /\n/, $response->content() ) {
       next unless /^authors/;
       next unless /\.(tar\.gz|tgz|tar\.bz2|zip)$/;
       s!authors/id/!!;
       push @{ $self->{recent} }, $_;
    }
  }
  else {
    $self->{error} = $response->as_string();
  }
  $kernel->yield( '_recent', 'http' );
  return;
}

sub _process_ftp {
  my ($kernel,$self) = @_[KERNEL,OBJECT];
  POE::Component::SmokeBox::Recent::FTP->spawn(
        Username => 'anonymous',
        Password => 'anon@anon.org',
        address  => $self->{uri}->host,
	port	 => $self->{uri}->port,
	path     => File::Spec::Unix->catfile( $self->{uri}->path, 'RECENT' ),
  );
  return;
}

sub _get_connect_error {
  my ($kernel,$self,@args) = @_[KERNEL,OBJECT,ARG0..$#_];
  $self->{error} = join ' ', @args;
  $kernel->yield( '_recent', 'ftp' );
  return;
}

sub _get_error {
  my ($kernel,$self,$sender,@args) = @_[KERNEL,OBJECT,SENDER,ARG0..$#_];
  $self->{error} = join ' ', @args;
  $kernel->yield( '_recent', 'ftp' );
  return;
}

sub _get_data {
  my ($kernel,$self,$data) = @_[KERNEL,OBJECT,ARG0];
  return unless $data =~ /^authors/i;
  return unless $data =~ /\.(tar\.gz|tgz|tar\.bz2|zip)$/;
  $data =~ s!authors/id/!!;
  push @{ $self->{recent} }, $data;
  return;
}

sub _get_done {
  my ($kernel,$self,$sender) = @_[KERNEL,OBJECT,SENDER];
  $kernel->yield( '_recent', 'ftp' );
  return;
}

1;
__END__

=head1 NAME

POE::Component::SmokeBox::Recent - A POE component to retrieve recent CPAN uploads.

=head1 SYNOPSIS

  use strict;
  use POE qw(Component::SmokeBox::Recent);

  $|=1;

  POE::Session->create(
	package_states => [
	  'main' => [qw(_start recent)],
	],
  );

  $poe_kernel->run();
  exit 0;

  sub _start {
    POE::Component::SmokeBox::Recent->recent( 
	url => 'http://www.cpan.org/',
	event => 'recent',
    );
    return;
  }

  sub recent {
    my $hashref = $_[ARG0];
    if ( $hashref->{error} ) {
	print $hashref->{error}, "\n";
	return;
    }
    print $_, "\n" for @{ $hashref->{recent} };
    return;
  }

=head1 DESCRIPTION

POE::Component::SmokeBox::Recent is a L<POE> component for retrieving recently uploaded CPAN distributions 
from the CPAN mirror of your choice.

It accepts a url and an event name and attempts to download and parse the RECENT file from that given url.

It is part of the SmokeBox toolkit for building CPAN Smoke testing frameworks.

=head1 CONSTRUCTOR

=over

=item recent

Takes a number of parameters:

  'url', the full url of the CPAN mirror to retrieve the RECENT file from, only http and ftp are currently supported, mandatory;
  'event', the event handler in your session where the result should be sent, mandatory;
  'session', optional if the poco is spawned from within another session;
  'context', anything you like that'll fit in a scalar, a ref for instance;

The 'session' parameter is only required if you wish the output event to go to a different
session than the calling session, or if you have spawned the poco outside of a session.

The poco does it's work and will return the output event with the result.

=back

=head1 OUTPUT EVENT

This is generated by the poco. ARG0 will be a hash reference with the following keys:

  'recent', an arrayref containing recently uploaded distributions; 
  'error', if something went wrong this will contain some hopefully meaningful error messages;
  'context', if you supplied a context in the constructor it will be returned here;

=head1 AUTHOR

Chris C<BinGOs> Williams <chris@bingosnet.co.uk>

=head1 LICENSE

Copyright C<(c)> Chris Williams

This module may be used, modified, and distributed under the same terms as Perl itself. Please see the license that came with your Perl distribution for details.

=head1 KUDOS

Andy Armstrong for helping me to debug accessing his CPAN mirror. 

=head1 SEE ALSO

L<POE>

L<http://cpantest.grango.org/>

L<POE::Component::Client::HTTP>

L<POE::Component::Client::FTP>

=cut
