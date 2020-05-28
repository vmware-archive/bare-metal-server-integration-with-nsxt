#
# Cookbook:: nsx-t-chef
# Recipe:: default
#
# Copyright:: 2020, The Authors, All Rights Reserved.

include_recipe 'nsx-t-chef::validate'

include_recipe 'nsx-t-chef::download'

include_recipe 'nsx-t-chef::install'

include_recipe 'nsx-t-chef::join_mp'

include_recipe 'nsx-t-chef::tn_register'

include_recipe 'nsx-t-chef::lsp_create'

include_recipe 'nsx-t-chef::vif_attach'