import requests
import csv
import uuid
import time

TOKEN     = "50f44ab1aefc29b47dad6e51886ae8af7b4efee9"
ASSET_UID = "aPR8YaaQkXuxNQrx6o9Lr5"
KF_BASE   = "https://kf.kobotoolbox.org"
KC_BASE   = "https://kc.kobotoolbox.org"

auth_headers = {"Authorization": f"Token {TOKEN}"}

# Step 1: Get the form's XForm ID (the internal id_string used in XML)
print("Fetching form details...")
r = requests.get(f"{KF_BASE}/api/v2/assets/{ASSET_UID}/", headers=auth_headers)
asset = r.json()
deployment = asset.get("deployment__identifier", "")
print(f"Deployment identifier: {deployment}")

# The id_string is the form's internal ID used in XML submissions
# Try fetching from the deployment info
r2 = requests.get(f"{KF_BASE}/api/v2/assets/{ASSET_UID}/deployment/", headers=auth_headers)
print(f"Deployment status: {r2.status_code}")
if r2.status_code == 200:
    dep = r2.json()
    print("Deployment info keys:", list(dep.keys()))
    print("Identifier:", dep.get("identifier"))
    print("Active:", dep.get("active"))

# Step 2: Find the correct submission URL
# Try the KoboCollect username-based endpoint
r3 = requests.get(f"{KF_BASE}/api/v2/assets/{ASSET_UID}/", headers=auth_headers)
asset_data = r3.json()
print("\nDeployment links:")
print(json_safe(asset_data.get("deployment__links", {})))

def json_safe(obj):
    import json
    return json.dumps(obj, indent=2)[:500]

print(json_safe(asset_data.get("deployment__links", {})))
