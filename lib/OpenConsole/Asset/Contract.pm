# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Asset::Contract;
use Mojo::Base 'OpenConsole::Asset';

use Log::Report 'open-console-core';

use Encode            qw(decode);
use OpenConsole::Util qw(new_token timestamp);
use Scalar::Util      qw(blessed);

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
	if(my $service = delete $insert->{service})
	{	$insert->{serviceid} = blessed $service ? $service->id : $service;
	}
	$insert->{status} ||= 'incomplete';
	$class->SUPER::create($insert, %args);
}

sub _summary(%)
{	my $self = shift;
	$self->SUPER::_summary(@_);
}

#-------------
=section Attributes
=cut

sub schema()   { '20240917' }
sub set()      { 'contracts' }
sub element()  { 'contract'  }
sub setName()  { __"Contracts" }
sub elemName() { __"Contract" }
sub iconFA()   { 'fa-solid fa-handshake-simple' }

=method isSigned
Returns a HASH which explains how the contract was signed.
sub isSigned() { $_[0]->_data->{signed} }

sub serviceId() { $_[0]->_data->{serviceid} }
sub agreedAnnex()     { $_[0]->_data->{annex} }
sub agreedTerms()     { $_[0]->_data->{terms} }
sub acceptedLicense() { $_[0]->_data->{license} }
sub presel($)         { $_[0]->_data->{presel}{$_[1]} ||= {} }
sub service()  { $_[0]->{OAC_service} ||= $::app->assets->service($_[0]->serviceId) }

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

=method sign $account
Register that this contract is signed by the logged-in account.

=method invalidate
Revoke the signature.
=cut

sub sign($) { $_[0]->setData(status => 'signed', signed => +{ when => timestamp, by => $_[1]->id }) }
sub invalidate() { $_[0]->setData(status => 'incomplete', signed => undef) }

1;
