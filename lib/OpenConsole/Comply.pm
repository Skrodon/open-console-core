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
=requires contract $id|$contract 

=option  service $id|$service
=default service C<$contract->serviceId>
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	$insert->{id}      ||= new_token 'T';
	$insert->{expires} ||= '2027-01-01T00:00:00Z';

	my $contract          = delete $insert->{contract} or panic;
	$insert->{serviceid} = blessed $contract ? $contract->id : $contract;

	my $service          = delete $insert->{service} || $contract->serviceId;
	$insert->{serviceid} = blessed $service ? $service->id : $service;

	my $self = $class->SUPER::create($insert, %args);
	$self;
}

#-------------
=section Attributes
=cut

sub schema()      { '20241001' }
sub set()         { 'complies' }
sub element()     { 'comply'  }

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

#------------------
=section Actions
=cut

sub _load($)  { $::app->connect->comply($_[1]) }
sub _remove() { $::app->connect->removeComply($_[0]) }
sub _save()   { $::app->connect->saveComply($_[0]) }

1;
