# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Comply;
use Mojo::Base 'OpenConsole::Mango::Object';

use Log::Report 'open-console-core';

use OpenConsole::Util qw(new_token);

use Scalar::Util   qw(blessed);

=chapter NAME
OpenConsole::Comply - temporary login to an application

=chapter DESCRIPTION
When a user connects to an application, it has to Comply to the
signed Contract.  The user picks personal facts from its chosen
identity.

=chapter METHODS

=section Constructors

=c_method create $insert, %options
=requires contract $contract 

=option  service $service
=default service C<$contract->serviceId>

=option  give HASH
=default give +{ }
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	$insert->{expires}  ||= '2027-01-01T00:00:00Z';
	$insert->{give}     ||= {};

	my $contract          = delete $insert->{contract} or panic;
	$insert->{contractid} = blessed $contract ? $contract->id : $contract;

	my $service           = delete $insert->{service} || (blessed $contract ? $contract->service : panic);
	$insert->{serviceid}  = blessed $service ? $service->id : $service;

	my $self = $class->SUPER::create($insert, %args);
	$self;
}

#-------------
=section Attributes
=cut

sub schema()   { '20241001' }
sub set()      { 'complies' }
sub element()  { 'comply'  }
sub setName()  { __"Complies" }
sub elemName() { __"Comply" }
sub iconFA()   { 'fa-solid fa-share' }

=method contractId
=method contract [$contractId]
Returns the related contract object (if it still exists).

=method serviceId
=method service [$serviceId]
Returns the related service object (if it still exists).
=cut

sub contractId() { $_[0]->_data->{contractid} }
sub contract()   { $_[0]->{CC_contr} ||= $::app->assets->contract($_[1] || $_[0]->contractId) }

# Although the contract already points to the service, we still add this
# to be able to search faster.
sub serviceId()  { $_[0]->_data->{serviceid} }
sub service()    { $_[0]->{CC_serv}  ||= $::app->assets->service($_[1] || $_[0]->serviceId) }

=method giveFacts
Return a HASH with the facts collected to be sent to the Application.  When nothing is
selected yet, then an empty HASH is returned.
=cut

sub giveFacts() { $_[0]->_data->{give} }

=method endpoint
Where we login, an absolute URL string pointing to the application.
=cut

sub endpoint($)  { '/client/service';
	# $_[0]->_data->{endpoint};
}

=method grant
The basic template for the grant, created by M<OpenConsole::Controller::Comply> method
C<_prepareGrant()>.
=cut

sub grant() { $_[0]->_data->{grant} }

#------------------
=section Actions
=cut

sub _load($)  { $::app->connect->comply($_[1]) }
sub _remove() { $::app->connect->removeComply($_[0]) }
sub _save()   { $::app->connect->saveComply($_[0]) }

sub save(%)
{	my ($self, %args) = @_;
	$self->setData(id => new_token 'R') if $self->isNew;
warn "COMPLY ID = ", $self->id;
	$self->SUPER::save(%args);
}

=method makeGrant %options
The grant object is not stored as such, but a JSON compliant HASH generated each time
it gets requested.  The comply process has collected all the required data, but not in
the definitive JSON structure.
=cut

sub makeGrant(%)
{	my ($self, %options) = @_;
	my $prepared = $self->grant;
	$prepared;
}

1;
