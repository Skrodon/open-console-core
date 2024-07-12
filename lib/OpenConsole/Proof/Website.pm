# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Proof::Website;
use Mojo::Base 'OpenConsole::Proof';

use Log::Report 'open-console-core';

use OpenConsole::Util qw(new_token);
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

sub schema() { WEB1_SCHEMA }
sub set()    { 'websites' }
sub element(){ 'website'  }
sub sort()   { lc $_[0]->_data->{url} }

sub url()          { $_[0]->_data->{url} }
sub challenge()    { $_[0]->_data->{challenge} ||= new_token 'C' }

sub verifyURL()    { $_[0]->_data->{verifyURL} || {}}
sub hostPunicode() { $_[0]->verifyURL->{host_puny} }
sub normalizedURL() { $_[0]->verifyURL->{url_normalized} }
sub printableURL()  { $_[0]->verifyURL->{url_printable} }

sub urlUnicode
{	my $self = shift;

	# Net::LibDN "Limitations" explains it returns bytes not a string
	$self->{OPW_uni} //= decode 'utf-8', idn_to_unicode($self->url, 'utf-8');
}

1;
