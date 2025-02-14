# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::Model;
use Mojo::Base -base;

use Log::Report 'open-console-core';

=chapter NAME
OpenConsole::Model - base-class for all Models

=chapter DESCRIPTION

=over 4
=item * M<OpenConsole::Model::Users>
tables for accounts, identities, and groups.

=item * M<OpenConsole::Model::Assets>
tables for proofs, contracts, and services.

=item * M<ConnectConsole::Model::Connect>
tables for appsessions and complies.

=back

=chapter METHODS

=section Attributes
=cut

#-----------
=section Other

=method upgrade %options
Upgrade all tables which are contained in this Model.
=cut

sub upgrade(%) { }

=method _upgrade $table
Generic activities during upgrading one table.
=cut

sub _upgrade($) { }

1;
