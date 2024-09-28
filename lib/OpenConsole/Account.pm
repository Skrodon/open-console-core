# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Account;
use Mojo::Base 'OpenConsole::Mango::Object';

use Log::Report 'open-console-core';

use Mango::BSON::Time ();
use DateTime          ();
use DateTime::Format::Mail ();
use Scalar::Util      qw(blessed);

use OpenConsole::Util     qw(new_token verify_secret encrypt_secret);
use OpenConsole::Identity ();
use OpenConsole::Assets   ();

=chapter NAME
OpenConsole::Account - a user's login

=chapter DESCRIPTION
An Account is a login.

=chapter METHODS
=section Constructors
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	my $userid = $insert->{id} = new_token 'A';
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
	if($data->{schema} < $class->schema) {
		# We may need to upgrade the user object partially automatically,
		# partially with the user's help.
	}
	$class->SUPER::fromDB($data);
}

#------------------
=section Attributes
=cut

sub schema()    { '20240102' }
sub element()   { 'account' }
sub set()       { 'accounts' }
sub elemName()  { __"Account" }
sub setName()   { __"Accounts" }
sub iconFA()    { 'fa-solid fa-user' }

sub isPerson()  { 1 }
sub isIdentity(){ 0 }
sub isGroup()   { 0 }

#### Keep these attributes in sync with OwnerConsole::Collector::Account::submit()

sub name()      { (__"Personal properties")->toString }
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
sub link()       { '/dashboard/account/' . $_[0]->id }

=method localTime $timestamp
Convert a timestamp C<"YYYY-mm-DDTHH::MM::SSZ"> (as produced by M<OpenConsole::Util::timestamp()>)
into a printable time, in the timezone of the account.
=cut

sub localTime($)
{	my ($self, $stamp) = @_;
	$stamp =~ /^([0-9]{4})\-([01][0-9])\-([0-3][0-9])T([0-2][0-9])\:([0-5][0-9])\:([0-5][0-9])Z$/ or panic $stamp;
	my $dt = DateTime->new(year => $1, month => $2, day => $3,
		hour => $4, minute => $5, second => $6,
		time_zone => $self->timezone);
	DateTime::Format::Mail->format_datetime($dt);
}

#------------------
=section Password handling
=cut

sub correctPassword($)
{	my ($self, $password) = @_;
	verify_secret $self->_data->{password}, $password;
}

sub changePassword($)
{	my ($self, $password) = @_;
	$self->_data->{password} = encrypt_secret $password;
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
	my $id  = ref $identity ? $identity->id : $identity;
	return $self if grep $id eq $_, @$ids;

	push @$ids, $id;
	delete $self->{OA_ids};  # clean cache

	$self->log("Added identity $id");
	$self;
}

sub removeIdentity($)
{	my ($self, $identity) = @_;

	my $id  = $identity->id;
	$self->setData(identities => [ grep $_ ne $id, $self->identityIds ]);
	delete $self->{OA_ids};
	$self->log("Removed identity $id");

	$identity->remove($self);
	$self->save;
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
		$self->_data->{identities} =  [ map $_->id, @identities ];
	}
	@{$self->{OA_ids}};
}

sub preferredIdentity()
{	my $self = shift;

	#XXX No way to configure this yet
	($self->identities)[0] // undef;
}

#------------------
=section Group Identities
=cut

sub addGroup($)  # by id or object
{	my ($self, $group) = @_;
	defined $group or return;

	my $groupIds = $self->_data->{groups} ||= [];
	my $id       = ref $group ? $group->id : $group;
	return $self if grep $id eq $_, @$groupIds;     # avoid doubles

	push @$groupIds, $id;
	$self->log("Added group $id");

	delete $self->{OA_groups};  # clean cache
	$self;
}

sub removeGroup($)
{	my ($self, $group) = @_;
	$group->_remove($self);

	my $id  = $group->id;
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

=method groupsForId $identity|$idid
Returns a LIST of groups where the $identity is member of.
=cut

sub _createGrById()
{	my $self = shift;
	my %t;
	foreach my $group ($self->groups)
	{	my $ident = $group->memberIdentityOf($self) or next;
		push @{$t{$ident->id}}, $group;
	}
	\%t;
}

#XXX not used
sub groupsFor($)
{	my ($self, $identity) = @_;
	my $id = blessed $identity ? $identity->id : $identity;
	my $groups = ($self->{OA_grById} ||= $self->_createGrById)->{$id} || [];
	@$groups;
}

#-------------
=section Assets
=cut

sub assets() { $_[0]->{OA_assets} ||= OpenConsole::Assets->new(owner => $_[0]) }

# Asset may be missing when the world meanwhile changed
sub asset($$)
{	my ($self, $set, $assetid) = @_;

	my $asset = $self->assets->asset($set, $assetid);
	return $asset if $asset;

	foreach my $identity ($self->identity)
	{   $asset = $identity->assets->asset($set, $assetid);
		return $asset if $asset;
	}

	foreach my $group ($self->groups)
	{   $asset = $group->assets->asset($set, $assetid);
		return $asset if $asset;
	}

	undef;
}

=method assetSearch $set, %options
=option  min_score INTEGER
=default min_score 0
Only return elements from the $set which have a minimum score of at least this
value.  With C<0>, even unproven entries are returned.

=option  owner OBJECT
=default owner C<undef>
Only return the elements which are related to the Account, Identity, or Group
specified.  The Identity and Group MUST be Account related.
=cut

sub assetSearch($%)
{	my ($self, $set, %args) = @_;
	my $score = delete $args{min_score} || 0;

	my @list;
	if(my $owner = delete $args{owner})
	{	push @list,
			$owner==$self      ? $self->assets->for($set, undef)
		  :	$owner->isIdentity ? $self->assets->for($set, $owner)
		  :	                     $owner->assets->for($set);
	}
	else
	{	push @list,
			$self->assets->for($set, undef),
			(map $self->assets->for($set, $_), $self->identities),
			(map $_->assets->for($set), $self->groups);
	}

	@list = grep $_->score >= $score, @list if $score;
	@list;
}

=method findOwner $id
Returns the Account, Identity, or Group object, within this account, which
is represented by the $id.
=cut

sub findOwner($)
{	my ($self, $id) = @_;
	return $self if $id eq $self->id;
	$self->identity($id) || $self->group($id);
}

#------------------
=section Actions
=cut

sub _load($)  { $::app->users->account($_[1]) }
sub _remove() { $::app->users->removeAccount($_[0]) }
sub _save()   { $::app->users->saveAccount($_[0])   }

sub remove(%)
{	my ($self, %args) = @_;
    $self->removeGroup($_)    for $self->groups;
	$self->removeIdentity($_) for $self->identities;
    $::app->batch->removeEmailsRelatedTo($self->id);
	$self->SUPER::remove(%args);
}

sub save(%)
{	my ($self, %args) = @_;

	delete $self->_data->{reset}   # leave the reset procedure
		if $args{by_user};

	$self->SUPER::save(%args);
}

1;
