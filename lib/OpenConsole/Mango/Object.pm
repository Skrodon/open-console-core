# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Mango::Object;
use Mojo::Base -base;

use Log::Report 'open-console-core';

#------------------------
=section Constructors
=cut

use Data::Dumper;
$Data::Dumper::Indent = 1;
sub fromDB($)
{	my ($class, $data) = @_;
delete $data->{logging};   #XXX remove after restart of the DBs
	$class->new(_data => $data);
}

sub create($%)
{	my ($class, $insert, %args) = @_;
	$insert->{created} = Mango::BSON::Time->new;
	$class->new(_data => $insert);
}

#------------------------
=section Attributes
=cut

sub created() { my $c = $_[0]->_data->{created}; $c ? $c->to_datetime : undef }

#------------------------
=section Data
=cut

has _data => sub { +{} };

sub toDB() { $_[0]->_data }  #XXX might become more complex later

sub changed()    { ++$_[0]->{OP_changed} }
sub hasChanged() { !! $_[0]->{OP_changed} }

sub setData(@)
{	my $self = shift;
	my $data = $self->_data;
	my $changes = 0;

	while(@_)
	{	my ($field, $value) = (shift @_, shift @_);

		# NOTE: blank fields do not exist: blank==missing
		if(my $changed = +($data->{$field} // ' ') ne ($value // ' '))
		{	$data->{$field} = $value;
warn "CHANGED $field to " . ($value // 'undef');
			$self->changed;
			$changes++;
		}
	}

	$changes;
}

#------------------------
=section Logging
=cut

sub logging(%)
{	my ($self, %args) = @_;
	my $after  = $args{after};
	my $before = $args{before};

	my @lines;
	foreach my $log (@{$self->_data->{logging}})
	{	my %line = %$log;
		my $when = $line{when} = $log->{timestamp}->to_datetime;
		next if defined $after  && $when < $after;
		next if defined $before && $when > $before;
		push @lines, \%line;
	}
	\@lines;
}

sub log($)
{	my ($self, $insert) = @_;
	$insert = { text => $insert } unless ref $insert eq 'HASH';
warn "LOGGING: ", $insert->{text}, "\n";
return;
	$insert->{timestamp} //= Mango::BSON::Time->new;
#	$insert->{user}      //= $::app->user->username;
	push @{$self->_data->{logging}}, $insert;
}

#------------------------
=section Actions
=cut

1;
