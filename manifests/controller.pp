#
# This can be used to build out the simplest openstack controller
#
#
# $export_resources - Whether resources should be exported
#
# [public_interface] Public interface used to route public traffic. Required.
# [public_address] Public address for public endpoints. Required.
# [private_interface] Interface used for vm networking connectivity. Required.
# [internal_address] Internal address used for management. Required.
# [mysql_root_password] Root password for mysql server.
# [admin_email] Admin email.
# [admin_password] Admin password.
# [keystone_db_password] Keystone database password.
# [keystone_admin_token] Admin token for keystone.
# [glance_db_password] Glance DB password.
# [glance_user_password] Glance service user password.
# [nova_db_password] Nova DB password.
# [nova_user_password] Nova service password.
# [rabbit_password] Rabbit password.
# [rabbit_user] Rabbit User.
# [network_manager] Nova network manager to use.
# [fixed_range] Range of ipv4 network for vms.
# [floating_range] Floating ip range to create.
# [create_networks] Rather network and floating ips should be created.
# [num_networks] Number of networks that fixed range should be split into.
# [multi_host] Rather node should support multi-host networking mode for HA.
#   Optional. Defaults to false.
# [auto_assign_floating_ip] Rather configured to automatically allocate and
#   assign a floating IP address to virtual instances when they are launched.
#   Defaults to false.
# [network_config] Hash that can be used to pass implementation specifc
#   network settings. Optioal. Defaults to {}
# [verbose] Rahter to log services at verbose.
# [export_resources] Rather to export resources.
# Horizon related config - assumes puppetlabs-horizon code
# [secret_key]          secret key to encode cookies, …
# [cache_server_ip]     local memcached instance ip
# [cache_server_port]   local memcached instance port
# [swift]               (bool) is swift installed
# [glance_on_swift]     (bool) is glance to run on swift or on file
# [quantum]             (bool) is quantum installed
#   The next is an array of arrays, that can be used to add call-out links to the dashboard for other apps.
#   There is no specific requirement for these apps to be for monitoring, that's just the defacto purpose.
#   Each app is defined in two parts, the display name, and the URI
# [horizon_app_links]     array as in '[ ["Nagios","http://nagios_addr:port/path"],["Ganglia","http://ganglia_addr"] ]'
# [horizon_top_links]     just like horizon_app_links, but shown in the header
#
# [enabled] Whether services should be enabled. This parameter can be used to
#   implement services in active-passive modes for HA. Optional. Defaults to true.
class openstack::controller(
  # my address
  $public_address,
  $public_interface,
  $private_interface,
  $internal_address,
  $admin_address           = $internal_address,
  # connection information
  $mysql_root_password     = undef,
  $admin_email             = 'some_user@some_fake_email_address.foo',
  $admin_password          = 'ChangeMe',
  $keystone_db_password    = 'keystone_pass',
  $keystone_admin_token    = 'keystone_admin_token',
  $keystone_admin_tenant   = 'openstack',
  $glance_db_password      = 'glance_pass',
  $glance_user_password    = 'glance_pass',
  $glance_sql_connection   = 'sqlite:////var/lib/glance/glance.sqlite',
  $nova_db_password        = 'nova_pass',
  $nova_user_password      = 'nova_pass',
  $rabbit_password         = 'rabbit_pw',
  $rabbit_user             = 'nova',
  # network configuration
  # this assumes that it is a flat network manager
  $nova_net_install	   = false,
  $network_manager         = 'nova.network.quantum.manager.QuantumManager',
  # this number has been reduced for performance during testing
  $fixed_range             = '10.0.0.0/16',
  $floating_range          = false,
  $create_networks         = false,
  $num_networks            = 1,
  $multi_host              = false,
  $auto_assign_floating_ip = false,
  # TODO need to reconsider this design...
  # this is where the config options that are specific to the network
  # types go. I am not extremely happy with this....
  $network_config          = {},
  # I do not think that this needs a bridge?
  $verbose                 = false,
  $export_resources        = true,
  $secret_key              = 'dummy_secret_key',
  $cache_server_ip         = '127.0.0.1',
  $cache_server_port       = '11211',
  $swift                   = false,
  $glance_on_swift         = false,
  $quantum                 = false,
  $horizon_app_links       = false,
  $horizon_top_links       = false,
  $enabled                 = true,
  ##### new quantum config ######
  $quantum_user_password       = 'quantum_pass',
  $quantum_db_password         = 'quantum_pass',  
  $quantum_rabbit_host         = '127.0.0.1',
  $quantum_rabbit_user         = 'openstack_rabbit_user',
  $quantum_rabbit_password     = 'openstack_rabbit_password',
  $quantum_rabbit_virtual_host = '/',
  $enable_ovs_tunneling        = true,
  $local_ovs_tunnel_ip         = $internal_address,
  $ovs_sql_connection          = "mysql://quantum:${quantum_db_password}@${internal_address}/quantum",
  $ovs_bridge_mappings	       = ['default:br-ex'],
  $ovs_bridge_uplinks          = ['br-ex:eth1'],
  ### Quantum OLD CONFIG ####
  $network_api_class           = 'nova.network.quantumv2.api.API',
  $quantum_url                 = "http://${internal_address}:9696",
  $quantum_auth_strategy       = 'keystone',
  $quantum_admin_auth_url      = "http://${internal_address}:35357/v2.0",
  $quantum_ip_overlap          = false,
  $libvirt_vif_driver	       = 'nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver',
) {

  $glance_api_servers = "${internal_address}:9292"
  $nova_db = "mysql://nova:${nova_db_password}@${internal_address}/nova"

  if ($export_resources) {
    # export all of the things that will be needed by the clients
    @@nova_config { 'rabbit_host': value => $internal_address }
    Nova_config <| title == 'rabbit_host' |>
    @@nova_config { 'sql_connection': value => $nova_db }
    Nova_config <| title == 'sql_connection' |>
    @@nova_config { 'glance_api_servers': value => $glance_api_servers }
    Nova_config <| title == 'glance_api_servers' |>
    @@nova_config { 'novncproxy_base_url': value => "http://${public_address}:6080/vnc_auto.html" }
    $sql_connection    = false
    $glance_connection = false
    $rabbit_connection = false
  } else {
    $sql_connection    = $nova_db
    $glance_connection = $glance_api_servers
    $rabbit_connection = $internal_address
  }

  ####### DATABASE SETUP ######

  # set up mysql server
  if (!defined(Class[mysql::server])) {
    class { 'mysql::server':
      config_hash => {
        # the priv grant fails on precise if I set a root password
        # TODO I should make sure that this works
        'root_password' => $mysql_root_password,
        'bind_address'  => '0.0.0.0'
      },
      enabled => $enabled,
    }
  }
  if ($enabled) {
    # set up all openstack databases, users, grants
    class { 'keystone::db::mysql':
      password => $keystone_db_password,
    }
    Class['glance::db::mysql'] -> Class['glance::registry']
    class { 'glance::db::mysql':
      host     => $internal_address,
      password => $glance_db_password,
      allowed_hosts => '%',
    }
    # TODO should I allow all hosts to connect?
    class { 'nova::db::mysql':
      password      => $nova_db_password,
      host          => $internal_address,
      allowed_hosts => '%',
    }
    class { 'quantum::db::mysql':
      password      => $quantum_db_password,
      host          => $internal_address,
      allowed_hosts => '%',
    }
  }

  ####### KEYSTONE ###########

  # set up keystone
  class { 'keystone':
    admin_token  => $keystone_admin_token,
    # we are binding keystone on all interfaces
    # the end user may want to be more restrictive
    bind_host    => '0.0.0.0',
    log_verbose  => $verbose,
    log_debug    => $verbose,
    catalog_type => 'sql',
    enabled      => $enabled,
  }
  # set up keystone database
  # set up the keystone config for mysql
  class { 'keystone::config::mysql':
    password => $keystone_db_password,
  }

  if ($enabled) {
    # set up keystone admin users
    class { 'keystone::roles::admin':
      email        => $admin_email,
      password     => $admin_password,
      admin_tenant => $keystone_admin_tenant,
    }
    # set up the keystone service and endpoint
    class { 'keystone::endpoint':
      public_address   => $public_address,
      internal_address => $internal_address,
      admin_address    => $admin_address,
    }
    # set up glance service,user,endpoint
    class { 'glance::keystone::auth':
      password         => $glance_user_password,
      public_address   => $public_address,
      internal_address => $internal_address,
      admin_address    => $admin_address,
      before           => [Class['glance::api'], Class['glance::registry']]
    }
    # set up nova serice,user,endpoint
    class { 'nova::keystone::auth':
      password         => $nova_user_password,
      public_address   => $public_address,
      internal_address => $internal_address,
      admin_address    => $admin_address,
      before           => Class['nova::api'],
    }
    # set up quantum serice,user,endpoint
    class { 'quantum::keystone::auth':
      password         => $quantum_user_password,
      public_address   => $public_address,
      internal_address => $internal_address,    
      admin_address    => $admin_address,
      before           => Class['quantum::server'],
    }

  }

  ######## END KEYSTONE ##########

  ######## BEGIN GLANCE ##########


  class { 'glance::api':
    log_verbose       => $verbose,
    log_debug         => $verbose,
    auth_type         => 'keystone',
    auth_host         => '127.0.0.1',
    auth_port         => '35357',
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
    keystone_password => $glance_user_password,
    sql_connection    => $glance_sql_connection,
    enabled           => $enabled,
  }
  if $glance_on_swift {
    class { 'glance::backend::swift':
      swift_store_user => 'openstack:admin',
      swift_store_key => $admin_password,
      swift_store_auth_address => "http://$internal_address:5000/v2.0/",
      swift_store_container => 'glance',
      swift_store_create_container_on_put => 'true'
    }
  } else {
    class { 'glance::backend::file': }
  }
  class { 'glance::registry':
    log_verbose       => $verbose,
    log_debug         => $verbose,
    auth_type         => 'keystone',
    auth_host         => '127.0.0.1',
    auth_port         => '35357',
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
    keystone_password => $glance_user_password,
    sql_connection    => $glance_sql_connection,
    enabled           => $enabled,
  }

  ######## END GLANCE ###########

  ######## BEGIN NOVA ###########


  class { 'nova::rabbitmq':
    userid   => $rabbit_user,
    password => $rabbit_password,
    enabled  => $enabled,
  }

  # TODO I may need to figure out if I need to set the connection information
  # or if I should collect it
  class { 'nova':
    sql_connection     => $sql_connection,
    # this is false b/c we are exporting
    rabbit_host        => $rabbit_connection,
    rabbit_userid      => $rabbit_user,
    rabbit_password    => $rabbit_password,
    image_service      => 'nova.image.glance.GlanceImageService',
    glance_api_servers => $glance_connection,
    verbose            => $verbose,
  }

  class { 'nova::api':
    enabled           => $enabled,
    # TODO this should be the nova service credentials
    admin_tenant_name => 'services',
    admin_user        => 'nova',
    admin_password    => $nova_user_password,
  }

  class { [
    'nova::cert',
    'nova::consoleauth',
    'nova::scheduler',
    'nova::objectstore',
    'nova::vncproxy'
  ]:
    enabled => $enabled,
  }

  if $multi_host {
    nova_config { 'multi_host':   value => 'True'; }
    $enable_network_service = false
  } elsif  
      $network_manager == 'nova.network.quantum.manager.QuantumManager' {
      $enable_network_service = false
  } else {
    if $enabled == true {
      $enable_network_service = true
    } else {
      $enable_network_service = false
    }
  }

  if $enabled {
    $really_create_networks = $create_networks
  } else {
    $really_create_networks = false
  }

  # set up networking
  class { 'nova::network':
    private_interface 		   => $private_interface,
    public_interface  		   => $public_interface,
    fixed_range       		   => $fixed_range,
    floating_range    		   => $floating_range,
    network_manager   		   => $network_manager,
    config_overrides  		   => $network_config,
    create_networks   		   => $really_create_networks,
    num_networks      		   => $num_networks,
    enabled           		   => $enable_network_service,
    install_service   		   => $nova_net_install,
    network_api_class		   => $network_api_class,
    quantum_url 		   => $quantum_url,
    quantum_auth_strategy 	   => $quantum_auth_strategy,
    quantum_admin_password 	   => $quantum_user_password,
    quantum_admin_auth_url 	   => $quantum_admin_auth_url,
    quantum_ip_overlap     	   => $quantum_ip_overlap,
    libvirt_vif_driver 		   => $libvirt_vif_driver,
    libvirt_use_virtio_for_bridges => $libvirt_use_virtio_for_bridges,
  }

  # set up Quantum infrastructure services
  class { 'quantum':
    rabbit_host            => $quantum_rabbit_host,
    rabbit_port            => '5672',
    rabbit_user            => $quantum_rabbit_user,
    rabbit_password        => $quantum_rabbit_password,
    rabbit_virtual_host    => $quantum_rabbit_virtual_host,
    allow_overlapping_ips  => 'False',
  }

  # set up Quantum Server
  class { 'quantum::server':
    auth_host     => $internal_address,
    auth_password => $quantum_user_password,
  } 

  # setup Quantum Server OVS Plugin
  class { 'quantum::plugins::ovs':
    sql_connection      => $ovs_sql_connection,
    tenant_network_type => 'gre',
    bridge_mappings     => $ovs_bridge_mappings,
    enable_tunneling    => true,
  }

  # set up Quantum Client
  class { 'quantum::client':}

  # set up Quantum DHCP Agent
  class { 'quantum::agents::dhcp':}

  # set up Quantum L3 Agent
  class { 'quantum::agents::l3':
    auth_url        => $quantum_admin_auth_url,
    auth_password   => $quantum_user_password,
    metadata_ip     => $internal_address, 
  }

  # set up Quantum OVS Agent
  class { 'quantum::agents::ovs':
    bridge_uplinks   => $ovs_bridge_uplinks, 
    enable_tunneling => $enable_ovs_tunneling,
    local_ip         => $local_ovs_tunnel_ip,
  }


  #### End Quantum Configuration ####

  if ($network_manager) != 'nova.network.quantum.manager.QuantumManager' and ($auto_assign_floating_ip) {
    nova_config { 'auto_assign_floating_ip':   value => 'True'; }
  }

  ######## Horizon ########

  class { 'memcached':
    listen_ip => '127.0.0.1',
  }

  class { 'horizon':
    secret_key => $secret_key,
    cache_server_ip => $cache_server_ip,
    cache_server_port => $cache_server_port,
    swift => $swift,
    quantum => $quantum,
    horizon_app_links => $horizon_app_links,
    horizon_top_links => $horizon_top_links,
  }

  ######## End Horizon #####

}
