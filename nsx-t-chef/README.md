# nsx-t-chef: Chef Cookbook for Bare Metal Server

Chef Cookbook for Bare Metal Server Integration with NSX-T

## Notes
How to setup Chef env is not scope of this Cookbook. This cookbook only contains configurations and integration steps for Bare Metal Server with NSX-T by Chef Infra.


## Attributes

### Global Attributes
Global Attributes will be applied to all Chef Clients(Nodes)

```Ruby
# NSX Manager's ip address
default['manager']['ip'] = ''
# NSX Manager's username
default['manager']['username'] = ''
# NSX Manager's password
default['manager']['password'] = ''
# NSX Manager's thumbprint, login Manager, then use >nsxcli -c "get certificate api thumbprint"
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
default['nsx']['tn']["ip_assignment_spec"] = {
    'resource_type' => 'StaticIpPoolSpec'
    'ip_pool_id' => '',
}
or
default['nsx']['tn']["ip_assignment_spec"] = {
    'resource_type' => 'AssignedByDhcp'
}
or
default['nsx']['tn']["ip_assignment_spec"] = {
    'resource_type' => 'StaticIpListSpec',
    'ip_list' => ['192.168.1.2', '192.168.1.3'],
    'subnet_mask' => '255.255.255.0',
    'default_gateway' => '192.168.1.1'
}

# Logical Switch Name or Uuid that BMS node wants to connect
default['nsx']['tn']['ls_name'] = ''
or
default['nsx']['tn']['ls_id'] = ''

# Application VIF IP mode: static or dhcp or migration
default['nsx']['vif']['mode'] = 'static'
or
default['nsx']['vif']['mode'] = 'dhcp'
or
default['nsx']['vif']['mode'] = 'migration'

# Application VIF IP static ip address, support multiple IPs
# Nots: this should be Node-Spec Attribute, see Node-Spec Attributes section
default['nsx']['vif']['static_ip'] = "192.168.1.11/24"
or
default['nsx']['vif']['static_ip'] = "192.168.1.11/24 192.168.1.12/24"

# Interface name on BMS which needs to be migrated, only for migration mode
default['nsx']['vif']['migrate_intf'] = "eth0"

# option route entry for Application Interface
# routing table syntax:
# [-net|-host] target [netmask Nm] [gw Gw] [metric N] i [mss M] [window W] [irtt m] [reject] [mod] [dyn] [reinstate]
default['nsx']['vif']['route'] = "-net 192.1.2.0/24 gw 192.168.1.1, -net 192.1.3.0/24 gw 192.168.1.1"
```

### Node-Spec Attributes
Node-Spec Attribute is for configure each Chef Client its own Attribute, for example, each of Bare Metal Servers has different static IP address setting.

Node-Spec Attribute setting will override Global Attribute if attribute has the same key.

```bash
$ knife node edit NODE-NAME
```
This command will open a editable json format file, then update attribute as following(red highlight), and save.


for example: add static ip(192.168.1.3/24)


```json
{
	"name": "chef-node.example.com",
	"chef_environment": "_default",
	"normal": {
		"nsx": {
			"vif": {
				"static_ip": "192.168.1.3/24"
			}
		},
		"tags": [ ]
	},
	"policy_name": null,
	"policy_group": null,
	"run_list": [
		"recipe[nsx-t-chef]"
	]
}
```

## How to Run nsx-t-chef cookbook?

### Installation
Bare Metal Server Installation include several steps, each step shown as a separate recipe:
1. validate  
validate.rb: do validation for input attributes

2. download  
download.rb: download nsx lcp bundle via wget specific link

3. install  
install.rb: install nsx lcp bundle

4. join mp  
join_mp.rb: Register BMS as Fabric Node from Host by NSXCLI, not from MP

5. transport node register  
tn_register.rb: Register BMS as Transport Node by REST API

6. logical switch port create  
lsp_create.rb: Create Logical Switch Port by REST API

7. vif attachment  
vif_attach.rb: Application VIF attachment

#### Installation Run
default.rb combine installation steps together, "chef-client" command will trigger whole install workflow.
```bash
chef-client
```

#### Individual Step Run
```bash
chef-client -o 'recipe[nsx-t-chef::RECIPE-NAME]'
```
for example:
```bash
chef-client -o 'recipe[nsx-t-chef::download]'
```

### Cleanup
Bare Metal Server Cleanup include several steps, each step shown as a separate recipe:
1. vif detachment  
vif_detach.rb: Detach Application VIF

2. logical switch port delete  

lsp_delete.rb: Delete Logical Switch Port

3. transport node delete  
tn_delete.rb: Delete transport node from MP

4. nsx lcp bundle uninstall
uninstall.rb: Uninstall nsx lcp bundle

#### Run
clean.rb combine cleanup steps together, "chef-client -o 'recipe[nsx-t-chef::cleanup]'" command will trigger whole cleanup workflow.
```bash
chef-client -o 'recipe[nsx-t-chef::clean]'
```

#### Individual Step Run
```bash
chef-client -o 'recipe[nsx-t-chef::RECIPE-NAME]'
```
for example:
```bash
chef-client -o 'recipe[nsx-t-chef::lsp_delete]'
```
