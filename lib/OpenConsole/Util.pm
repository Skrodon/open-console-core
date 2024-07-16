# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Util;
use Mojo::Base 'Exporter';

use Log::Report    'open-console-core';

use DateTime       ();
use Email::Valid   ();
use List::Util     qw(first);
use LWP::UserAgent ();
use Session::Token ();
use Time::HiRes    ();
use DateTime       ();
use JSON::PP       ();

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

our @EXPORT_OK = (@is_valid, @validators, @bool, qw(
	flat
	bson2datetime
	timestamp
	new_token
	reseed_tokens
	get_page
	user_agent
));

our %EXPORT_TAGS = (
   validate => [ @is_valid, @validators ],
   bool => \@bool,
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
	$text =~ s/[ \t]{2,}/ /gr =~ s/ $//gmr =~ s/\n{2,}/\n/gr;
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
sub is_valid_zulu($)  { $_[0] =~ m!^[0-9]{4}-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z$! }

#----------
=section MongoDB
=function bson2datetime $timezone
Represent a timestamp in the MongoDB specific time format (M<Mango::BSON::Time>), in
human readible form.
=cut

sub bson2datetime($$)
{	my ($stamp, $tz) = @_;
	$stamp ? DateTime->from_epoch(epoch => $stamp->to_epoch)->set_time_zone($tz) : undef;
}

=function timestamp [$datetime]
=cut

sub timestamp(;$)
{	my $stamp = shift || DateTime->now;
	$stamp->set_time_zone('Z');
	$stamp->iso8601 . 'Z';
}

#-----------
=section Tokens
Tokens are cryptographically strong unique codes.  There is no protection against the
generation of dupplicates, because that chance is uncredably small.

The unique part is preceeded by a code for the Open Console server instance, and a prefix
which indicate its application.  The latter mainly for debugging purposes.

Token prefixes:

   A = Account
   C = Challenge
   G = Group identity
   I = personal Identity
   M = send eMail
   N = iNvite email
   P = proof

=function new_token $prefix
=function reseed_tokens
=cut

my $token_generator = Session::Token->new;
sub new_token($)      { state $i = $::app->config->{instance}; "$i:${_[0]}:" . $token_generator->get }
sub reseed_tokens()   { $token_generator = Session::Token->new }

sub is_valid_token($) { $_[0] =~ m!^[a-z0-9]{5,8}\:[A-Z]\:[a-zA-Z0-9]{10,50}$! }

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

1;