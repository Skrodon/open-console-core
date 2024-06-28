# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Proof;
use Mojo::Base 'OpenConsole::Mango::Object';

use Log::Report 'open-console-core';

use Scalar::Util  qw(blessed);
use DateTime      ();

use OpenConsole::Util  qw(bson2datetime new_token);

=chapter DESCRIPTION
Base class for all kinds of proofs of ownership.

=chapter METHODS
=section Constructors
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	$insert->{schema} or panic;
	$insert->{set}       = $class->set;
	$insert->{proofid}   = 'new';
	$insert->{status}    = 'unproven';
	$insert->{score}     = 0;

	my $owner = delete $insert->{owner} or panic;
	$insert->{ownerid}   = $owner->ownerId;
	$insert->{ownerclass}= ref $owner;

	my $self = $class->SUPER::create($insert, %args);
	$self;
}

sub fromDB($)
{	my ($class, $data) = @_;
	my $self = $class->SUPER::fromDB($data);

	$self->setStatus('expired')
		if $self->status ne 'expired' && $self->hasExpired;

	$self;
}

#-------------
=section Attributes
=cut

# Must be extended
sub set()     { ... }
sub element() { ... }
sub sort()    { ... }

sub isNew()      { $_[0]->proofId eq 'new' }

# Keep these attributes in sync with the OwnerConsole/Controller/Proof.pm
# method submit_group()

sub algorithm()  { $_[0]->_data->{algorithm} }
sub ownerClass() { $_[0]->_data->{ownerclass} }
sub ownerId()    { $_[0]->_data->{ownerid} }
sub proofId()    { $_[0]->_data->{proofid} }
sub prover()     { $_[0]->_data->{prover} }
sub schema()     { $_[0]->_data->{schema} }
sub score()      { $_[0]->_data->{score} }
sub status()     { $_[0]->_data->{status} }

sub expires()
{	my $self = shift;
	return $self->{OP_exp} if exists $self->{OP_exp};

	my $exp = $self->_data->{expires};
	$self->{OP_exp} = $exp ? (bson2datetime $exp, $self->timezone) : undef;
}

sub hasExpired()
{	my $self = shift;
	return $self->{OP_dead} if exists $self->{OP_dead};
	my $exp  = $self->expires;
	$self->{OP_dead} = defined $exp ? $exp < DateTime->now : 0;
}

sub elemLink()   { '/dashboard/' . $_[0]->element . '/' . $_[0]->proofId }

#-------------
=section Ownership
=cut

sub owner($)
{	my ($self, $account) = @_;
	return $self->{OP_owner} if $self->{OP_owner};

	my $class = $self->ownerClass;
	if($class->isOwnedByMe)
	{	$account->userId eq $self->ownerId
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
sub isOwnedByGroup($) { $_[0]->ownerId eq $_[1]->groupId }

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

sub setStatus($)
{	my ($self, $new) = @_;
	$self->setData(status => $new);
	$self;
}

#-------------
=section Validation

Validation administration.
=cut

sub invalidate() { $_[0]->setStatus('unproven') }

sub isInvalid()  { $_[0]->status ne 'proven' }

#-------------
=section Action
=cut

sub save(%)
{   my ($self, %args) = @_;
	$self->setData(proofid => new_token 'P') if $self->proofId eq 'new';

	if($args{by_user})
    {	$self->setData(schema => $self->schema);
		$self->log('changed proof settings');
	}

    $::app->proofs->saveProof($self);
}

sub delete() { $::app->proofs->deleteProof($_[0]) }

sub accepted()
{	my $self = shift;
	$self->setData(expires => undef);
	$self->setStatus('proven');
}

1;
