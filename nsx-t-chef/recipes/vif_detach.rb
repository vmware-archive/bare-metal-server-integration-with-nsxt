################################################################################
### Copyright (C) 2020 VMware, Inc.  All rights reserved.
### SPDX-License-Identifier: BSD-2-Clause
################################################################################
#
# Cookbook:: nsx-t-chef
# Recipe:: vif_detach
#
# Copyright:: 2020, The Authors, All Rights Reserved.

# app vif detach
execute 'app_vif_install' do
    command "/opt/vmware/nsx-opsagent/scripts/app_vif_install.sh -c restore"
end
