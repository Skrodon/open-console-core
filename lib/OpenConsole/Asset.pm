# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Asset;
use Mojo::Base 'OpenConsole::Mango::Object';

use Log::Report 'open-console-core';

use Scalar::Util  qw(blessed);

use OpenConsole::Util  qw(bson2datetime new_token token_set now);

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
	$insert->{ownerid}   = $owner->id;
	$insert->{ownerclass}= ref $owner;

	my $self = $class->SUPER::create($insert, %args);
	$self;
}

sub fromDB($)
{	my ($class, $data) = @_;
	my $self = $class->SUPER::fromDB($data);

	$self->setData(status => 'expired')
		if $self->status ne 'expired' && $self->hasExpired;

	$self;
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

=method status
=cut

sub status()     { $_[0]->_data->{status} }

#XXX to be removed
sub score() { 100 }

#-------------
=section Maintainance

=method hasExpired
Whether this Asset is still useable, or got invalidated because of time
restrictions.  The Asset form needs to be revisited to get revived again.
Expired assets may be removed from the database, after some time.
=cut

sub hasExpired()
{	my $self = shift;
	return $self->{OP_dead} if exists $self->{OP_dead};
	my $exp  = $self->expires;
	$self->{OP_dead} = defined $exp ? $exp < now : 0;
}

=method expires
Returns the M<DateTime>-object which represents when this Asster will
retire.  Returns C<undef> when no expiration is set.
=cut

sub expires()
{	my $self = shift;
	return $self->{OP_exp} if exists $self->{OP_exp};

	my $exp = $self->_data->{expires};
	$self->{OP_exp} = $exp ? bson2datetime($exp, $self->timezone) : undef;
}

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
=section Action

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

1;
