# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Proof::Website1;
use Mojo::Base 'OpenConsole::Proof';

use Log::Report 'open-console-core';

use Net::LibIDN  qw(idn_to_unicode);
use Encode       qw(decode);

use constant {
	WEB1_SCHEMA => '20240218',
};

=section DESCRIPTION

=section Constructors
=cut

sub create($%)
{	my ($class, $insert, %args) = @_;
	$insert->{schema}  ||= WEB1_SCHEMA;

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

sub set()    { 'websites' }
sub element(){ 'website'  }
sub algo()   { 'website1' }
sub sort()   { lc $_[0]->_data->{url} }
sub _score() { 50 }

sub schema() { WEB1_SCHEMA }

sub url()    { $_[0]->_data->{url} }

sub urlUnicode
{	my $self = shift;

	# Net::LibDN "Limitations" explains it returns bytes not a string
	$self->{OPW_uni} //= decode 'utf-8', idn_to_unicode($self->url, 'utf-8');
}

1;
