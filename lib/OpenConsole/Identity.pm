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

#-------------
=section Attributes
=cut

sub schema()     { '20240111' }
sub userId()     { $_[0]->_data->{userid} }

# Keep these attributes in sync with the OwnerConsole/Controller/Identities.pm
# method submit_identity()

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
=section Assets
=cut

sub assets() { $_[0]->{OI_assets} ||= OpenConsole::Assets->new(owner => $_[0]) }

#-------------
=section Actions
=cut

sub _remove($)
{	my ($self, $acount) = @_;
	$::app->batch->removeEmailsRelatedTo($self->id);
	$::app->users->removeIdentity($self);
}

sub usedForGroups() { $::app->users->groupsUsingIdentity($_[0]) }

sub save(%)
{   my ($self, %args) = @_;
	$self->_data->{id} = new_token 'I' if $self->id eq 'new';
	if($args{by_user})
    {	$self->_data->{schema} = $self->schema;
		$self->log('changed identity settings');
	}
    $::app->users->saveIdentity($self);
}

1;
