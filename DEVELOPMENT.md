Preface
=======

Whimsy is a set of independent tools and a common library which typically will
need to access various ASF SVN directories and/or LDAP.  To do development and
testing, you will need access to a machine on which you are willing to install
libraries which do things like access LDAP, XML parsing, ASF Subversion repos,
composing mail and the like for full functionality.  

Contents :books:
-------

- [Architecture](#architecture-overview)
- [Setup Whimsy Locally](#setup-whimsy-locally)
- [Running Whimsy Applications](#running-whimsy-applications)
- [Advanced Configuration](#advanced-configuration)
- [Server Configuration](DEPLOYMENT.md)
- [Further Reading](#further-reading)
- [How To / FAQ](#how-to-faq)
- [Running Whimsy on Windows](#whimsy-on-windows)

Architecture Overview
========

The core Whimsy code is split into model/view, with a variety of independent tools.

1. [lib/whimsy/asf](lib/whimsy/asf) contains the "model", i.e., a set of classes
   which encapsulate access
   to a number of data sources such as LDAP, ICLAs, auth lists, etc.  This
   code originally was developed as a part of separate tools and was later
   refactored out into a common library.  Some of the older tools don't fully
   make use of this refactoring.

2. [www](www) contains the "view", largely a set of CGI scripts that produce
   HTML.  Generally a CGI script is self contained, including all of the CSS,
   scripts, AJAX logic (client and server), SVG images, etc.  A single script
   may also produce a set (subtree) of web pages.  CGI scripts can be
   identified by their `.cgi` file extension.

   Some of the directories (like the roster tool) contain
   <a name="rackapp">[rack](http://rack.github.io/) applications</a>.  These can be run
   independently, or under the Apache web server through
   the use of [Phusion Passenger](https://www.phusionpassenger.com/).
   Directories containing Rack applications can be identified by the presence
   of a file with the name of `config.ru`.

3. [tools](tools) contains miscellaneous and testing tools.

4. [config](config) contains some sample configuration data for 
   installing various services needed.  

Setup Whimsy Locally
=====

This section is for those desiring to run a whimsy tool on their own machine.
[See below for deploying](#advanced-configuration) in a Docker container or a Vagrant VM.

1. **Setup ruby 1.9.3 or higher.**  Verify with `ruby -v`.
   If you use a system provided version of Ruby, you may need to prefix
   certain commands (like gem install) with `sudo`.  Alternatives to using
   the system provided version include using a Ruby version manager like
   `rbenv` or `rvm`.  Rbenv generally requires you to be more aware of what you
   are doing (e.g., the need for rbenv shims).  Rvm tends to be more of a set
   and forget operation, but it tends to be more system intrusive (e.g. aliasing
   'cd' in bash).  Note the Whimsy server currently uses **ruby 2.3+**.

    For more information:

    1. [Understanding rbenv Shims](https://github.com/sstephenson/rbenv#understanding-shims)
    2. [Understanding rbenv Binstubs](https://github.com/sstephenson/rbenv/wiki/Understanding-binstubs)
    3. [Ruby Version Manager - rvm](https://rvm.io/)


2. **Install ruby gems:** `whimsy-asf` and `bundler`:

   `gem install whimsy-asf bundler`  (mail and listen may be needed too)

3. **SVN checkout ASF repositories** into (or linked to from)
   `/srv/svn`

        svn co --depth=files https://svn.apache.org/repos/private/foundation

   You can specify an alternate location for these directories by placing
   a YAML [configuration file](CONFIGURE.md) named `.whimsy` in your home 
   directory  An minimal example (be sure to include the dashed lines!):

        :svn:
        - /home/rubys/svn/foundation
        - /home/rubys/svn/committers
   
   See repository.yml for a full list of repos needed.  Different tools 
   require different local checkouts to function; some require git clone.

4. **Configure LDAP** servers and certificates:
<a name="ldapconfig"> </a>

    1. The model code determines what host and port to connect to by parsing
      either `/etc/ldap/ldap.conf` or `/etc/openldap/ldap.conf` for a line that
      looks like the following:
        `uri     ldaps://ldap1-lw-us.apache.org:636`

    2. A `TLS_CACERT` can be obtained via either of the following commands:

        `ruby -r whimsy/asf -e "puts ASF::LDAP.cert"`<br/>
        `openssl s_client -connect ldap1-lw-us.apache.org:636 </dev/null`

      Copy from `BEGIN` to `END` inclusive into the file
      `/etc/ldap/asf-ldap-client.pem`.  Point to the file in
      `/etc/ldap/ldap.conf` with a line like the following:

     ```   TLS_CACERT      /etc/ldap/asf-ldap-client.pem```

      N.B. OpenLDAP on Mac OS/X uses `/etc/openldap/` instead of `/etc/ldap/`
      Adjust the paths above as necessary.  Additionally ensure that
      that `TLS_REQCERT` is set to `allow`.

      Note: the certificate is needed because the ASF LDAP hosts use a
      self-signed certificate.

      Simple way to configure LDAP is:

        sudo ruby -r whimsy/asf -e "ASF::LDAP.configure"

      These commands can also be used to update your configuration as
      the ASF changes LDAP servers; they are cached in your `.whimsy`.

5. **Verify your configuration** by running:

   `ruby examples/board.rb`

   It should print out an HTML page with current board members.
   See comments in the `board.rb` file for running the script as a 
   standalone server to view in a local web browser.

6. **Configure mail sending** :mailbox_with_mail: (_optional_):

   Configuration of outbound mail delivery is done through the `.whimsy`
   file.  Three examples are provided below, followed by links to where
   documentation of the parameters can be found.

        :sendmail:
          delivery_method: sendmail

        :sendmail:
          delivery_method: smtp
          address: smtp-server.nc.rr.com
          domain:  intertwingly.net

        :sendmail:
          delivery_method: smtp
          address: smtp.gmail.com
          port: 587
          domain: apache.org
          user_name: username
          password: password
          authentication: plain
          enable_starttls_auto: true

   For more details, see the mail gem documention for
   [smtp](http://www.rubydoc.info/github/mikel/mail/Mail/SMTP),
   [exim](http://www.rubydoc.info/github/mikel/mail/Mail/Exim),
   [sendmail](http://www.rubydoc.info/github/mikel/mail/Mail/Sendmail),
   [testmailer](http://www.rubydoc.info/github/mikel/mail/Mail/TestMailer), and
   [filedelivery](http://www.rubydoc.info/github/mikel/mail/Mail/FileDelivery)

Running Whimsy Applications :car:
============================

If there is a `Gemfile` in the directory containing the script or application
you wish to run, dependencies needed for execution can be installed using the
command `bundle install`.  Similarly, if starting from scratch you 
may need `gem install rake`.

1. CGI applications can be run from a command line, and produce output to
   standard out.  If you would prefer to see the output in a browser, you
   will need to have a web server configured to run CGI, and a small CGI
   script which runs your application.  For CGI scripts that make use of
   wunderbar, this script can be generated and installed for you by
   passing a `--install` option on the command, for example:

       ruby examples/board.rb --install=~/Sites/

   Note that by default CGI scripts run as a user with a different home
   directory very little privileges.  You may need to copy or symlink your
   `~/.whimsy` file and/or run using
   [suexec](http://httpd.apache.org/docs/current/suexec.html).

2. [Rack applications](#rackapp) can be run as a standalone web server.  If a `Rakefile`
   is provided, the convention is that `rake server` will start the server,
   typically with listeners that will automatically restart the application
   if any source file changes.  If a `Rakefile` isn't present, the `rackup`
   command can be used to start the application.

   If you are testing an application that makes changes to LDAP, you will
   need to enter your ASF password.  To do so, substitute `rake auth server`
   for the `rake server` command above.  This will prompt you for your
   password.  Should your ASF availid differ from your local user id,
   set the `USER` environment variable prior to executing this command.

Advanced Configuration
======================

Setting things up so that the **entire** whimsy website is available as
a virtual host, complete with authentication:

1. Install passenger by running either running 
   `passenger-install-apache2-module` and following its instructions, or
   by visiting https://www.phusionpassenger.com/library/install/apache/install/oss/.

2. Visit [vhost-generator](https://whimsy.apache.org/test/vhost-generator) to
   generate a custom a vhost definition, and to see which apache modules need
   to be installed.

   a. On Ubuntu, place the generated vhost definition into
      `/etc/apache2/sites-available` and enable the site using `a2ensite`.
      Enable the modules you need using `a2ensite`.  Restart the Apache httpd
      web server using `service apache2 restart`.

   b. On Mac OS/X, place the generated vhost definition into
      `/private/etc/apache2/extra/httpd-vhosts.conf`.  Edit
      `/etc/apache2/httpd.conf` and uncomment out the line that includes
      `httpd-vhosts.conf`, and
      enable the modules you need by uncommenting out the associated lines.
      Restart the Apache httpd web server using `apachectl restart`.

3. (Optional) run a service that will restart your passenger applications
   whenever the source to that application is modified.  On Ubuntu, this is
   done  by creating a `~/.config/upstart/whimsy-listener` file with the
   following contents:

       description "listen for changes to whimsy applications"
       start on dbus SIGNAL=SessionNew
       exec /srv/whimsy/tools/toucher
       
More details about the production Whimsy instance are in [DEPLOYMENT.md](DEPLOYMENT.md)

How To / FAQ :question:
============

### How To: Create A New Whimsy CGI

The simplest way to create a new standalone tool is copy an existing .cgi. 
Important things to check:

- chmod 755 is likely needed
- Double-check paths to the lib/asf files (which you will be using a lot)
- Test locally first; in production logs are in [/members/log](https://whimsy.apache.org/members/log/)

### How To: Use New SVN or Git Directories

Some SVN/Git repos/files are checked out via cron jobs regularly for 
caching and read only access.  Some applications checkout needed files 
just when running into temp dirs (typically to modify them and commit 
changes).  If you have trouble using the existing [ASF::SVN classes](lib/whimsy/asf/svn.rb) 
class to access files from Subversion on the server, then check:

- Default SVN checkouts: [repository.yml](repository.yml)

### How To: Keep Your Local Environment Updated

`rake update git:pull svn:update` will crawl the tree, updating all 
gems as well as pulling/updating any existing git or svn checkouts that
you have locally from repository.yml.

Note also that sometimes you may need to `bundle exec *command*` instead 
of just doing `bundle *command*`, since using the exec uses a subtly 
different set of gem versions from the local director.

Whimsy On Windows
=================

While some tools may work on Microsoft Windows, many don't currently.  
Alternatives for Windows include a Docker image, a custom Vagrant VM, and a Kitchen/Puppet 
managed Vagrant VM (as the [live instance](DEPLOYMENT.md) does).  The primary advantage 
of using an image or a VM is isolation.  The primary disadvantage is that 
you will need to install your SVN credentials there and arrange to either 
duplicate or mount needed SVN directories.

Further Reading
===============

The [board agenda](www/board/agenda) application
is an eample of a complete tool that makes extensive use of the library
factoring, has a suite of test cases, and client componentization (using
ReactJS), and provides instructions for setting up both a Docker component and
a Vagrant VM.  There are [custom setup steps](config/board-agenda.md) to run it locally.

If you would like to understand how the view code works, you can get started
by looking at a few of the
[Wunderbar demos](https://github.com/rubys/wunderbar/tree/master/demo)
and [README](https://github.com/rubys/wunderbar/blob/master/README.md).
