#
# Cookbook:: nsx-t-chef
# Recipe:: validate
#
# Copyright:: 2020, The Authors, All Rights Reserved.

if node['manager']['ip'] == nil or
    node['manager']['username'] == nil or
    node['manager']['password'] == nil or
    node['manager']['thumbprint'] == nil
    raise "Pls. config manager ip/username/password/thumbprint!"
end

if node['nsx']['tn']['ls_id'] == nil and node['nsx']['tn']['ls_name'] == nil
    raise "Pls. config ls id or ls name!"
end

if not ["static", "dhcp", "migration"].include?(node['nsx']['vif']['mode'])
    raise "node['nsx']['vif']['mode'] must be static or dhcp or migration"
end

if node['nsx']['vif']['mode'] == "static"
    if node['nsx']['vif']['static_ip'] == nil
        raise "Pls. config static ip!"
    end
end

if node['nsx']['tn']['transport_zone_id'] == nil
    raise "Pls. config transport zone id!"
end

if node['nsx']['tn']['uplink_profile_id'] == nil
    raise "Pls. config uplink profile id!"
end


if node['nsx']['tn']['pnics'] == nil
    raise "Pls. config pnics mapping"
end

if node['nsx']['vif']['mode'] == "migration"
    if node['nsx']['vif']['migrate_intf'] == nil
        raise "Pls. select a interface which needs to be migrated!"
    end

    if node['nsx']['vif']['migrate_intf'] != node['nsx']['tn']['pnics'][0]['device_name']
        raise "migrate interface should be same as uplink device name!"
    end
end

