# A ground-up build of a puppetized box to run aegir drupal sites.

Built from scratch because all the examples I found had too much stuff that I didn't understand yet.

## Warning

This probably won't work for anyone but me - it was built on a local Virtualbox
and it's hard-coded to use a local apt-cacher I keep on another VM.
Because it takes 40 minutes to provision from scratch each time if I try to do
a dist-upgrade at home otherwise.

I found that almost no online help docs worked, as the versions of Puppet have
changed so much in the last 2 years it's impossible to find what best-practice,
or even 'supported' methodology is.

Seriously, do not expect this to work or to learn anything off it. It's only
in git so I can experiment with puppetmaster provisioning etc.

# Usage

Run

    vagrant up

This will take a while to download the box the first time if you do not
already have it.

## ssh

run

    vagrant ssh

to connect.

To use another ssh client, the user:pass is vagrant:vagrant
and more info about connecting (port 2222 and IP) may be seen by running

     vagrant ssh-config

## Website

The website it sets up is accessible via port forwarding, so may be found at

http://localhost:8080

# Diagnostics etc.

The puppet client should already be on the system.

It installs local things at /etc/puppet.

To re-apply the full set of puppet scripts, ssh in and:

    sudo puppet apply /vagrant/manifests/site.pp


More docs that took ages to unpack. To add a module directly on the guest:
( probably should not do this, but when testing, this is the command )

    puppet module --modulepath /vagrant/modules install puppetlabs-stdlib

.. fails in 2.7.11



# Intallation dependencies

Seeing as I thought the entire purpose of using puppet was *not* to re-invent
the wheel and just be able to say "I need Apache and PHP with mem_limit of 256"
I'm trying REALLY hard to re-use and import existing module manifests.
But most of the ones I find are horrible.
All the interesting tutorials teach us to go ahead and make our own thing,
and are full of individual file edits and shell calls,
or have exploded into dozens of enterprise-level dependency-hells.
What am I to do?

So I'm using git submodules to pull in a small handfull of what look like sane
lliraries from puppetlabs.
I get puppet modules for apt, apache and mysql from there.
Could not find one for PHP

Using the puppetlabs modules also requires
'puppetlabs/stdlib'
'puppetlabs/concat'

I'm still having trouble with the execution order for apt.

# More

This was pulled together by referring to multiple sources.
I still can't figure out why every example seems to create its own full
libraries of Puppet class files and manifests - isn't the point to re-use
the common setup requirements and make them overridable as needed
- not to rewrite them every time?

https://puphpet.com/
Gave me some hints, but the auto-generated code was so riddled with
OS-related if-thens that it was hard to read.

https://github.com/mikkeschiren/vagrant-example
Looks clearer, but despite seeming simple on the top where it just listed the
included modules by name, it also distributes the full source code of those
handmade modules. Where is the re-use?

Variations of aegir-up kept their code in funny places

# Things I did not know

## Order of operations

Puppet does not run your actions in order as specified in your .pp file.
That's madenning until you end up listing all the dependency orders/

## Language:

  class util-setup {

and

  class { 'util-setup':

Are *totally* different parts of the language.
The first begins a class declaration that we out code actions into.
The second re-uses an existing class found in /modules, referred to by name
 and optionally sets some parameters to use when wh call it.

The first one does NOT instantiate the class, and requires you to
  include "util-setup"

The second one DOES instantiate it immediately!
http://garylarizza.com/blog/2011/03/11/using-run-stages-with-puppet/

## apt versions

If we use only the Ubuntu stable repositories, we have very little choice as
to the available versions.
On 'precise', PHP is locked to "5.3.10-1ubuntu3.11".
Note that the full string is required as the version. Though "5.3.10-1ubuntu3"
also works.

We can tell the package manager to

    package { "php5":
      ensure => "5.3.10-1ubuntu3.11",
    }

And that will work, but no other number will.
For other versions, we will need to add a different repo.

Adding a private repo where newer versions of PHP can be got is helpful.
http://www.jeffmould.com/2013/10/06/upgrading-from-php-5-3-to-5-x-on-ubuntu-12-04/
Though that requres you to know the obscure version number also :
"5.5.11-2+deb.sury.org~precise+2"

### Specific versions

But what about older versions?

And what about downgrading (and holding/pinning)?

The terminology is now 'hold' as 'pin' is mutable and only hints at the version
we want but does not enforce it of some other thing wants to pull the old
version up..


If I try to use this months new Ubuntu LTS ('trusty')
and used "ensure present"
I would get given  5.5.9+dfsg-1ubuntu4

Listing the available versions does not work:

    apt-cache madison php5

Not unless additional repos are added.

By adding

  deb http://bg.archive.ubuntu.com/ubuntu/ precise main restricted

We get access to 5.3.10-1ubuntu3
Then we need to specify the version and also 'hold' the version
- for all php-related mods.


### Clean-slate to begin

If they have already been installed :

Find them all
    dpkg --get-selections | grep php
    dpkg -l | grep php
kill them all
    apt-get purge php5 php5-common php5-gd php5-mysql php5-cgi php5-cli php-pear php5-curl php5-json php5-readline libapache2-mod-php5


But on a new box, that's no big deal.
Instead, use the puppet-apt tool and hold them.
This works by giving a higher priority to the older archive version..
though it does not prevent accidental upgrades.

### Madness with circular loops

It turns out that specifying a perferred version for one part of php, but not
for others (like php5-gd) craps out, OR forcibly upgrades the thing you were
trying to keep back OR produces some combination of the two.
We need to hold them all at the same time, and this is possible byu putting all
versions and numbers on the same line using apt-get, but NOT when using puppet
as it installs each package one by one, in no special order.

To get this all installed at all, we need to 'pin' and define our preferred
install versions.

### Diagnostics

To find what version is installed,

    dpkg -l | grep php

To add pins, use the puppet-apt utility apt::hold in the manifest

    apt::hold { $packages:
      # Here it requires the partial version number.
      version => '5.7.10*',
    }

Which produces configs ('pins') in /etc/apt/preferences.d like so:

    Explanation: apt: hold php5 at 5.7.10*
    Package: php5
    Pin: version 5.7.10*
    Pin-Priority: 1001

To find what priorities the competing versions have

    apt-cache policy php5-cgi

However the output from that is deceptive. Explained a little better here.
http://carlo17.home.xs4all.nl/howto/debian.html#errata

    php5-cgi:
      Installed: (none)
      Candidate: 5.3.10-1ubuntu3
      Package pin: 5.3.10-1ubuntu3
      Version table:
         5.5.9+dfsg-1ubuntu4 1000
            500 http://mirrors.digitalocean.com/ubuntu/ trusty/main amd64 Packages
         5.3.10-1ubuntu3 1000
            500 http://bg.archive.ubuntu.com/ubuntu/ precise/main amd64 Packages

The 1000 there is only a value to match against, not the value found.
We specified that
"A version 5.3.10 is worth 1000 points, now search for anything that meets or beats that value"
And that has been correctly identified as the "candidate",
no matter what the weightings on the repository lists are
(500 and 500 respectively, as both candidates are from stable milestone repos).

### Gotchas

* The gotcha that killed me was that the 'version' in a 'pin'
  is not the full version string we use elsewhere, like in apt-get.
  NOT:     5.3.10-1ubuntu3
  INSTEAD: 5.3.10*
  This lost me the whole day.

* Actually, what lost me the rest of the day was that apt::hold creates
  conf files with spaces in, and SPACES DO NOT WORK.

* If you specify a version that is not available from the current repos,
  it ignores you and takes a guess as if you said nothing.
  Gee thanks.

* If you then install something that is not pinned, and the latest version of
  that expects the latest version of the rest, the rest will be instantly
  upgraded to meet the newbies expectations.
  Instant death, why did we bother.
  Need to also 'hold' it to prevent this from happening.


### Really 'holding' a version

Doing something innocuous manually now, like

    apt-get install php5-ldap

Can destroy all our fun. It will pull everything along to the latest.

apt::hold (right now) does NOT actually 'hold' (and lock) it.
Some excuses for this are in the docs, but the promised solution does not deliver.
https://github.com/puppetlabs/puppetlabs-apt
The concept it refers to as
"causes a version to be installed even if this constitutes a downgrade of the package"
http://www.howtoforge.com/a-short-introduction-to-apt-pinning
does NOT prevent later dependencies from upgrading the parent.

To do that,

    apt-mark hold php5-common

So now, an inadvertant and presumed safe action like:

    apt-get install php5-ldap

Will NOT kill everything, it will just make you figure out that life is terrible
and you need to go:

    apt-get install php5-ldap=5.3.10-1ubuntu3

Note that AFTER locking a package, apt-get will complain and die if you try a
simple update that would break the lock. But if you use aptitude, it will
problem-solve for you:

    $ aptitude install php5-xsl
    The following NEW packages will be installed:
      libxslt1.1{a} php5-xsl{b}
    0 packages upgraded, 2 newly installed, 0 to remove and 7 not upgraded.
    Need to get 159 kB of archives. After unpacking 587 kB will be used.
    The following packages have unmet dependencies:
     php5-xsl : Depends: phpapi-20121212 which is a virtual package.
                Depends: php5-common (= 5.5.9+dfsg-1ubuntu4) but 5.3.10-1ubuntu3 is installed and it is kept back.
    The following actions will resolve these dependencies:

         Keep the following packages at their current version:
    1)     php5-xsl [Not Installed]

    Accept this solution? [Y/n/q/?] n


    The following actions will resolve these dependencies:

         Install the following packages:
    1)     php5-xsl [5.3.10-1ubuntu3 (precise)]


    Accept this solution? [Y/n/q/?]

Yep, that is the solution.
