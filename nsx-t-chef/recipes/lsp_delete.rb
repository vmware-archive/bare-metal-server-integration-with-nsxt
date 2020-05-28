#
# Cookbook:: nsx-t-chef
# Recipe:: uninstall
#
# Copyright:: 2020, The Authors, All Rights Reserved.


# lsp delete
execute 'lsp-delete' do
  command "python /opt/vmware/nsx-opsagent/scripts/nsx-bms.py #{node['manager']['ip']} #{node['manager']['username']} #{node['manager']['password']} #{node['manager']['thumbprint']} lsp -d"
end