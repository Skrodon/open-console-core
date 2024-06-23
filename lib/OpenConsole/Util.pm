# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Util;
use Mojo::Base 'Exporter';

use Log::Report    'open-console-core';

use Email::Valid   ();
use List::Util     qw(first);
use DateTime       ();
use Session::Token ();

my @is_valid = qw(
	is_valid_date
	is_valid_email
	is_valid_phone
	is_valid_url
);

my @validators = qw(
	val_line
	val_text
);

our @EXPORT_OK = (@is_valid, @validators, qw(
	flat
	bson2datetime
	new_token
	reseed_tokens
));

our %EXPORT_TAGS = (
   validate => [ @is_valid, @validators ],
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
sub new_token($)    { state $i = $::app->config->{instance}; "$i:${_[0]}:" . $token_generator->get }
sub reseed_tokens() { $token_generator = Session::Token->new }

1;
