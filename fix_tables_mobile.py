with open('frontend/lib/features/admin/admin_dashboard.dart', 'r') as f:
    content = f.read()

# 1. _buildCoaches
content = content.replace('''  Widget _buildCoaches() {
    if (_isLoadingManagement) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));''', '''  Widget _buildCoaches() {
    if (_isLoadingManagement) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));
    final isMobile = ResponsiveWrapper.isMobile(context);''')

content = content.replace('''              Expanded(flex: 2, child: _sortableColHeader('Email', 'email', _coachesSortCol, _coachesSortAsc, () => toggleSort('email'))),
              Expanded(flex: 2, child: _sortableColHeader('Team', 'team', _coachesSortCol, _coachesSortAsc, () => toggleSort('team'))),''', '''              if (!isMobile) Expanded(flex: 2, child: _sortableColHeader('Email', 'email', _coachesSortCol, _coachesSortAsc, () => toggleSort('email'))),
              if (!isMobile) Expanded(flex: 2, child: _sortableColHeader('Team', 'team', _coachesSortCol, _coachesSortAsc, () => toggleSort('team'))),''')

# 2. _coachRow
content = content.replace('''  Widget _coachRow(Map<String, dynamic> c) {
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);''', '''  Widget _coachRow(Map<String, dynamic> c) {
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);
    final isMobile = ResponsiveWrapper.isMobile(context);''')

content = content.replace('''        // Email
        Expanded(flex: 2, child: Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)),
        // Team
        Expanded(flex: 2, child: Text(team, style: const TextStyle(fontSize: 12))),''', '''        // Email
        if (!isMobile) Expanded(flex: 2, child: Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)),
        // Team
        if (!isMobile) Expanded(flex: 2, child: Text(team, style: const TextStyle(fontSize: 12))),''')


# 3. _buildReferees
content = content.replace('''  Widget _buildReferees() {
    if (_isLoadingManagement) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));''', '''  Widget _buildReferees() {
    if (_isLoadingManagement) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));
    final isMobile = ResponsiveWrapper.isMobile(context);''')

content = content.replace('''              Expanded(flex: 2, child: _sortableColHeader('Email', 'email', _refereesSortCol, _refereesSortAsc, () => toggleSort('email'))),
              Expanded(flex: 2, child: _sortableColHeader('Phone', 'phone', _refereesSortCol, _refereesSortAsc, () => toggleSort('phone'))),''', '''              if (!isMobile) Expanded(flex: 2, child: _sortableColHeader('Email', 'email', _refereesSortCol, _refereesSortAsc, () => toggleSort('email'))),
              if (!isMobile) Expanded(flex: 2, child: _sortableColHeader('Phone', 'phone', _refereesSortCol, _refereesSortAsc, () => toggleSort('phone'))),''')

# 4. _refereeRow
content = content.replace('''  Widget _refereeRow(Map<String, dynamic> r) {
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);''', '''  Widget _refereeRow(Map<String, dynamic> r) {
    final ap = Provider.of<auth.AuthProvider>(context, listen: false);
    final isMobile = ResponsiveWrapper.isMobile(context);''')

content = content.replace('''        // Email
        Expanded(flex: 2, child: Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)),
        // Phone
        Expanded(flex: 2, child: Text(phone, style: const TextStyle(fontSize: 12))),''', '''        // Email
        if (!isMobile) Expanded(flex: 2, child: Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)),
        // Phone
        if (!isMobile) Expanded(flex: 2, child: Text(phone, style: const TextStyle(fontSize: 12))),''')

# 5. _buildPlayers
content = content.replace('''  Widget _buildPlayers() {
    if (_isLoadingManagement) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));''', '''  Widget _buildPlayers() {
    if (_isLoadingManagement) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A651)));
    final isMobile = ResponsiveWrapper.isMobile(context);''')

content = content.replace('''              Expanded(flex: 2, child: _sortableColHeader('Team', 'team', _playersSortCol, _playersSortAsc, () => toggleSort('team'))),
              SizedBox(width: 70, child: _sortableColHeader('Position', 'position', _playersSortCol, _playersSortAsc, () => toggleSort('position'))),''', '''              if (!isMobile) Expanded(flex: 2, child: _sortableColHeader('Team', 'team', _playersSortCol, _playersSortAsc, () => toggleSort('team'))),
              if (!isMobile) SizedBox(width: 70, child: _sortableColHeader('Position', 'position', _playersSortCol, _playersSortAsc, () => toggleSort('position'))),''')

# 6. _buildPlayerRow
content = content.replace('''  Widget _buildPlayerRow(Map<String, dynamic> player) {
    final name = player['full_name'] ?? 'Unknown';''', '''  Widget _buildPlayerRow(Map<String, dynamic> player) {
    final isMobile = ResponsiveWrapper.isMobile(context);
    final name = player['full_name'] ?? 'Unknown';''')

content = content.replace('''        // Team
        Expanded(
          flex: 2,
          child: Text(teamName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        // Position badge
        SizedBox(
          width: 60,
          child: Center(child: _posBadge(position)),
        ),''', '''        // Team
        if (!isMobile) Expanded(
          flex: 2,
          child: Text(teamName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        // Position badge
        if (!isMobile) SizedBox(
          width: 60,
          child: Center(child: _posBadge(position)),
        ),''')


with open('frontend/lib/features/admin/admin_dashboard.dart', 'w') as f:
    f.write(content)

print("Applied mobile conditionally hiding logic")
