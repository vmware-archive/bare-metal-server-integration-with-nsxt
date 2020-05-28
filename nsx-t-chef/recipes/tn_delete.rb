################################################################################
### Copyright (C) 2020 VMware, Inc.  All rights reserved.
### SPDX-License-Identifier: BSD-2-Clause
################################################################################
#
# Cookbook:: nsx-t-chef
# Recipe:: tn_delete
#
# Copyright:: 2020, The Authors, All Rights Reserved.

execute 'tn-register' do
  command "python /opt/vmware/nsx-opsagent/scripts/nsx-bms.py #{node['manager']['ip']} #{node['manager']['username']} #{node['manager']['password']} #{node['manager']['thumbprint']} tn -d >> /var/log/nsxt-chef.log 2>&1"
end