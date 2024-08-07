# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

use ExtUtils::MakeMaker;

use 5.016;

WriteMakefile
 ( NAME     => 'Open-Console-Core'
 , VERSION  => '0.01'

 , PREREQ_PM    => { 
	'Crypt::PBKDF2'		=> 0,
	'Data::Dumper'		=> 0,
	'DateTime'			=> 1.50,
	'Devel::GlobalDestruction' => 0,
	'Email::Valid'		=> 0,
	'Encode'			=> 0,
	'JSON::PP'			=> 0,
	'List::Util'		=> 0,
	'Log::Report'		=> 0,
	'LWP::UserAgent'	=> 0,
	'Mango'				=> 0,
	'Mango::BSON'		=> 0,
	'Mango::BSON::Time'	=> 0,
	'Mojo::Base'		=> 0,
	'Mojolicious'       => 0,
	'Net::LibIDN'		=> 0,
	'Scalar::Util'		=> 0,
	'Session::Token'	=> 1.503,
	'Time::HiRes'		=> 0,
   }
 , EXE_FILES    => []
 , AUTHOR       => 'Open Console <team@open-console.eu>'
 , ABSTRACT     => 'Open Console Core Components'
 , LICENSE      => 'perl_5'

 , META_MERGE =>
      { 'meta-spec' => { version => 2 }
      , resources  =>
          { repository =>
              { type => 'git'
              , url  => 'https://github.com/Skrodon/open-console-core.git'
              , web  => 'https://github.com/Skrodon/open-console-core'
              }
          , homepage => 'http://open-console.eu'
          , license  => [ 'http://dev.perl.org/licenses/' ]
          }
      }
 );

### used by oodist during production of distribution
sub MY::postamble { <<'__POSTAMBLE' }

# for DIST
RAWDIR          = /tmp/OpenConsole/raw
DISTDIR         = /tmp/OpenConsole/source

# for POD
FIRST_YEAR      = 2024
EMAIL           = mark@open-console.eu
EXTENDS         = 
WEBSITE         = http://perl.overmeer.net/open-console

__POSTAMBLE
