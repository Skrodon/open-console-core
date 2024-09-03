# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Model::Users;
use Mojo::Base -base;

use Log::Report 'open-console-core';

use Mango::BSON ':bson';

use OpenConsole::Account  ();
use OpenConsole::Identity ();
use OpenConsole::Group    ();

=chapter NAME
OpenConsole::Model::Users - database with important user data

=chapter DESCRIPTION
This object handles the "users" database, which contains all information
which related to perticular people with a login.

collections:
=over 4
=item * 'accounts': the logins of a users
=item * 'identities': the public representation of Persons
=item * 'groups': indentity groups
=back

=chapter METHODS
=cut

has db => undef;
has accounts   => sub { $_[0]->{OMU_account} ||= $_[0]->db->collection('accounts')   };
has identities => sub { $_[0]->{OMU_ident}   ||= $_[0]->db->collection('identities') };
has groups     => sub { $_[0]->{OMU_group}   ||= $_[0]->db->collection('groups') };

#---------------------
=section UserDB configuration
=cut

sub upgrade
{	my $self = shift;

    #### Indices
	# We can run "ensure_index()" as often as we want.

#$self->accounts->drop_index('email');
	$self->accounts->ensure_index({ userid => 1 }, { unique => bson_true });

	$self->accounts->ensure_index({ email  => 1 }, {
		unique    => bson_true,
		collation => { locale => 'en', strength => 2 },  # address is case-insensitive
	});

#$self->identities->drop_index('userid');
	$self->identities->ensure_index({ identid => 1 }, { unique => bson_true });
	$self->identities->ensure_index({ userid  => 1 }, { unique => bson_false });

	$self->groups->ensure_index({ groupid => 1 }, { unique => bson_true });
	$self->groups->ensure_index({ userid  => 1 }, { unique => bson_false });
	$self->groups->ensure_index({ identid => 1 }, { unique => bson_false });
	$self;
}

#---------------------
=section The "account" table
=cut

sub account($)
{	my ($self, $userid) = @_;
	defined $userid or return;

#warn "LOADING ACCOUNT $userid";
	my $data = $self->accounts->find_one({userid => $userid})
		or return;
 
	OpenConsole::Account->fromDB($data);
}
 
sub accountByEmail($)
{	my ($self, $email) = @_;
	my $data = $self->accounts->find_one({email => $email})
		or return;
 
	OpenConsole::Account->fromDB($data);
}
 
sub removeAccount($)
{	my ($self, $userid) = @_;
	$self->accounts->remove({userid => $userid})
		or return;
}
 
sub saveAccount($)
{	my ($self, $account) = @_;
	$self->accounts->save($account->toDB);
}
 
sub allAccounts()
{	my $self = shift;
	$self->accounts->find->all;
}

#---------------------
=section The "identity" table
=cut

sub identity($)
{	my ($self, $identid) = @_;
	my $data = $self->identities->find_one({identid => $identid})
		or return;

	OpenConsole::Identity->fromDB($data);
}

sub removeIdentity($)
{	my ($self, $identity) = @_;
	$self->identities->remove({identid => $identity->identityId});
}

sub saveIdentity($)
{	my ($self, $identity) = @_;
	$self->identities->save($identity->toDB);
}

sub allIdentities()
{	my $self = shift;
	$self->identities->find->all;
}


#---------------------
=section The "group" table
=cut

sub group($)
{	my ($self, $groupid) = @_;
	my $data = $self->groups->find_one({groupid => $groupid})
		or return;

	OpenConsole::Group->fromDB($data);
}

sub removeGroup($)
{	my ($self, $group) = @_;
	$self->groups->remove({groupid => $group->groupId});
}

sub saveGroup($)
{	my ($self, $group) = @_;
	$self->groups->save($group->toDB);
}

sub allGroups()
{	my $self = shift;
	$self->groups->find->all;
}

sub groupsUsingIdentity($)
{	my ($self, $identity) = @_;
	my $groups = $self->groups->find({identid => $identity->identityId})->all;
	map OpenConsole::Group->fromDB($_), @$groups;
}

1;
