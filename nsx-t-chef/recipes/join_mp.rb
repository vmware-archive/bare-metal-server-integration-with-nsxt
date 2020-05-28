#
# Cookbook:: nsx-t-chef
# Recipe:: join-mp
#
# Copyright:: 2020, The Authors, All Rights Reserved.

if node['manager']['ip'] == nil or
    node['manager']['username'] == nil or
    node['manager']['password'] == nil or
    node['manager']['thumbprint'] == nil
    raise "Pls. config manager ip/username/password/thumbprint!"
end

cookbook_file '/opt/vmware/nsx-opsagent/scripts/join-mp.sh' do
    source 'join-mp.sh'
    owner 'root'
    group 'root'
    mode '0755'
    action :create
end

execute 'join-mp' do
    command "/opt/vmware/nsx-opsagent/scripts/join-mp.sh #{node['manager']['ip']} #{node['manager']['username']} #{node['manager']['password']} #{node['manager']['thumbprint']} >> /var/log/nsxt-chef.log 2>&1"
end