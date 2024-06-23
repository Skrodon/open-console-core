# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@open-console.eu>
# SPDX-License-Identifier: EUPL-1.2-or-later

package OpenConsole::OpenID::Discovery;
use Mojo::Base 'Mojolicious';

use Log::Report 'open-console-core';

=chapter NAME

OpenConsole::OpenID::Discovery = manage discovery reply

=chapter SYNOPSIS

  

=chapter DESCRIPTION

As specified in F<https://openid.net/specs/openid-connect-discovery-1_0.html>,
a GET on location C</.well-known/openid-configuration> should return a complex
structure.  The location should be absolute within the issuer URI.

  https://open-console.eu/contract/.well-known/openid-configuration
  https://contract.open-console.eu/.well-known/openid-configuration

=chapter METHODS

=section Constructors
=cut

=pod example of a reply

  TOKEN=temporary session id
  SCOPE="contract"

  HTTP/1.1 200 OK
  Content-Type: application/json

  {
   "issuer":                                              # required
     "https://server.example.com",
   "authorization_endpoint":                              # required
     "https://server.example.com/connect/authorize",
   "token_endpoint":                                      # required
     "https://server.example.com/connect/token",
   "token_endpoint_auth_methods_supported":
     ["client_secret_basic", "private_key_jwt"],
   "token_endpoint_auth_signing_alg_values_supported":
     ["RS256", "ES256"],
   "userinfo_endpoint":                                   # recommended
     "https://server.example.com/connect/userinfo",
   "check_session_iframe":
     "https://server.example.com/connect/check_session",
   "end_session_endpoint":
     "https://server.example.com/connect/end_session",
   "jwks_uri":                                            # required
     "https://server.example.com/jwks.json",
   "registration_endpoint":
     "https://server.example.com/connect/register",
   "scopes_supported":                                    # recommended
     ["openid", "profile", "email", "address",
      "phone", "offline_access"],
   "response_types_supported":                            # required
     ["code", "code id_token", "id_token", "id_token token"],
   "acr_values_supported":
     ["urn:mace:incommon:iap:silver",
      "urn:mace:incommon:iap:bronze"],
   "subject_types_supported":                             # required
     ["public", "pairwise"],
   "userinfo_signing_alg_values_supported":
     ["RS256", "ES256", "HS256"],
   "userinfo_encryption_alg_values_supported":
     ["RSA-OAEP-256", "A128KW"],
   "userinfo_encryption_enc_values_supported":
     ["A128CBC-HS256", "A128GCM"],
   "id_token_signing_alg_values_supported":
     ["RS256", "ES256", "HS256"],
   "id_token_encryption_alg_values_supported":            # required
     ["RSA-OAEP-256", "A128KW"],
   "id_token_encryption_enc_values_supported":
     ["A128CBC-HS256", "A128GCM"],
   "request_object_signing_alg_values_supported":
     ["none", "RS256", "ES256"],
   "display_values_supported":
     ["page", "popup"],
   "claim_types_supported":
     ["normal", "distributed"],
   "claims_supported":
     ["sub", "iss", "auth_time", "acr",
      "name", "given_name", "family_name", "nickname",
      "profile", "picture", "website",
      "email", "email_verified", "locale", "zoneinfo",
      "http://example.info/claims/groups"],
   "claims_parameter_supported":
     true,
   "service_documentation":
     "http://server.example.com/connect/service_documentation.html",
   "ui_locales_supported":
     ["en-US", "en-GB", "en-CA", "fr-FR", "fr-CA"]
  }

=cut

#----------------
=section Other

=cut

1;
