#!/usr/bin/env bash
################################################################################
### Copyright (C) 2020 VMware, Inc.  All rights reserved.
### SPDX-License-Identifier: BSD-2-Clause
################################################################################
date
export PATH=$PATH:/usr/sbin
echo "PATH: $PATH"


host_os=

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

isOEL() {
    if [ "$host_os" == "OracleServer" ]; then
        return 0
    fi
    return 1
}

get_os_type
if isRhel || isOEL || isSUSE; then
    rpm -e cvm-snmp nsx-agent nsx-cli nsx-exporter nsx-host-baremetal-server nsx-monitoring \
           nsx-mpa nsx-nestdb nsx-nestdb-python nsx-netopa nsx-opsagent nsx-platform-client \
           nsx-proxy nsx-python-gevent nsx-python-greenlet nsx-python-logging nsx-python-protobuf \
           nsx-python-utils nsx-rpc-python nsx-sfhc nsx-shared-libs nsx-vdpi openvswitch openvswitch-kmod \
           openvswitch-selinux-policy
    exit 0
elif isUbuntu; then
    dpkg --purge cvm-snmp libopenvswitch nsx-agent nsx-cli nsx-exporter nsx-host-baremetal-server nsx-monitoring nsx-mpa \
                 nsx-nestdb nsx-netopa nsx-opsagent nsx-platform-client nsx-proxy nsx-python-gevent nsx-python-greenlet \
                 nsx-python-logging nsx-python-protobuf nsx-python-utils nsx-sfhc nsx-shared-libs nsx-vdpi openvswitch-common \
                 openvswitch-datapath-dkms openvswitch-pki openvswitch-switch python-openvswitch
    exit 0
else
    exit 1
fi
