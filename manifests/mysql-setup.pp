notice("Setting up Mysql")

# Using the module distributed by puppetlabs.
# https://github.com/puppetlabs/puppetlabs-mysql#usage

class  { 'mysql::server':
  #override_options => { 'mysqld' => { 'max_connections' => '1024' } }
}
include "mysql::server"
include "mysql::client"
