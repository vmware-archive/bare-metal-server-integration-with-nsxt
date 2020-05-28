################################################################################
### Copyright (C) 2020 VMware, Inc.  All rights reserved.
### SPDX-License-Identifier: BSD-2-Clause
################################################################################
#
# Cookbook:: nsx-t-chef
# Recipe:: vif-attach
#
# Copyright:: 2020, The Authors, All Rights Reserved.



directory '/opt/vmware/nsx-opsagent/scripts' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

file "/opt/vmware/nsx-opsagent/scripts/nsx-config.json" do
    content Chef::JSONCompat.to_json_pretty(node['nsx'])
end

remote_directory '/opt/vmware/nsx-opsagent/scripts/' do
    source 'bms-config'
    owner 'root'
    group 'root'
    mode '0755'
    files_owner 'root'
    files_group 'root'
    files_mode '0755'
    action :create
end

execute 'app_vif_install' do
    param = ""
    if node['nsx']['vif']['intf_name'] != nil
        param += "-a '#{node['nsx']['vif']['intf_name']}'"
    end
    case node['nsx']['vif']['mode']
        when "static"
            if node['nsx']['vif']['mac'] != nil
                param += " -m '#{node['nsx']['vif']['mac']}'"
            end
            if node['nsx']['vif']['route'] != nil
                param += " -r '#{node['nsx']['vif']['route']}'"
            end
            command "/opt/vmware/nsx-opsagent/scripts/app_vif_install.sh -c static -s '#{node['nsx']['vif']['static_ip']}' #{param} -v `cat /opt/vmware/nsx-opsagent/scripts/vifid`"
        when "dhcp"
            if node['nsx']['vif']['mac'] != nil
                param += " -m '#{node['nsx']['vif']['mac']}'"
            end
            if node['nsx']['vif']['route'] != nil
                param += " -r '#{node['nsx']['vif']['route']}'"
            end
            command "/opt/vmware/nsx-opsagent/scripts/app_vif_install.sh -c dhcp #{param} -v `cat /opt/vmware/nsx-opsagent/scripts/vifid`"
        when "migration"
            if node['nsx']['vif']['migrate_intf'] != nil
                param += " -i '#{node['nsx']['vif']['migrate_intf']}'"
            end
            command "/opt/vmware/nsx-opsagent/scripts/app_vif_install.sh -c migration #{param} -v `cat /opt/vmware/nsx-opsagent/scripts/vifid`"
    end
end