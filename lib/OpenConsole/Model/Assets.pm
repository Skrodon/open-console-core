# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Model::Assets;
use Mojo::Base -base;

use Log::Report 'open-console-core';

use Mango::BSON ':bson';

use OpenConsole::Assets         ();

=chapter NAME
OpenConsole::Model::Assets - database for collected assets

=chapter DESCRIPTION

collections:
=over 4
=item * 'proofs'
All kinds of proofs are in one table, to give fast access to them.
They are only accessible via their id and they owner (Account, Identity, Group).

=item * 'contracts'
The signed service contracts.  These are also searcheable by service.

=item * 'services'
Not a proof, but nothing special, hence currenly included in the proofs
table.

=back

=cut

=chapter METHODS

=section Attributes
=cut

has db         => undef;
has proofs     => sub { $_[0]->{OMB_proof} ||= $_[0]->db->collection('proofs')};
has contracts  => sub { $_[0]->{OMB_contr} ||= $_[0]->db->collection('contracts')};

sub upgrade
{	my $self = shift;
	$self->_upgrade_proofs
		-> _upgrade_contracts;
}

#---------------------
=section Generic
=cut

#XXX may get redundant when the summary is available
sub assetForOwner($$)
{	my ($self, $set, $owner) = @_;
	$set eq 'contracts' ? $self->contractsForOwner($set, $owner) : $self->proofsForOwner($set, $owner);
}

#---------------------
=section Proofs
All kinds of proof are moved to the same table.
=cut

sub _upgrade_proofs()
{	my $self = shift;
	$self->proofs->ensure_index({ id => 1 }, { unique => bson_true });
	$self->proofs->ensure_index({ ownerid => 1 }, { unique => bson_false });
	$self->proofs->ensure_index({ identid => 1 }, { unique => bson_false });
	$self;
}

sub proofsForOwner($$)
{	my ($self, $set, $owner) = @_;
	my $proofs = $self->proofs->find({ownerid => $owner->id, set => $set})->all;
	map OpenConsole::Assets->assetFromDB($_), @$proofs;
}

sub saveProof($)
{	my ($self, $asset) = @_;
	$self->proofs->save($asset->toDB);
}

sub proof($)
{	my ($self, $proofid) = @_;
	my $data = $self->proofs->find_one({id => $proofid});
	$data ? OpenConsole::Assets->assetFromDB($data) : undef;
}

sub deleteProof($)
{	my ($self, $proof) = @_;
	$self->proofs->remove({ id => $proof->id });
}

#---------------------
=section Contracts
The Service use contracts.
=cut

sub _upgrade_contracts()
{	my $self = shift;
	$self->contracts->ensure_index({ id => 1 }, { unique => bson_true });
	$self->contracts->ensure_index({ ownerid => 1 }, { unique => bson_false });
	$self->contracts->ensure_index({ identid => 1 }, { unique => bson_false });
	$self->contracts->ensure_index({ serviceid => 1 }, { unique => bson_false });
	$self;
}

sub contractsForOwner($$)
{	my ($self, $set, $owner) = @_;
	my $contracts = $self->contracts->find({ownerid => $owner->id, set => $set})->all;
	map OpenConsole::Assets->assetFromDB($_), @$contracts;
}

sub saveContract($)
{	my ($self, $asset) = @_;
	$self->contract->save($asset->toDB);
}

sub contract($)
{	my ($self, $contractid) = @_;
	my $data = $self->contracts->find_one({id => $contractid});
	$data ? OpenConsole::Assets->assetFromDB($data) : undef;
}

sub deleteContract($)
{	my ($self, $contract) = @_;
	$self->contracts->remove({ id => $contract->id });
}

#---------------------
=section Services
Hidden in the proofs table.
=cut

*serviceSearch = \&proofSearch;
*saveService   = \&saveProof;
*service       = \&proof;
*deleteService = \&deleteProof;


1;
