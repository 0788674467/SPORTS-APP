import requests
import csv
import uuid
import time

TOKEN      = "50f44ab1aefc29b47dad6e51886ae8af7b4efee9"
USERNAME   = "santo_rayern"
FORM_ID    = "aPR8YaaQkXuxNQrx6o9Lr5"
SUBMIT_URL = f"https://kc.kobotoolbox.org/{USERNAME}/submission"

auth_headers = {"Authorization": f"Token {TOKEN}"}

with open("kobo_import_ready.csv") as f:
    data = list(csv.DictReader(f))

print(f"Submitting {len(data)} responses to KoboToolbox...\n")

success = 0
failed  = 0

for i, row in enumerate(data, 1):
    instance_id = f"uuid:{uuid.uuid4()}"

    # Build OpenRosa XML — fields inside groups use group/field nesting
    xml = f"""<?xml version='1.0' ?>
<{FORM_ID} id="{FORM_ID}">
  <sec_a>
    <role>{row["role"]}</role>
    <duration>{row["duration"]}</duration>
    <device>{row["device"]}</device>
  </sec_a>
  <sec_b>
    <b1_fixtures>{row["b1_fixtures"]}</b1_fixtures>
    <b2_results>{row["b2_results"]}</b2_results>
    <b3_standings>{row["b3_standings"]}</b3_standings>
    <b4_players>{row["b4_players"]}</b4_players>
    <b5_comm>{row["b5_comm"]}</b5_comm>
    <b6_efficient>{row["b6_efficient"]}</b6_efficient>
  </sec_b>
  <sec_c>
    <c1_easy>{row["c1_easy"]}</c1_easy>
    <c2_fixture_mgt>{row["c2_fixture_mgt"]}</c2_fixture_mgt>
    <c3_result_mgt>{row["c3_result_mgt"]}</c3_result_mgt>
    <c4_comm_mgt>{row["c4_comm_mgt"]}</c4_comm_mgt>
    <c5_stats>{row["c5_stats"]}</c5_stats>
    <c6_spectator>{row["c6_spectator"]}</c6_spectator>
    <c7_recommend>{row["c7_recommend"]}</c7_recommend>
    <c8_satisfaction>{row["c8_satisfaction"]}</c8_satisfaction>
  </sec_c>
  <sec_d>
    <d1_old_problems>{row["d1_old_problems"]}</d1_old_problems>
    <d2_new_likes>{row["d2_new_likes"]}</d2_new_likes>
    <d3_challenges>{row["d3_challenges"]}</d3_challenges>
    <d4_improvements>{row["d4_improvements"]}</d4_improvements>
  </sec_d>
  <meta>
    <instanceID>{instance_id}</instanceID>
  </meta>
</{FORM_ID}>"""

    files = {"xml_submission_file": ("submission.xml", xml, "text/xml")}
    r = requests.post(SUBMIT_URL, files=files, headers=auth_headers)

    if r.status_code in (200, 201, 202):
        success += 1
        print(f"  [{i:02d}/50] ✅  {row['role']:<12} | B_avg≈{(sum(int(row[f]) for f in ['b1_fixtures','b2_results','b3_standings','b4_players','b5_comm','b6_efficient'])/6):.1f} | C_avg≈{(sum(int(row[f]) for f in ['c1_easy','c2_fixture_mgt','c3_result_mgt','c4_comm_mgt','c5_stats','c6_spectator','c7_recommend','c8_satisfaction'])/8):.1f}")
    else:
        failed += 1
        print(f"  [{i:02d}/50] ❌ FAILED ({r.status_code}): {r.text[:150]}")
        if i == 1:
            print("Stopping on first failure to debug.")
            break

    time.sleep(0.4)

print(f"\n{'='*50}")
print(f"✅ Successfully submitted: {success}/50")
print(f"❌ Failed:                 {failed}/50")
if success > 0:
    print(f"\nCheck your KoboToolbox Data tab — {success} responses should now appear!")
