# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Model::Assets;
use Mojo::Base 'OpenConsole::Model';

use Log::Report 'open-console-core';

use Mango::BSON ':bson';

use OpenConsole::Assets    ();

use OpenConsole::Util      qw(token_set);

=chapter NAME
OpenConsole::Model::Assets - database for collected assets

=chapter DESCRIPTION

collections:
=over 4
=item * 'proofs'
All kinds of proofs are in one table, to give fast access to them.
They are only accessible via their id and their owner (Account, Identity, Group).

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
	$self->SUPER::upgrade(@_);
	$self->_upgrade_proofs->_upgrade_contracts;
}

#---------------------
=section Generic
=cut

#XXX may get redundant when the summary is available
sub assetForOwner($$)
{	my ($self, $set, $owner) = @_;
	$set eq 'contracts' ? $self->contractsForOwner($set, $owner) : $self->proofsForOwner($set, $owner);
}

sub asset($)
{	my ($self, $id) = @_;
	token_set $id eq 'contract' ? $self->contract($id) : $self->proof($id);
}

#---------------------
=section Proofs
All kinds of proof are moved to the same table.
=cut

sub _upgrade_proofs()
{	my $self  = shift;
	my $table = $self->proofs;
	$self->_upgrade($table);
	$table->ensure_index({ id => 1 }, { unique => bson_true });
	$table->ensure_index({ ownerid => 1 }, { unique => bson_false });
	$table->ensure_index({ identid => 1 }, { unique => bson_false });
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

sub removeProof($)
{	my ($self, $proof) = @_;
	$self->proofs->remove({ id => $proof->id });
}

#---------------------
=section Contracts
The Service use contracts.
=cut

sub _upgrade_contracts()
{	my $self  = shift;
	my $table = $self->contracts;
	$self->_upgrade($table);
	$table->ensure_index({ id => 1 }, { unique => bson_true });
	$table->ensure_index({ ownerid => 1 }, { unique => bson_false });
	$table->ensure_index({ identid => 1 }, { unique => bson_false });
	$table->ensure_index({ serviceid => 1 }, { unique => bson_false });
	$self;
}

sub contractsForOwner($$)
{	my ($self, $set, $owner) = @_;
	my $contracts = $self->contracts->find({ownerid => $owner->id, set => $set})->all;
	map OpenConsole::Assets->assetFromDB($_), @$contracts;
}

#XXX Once we have the summary, we do not need to search
sub contractsForService($$)
{	my ($self, $owner, $service) = @_;
	my $sid = blessed $service ? $service->id : $service;

	my $contracts = $self->contracts->find({ownerid => $owner->id, serviceid => $sid })->all;
	map OpenConsole::Assets->assetFromDB($_), @$contracts;
}

sub saveContract($)
{	my ($self, $asset) = @_;
	$self->contracts->save($asset->toDB);
}

sub contract($)
{	my ($self, $contractid) = @_;
	my $data = $self->contracts->find_one({id => $contractid});
	$data ? OpenConsole::Assets->assetFromDB($data) : undef;
}

sub removeContract($)
{	my ($self, $contract) = @_;
	$self->contracts->remove({ id => $contract->id });
}

#---------------------
=section Services
Hidden in the proofs table.
=cut

sub servicesForOwner($$)
{	my ($self, $set, $owner) = @_;
	my $services = $self->proofs->find({ownerid => $owner->id, set => $set})->all;
	map OpenConsole::Assets->assetFromDB($_), @$services;
}

sub saveService($)
{	my ($self, $asset) = @_;
	$self->proofs->save($asset->toDB);
}

sub service($)
{	my ($self, $id) = @_;

	my $data = $self->proofs->find_one({id => $id});
	$data ? OpenConsole::Assets->assetFromDB($data) : undef;
}

sub removeService($)
{	my ($self, $service) = @_;
	$self->proofs->remove({ id => $service->id });
}

=method publicServiceIndex %options
produce an ARRAY of owners (sorted by name), each containing an ARRAY of offered
enabled services (also sorted by name)
=cut

sub publicServiceIndex()
{	my ($self, %args) = @_;
	my %owners;
warn "#1";
	my $services = $self->proofs->find({ set => 'services', status => 'public' })->all;
use Data::Dumper;
warn "#2 ", Dumper $services;
	push @{$owners{$_->{ownerid}}{services}}, +{ id => $_->{id}, name => $_->{name} }
		for @$services;

	foreach my $ownerid (keys %owners) {
		my $owner = $::app->users->getOwner($ownerid) or next;   # disappeared?
		$owners{$ownerid}{name} = $owner->name;
	}

	[ sort { $a->{name} cmp $b->{name} } values %owners ];
}

1;
