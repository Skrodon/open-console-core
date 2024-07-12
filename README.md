
# LICENSE

This software is braught to you under the EUPL-1.2 (or later) license.
The text of this license can be found in the LICENSES directory.

# Open Console

The software for Open Console is spread of multiple repositories:
  * <https://github.com/Skrodon/open-console-core> Core (this repo)
  * <https://github.com/Skrodon/open-console-owner> Owner Website
  * <https://github.com/Skrodon/open-console-connect> Connection provider
  * <https://github.com/Skrodon/open-console-tasks> batch processing

# Open Console, Website Owner Interface
 
This project is part of https://open-console.eu Open Console, which is
(mainly) an initiative let website-owners communicate with service
which do something with their website, domain-name, or network.

For instance, the EU initiative https://OpenWebSearch.EU OpenWebSearch.EU
(which crawls websites for research and Google alternatives) uses this
interface to implement the (EU) legal requirements for correction rights
(take-downs).  Besides, it shows which parts of your site it collected,
and what information it extracted.

Open Console is a larger project: this sub-project only focusses on the
owner-to-service communication.  Other sub-projects focus on the exchange
of website information between parties who have information about websites,
and parties who need to know.  For instance, lists of phishing sites.

## Installing Perl modules

  * You may be able to install most of the required Perl packages from your distribution.  (When you have tried this, please contribute that list for inclusion here.  See the `Makefile.PL` for the list of required modules.)
  * Use Perl to install it for you:
	  * in the GIT extract of this code, run "perl Makefile.PL; make install`.  (You probably need super-admin rights to do this: depends on your Perl set-up)

# Developers
