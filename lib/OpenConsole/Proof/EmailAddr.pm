# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Proof::EmailAddr;
use Mojo::Base 'OpenConsole::Asset::Proof';

use Log::Report 'open-console-core';

=chapter NAME
OpenConsole::Proof::EmailAddr - collectable proof of website ownership

=chapter DESCRIPTION
=chapter METHODS
=section Constructors
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	$insert->{sub_addressing} //= 0;
	$class->SUPER::create($insert, %args);
}

#-------------
=section Attributes
=cut

sub schema()  { '20240210' }
sub element() { 'emailaddr'  }
sub set()     { 'emailaddrs' }
sub elemName(){ __"Email address" }
sub setName() { __"Email addresses" }
sub iconFA()  { 'fa-solid fa-envelope-circle-check' }

sub email()   { $_[0]->_data->{email} }
*name = \&email;

sub supportsSubAddressing() { $_[0]->_data->{sub_addressing} }

#-------------
=section Other
=cut

sub score()   { 50 }

1;
