# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Asset::Contract;
use Mojo::Base 'OpenConsole::Mango::Object';

use Log::Report 'open-console-core';

use Encode            qw(decode);
use OpenConsole::Util qw(new_token);

=chapter NAME
OpenConsole::Asset::Contract - a contract between an account and a service

=chapter DESCRIPTION
A "contract" is an agreement between an personal or group Identity and a 
service provider.  The service provider is a group identity.

=chapter METHODS
=section Constructors
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	my $self = $class->SUPER::create($insert, %args);
	$self;
}

#-------------
=section Attributes
=cut

sub schema() { '20240224' }
sub set()    { 'contracts' }
sub element(){ 'contract'  }

sub sort()   { lc $_[0]->_data->{name} }
sub name()   { $_[0]->_data->{name} }

#-------------
=section Action
=cut

sub _load($)  { $::app->assets->contract($_[1]) }
sub _remove() { $::app->assets->removeContract($_[0]) }
sub _save()   { $::app->assets->saveContract($_[0]) }

sub save(%)
{   my ($self, %args) = @_;
	$self->setData(id => new_token 'C') if $self->isNew;
	$self->SUPER::save(%args);
}

1;
