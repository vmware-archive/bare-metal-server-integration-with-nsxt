#!/usr/bin/env bash
################################################################################
### Copyright (C) 2018 VMware, Inc.  All rights reserved.
### SPDX-License-Identifier: BSD-2-Clause
################################################################################

#
# download.sh lcp-bundle-link
#

date
export PATH=$PATH:/usr/sbin

if [ $# != 1 ]; then
    exit 1
fi


# Fetch new nsx-lcp bundle
rm -rf /tmp/nsx-*
wget --no-check-certificate $1 -P /tmp/
tar xvC /tmp/ -f /tmp/${1##*/}

exit 0