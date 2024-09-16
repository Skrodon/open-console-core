# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Identity;
use Mojo::Base 'OpenConsole::Mango::Object';

use Log::Report 'open-console-core';

use OpenConsole::Util   qw(new_token);
use OpenConsole::Assets ();

=chapter NAME
OpenConsole::Identity - a person's identity

=chapter DESCRIPTION

An Identity represents one of the ways a person wants to present
him/herself.  See it as: one of the roles a person plays in
society.

A person may decide to make an identity which has very few personal
facts, and one with many detailed information.  Identities may be
validated by organizations.

The Identity should probably support the data in
https://openid.net/specs/openid-connect-basic-1_0-23.html
section 2.4.2.  At least, one method MUST be implemented which produces
these facts.  Work in progress.

=chapter METHODS
=section Constructors
=cut

sub create($%)
{	my ($class, $account, %args) = @_;

	my %insert =
	  (	userid   => $account->id,
		gender   => $account->gender,
		language => $account->preferredLanguage,
	  );

	$class->SUPER::create(\%insert, %args);
}

sub _summary(%)
{	my $self = shift;
	 +(	$self->SUPER::_summary(@_),
		role   => $self->role,
	  );
}

#-------------
=section Attributes
=cut

sub schema()     { '20240111' }
sub element()    { 'identity' }
sub set()        { 'identities' }

# Keep these attributes in sync with the OwnerConsole/Controller/Identities.pm
# method submit_identity()

sub userId()     { $_[0]->_data->{userid} }
sub role()       { $_[0]->_data->{role} }
sub fullname()   { $_[0]->_data->{fullname} }
sub nickname()   { $_[0]->_data->{nickname} }
sub language()   { $_[0]->_data->{language} }
sub gender()     { $_[0]->_data->{gender} }
sub postal()     { $_[0]->_data->{postal} }

sub email()      { $_[0]->_data->{email} }
sub phone()      { $_[0]->_data->{phone} }

sub link()       { '/dashboard/identity/' . $_[0]->id }

sub nameInGroup() { $_[0]->fullname || $_[0]->nickname || $_[0]->role }

#-------------
=section Actions
=cut

sub _load($)  { $::app->users->identity($_[1]) }
sub _remove() { $::app->users->removeIdentity($_[0]) }
sub _save()   { $::app->users->saveIdentity($_[0]) }

sub remove(%)
{	my ($self, %args) = @_;
	$::app->batch->removeEmailsRelatedTo($self->id);
	$self->SUPER::remove(%args);
}

sub usedForGroups() { $::app->users->groupsUsingIdentity($_[0]) }

sub save(%)
{   my ($self, %args) = @_;
	$self->setData(id => new_token 'I') if $self->isNew;
	$self->SUPER::save(%args);
}

1;
