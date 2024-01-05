import requests
from os import environ

# NOTE: Need to define these env variables
RPORT_HOST_ENV = "RPORT_HOST"
CREDS_ENV = "RPORT_CREDENTIALS"

if RPORT_HOST_ENV not in environ:
    raise EnvironmentError("ERROR: Missing env variable $RPORT_HOST")

RPORT_HOST = environ.get(RPORT_HOST_ENV)
RPORT_URL_ROOT = f"https://{RPORT_HOST}/api/v1"

if CREDS_ENV not in environ:
    raise EnvironmentError("ERROR: Missing env variable $RPORT_CREDENTIALS")
creds = environ.get(CREDS_ENV).split(":")
if len(creds) != 2:
    raise EnvironmentError("ERROR: Missing env variable $RPORT_CREDENTIALS")
authCache = requests.auth.HTTPBasicAuth(creds[0], creds[1])


def httpGet(url):
    res = requests.get(url, auth=authCache)
    if res.status_code != 200:
        raise EnvironmentError(
            f"Request failed: {url}, http_code: {res.status_code}, text: {res.text}"
        )
    return res.json()["data"]


def httpPut(url):
    res = requests.put(url, auth=authCache)
    if res.status_code != 200:
        raise EnvironmentError(
            f"Request failed: {url}, http_code: {res.status_code}, text: {res.text}"
        )
    return res.json()["data"]


def vaultLookup(clientId, keys):
    dict = {}
    url = f"{RPORT_URL_ROOT}/vault?filter[client_id]={clientId}"
    vaultValues = httpGet(url)
    for v in vaultValues:
        if v["key"] in keys:
            url = f"{RPORT_URL_ROOT}/vault/{v['id']}"
            dict[v["key"]] = httpGet(url)["value"]
    return dict
