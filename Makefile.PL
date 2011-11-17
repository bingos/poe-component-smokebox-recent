use strict;
use inc::Module::Install;
name 'POE-Component-SmokeBox-Recent';
author 'Chris Williams <chris@bingosnet.co.uk>';
license 'perl';
auto_license holder => 'Chris Williams';
version_from 'lib/POE/Component/SmokeBox/Recent.pm';
abstract_from 'lib/POE/Component/SmokeBox/Recent.pm';
readme_from 'lib/POE/Component/SmokeBox/Recent.pm';
author_tests 'xt';
perl_version '5.006';
build_requires 'Test::More' => 0.47;
build_requires 'Test::POE::Server::TCP' => 0.14;
build_requires 'HTTP::Date' => 0;
build_requires 'HTTP::Response' => 0;
requires 'CPAN::Recent::Uploads' => 0.06;
requires 'URI' => 0;
requires 'HTTP::Request' => 0;
requires 'Net::IP::Minimal' => 0;
requires 'POE' => 0.38;
requires 'POE::Component::Client::DNS' => 1.02;
requires 'POE::Filter::HTTP::Parser' => 1.06;
requires 'Test::POE::Client::TCP' => 0.08;
clean_files 'network.tests';
my $value;
if ( $Module::Install::AUTHOR ) {
  $value = 'y';
}
else {
  $value = prompt( 'Do you want live network tests [N/y]?', 'N' );
}
if ( $value =~ /^y$/i ) {
  open FH, "> network.tests" or die "$!\n";
  print FH "Bleh\n";
  close FH;
}
githubmeta;
auto_provides;
makemaker_args(dist => { PREOP => "$^X ./tools/git-log.pl > ./Changes" });
WriteAll();
