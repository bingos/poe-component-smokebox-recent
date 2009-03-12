use strict;
use warnings;
use Test::More;
#sub POE::Component::Client::FTP::DEBUG () { 1 }
use POE qw(Component::SmokeBox::Recent::FTP Filter::Line);
use Test::POE::Server::TCP;

my %tests = (
   'USER anonymous' 	=> '331 Any password will work',
   'PASS anon@anon.org' => '230 Any password will work',
   'SIZE /pub/CPAN/RECENT' => '550 /pub/CPAN/RECENT: No such file or directory',
   'QUIT' 		=> '221 Goodbye.',
);

plan tests => 9;

POE::Session->create(
   package_states => [
	main => [qw(
			_start 
			_stop
			testd_registered 
			testd_connected
			testd_disconnected
			testd_client_input
                        testd_client_input
			ftp_error
		)],
   ],
   heap => { tests => \%tests, types => [ [ '200', 'Type set to A' ], [ '200', 'Type set to I' ] ] },
);

$poe_kernel->run();
exit 0;

sub _start {
  my $heap = $_[HEAP];
  $heap->{testd} = Test::POE::Server::TCP->spawn(
#    filter => POE::Filter::Line->new,
    address => '127.0.0.1',
  );
  my $port = $heap->{testd}->port;
  $heap->{remote_port} = $port;
  return;
}

sub _stop {
  pass("Done");
  return;
}

sub testd_registered {
  my ($kernel,$heap) = @_[KERNEL,HEAP];
  my $ftp = POE::Component::SmokeBox::Recent::FTP->spawn(
        address => '127.0.0.1',
	port => $heap->{remote_port},
	path => '/pub/CPAN/RECENT',
  );
  isa_ok( $ftp, 'POE::Component::SmokeBox::Recent::FTP' );
  return;
}

sub testd_connected {
  my ($kernel,$heap,$id,$client_ip,$client_port,$server_ip,$server_port) = @_[KERNEL,HEAP,ARG0..ARG4];
  diag("$client_ip,$client_port,$server_ip,$server_port\n");
  my @banner = (
	'220---------- Welcome to Pure-FTPd [privsep] ----------',
	'220-You are user number 228 of 1000 allowed.',
	'220-Local time is now 18:46. Server port: 21.',
	'220-Only anonymous FTP is allowed here',
	'220 You will be disconnected after 30 minutes of inactivity.',
  );
  pass("Client connected");
  $heap->{testd}->send_to_client( $id, $_ ) for @banner;
  return;
}

sub testd_disconnected {
  my ($kernel,$heap) = @_[KERNEL,HEAP];
  pass("Client disconnected");
  $heap->{testd}->shutdown();
  delete $heap->{testd};
  return;
}

sub testd_client_input {
  my ($kernel, $heap, $id, $input) = @_[KERNEL, HEAP, ARG0, ARG1];
  diag($input);
  if ( defined $heap->{tests}->{ $input } ) {
     pass($input);
     my $response = delete $heap->{tests}->{ $input };
     $heap->{testd}->disconnect( $id ) unless scalar keys %{ $heap->{tests} };
     $heap->{testd}->send_to_client( $id, $response );
  }
  return;
}

sub ftp_error {
  ok( $_[ARG0] eq '550 /pub/CPAN/RECENT: No such file or directory', $_[ARG0] );
  return;
}

 sub _default {
     my ($event, $args) = @_[ARG0 .. $#_];
     return 0 if $event eq '_child';
     my @output = ( "$event: " );

     for my $arg (@$args) {
         if ( ref $arg eq 'ARRAY' ) {
             push( @output, '[' . join(' ,', @$arg ) . ']' );
         }
         else {
             push ( @output, "'$arg'" );
         }
     }
     print join ' ', @output, "\n";
     return 0;
 }
