require 'spec_helper'
describe 'openstack::db::mysql' do

  let :required_params do
    {
      :mysql_root_password  => 'root_pw',
      :keystone_db_password => 'keystone_pass',
      :glance_db_password   => 'glance_pass',
      :nova_db_password     => 'nova_pass',
      :cinder_db_password   => 'cinder_pass',
      :quantum_db_password  => 'quantum_pass'
    }
  end

  let :params do
    required_params
  end

  let :facts do
    {
      :osfamily => 'Debian'
    }
  end

  describe 'with only required parameters' do
    it 'should setup mysql with databases using required and default params' do
      should contain_class('mysql::server').with_config_hash(
        'root_password' => 'root_pw',
        'bind_address'  => '0.0.0.0'
      )

      ['keystone', 'glance', 'nova', 'cinder', 'quantum'].each do |type|
        should contain_class("#{type}::db::mysql").with(
          :user          => type,
          :password      => "#{type}_pass",
          :host          => '127.0.0.1',
          :dbname        => type,
          :allowed_hosts => false
        )
      end
    end
  end
end
