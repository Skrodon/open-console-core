# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Asset::Proof;
use Mojo::Base 'OpenConsole::Asset';

use Log::Report 'open-console-core';

use Scalar::Util  qw(blessed);
use DateTime      ();

use OpenConsole::Util  qw(bson2datetime new_token);

=chapter NAME
OpenConsole::Asset::Proof - base class for any kind of collected proof

=chapter DESCRIPTION
Base class for all kinds of proofs of ownership.

=chapter METHODS
=section Constructors
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	$insert->{status}    = 'unproven';
	$insert->{score}     = 0;

	my $self = $class->SUPER::create($insert, %args);
	$self;
}

sub _summary(%)
{	my $self = shift;
	$self->SUPER::_summary(@_);
}

#-------------
=section Attributes
=cut

sub status()     { $_[0]->_data->{status} }

=method score %options
Rate the quality of the proof.  The higher the value, the better the
proof.  A value of '0' means "no proof".

The actual score can depend on many factors, which may even be controlled
by the Service.  Therefore, the C<score> needs to be recomputed often.
=cut

sub score() { panic "must be extended" }

#-------------
=section Maintainance
=cut

sub study()       { $_[0]->_data->{study} || {} }
sub algorithm()   { $_[0]->study->{algorithm} || 'none' }
sub algoVersion() { $_[0]->study->{version}   || 'error' }
sub verified()    { $_[0]->study->{verified}  || 'error' }

sub invalidate() { $_[0]->setData(status => 'unproven') }
sub accepted()   { $_[0]->setData(expires => undef, status => 'proven') }
sub isValid()    { $_[0]->status eq 'proven' }   # expiration is checked at db-load

#-------------
=section Action
=cut

sub _load($)  { $::app->assets->proof($_[1]) }
sub _remove() { $::app->assets->removeProof($_[0]) }
sub _save()   { $::app->assets->saveProof($_[0]) }

sub save(%)
{   my ($self, %args) = @_;
	$self->setData(id => new_token 'P') if $self->isNew;
	$self->SUPER::save(%args);
}

1;
