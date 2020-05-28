#!/bin/bash
#
# Copyright (C) 2018 VMware, Inc.  All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause
#
# nsx-baremetal-server
#
# chkconfig: 2345 08 92
# description:

#
### BEGIN INIT INFO
# Provides:          nsx-baremetal-server
# Required-Start:
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: nsx-baremetal-server
### END INIT INFO


BMS_CONFIG_FILE="/etc/vmware/nsx-bm/bms.conf"

config_mode=
migrate_interface=
isStatic=
ip_address=
prefix=
gateway=
migrate_mac=
defaultGatewayIp=
defaultGatewayDev=


nsx_bm_log() {
    echo "${1}"
    logger -p daemon.info -t NSX-BMS "${1}"
}

get_os_type() {
    host_os=$(lsb_release -si)
    nsx_log "host_os: $host_os"
}

isSUSE() {
    if [ "$host_os" == "SUSE" ]; then
        return 0
    fi
    return 1
}

parse_bms_config() {
    if [ ! -f $BMS_CONFIG_FILE ]; then
        nsx_bm_log "ERROR: BMS config file not found"
        exit 1
    fi

    while read line
    do
        output=($(echo $line | awk -F'=' '{print $1,$2}'))
        key="${output[0]}"
        value="${output[1]}"
        if [ "$key" == "config_mode" ]; then
            config_mode=$value
        elif [ "$key" == "migrate_interface" ]; then
            migrate_interface=$value
        elif [ "$key" == "isStatic" ]; then
            isStatic=$value
        elif [ "$key" == "ip_address" ]; then
            ip_address=$value
        elif [ "$key" == "netmask" ]; then
            netmask=$value
        elif [ "$key" == "prefix" ]; then
            prefix=$value
        elif [ "$key" == "gateway" ]; then
            gateway=$value
        elif [ "$key" == "migrate_mac" ]; then
            migrate_mac=$value
        elif [ "$key" == "defaultGatewayIp" ]; then
            defaultGatewayIp=$value
        elif [ "$key" == "defaultGatewayDev" ]; then
            defaultGatewayDev=$value
        fi
    done < $BMS_CONFIG_FILE

    nsx_bm_log "config_mode: $config_mode"
    nsx_bm_log "migrate_interface: $migrate_interface"
    nsx_bm_log "isStatic: $isStatic"
    nsx_bm_log "ip_address: $ip_address"
    nsx_bm_log "netmask: $netmask"
    nsx_bm_log "prefix: $prefix"
    nsx_bm_log "gateway: $gateway"
    nsx_bm_log "migrate_mac: $migrate_mac"
    nsx_bm_log "defaultGatewayIp: $defaultGatewayIp"
    nsx_bm_log "defaultGatewayDev: $defaultGatewayDev"
}

start() {
    nsx_bm_log "nsx bare metal start"
    parse_bms_config

    ip link add {{ app_intf_name }} type veth peer name {{ app_intf_name }}-peer
    ip link set dev {{ app_intf_name }} address $migrate_mac
    ip link set dev {{ app_intf_name }} up
    ip link set dev {{ app_intf_name }}-peer up

    ovs-vsctl --timeout=5 -- --if-exists del-port {{ app_intf_name }}-peer -- add-port nsx-managed {{ app_intf_name }}-peer \
    -- set Interface {{ app_intf_name }}-peer external-ids:attached-mac=$migrate_mac \
    external-ids:iface-id={{ vif_id }} external-ids:iface-status=active

    if [ "$isStatic" = true ]; then
        if [ ! -z "$netmask" ]; then
            ifconfig {{ app_intf_name }} $ip_address netmask $netmask up
        elif [ ! -z "$prefix" ]; then
            ifconfig {{ app_intf_name }} $ip_address/$prefix
        else
            ifconfig {{ app_intf_name }} $ip_address
        fi
        if [ ! -z "$gateway" ]; then
            ip route add default via $gateway dev {{ app_intf_name }}
        fi
        if [ "$migrate_interface" == "$defaultGatewayDev" ]; then
            route add default gw $defaultGatewayIp
        fi
    else
        if isSUSE; then
            ifup {{ app_intf_name }}
        else
            dhclient -nw -pf /var/run/dhclient-{{ app_intf_name }}.pid {{ app_intf_name }}
        fi
    fi
    bash /opt/vmware/nsx-bm/route.sh
}

case "${1}" in
   "start")
      start
   ;;
   *)
      exit 1
   ;;
esac
