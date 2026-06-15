import requests
import json
import csv
import uuid
import time

TOKEN    = "50f44ab1aefc29b47dad6e51886ae8af7b4efee9"
ASSET_UID = "aPR8YaaQkXuxNQrx6o9Lr5"
KF_BASE  = "https://kf.kobotoolbox.org"
KC_BASE  = "https://kc.kobotoolbox.org"

headers = {"Authorization": f"Token {TOKEN}"}

# ── Step 1: Verify token & fetch asset info ────────────────────────────────
print("Checking token and fetching form info...")
r = requests.get(f"{KF_BASE}/api/v2/assets/{ASSET_UID}/", headers=headers)
if r.status_code != 200:
    print(f"ERROR: {r.status_code} - {r.text[:300]}")
    exit(1)

asset = r.json()
print(f"✅ Form found: {asset.get('name')}")
print(f"   Status:     {asset.get('deployment_status')}")
print(f"   XForm ID:   {asset.get('uid')}")

# Print content (to understand field names)
content = asset.get("content", {})
survey = content.get("survey", [])
print(f"\nFirst 10 survey fields:")
for item in survey[:10]:
    print(f"  type={item.get('type'):<20} name={item.get('$autoname', item.get('name',''))}")
