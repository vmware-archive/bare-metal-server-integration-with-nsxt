#!/usr/bin/env bash
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
if isRhel || isOEL; then
    OVS_DATAPATH_PKG=$(ls /tmp/nsx-lcp-baremetal-server*/openvswitch-kmod*.rpm)
    sudo rpm -iv --replacepkgs $OVS_DATAPATH_PKG
    OVS_OTHER_PKGS=$(ls /tmp/nsx-lcp-baremetal-server*/*openvswitch*.rpm | grep -v openvswitch-kmod)
    sudo rpm -iv --replacepkgs $OVS_OTHER_PKGS
    ALL_OTHER_PKGS=$(ls /tmp/nsx-lcp-baremetal-server*/*.rpm | grep -v openvswitch)
    sudo rpm -Uv --replacepkgs --oldpackage $ALL_OTHER_PKGS
elif isUbuntu; then
    OVS_DATAPATH_PKG=$(ls /tmp/nsx-lcp-baremetal-server*/openvswitch-datapath*.deb)
    OVS_OTHER_PKGS=$(ls /tmp/nsx-lcp-baremetal-server*/*openvswitch*.deb | grep -v openvswitch-datapath)
    ALL_OTHER_PKGS=$(ls /tmp/nsx-lcp-baremetal-server*/*.deb | grep -v openvswitch)
    sudo dpkg -i $OVS_DATAPATH_PKG
    sudo dpkg -i -B $OVS_OTHER_PKGS
    sudo dpkg -i $ALL_OTHER_PKGS
elif isSUSE; then
    NSX_SHARED_LIBS=$(ls /tmp/nsx-lcp-baremetal-server*/nsx-shared-libs*.rpm)
    OVS_DATAPATH_PKG=$(ls /tmp/nsx-lcp-baremetal-server*/openvswitch-kmod*.rpm)
    OVS_OTHER_PKGS=$(ls /tmp/nsx-lcp-baremetal-server*/*openvswitch*.rpm | grep -v openvswitch-kmod)
    ALL_OTHER_PKGS=$(ls /tmp/nsx-lcp-baremetal-server*/*.rpm | grep -v openvswitch)
    sudo rpm -Uv --replacepkgs --oldpackage $NSX_SHARED_LIBS
    sudo rpm -iv --replacepkgs $OVS_DATAPATH_PKG
    sudo rpm -iv --replacepkgs $OVS_OTHER_PKGS
    sudo rpm -Uv --replacepkgs --oldpackage $ALL_OTHER_PKGS
else
    exit 1
fi
