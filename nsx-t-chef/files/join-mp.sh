#!/usr/bin/env bash

#
# join-mp.sh mp-ip username password thumbprint
#

if [ $# != 4 ]; then
    exit 1
fi

nsxcli -c "join management-plane $1 username $2 password $3 thumbprint $4"