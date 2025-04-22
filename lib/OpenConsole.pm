# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole;
use Mojo::Base 'Mojolicious';

use Log::Report 'open-console-core';

use feature 'state';

use List::Util         qw(first);

use OpenConsole::Util  qw(reseed_tokens to_secs);

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

=cut

my %_dbservers;
sub _mango($)  # server connections shared, when databases on same server
{	my ($self, $class, $model) = @_;

	eval "require $class" or panic $@;
	my $config = $self->config($model) or panic "DB $model not configured";

	my $server = $config->{server}    || MONGODB_CONNECT;
	my $client = $_dbservers{$server} ||= Mango->new($server);
	$class->new(db => $client->db($config->{dbname}));
}

=method users
The C<users> database (M<OpenConsole::Model::Users>), contains generic user and group
information.  It is important data, and inconsistencies in the administration shall not
happen at any cost.
=cut

sub users()
{	my $self = shift;
	state $u = $self->_mango('OpenConsole::Model::Users' => 'userdb');
}

=method assets
The C<assets> database (M<OpenConsole::Model::Assets>) contains the proof,
contract, and service administration.  Less important than the C<users> database information.
=cut

sub assets()
{	my $self = shift;
	state $u = $self->_mango('OpenConsole::Model::Assets' => 'assetsdb');
}

=method connect
Connects to the C<connect> database (M<ConnectConsole::Model::Connect>) which
contains the run-time administration for the connections between external
applications and their users.
=cut

sub connect()
{	my $self = shift;
	state $u = $self->_mango('ConnectConsole::Model::Connect' => 'connectdb');
}

#----------------
=section Running the daemons

=method startup
This method will run once at server start.
=cut

sub startup
{	my $self = shift;

	ref $self ne __PACKAGE__ or panic "You must instantiate extensions.";
	$main::app = $self;  #XXX probably not the right way

	# Load configuration from hash returned by config file
	my $config = $self->plugin('Config');
warn "** STARTUP VHOST $config->{vhost}";
	my $vhost  = $config->{vhost} ||= 'https://' . $ENV{HTTP_HOST};

	### Configure the application

	if(my $s = $config->{sessions})   # not for tasks
	{	my $sessions = $self->sessions;
		$sessions->default_expiration(to_secs $s->{expiration} || 3600);
		$sessions->cookie_domain($s->{cookie_domain} || 'open-console.eu');
		$sessions->cookie_name($config->{squad});
		$sessions->samesite('Lax');  # We share cookies between owner and connect servers
		$self->secrets($s->{secrets});
	}

	srand;
	Mojo::IOLoop->timer(0 => sub { srand; reseed_tokens });
}

#----------------
=section Other
=cut

1;
