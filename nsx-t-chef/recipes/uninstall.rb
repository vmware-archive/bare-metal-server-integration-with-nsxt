################################################################################
### Copyright (C) 2020 VMware, Inc.  All rights reserved.
### SPDX-License-Identifier: BSD-2-Clause
################################################################################
#
# Cookbook:: nsx-t-chef
# Recipe:: install
#
# Copyright:: 2020, The Authors, All Rights Reserved.

cookbook_file '/tmp/uninstall.sh' do
  source 'uninstall.sh'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

execute 'uninstall' do
  command "/tmp/uninstall.sh >> /var/log/nsxt-chef.log 2>&1"
end
