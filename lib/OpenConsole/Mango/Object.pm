# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Mango::Object;
use Mojo::Base -base;

use Log::Report 'open-console-core';
use Mojo::Util          qw(xml_escape);

use OpenConsole::Util   qw(:time);

=chapter NAME
OpenConsole::Mango::Object - base for any database storable object

=chapter SYNOPSIS
  # Do only instantiate extensions of this class

=chapter DESCRIPTION

This base module implements everything which is offered by any object
which gets stored in the database.  For the moment --as the name of the
module says-- in a MongoDB database, but prepared to be converted into
a CouchDB database.

All these objects have attributes which may be stored in the database,
and attributes which are not stored in the database.  The former are
kept in a sub-HASH named C<_data>.  The other attributes are on the
top level of the object HASH.  Thou SHALL NOT address the fields of
the object HASH: only use accessors!

OpenConsole tries to avoid the Mojo::Base accessor generators, because
it is not flexible enough.

=chapter METHODS

=section Constructors

=c_method new %options
The C<new()> method is provided by M<Mojo::Base>.

=c_method fromDB \%data, %options
Revive this object from its database storage.  The %options are passed
to the object constructore.

The expiration of the object is always checked.  Every object may expire.
The database does not actively track expiration for performance reasons.
=cut

use Data::Dumper;
$Data::Dumper::Indent = 1;

sub fromDB($%)
{	my ($class, $data, %args) = @_;
	my $self = $class->new(_data => $data, %args);
use Data::Dumper;
#warn "Mongo::fromDB($class) = ", Dumper $data;
warn "Mongo::fromDB($class) = ", $self->name, "\n";

	$self->setData(status => 'expired')
		if $self->status ne 'expired' && $self->hasExpired;

	$self;
}

#XXX work in progress
sub fromSummary($)
{	my ($class, $data) = @_;
	$class->new(_sum => $data);
}

=c_method create \%data, %options
Create a new object, not yet in the database.

The %data is exactly what is stored in the database, and usually hidden
internally in the abstract objects.  Only the Controller modules are
allowed to handle these internals, nowhere else!
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	$insert->{id}      ||= 'new';
	$insert->{schema}  ||= $class->schema;
	$insert->{status}  ||= 'new';
	$insert->{created} ||= timestamp($insert->{created})  || timestamp;

	if(my $ex = delete $insert->{expiration})
	{	$insert->{expires} = timestamp(now + duration($ex));
	}
	else
	{	$insert->{expires} = timestamp($insert->{expires});
	}

	$class->new(_data => $insert, %args);
}

#------------------------
=section Attributes

=method set
The name of the C<set> where this object belongs to.  Usually then name of
the M<element()> followed by a C<s>.

=ci_method setName
The display representation of the name of the set.

=ci_method iconFA
Which FontAwesome character is representing this set.

=ci_method element
The type of element this object presents.

=ci_method elemName
The display of a single element in this set.

=ci_method schema
The version of the current running implementation of the object.  This may differ
from the object's version which comes from store.
=cut

sub schema()  { '' }    # some objects will not be saved
sub element() { panic }
sub set()     { panic }
sub setName() { panic }
sub elemName(){ panic }
sub iconFA()  { panic }

=method id
The unique identifier for this object.  It is even unique within the whole
program and database.

=method name
The name gets displayed to the user.

=method created
The moment of creation of the object.

=method updated
Moment of last save.
=cut

# Mongo: When an object has been created, its id is not in _id
sub id()       { $_[0]->_data->{id} }
sub name()     { $_[0]->_data->{name} }
sub created()  { $_[0]->_data->{created} }
sub updated()  { $_[0]->_data->{updated} || $_[0]->created }

=method createdDT
Returns the M<created()> time as a M<DateTime> object.
=method updatedDT
Returns the M<updated()> time as a M<DateTime> object.
=cut

sub createdDT(){ $_[0]->{OMO_cdt} ||= timestamp2dt($_[0]->created) }
sub updatedDT(){ $_[0]->{OMO_udt} ||= timestamp2dt($_[0]->updated) }

#-------------
=section Maintainance

=method sorter
The key to be used when sorting this kind of objects.  Efficiently
used my M<OpenConsole::Util::sorted()>.

=method isNew
Whether the object was already saved.

=method elemLink
Produce the (site absolute) URL which brings you to the object.
=cut

sub sorter()   { lc $_[0]->name }
sub isNew()    { $_[0]->id eq 'new' }
sub elemLink() { '/dashboard/' . $_[0]->element . '/' . $_[0]->id }

=method hasExpired
Whether this Asset is still useable, or got invalidated because of time
restrictions.  The Asset form needs to be revisited to get revived again.
Expired assets may be removed from the database, after some time.
=cut

sub hasExpired()
{	my $self = shift;
	return $self->{OMO_dead} if exists $self->{OMO_dead};
return 0;  #XXX
	my $exp  = $self->expires;
	$self->{OMO_dead} = defined $exp ? $exp < now : 0;
}

=method expires
Returns the M<DateTime>-object which represents when this object will
retire.  Returns C<undef> when no expiration is set.
=cut

sub expires()
{	my $self = shift;
	return $self->{OMO_exp} if exists $self->{OMO_exp};

	my $exp = $self->_data->{expires};
	$self->{OMO_exp} = $exp ? timestamp2dt($exp) : undef;
}

=method status
Returns the status of the object.  Which statusses are available depends on the
object class.  M<OpenConsole::Controller::badge()> usually has a translation
for the status name.
=cut

sub status()     { $_[0]->_data->{status} }

=method createdOn
Reports the service abbreviation included in the M<id()>.
=cut

sub createdOn()  { $_[0]->id =~ s/\:.*//r }

#------------------------
=section Data
=cut

# hidden for anything else than the core data objects.
has _data => sub { +{} };

=method changed
Flags that the data has been changed.

=method hasChanged
Checks whether the data is flagged to have changed.
=cut

sub changed()    { ++$_[0]->{OMO_changed} }
sub hasChanged() { !! $_[0]->{OMO_changed} }

=method setData @pairs
Replace one or more values.  Each @pair is a field-name and the new value.
Returned is the number of changes.  Old field values are replaced.

When any of the values is different than the old value for that field, or
when that field did not exist yet, then the C<changed> flag will be set.
=cut

sub setData(@)
{	my $self = shift;
	my $data = $self->_data;
	my $changes = 0;

	while(@_)
	{	my ($field, $value) = (shift @_, shift @_);

		# NOTE: blank fields do not exist: blank==missing
		if(my $changed = ref $value || +($data->{$field} // ' ') ne ($value // ' '))
		{	$data->{$field} = $value;
warn "CHANGED $field to " . ($value // 'undef');
			$self->changed;
			$changes++;
		}
	}

	$changes;
}

=method pushData $queue, @elements
Add zero or more @elements to the $queue.
=cut

sub pushData($@)
{	my ($self, $queue) = (shift, shift);
	@_ or return 0;

	my $array = $self->_data->{$queue} ||= [];
	push @$array, @_;
	$self->changed;
	1;
}

=method summary %options
Returns the summary data for this object.  When it is not available
yet, it will get create.
=cut

#XXX under development
sub summary(%)  { $_[0]->{OMO_sum} ||= +{ $_[0]->_summary } }

sub _summary()
{	my $self = shift;
	(id => $self->id);
}

=method forGrant @pairs
Returns a HASH which contains information published to service
providers.  The C<@pairs> are added to the HASH.
=cut

sub forGrant(@)
{	my $self = shift;
	+{ @_ };
}

#------------------------
=section Logging
Logging inside the object is (currently) disabled, because the objects
get pretty extra large.  When not used, we can better not take the
performance hit.

=method logging %options
=requires after DATE
=requires before DATE
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

=method log \%data|$text
Create a log line.
=cut

sub log($)
{	my ($self, $insert) = @_;
	$insert = { text => $insert } unless ref $insert eq 'HASH';
warn "LOGGING: ", $insert->{text}, "\n";
return;
	$insert->{timestamp} //= Mango::BSON::Time->new;
#	$insert->{user}      //= $::app->user->username;
	$self->pushData(logging => $insert);
}

#------------------------
=section Actions

=method remove %options
Remove this object.
=cut

sub remove(%)
{	my ($self, %args) = @_;
warn "Remove ".$self->element." ".$self->id;

	# The actual removal of the object from the database
	$self->_remove;
}

=method toDB
Convert the crucial object data into a structure to be saved in the database.
=cut

sub toDB()
{	my $self = shift;
	my $data = $self->_data;
	if(my $e = $data->{expires})
	{	$data->{_expires} = timestamp2bson $e;
	}

	$data;
}


=method save %options
Save this object to the database.  This may trigger the Summary to expire.

=option  by_user BOOLEAN
=default by_user C<false>
When the object is saved by the user, then the new data is accepted which
means "up to date".  Therefore, the schema version gets reset.
=cut

sub save(%)
{	my ($self, %args) = @_;

	$self->setData(updated => timestamp);
	$self->setData(schema  => $self->schema) if $args{by_user};

warn "Save ".$self->element." ".$self->id;
use Data::Dumper;
warn Dumper $self->_data;

	# The actual saving of this object
	$self->_save;
	$self;
}

#XXX!!! use the next three with <%== !!! (double =)
sub icon()     { '<i class="' . $_[0]->iconFA . '" aria-hidden="true"></i>' }
sub iconSet()  { $_[0]->icon . ' ' . xml_escape($_[0]->setName->toString) }
sub iconElem() { $_[0]->icon . ' ' . xml_escape($_[0]->elemName->toString) }
sub iconName() { $_[0]->icon . ' ' . xml_escape($_[0]->name) }

1;
