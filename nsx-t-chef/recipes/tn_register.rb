#
# Cookbook:: nsx-t-chef
# Recipe:: tn-register
#
# Copyright:: 2020, The Authors, All Rights Reserved.


file "/opt/vmware/nsx-opsagent/scripts/nsx-config.json" do
  content Chef::JSONCompat.to_json_pretty(node['nsx'])
end


cookbook_file '/opt/vmware/nsx-opsagent/scripts/nsx-bms.py' do
  source 'nsx-bms.py'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

# vlan tz check if migration mode
if node['nsx']['vif']['mode'] == "migration"
    execute 'tz-check' do
        command "python /opt/vmware/nsx-opsagent/scripts/nsx-bms.py #{node['manager']['ip']} #{node['manager']['username']} #{node['manager']['password']} #{node['manager']['thumbprint']} tz -vlantzcheck >> /var/log/nsxt-chef.log 2>&1"
    end
end

execute 'tn-register' do
  command "python /opt/vmware/nsx-opsagent/scripts/nsx-bms.py #{node['manager']['ip']} #{node['manager']['username']} #{node['manager']['password']} #{node['manager']['thumbprint']} tn -a >> /var/log/nsxt-chef.log 2>&1"
end