# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Proof::Website;
use Mojo::Base 'OpenConsole::Asset::Proof';

use Log::Report 'open-console-core';

use OpenConsole::Util;

use Encode       qw(decode);

=chapter NAME
OpenConsole::Proof::Website - collects proofs of website ownership

=chapter DESCRIPTION
Contains a proof of website ownership.

=chapter METHODS
=section Constructors
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	$class->SUPER::create($insert, %args);
}

#-------------
=section Attributes
=cut

sub schema()   { '20240218' }
sub element()  { 'website'  }
sub set()      { 'websites' }
sub elemName() { __"Website" }
sub setName()  { __"Websites" }
sub iconFA()   { 'fa-solid fa-file-circle-check' }

sub website()  { $_[0]->_data->{website} }
*name = \&website;

sub challenge()      { $_[0]->_data->{challenge} }

sub verifyURL()      { $_[0]->_data->{verifyURL} || {}}
sub verifyURLTrace() { $_[0]->_data->{verifyURLTrace} || []}
sub allDNSSEC()      { $_[0]->verifyURL->{dns_check}{all_dnssec} }

sub hostPunicode()   { $_[0]->verifyURL->{host_puny} }
sub hostUTF8()       { $_[0]->verifyURL->{host_utf8} }
sub normalizedURL()  { $_[0]->verifyURL->{url_normalized} }
sub printableURL()   { $_[0]->verifyURL->{url_printable} }

sub proofTrace()     { $_[0]->_data->{proofTrace} || [] }

#-------------
=section Data
=cut

sub forGrant(@)
{	my $self = shift;
	$self->SUPER::forGrant(
		dnssec => bool($self->allDNSSEC),
		@_,
	);
}

#-------------
=section Action
=cut

# See https://github.com/Skrodon/open-console-owner/wiki/Proof-Website-Ownership/
# and lib/TasksConsole/Prover/Website.pm

sub score(%)
{	my ($self, %args) = @_;
	$self->status eq 'proven' or return 0;

	my $score = 0;
	$score   += 20 if $self->allDNSSEC;

	my $study = $self->study;
	$score += 40 if $study->{challenge};

	my $algo  = $study->{algorithm};
	if($algo eq 'dns')
	{	$score += 10 if $study->{txt_dnssec};
	}
	else
	{	$score += 10 if $study->{use_https};
	}

	$score;
}

=method link [$path]
Compose a link to a page on this website.  When the status of the proof is
questionable, no link will be made.
=cut

sub link(;$)
{	my ($self, $path) = @_;
	return undef if $self->hasExpired;

	my $ws = $self->website;
	defined $path && length $path or return $ws;

	($ws =~ s!/$!!r) . '/' . ($path =~ s!^/!!r);
}

1;
