# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Util;
use Mojo::Base 'Exporter';

use Log::Report    'open-console-core';

use Crypt::PBKDF2  ();
use DateTime       ();
use DateTime::Format::ISO8601 ();
use DateTime::Format::Duration::ISO8601 ();
use Email::Valid   ();
use File::Slurper  qw/read_lines/;
use JSON::PP       ();
use List::Util     qw(first);
use LWP::UserAgent ();
use Mango::BSON::Time ();
use Mojo::URL      ();
use Session::Token ();
use Time::HiRes    ();

my @is_valid = qw(
	is_valid_date
	is_valid_email
	is_valid_phone
	is_valid_url
	is_valid_zulu
	is_valid_token
);

my @validators = qw(
	val_line
	val_text
);

my @bool = qw(
	true
	false
	bool
);

my @tokens = qw(
	new_token
	reseed_tokens
	token_infix
	token_set
	token_class
	is_valid_token
);

my @time = qw(
	bson2datetime
	dt2bson
	timestamp2bson
	timestamp
	timestamp2dt
	duration
	duration2secs
	now
);
	
our @EXPORT_OK = (@is_valid, @validators, @bool, @tokens, @time, qw(
	flat
	get_page
	user_agent
	domain_suffix
	encrypt_secret
	verify_secret
	is_private_ipv4
	is_private_ipv6
	url
));

our %EXPORT_TAGS = (
	validate => [ @is_valid, @validators ],
	bool     => \@bool,
	tokens   => \@tokens,
	time     => \@time,
);

=chapter NAME

OpenConsole::Util - collection of useful functions

=chapter FUNCTIONS

=section Practical

=function flat @anything
Flatten ARRAYs into elements, and remove undefined elements from the list.
=cut

sub flat(@) { grep defined, map ref eq 'ARRAY' ? @$_ : $_, @_ }

#----------
=section Validation
=cut

sub val_line($)
{	my $line = shift;
	defined $line && $line =~ /\S/ or return undef;
	$line =~ s/\s{2,}/ /gr =~ s/^ //r =~ s/ $//gr;
}

sub val_text($)
{	my $text = shift;
	defined $text && $text =~ /\S/ or return undef;
	$text =~ s/\r\n?/\n/gr =~ s/[ \t]+/ /gr =~ s/ $//gmr =~ s/\n{2,}\Z/\n/gr;
}

sub is_valid_email($) { Email::Valid->address($_[0]) }
sub is_valid_phone($) { $_[0] =~ m!^\+[0-9 \-]{4,}(?:/.+)?! }
sub is_valid_date($)  { $_[0] =~ s! ^\s* ([0-9]{4}) (?:[-/ ]?) ([0-9]{2}) (?:[-/ ]?)? ([0-9]{2}) \s*$ !$1-$2-$3!r }

sub is_valid_url($)
{	# Only a first check: needs to be normalized
	defined $_[0] && $_[0] =~ m!^
		https?://               # scheme
                                # no username/password
		[\w\-]+(\.[\w\-){1,}\.? # hostname
		(?: \: [0-9]+ )?        # port
		(?: / [^?#]* )?         # path, no query or fragment
	$ !x;
}

# The timestamps I generate myself
sub is_valid_zulu($)
{	$_[0] =~ m!^[0-9]{4}-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z$!;
}

#----------
=section Time

=function bson2datetime $bson_time, [$timezone]
Convert a timestamp in the MongoDB specific time format (M<Mango::BSON::Time>) into
a M<DateTime> object.
=cut

sub bson2datetime($;$)
{	my ($stamp, $tz) = @_;
	$stamp ? DateTime->from_epoch(epoch => $stamp->to_epoch)->set_time_zone($tz // 'Z') : undef;
}

=function dt2bson $dt
Convert a M<DateTime> object into a MongoDB time object.
=cut

sub dt2bson($)
{	my $dt = shift or return;
	Mango::BSON::Time->new($dt->epoch * 1000);
}

=function timestamp2bson $iso8601
Convert an timestamp in string format to a bson time object.
=cut

#XXX Most timestamps are in "YYYY...Z" string format to prepare for move to CouchDB, but
#XXX in rare cases, we need a MongoDB BSON::Time object.  Mainly for automatic expire.
sub timestamp2dt($);
sub timestamp2bson($)
{	my $stamp = shift or return;
	dt2bson timestamp2dt $stamp;
}

=function now
Returns the current time in UTC as M<DateTime> object.
=cut

sub now() { DateTime->now(time_zone => 'Z') }

=function timestamp [$datetime]
=cut

sub timestamp(;$)
{	my $stamp = @_ ? (shift->set_time_zone('Z')) : now();
	$stamp->iso8601 . 'Z';
}

=function timestamp2dt $iso8601
Convert any kind of ios8601 formatted time into a M<DateTime> object.
=cut

sub timestamp2dt($)
{	DateTime::Format::ISO8601->parse_datetime($_[0]);
}

=function duration $iso8601
Parse a iso8601 duration string (like C<P2W1DT15H>) into a M<DateTime::Duration> object.
Returns C<undef> on failure.  Returns the parameter when it is already a duration object.
=cut

my $dur = DateTime::Format::Duration::ISO8601->new(on_error => sub {});
sub duration($)
{	my $d = shift;
	blessed $d && $d->isa('DateTime::Duration') ? $d : defined $d ? $dur->parse_duration($d) : undef;
}

=function duration2secs $duration
From a M<DateTime::Duration> object into a number of seconds, for an average situation.
=cut

sub duration2secs($)
{	my $dur = shift or return undef;
	my %d   = $dur->deltas;
	# DateTime::Duration internal storage really sucks: hours and years are faked
	(($d->{months} * 30 + $d->{days}) * 24*60 + $d->{minutes}) * 60 + $d->{seconds};
}

#-----------
=section Tokens
Tokens are cryptographically strong unique codes.  There is no protection against the
generation of duplicates, because that chance is uncredibly small.

The unique part is preceeded by a code for the Open Console server instance, and a prefix
which indicate its application.  The latter mainly for debugging purposes.  The total will
never exceed 63 characters.
=cut

my %token_infixes = (
	A => [ account    => 'OpenConsole::Account'  ],
	C => [ contract   => 'OpenConsole::Asset::Contract' ],
	G => [ group      => 'OpenConsole::Group'    ],
	H => [ challenge  => undef                   ],  # cHallenge
	I => [ identity   => 'OpenConsole::Identity' ],
	M => [ email      => undef                   ],  # send eMail
	N => [ invite     => undef                   ],  # iNvite email
	P => [ proof      => 'OpenConsole::Asset::Proof'   ],
	R => [ comply     => 'ConnectConsole::Comply'      ],  # Run connection
	S => [ service    => 'OpenConsole::Asset::Service' ],
	T => [ appsession => 'ConnectConsole::AppSession'  ],  # Temporary application session id
);

=function new_token $prefix
=function reseed_tokens
=function is_valid_token $token
=function token_infix $token
=function token_set $token
=function token_class $token
=cut

my $token_generator = Session::Token->new;
sub new_token($)      { state $i = $::app->config->{instance}; "$i:${_[0]}:" . $token_generator->get }
sub reseed_tokens()   { $token_generator = Session::Token->new }
sub is_valid_token($) { $_[0] =~ m!^[a-z0-9]{5,8}\:[A-Z]\:[a-zA-Z0-9]{10,50}$! }
sub token_infix($)    { $_[0] =~ m!\:(.)\:! ? $1 : undef }
sub token_set($)      { my $i = token_infix $_[0]; $i ? $token_infixes{$i}[0] : undef }
sub token_class($)    { my $i = token_infix $_[0]; $i ? $token_infixes{$i}[1] : undef }

#-----------
=section Browser client
=cut

my $ua;
sub user_agent()
{	$ua ||= LWP::UserAgent->new(
		agent        => 'Open Console Verifier',
		from         => 'support@open-console.eu',
		max_redirect => 0,
		max_size     => 1_000_000,
	);
}

sub get_page($$)
{	my ($session, $url) = @_;

	my $start    = Time::HiRes::time;
	my $response = user_agent->get($url);
	my $code     = $response->code;

	my $elapse   = int( (Time::HiRes::time - $start) * 1000 ) . 'ms';
	my $size     = length $response->content;
	my $size_k   = $size > 2.5*1024 ? int(($size+512)/1024).'k' : $size.'b';
	my $ct       = $response->content_type || 'no-content-type';

	$session->_trace("GET $url returned $code");
	$session->_trace("Downloaded in $elapse, $size_k $ct");

	( $response,
	  +{ url => $url, fetched => timestamp(), elapse => $elapse, size => $size, content_type => $ct },
	);
}

#-----------
=section JSON

When creating JSON, be careful with booleans: booleans which are written to the database must
be encoded into 'true' and 'false' to be compatible with other programming languages, and the
database language.
=cut

sub true()  { JSON::PP::true }
sub false() { JSON::PP::false }
sub bool($) { $_[0] ? JSON::PP::true : JSON::PP::false }

#-----------
=section Domain-names and IP

=method domain_suffix $name
Split a given (host~) $name into an (optional) host part, an
(optional) registered domain-name, and the public suffix.
The name MUST be in utf8 form.

The host may contain dots, also the suffix.
The public suffix list is distributed with Linux, and maintained
by Mozilla.

=example Split a domain
  my ($host, $domain, $suffix) = domain_suffix "www.nos.nl";
  #    -> ('www', 'nos', 'nl')
  # bbc.co.uk -> (undef, 'bbc', 'co.uk')
=cut

use constant SOURCE => '/usr/share/publicsuffix/public_suffix_list.dat';
my (%excluded, %wildcard, %suffix);

BEGIN
{	foreach my $line (read_lines SOURCE)
	{	next if $line =~ m,^\s*$|^\/\/,;   # blank line or comment

		   if($line =~ s/^!//)    { undef $excluded{$line} }
		elsif($line =~ s/^\*\.//) { undef $wildcard{$line} }
		else                      { undef $suffix{$line}   }
	}
}

sub domain_suffix($);
sub domain_suffix($)
{	my $name = shift;
	return (undef, undef, $name)
		if exists $suffix{$name};

	my ($first, $rest) = split /\./, $name, 2;
	return (undef, undef, $name)
		if ! defined $rest
		|| (exists $wildcard{$rest} && ! exists $excluded{$name});

	my ($host, $domain, $suffix) = domain_suffix $rest;

	   if(!defined $domain) { $domain = $first }
	elsif( defined $host)   { $host   = "$first.$host" }
	else                    { $host   = $first }

	($host, $domain, $suffix);
}

=method is_private_ipv4 $address
Returns true when the address (in dotted notation) is not a valid public
ipv4 address available to websites.  RFC1918
=cut

sub is_private_ipv4($)
{	$_[0] =~
	  m/ ^  10 \.
	   | ^ 127 \. 0
	   | ^ 172 \. (?: 1[6-9]|2[0-9]|3[01] ) \.
	   | ^ 192 \. 168 \.
	   | ^ (?: 22[4-9] | 23[0-9] ) \.
	   | ^ 255 \. 255 \. 255 \. 255 $
	   /x;
}

=method is_private_ipv6 $address
Returns true when the address (in dotted notation) is not a valid public
ipv6 address, available to websites.
=cut

sub is_private_ipv6($)
{	$_[0] !~ m/ ^ (?: 64 | 2002 ) \: /x;
}

=method url $url
Parse the $url into a M<Mojo::URL> object.
=cut

sub url($)
{	my $u = shift // return undef;
	blessed $u && $u->isa('Mojo::URL') ? $u : Mojo::URL->new($u);
}

#--------------
=section secrets

=function encrypt_secret $secret
Hide a shared secret token (like a password) in a strong hash.
=cut

my $crypt = Crypt::PBKDF2->new;

sub encrypt_secret($)
{	my $secret = shift;
	 +{	encrypted => $crypt->generate($secret),
		algorithm => 'PBKDF2',
	  };
}

=function verify_secret $encrypted, $secret
The $encrypted structure was produced by M<encrypt_secret()>.
=cut

sub verify_secret($$)
{	my ($encr, $secret) = @_;
	$crypt->validate($encr->{encrypted}, $secret);
}

1;
