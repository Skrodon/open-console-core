# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Account;
use Mojo::Base 'OpenConsole::Mango::Object';

use Log::Report 'open-console-core';

use Mango::BSON::Time ();
use Crypt::PBKDF2     ();
my $crypt = Crypt::PBKDF2->new;

use OpenConsole::Util     qw(new_token);
use OpenConsole::Identity ();
use OpenConsole::Proofs   ();

use constant ACCOUNT_SCHEMA => '20240102';

=section Constructors
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	my $userid = $insert->{userid} = new_token 'A';
	$insert->{schema}    //= ACCOUNT_SCHEMA;
	$insert->{languages} //= [ 'en', 'nl' ];
	$insert->{iflang}    //= 'en';

	my $password = delete $insert->{password};

	my $self = $class->SUPER::create($insert, %args);

	$self->log("created account $userid");
	$self->changePassword($password);
	$self;
}

sub fromDB($)
{   my ($class, $data) = @_;
	if($data->{schema} < ACCOUNT_SCHEMA) {
		# We may need to upgrade the user object partially automatically,
		# partially with the user's help.
	}
	$class->SUPER::fromDB($data);
}

#------------------
=section Attributes
=cut

#### Keep these attributes in sync with OwnerConsole::Collector::Account::submit()

sub schema()    { $_[0]->_data->{schema} }
sub ownerId()   { $_[0]->userId }

sub userId()    { $_[0]->_data->{userid} }
sub email()     { $_[0]->_data->{email}  }
sub birth()     { $_[0]->_data->{birth_date} }
sub gender()    { $_[0]->_data->{gender} }
sub languages() { @{$_[0]->_data->{languages} || []} }
sub phone()     { $_[0]->_data->{phone_number} }
sub iflang()    { $_[0]->_data->{iflang} }
sub timezone()  { $_[0]->_data->{timezone} }
sub reset()     { $_[0]->_data->{reset} }

sub identityIds() { @{$_[0]->_data->{identities} || []} }
sub groupIds()    { @{$_[0]->_data->{groups} || []} }

sub isAdmin()   { $_[0]->{OA_admin} ||= $::app->isAdmin($_[0]) }
sub preferredLanguage { ($_[0]->languages)[0] }
sub orderedLang() { join ',', $_[0]->languages }

sub nrIdentities { scalar $_[0]->identityIds }
sub nrGroups     { scalar $_[0]->groupIds }
sub link()       { '/dashboard/account/' . $_[0]->userId }

=method localTime $timestamp
Convert a timestamp C<"YYYY-mm-DDTHH::MM::SSZ"> (as produced by M<OpenConsole::Util::timestamp()>)
into a printable time, in the timezone of the account.
=cut

sub localTime($)
{	my ($self, $stamp) = @_;
	$stamp =~ /^([0-9]{4}\-([01][0-9])\-([0-3][0-9])T([0-2][0-9])\:([0-5][0-9])\:([0-5][0-9])Z$/ or panic $stamp;
	my $dt = DataTime->new(year => $1, month => $2, day => $3,
		hour => $4, minute => $5, second => $6,
		time_zone => $self->timezone);
	$dt->...
}

#------------------
=section Password handling
=cut

sub encryptedPassword { $_[0]->_data->{password}{encrypted} }

sub correctPassword($)
{	my ($self, $password) = @_;
	$crypt->validate($self->encryptedPassword, $password);
}

sub changePassword($)
{	my ($self, $password) = @_;
	$self->_data->{password} = +{
		encrypted => $crypt->generate($password),
		algorithm => 'PBKDF2',
	};
	$self->log("changed password");
	$self;
}

sub startPasswordReset($)
{	my ($self, $token) = @_;
	$self->_data->{reset} = +{
		token     => $token,
		initiated => Mango::BSON::Time->new,
		by        => $ENV{REMOTE_HOST},
	};
	$self->log("start password reset $token");
}

sub correctResetToken($)
{	my ($self, $token) = @_;
	if(my $reset = $self->reset)
	{	return $reset->{token} eq $token;
	}

	warn "Not in a reset procedure, at the moment.";
	0;
}

#------------------
=section Personal Identities
=cut

sub addIdentity($)  # by id or object
{	my ($self, $identity) = @_;
	defined $identity or return;

	my $ids = $self->_data->{identities} ||= [];
	my $id  = ref $identity ? $identity->identityId : $identity;
	return $self if grep $id eq $_, @$ids;

	push @$ids, $id;
	delete $self->{OA_ids};  # clean cache

	$self->log("Added identity $id");
	$self;
}

sub removeIdentity($)
{	my ($self, $identity) = @_;
	my $id  = $identity->identityId;
	$self->_data->{identities} = [ grep $_ ne $id, $self->identityIds ];
	delete $self->{OA_ids};
	$self->log("Removed identity $id");
	$::app->users->saveAccount($self);
	$self;
}

sub identity($)
{	my ($self, $id) = @_;
	$::app->users->identity($id);
}

sub identities
{	my $self = shift;
	unless($self->{OA_ids})
	{	# Silently remove identities which do not exist anymore (different database)
		my @identities;
		foreach my $id ($self->identityIds)
		{	if(my $identity = $self->identity($id))
			{	push @identities, $identity;
			}
			else
			{	$self->log("silently removed identity which disappeared: $id");
			}
		}
		$self->{OA_ids} = [ sort {$a->role cmp $b->role} @identities ];
		$self->_data->{identities} =  [ map $_->identityId, @identities ];
	}
	@{$self->{OA_ids}};
}

sub preferredIdentity()
{	my $self = shift;

	#XXX No way to configure this yet
	($self->identities)[0];
}

#------------------
=section Group Identities
=cut

sub addGroup($)  # by id or object
{	my ($self, $group) = @_;
	defined $group or return;

	my $groupIds = $self->_data->{groups} ||= [];
	my $id       = ref $group ? $group->groupId : $group;
	return $self if grep $id eq $_, @$groupIds;     # avoid doubles

	push @$groupIds, $id;
	$self->log("Added group $id");

	delete $self->{OA_groups};  # clean cache
	$self;
}

sub removeGroup($)
{	my ($self, $group) = @_;
	my $id  = $group->groupId;
	$self->_data->{groups} = [ grep $_ ne $id, $self->groupIds ];
	delete $self->{OA_groups};
	$self->log("Removed group $id");
	$::app->users->saveAccount($self);
	$self;
}

sub group($)
{	my ($self, $id) = @_;
	$::app->users->group($id);
}

sub groups
{	my $self = shift;
	unless($self->{OA_groups})
	{	# Silently remove groups which do not exist anymore (different database), or where you
        # disappeared from the member-list.

		my (@groups, @groupids);
		foreach my $id ($self->groupIds)
		{	my $group = $::app->users->group($id);
			if(! $group)
			{	# Someone else may have removed this group.
				$self->log("Silently removed group which disappeared: $id");
			}
			elsif(! $group->hasMemberFrom($self))
			{	# Someone else may have kicked you out.
				$self->log("Group $id does not contain any of these identities anymore");
			}
			else
			{	push @groups, $group;
				push @groupids, $id;
			}
		}
		$self->{OA_groups} = [ sort {$a->name cmp $b->name} @groups ];
		$self->_data->{groups} = \@groupids;
	}
	@{$self->{OA_groups}};
}

#-------------
=section Proofs
=cut

sub proofs() {	$_[0]->{OA_proofs} ||= OpenConsole::Proofs->new(owner => $_[0]) }

# proof may be missing when the world meanwhile changed
sub proof($$)
{	my ($self, $set, $proofid) = @_;

	my $proof = $self->proofs->proof($set, $proofid);
	return $proof if $proof;

	foreach my $group ($self->groups)
	{   $proof = $group->proofs->proof($set, $proofid);
		return $proof if $proof;
	}

	undef;
}

#------------------
=section Actions
=cut

sub remove()
{	my $self = shift;
    $_->remove for $self->groups, $self->identities;
    $::app->batch->removeEmailsRelatedTo($self->accountId);
}

sub save(%)
{	my ($self, %args) = @_;

	if($args{by_user})
	{	$self->_data->{schema} = ACCOUNT_SCHEMA;
		$self->log('Changed account settings');
		delete $self->_data->{reset};   # leave the reset procedure
	}
	$::app->users->saveAccount($self);
}

1;
