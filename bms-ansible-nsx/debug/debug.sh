# Copyright (C) 2018 VMware, Inc.  All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

echo "netstat -an |grep 5671"
netstat -an |grep 5671

echo "netstat -an |grep 1235"
netstat -an |grep 1235

echo "ifconfig"
ifconfig

echo "ovs-vsctl show"
ovs-vsctl show

echo "ovs-ofctl dump-flows nsx-managed |ovs-decode-note|grep bms_bootstrap"
ovs-ofctl dump-flows nsx-managed |ovs-decode-note|grep bms_bootstrap

echo "ovs-appctl -t /var/run/vmware/nsx-agent/nsxa-ctl bms/underlay-get"
ovs-appctl -t /var/run/vmware/nsx-agent/nsxa-ctl bms/underlay-get

echo "LogSwitchConfigMsg"
/opt/vmware/nsx-nestdb/bin/nestdb-cli --json --cmd get vmware.nsx.nestdb.LogSwitchConfigMsg

echo "LogSwitchPortConfigMsg"
/opt/vmware/nsx-nestdb/bin/nestdb-cli --json --cmd get vmware.nsx.nestdb.LogSwitchPortConfigMsg

echo "VifStateMsg"
/opt/vmware/nsx-nestdb/bin/nestdb-cli --json --cmd get vmware.nsx.nestdb.VifStateMsg

echo "CcpSessionMsg"
/opt/vmware/nsx-nestdb/bin/nestdb-cli --json --cmd get vmware.nsx.nestdb.CcpSessionMsg

echo "ControllerInfoMsg"
/opt/vmware/nsx-nestdb/bin/nestdb-cli --json --cmd get vmware.nsx.nestdb.ControllerInfoMsg
