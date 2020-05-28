# NSX Manager's ip address
default['manager']['ip'] = ''
# NSX Manager's username
default['manager']['username'] = ''
# NSX Manager's password
default['manager']['password'] = ''
# NSX Manager's thumbprint, login Manager, use >nsxcli -c "get certificate api thumbprint"
default['manager']['thumbprint'] = ''


# nsx lcp bundle download link, used by "wget"
case node['platform']
    when "centos", "redhat", "oracle"
        case node['platform_version']
            when /^7\.6.*/
                default['nsx']['install']['lcp_bundle_link'] = ''
            when /^7\.7.*/
                default['nsx']['install']['lcp_bundle_link'] = ''
        end
    when "ubuntu", "debian"
        case node['platform_version']
            when "16.04"
                default['nsx']['install']['lcp_bundle_link'] = ''
            when "18.04"
                default['nsx']['install']['lcp_bundle_link'] = ''
        end
    when "suse"
        case node['platform_version']
            when "12.3"
                default['nsx']['install']['lcp_bundle_link'] = ''
            when "12.4"
                default['nsx']['install']['lcp_bundle_link'] = ''
        end
end

# Transport Zone ID
default['nsx']['tn']['transport_zone_id'] = ''

# Uplink Profile ID
default['nsx']['tn']['uplink_profile_id'] = ''

# Teaming Policy Switch Mapping
default['nsx']['tn']['pnics'] = [{
    'uplink_name' => 'uplink-1',
    'device_name' => 'eth1'
}]

# IP Assignment, Only for Overlay Transport Node, support ippool, dhcp and iplist
# default['nsx']['tn']["ip_assignment_spec"] = {
#     'resource_type' => 'StaticIpPoolSpec',
#     'ip_pool_id' => ''
# }

# Logical Switch Name or ID that BMS node wants to connect
default['nsx']['tn']['ls_name'] = ''

# Application VIF IP mode: static or dhcp or migration
default['nsx']['vif']['mode'] = 'static'

# Application VIF IP static ip address
default['nsx']['vif']['static_ip'] = "192.168.1.11/24"


# Interface name on BMS which needs to be migrated, only for migration mode
#default['nsx']['vif']['migrate_intf'] = "eth0"


# option: route setting for application interface
#default['nsx']['vif']['route'] = "-net 192.1.2.0/24 gw 192.168.1.1, -net 192.1.3.0/24 gw 192.168.1.1"
