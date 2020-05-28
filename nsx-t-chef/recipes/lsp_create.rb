#
# Cookbook:: nsx-t-chef
# Recipe:: lsp-create
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

# vlan0 ls check if migration mode
if node['nsx']['vif']['mode'] == "migration"
    execute 'lsp-create' do
        command "python /opt/vmware/nsx-opsagent/scripts/nsx-bms.py #{node['manager']['ip']} #{node['manager']['username']} #{node['manager']['password']} #{node['manager']['thumbprint']} ls -vlan0check >> /var/log/nsxt-chef.log 2>&1"
    end
end

execute 'lsp-create' do
  command "python /opt/vmware/nsx-opsagent/scripts/nsx-bms.py #{node['manager']['ip']} #{node['manager']['username']} #{node['manager']['password']} #{node['manager']['thumbprint']} lsp -a >> /var/log/nsxt-chef.log 2>&1"
end