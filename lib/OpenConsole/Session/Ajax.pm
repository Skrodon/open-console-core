# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Session::Ajax;
use Mojo::Base 'OpenConsole::Session';

use Log::Report 'open-console-owner', import => [ qw/__x/ ];

use OpenConsole::Util qw(val_line);

=chapter NAME

OwnerConsole::Session::Ajax - a session which communicates with a browser

=chapter SYNOPSIS

=chapter DESCRIPTION

B<Be warned:> this object, nor its extensions, should contain references
to other objects: the client-side of this response may (=is probably)
not be Perl, hence objects will not be portable.

=chapter METHODS

=section Constructors
=cut

#------------------
=section Attributes
=cut

has account    => sub { $_[0]->controller->account };
has lang       => sub { $_[0]->account->iflang };
has pollDelay  => sub { $::app->config->{tasks}{poll_interval} // 2000 };

#------------------
=section About the request
=cut

=method request
Returns the http request object which is handled.
=cut

sub request() { $_[0]->{OSA_request} ||= $_[0]->controller->req }

=method query
Returns the HASH with the request query parameters.
=cut

sub query()
{	my $self = shift;
	exists $self->{OSA_query} or $self->{OSA_query} = $self->request->url->query;
	$self->{OSA_query};
}

=method about $label
Returns the crucial identifier for this call: where are we speaking
about.  Sometimes there are multiple identifiers passed, but the one
returned here is the first object to load.

The value may come from the routing path.
=cut

sub about($)
{	my ($self, $idlabel) = @_;
	$self->controller->param($idlabel);
}

=method params
Returns a HASH with all incoming query and body parameters.
=cut

sub params()
{	my $self = shift;
	my $req  = $self->request;
my $new = ! defined $self->{OSA_params};
my $p =
	$self->{OSA_params} ||= $req->json || $req->body_params->to_hash;
use Data::Dumper;
warn "PARAMS=", Dumper $p if $new;
$p;
}

=method optionalParam $param, [$default]
Get the value of an optional calling parameter.  You can call this only
once.
=cut

sub optionalParam($;$) { delete $_[0]->params->{$_[1]} // $_[2] }

=method ignoreParam $param
Flag that you do now that a certain parameter is passed, but you chose
to ignore its existence (for some time?).
This will silence the complaint by M<checkParamsUsed()>.
=cut

sub ignoreParam($)     { delete $_[0]->params->{$_[1]} }

=method requiredParam $param
Take the value of a required calling parameter.
=cut

sub requiredParam($)
{	my ($self, $param) = @_;
	my $p = $self->optionalParam($param);

	unless(defined $p && $p =~ /\S/)
	{	$self->addError($param => __x"Required parameter missing.");
		return 'missing';
	}

	$p;
}

=method checkParamsUsed
Check whether all parameters have been used: whether the controller handler
matches the template.
=cut

sub checkParamsUsed()
{	my $self   = shift;
	my $params = $self->params;
	keys %$params == 0
		or warn "Unprocessed parameters: ", join ', ', sort keys %$params;
	$self;
}

#------------------
=section Collecting the answer

=method startPoll $location, $task, %options
Ask the browser logic to start polling the result on the given location, to
wait for a result (produced by the Tasks processed).

=option  delay MILLISECONDS
=default delay 2000
=cut

sub startPoll($$%)
{	my ($self, $location, $task, %args) = @_;
	my $delay = $args{delay} || $self->pollDelay;
	$self->setData(poll => { where => $location, task => $task->id, delay => $delay });
}

=method stopPolling
Flag to the browser logic that there will be no new information when polling
continues.
=cut

sub stopPolling() { $_[0]->setData(task_ready => $_[0]->isHappy ? 'success' : 'failed') }

=method mergeTaskResults $task
Merge the results of received task results into this session.
=cut

sub mergeTaskResults($)
{	my ($self, $task) = @_;
	my $to   = $self->_data;
	my $from = $task->_data;
use Data::Dumper;
warn "MERGING", Dumper $to, $from;
	push @{$to->{$_}}, @{$from->{$_}} for qw/warnings errors notifications internal_errors trace/;
	$self;
}

1;
