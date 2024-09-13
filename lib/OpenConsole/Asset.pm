# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Asset;
use Mojo::Base 'OpenConsole::Mango::Object';

use Log::Report 'open-console-core';

use Scalar::Util  qw(blessed);
use DateTime      ();

use OpenConsole::Util  qw(bson2datetime new_token);

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
	$insert->{schema} or panic;
	$insert->{set}       = $class->set;
	$insert->{proofid}   = 'new';

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
=cut

sub ownerClass() { $_[0]->_data->{ownerclass} }
sub ownerId()    { $_[0]->_data->{ownerid} }

#-------------
=section Maintainance
=cut

sub hasExpired()
{	my $self = shift;
	return $self->{OP_dead} if exists $self->{OP_dead};
	my $exp  = $self->expires;
	$self->{OP_dead} = defined $exp ? $exp < DateTime->now : 0;
}

sub expires()
{	my $self = shift;
	return $self->{OP_exp} if exists $self->{OP_exp};

	my $exp = $self->_data->{expires};
	$self->{OP_exp} = $exp ? bson2datetime($exp, $self->timezone) : undef;
}

sub owner($)
{	my ($self, $account) = @_;
	return $self->{OP_owner} if $self->{OP_owner};

	my $class = $self->ownerClass;
	if($class->isOwnedByMe)
	{	$account->id eq $self->ownerId
			or error __x"Account does not own the proof anymore.";
		return $self->{OP_owner} = $account;
	}

	if($class->ownerClass->isa('OpenConsole::Identity'))
	{	my $identity = $account->identity($self->ownerId)
			or error __x"Missing identity.";
		return $self->{OP_owner} = $identity;
	}

	if($class->ownerClass->isa('OpenConsole::Group'))
	{	my $group = $account->group($self->ownerId)
			or error __x"Not member of the owner group anymore.";
		return $self->{OP_owner} = $group;
	}

	panic "Unknown owner type $class";
}

sub isOwnedByMe()     { $_[0]->ownerClass->isa('OpenConsole::Account') }
sub isOwnedByGroup($) { $_[0]->ownerId eq $_[1]->id }

# The identity which is related to this proof.  This may change by external
# factors.

sub identity($)
{	my ($self, $account) = @_;
	$self->isOwnedByMe ? $account->preferredIdentity : $self->owner->memberIdentityOf($account);
}

sub changeOwner($$)
{	my ($self, $account, $ownerid) = @_;
	$self->setData(ownerid => $ownerid);
	delete $self->{OP_owner};
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
		$self->log('user upgraded asset structure');
	}

    $::app->asset->saveAsset($self);
}

=method delete
Flag this proof for deletion.
=cut

sub delete() { $::app->assets->deleteAsset($_[0]) }

1;
