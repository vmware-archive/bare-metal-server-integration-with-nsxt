#
# Cookbook:: nsx-t-chef
# Recipe:: install
#
# Copyright:: 2020, The Authors, All Rights Reserved.


case node['platform']
    when "centos", "redhat", "oracle", "suse"
        cmd = "rpm -qa |grep nsx-host-baremetal-server"
    when "ubuntu", "debian"
        cmd = "dpkg -l |grep nsx-host-baremetal-server"
end

package = `#{cmd}`
unless package.empty?
    raise "Possibly NSX packages already installed, please check or cleanup first!"
end


cookbook_file '/opt/vmware/nsx-opsagent/scripts/install.sh' do
  source 'install.sh'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

execute 'install' do
  command "/opt/vmware/nsx-opsagent/scripts/install.sh >> /var/log/nsxt-chef.log 2>&1"
end
