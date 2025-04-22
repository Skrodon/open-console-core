# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Assets;
use Mojo::Base -base;

use Log::Report 'open-console-core';

use Scalar::Util    qw(blessed);

use OpenConsole::Proof::EmailAddr ();
use OpenConsole::Proof::Website   ();
use OpenConsole::Asset::Contract  ();
use OpenConsole::Asset::Service   ();
use OpenConsole::Util             qw(sorted);

# All ::Proof:: extends ::Asset
my %asset_class = (
	emailaddrs => 'OpenConsole::Proof::EmailAddr',
	websites   => 'OpenConsole::Proof::Website',
	contracts  => 'OpenConsole::Asset::Contract',
	services   => 'OpenConsole::Asset::Service',
);

my @proof_sets = qw/emailaddrs websites/;

=chapter NAME
OpenConsole::Assets - handling sets of Assets

=chapter DESCRIPTION
Manage a set of assets for an owner, which could be an Account, an
(personal) Identity, or a Group (identity).

=chapter METHODS
=section Constructors
=cut

#------------------
=section Attributes

=method owner
Returns the owner object for this asset.
=cut

has owner => sub { error "Requires owner" }, weak => 1;

=method assetClass $set
Translates a asset group name into the package which implements the
asset.
=cut

sub assetClass($) { $asset_class{$_[1]} }

=ci_method proofSets
Returns a list of all implemented proof types.  They are in the preferred
order of display.
=cut

sub proofSets()   { @proof_sets }

#------------------
=section Ownership
=cut

sub ownerId()         { $_[0]->owner->id }
sub ownedByPerson()   { $_[0]->owner->isa('OpenConsole::Account')  }
sub ownedByIdentity() { $_[0]->owner->isa('OpenConsole::Identity') }
sub ownedByGroup()    { $_[0]->owner->isa('OpenConsole::Group')    }

#------------------
=section Separate Assets

=ci_method assetFromDB $data
=cut

sub assetFromDB($)
{	my ($thing, $data) = @_;
	my $set   = $data->{set};
	my $class = $asset_class{$set} or panic "Unknown asset set '$set'";
	$class->fromDB($data);
}

=method for $set, [$identity|$identityid|undef]
We are always loading whole sets of assets at once, because we usually need them all and there are
usually just a few.

When an $identity is provided, then only the assets which match that will be returned.
=cut

sub _set($)
{	my ($self, $set) = @_;
	$self->{"OA_$set"} ||= +{ map +($_->id => $_), $::app->assets->assetForOwner($set, $self->owner) };
}

sub for($;$)
{	my $self = shift;
	my $set  = $self->_set(shift);
	@_ or return sorted values %$set;

	my $idid = shift || 'undef';
	$idid    = $idid->id if blessed $idid;

	sorted
		grep +($_->identityId || 'undef') eq $idid,
			values %$set;
}

sub asset($$)
{	my ($self, $set, $asset_id) = @_;
	my $list = $self->_set($set);
	$list->{$asset_id};
}

#------------------
=section Actions
=cut

1;
