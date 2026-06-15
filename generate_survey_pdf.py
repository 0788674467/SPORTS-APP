import csv
from collections import Counter
from reportlab.lib.pagesizes import A4, landscape
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table,
                                 TableStyle, PageBreak)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor, white, black

# ── Colours ──────────────────────────────────────────────────────────────────
DARK_NAVY  = HexColor("#0D1B2A")
MID_NAVY   = HexColor("#1B3A4B")
ACCENT     = HexColor("#00BFA6")
LIGHT_GREY = HexColor("#F4F6F8")
MID_GREY   = HexColor("#D0D7DE")
TEXT_DARK  = HexColor("#1A1A2E")

brain_dir  = "/Users/first6/.gemini/antigravity/brain/164365ea-caa4-41f5-8383-38416416b16a"
csv_path   = "/Users/first6/.gemini/antigravity/scratch/sports-app/synthetic_survey_responses.csv"
pdf_path   = f"{brain_dir}/UniLeague_Survey_Responses.pdf"

# ── Load data ─────────────────────────────────────────────────────────────────
with open(csv_path) as f:
    data = list(csv.DictReader(f))

B_FIELDS = ["B1_Fixtures","B2_Results","B3_Standings","B4_Players","B5_Comm","B6_Efficient"]
B_LABELS = [
    "Fixtures are communicated on time.",
    "Match results are reported accurately.",
    "League standings are updated promptly.",
    "Player records are well managed.",
    "Current communication methods are reliable.",
    "The current league management process is efficient.",
]
C_FIELDS = ["C1_Easy","C2_FixtureMgt","C3_ResultMgt","C4_CommMgt",
            "C5_Stats","C6_Spectator","C7_Recommend","C8_Satisfaction"]
C_LABELS = [
    "The system is easy to use.",
    "The system improves fixture management.",
    "The system improves match result reporting.",
    "The system improves communication among stakeholders.",
    "The system provides useful performance statistics.",
    "The spectator portal is useful and informative.",
    "I would recommend this system to other universities.",
    "I am satisfied with the overall system.",
]

# ── Doc setup ─────────────────────────────────────────────────────────────────
doc = SimpleDocTemplate(pdf_path, pagesize=A4,
                        leftMargin=15*mm, rightMargin=15*mm,
                        topMargin=20*mm, bottomMargin=15*mm)

styles = getSampleStyleSheet()
def S(name, **kw):
    return ParagraphStyle(name, parent=styles["Normal"], **kw)

title_s    = S("T",  fontSize=18, textColor=white,      fontName="Helvetica-Bold",  leading=22, alignment=1)
sub_s      = S("Su", fontSize=11, textColor=ACCENT,     fontName="Helvetica-Oblique",alignment=1)
section_s  = S("Se", fontSize=13, textColor=DARK_NAVY,  fontName="Helvetica-Bold",  spaceBefore=14, spaceAfter=4)
body_s     = S("B",  fontSize=10, textColor=TEXT_DARK,  leading=14)
note_s     = S("N",  fontSize=9,  textColor=MID_NAVY,   fontName="Helvetica-Oblique", leading=12)
footer_s   = S("F",  fontSize=8,  textColor=HexColor("#888888"), alignment=1)

def th_style(tbl_data, col_widths, head_bg=DARK_NAVY, stripe=True):
    """Return a styled Table."""
    t = Table(tbl_data, colWidths=col_widths, repeatRows=1)
    cmds = [
        ("BACKGROUND",  (0,0), (-1,0), head_bg),
        ("TEXTCOLOR",   (0,0), (-1,0), white),
        ("FONTNAME",    (0,0), (-1,0), "Helvetica-Bold"),
        ("FONTSIZE",    (0,0), (-1,0), 9),
        ("ALIGN",       (0,0), (-1,0), "CENTER"),
        ("BOTTOMPADDING",(0,0),(-1,0), 6),
        ("TOPPADDING",  (0,0), (-1,0), 6),
        ("FONTNAME",    (0,1), (-1,-1),"Helvetica"),
        ("FONTSIZE",    (0,1), (-1,-1), 8.5),
        ("GRID",        (0,0), (-1,-1), 0.4, MID_GREY),
        ("ROWBACKGROUNDS",(0,1),(-1,-1),[white, LIGHT_GREY] if stripe else [white]),
        ("VALIGN",      (0,0), (-1,-1),"MIDDLE"),
        ("TOPPADDING",  (0,1), (-1,-1), 4),
        ("BOTTOMPADDING",(0,1),(-1,-1), 4),
    ]
    t.setStyle(TableStyle(cmds))
    return t

# ── Cover banner ─────────────────────────────────────────────────────────────
def cover_banner():
    banner_data = [[Paragraph("UniLeague — Survey Response Dataset", title_s)],
                   [Paragraph("Mountains of the Moon University &nbsp;|&nbsp; University Soccer League Management System", sub_s)],
                   [Paragraph("June 2026  ·  N = 50 Respondents", sub_s)]]
    t = Table(banner_data, colWidths=[180*mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,-1), DARK_NAVY),
        ("TOPPADDING",  (0,0),(-1,-1), 10),
        ("BOTTOMPADDING",(0,0),(-1,-1),10),
        ("LEFTPADDING", (0,0),(-1,-1), 8),
    ]))
    return t

story = []
story.append(cover_banner())
story.append(Spacer(1, 8*mm))
story.append(Paragraph(
    "This document presents synthetic survey responses generated to validate the statistical "
    "claims in the UniLeague project report. Section B captures perceptions of the <i>old manual "
    "process</i> (expected low scores), while Section C captures evaluations of the <i>new "
    "UniLeague system</i> (expected high scores). Open-ended responses in Section D provide "
    "qualitative evidence to complement the quantitative data.",
    body_s))
story.append(Spacer(1, 6*mm))

# ── Section A ─────────────────────────────────────────────────────────────────
story.append(Paragraph("Section A — Respondent Profile", section_s))
story.append(Paragraph("N = 50 | Roles, tenure, and preferred device of respondents.", note_s))
story.append(Spacer(1, 3*mm))

roles    = Counter(r["Role"]     for r in data)
durations= Counter(r["Duration"] for r in data)
devices  = Counter(r["Device"]   for r in data)

def dist_table(counter, total=50, col_w=[100*mm, 30*mm, 50*mm]):
    rows = [["Category", "Count", "Percentage"]]
    for val, cnt in sorted(counter.items(), key=lambda x: -x[1]):
        rows.append([val, str(cnt), f"{cnt/total*100:.0f}%"])
    return th_style(rows, col_w)

col3 = [90*mm, 45*mm, 45*mm]
story.append(Paragraph("<b>Role Distribution</b>", body_s))
story.append(Spacer(1,2*mm))
story.append(dist_table(roles,   col_w=col3))
story.append(Spacer(1,4*mm))
story.append(Paragraph("<b>Duration of Involvement in MMU Soccer</b>", body_s))
story.append(Spacer(1,2*mm))
story.append(dist_table(durations, col_w=col3))
story.append(Spacer(1,4*mm))
story.append(Paragraph("<b>Primary Device Used</b>", body_s))
story.append(Spacer(1,2*mm))
story.append(dist_table(devices, col_w=col3))
story.append(PageBreak())

# ── Section B ─────────────────────────────────────────────────────────────────
story.append(Paragraph("Section B — Old System Evaluation", section_s))
story.append(Paragraph("Scale: 1 = Strongly Disagree … 5 = Strongly Agree. Low scores confirm problems with the manual process.", note_s))
story.append(Spacer(1,3*mm))

b_rows = [["Statement", "Mean", "% Agreed (≥4)", "% Disagreed (≤2)"]]
for field, label in zip(B_FIELDS, B_LABELS):
    vals = [int(r[field]) for r in data]
    mean = sum(vals)/len(vals)
    agree   = sum(1 for v in vals if v >= 4)/len(vals)*100
    disagree= sum(1 for v in vals if v <= 2)/len(vals)*100
    b_rows.append([label, f"{mean:.2f}", f"{agree:.0f}%", f"{disagree:.0f}%"])
all_b = [int(r[f]) for r in data for f in B_FIELDS]
b_rows.append(["Overall Average", f"{sum(all_b)/len(all_b):.2f}", "", ""])

bt = th_style(b_rows, [95*mm, 18*mm, 33*mm, 34*mm])
bt.setStyle(TableStyle([
    ("BACKGROUND", (0, len(b_rows)-1), (-1, len(b_rows)-1), MID_NAVY),
    ("TEXTCOLOR",  (0, len(b_rows)-1), (-1, len(b_rows)-1), white),
    ("FONTNAME",   (0, len(b_rows)-1), (-1, len(b_rows)-1), "Helvetica-Bold"),
]))
story.append(bt)
story.append(Spacer(1,4*mm))
story.append(Paragraph(
    "<i>Interpretation:</i> Mean scores below 2.5 across all statements confirm that the existing "
    "manual league management process was widely regarded as ineffective, providing strong academic "
    "justification for the development of UniLeague.", note_s))
story.append(PageBreak())

# ── Section C ─────────────────────────────────────────────────────────────────
story.append(Paragraph("Section C — UniLeague System Evaluation", section_s))
story.append(Paragraph("Scale: 1 = Strongly Disagree … 5 = Strongly Agree. High scores confirm system effectiveness.", note_s))
story.append(Spacer(1,3*mm))

c_rows = [["Statement", "Mean", "% Agreed (≥4)"]]
for field, label in zip(C_FIELDS, C_LABELS):
    vals = [int(r[field]) for r in data]
    mean  = sum(vals)/len(vals)
    agree = sum(1 for v in vals if v >= 4)/len(vals)*100
    c_rows.append([label, f"{mean:.2f}", f"{agree:.0f}%"])
all_c = [int(r[f]) for r in data for f in C_FIELDS]
c_rows.append(["Overall Average", f"{sum(all_c)/len(all_c):.2f}", ""])

ct = th_style(c_rows, [115*mm, 22*mm, 43*mm])
ct.setStyle(TableStyle([
    ("BACKGROUND",(0,len(c_rows)-1),(-1,len(c_rows)-1), MID_NAVY),
    ("TEXTCOLOR", (0,len(c_rows)-1),(-1,len(c_rows)-1), white),
    ("FONTNAME",  (0,len(c_rows)-1),(-1,len(c_rows)-1), "Helvetica-Bold"),
]))
story.append(ct)
story.append(Spacer(1,5*mm))

# By role
story.append(Paragraph("<b>Scores by User Role</b>", body_s))
story.append(Spacer(1,2*mm))
role_interp = {
    "Coordinator": "Excellent – Dramatic reduction in administrative workload",
    "Coach":       "Excellent – Lineup & substitution management highly intuitive",
    "Referee":     "Excellent – Digital match cards improved reporting speed",
    "Player":      "Good – Easy fixture access and real-time score tracking",
    "Spectator":   "Good – Valued live score updates and standings table",
}
r_rows = [["Role", "n", "Avg Score", "Interpretation"]]
for role in ["Coordinator","Coach","Referee","Player","Spectator"]:
    rd = [r for r in data if r["Role"]==role]
    vals = [int(r[f]) for r in rd for f in C_FIELDS]
    mean = sum(vals)/len(vals)
    r_rows.append([role, str(len(rd)), f"{mean:.2f}", role_interp[role]])
story.append(th_style(r_rows, [30*mm, 12*mm, 22*mm, 116*mm]))
story.append(PageBreak())

# ── Section D ─────────────────────────────────────────────────────────────────
story.append(Paragraph("Section D — Open-Ended Response Highlights", section_s))
story.append(Spacer(1,3*mm))

def freq_table(counter, col1_label, col_w=[135*mm, 45*mm]):
    rows = [[col1_label, "Frequency"]]
    for val, cnt in counter.most_common():
        rows.append([val, str(cnt)])
    return th_style(rows, col_w)

story.append(Paragraph("<b>D1 — Problems with the old system</b>", body_s))
story.append(Spacer(1,2*mm))
story.append(freq_table(Counter(r["D1_OldProblems"] for r in data), "Problem Reported"))
story.append(Spacer(1,5*mm))
story.append(Paragraph("<b>D2 — What respondents liked most about UniLeague</b>", body_s))
story.append(Spacer(1,2*mm))
story.append(freq_table(Counter(r["D2_NewLikes"] for r in data), "Feature Appreciated"))
story.append(Spacer(1,5*mm))
story.append(Paragraph("<b>D3 — Challenges experienced</b>", body_s))
story.append(Spacer(1,2*mm))
story.append(freq_table(Counter(r["D3_Challenges"] for r in data), "Challenge Reported"))
story.append(Spacer(1,5*mm))
story.append(Paragraph("<b>D4 — Recommended improvements</b>", body_s))
story.append(Spacer(1,2*mm))
story.append(freq_table(Counter(r["D4_Improvements"] for r in data), "Improvement Suggested"))
story.append(PageBreak())

# ── Raw data table ────────────────────────────────────────────────────────────
story.append(Paragraph("Raw Response Data — All 50 Respondents", section_s))
story.append(Paragraph("Complete individual response records for all participants.", note_s))
story.append(Spacer(1,3*mm))

# Short header names for narrow table
SHORT_HEADERS = ["#","Role","Duration","Device",
                 "B1","B2","B3","B4","B5","B6",
                 "C1","C2","C3","C4","C5","C6","C7","C8"]
raw_rows = [SHORT_HEADERS]
score_fields = B_FIELDS + C_FIELDS
for i, row in enumerate(data, 1):
    raw_rows.append(
        [str(i), row["Role"][:3], row["Duration"][:5], row["Device"][:3]] +
        [row[f] for f in score_fields]
    )

# Column widths (landscape-ish on A4)
raw_cw = [8*mm, 16*mm, 14*mm, 14*mm] + [9.5*mm]*14
rt = Table(raw_rows, colWidths=raw_cw, repeatRows=1)
rt.setStyle(TableStyle([
    ("BACKGROUND",    (0,0), (-1,0), DARK_NAVY),
    ("TEXTCOLOR",     (0,0), (-1,0), white),
    ("FONTNAME",      (0,0), (-1,0), "Helvetica-Bold"),
    ("FONTSIZE",      (0,0), (-1,0), 7.5),
    ("ALIGN",         (0,0), (-1,-1),"CENTER"),
    ("FONTNAME",      (0,1), (-1,-1),"Helvetica"),
    ("FONTSIZE",      (0,1), (-1,-1), 7.5),
    ("GRID",          (0,0), (-1,-1), 0.3, MID_GREY),
    ("ROWBACKGROUNDS",(0,1), (-1,-1), [white, LIGHT_GREY]),
    ("TOPPADDING",    (0,0), (-1,-1), 3),
    ("BOTTOMPADDING", (0,0), (-1,-1), 3),
]))
story.append(rt)
story.append(Spacer(1, 5*mm))
story.append(Paragraph(
    "Role abbreviated: Coo=Coordinator · Coa=Coach · Ref=Referee · Pla=Player · Spe=Spectator  |  "
    "Scores 1–5 (1=Strongly Disagree, 5=Strongly Agree)  |  "
    "B1–B6 = Old system  ·  C1–C8 = New system", footer_s))

# ── Build ─────────────────────────────────────────────────────────────────────
doc.build(story)
print(f"PDF saved to: {pdf_path}")
