# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Mango::Object;
use Mojo::Base -base;

use Log::Report 'open-console-core';

=chapter NAME
OpenConsole::Mango::Object - base for any database storable object

=chapter METHODS

=section Constructors
=cut

use Data::Dumper;
$Data::Dumper::Indent = 1;
sub fromDB($)
{	my ($class, $data) = @_;
	$class->new(_data => $data);
}

sub create($%)
{	my ($class, $insert, %args) = @_;
	$insert->{id}      ||= 'new';
	$insert->{schema}  ||= $class->schema;
	$insert->{created}   = Mango::BSON::Time->new;
	$class->new(_data => $insert, %args);
}

#------------------------
=section Attributes

=method id
The unique identifier for this object.  It is even unique within the whole
program and database.

=method created
The moment of creation of the object.

=method set
The name of the C<set> where this object belongs to.  Usually then name of
the M<element()> followed by a C<s>.

=method element
The type of element this object presents.

=method schema
The version of the current implementation
=cut

# Mongo: When an object has been created, its id is not in _id
sub id()      { $_[0]->_data->{id} }

sub created() { my $c = $_[0]->_data->{created}; $c ? $c->to_datetime : undef }
sub set()     { panic }
sub element() { panic }
sub schema()  { '' }    # some objects will not be saved

=method sort
The key to be used when sorting this kind of objects.

=method isNew
Whether the object was already saved.

=method elemLink
Produce the (site absolute) URL which brings you to the object.
=cut

sub sort()     { $_[0]->id }
sub isNew()    { $_[0]->id eq 'new' }
sub elemLink() { '/dashboard/' . $_[0]->element . '/' . $_[0]->id }


#------------------------
=section Data
=cut

has _data => sub { +{} };

sub toDB()       { $_[0]->_data }  #XXX might become more complex later

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

sub pushData($@)
{	my ($self, $queue) = (shift, shift);
	@_ or return;

	my $array = $self->_data->{$queue} ||= [];
	push @$array, @_;
	$self->changed;
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
