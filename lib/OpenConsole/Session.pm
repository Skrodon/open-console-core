# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Session;
use Mojo::Base -base;

use Log::Report  'open-console-core';

use Scalar::Util qw(blessed);
use Time::HiRes  qw(time);

=chapter NAME

OpenConsole::Session - manage a processing step

=chapter SYNOPSIS

=chapter DESCRIPTION

B<Be warned:> this object, nor its extensions, should contain references to
other objects: session objects get serialized in the data-base or as HTTP
response, hence objects will not survive.

=over 4
=item * M<OpenConsole::Session::REST> is used for non-interactive clients
=item * M<OwnerConsole::Session::TaskResults> is used to communicate with Minion workers
=item * M<OwnerConsole::Session::Ajax> is used as reply to browser Ajax requests
=back

=chapter METHODS

=section Constructors
=cut

sub new(@) { my $self = shift->SUPER::new(@_); $self->start; $self }

#------------------
=section Attributes

=cut

has _data => sub {  +{ warnings => [], errors => [], notifications => [], internal_errors => [], trace => [] } };
has lang  => sub { ... };
has start => sub { $_[0]->_data->{start} = time };

#------------------
=section Collecting the answer
=cut

sub addError($$)
{	my ($self, $field, $error) = @_;
	push @{$self->_data->{errors}}, [ $field => blessed $error ? $error->toString($self->lang) : $error ];
}

sub hasErrors() { scalar @{$_[0]->_data->{errors}} }

sub addWarning($$)
{	my ($self, $field, $warn) = @_;
	push @{$self->_data->{warnings}}, [ $field => blessed $warn ? $warn->toString($self->lang) : $warn ];
}

sub notify($$)
{	my ($self, $level, $msg) = @_;
	# Hopefully, later we can have nicer notifications than a simple alert.
	my $text = blessed $msg ? $msg->toString($self->lang) : $msg;
	push @{$self->_data->{notifications}}, "$level: $text";
}

sub addOtherData($$)
{	my ($self, $key, $value) = @_;
	$self->_data->{$key} = $value;
}

sub internalError($)
{	my ($self, $error) = @_;
	push @{$self->_data->{internal_errors}}, blessed $error ? $error->toString($self->lang) : $error;
}

sub hasInternalErrors() { scalar @{$_[0]->_data->{internal_errors}} }

sub isHappy() { ! $_[0]->hasErrors && ! $_[0]->hasInternalErrors }

#------------------
=section Trace
=cut

# Trace messages are not translated.
sub _trace($) { push @{$_[0]->_data->{trace}}, [ time, $_[1] ] }

sub showTrace($%)
{	my ($self, $account, %args) = @_;
	my @trace = @{$self->_data->{trace}};
	@trace or return [];

	my @lines;
	my $first = shift @trace;
	my $start = DateTime->from_epoch(epoch => $first->[0]);
	$start->set_time_zone($account->timezone) if $account;

	push @lines, [ $start->stringify, $first->[1] ];
	push @lines, [ (sprintf "+%ds", $_->[0] - $first->[0]), $_->[1] ]
		for @trace;

	\@lines;
}

1;
