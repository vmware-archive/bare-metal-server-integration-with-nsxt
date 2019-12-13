################################################################################
### Copyright (C) 2019 VMware, Inc.  All rights reserved.
### SPDX-License-Identifier: BSD-2-Clause
################################################################################
from hashlib import sha256
import importlib
import ssl
import sys
import socket

httplib_module = "http.client" if sys.version_info >= (3,) else "httplib"
httplib = importlib.import_module(httplib_module)
import traceback


_OK = 0
_ERROR_NOT_ENOUGH_ARGUMENTS_SPECIFIED = 1
_ERROR_CONNECT_TO_MP_FAILURE = 2
_ERROR_MP_THUMBPRINT_MISMATCH = 3
_ERROR_UNABLE_TO_GET_THUMBPRINT = 4


def thumbprint_validate(server, port, thumbprint):
    try:
        # Suppress default Python 2.7.9+ HTTPSConnection certificate and
        # hostname verification. Doing manual certificate thumbprint check
        # instead.
        if (sys.version_info >= (2, 7, 9) or
                "_create_unverified_context" in dir(ssl)):
            ctx = ssl._create_unverified_context()
            conn = httplib.HTTPSConnection(
                server, port, context=ctx,
                timeout=30)
        else:
            conn = httplib.HTTPSConnection(
                server, port, timeout=30)
        conn.connect()
    except socket.error as ex:
        sys.stderr.write(
            "ERROR: unable to connect to manager at %s:%s\n" %
            (server, port))
        return _ERROR_CONNECT_TO_MP_FAILURE

    try:
        # Verify server thumbprint
        conn_thumbprint = sha256(conn.sock.getpeercert(True)).hexdigest()
        conn_thumbprint = conn_thumbprint.lower()
        if conn_thumbprint != thumbprint:
            sys.stderr.write("ERROR: manager thumbprint mismatch\n")
            return _ERROR_MP_THUMBPRINT_MISMATCH
        else:
            sys.stdout.write("OK: manager thumbprint match\n")
    except Exception:
        sys.stderr.write(
            "ERROR: unable to get thumbprint: %s\n" %
            traceback.format_exc())
        return _ERROR_UNABLE_TO_GET_THUMBPRINT
    finally:
        if conn:
            conn.close()
    return _OK


def main(argv):
    if len(argv) < 4:
        sys.stderr.write("ERROR: not enough arguments specified\n")
        return _ERROR_NOT_ENOUGH_ARGUMENTS_SPECIFIED

    server = argv[1]
    port = argv[2]
    thumbprint = argv[3]

    return thumbprint_validate(server, port, thumbprint)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
