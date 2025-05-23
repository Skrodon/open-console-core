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
	$insert->{status} ||= 'testing';
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

sub schema()    { '20240912' }
sub set()       { 'services' }
sub element()   { 'service'  }
sub setName()   { __"Services" }
sub elemName()  { __"Service" }
sub iconFA()    { 'fa-solid fa-chart-line' }

sub secret()    { $_[0]->_data->{secret} }
sub contact()   { $_[0]->_data->{contact} }
sub support()   { $_[0]->_data->{support} }
sub termsLink() { $_[0]->_data->{terms} }
sub license()   { $_[0]->_data->{license} }
sub payments()  { $_[0]->_data->{payments} }
sub groupOnly() { $_[0]->_data->{group_only} }
sub licenseLink() { $_[0]->_data->{license_link} }
sub description() { $_[0]->_data->{description} }
sub usability()   { $_[0]->_data->{usability} }
sub endpointWebsite() { $_[0]->_data->{endpoint_ws} }
sub endpointPath()    { $_[0]->_data->{endpoint_path} }
sub infoWebsite()     { $_[0]->_data->{info_ws} }
sub infoPath()        { $_[0]->_data->{info_path} }
sub needsFacts()      { $_[0]->_data->{needs_facts} }
sub needsAssets()     { $_[0]->_data->{needs_assets} }
sub explainUser()     { $_[0]->_data->{explain_user} }
sub explainGroup()    { $_[0]->_data->{explain_group} }

sub contractPersons() { my $u = $_[0]->usability; $u eq 'person' || $u eq 'any' }
sub contractGroups()  { my $u = $_[0]->usability; $u eq 'group'  || $u eq 'any' }

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

=method useEndpoint $account
Returns both the proof as the URL which combines the M<endpointWebsite()>
with the M<endpointPath()> into a URL string.
=cut

sub useEndpoint($)
{	my ($self, $account) = @_;
	my $proof = $account->asset(websites => $self->endpointWebsite) or return ();
	($proof, $proof->link($self->endpointPath));
}

=method useInfoWebsite
Returns both the proof, as the path inside the website when the proof is valid.
=cut

my %assets;
sub useInfoWebsite()
{	my ($self) = @_;
	my $ws    = $self->infoWebsite or return ();
	my $proof = $::app->assets->asset($ws) or return ();
	($proof, $proof->link($self->infoPath));
}

1;
