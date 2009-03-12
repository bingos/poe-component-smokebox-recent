use strict;
use warnings;
use Test::More tests => 3;
BEGIN { use_ok( 'POE::Component::SmokeBox::Recent' ); };
BEGIN { use_ok( 'POE::Component::SmokeBox::Recent::FTP' ); };
BEGIN { use_ok( 'POE::Component::SmokeBox::Recent::HTTP' ); };
diag( "Testing POE::Component::SmokeBox::Recent-$POE::Component::SmokeBox::Recent::VERSION, POE-$POE::VERSION, Perl $], $^X" );
