# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Asset;
use Mojo::Base 'OpenConsole::Mango::Object';

use Log::Report 'open-console-core';

use Scalar::Util  qw(blessed);

use OpenConsole::Util  qw(new_token token_set now);

=chapter NAME
OpenConsole::Asset - base class for any kind of collectables

=chapter DESCRIPTION
Base class for all kinds of assets which can be collected by
a login.

=chapter METHODS
=section Constructors
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	$insert->{set}       = $class->set;

	my $owner = delete $insert->{owner} or panic;
warn "ASSET CREATE OWNER ", $owner->id;
	$insert->{ownerid}   = $owner->id;

	$class->SUPER::create($insert, %args);
}

#-------------
=section Attributes

=method ownerClass
The Perl class implementation for the owner type.  This can be either
M<OpenConsole::Account> or M<OpenConsole::Group>.

=method ownerId
The Id of the owner of this Asset, either an Account or a Group identifier.
The M<ownerClass()> tells you which kind, if that's important (usually not).

=method identityId
When the owner is an Account, then this Id will tell you whether it is
managed by a personal Identity of that user.
=cut

sub ownerId()    { $_[0]->_data->{ownerid} }
sub identityId() { $_[0]->_data->{identid} }

#XXX to be removed
sub score() { 100 }

#-------------
=section Maintainance

=method owner
Returns the owner of this Asset, either an Account or a Group.

=method isOwnedByMe
Returns whether this Asset is owned by the current Account.

=method isOwnedByGroup ($group|$groupid)
Check whether a certain group owns this asset.
=cut

sub owner($)
{	my ($self, $account) = @_;
	$self->{OP_owner} ||= $self->isOwnedByMe ? $account : $account->group($self->ownerId);
}

sub isOwnedByMe()     { token_set($_[0]->ownerId) eq 'account' }
sub isOwnedByGroup($) { my $id = blessed $_[1] ? $_[1]->id : $_[1]; $_[0]->ownerId eq $id }

=method identity $account
The identity which is related to this asset.  This may change by external
factors.
=cut

sub identity($)
{	my ($self, $account) = @_;
	$self->isOwnedByMe ? $account->preferredIdentity : $self->owner->memberIdentityOf($account);
}

=method changeOwner $account, ($who|$whoid)
Change $who is the owner of this asset.  When the new owner is an
identity, than it will be assigned to the $account with a note about the
identity.  When the new owner is a group, then this has big implications
for every member of the group.
=cut

sub changeOwner($$)
{	my ($self, $account, $who) = @_;
	my $id = blessed $who ? $who->id : $who;

	my ($ownerid, $identid) = token_set($id) eq 'identity' ? ($account->id, $id) : ($id, undef);
	$self->setData(ownerid => $ownerid, identid => $identid);
warn "Owner changed to $ownerid, ", $identid ? "identity $identid" : "";

	delete $self->{OP_owner};
	$self;
}

#-------------
=section Actions

=method save %options
Save this proof to the database.  When it does not have an ID yet, then
it will get assigned on.

=option  by_user BOOLEAN
=default by_user <false>
When a user saves this form, it is accepting the data changes which require
human intervention.  Automated procedures may also update the schema, when
they are sure that no user action is required.
=cut

sub save(%)
{   my ($self, %args) = @_;
	$self->id ne 'new' or panic "assign an id before saving";

	if($args{by_user})
    {	$self->setData(schema => $self->schema);
		$self->log('User upgraded asset structure');
	}

warn "Saving asset ".$self->id;
	$self->_save($self);
}

=method delete
Flag this proof for deletion.
=cut

sub delete()
{	my $self = shift;
warn "Removing asset ".$self->id;
	$self->_remove($self);
}

sub forGrant(@)
{	my $self = shift;
	#!!! The id and created are usually not passed.

	$self->SUPER::forGrant(
		status  => $self->status,
		expires => $self->expires,
		updated => $self->updated,
		@_,
	);
}

1;
