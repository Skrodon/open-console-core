# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Session::Task;
use Mojo::Base 'OpenConsole::Session';

use Log::Report 'open-console-owner';

use OpenConsole::Util qw(val_line);

=chapter NAME

OpenConsole::Session::Task - a session which runs a task

=chapter SYNOPSIS

=chapter DESCRIPTION

The tasks run on the Tasks server, which provides a REST interface.

The reply of the REST calls in standardized in this session object:
when a Task runs, it maintains this object.  On request, it will
return this object in its current state.  It flags that the state
is final when the task ends successfully or failed.

B<Be warned:> the data this object, nor its extensions, should contain
references to other objects, because it gets transported over HTTP.

=chapter METHODS

=section Constructors

=c_method job $jobid, %options
Collect the results from a task ran or still running.  The %options
are passed to M<new()>.
=cut

sub job($$)
{	my ($class, $jobid) = (shift, shift);
	my $job  = $::app->minion->job($jobid);

	unless($job)
	{	my $self = $class->create;
		$self->internalError(__x"Job {id} disappeared.", id => $jobid);
		return $self;
	}

use Data::Dumper;
warn "JOB $jobid RETURNED=", Dumper $job->info;
	$class->create($job->info->{result}, jobId => $jobid, @_);
}

=c_method fromResponse $json, %options
=requires server \%config
=cut

sub fromResponse($%)
{	my ($class, $json, %args) = @_;
	$class->create($json, jobId => $json->{jobid}, %args);
}

#------------------
=section Attributes

=method server
On the client-side, this lists the server configuration.

=method jobId
On the client-side, this returns the job number
=cut

has 'server';
has jobId  => sub { 0 };

=method id
On the client-side, the taskId represents an encoding of the server and the
job.  At the moment, this is the server sequence number followed by the job
sequence number of that server.
=cut

sub id()
{	my $self = shift;
	$self->server->{label} . '-' . $self->jobId;
}

#------------------
=section Collecting the answer

Raw job data, see F<https://metacpan.org/pod/Minion::Job#info>.
Create abstracted methods!

=method jobQueued $jobid, $settings, %options
Flag that a job has been prepared.
=cut

sub jobQueued($$%)
{	my ($self, $jobid, $settings, %args) = @_;
	$self->setData(%$settings, state => 'queued', jobid => $jobid, created => time);
}

=method state
=cut

sub state  { $_[0]->_data->{state} }

=method results
=cut

sub results(;$)
{	my $self = shift;
	$self->_data->{results} ||= shift || +{};
}

=method reply
Create the REST reply.
=cut

sub reply()
{	my $self = shift;
	$self->controller->render(json => $self->_data);
}

1;
