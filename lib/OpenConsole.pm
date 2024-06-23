# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole;
use Mojo::Base 'Mojolicious';

use Log::Report 'open-console-core';

use feature 'state';
use Mango;

use List::Util  qw(first);

use OpenConsole::Util          qw(reseed_tokens);
use OpenConsole::Model::Users  ();
use OpenConsole::Model::Proofs ();

my (%dbconfig, %_dbservers);
my @databases = qw/userdb batchdb proofdb/;

use constant
{	MONGODB_CONNECT => 'mongodb://localhost:27017',
};

=chapter NAME

OpenConsole - Open Console

=chapter SYNOPSIS

  morbo script/owner_console &

=chapter DESCRIPTION

=chapter METHODS

=section Constructors
Standard M<Mojo::Base> constructors.

=section Databases
The application may configure different MongoDB databases (clusters), for different
characteristics of tasks.

=method users
The C<users> database (M<OpenConsole::Model::Users>), contains generic user and group
information.  It is important data, and inconsistencies in the administration shall not
happen at any cost.

=method proofs
The C<proofs> database (M<OpenConsole::Model::Proofs>) contains the proof
and contract administration.  Less important than the C<users> database information.
=cut

sub _dbserver($)  # server connections shared, when databases on same server
{	my $server = $_[1] || MONGODB_CONNECT;
	$_dbservers{$server} ||= Mango->new($server);
}

sub users()
{	my $self   = shift;
	my $config = $dbconfig{userdb};
	state $u   = OpenConsole::Model::Users->new(db => $self->_dbserver($config->{server})->db($config->{dbname}))->upgrade;
}

sub proofs()
{	my $self   = shift;
	my $config = $dbconfig{proofdb};
	state $p   = OpenConsole::Model::Proofs->new(db => $self->_dbserver($config->{server})->db($config->{dbname}))->upgrade;
}

#----------------
=section Other

=method isAdmin $account
=cut

my %admins;   # emails are case insensitive

# This method will run once at server start
sub startup
{	my $self = shift;
	$main::app = $self;  #XXX probably not the right way

	# Load configuration from hash returned by config file
	my $config = $self->plugin('Config');
	$config->{vhost} ||= 'https://' . $ENV{HTTP_HOST};

	### Configure the application
	$self->secrets($config->{secrets});

	$dbconfig{$_}    = $config->{$_} for @databases;

#$::app->users->db->collection('accounts')->remove({});  #XXX hack clean whole accounts table

	# 'user' is the logged-in user, the admin can select to show a different 'account'
	$self->helper(user      => sub {
		my $c = shift;
		my $user;
		unless($user = $c->stash('user'))
		{	$user = $self->users->account($c->session('userid'));
			$c->stash(user => $user);
		}
		$user;
	});

	$self->helper(account   => sub {
		my $c = shift;
		my $account;
		unless($account = $c->stash('account'))
		{	my $aid = $c->session('account');
			$account = defined $aid ? $self->users->account($aid) : $c->user;
			$c->stash(account => $account);
		}
		$account;
	});

	srand;
	Mojo::IOLoop->timer(0 => sub { srand; reseed_tokens });
}

1;
