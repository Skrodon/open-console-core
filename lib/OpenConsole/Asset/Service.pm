# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Asset::Service;
use Mojo::Base 'OpenConsole::Asset';

use Log::Report 'open-console-core';

use Encode       qw(decode);

use constant {
	SERVICE_SCHEMA => '20240912',
};

=chapter NAME
OpenConsole::Asset::Service - describes a Service

=chapter DESCRIPTION
The "service" defines what an organization has to offer to other
people.  The service is described as a rules, which needs to match
the information which the user of that service is willing to give.
Together, the "service" and the (personal or group identity)
negotiate a "contract" of usage.

=chapter METHODS
=section Constructors
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	$insert->{schema}  ||= SERVICE_SCHEMA;

	my $self = $class->SUPER::create($insert, %args);
	$self;
}

#sub fromDB($)
#{	my ($class, $data) = @_;
#	$class->SUPER::fromDB($data);
#}

#-------------
=section Attributes
=cut

sub schema() { SERVICE_SCHEMA }
sub set()    { 'services' }
sub element(){ 'service'  }

sub sort()   { lc $_[0]->_data->{name} }
sub name()   { $_[0]->_data->{name} }

1;