################################################################################
### Copyright (C) 2020 VMware, Inc.  All rights reserved.
### SPDX-License-Identifier: BSD-2-Clause
################################################################################
#
# Cookbook:: nsx-t-chef
# Recipe:: download
#
# Copyright:: 2020, The Authors, All Rights Reserved.


directory '/opt/vmware/nsx-opsagent/scripts' do
  owner 'root'
  group 'root'
  mode '0755'
  recursive true
  action :create
end

file "/opt/vmware/nsx-opsagent/scripts/nsx-config.json" do
  content Chef::JSONCompat.to_json_pretty(node['nsx'])
end

cookbook_file '/opt/vmware/nsx-opsagent/scripts/download.sh' do
    source 'download.sh'
    owner 'root'
    group 'root'
    mode '0755'
    action :create
end

execute 'download' do
    command "/opt/vmware/nsx-opsagent/scripts/download.sh #{node['nsx']['install']['lcp_bundle_link']} >> /var/log/nsxt-chef.log 2>&1"
end