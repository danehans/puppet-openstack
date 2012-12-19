#
# This class is intended to serve as
# a way of deploying compute nodes.
#
# This currently makes the following assumptions:
#   - libvirt is used to manage the hypervisors
#   - flatdhcp networking is used
#   - glance is used as the backend for the image service
#
# TODO - I need to make the choise of networking configurable
#
#
# [private_interface] Interface used for vm networking connectivity. Required.
# [internal_address] Internal address used for management. Required.
# [public_interface] Public interface used to route public traffic. Optional.
#   Defaults to false.
# [fixed_range] Range of ipv4 network for vms.
# [network_manager] Nova network manager to use.
# [multi_host] Rather node should support multi-host networking mode for HA.
#   Optional. Defaults to false.
# [network_config] Hash that can be used to pass implementation specifc
#   network settings. Optioal. Defaults to {}
# [sql_connection] SQL connection information. Optional. Defaults to false
#   which indicates that exported resources will be used to determine connection
#   information.
# [nova_user_password] Nova service password.
#  [rabbit_host] RabbitMQ host. False indicates it should be collected.
#    Optional. Defaults to false,
#  [rabbit_password] RabbitMQ password. Optional. Defaults to  'rabbit_pw',
#  [rabbit_user] RabbitMQ user. Optional. Defaults to 'nova',
#  [glance_api_servers] List of glance api servers of the form HOST:PORT
#    delimited by ':'. False indicates that the resource should be collected.
#    Optional. Defaults to false,
#  [libvirt_type] Underlying libvirt supported hypervisor.
#    Optional. Defaults to 'kvm',
#  [vncproxy_host] Host that serves as vnc proxy. Optional.
#    Defaults to false. False indicates that a vnc proxy should not be configured.
#  [vnc_enabled] Rather vnc console should be enabled.
#    Optional. Defaults to 'true',
#  [verbose] Rather components should log verbosely.
#    Optional. Defaults to false.
#  [manage_volumes] Rather nova-volume should be enabled on this compute node.
#    Optional. Defaults to false.
#  [nova_volumes] Name of volume group in which nova-volume will create logical volumes.
#    Optional. Defaults to nova-volumes.
#
class openstack::compute(
  $private_interface,
  $internal_address,
  $public_interface    		   = undef,
  $fixed_range         		   = '10.0.0.0/16',
  $network_manager     		   = 'nova.network.quantum.manager.QuantumManager',
  $multi_host          		   = false,
  $network_config      		   = {},
  $sql_connection      		   = false,
  $auth_host           		   = '127.0.0.1',
  $nova_user_password  		   = 'nova_pass',
  $rabbit_host         		   = false,
  $rabbit_password     		   = 'rabbit_pw',
  $rabbit_user         		   = 'nova',
  $glance_api_servers  		   = false,
  $libvirt_type        		   = 'kvm',
  $libvirt_vif_driver              = 'nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver',
  $libvirt_use_virtio_for_bridges  = 'True',
  $vncproxy_host       		   = false,
  $vnc_enabled         		   = 'true',
  $verbose             		   = false,
  $manage_volumes      		   = false,
  $nova_volume         		   = 'nova-volumes',
  $prevent_db_sync                 = true,
  $ovs_bridge_uplinks              = ['br-ex:eth1'],
  $enable_ovs_tunneling            = true,
  $local_ovs_tunnel_ip             = $internal_address,
  $ovs_sql_connection              = "mysql://quantum:${quantum_db_password}@${internal_address}/quantum", 
  $network_api_class               = 'nova.network.quantumv2.api.API',
  $quantum_url                     = "http://${internal_address}:9696",
  $quantum_rabbit_host             = '127.0.0.1',
  $quantum_rabbit_user             = 'openstack_rabbit_user',
  $quantum_rabbit_password         = 'openstack_rabbit_password',
  $quantum_rabbit_virtual_host     = '/',
  $quantum_uplink_enable           = false,
  $quantum_admin_auth_url          = "http://${internal_address}:35357/v2.0",
  $quantum_ip_overlap              = false, 
) {

  class { 'nova':
    sql_connection     => $sql_connection,
    rabbit_host        => $rabbit_host,
    rabbit_userid      => $rabbit_user,
    rabbit_password    => $rabbit_password,
    image_service      => 'nova.image.glance.GlanceImageService',
    glance_api_servers => $glance_api_servers,
    prevent_db_sync    => $prevent_db_sync,
    verbose            => $verbose,
  }

  class { 'nova::compute':
    enabled                        => true,
    vnc_enabled                    => $vnc_enabled,
    vncserver_proxyclient_address  => $internal_address,
    vncproxy_host                  => $vncproxy_host,
  }

  class { 'nova::compute::libvirt':
    libvirt_type     => $libvirt_type,
    vncserver_listen => $internal_address,
  }

  # if the compute node should be configured as a multi-host
  # compute installation
  if $multi_host {

    include keystone::python

    nova_config {
      'multi_host':        value => 'True';
      'send_arp_for_ha':   value => 'True';
    }
    if ! $public_interface {
      fail('public_interface must be defined for multi host compute nodes')
    }
      $enable_network_service = true
      class { 'nova::api':
        enabled           => true,
        admin_tenant_name => 'services',
        admin_user        => 'nova',
        admin_password    => $nova_user_password,
        auth_host         => $virtual_address,
        api_bind_address  => $api_bind_address,
      }
    } elsif
      $network_manager == 'nova.network.quantum.manager.QuantumManager' {
        $enable_network_service = false
  } else {
    $enable_network_service = false
      nova_config {
        'multi_host':        value => 'False';
        'send_arp_for_ha':   value => 'False';
      }
    } 

  # set up configuration for networking
  class { 'nova::network':
    private_interface 	           => $private_interface,
    public_interface               => $public_interface,
    fixed_range                    => $fixed_range,
    floating_range                 => false,
    network_manager                => $network_manager,
    config_overrides               => $network_config,
    create_networks                => false,
    enabled                        => $enable_network_service,
    install_service                => $enable_network_service,
    network_api_class	           => $network_api_class,
    quantum_url                    => $quantum_url,
    quantum_auth_strategy          => $quantum_auth_strategy,
    quantum_admin_tenant_name      => $quantum_admin_tenant_name,
    quantum_admin_username         => $quantum_admin_username,
    quantum_admin_password         => $quantum_admin_password,
    quantum_admin_auth_url         => $quantum_admin_auth_url,
    quantum_ip_overlap             => $quantum_ip_overlap,
    libvirt_vif_driver             => $libvirt_vif_driver,
    libvirt_use_virtio_for_bridges => $libvirt_use_virtio_for_bridges,
  }

  # Base Quantum Class to manage quantum.conf for Compute Nodes
  class { 'quantum':
    enabled                => false,
    rabbit_host            => $quantum_rabbit_host,
    rabbit_port            => '5672',
    rabbit_user            => $quantum_rabbit_user,
    rabbit_password        => $quantum_rabbit_password,
    rabbit_virtual_host    => $quantum_rabbit_virtual_host,
    allow_overlapping_ips  => 'False',
  }

  # setup Quantum OVS Plugin
  class { 'quantum::plugins::ovs':
    sql_connection      => $ovs_sql_connection,
    tenant_network_type => 'gre',
    enable_tunneling    => true,
    use_bridge_uplink   => $quantum_uplink_enable,
  }

  # set up Quantum Client
  class { 'quantum::client':}

  # set up Quantum OVS Agent
  class { 'quantum::agents::ovs':
    bridge_uplinks    => $ovs_bridge_uplinks,
    use_bridge_uplink => $quantum_uplink_enable,
    enable_tunneling  => $enable_ovs_tunneling,
    local_ip          => $local_ovs_tunnel_ip,
  }

  if $manage_volumes {

    class { 'nova::volume':
      enabled => true, 
    }

    class { 'nova::volume::iscsi':
      volume_group     => $nova_volume,
      iscsi_ip_address => $internal_address,
    } 
  }

}
