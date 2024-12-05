# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Session;
use Mojo::Base 'OpenConsole::Mango::Object';

use Log::Report  'open-console-core', import => [ qw/panic/ ];  # 'trace' name conflict

use Scalar::Util qw(blessed);
use Time::HiRes  qw(time);

my @messages = qw/warnings errors notifications internal_errors trace/;

=chapter NAME

OpenConsole::Session - manage a processing step

=chapter SYNOPSIS

=chapter DESCRIPTION

B<Be warned:> this object, nor its extensions, should contain references to
other objects: session objects get serialized in the data-base or as HTTP
response, hence objects will not survive.

=over 4
=item * C<OpenConsole::Session::REST> (todo) is used for non-interactive clients
=item * M<OwnerConsole::Session::Task> is used to communicate with Minion workers
=item * M<OwnerConsole::Session::Ajax> is used as reply to browser Ajax requests
=back

=chapter METHODS

=section Constructors
=cut

sub create(;$%)
{	my $class = shift;
	my $data  = shift // { };
ref $data eq 'HASH' or panic;
	$data->{$_} ||= [ ] for @messages;
	$class->SUPER::create($data, @_);
}

#------------------
=section Attributes

=cut

has lang       => sub { panic(join '#', caller) };
has controller => sub { panic(join '#', caller) };

sub results() { $_[0]->_data->{results} }

sub trace()   { $_[0]->_data->{trace} || [] }

#------------------
=section Collecting the answer
=cut

sub addError($$)
{	my ($self, $field, $error) = @_;
	$self->pushData(errors => [ $field => blessed $error ? $error->toString($self->lang) : $error ]);
	$self->_trace('error: ' . $error->toString);
}

sub hasErrors() { scalar @{$_[0]->_data->{errors}} }

sub addWarning($$)
{	my ($self, $field, $warn) = @_;
	$self->pushData(warnings => [ $field => blessed $warn ? $warn->toString($self->lang) : $warn ]);
	$self->_trace('warning: ' . $warn->toString);
}

sub addInfo($$)
{	my ($self, $field, $info) = @_;
	$self->pushData(info => [ $field => blessed $info ? $info->toString($self->lang) : $info ]);
	$self->_trace('info: ' . $info->toString);
}

sub notify($$)
{	my ($self, $level, $msg) = @_;
	# Hopefully, later we can have nicer notifications than a simple alert.
	$self->pushData(notifications => $level . ': '. (blessed $msg ? $msg->toString($self->lang) : $msg));
	$self->_trace("notify $level:" . (blessed $msg ? $msg->toString : $msg));
}

sub internalError($)
{	my ($self, $error) = @_;
	$self->pushData(internal_errors => blessed $error ? $error->toString($self->lang) : $error);
	$self->_trace('crash: ' . (blessed $error ? $error->toString : $error));
}

sub hasInternalErrors() { scalar @{$_[0]->_data->{internal_errors}} }

=method isHappy
Returns true when there are no errors collected.
=cut

sub isHappy() { ! $_[0]->hasErrors && ! $_[0]->hasInternalErrors }

=method redirect $url
Ask the browser logic to redirect the user page to the given $location.
=cut

sub redirect($)
{	my ($self, $location) = @_;
	$self->setData(redirect => $location);
}

=method reply
=cut

sub reply()
{	my $self = shift;
	$self->controller->render(json => $self->_data);
}

#------------------
=section Trace
=cut

# Trace messages are not translated.
sub _trace($) { $_[0]->pushData(trace => [ time, $_[1] ]) }

1;
