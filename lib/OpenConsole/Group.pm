# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Group;
use Mojo::Base 'OpenConsole::Mango::Object';

use Log::Report 'open-console-core';

use Scalar::Util qw(blessed);
use List::Util   qw(first);

use OpenConsole::Util     qw(new_token);
use OpenConsole::Assets   ();

=chapter NAME
OpenConsole::Group - Manage a group of users

=chapter DESCRIPTION

=chapter METHODS

=section Constructors
=cut

sub create($%)
{	my ($class, $account, %args) = @_;

	my %insert =
	  (	language    => $account->preferredLanguage,
		timezone    => $account->timezone || 'GMT',
		members     => [],
	  );

	my $self = $class->SUPER::create(\%insert, %args);
	$self->addMember($account, $account->preferredIdentity);
	$self;
}

sub _summary(%)
{	my $self = shift;

	  (	$self->SUPER::_summary(@_),
		name     => $self->name,
		fullname => $self->fullname,
		members  => $self->members,
	  );
}

#-------------
=section Attributes
=cut

sub schema()     { '20240112' }
sub element()    { 'group' }
sub set()        { 'groups' }
sub iconFA()     { 'fa-solid fa-people-group' }
sub elemName()   { __"Group" }
sub setName()    { __"Groups" }

sub isPerson()   { 0 }
sub isIdentity() { 0 }
sub isGroup()    { 1 }

# Keep these attributes in sync with the OwnerConsole/Controller/Groups.pm
# method submit_group()

sub country()    { $_[0]->_data->{country} }
sub department() { $_[0]->_data->{department} }
sub email()      { $_[0]->_data->{email} }
sub fullname()   { $_[0]->_data->{fullname} || $_[0]->name }
sub language()   { $_[0]->_data->{language} }
sub members()    { @{$_[0]->_data->{members}} }   # HASHes
sub name()       { $_[0]->_data->{name} }
sub organization() { $_[0]->_data->{organization} }
sub phone()      { $_[0]->_data->{phone} }
sub postal()     { $_[0]->_data->{postal} }
sub timezone()   { $_[0]->_data->{timezone} }

sub link()       { '/dashboard/group/' . $_[0]->id }

#-------------
=section Accepted Members

Structure: ARRAY of

   { identid   => $code,    # identity identifier, required after accepted
     accepted  => date,
   }

=cut

sub addMember($$)
{	my ($self, $account, $identity) = @_;
	my $id  = blessed $identity ? $identity->id : $identity;
	my $aid = $account->id;
	my $gid = $self->id;

	if(my $has = $self->hasMemberFrom($account))
	{	if($has->{identid} ne $id)
		{	$has->{identid} = $id;
			$self->log("Changed identity of account $aid in group $gid to $id.");
        }
	}
	else
	{	my $members = $self->_data->{members};
		push @$members, +{
			identid  => $id,
			accepted => Mango::BSON::Time->new,
			is_admin => @$members ? 0 : 1,
		};
	}
	$self->log("Added identity $id of account $aid to group $gid.");
}

sub isMember($)
{	my ($self, $identid) = @_;
	defined first { $_->{identid} eq $identid } $self->members;
}

sub removeMember($)
{	my ($self, $id) = @_;
	$self->_data->{members} = [ grep { $_->{identid} ne $id } $self->members ];
}

sub _import_member($)
{	my %member = %{$_[1]};
	$member{invited}  = $member{invited}->to_datetime if $member{invited};
	$member{accepted} = $member{accepted}->to_datetime;
	\%member;
}

sub member($)
{	my ($self, $identid) = @_;
	defined $identid or return ();

	my $data = first { $_->{identid} eq $identid } $self->members;
	defined $data ? $self->_import_member($data) : undef;
}

sub allMembers(%)
{	my ($self, %args) = @_;
	my $load  = $args{get_identities};

	my $gid   = $self->id;
	my $users = $::app->users;

	my @members;
  MEMBER:
	foreach my $info (map $self->_import_member($_), $self->members)
	{	my $identid = $info->{identid};
		if($load)
		{	unless($info->{identity} = $users->identity($identid))
			{	$self->log("Identity $identid disappeared from group $gid.");
				$self->removeMember($identid);
				next MEMBER;
			}
		}
		push @members, $info;
	}

	# There must be at least one admin left
	if(@members && ! grep $_->{is_admin}, @members)
	{	$members[0]->{is_admin} = 1;
		$self->log("Member ". $members[0]->{identid} ." in group $gid promoted to admin.");
	}

	@members;
}

sub hasMemberFrom($)
{	my ($self, $account) = @_;
	my %ids  = map +($_->id => 1), $account->identities;
use Data::Dumper;
warn "MISSING IDENTID ", Dumper [ $self->members ] if grep ! $_->{identid}, $self->members;
    my $data = first { $ids{$_->{identid}} } $self->members;
    defined $data ? $self->_import_member($data) : undef;
}

sub memberIdentityOf($)
{	my ($self, $account) = @_;
	my %memids = map +($_->{identid} => $_), $self->members;
	first { exists $memids{$_->id}} $account->identities;
}

sub changeIdentity($$)
{	my ($self, $account, $identity) = @_;
	my $identid = blessed $identity ? $identity->id : $identity;
	my %memids  = map +($_->{identid} => $_), $self->members;
	foreach my $identity ($account->identities)
	{	my $had = $memids{$identity->id} or next;
		$had->{identid} = $identid;
	}

	1;
}

sub memberIsAdmin($)
{	my ($self, $account) = @_;
	my $member = $self->hasMemberFrom($account) or return 0;
	$member->{is_admin};
}

sub nrAdmins() { scalar grep $_->{is_admin}, $_[0]->members }

sub findMemberWithEmail($)
{	my ($self, $email) = @_;

	#TODO probably we should look through the other identities of
	#TODO the member, to see whether someone has used that one to
    #TODO link.  On the other hand, the invitee can flag this as well.

	foreach my $member ($self->allMembers(get_identities => 1))
	{	my $identity = $member->{identity};
		return $identity if $identity->email eq $email;
	}

	undef;
}

#-------------
=section Assets
=cut

sub assets() { $_[0]->{OG_assets} ||= OpenConsole::Assets->new(owner => $_[0]) }

#-------------
=section Actions
=cut

sub _load($)  { $::app->users->group($_[1]) }
sub _remove() { $::app->users->removeGroup($_[0]) }
sub _save()   { $::app->users->saveGroup($_[0]) }

sub remove(%)
{	my ($self, %args) = @_;
	$::app->batch->removeEmailsRelatedTo($self->id);
#XXX Check ownerships which have to be reassigned
	$self->SUPER::remove(%args);
}

sub save(%)
{   my ($self, %args) = @_;
	$self->setData(id => new_token 'G') if $self->isNew;
	$self->SUPER::save(%args);
}

1;
