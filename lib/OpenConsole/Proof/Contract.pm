# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Proof::Contract;
use Mojo::Base 'OpenConsole::Proof';

use Log::Report 'open-console-core';

use Encode       qw(decode);

use constant {
	CONTRACT_SCHEMA => '20240224',
};

=section DESCRIPTION

=section Constructors
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	$insert->{schema}  ||= CONTRACT_SCHEMA;

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

sub schema() { CONTRACT_SCHEMA }
sub set()    { 'contracts' }
sub element(){ 'contract'  }

sub sort()   { lc $_[0]->_data->{name} }
sub name()   { $_[0]->_data->{name} }

1;
