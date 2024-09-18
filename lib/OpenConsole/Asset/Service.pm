# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Asset::Service;
use Mojo::Base 'OpenConsole::Asset';

use Log::Report 'open-console-core';

use Encode       qw(decode);
use OpenConsole::Util qw(new_token verify_secret encrypt_secret);

=chapter NAME
OpenConsole::Asset::Service - describes a Service

=chapter DESCRIPTION
The "service" defines what an organization has to offer to other
people.  The service is described as a rules, which needs to match
the information which the user of that service is willing to give.
Together, the "service" and the (personal or Group identity)
negotiate a "contract" of usage.

=chapter METHODS
=section Constructors
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
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

sub schema() { '20240912' }
sub set()    { 'services' }
sub element(){ 'service'  }

sub sort()     { $_[0]->_data->{name} }
sub name()     { $_[0]->_data->{name} }
sub endpoint() { $_[0]->_data->{endpoint} }
sub secret()   { $_[0]->_data->{secret} }
sub description() { $_[0]->_data->{description} }

#-------------
=section Action
=cut

sub _load($)  { $::app->assets->service($_[1]) }
sub _remove() { $::app->assets->removeService($_[0]) }
sub _save()   { $::app->assets->saveService($_[0]) }

sub save(%)
{   my ($self, %args) = @_;
	$self->setData(id => new_token 'S') if $self->isNew;
	$self->SUPER::save(%args);
}

sub correctSecret($)
{   my ($self, $secret) = @_;
    verify_secret $self->_data->{secret}, $secret;
}

sub changeSecret($)
{	my ($self, $secret) = @_;
	$self->_data->{secret} = encrypt_secret $secret;
    $self;
}

1;
