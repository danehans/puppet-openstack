#
# == Class: openstack::quantum
#
# Class to define quantum components for opensack. This class can
# be configured to provide all quantum related functionality.
#
# === Parameters
#
# [db_password]
#   (required) Password used to connect to quantum database.
#
# [bridge_uplinks]
#   (optional) OVS external bridge name and physcial bridge interface tuple.
#
# [bridge_mappings]
#   (optional) Physcial network name and OVS external bridge name tuple. Only needed for flat and VLAN networking.
#
# [external_bridge_name]
#    (optional) Name of external bridge that bridges to public interface.
#    Defaults to br-ex.
#
# === Examples
#
# class { 'openstack::quantum':
#   db_password           => 'quantum_db_pass',
#   user_password         => 'keystone_user_pass',
#   rabbit_password       => 'quantum_rabbit_pass',
#   bridge_uplinks        => '[br-ex:eth0]',
#   bridge_mappings       => '[default:br-ex],
#   enable_ovs_agent      => true,
#   ovs_local_ip          => '10.10.10.10',
# }
#

class openstack::quantum (
  # Passwords
  $db_password,
  $user_password,
  $rabbit_password,
  # enable or disable quantum
  $enabled                = true,
  $enable_server          = true,
  # Set DHCP/L3 Agents on Primary Controller
  $enable_dhcp_agent      = false,
  $enable_l3_agent        = false,
  $enable_metadata_agent  = false,
  $enable_ovs_agent       = undef,
  # OVS settings
  $ovs_local_ip           = undef,
  $ovs_enable_tunneling   = true,
  $firewall_driver        = undef,
  # networking and Interface Information
  $bridge_uplinks         = [],
  $bridge_mappings        = [],
  # Quantum Authentication Information
  $auth_url               = 'http://localhost:35357/v2.0',
  # Metadata Configuration
  $shared_secret          = false,
  $metadata_ip            = '127.0.0.1', 
  # Rabbit Information
  $rabbit_user            = 'quantum',
  $rabbit_host            = '127.0.0.1',
  $rabbit_virtual_host    = '/',
  # Database. Currently mysql is the only option.
  $db_type                = 'mysql',
  $db_host                = '127.0.0.1',
  $db_name                = 'quantum',
  $db_user                = 'quantum',
  # General
  $bind_address           = '0.0.0.0',
  $keystone_host          = '127.0.0.1',
  $verbose                = 'False',
  $debug                  = 'False',
  $enabled                = true
) {

  ####### DATABASE SETUP ######
  # set up mysql server
  if ($db_type == 'mysql') {
      $sql_connection = "mysql://${db_user}:${db_password}@${db_host}/${db_name}?charset=utf8"
  }

  class { '::quantum':
    enabled             => $enabled,
    bind_host           => $bind_address,
    rabbit_host         => $rabbit_host,
    rabbit_virtual_host => $rabbit_virtual_host,
    rabbit_user         => $rabbit_user,
    rabbit_password     => $rabbit_password,
    verbose             => $verbose,
    debug               => $debug,
  }

  if $enable_server {
    class { 'quantum::server':
      auth_host	    => $keystone_host,
      auth_password => $user_password,
    }
    class { 'quantum::plugins::ovs':
      sql_connection      => $sql_connection,
      tenant_network_type => 'gre',
    }
  }

  if $enable_ovs_agent {
    if ! $bridge_uplinks {
      fail('bridge_uplinks paramater must be set when using ovs agent')
    }
    if ! $bridge_mappings {
      fail('bridge_mappings paramater must be set when using ovs agent')
    }
    class { 'quantum::agents::ovs':
      bridge_uplinks   => $bridge_uplinks,
      bridge_mappings  => $bridge_mappings,
      enable_tunneling => $ovs_enable_tunneling,
      local_ip         => $ovs_local_ip,
      firewall_driver  => $firewall_driver
    }
  }

  if $enable_dhcp_agent {
    class { 'quantum::agents::dhcp':
      use_namespaces => True
    }
  }
  if $enable_l3_agent {
    class {"quantum::agents::l3":
      use_namespaces => True
    }
  }
  if $enable_metadata_agent {
    class { 'quantum::agents::metadata':
      auth_password => $user_password, 
      shared_secret => $shared_secret,
      auth_url      => $auth_url, 
      metadata_ip   => $metadata_ip            
    }
  }
}
