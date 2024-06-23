# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Proofs;
use Mojo::Base -base;

use Log::Report 'open-console-core';

#XXX "Proofs" may have been "Collectables", but in the wider sence, a contract
#XXX is also a kind of proof: a proof that you agreed communicating.

use Scalar::Util    qw(blessed);

use OpenConsole::Proof::EmailAddr1 ();
use OpenConsole::Proof::Website1   ();
use OpenConsole::Proof::Contract1  ();

my %proofclass = (
	emailaddr1 => 'OpenConsole::Proof::EmailAddr1',
	website1   => 'OpenConsole::Proof::Website1',
	contract1  => 'OpenConsole::Proof::Contract1',
);

=chapter DESCRIPTION

=chapter METHODS
=section Constructors
=cut

#------------------
=section Attributes
=cut

has owner => sub { error "Requires owner" }, weak => 1;

#------------------
=section Ownership
=cut

sub ownerId()         { $_[0]->owner->ownerId }
sub ownedByPerson()   { $_[0]->owner->isa('OpenConsole::Account')  }
sub ownedByIdentity() { $_[0]->owner->isa('OpenConsole::Identity') }
sub ownedByGroup()    { $_[0]->owner->isa('OpenConsole::Group')    }

#------------------
=section Separate Proofs

=ci_method proofFromDB $data
=cut

sub proofFromDB($)
{	my ($thing, $data) = @_;
	my $algo  = $data->{algorithm};
	my $class = $proofclass{$algo} or panic "Unknown proof algorithm $algo";
	$class->fromDB($data);
}

=method for SET
We are always loading whole sets of proofs at once, because we usually need them all and there are
usually just a few.
=cut

sub _set($)
{	my ($self, $set) = @_;
	$self->{"OP_$set"} ||= +{ map +($_->proofId => $_),  $::app->proofs->proofSearch($set, $self->ownerId) };
}

sub for($) { my $set = $_[0]->_set($_[1]); sort { $a->sort cmp $b->sort } values %$set }

sub proof($$)
{	my ($self, $set, $proofid) = @_;
	my $list = $self->_set($set);
	$list->{$proofid};
}

#------------------
=section Actions
=cut


1;
