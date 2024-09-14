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
=item * 'assets'
All kinds of collectables are put in the same table: proofs, contracts, services, and
more to come.  They are only accessible via their id and they owner (Account, Identity,
Group).

=back

=cut

=chapter METHODS

=section Attributes
=cut

has db         => undef;
has assets     => sub { $_[0]->{OMB_assets} ||= $_[0]->db->collection('assets')};

sub upgrade
{	my $self = shift;
	$self->assets->ensure_index({ id => 1 }, { unique => bson_true });
	$self->assets->ensure_index({ ownerid => 1 }, { unique => bson_false });
	$self;
}

#---------------------
=section Assets

All kinds of assets are moved to the same table.
=cut

sub assetSearch($$)
{	my ($self, $set, $ownerid) = @_;
	my $assets = $self->assets->find({ownerid => $ownerid, set => $set})->all;
	map OpenConsole::Assets->assetFromDB($_), @$assets;
}

sub saveAsset($)
{	my ($self, $asset) = @_;
	$self->assets->save($asset->toDB);
}

sub asset($)
{	my ($self, $assetid) = @_;
	my $data = $self->assets->find_one({id => $assetid})
		or return;

	OpenConsole::Assets->assetFromDB($data);
}

sub deleteAsset($)
{	my ($self, $asset) = @_;
	$self->assets->remove({ id => $asset->id });
}

1;
