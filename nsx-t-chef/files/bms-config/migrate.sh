#!/bin/bash

# Copyright (C) 2018 VMware, Inc.  All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

NSX_ETH={{ app_intf_name }}
APP_VIF_ID={{ vif_id }}
MigratePnicName={{ migrate_intf }}

STOP_DHCLIENT_SCRIPT="/etc/vmware/nsx-opsagent/dhclient-stop "
IFCFG_FILE_UBUNTU="/etc/network/interfaces"
BMS_CONFIG_DIR="/etc/vmware/nsx-bm"
BMS_CONFIG_FILE="/etc/vmware/nsx-bm/bms.conf"
BMS_CMT_PREFIX="##BMS "

NSX_ETH_PEER=$NSX_ETH"-peer"

# ConfigMode: "dhcp" "static" "migrate"
ConfigMode="migrate"
BridgeIntfPrefix="~"
SUSEBridgeIntfPrefix="nsx_"
MigrateBridgeIntfName=
isStatic=true
isIpConfigured=false
interfaceStatus=
ip_address=
netmask=
prefix=
gateway=
migrate_mac=
defaultGatewayIp=
defaultGatewayDev=
host_os=

nsx_bm_log() {
    echo "${1}"
    logger -p daemon.info -t NSX-BMS "${1}"
}

get_os_type() {
    host_os=$(lsb_release -si)
    nsx_bm_log "host_os: $host_os"
}

isRhel() {
    if [ "$host_os" == "RedHatEnterpriseServer" ]; then
        return 0
    fi
    if [ "$host_os" == "CentOS" ]; then
        return 0
    fi
    if [ "$host_os" == "OracleServer" ]; then
        return 0
    fi
    return 1
}

isUbuntu() {
    if [ "$host_os" == "Ubuntu" ]; then
        return 0
    fi
    return 1
}

isSUSE() {
    if [ "$host_os" == "SUSE" ]; then
        return 0
    fi
    return 1
}

get_migrate_bridge_intf_name() {
    if isSUSE; then
        MigrateBridgeIntfName=$SUSEBridgeIntfPrefix$MigratePnicName
    else
        MigrateBridgeIntfName=$BridgeIntfPrefix$MigratePnicName
    fi
}

GetDefaultRoute() {
    output=($(route -n | grep "^0.0.0.0" | awk {'print $8, $2'}))
    defaultGatewayDev="${output[0]}"
    defaultGatewayIp="${output[1]}"
    nsx_bm_log "defaultGatewayIp: $defaultGatewayIp"
    nsx_bm_log "defaultGatewayDev: $defaultGatewayDev"
}

get_interface_status() {
    #$1: nic name
    local intf_name=$1
    nsx_bm_log "get interface $intf_name's status"
    ret=$(ls /sys/class/net/$intf_name 2>&1)
    match=$(echo $ret | grep "No such file")
    if [ ! -z "$match" ]; then
        nsx_bm_log "interface $intf_name not exist"
        interfaceStatus="not-found"
        exit 1
    fi

    up=$(ifconfig $intf_name |grep "UP")
    if [ -z "$up" ]; then
        interfaceStatus="down"
        return
    fi

    ip=$(ifconfig $intf_name |grep inet |grep -v inet6|awk '{print $2}'|tr -d "addr:")
    nsx_bm_log "ip: $ip"
    if [ ! -z "$ip" ]; then
        interfaceStatus="l3up"
    else
        interfaceStatus="l2up"
    fi
}


get_nic_ip_config_spec() {
    if isRhel || isSUSE; then
        get_rhel_nic_ip_config_spec $1
    elif isUbuntu; then
        get_ubuntu_nic_ip_config_spec $1
    else
        nsx_bm_log "unkown OS, abort"
        exit 1
    fi
    if [ "$isStatic" = true ] && [ ! -z "$ip_address" ]; then
        isIpConfigured=true
    elif [ "$isStatic" = false ]; then
        isIpConfigured=true
    fi

    nsx_bm_log "isStatic: $isStatic"
    nsx_bm_log "ip_address: $ip_address"
    nsx_bm_log "netmask: $netmask"
    nsx_bm_log "prefix: $prefix"
    nsx_bm_log "gateway: $gateway"
    nsx_bm_log "isIpConfigured: $isIpConfigured"
}

get_rhel_nic_ip_config_spec() {
    local intf_name=$1
    if isRhel; then
        local configFile="/etc/sysconfig/network-scripts/ifcfg-"$1
    elif isSUSE; then
        local configFile="/etc/sysconfig/network/ifcfg-"$1
    fi

    nsx_bm_log "configFile: $configFile"

    while read line
    do
        output=($(echo $line | awk -F'=' '{print $1,$2}'))
        key="${output[0]}"
        value="${output[1]}"
        if [ "$key" == "BOOTPROTO" ]; then
            if [ "$value" == "dhcp" ] || [ "$value" == "\"dhcp\"" ] || [ "$value" == "'dhcp'" ]; then
                isStatic=false
            fi
        elif [ "$key" == "IPADDR" ]; then
            ip_address=$value
            ip_address="${ip_address%\"}"
            ip_address="${ip_address#\"}"
        elif [ "$key" == "NETMASK" ]; then
            netmask=$value
            netmask="${netmask%\"}"
            netmask="${netmask#\"}"
        elif [ "$key" == "PREFIX" ]; then
            prefix=$value
            prefix="${prefix%\"}"
            prefix="${prefix#\"}"
        elif [ "$key" == "GATEWAY" ]; then
            gateway=$value
            gateway="${gateway%\"}"
            gateway="${gateway#\"}"
        fi
    done < $configFile
}

get_ubuntu_nic_ip_config_spec() {
    #$1: nic name
    nsx_bm_log "get nic ip config spec..."
    local intf_name=$1
    nsx_bm_log "interface: $intf_name"
    local isTargetInterface=false
    while read line
    do
        vars=($line)
        if [ "${vars[0]}" == "iface" ]; then
            if [ "${#vars[@]}" -eq 4 ]; then
                if [ "${vars[1]}" == "$intf_name" ]; then
                    if [ "${vars[3]}" == "dhcp" ]; then
                       isStatic=false
                    else
                       isStatic=true
                    fi
                    isTargetInterface=true
                    continue
                else
                    isTargetInterface=false
                fi
           fi
        fi
        if [ "$isTargetInterface" = true ]; then
            if [ "${#vars[@]}" -eq 2 ]; then
                if [ "${vars[0]}" == "address" ]; then
                    ip_address=${vars[1]}
                elif [ "${vars[0]}" == "netmask" ]; then
                    netmask=${vars[1]}
                elif [ "${vars[0]}" == "gateway" ]; then
                    gateway=${vars[1]}
                fi
            fi
        fi
    done < $IFCFG_FILE_UBUNTU
}


# save the pnic mac for migrating to application port
# IN: $1=<if_name> (e.g. eth1)
get_interface_mac() {
   #$1: nic name
   local mac=$(cat /sys/class/net/$1/address)
   nsx_bm_log $mac
}


StopDhclient() {
   #$1: nic name
   $STOP_DHCLIENT_SCRIPT $1
}


StartIntf() {
   ifup $1
}


StopIntf() {
    StopDhclient $1
    ifdown $1
}


RestartInterface() {
   StopIntf $1
   StartIntf $1
}


IFUP_L2_ONLY() {
   ifconfig $1 0.0.0.0 up 2>&1
}

start_app_intf_forSUSE() {
    nsx_bm_log "start_app_intf_forSUSE"
    local old="/etc/sysconfig/network/ifcfg-"$MigrateBridgeIntfName
    local new="/etc/sysconfig/network/ifcfg-"$1
    cp $old $new
    sed -i "/DEVICE/s/^/$BMS_CMT_PREFIX/" $new
    sed -i "/NAME/s/^/$BMS_CMT_PREFIX/" $new
    ifdown $1
    ifup $1
}


# IN: $1=<if_name> (e.g. eth1)
start_app_intf() {
    nsx_bm_log "start app interface"
    ip link set $NSX_ETH up

    if isSUSE; then
        start_app_intf_forSUSE $1
        return
    else
        if [ "$isStatic" = false ]; then
            nsx_bm_log "start app interface dhcp"
            dhclient -nw -pf /var/run/dhclient-$1.pid $1
        fi
    fi
}

# IN: $1=<if_name> (e.g. eth1)
stop_app_intf_dhcp() {
    dhclient -r -pf /var/run/dhclient-$1.pid $1
}

update_ifcfg_file() {
    if isRhel || isSUSE; then
        update_rhel_ifcfg_file $1
    fi
    if isUbuntu; then
        update_ubuntu_ifcfg_file $1
    fi
}

update_ubuntu_ifcfg_file() {
    local intf_name=$1
    nsx_bm_log "update_ifcfg_file"
    if [ "$isStatic" = false ]; then
        sed -i "/auto $intf_name/s/^/$BMS_CMT_PREFIX/" $IFCFG_FILE_UBUNTU
        sed -i "/iface $intf_name inet dhcp/s/^/$BMS_CMT_PREFIX/" $IFCFG_FILE_UBUNTU
    else
        nsx_bm_log "update static config"
        line=$(sed -n "/auto $intf_name/=" $IFCFG_FILE_UBUNTU)
        sed -i "$line aauto $NSX_ETH" $IFCFG_FILE_UBUNTU
        sed -i "/auto $intf_name/s/^/$BMS_CMT_PREFIX/" $IFCFG_FILE_UBUNTU

        #line=$(sed -n "/iface $intf_name inet static/=" $IFCFG_FILE_UBUNTU)

        #total_linenum=$(cat $IFCFG_FILE_UBUNTU |wc -l)
        #(( line++ ))
        #while [ $line -le $total_linenum ]
        #do
        #    key=$(sed -n "$line"p $IFCFG_FILE_UBUNTU | awk {'print $1'})
        #    if [ "$key" == "auto" ] || [ "$key" == "iface" ]; then
        #        break
        #    fi
        #    sed -i "$line{s/^/$BMS_CMT_PREFIX/}" $IFCFG_FILE_UBUNTU
        #    (( line++ ))
        #done

        line=$(sed -n "/iface $intf_name inet static/=" $IFCFG_FILE_UBUNTU)
        sed -i "$line aiface $NSX_ETH inet static" $IFCFG_FILE_UBUNTU
        sed -i "/iface $intf_name inet static/s/^/$BMS_CMT_PREFIX/" $IFCFG_FILE_UBUNTU
    fi
}

update_rhel_ifcfg_file() {
    local intf_name=$1
    if isRhel; then
        local configFile="/etc/sysconfig/network-scripts/ifcfg-"$1
    elif isSUSE; then
        local configFile="/etc/sysconfig/network/ifcfg-"$1
    fi


    if [ "$isStatic" = true ]; then
        sed -i "/IPADDR/s/^/$BMS_CMT_PREFIX/" $configFile
        sed -i "/NETMASK/s/^/$BMS_CMT_PREFIX/" $configFile
        sed -i "/GATEWAY/s/^/$BMS_CMT_PREFIX/" $configFile
        if isRhel; then
            cp /etc/sysconfig/network-scripts/ifcfg-$MigrateBridgeIntfName /etc/sysconfig/network-scripts/ifcfg-$NSX_ETH
            sed -i "s/^$BMS_CMT_PREFIX//g" /etc/sysconfig/network-scripts/ifcfg-$NSX_ETH
            sed -i "s/$MigrateBridgeIntfName/$NSX_ETH/" /etc/sysconfig/network-scripts/ifcfg-$NSX_ETH
            sed -i "/OVS/"d /etc/sysconfig/network-scripts/ifcfg-$NSX_ETH
            sed -i "/ovs/"d /etc/sysconfig/network-scripts/ifcfg-$NSX_ETH
        fi
    else
        sed -i "/BOOTPROTO/s/^/$BMS_CMT_PREFIX/" $configFile
    fi
}

pre_migrate_to_app() {
    local intf_name=$1
    # save the pnic mac for migrating to app port
    migrate_mac=$(get_interface_mac $intf_name)
    nsx_bm_log "migrate mac: $migrate_mac"
}

attach_ovs_port() {
    nsx_bm_log "attach ovs port..."
    ovs-vsctl --timeout=5 -- --if-exists del-port $NSX_ETH_PEER -- add-port nsx-managed $NSX_ETH_PEER -- set Interface $NSX_ETH_PEER external-ids:attached-mac=$migrate_mac external-ids:iface-id=$APP_VIF_ID external-ids:iface-status=active
}


update_route() {
    if [ ! -z "$gateway" ]; then
        ip route add default via $gateway dev $NSX_ETH
    fi
    # resotre default route (if the pnic is on static IP)
    if [ "$isStatic" = true ]; then
        if [ "$intf_name" == "$defaultGatewayDev" ]; then
            nsx_bm_log "add default route"
            route add default gw $defaultGatewayIp
        fi
    fi
}

create_app_intf() {
    nsx_bm_log "create app interface"

    ip link del $NSX_ETH &> /dev/null

    ip link add $NSX_ETH type veth peer name $NSX_ETH_PEER
    # migrate mac address
    ip link set $NSX_ETH address $migrate_mac
    ip link set $NSX_ETH_PEER up

    if [ "$isStatic" = true ]; then
        nsx_bm_log "config ipaddress"
        if [ ! -z "$ip_address" ]; then
            if [ ! -z "$netmask" ]; then
                ifconfig $NSX_ETH $ip_address netmask $netmask
            elif [ ! -z "$prefix" ]; then
                ifconfig $NSX_ETH $ip_address/$prefix
            else
                ifconfig $NSX_ETH $ip_address
            fi
        fi
    fi

    attach_ovs_port
}


post_migrate_to_app() {
    local intf_name=$1

    # ifdown migrated port
    StopIntf $intf_name

    start_app_intf $NSX_ETH

    update_route

    update_ifcfg_file $intf_name
}


delete_nsx_bms_config() {
    rm -rf $BMS_CONFIG_FILE
}


generate_config_file() {
    delete_nsx_bms_config

    mkdir -p $BMS_CONFIG_DIR

    nsx_bm_log "config_mode=$ConfigMode" >> $BMS_CONFIG_FILE
    nsx_bm_log "migrate_interface=$MigrateBridgeIntfName" >> $BMS_CONFIG_FILE
    nsx_bm_log "isStatic=$isStatic" >> $BMS_CONFIG_FILE
    nsx_bm_log "migrate_mac=$migrate_mac" >> $BMS_CONFIG_FILE
    nsx_bm_log "ip_address=$ip_address" >> $BMS_CONFIG_FILE
    nsx_bm_log "netmask=$netmask" >> $BMS_CONFIG_FILE
    nsx_bm_log "prefix=$prefix" >> $BMS_CONFIG_FILE
    nsx_bm_log "gateway=$gateway" >> $BMS_CONFIG_FILE
    nsx_bm_log "defaultGatewayIp=$defaultGatewayIp" >> $BMS_CONFIG_FILE
    nsx_bm_log "defaultGatewayDev=$defaultGatewayDev" >> $BMS_CONFIG_FILE
}

migrate_ip_to_app() {
    nsx_bm_log "migrage bridge ip to app"
    get_os_type

    get_migrate_bridge_intf_name
    nsx_bm_log "migrate bridge interface name $MigrateBridgeIntfName"

    get_interface_status $MigrateBridgeIntfName
    if [ "$interfaceStatus" != "l3up" ]; then
        nsx_bm_log "not l3up, no suitable interface to be migrated"
        return
    fi

    GetDefaultRoute
    get_nic_ip_config_spec $MigrateBridgeIntfName
    if [ "$isIpConfigured" = false ]; then
        nsx_bm_log "nic $MigrateBridgeIntfName has no IP configured, skip migration"
        return
    fi

    pre_migrate_to_app $MigrateBridgeIntfName
    generate_config_file
    create_app_intf
    post_migrate_to_app $MigrateBridgeIntfName
}

echo "=========================="
date
nsx_bm_log "nsx baremetal migrate ip to application"
nsx_bm_log "NSX_ETH: $NSX_ETH, APP_VIF_ID: $APP_VIF_ID, MigratePnicName: $MigratePnicName"
migrate_ip_to_app
