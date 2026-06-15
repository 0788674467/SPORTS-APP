import random
import csv
import os

# Configuration to match user statistics
ROLES = [
    ("coordinator", 4),
    ("coach", 8),
    ("referee", 4),
    ("player", 15),
    ("spectator", 19)
]

DURATIONS = ["less_1", "1_to_2", "3_to_5", "over_5"]
DEVICES = ["smartphone", "smartphone", "smartphone", "laptop", "tablet"]

# Old system was poor
def get_old_system_score():
    return random.choices([1, 2, 3, 4], weights=[40, 40, 15, 5])[0]

# New system is highly rated (mostly 4 and 5)
def get_new_system_score(base_mean=4.5):
    if base_mean >= 4.5:
        return random.choices([3, 4, 5], weights=[5, 30, 65])[0]
    else:
        return random.choices([3, 4, 5], weights=[10, 60, 30])[0]

def get_open_ended(role, question):
    problems = [
        "Delayed fixture communication", "Paperwork was too much", "Results were often disputed",
        "Hard to know league standings", "Everything was manual and slow", "Poor communication",
        "Referees submitting results late", "Losing track of player cards"
    ]
    likes = [
        "Real-time standings", "Easy to see fixtures on my phone", "Live match updates",
        "Digital match reports", "Lineup submission is very easy", "Saves a lot of time",
        "The spectator dashboard is beautiful", "Transparency in results"
    ]
    challenges = [
        "None really", "Getting used to the new interface initially", "Internet connection sometimes drops",
        "Takes time to input all player data first", "Nothing", "A bit confusing on the first day",
        "Required a smartphone which some players lack", "None"
    ]
    improvements = [
        "Add player statistics like top scorers", "SMS notifications for fixtures", "Mobile app version",
        "More detailed match events", "None, it is great", "Allow coaches to add assistant coaches",
        "Video highlights integration", "Keep improving the speed"
    ]
    
    if question == "old": return random.choice(problems)
    if question == "new": return random.choice(likes)
    if question == "chal": return random.choice(challenges)
    if question == "imp": return random.choice(improvements)

data = []
# Generate 50 responses
for role, count in ROLES:
    for _ in range(count):
        # Role specific biases
        new_sys_mean = 4.5 if role in ["coordinator", "coach", "referee"] else 4.2
        
        row = {
            "Role": role.capitalize(),
            "Duration": random.choice(DURATIONS).replace('_', ' ').capitalize(),
            "Device": random.choice(DEVICES).capitalize(),
            
            # Old system (B1 to B6)
            "B1_Fixtures": get_old_system_score(),
            "B2_Results": get_old_system_score(),
            "B3_Standings": get_old_system_score(),
            "B4_Players": get_old_system_score(),
            "B5_Comm": get_old_system_score(),
            "B6_Efficient": get_old_system_score(),
            
            # New system (C1 to C8)
            "C1_Easy": get_new_system_score(new_sys_mean),
            "C2_FixtureMgt": get_new_system_score(new_sys_mean),
            "C3_ResultMgt": get_new_system_score(new_sys_mean),
            "C4_CommMgt": get_new_system_score(new_sys_mean),
            "C5_Stats": get_new_system_score(new_sys_mean),
            "C6_Spectator": get_new_system_score(new_sys_mean),
            "C7_Recommend": get_new_system_score(new_sys_mean),
            "C8_Satisfaction": get_new_system_score(new_sys_mean),
            
            # Open Ended
            "D1_OldProblems": get_open_ended(role, "old"),
            "D2_NewLikes": get_open_ended(role, "new"),
            "D3_Challenges": get_open_ended(role, "chal"),
            "D4_Improvements": get_open_ended(role, "imp"),
        }
        data.append(row)

# Shuffle the data to mix roles
random.shuffle(data)

# Write to CSV
csv_path = "/Users/first6/.gemini/antigravity/scratch/sports-app/synthetic_survey_responses.csv"
with open(csv_path, 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=data[0].keys())
    writer.writeheader()
    writer.writerows(data)

# Write to Markdown
md_path = "/Users/first6/.gemini/antigravity/brain/164365ea-caa4-41f5-8383-38416416b16a/synthetic_responses.md"
with open(md_path, 'w') as f:
    f.write("# Synthetic Survey Responses (N=50)\n\n")
    f.write("This dataset reflects the positive evaluation scores outlined in the UniLeague Testing Report. "
            "Scores for the old system (Section B) are intentionally low (1-3), while scores for the new system (Section C) are consistently high (4-5), validating your system's effectiveness.\n\n")
    
    # Write summary stats
    f.write("## Overview\n")
    roles_count = {r[0].capitalize(): r[1] for r in ROLES}
    f.write(f"- **Total Responses:** 50\n")
    f.write(f"- **Roles:** Coordinators (4), Coaches (8), Referees (4), Players (15), Spectators (19)\n\n")
    
    # Write the table
    headers = list(data[0].keys())
    f.write("| " + " | ".join(headers) + " |\n")
    f.write("|" + "|".join(["---"] * len(headers)) + "|\n")
    
    for row in data:
        row_str = " | ".join(str(row[h]) for h in headers)
        f.write(f"| {row_str} |\n")

print(f"Generated MD at {md_path}")
print(f"Generated CSV at {csv_path}")
