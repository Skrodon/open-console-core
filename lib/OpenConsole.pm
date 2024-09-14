# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole;
use Mojo::Base 'Mojolicious';

use Log::Report 'open-console-core';

use feature 'state';

use List::Util  qw(first);

use OpenConsole::Util          qw(reseed_tokens);
use OpenConsole::Model::Users  ();
use OpenConsole::Model::Assets ();

use Mango;
use constant
{	MONGODB_CONNECT => 'mongodb://localhost:27017',
};

=chapter NAME

OpenConsole - Open Console

=chapter SYNOPSIS

  # This is a base class, so instantiate extensions
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

=method assets
The C<assets> database (M<OpenConsole::Model::Assets>) contains the proof,
contract, and service administration.  Less important than the C<users> database information.
=cut

my %_dbservers;
sub _mango($)  # server connections shared, when databases on same server
{	my ($self, $class, $model) = @_;
	my $config = $self->config($model);
    my $server = $config->{server}    || MONGODB_CONNECT;
	my $client = $_dbservers{$server} ||= Mango->new($server);
	$class->new(db => $client->db($config->{dbname}));
}

sub users()
{	my $self = shift;
	state $u = $self->_mango('OpenConsole::Model::Users' => 'userdb');
}

sub assets()
{	my $self = shift;
	state $u = $self->_mango('OpenConsole::Model::Assets' => 'assetsdb');
}

#----------------
=section Running the daemons

=method isAdmin $account
=cut

my %admins;   # emails are case insensitive
sub isAdmin($) { $admins{lc $_[1]->email} }

=method startup
This method will run once at server start.
=cut

sub startup
{	my $self = shift;

	ref $self ne __PACKAGE__ or panic "You must instantiate extensions.";
	$main::app = $self;  #XXX probably not the right way

	# Load configuration from hash returned by config file
	my $config = $self->plugin('Config');
	$config->{vhost} ||= 'https://' . $ENV{HTTP_HOST};

	### Configure the application
	$self->secrets($config->{secrets});

	%admins = map +(lc($_) => 1), @{$config->{admins} || []};

	$self->users->upgrade;
	$self->assets->upgrade;

#$::app->users->db->collection('accounts')->remove({});  #XXX hack clean whole accounts table

	srand;
	Mojo::IOLoop->timer(0 => sub { srand; reseed_tokens });
}

#----------------
=section Other
=cut

1;
