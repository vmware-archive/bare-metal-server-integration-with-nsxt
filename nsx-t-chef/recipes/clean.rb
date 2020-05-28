################################################################################
### Copyright (C) 2020 VMware, Inc.  All rights reserved.
### SPDX-License-Identifier: BSD-2-Clause
################################################################################
#
# Cookbook:: nsx-t-chef
# Recipe:: clean
#
# Copyright:: 2020, The Authors, All Rights Reserved.


# app vif detach
include_recipe 'nsx-t-chef::vif_detach'

# lsp delete
include_recipe 'nsx-t-chef::lsp_delete'

# tn delete
include_recipe 'nsx-t-chef::tn_delete'

# nsx lcp bundle delete
include_recipe 'nsx-t-chef::uninstall'