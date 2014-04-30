#

group { "puppet":
  ensure => "present",
}

File { owner => 0, group => 0, mode => 0644 }

# Global site additions :
# I like putting lots of handy info into the login screen.

file { '/etc/motd':
  content => "This box is managed by Puppet.
  Built as an Drupal Aegir Slave
    by dman 2014.
  "
}
file { "/etc/update-motd.d/40-about-puppet":
  ensure  => file,
  # I can't get 'puppet:///files/' to resolve here. Not when running local at least. 
  source => "/etc/puppet/files/etc/update-motd.d/40-about-puppet",
  mode => '0755',
}
file { "/etc/update-motd.d/30-about-server":
  ensure  => file,
  # I can't get 'puppet:///files/' to resolve here. Not when running local at least.
  source => "/etc/puppet/files/etc/update-motd.d/30-about-server",
  mode => '0755',
}

# If I don't have the puppetlabs libraries, pain.
# to prevent "Invalid resource type module_dir"

include "stdlib"


# Most of the individual setups are listed in 'nodes'

import "nodes"

