#!/bin/bash
#
# Copyright (C) 2018 VMware, Inc.  All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause
#
# nsx-baremetal-server
#
routing_rules='{{ routing_rules }}'
if [ "x$routing_rules" != "x" ]; then
    echo ${routing_rules} | awk '{len=split($0,a,",");for(i=1;i<=len;i++) system("route add "a[i]" dev {{ app_intf_name }}")}'
fi
