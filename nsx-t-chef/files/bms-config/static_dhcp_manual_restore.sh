#!/bin/bash

################################################################################
### Copyright (C) 2018 VMware, Inc.  All rights reserved.
### SPDX-License-Identifier: BSD-2-Clause
################################################################################

if (($# > 1)); then
    echo "Too many parameters: $@"
    exit
elif [ $# -eq 1 ]; then
    app_intf_name=$1
else
    app_intf_name=nsx-eth
fi

get_os_type() {
    host_os=$(lsb_release -si)
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

get_os_type


dhclient -r -pf /var/run/dhclient-$app_intf_name.pid $app_intf_name
ovs-vsctl -- --if-exists del-port ${app_intf_name}-peer

ip link del ${app_intf_name} &> /dev/null

if isRhel; then
    chkconfig --del nsx-baremetal
elif isUbuntu; then
    update-rc.d -f nsx-baremetal remove
fi

rm -rf /etc/vmware/nsx-bm
rm -f /etc/init.d/nsx-baremetal

