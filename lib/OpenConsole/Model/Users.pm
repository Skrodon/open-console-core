# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Model::Users;
use Mojo::Base 'OpenConsole::Model';

use Log::Report 'open-console-core';

use Mango::BSON ':bson';

use OpenConsole::Account  ();
use OpenConsole::Identity ();
use OpenConsole::Group    ();
use OpenConsole::Util     qw(token_set);

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

=method upgrade
Bring the database tables to the newest configuration.
=cut

sub upgrade
{	my $self = shift;
	$self->SUPER::upgrade(@_);
	$self->_upgrade_accounts->_upgrade_identities->_upgrade_groups;
}

=method getOwner $id
The Owner can be a User, Identity, or Group.  We can see this from the $id.
Returns the right object.
=cut

sub getOwner($)
{	my ($self, $id) = @_;
	my $set = token_set $id;

	    $set eq 'account'  ? $self->account($id)
      : $set eq 'identity' ? $self->identity($id)
	  : $set eq 'group'    ? $self->group($id)
	  :     panic $id;
}

#---------------------
=section The "account" table
=cut

sub _upgrade_accounts()
{	my $self  = shift;
	my $table = $self->accounts;
	$self->_upgrade($table);
#$self->accounts->drop_index('email');
	$table->ensure_index({ id  => 1 }, { unique => bson_true });
	$table->ensure_index({ email  => 1 }, {
		unique    => bson_true,
		collation => { locale => 'en', strength => 2 },  # address is case-insensitive
	});
	$self;
}

sub account($)
{	my ($self, $userid) = @_;
	defined $userid or return;

#warn "LOADING ACCOUNT $userid";
	my $data = $self->accounts->find_one({id => $userid})
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
	$self->accounts->remove({id => $userid})
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

sub _upgrade_identities()
{	my $self  = shift;
	my $table = $self->identities;
	$self->_upgrade($table);
	$table->ensure_index({ id  => 1 }, { unique => bson_true });
	$table->ensure_index({ userid  => 1 }, { unique => bson_false });
	$self;
}

sub identity($)
{	my ($self, $identid) = @_;
	my $data = $self->identities->find_one({id => $identid})
		or return;

	OpenConsole::Identity->fromDB($data);
}

sub identitiesOf($)
{	my ($self, $account) = @_;
	map OpenConsole::Identity->fromDB($_),
		$self->identities->find({userid => $account->id})->all;
}

sub removeIdentity($)
{	my ($self, $identity) = @_;
	$self->identities->remove({identid => $identity->id});
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

sub _upgrade_groups()
{	my $self  = shift;
	my $table = $self->groups;
	$self->_upgrade($table);

	$table->ensure_index({ id  => 1 }, { unique => bson_true });
	$table->ensure_index({ userid  => 1 }, { unique => bson_false });
	$table->ensure_index({ identid => 1 }, { unique => bson_false });
	$self;
}

sub group($)
{	my ($self, $groupid) = @_;
	my $data = $self->groups->find_one({id => $groupid})
		or return;

	OpenConsole::Group->fromDB($data);
}

sub removeGroup($)
{	my ($self, $group) = @_;
	$self->groups->remove({groupid => $group->id});
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
	my $groups = $self->groups->find({identid => $identity->id})->all;
	map OpenConsole::Group->fromDB($_), @$groups;
}

1;
