#
# Example file for building out a multi-node environment
#
# This example creates nodes of the following roles:
#   swift_storage - nodes that host storage servers
#   swift_proxy - nodes that serve as a swift proxy
#   swift_ringbuilder - nodes that are responsible for
#     rebalancing the rings
#
# This example assumes a few things:
#   * the multi-node scenario requires a puppetmaster
#   * networking is correctly configured
#
# These nodes need to be brought up in the following order:
#
# 1. storage nodes
# 2. ringbuilder
# 3. run the storage nodes again (to synchronize the ring db)
# 4. run the proxy
# 5. test that everything works!!
# this site manifest serves as an example of how to deploy a multi-node swift environment.

# Top-level Swift Configuration Parameters
$swift_user_password     = 'swift_pass'
$swift_shared_secret     = 'Gdr8ny7YyWqy2'
$swift_local_net_ip      = $ipaddress_eth0
$swift_memcache_servers  = ['192.168.220.52:11211,192.168.220.53:11211']

# configurations that need to be applied to all swift nodes
node swift_base inherits base  {

  class { 'ssh::server::install': }

  class { 'swift':
    # not sure how I want to deal with this shared secret
    swift_hash_suffix => "$swift_shared_secret",
    package_ensure    => latest,
  }

}

# The following specifies 3 swift storage nodes
node /swift01/ inherits swift_base {

 # Configure /etc/network/interfaces file
 class { 'networking::interfaces':
   node_type           => swift-storage,
   mgt_is_public       => true,
   vlan_networking     => true,
   vlan_interface      => "eth0",
   mgt_interface       => "eth0",
   mgt_ip              => "192.168.220.71",
   mgt_gateway         => "192.168.220.1",
   storage_vlan        => "221",
   storage_ip          => "192.168.221.71",
   dns_servers         => "192.168.220.254",
   dns_search          => "dmz-pod2.lab",
 }

  include swift-ucs-disk
  $swift_zone = 1
  include role_swift_storage

}
node /swift02/ inherits swift_base {

 # Configure /etc/network/interfaces file
 class { 'networking::interfaces':
   node_type           => swift-storage,
   mgt_is_public       => true,
   vlan_networking     => true,
   vlan_interface      => "eth0",
   mgt_interface       => "eth0",
   mgt_ip              => "192.168.220.72",
   mgt_gateway         => "192.168.220.1",
   storage_vlan        => "221",
   storage_ip          => "192.168.221.72",
   dns_servers         => "192.168.220.254",
   dns_search          => "dmz-pod2.lab",
 }

  include swift-ucs-disk
  $swift_zone = 2
  include role_swift_storage

}
node /swift03/ inherits swift_base {

 # Configure /etc/network/interfaces file
 class { 'networking::interfaces':
   node_type           => swift-storage,
   mgt_is_public       => true,
   vlan_networking     => true,
   vlan_interface      => "eth0",
   mgt_interface       => "eth0",
   mgt_ip              => "192.168.220.73",
   mgt_gateway         => "192.168.220.1",
   storage_vlan        => "221",
   storage_ip          => "192.168.221.73",
   dns_servers         => "192.168.220.254",
   dns_search          => "dmz-pod2.lab",
 }

  include swift-ucs-disk
  $swift_zone = 3
  include role_swift_storage

}

# Used to create XFS volumes for Swift storage nodes.

class swift-ucs-disk {

  include swift::xfs

  $byte_size = '1024'
  $size = '499GB'
  $mnt_base_dir = '/srv/node'

  file { $mnt_base_dir:
        ensure => directory,
	owner => 'swift',
	group => 'swift',
  }

  swift::storage::disk { 'sdb':
    device => "sdb",
    mnt_base_dir => $mnt_base_dir,
    byte_size => $byte_size,
    size => $size
  }

  swift::storage::disk { 'sdc':
    device => "sdc",
    mnt_base_dir => $mnt_base_dir,
    byte_size => $byte_size,
    size => $size
  }

  swift::storage::disk { 'sdd':
    device => "sdd",
    mnt_base_dir => $mnt_base_dir,
    byte_size => $byte_size,
    size => $size
  }

  swift::storage::disk { 'sde':
    device => "sde",
    mnt_base_dir => $mnt_base_dir,
    byte_size => $byte_size,
    size => $size
  }

  swift::storage::disk { 'sdf':
    device => "sdf",
    mnt_base_dir => $mnt_base_dir,
    byte_size => $byte_size,
    size => $size
  }
}

class role_swift_storage {

  # install all swift storage servers together
  class { 'swift::storage::all':
    storage_local_net_ip => $swift_local_net_ip,
  }

  # specify endpoints per device to be added to the ring specification
  @@ring_object_device { "${swift_local_net_ip}:6000/sdb":
    zone        => $swift_zone,
    weight      => 1,
  }

  @@ring_object_device { "${swift_local_net_ip}:6000/sdc":
    zone        => $swift_zone,
    weight      => 1,
  }

  @@ring_object_device { "${swift_local_net_ip}:6000/sdd":
    zone        => $swift_zone,
    weight      => 1,
  }

  @@ring_object_device { "${swift_local_net_ip}:6000/sde":
    zone        => $swift_zone,
    weight      => 1,
  }

  @@ring_object_device { "${swift_local_net_ip}:6000/sdf":
    zone        => $swift_zone,
    weight      => 1,
  }

  @@ring_container_device { "${swift_local_net_ip}:6001/sdb":
    zone        => $swift_zone,
    weight      => 1,
  }

  @@ring_container_device { "${swift_local_net_ip}:6001/sdc":
    zone        => $swift_zone,
    weight      => 1,
  }

  @@ring_container_device { "${swift_local_net_ip}:6001/sdd":
    zone        => $swift_zone,
    weight      => 1,
  }

  @@ring_container_device { "${swift_local_net_ip}:6001/sde":
    zone        => $swift_zone,
    weight      => 1,
  }

  @@ring_container_device { "${swift_local_net_ip}:6001/sdf":
    zone        => $swift_zone,
    weight      => 1,
  }

  @@ring_account_device { "${swift_local_net_ip}:6002/sdb":
    zone        => $swift_zone,
    weight      => 1,
  }

  @@ring_account_device { "${swift_local_net_ip}:6002/sdc":
    zone        => $swift_zone,
    weight      => 1,
  }

  @@ring_account_device { "${swift_local_net_ip}:6002/sdd":
    zone        => $swift_zone,
    weight      => 1,
  }

  @@ring_account_device { "${swift_local_net_ip}:6002/sde":
    zone        => $swift_zone,
    weight      => 1,
  }

  @@ring_account_device { "${swift_local_net_ip}:6002/sdf":
    zone        => $swift_zone,
    weight      => 1,
  }

  # collect resources for synchronizing the ring databases
  Swift::Ringsync<<||>>

}

node /<proxy_node1>/ inherits swift_base {

 # Configure /etc/network/interfaces file
 class { 'networking::interfaces':
   node_type           => swift-proxy,
   mgt_is_public       => true,
   vlan_networking     => true,
   vlan_interface      => "eth0",
   mgt_interface       => "eth0",
   mgt_ip              => "192.168.220.52",
   mgt_gateway         => "192.168.220.1",
   storage_vlan        => "221",
   storage_ip          => "192.168.221.52",
   dns_servers         => "192.168.220.254",
   dns_search          => "dmz-pod2.lab",
 }

  # curl is only required so that I can run tests
  package { 'curl': ensure => present }

  class { 'memcached':
    listen_ip => $swift_local_net_ip,
  }

  # specify swift proxy and all of its middlewares
  class { 'swift::proxy':
    proxy_local_net_ip => $swift_local_net_ip,
    pipeline           => [
      'catch_errors',
      'healthcheck',
      'cache',
      'ratelimit',
      'swift3',
      's3token',
      'authtoken',
      'keystone',
      'proxy-server'
    ],
    account_autocreate => true,
    # TODO where is the  ringbuilder class?
    require            => Class['swift::ringbuilder'],
  }

  # configure all of the middlewares
  class { [
    'swift::proxy::catch_errors',
    'swift::proxy::healthcheck',
    #'swift::proxy::cache',
    'swift::proxy::swift3',
  ]: }
  
  class { 'swift::proxy::cache':
    memcache_servers  	   => $swift_memcache_servers,   
  }

  class { 'swift::proxy::ratelimit':
    clock_accuracy         => 1000,
    max_sleep_time_seconds => 60,
    log_sleep_time_seconds => 0,
    rate_buffer_seconds    => 5,
    account_ratelimit      => 0
  }
  class { 'swift::proxy::s3token':
    # assume that the controller host is the swift api server
    auth_host     => $controller_node_public,
    auth_port     => '35357',
  }
  class { 'swift::proxy::keystone':
    operator_roles => ['admin', 'SwiftOperator'],
  }
  class { 'swift::proxy::authtoken':
    admin_user        => 'swift',
    admin_tenant_name => 'services',
    admin_password    => $swift_user_password,
    # assume that the controller host is the swift api server
    auth_host         => $controller_node_public,
  }

  # collect all of the resources that are needed
  # to balance the ring
  Ring_object_device <<| |>>
  Ring_container_device <<| |>>
  Ring_account_device <<| |>>

  # create the ring
  class { 'swift::ringbuilder':
    # the part power should be determined by assuming 100 partitions per drive
    part_power     => '18',
    replicas       => '3',
    min_part_hours => 1,
    require        => Class['swift'],
  }

  # sets up an rsync db that can be used to sync the ring DB
  class { 'swift::ringserver':
    local_net_ip => $swift_local_net_ip,
  }

  # exports rsync gets that can be used to sync the ring files
  @@swift::ringsync { ['account', 'object', 'container']:
   ring_server => $swift_local_net_ip
 }
}

node /<swift_proxy2>/ inherits swift_base {

 # Configure /etc/network/interfaces file
 class { 'networking::interfaces':
   node_type           => swift-proxy,
   mgt_is_public       => true,
   vlan_networking     => true,
   vlan_interface      => "eth0",
   mgt_interface       => "eth0",
   mgt_ip              => "192.168.220.53",
   mgt_gateway         => "192.168.220.1",
   storage_vlan        => "221",
   storage_ip	       => "192.168.221.53",
   dns_servers         => "192.168.220.254",
   dns_search          => "dmz-pod2.lab",
 }

  # curl is only required so that I can run tests
  package { 'curl': ensure => present }

  class { 'memcached':
    listen_ip => $swift_local_net_ip,
  }

  # specify swift proxy and all of its middlewares
  class { 'swift::proxy':
    proxy_local_net_ip => $swift_local_net_ip,
    pipeline           => [
      'catch_errors',
      'healthcheck',
      'cache',
      'ratelimit',
      'swift3',
      's3token',
      'authtoken',
      'keystone',
      'proxy-server'
    ],
    account_autocreate => true,
    # TODO where is the  ringbuilder class?
    require            => Class['swift::ringbuilder'],
  }

  # configure all of the middlewares
  class { [
    'swift::proxy::catch_errors',
    'swift::proxy::healthcheck',
    #'swift::proxy::cache',
    'swift::proxy::swift3',
  ]: }
  
  class { 'swift::proxy::cache':
    memcache_servers  	   => $swift_memcache_servers,   
  }

  class { 'swift::proxy::ratelimit':
    clock_accuracy         => 1000,
    max_sleep_time_seconds => 60,
    log_sleep_time_seconds => 0,
    rate_buffer_seconds    => 5,
    account_ratelimit      => 0
  }
  class { 'swift::proxy::s3token':
    # assume that the controller host is the swift api server
    auth_host     => $controller_node_public,
    auth_port     => '35357',
  }
  class { 'swift::proxy::keystone':
    operator_roles => ['admin', 'SwiftOperator'],
  }
  class { 'swift::proxy::authtoken':
    admin_user        => 'swift',
    admin_tenant_name => 'services',
    admin_password    => $swift_user_password,
    # assume that the controller host is the swift api server
    auth_host         => $controller_node_public,
  }

  # collect all of the resources that are needed
  # to balance the ring
  Ring_object_device <<| |>>
  Ring_container_device <<| |>>
  Ring_account_device <<| |>>

  # create the ring
  class { 'swift::ringbuilder':
    # the part power should be determined by assuming 100 partitions per drive
    part_power     => '18',
    replicas       => '3',
    min_part_hours => 1,
    require        => Class['swift'],
  }

  # sets up an rsync db that can be used to sync the ring DB
  class { 'swift::ringserver':
    local_net_ip => $swift_local_net_ip,
  }

  # exports rsync gets that can be used to sync the ring files
  @@swift::ringsync { ['account', 'object', 'container']:
   ring_server => $swift_local_net_ip
 }
}

