import openpyxl

wb = openpyxl.Workbook()

# Sheet 1: survey
ws_survey = wb.active
ws_survey.title = "survey"

survey_headers = ["type", "name", "label", "appearance", "required"]
ws_survey.append(survey_headers)

survey_data = [
    ["note", "intro", "Mountains of the Moon University\nFaculty of Science, Technology and Innovation\n\nDear Respondent, this questionnaire seeks your views on the current soccer league management process at MMU and your experience with the developed digital system. Your responses will be kept confidential and used for academic purposes only.", "", ""],
    ["begin group", "sec_a", "Section A: Respondent Profile", "field-list", ""],
    ["select_one role", "role", "1. Please indicate your role:", "", "yes"],
    ["select_one duration", "duration", "2. How long have you been involved in MMU soccer activities?", "", "yes"],
    ["select_one device", "device", "3. Which device do you mainly use to access digital services?", "", "yes"],
    ["end group", "", "", "", ""],
    ["begin group", "sec_b", "Section B: Current Process", "", ""],
    ["note", "note_b", "Rate the following statements on a scale of 1 to 5 (1 = Strongly Disagree, 5 = Strongly Agree)", "", ""],
    ["select_one likert", "b1_fixtures", "Fixtures are communicated on time.", "", "yes"],
    ["select_one likert", "b2_results", "Match results are reported accurately.", "", "yes"],
    ["select_one likert", "b3_standings", "League standings are updated promptly.", "", "yes"],
    ["select_one likert", "b4_players", "Player records are well managed.", "", "yes"],
    ["select_one likert", "b5_comm", "Current communication methods are reliable.", "", "yes"],
    ["select_one likert", "b6_efficient", "The current league management process is efficient.", "", "yes"],
    ["end group", "", "", "", ""],
    ["begin group", "sec_c", "Section C: System Evaluation", "", ""],
    ["note", "note_c", "Rate the following statements on a scale of 1 to 5 (1 = Strongly Disagree, 5 = Strongly Agree)", "", ""],
    ["select_one likert", "c1_easy", "The system is easy to use.", "", "yes"],
    ["select_one likert", "c2_fixture_mgt", "The system improves fixture management.", "", "yes"],
    ["select_one likert", "c3_result_mgt", "The system improves match result reporting.", "", "yes"],
    ["select_one likert", "c4_comm_mgt", "The system improves communication among stakeholders.", "", "yes"],
    ["select_one likert", "c5_stats", "The system provides useful performance statistics.", "", "yes"],
    ["select_one likert", "c6_spectator", "The spectator portal is useful and informative.", "", "yes"],
    ["select_one likert", "c7_recommend", "I would recommend this system to other universities.", "", "yes"],
    ["select_one likert", "c8_satisfaction", "I am satisfied with the overall system.", "", "yes"],
    ["end group", "", "", "", ""],
    ["begin group", "sec_d", "Section D: Open-Ended Questions", "", ""],
    ["text", "d1_old_problems", "1. What problem did you experience most in the old soccer league management process?", "multiline", "yes"],
    ["text", "d2_new_likes", "2. What did you like most about the developed UniLeague system?", "multiline", "yes"],
    ["text", "d3_challenges", "3. What challenges did you experience while using the system?", "multiline", "yes"],
    ["text", "d4_improvements", "4. What improvements would you recommend for future versions?", "multiline", "yes"],
    ["end group", "", "", "", ""]
]

for row in survey_data:
    ws_survey.append(row)


# Sheet 2: choices
ws_choices = wb.create_sheet(title="choices")

choices_headers = ["list_name", "name", "label"]
ws_choices.append(choices_headers)

choices_data = [
    ["role", "coordinator", "Coordinator"],
    ["role", "coach", "Coach"],
    ["role", "referee", "Referee"],
    ["role", "player", "Player"],
    ["role", "spectator", "Spectator"],
    ["duration", "less_1", "Less than 1 year"],
    ["duration", "1_to_2", "1-2 years"],
    ["duration", "3_to_5", "3-5 years"],
    ["duration", "over_5", "More than 5 years"],
    ["device", "smartphone", "Smartphone"],
    ["device", "laptop", "Laptop"],
    ["device", "desktop", "Desktop"],
    ["device", "tablet", "Tablet"],
    ["likert", "1", "1 - Strongly Disagree"],
    ["likert", "2", "2 - Disagree"],
    ["likert", "3", "3 - Neutral"],
    ["likert", "4", "4 - Agree"],
    ["likert", "5", "5 - Strongly Agree"]
]

for row in choices_data:
    ws_choices.append(row)

# Save the workbook
output_path = "/Users/first6/.gemini/antigravity/scratch/sports-app/UniLeague_Questionnaire.xlsx"
wb.save(output_path)
print(f"XLSX file generated at: {output_path}")
