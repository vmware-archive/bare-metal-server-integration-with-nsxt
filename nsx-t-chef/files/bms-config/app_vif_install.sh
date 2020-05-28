#!/bin/bash
#
# Copyright (C) 2018 VMware, Inc.  All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause
#
# usage:
#       -c [config_mode: static|dhcp|migration|restore] -s [static ips]
#       -a [app interface name] -m [mac address] -r [routing rules] \
#       -i [migration interface] -v [vif id]
#
set -e
nsx_bm_log() {
    echo "${1}"
    logger -p daemon.info -t NSX-BMS "${1}"
}

_config_mode=""
_static_ips=""
_app_intf_name="nsx-eth"
_mac_address=""
_routing_rules=""
_migrate_intf=""
_vif_id=""
_manager_ips=`grep "<ip>.*</ip>" /etc/vmware/nsx/appliance-info.xml | sed -r 's/.*<ip>((([0-9]{1,3}\.){3}([0-9]{1,3})))<\/ip>.*/\1/g'`
underlay_mode=""
os_type=`/usr/bin/lsb_release -si`
int_br_name=""

usage()
{
    echo "usage: $0"
    echo "       -c [config_mode: static|dhcp|migration|restore] -s [static ips] \\"
    echo "       -a [app interface name] -m [mac address] -r [routing rules] \\"
    echo "       -i [migration interface] -v [vif id]"
    exit 0
}

get_integration_bridge_name()
{
    int_br_name=`ovs-vsctl list-br | while read line; do if [ $(ovs-vsctl br-get-external-id $line) ]; then echo $line; fi; done`
    if [ "x$int_br_name" = "x" ]; then
        nsx_bm_log "ERROR: integration bridge not found"
        exit 1
    fi
}

check_vif_id()
{
    if [ "x$_vif_id" = "x" ]; then
        nsx_bm_log "ERROR: vif id is not defined"
        exit 1
    fi
}

bms_config()
{
    if [ "x$underlay_mode" = "x" ]; then
        underlay_mode="false"
    fi
    sed -e "s|{{ underlay_mode }}|$underlay_mode|" /opt/vmware/nsx-opsagent/scripts/nsx-baremetal.xml > /etc/vmware/nsx/nsx-baremetal.xml
    declare -i id=0
    for managerIp in $_manager_ips
    do
        sed -i "/.*<\/endpointList>/i\        <endpoint id=\"$id\">\n            <ip>$managerIp</ip>\n\
            <port>1234</port>\n            <proto>6</proto>\n            <remote>true</remote>\n\
        </endpoint>" /etc/vmware/nsx/nsx-baremetal.xml
        id+=1
    done
    chown nsx-agent:nsx-agent /etc/vmware/nsx/nsx-baremetal.xml
    chmod 0660 /etc/vmware/nsx/nsx-baremetal.xml
    /etc/init.d/nsx-agent restart
}

generate_config_file()
{
    mkdir -p /etc/vmware/nsx-bm
    chmod 0755 /etc/vmware/nsx-bm
    echo "config_mode="$_config_mode > /etc/vmware/nsx-bm/bms.conf
}

create_vif()
{
    # check app interface name
    if [ "x$_app_intf_name" = "x" ]; then
        nsx_bm_log "ERROR: app interface name is not defined"
        exit 1
    fi
    # delete legacy app interface
    ip link del $_app_intf_name &> /dev/null | cat
    # create veth pair
    ip link add $_app_intf_name type veth peer name ${_app_intf_name}-peer
    # bring veth up
    ip link set $_app_intf_name up
    ip link set ${_app_intf_name}-peer up
    if [ "x$_mac_address" = "x" ]; then
        # get app interface MAC address
        _mac_address=`ip link show $_app_intf_name | grep ether | awk '{print $2}'`
    else
        ip link set dev $_app_intf_name address $_mac_address
    fi
}

create_manual_restore_script()
{
    cp -f /opt/vmware/nsx-opsagent/scripts/static_dhcp_manual_restore.sh /opt/vmware/nsx-bm/static_dhcp_manual_restore.sh
    chmod 0755 /opt/vmware/nsx-bm/static_dhcp_manual_restore.sh
    chown root:root /opt/vmware/nsx-bm/static_dhcp_manual_restore.sh
}

creat_bm_directory()
{
    mkdir -p /opt/vmware/nsx-bm
    chmod 0755 /opt/vmware/nsx-bm
}

attach_vif_to_intbr()
{
    ovs-vsctl --timeout=5 -- --if-exists del-port ${_app_intf_name}-peer -- add-port $int_br_name ${_app_intf_name}-peer -- set Interface ${_app_intf_name}-peer external-ids:attached-mac=$_mac_address external-ids:iface-id=$_vif_id external-ids:iface-status=active
}

create_bootup_script()
{
    init_script=""
    if [ "x$_config_mode" = "xstatic" ]; then
        init_script=/opt/vmware/nsx-opsagent/scripts/bms_static_init.sh
    elif [ "x$_config_mode" = "xdhcp" ]; then
        init_script=/opt/vmware/nsx-opsagent/scripts/bms_dhcp_init.sh
    elif [ "x$_config_mode" = "xmigration" ]; then
        init_script=/opt/vmware/nsx-opsagent/scripts/bms_migrate_init.sh
    fi
    sed -e "s|{{ app_intf_name }}|$_app_intf_name|g; s|{{ mac_address }}|$_mac_address|g; s|{{ int_br_name }}|$_int_br_name|g; s|{{ vif_id }}|$_vif_id|g; s|{{ routing_rules }}|$_routing_rules|g; s|{{ static_ips }}|$_static_ips|g" $init_script >  /etc/init.d/nsx-baremetal
    chmod 0755 /etc/init.d/nsx-baremetal
    chown root:root /etc/init.d/nsx-baremetal
}

add_service_bootup()
{
    if [ "x$os_type" = "xUbuntu" ]; then
        update-rc.d nsx-baremetal defaults 9
    elif [ "x$os_type" = "xRedHatEnterpriseServer" ] || [ "x$os_type" = "xCentOS" ] || [ "x$os_type" = "xSUSE" ] || [ "x$os_type" = "xOracleServer" ]; then
        chkconfig --add nsx-baremetal
    fi
}

config_routing_rules()
{
    if [ "x$_routing_rules" != "x" ]; then
        echo ${_routing_rules} | awk '{len=split($0,a,",");for(i=1;i<=len;i++) system("route add "a[i]" dev '$_app_intf_name'")}'
    fi
}

set_fqdn()
{
    fqdn_tag=`grep \<fqdn\> /etc/vmware/nsx/controller-info.xml | cat`
    if [ "x$fqdn_tag" != "x" ]; then
        FQDN="true"
    fi
}

static_config()
{
    underlay_mode="false"
    get_integration_bridge_name
    check_vif_id
    if [ "x$_static_ips" = "x" ]; then
        nsx_bm_log "ERROR: static ip is not defined"
        exit 1
    fi
    bms_config
    generate_config_file
    create_vif
    creat_bm_directory
    create_manual_restore_script
    for static_ip in $_static_ips
    do
        ip addr add $static_ip dev $_app_intf_name
    done
    attach_vif_to_intbr
    config_routing_rules
    generate_config_file
    create_bootup_script
    add_service_bootup
}

dhcp_config()
{
    underlay_mode="false"
    get_integration_bridge_name
    check_vif_id
    bms_config
    generate_config_file
    create_vif
    attach_vif_to_intbr
    config_routing_rules
    creat_bm_directory
    create_manual_restore_script
    if [ "x$os_type" = "SUSE" ]; then
        cp -f /opt/vmware/nsx-opsagent/scripts/suse_dhcp_network_template /etc/sysconfig/network/ifcfg-$_app_intf_name
        chmod 0644 /etc/sysconfig/network/ifcfg-$_app_intf_name
        chown root:root /etc/sysconfig/network/ifcfg-$_app_intf_name
        ifup $_app_intf_name
    else
        dhclient -nw -pf /var/run/dhclient-$_app_intf_name.pid $_app_intf_name
    fi
    generate_config_file
    create_bootup_script
    add_service_bootup
}

migration_config()
{
    underlay_mode="true"
    FQDN="true"
    set_fqdn
    get_integration_bridge_name
    check_vif_id
    if [ "x$_migrate_intf " = "x" ]; then
        nsx_bm_log "ERROR: migrate interface is not defined"
        exit 1
    fi
    if [ "x$FQDN" = "xfalse" ]; then
        bms_config
    fi
    rm -f /etc/vmware/nsx-bm/bms.conf
    creat_bm_directory
    cp -f /opt/vmware/nsx-opsagent/scripts/debug.sh /opt/vmware/nsx-bm/debug.sh
    chmod 755 /opt/vmware/nsx-bm/debug.sh
    chown root:root /opt/vmware/nsx-bm/debug.sh
    cp -f /opt/vmware/nsx-opsagent/scripts/migration_manual_restore.sh /opt/vmware/nsx-bm/migration_manual_restore.sh
    chmod 755 /opt/vmware/nsx-bm/migration_manual_restore.sh
    chown root:root /opt/vmware/nsx-bm/migration_manual_restore.sh
    sed -e "s|{{ app_intf_name }}|$_app_intf_name|g; s|{{ routing_rules }}|$_routing_rules|g;" /opt/vmware/nsx-opsagent/scripts/route.sh > /opt/vmware/nsx-bm/route.sh
    chmod 755 /opt/vmware/nsx-bm/route.sh
    chown root:root /opt/vmware/nsx-bm/route.sh
    cp -f /opt/vmware/nsx-opsagent/scripts/bms_migrate.sh /tmp/bms_migrate.sh
    chmod 755 /tmp/bms_migrate.sh
    chown root:root /tmp/bms_migrate.sh
    sed -e "s|{{ app_intf_name }}|$_app_intf_name|g; s|{{ vif_id }}|$_vif_id|g; s|{{ migrate_intf }}|$_migrate_intf|g;" /opt/vmware/nsx-opsagent/scripts/migrate.sh > /tmp/migrate.sh
    chmod 755 /tmp/migrate.sh
    chown root:root /tmp/migrate.sh
    sed -e "s|{{ app_intf_name }}|$_app_intf_name|g;" /opt/vmware/nsx-opsagent/scripts/revert.sh > /tmp/revert.sh
    chmod 755 /tmp/revert.sh
    chown root:root /tmp/revert.sh
    create_bootup_script
    add_service_bootup
    bash -c "/tmp/bms_migrate.sh >> /var/log/migrate.log 2>&1"
    cat /var/log/migrate.log
}

ConfigMode=""

del_bootup_script()
{
    if [ "x$os_type" = "xUbuntu" ]; then
        update-rc.d -f nsx-baremetal remove
    elif [ "x$os_type" = "xRedHatEnterpriseServer" ] || [ "x$os_type" = "xCentOS" ] || [ "x$os_type" = "xSUSE" ] || [ "x$os_type" = "xOracleServer" ]; then
        chkconfig --del nsx-baremetal
    fi
}

bms_static_dhcp_restore()
{
    if [ "x$ConfigMode" = "xdhcp" ]; then
        dhclient -r -pf /var/run/dhclient-$_app_intf_name.pid $_app_intf_name
    fi
    ovs-vsctl -- --if-exists del-port ${_app_intf_name}-peer
    ip link del ${_app_intf_name} &> /dev/null || true
    del_bootup_script
    rm -rf /etc/vmware/nsx-bm /etc/init.d/nsx-baremetal
    if [ "x$os_type" = "xSUSE" ]; then
        rm -f /etc/sysconfig/network/ifcfg-$_app_intf_name
    fi
    rm -f /etc/vmware/nsx/nsx-baremetal.xml
    /etc/init.d/nsx-agent restart
    rm -rf /opt/vmware/nsx-bm
}

bms_migrate_restore()
{
    FQDN="false"
    set_fqdn
    sed -e "s|{{ app_intf_name }}|$_app_intf_name|g;" /opt/vmware/nsx-opsagent/scripts/bms_migrate_restore.sh > /tmp/bms_restore.sh
    chmod 755 /tmp/bms_restore.sh
    chown root:root /tmp/bms_restore.sh
    /tmp/bms_restore.sh >> /var/log/restore.log 2>&1
    del_bootup_script
    rm -rf /etc/vmware/nsx-bm /etc/init.d/nsx-baremetal
    if [ "x$FQDN" = "xfalse" ]; then
        rm -f /etc/vmware/nsx/nsx-baremetal.xml
        /etc/init.d/nsx-agent restart
    fi
    rm -rf /opt/vmware/nsx-bm
}

restore_config()
{
    set +e
    ConfigMode=`grep config_mode /etc/vmware/nsx-bm/bms.conf | cut -d"=" -f2`
    if [ "x$ConfigMode" = "xstatic" ] || [ "x$ConfigMode" = "xdhcp" ]; then
        bms_static_dhcp_restore
    elif [ "x$ConfigMode" = "xmigrate" ]; then
        bms_migrate_restore
    fi
}

[ $# -eq 0 ] && usage
while getopts ":c:s:a:m:r:i:v:h:" arg; do
    case $arg in
        c) # config_mode
            _config_mode=${OPTARG}
            ;;
        s) # static ips
            _static_ips=${OPTARG}
            for ip in $_static_ips
            do
                if ! echo $ip | grep -qE "^([0-9]{1,3}\.){3}([0-9]{1,3})/[0-9]{1,2}$|^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}/[0-9]{1,3}$" ; then
                    nsx_bm_log "ERROR: invalid static IP: $ip"
                    exit 1
                fi
            done
            ;;
        a) # app interface name
            _app_intf_name=${OPTARG}
            ;;
        m) # mac address
            _mac_address=${OPTARG}
            if ! echo $_mac_address | grep -qE "^(\w{2}:){5}\w{2}$" ; then
                nsx_bm_log "ERROR: invalid mac address: $_mac_address"
                exit 1
            fi
            ;;
        r) # routing rules
            _routing_rules=${OPTARG}
            ;;
        i) # migration interface name
            _migrate_intf=${OPTARG}
            ;;
        v) # vif id
            _vif_id=${OPTARG}
            if ! echo $_vif_id | grep -qE "^\w{8}(-\w{4}){3}-\w{12}$" ; then
                nsx_bm_log "ERROR: invalid vif id: $_vif_id"
                exit 1
            fi
            ;;
        h | *) # help
            usage
            exit 0
            ;;
    esac
done

if [ "x$_config_mode" = "xstatic" ]; then
    static_config
elif [ "x$_config_mode" = "xdhcp" ]; then
    dhcp_config
elif [ "x$_config_mode" = "xmigration" ]; then
    migration_config
elif [ "x$_config_mode" = "xrestore" ]; then
    restore_config
else
    nsx_bm_log "ERROR: invalid config mode: $_config_mode"
    exit 1
fi

exit 0
