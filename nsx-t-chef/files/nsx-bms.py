try:
    import simplejson
except ImportError:
    import json as simplejson
import sys
from hashlib import sha256
import os
import socket
import time
import re
import ssl
import sys
if sys.version_info < (3,):
    from urllib import urlencode as compat23_urlencode
    import httplib as compat23_httplib
else:
    from urllib.parse import urlencode as compat23_urlencode
    import http.client as compat23_httplib
import uuid
from base64 import b64encode


NSX_CONFIG_FILE = "/opt/vmware/nsx-opsagent/scripts/nsx-config.json"
NSX_VIFID_FILE = "/opt/vmware/nsx-opsagent/scripts/vifid"
NSX_LSPID_FILE = "/opt/vmware/nsx-opsagent/scripts/lspid"

mgrIP = ""
mgrUserName = ""
mgrPassWord = ""
mgrThumbPrint = ""


SERVICE_UNAVAILABLE_MAX_RETRY_COUNT = 3
_JSESSION_COOKIE_RE = re.compile("(?:^|;| |,)JSESSIONID=([^;, ]*)")


class ApiException(Exception):

    def __init__(self, msg):
        super(ApiException, self).__init__(msg)


def nsx_api_request(host, port, thumbprint, credentials,
            http_method, path, body=None, headers=None,
            connection_timeout=30, request_timeout=180,
            retry_count = SERVICE_UNAVAILABLE_MAX_RETRY_COUNT):
    """
    Issue an API request against an NSX API server. If a connection to
    the server cannot be established due to a connection error or a
    thumbprint mismatch, raises an ApiException.

    Args:
        host, port: Host IP and port number to send request to.
        thumbprint: The host API certificate thumbprint.
        credentials: A dictionary containing credentials to authenticate
                     with the host. Should either contain "username"
                     and "password", or "token". If all are supplied then
                     the token method will take precendence.
        http_method: "POST", "PUT", "GET", etc.
        path: Path on the host to send request to.
        body: Body of the message, if required.
        headers: Headers of the message, if required.
        connection_timeout: Raise socket.timeout if connection attempt
            exceeds this value.
        request_timeout: Raise socket.timeout if request exceeds this value.
        retry_count: Request is retried in case 'Retry-After' header is
            present in response.

    Returns:
        If a connection to the API server is established, returns a
        tuple (status, json, text, resp), where
        status is an HTTP response code
        json is the response from the server, if content-type application/json
             was returned from the API
        text is a textual description of the error, if a problem was encountered
        resp is the HTTP response object
    """
    port = int(port)
    thumbprint = thumbprint.lower()
    conn = None
    try:
        # Suppress default Python 2.7.9+ HTTPSConnection certificate and
        # hostname verification. Doing manual certificate thumbprint check
        # instead.
        if (sys.version_info >= (2, 7, 9) or
                "_create_unverified_context" in dir(ssl)):
            ctx = ssl._create_unverified_context()
            conn = compat23_httplib.HTTPSConnection(host, port, context=ctx,
                                                    timeout=connection_timeout)
        else:
            conn = compat23_httplib.HTTPSConnection(host, port,
                                                    timeout=connection_timeout)
        #if is_windows():
        #    conn._context.check_hostname = False
        conn.connect()
        # Change conn object's timeout property to request_timeout now that
        # we have an active connection
        conn.sock.settimeout(request_timeout)
    except (socket.error, socket.timeout) as ex:
        print("%s %s raised exception: %s" % (http_method, path, ex))
        raise ApiException("MSG_API_CONNECTION_FAILED")
    try:
        # Verify server thumbprint
        conn_thumbprint = sha256(conn.sock.getpeercert(True)).hexdigest()
        conn_thumbprint = conn_thumbprint.lower()
        if conn_thumbprint != thumbprint:
            raise ApiException("MSG_NODE_MANAGER_BAD_THUMBPRINT")

        # Authenticate
        if "token" in credentials and credentials["token"]:
           # No need to use /session/create API. Just add authorization header with token.
           auth_hdrs = {"Authorization": "RegistrationToken " + credentials["token"]}
           auth_failed_msg = "Authentication failed - bad token"
        else:
           auth_failed_msg = "Authentication failed - bad cookie or bad xsrf token"
           # Get session cookie by calling /session/create API.
           # Setup authentication headers/cookie in the form of "JSESSIONID=..."
           login_body = compat23_urlencode(
               {"j_username": credentials.get("username"), "j_password": credentials.get("password")})
           hdrs = {"Content-Type": "application/x-www-form-urlencoded",
                   "Content-Length": len(login_body)}
           conn.request("POST", "/api/session/create", login_body, hdrs)
           resp = conn.getresponse()
           resp_body = resp.read()
           # Note: for now Manager reverse proxy returns a 302 status if the
           # authentication succeeds (btw, it also returns 302 status if
           # authentication fails... see location note below).
           if resp.status != compat23_httplib.OK:
               err_text = "Authentication failed"
               return compat23_httplib.UNAUTHORIZED, None, err_text, None
           auth_hdrs = {}
           for hdr, value in resp.getheaders():
               if hdr.lower() == "set-cookie":
                   m = _JSESSION_COOKIE_RE.search(value)
                   if m is not None:
                       auth_hdrs = {"Cookie": "JSESSIONID=%s" % m.group(1)}
               if hdr.lower() == "x-xsrf-token":
                   auth_hdrs["X-XSRF-TOKEN"] = value
           if not auth_hdrs:
               print("API authentication response missing cookie")
               err_text = "Authentication failed - missing cookie"
               return compat23_httplib.UNAUTHORIZED, None, err_text, None
           if "X-XSRF-TOKEN" not in auth_hdrs:
               print("API authentication response missing xsrf token")
               pass

        # Invoke the requested API
        headers = {} if not headers else headers
        headers.update(auth_hdrs)
        conn.request(http_method, path, body, headers)
        resp = conn.getresponse()
        content_type = resp.getheader("content-type", "").lower()
        resp_body = resp.read()
        if resp.status == compat23_httplib.UNAUTHORIZED:
            return compat23_httplib.UNAUTHORIZED, None, auth_failed_msg, None
        if resp.status not in [
                compat23_httplib.OK, compat23_httplib.CREATED, compat23_httplib.ACCEPTED,
                compat23_httplib.NO_CONTENT]:
            print("%s %s returned status: %s\n%s" % (http_method, path,
                     resp.status, resp_body))

    except (socket.error, socket.timeout) as ex:
        print("%s %s raised exception: %s" % (http_method, path, ex))
        raise ApiException("MSG_API_CONNECTION_FAILED")
    except ApiException:
        raise
    except Exception as ex:
        print("%s %s raised exception: %s" % (http_method, path, ex))
        err_text = "An unexpected error occurred."
        return compat23_httplib.INTERNAL_SERVER_ERROR, None, err_text, None
    finally:
        if conn:
            conn.close()
            conn = None

    json = text = None
    if content_type.startswith("application/json"):
        try:
            if sys.version_info >= (3,):
                resp_body = resp_body.decode("utf8")
            json = simplejson.loads(resp_body)
        except:
            err_text = "The API server returned an invalid response body."
            print(err_text)
            return compat23_httplib.INTERNAL_SERVER_ERROR, None, err_text, None
    elif content_type.find("text/plain") != -1:
        if resp.status >= compat23_httplib.BAD_REQUEST:
            text = resp_body
    elif content_type.find("text/html") != -1:
        text = resp_body

    # Retry if "Retry-After" header is received in response
    if resp.getheader("Retry-After") and retry_count > 0:
        # For error codes like 429, 503, server does not process request and expect client
        # to make request again after some time. This time can be retrieved from
        # response header 'Retry-After'.
        if retry_count > SERVICE_UNAVAILABLE_MAX_RETRY_COUNT:
            retry_count = SERVICE_UNAVAILABLE_MAX_RETRY_COUNT
        retry_count = retry_count - 1
        retry_after = int(resp.getheader("Retry-After"))
        print("Header Retry-After: %s, retry_count: %s" % (retry_after, retry_count))
        if retry_after > 60:
            retry_after = 60
        time.sleep(retry_after + 5)
        return nsx_api_request(host, port, thumbprint, credentials, http_method, path, body, headers,
                       connection_timeout, request_timeout, retry_count)
    return resp.status, json, text, resp


def GetTnUuid():
    stream = os.popen("grep -oP '(?<=uuid>)[^<]+' /etc/vmware/nsx/host-cfg.xml")
    output = stream.read()
    tnid = output.strip()
    return tnid

def TnRealization(tnid):
    global mgrIP, mgrUserName, mgrPassWord, mgrThumbPrint
    mpURL = "/api/v1/transport-nodes/" + tnid + "/state"

    print("GET " + mpURL)
    for tries in range(0, 20):
        status, json_resp, text, resp = nsx_api_request(mgrIP, 443, mgrThumbPrint,
                {"username": mgrUserName, "password": mgrPassWord}, "GET", mpURL)

        print(status)
        print(json_resp['state'])

        assert status == 200, (
            "Transport node state get failed: status = %d" % status)

        if json_resp["state"] == "success":
            return
        else:
            time.sleep(30)

    assert False, "TN %s failed to initialize" % tnid

def TnRegister(tnid):
    global mgrIP, mgrUserName, mgrPassWord, mgrThumbPrint

    with open(NSX_CONFIG_FILE) as nsx_json_file:
        nsxData = simplejson.load(nsx_json_file)

        transportZoneId = nsxData['tn']['transport_zone_id']
        uplinkProfileId = nsxData['tn']['uplink_profile_id']
        pnics = nsxData['tn']['pnics']

    host_switch = {
        "pnics": pnics,
        "host_switch_name": "nsxvswitch",
        "host_switch_profile_ids": [
            {
                "key": "UplinkHostSwitchProfile",
                "value": uplinkProfileId
            }],
        "host_switch_type": "NVDS",
        "host_switch_mode": "STANDARD"
    }

    if nsxData['tn'].has_key('ip_assignment_spec'):
        host_switch["ip_assignment_spec"] = nsxData['tn']["ip_assignment_spec"]

    host_switches = {
        "host_switches": [
            host_switch
        ],
        "resource_type": "StandardHostSwitchSpec"
    }
    hostname = socket.gethostname().split('.')[0]
    tnData = {
        "host_switch_spec": host_switches,

        "node_id": tnid,
        "display_name": hostname,
        "resource_type": "TransportNode",
        "transport_zone_endpoints": [{
            "transport_zone_id": transportZoneId
        }]
    }
    mpURL = "/api/v1/transport-nodes"
    print("POST " + mpURL)
    print(tnData)

    status, json_resp, text, resp = nsx_api_request(mgrIP, 443, mgrThumbPrint,
        {"username": mgrUserName, "password": mgrPassWord}, "POST",
        mpURL, simplejson.dumps(tnData), {"Content-Type": "application/json"})
    print(status)
    print(json_resp)
    if status not in [
        compat23_httplib.OK, compat23_httplib.CREATED, compat23_httplib.ACCEPTED,
        compat23_httplib.NO_CONTENT]:
        print("POST " + mpURL + " failed")
        sys.exit(1)

def CreateTransportNode():
    tnid = GetTnUuid()
    TnRegister(tnid)
    TnRealization(tnid)


def TnDelete(tnid):
    global mgrIP, mgrUserName, mgrPassWord, mgrThumbPrint
    mpURL = "/api/v1/transport-nodes/" + tnid + "?force=false&unprepare_host=false"
    print("DELETE " + mpURL)
    status, json_resp, text, resp = nsx_api_request(mgrIP, 443, mgrThumbPrint,
        {"username": mgrUserName, "password": mgrPassWord}, "DELETE",
        mpURL, None, {"Content-Type": "application/json"})
    print(status)
    if status not in [
        compat23_httplib.OK, compat23_httplib.CREATED, compat23_httplib.ACCEPTED,
        compat23_httplib.NO_CONTENT]:
        print("DELETE " + mpURL + " failed")
        sys.exit(1)

def poll_for_tn_to_be_deleted(tnid):
    print("poll_for_tn_to_be_deleted...")
    global mgrIP, mgrUserName, mgrPassWord, mgrThumbPrint
    mpURL = "/api/v1/transport-nodes/" + tnid + "/state"
    print("GET " + mpURL)

    for tries in range(0, 30):

        status, json_resp, text, resp = nsx_api_request(mgrIP, 443, mgrThumbPrint,
            {"username": mgrUserName, "password": mgrPassWord}, "GET",
            mpURL, None, {"Content-Type": "application/json"})
        print(status)
        print(json_resp)

        if json_resp.has_key("error_code") and json_resp["error_code"] == 600:
            return
        else:
            time.sleep(20)

    assert False, "TN %s failed to delete" % tnid


def DeleteTransportNode():
    print("DeleteTransportNode...")
    tnid = GetTnUuid()
    TnDelete(tnid)
    poll_for_tn_to_be_deleted(tnid)


def DeleteLogSwitchPort():
    global mgrIP, mgrUserName, mgrPassWord, mgrThumbPrint
    lspid = GetLspId()

    mpURL = "/api/v1/logical-ports/" + lspid + "?detach=true"
    status, json_resp, text, resp = nsx_api_request(mgrIP, 443, mgrThumbPrint,
        {"username": mgrUserName, "password": mgrPassWord}, "DELETE",
        mpURL, None, {"Content-Type": "application/json"})
    print("DELETE " + mpURL)
    print(status)

    if status not in [
        compat23_httplib.OK, compat23_httplib.CREATED, compat23_httplib.ACCEPTED,
        compat23_httplib.NO_CONTENT]:
        print("DELETE " + mpURL + " failed")
        sys.exit(1)

    return

def PersistLspId(lspid):
    with open(NSX_LSPID_FILE, "w") as lspid_file:
            lspid_file.write(lspid)

def PersistVifId(vifid):
    with open(NSX_VIFID_FILE, "w") as vifid_file:
        vifid_file.write(vifid)

def GetLspId():
    with open(NSX_LSPID_FILE, "r") as lspid_file:
        lspid = lspid_file.read().strip()
    return lspid

def CreateLSPById(lsid, vifid, tnid):
    print("CreateLSPById...")
    global mgrIP, mgrUserName, mgrPassWord, mgrThumbPrint
    hostname = socket.gethostname().split('.')[0]
    lspname = hostname + "/nsx-eth@" + tnid
    lspData = {
        "display_name": lspname,
        "logical_switch_id": lsid,
        "attachment": {
            "attachment_type": "VIF",
            "id": vifid,
            "context": {
                "resource_type": "VifAttachmentContext",
                "allocate_addresses": "None",
                "vif_type": "INDEPENDENT",
                "transport_node_uuid": tnid
            }
        },
        "address_bindings": [],
        "admin_state": "UP",
    }
    mpURL = "/api/v1/logical-ports"
    status, json_resp, text, resp = nsx_api_request(mgrIP, 443, mgrThumbPrint,
        {"username": mgrUserName, "password": mgrPassWord}, "POST",
        mpURL, simplejson.dumps(lspData), {"Content-Type": "application/json"})
    print("POST " + mpURL)
    print(status)
    print(json_resp)
    if status not in [
        compat23_httplib.OK, compat23_httplib.CREATED, compat23_httplib.ACCEPTED,
        compat23_httplib.NO_CONTENT]:
        print("POST /api/v1/logical-ports failed %s", status)
        sys.exit(1)
    else:
        lspid = json_resp["id"]
        PersistLspId(lspid)


def GetLSPIdByName(lsName):
    global mgrIP, mgrUserName, mgrPassWord, mgrThumbPrint
    mpURL = "/api/v1/logical-switches"
    status, json_resp, text, resp = nsx_api_request(mgrIP, 443, mgrThumbPrint,
        {"username": mgrUserName, "password": mgrPassWord}, "GET",
        mpURL, None, {"Content-Type": "application/json"})
    print("GET " + mpURL)
    print(status)
    print(json_resp)
    if status not in [
        compat23_httplib.OK, compat23_httplib.CREATED, compat23_httplib.ACCEPTED,
        compat23_httplib.NO_CONTENT]:
        assert False, "GET /api/v1/logical-switches failed"
        print("GET /api/v1/logical-switches failed")
        sys.exit(1)

    lsid = ""
    for ls in json_resp["results"]:
        if ls["display_name"] == lsName:
            lsid = ls["id"]
            break
    if lsid == "":
        print("no such logical switch existing")
        sys.exit(1)

    return lsid

def CreateLSPByName(lsName, vifid, tnid):
    print("CreateLSPByName...")
    lsid = GetLSPIdByName(lsName)

    CreateLSPById(lsid, vifid, tnid)

def RemoveLspVifIdFile():
    os.remove(NSX_LSPID_FILE)
    os.remove(NSX_VIFID_FILE)

def CreateLSP(lsid, lsName, vifid, tnid):
    if lsid != "":
        CreateLSPById(lsid, vifid, tnid)
    else:
        CreateLSPByName(lsName, vifid, tnid)

def CreateLogSwitchPort():
    lsId = ""
    lsName = ""
    with open(NSX_CONFIG_FILE) as nsx_json_file:
        nsxData = simplejson.load(nsx_json_file)

        if nsxData['tn'].has_key("ls_id"):
            lsId = nsxData['tn']['ls_id']
        else:
            lsName = nsxData['tn']['ls_name']

    vifid = str(uuid.uuid4())
    PersistVifId(vifid)
    tnid = GetTnUuid()
    CreateLSP(lsId, lsName, vifid, tnid)

def CheckLSById(lsid):
    print("CheckLSById...")
    global mgrIP, mgrUserName, mgrPassWord, mgrThumbPrint
    mpURL = "/api/v1/logical-switches/" + lsid
    status, json_resp, text, resp = nsx_api_request(mgrIP, 443, mgrThumbPrint,
        {"username": mgrUserName, "password": mgrPassWord}, "GET",
        mpURL, None, {"Content-Type": "application/json"})

    print("GET " + mpURL)
    print(status)
    print(json_resp)
    if status not in [
        compat23_httplib.OK, compat23_httplib.CREATED, compat23_httplib.ACCEPTED,
        compat23_httplib.NO_CONTENT]:
        assert False, "GET /api/v1/logical-switches failed"
        print("GET /api/v1/logical-switches failed")
        sys.exit(1)

    if json_resp.has_key("vlan"):
        if json_resp["vlan"] != 0:
            assert False, "not a valid vlan 0 logical swtich"
            sys.exit(1)
        else:
            print("Logical Switch checking passed!")
            return
    else:
        assert False, "GET %s failed" % mpURL
        sys.exit(1)


def CheckLSByName(lsName):
    lsid = GetLSPIdByName(lsName)
    CheckLSById(lsid)

def CheckLS(lsid, lsName):
    if lsid != "":
        CheckLSById(lsid)
    else:
        CheckLSByName(lsName)

def CheckLogSwitch():
    lsId = ""
    lsName = ""
    with open(NSX_CONFIG_FILE) as nsx_json_file:
        nsxData = simplejson.load(nsx_json_file)

        if nsxData['tn'].has_key("ls_id"):
            lsId = nsxData['tn']['ls_id']
        else:
            lsName = nsxData['tn']['ls_name']

    CheckLS(lsId, lsName)

def CheckVlanTZ():
    global mgrIP, mgrUserName, mgrPassWord, mgrThumbPrint

    transportZoneId = ""
    with open(NSX_CONFIG_FILE) as nsx_json_file:
        nsxData = simplejson.load(nsx_json_file)

        transportZoneId = nsxData['tn']['transport_zone_id']

    mpURL = "/api/v1/transport-zones/" + transportZoneId
    status, json_resp, text, resp = nsx_api_request(mgrIP, 443, mgrThumbPrint,
        {"username": mgrUserName, "password": mgrPassWord}, "GET",
        mpURL, None, {"Content-Type": "application/json"})

    print("GET " + mpURL)
    print(status)
    print(json_resp)
    if status not in [
        compat23_httplib.OK, compat23_httplib.CREATED, compat23_httplib.ACCEPTED,
        compat23_httplib.NO_CONTENT]:
        assert False, "GET /api/v1/transport-zones failed"
        print("GET /api/v1/transport-zones failed")
        sys.exit(1)

    if json_resp.has_key("transport_type"):
        if json_resp["transport_type"] != "VLAN":
            assert False, "not a valid vlan tranport zone"
            sys.exit(1)
        else:
            print("Transport Zone checking passed!")
            return
    else:
        assert False, "GET %s failed" % mpURL
        sys.exit(1)


def Usage():
    print("Usage: this-script nsx-bms.py <mgrip> <username> <password> <thumbprint> <tn/lsp/ls> <-a/-d/-vlan0check>")
    sys.exit(1)

# cmd: nsx-bms.py <mgrip> <username> <password> <thumbprint> <tn/lsp/tz> <-a/-d/-vlan0check/-vlantzcheck>
def main():
    global mgrIP, mgrUserName, mgrPassWord, mgrThumbPrint

    argLen = len(sys.argv)

    if argLen != 7:
        Usage()

    mgrIP = sys.argv[1]
    mgrUserName = sys.argv[2]
    mgrPassWord = sys.argv[3]
    mgrThumbPrint = sys.argv[4]

    if sys.argv[5] not in ["tn", "lsp", "ls", "tz"]:
        Usage()

    if sys.argv[6] not in ["-a", "-d", "-vlan0check", "-vlantzcheck"]:
        Usage()

    if sys.argv[5] == "tn":
        if sys.argv[6] == "-a":
            CreateTransportNode()
        elif sys.argv[6] == "-d":
            DeleteTransportNode()
        else:
            Usage()
    elif sys.argv[5] == "lsp":
        if sys.argv[6] == "-a":
            CreateLogSwitchPort()
        elif sys.argv[6] == "-d":
            DeleteLogSwitchPort()
            RemoveLspVifIdFile()
        else:
            Usage()
    elif sys.argv[5] == "ls":
        if sys.argv[6] == "-vlan0check":
            CheckLogSwitch()
        else:
            Usage()
    elif sys.argv[5] == "tz":
        if sys.argv[6] == "-vlantzcheck":
            CheckVlanTZ()
        else:
            Usage()

    return

if __name__ == "__main__":
    main()