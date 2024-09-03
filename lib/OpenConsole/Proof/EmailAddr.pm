# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Proof::EmailAddr;
use Mojo::Base 'OpenConsole::Proof';

use Log::Report 'open-console-core';

use constant {
	ADDR1_SCHEMA => '20240210',
};

=chapter NAME
OpenConsole::Proof::EmailAddr - collectable proof of website ownership

=chapter DESCRIPTION
=chapter METHODS
=section Constructors
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	$insert->{schema}  ||= ADDR1_SCHEMA;
	$insert->{sub_addressing} //= 0;

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

sub schema()  { ADDR1_SCHEMA }
sub set()     { 'emailaddrs' }
sub element() { 'emailaddr'  }
sub sort()    { lc $_[0]->_data->{email} }

sub email()   { $_[0]->_data->{email} }
sub supportsSubAddressing() { $_[0]->_data->{sub_addressing} }

#-------------
=section Other
=cut

sub score()   { 50 }

1;
