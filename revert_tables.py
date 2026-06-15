import re

with open('frontend/lib/features/admin/admin_dashboard.dart', 'r') as f:
    content = f.read()

# 1. Revert _buildCoaches horizontal scroll
content = content.replace('''          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sortable header''', '''          // Sortable header''')

content = content.replace('''                  if (coaches.isEmpty)
                    Padding(padding: const EdgeInsets.all(24), child: Text(_searchQuery.isEmpty ? 'No approved coaches.' : 'No coaches match "$_searchQuery".'))
                  else
                    ...coaches.map((c) => _coachRow(c)),
                ],
              ),
            ),
          ),''', '''          if (coaches.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(_searchQuery.isEmpty ? 'No approved coaches.' : 'No coaches match "$_searchQuery".'))
          else
            ...coaches.map((c) => _coachRow(c)),''')

# 2. Revert _buildReferees
content = content.replace('''          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),''', '''          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),''')

content = content.replace('''                  if (referees.isEmpty)
                    Padding(padding: const EdgeInsets.all(24), child: Text(_searchQuery.isEmpty ? 'No approved referees.' : 'No referees match "$_searchQuery".'))
                  else
                    ...referees.map((r) => _refereeRow(r)),
                ],
              ),
            ),
          ),''', '''          if (referees.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(_searchQuery.isEmpty ? 'No approved referees.' : 'No referees match "$_searchQuery".'))
          else
            ...referees.map((r) => _refereeRow(r)),''')

# 3. Revert _buildPlayers
content = content.replace('''          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sortable header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),''', '''          // Sortable header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),''')

content = content.replace('''                  if (players.isEmpty)
                    Padding(padding: const EdgeInsets.all(24), child: Text(_searchQuery.isEmpty ? 'No players found.' : 'No players match "$_searchQuery".'))
                  else
                    ...players.map((p) => _buildPlayerRow(p)),
                ],
              ),
            ),
          ),''', '''          if (players.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(_searchQuery.isEmpty ? 'No players found.' : 'No players match "$_searchQuery".'))
          else
            ...players.map((p) => _buildPlayerRow(p)),''')

# Save reverted
with open('frontend/lib/features/admin/admin_dashboard.dart', 'w') as f:
    f.write(content)

print("Reverted scrolls")
