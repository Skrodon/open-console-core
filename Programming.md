# Programming rules

This page will list a number of coding decissions everyone adding code should understand.
These are generic rules: each component may add rules which are specific for the component.

## Objects

The "core" module defines all database objects, because they are
usually shared by different implementation components.

These objects share some fields, like status, expires, set, element,
name: see OpenConsole/Mango/Object.pm

### the stored data

The data which is stored in the database is kept inside the object in a
separate HASH.  You are only allowed to use accessors to that data,
except in the related Controller implementation (see open-console-owner).
For instance, OpenConsole::Account data can only be handled without
accessors in OwnerConsole/Controller/Account.pm

### short-lived data

Objects may also have other data, which is needed to run the program.
This data is (of course) not maintained in the data HASH.  Those fields
are in the main object HASH.

The keys start with something like "OA_", which are the first letters of
the object classes.  This reduces the chance of key name collissions in
inheritance.  It also makes it easier to debug object dumps in many-level
inheritance (what we like to use).

## Database

At the moment, MongoDB is used.  In the near future, we will move to use
CouchDB via the Couch::DB module.

### Objects referencing other objects

Be aware that the data you get from the database may be incomplete:
in a clustered (MongoDB) environment, reads are rather cheap and writes
are *very expensive*.  Therefore, we have introduced different database
clusters: "users" is high quality, hence may be slow, "assets" is fast
and your copy might be slightly behind.
