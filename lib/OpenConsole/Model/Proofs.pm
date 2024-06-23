# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Model::Proofs;
use Mojo::Base -base;

use Log::Report 'open-console-core';

use Mango::BSON ':bson';

use OpenConsole::Proofs         ();

=chapter DESCRIPTION

collections:
=over 4
=item * 'proofs'
=back

=cut

=chapter METHODS

=section Attributes
=cut

has db         => undef;
has proofs     => sub { $_[0]->{OMB_proofs}  ||= $_[0]->db->collection('proofs')};

sub upgrade
{	my $self = shift;

	$self->proofs->ensure_index({ proofid => 1 }, { unique => bson_true  });
	$self->proofs->ensure_index({ ownerid => 1 }, { unique => bson_false });

	$self;
}

#---------------------
=section Proofs

All kinds of proofs are moved to the same table.
=cut

sub proofSearch($$)
{	my ($self, $set, $ownerid) = @_;
	my $proofs = $self->proofs->find({ownerid => $ownerid, set => $set})->all;
	map OpenConsole::Proofs->proofFromDB($_), @$proofs;
}

sub saveProof($)
{	my ($self, $proof) = @_;
	$self->proofs->save($proof->toDB);
}

sub proof($)
{	my ($self, $proofid) = @_;
	my $data = $self->proofs->find_one({proofid => $proofid})
		or return;

	OpenConsole::Proofs->proofFromDB($data);
}

sub deleteProof($)
{	my ($self, $proof) = @_;
	$self->proofs->remove({ proofid => $proof->proofId });
}

1;
