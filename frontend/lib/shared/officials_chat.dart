import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth/auth_provider.dart' as auth;

// ─── Officials Communication Center ──────────────────────────────────────────
//
// A self-contained real-time DM widget. Drop this into any dashboard.
// Provides:
//   • Conversation list (all partners, last message, unread badge)
//   • Centered compose panel with role-grouped officials dropdown on empty state
//   • Thread view with real-time updates via Supabase Realtime
//
class OfficialsChatWidget extends StatefulWidget {
  const OfficialsChatWidget({super.key});

  @override
  State<OfficialsChatWidget> createState() => _OfficialsChatWidgetState();
}

class _OfficialsChatWidgetState extends State<OfficialsChatWidget> {
  final _client = Supabase.instance.client;

  // ── State ──────────────────────────────────────────────────────────────────
  bool _loadingOfficials = true;
  List<Map<String, dynamic>> _officials = []; // all officials except self
  List<Map<String, dynamic>> _conversations = []; // distinct partners + last msg
  bool _loadingConversations = true;

  // Selected conversation thread
  Map<String, dynamic>? _openedPartner; // the person we're chatting with
  List<Map<String, dynamic>> _messages = [];
  bool _loadingMessages = false;
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSub;

  // New message compose
  Map<String, dynamic>? _selectedNewRecipient;
  bool _showNewMessagePanel = false;

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _sending = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Data Loading ───────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    await Future.wait([_loadOfficials(), _loadConversations()]);
  }

  Future<void> _loadOfficials() async {
    if (!mounted) return;
    final myId = _client.auth.currentUser?.id;
    try {
      final res = await _client
          .from('profiles')
          .select('id, full_name, role, avatar_url, email')
          .inFilter('role', ['admin', 'coach', 'referee'])
          .order('role')
          .order('full_name');

      if (mounted) {
        setState(() {
          _officials = (res as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where((p) => p['id'] != myId)
              .toList();
          _loadingOfficials = false;
        });
      }
    } catch (e) {
      debugPrint('OfficialsChatWidget: error loading officials: $e');
      if (mounted) setState(() => _loadingOfficials = false);
    }
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;
    final myId = _client.auth.currentUser?.id;
    if (myId == null) {
      if (mounted) setState(() => _loadingConversations = false);
      return;
    }
    try {
      // Fetch all messages involving me
      final res = await _client
          .from('official_messages')
          .select('id, sender_id, recipient_id, message, is_read, created_at')
          .or('sender_id.eq.$myId,recipient_id.eq.$myId')
          .order('created_at', ascending: false)
          .limit(200);

      // Build conversation list: group by partner, take latest message
      final Map<String, Map<String, dynamic>> latest = {};
      for (final msg in (res as List<dynamic>)) {
        final m = Map<String, dynamic>.from(msg as Map);
        final partnerId = m['sender_id'] == myId
            ? m['recipient_id'] as String
            : m['sender_id'] as String;
        if (!latest.containsKey(partnerId)) {
          latest[partnerId] = m;
        }
      }

      // Count unread per partner
      final Map<String, int> unread = {};
      for (final msg in (res as List<dynamic>)) {
        final m = Map<String, dynamic>.from(msg as Map);
        if (m['recipient_id'] == myId && m['is_read'] == false) {
          final partnerId = m['sender_id'] as String;
          unread[partnerId] = (unread[partnerId] ?? 0) + 1;
        }
      }

      // Enrich with profile data
      final partnerIds = latest.keys.toList();
      Map<String, Map<String, dynamic>> profiles = {};
      if (partnerIds.isNotEmpty) {
        final profilesRes = await _client
            .from('profiles')
            .select('id, full_name, role, avatar_url')
            .inFilter('id', partnerIds);
        for (final p in (profilesRes as List<dynamic>)) {
          final pMap = Map<String, dynamic>.from(p as Map);
          profiles[pMap['id'] as String] = pMap;
        }
      }

      final convList = partnerIds.map((pid) {
        final lastMsg = latest[pid]!;
        final profile = profiles[pid] ?? {'full_name': 'Unknown', 'role': '', 'avatar_url': null};
        return {
          ...profile,
          'last_message': lastMsg['message'],
          'last_time': lastMsg['created_at'],
          'unread': unread[pid] ?? 0,
        };
      }).toList();

      // Sort by last message time descending
      convList.sort((a, b) {
        final ta = DateTime.tryParse(a['last_time'] as String? ?? '') ?? DateTime(0);
        final tb = DateTime.tryParse(b['last_time'] as String? ?? '') ?? DateTime(0);
        return tb.compareTo(ta);
      });

      if (mounted) {
        setState(() {
          _conversations = convList;
          _loadingConversations = false;
        });
      }
    } catch (e) {
      debugPrint('OfficialsChatWidget: error loading conversations: $e');
      if (mounted) setState(() => _loadingConversations = false);
    }
  }

  void _openThread(Map<String, dynamic> partner) {
    setState(() {
      _openedPartner = partner;
      _messages = [];
      _loadingMessages = true;
      _showNewMessagePanel = false;
    });
    _subscribeToThread(partner['id'] as String);
  }

  void _subscribeToThread(String partnerId) {
    _messagesSub?.cancel();
    final myId = _client.auth.currentUser!.id;

    _messagesSub = _client
        .from('official_messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .listen((data) {
      if (!mounted) return;
      final filtered = data
          .where((m) =>
              (m['sender_id'] == myId && m['recipient_id'] == partnerId) ||
              (m['sender_id'] == partnerId && m['recipient_id'] == myId))
          .toList();
      setState(() {
        _messages = filtered;
        _loadingMessages = false;
      });
      // Mark incoming messages as read
      _markRead(partnerId, myId);
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  Future<void> _markRead(String partnerId, String myId) async {
    try {
      await _client
          .from('official_messages')
          .update({'is_read': true})
          .eq('sender_id', partnerId)
          .eq('recipient_id', myId)
          .eq('is_read', false);
    } catch (_) {}
  }

  Future<void> _sendMessage(String recipientId) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;

    setState(() => _sending = true);
    try {
      await _client.from('official_messages').insert({
        'sender_id': myId,
        'recipient_id': recipientId,
        'message': text,
        'is_read': false,
      });
      _msgCtrl.clear();
      // If we just sent the first message in a new conversation, open the thread
      if (_openedPartner == null || _openedPartner!['id'] != recipientId) {
        final partner = _officials.firstWhere(
          (o) => o['id'] == recipientId,
          orElse: () => {'id': recipientId, 'full_name': 'Official', 'role': '', 'avatar_url': null},
        );
        _openThread(partner);
      }
      await _loadConversations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _closeThread() {
    _messagesSub?.cancel();
    setState(() {
      _openedPartner = null;
      _messages = [];
      _showNewMessagePanel = false;
      _selectedNewRecipient = null;
    });
    _loadConversations();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ap = context.watch<auth.AuthProvider>();
    final myId = ap.user?.id ?? '';

    if (_openedPartner != null) {
      return _buildThreadView(myId);
    }
    return _buildConversationList();
  }

  // ── Conversation List ─────────────────────────────────────────────────────
  Widget _buildConversationList() {
    return Column(children: [
      // ── Header ───────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Communications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Officials only', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
          // New Message Button
          ElevatedButton.icon(
            onPressed: () => setState(() => _showNewMessagePanel = !_showNewMessagePanel),
            icon: Icon(_showNewMessagePanel ? Icons.close_rounded : Icons.edit_rounded, size: 16),
            label: Text(_showNewMessagePanel ? 'Cancel' : 'New Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: 0,
            ),
          ),
        ]),
      ),

      // ── New Message Panel ─────────────────────────────────────────────────
      if (_showNewMessagePanel)
        _buildNewMessagePanel(),

      // ── Conversations ─────────────────────────────────────────────────────
      Expanded(child: _loadingConversations
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (_, i) => _buildConversationTile(_conversations[i]),
                  ),
                )),
    ]);
  }

  Widget _buildNewMessagePanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: const Color(0xFF003087).withOpacity(0.04),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.forum_rounded, size: 16, color: Color(0xFF003087)),
          const SizedBox(width: 6),
          const Text('Select recipient', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF003087))),
        ]),
        const SizedBox(height: 8),
        _loadingOfficials
            ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
            : _officials.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('No other officials found in the system.', style: TextStyle(fontSize: 13))),
                    ]),
                  )
                : _buildOfficialDropdown(),
        // Selected official preview card
        if (_selectedNewRecipient != null) ...[
          const SizedBox(height: 10),
          _buildSelectedOfficialCard(_selectedNewRecipient!),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type your message to ${_selectedNewRecipient!['full_name'] ?? 'official'}…',
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF003087), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(
              sending: _sending,
              onTap: () => _sendMessage(_selectedNewRecipient!['id'] as String),
            ),
          ]),
        ],
      ]),
    );
  }

  /// Role-grouped dropdown of all officials except self
  Widget _buildOfficialDropdown() {
    // Build role-grouped items
    final admins = _officials.where((o) => o['role'] == 'admin').toList();
    final referees = _officials.where((o) => o['role'] == 'referee').toList();
    final coaches = _officials.where((o) => o['role'] == 'coach').toList();

    final List<DropdownMenuItem<Map<String, dynamic>>> items = [];

    void addGroup(String label, Color color, List<Map<String, dynamic>> list) {
      if (list.isEmpty) return;
      // Section header (disabled)
      items.add(DropdownMenuItem(
        enabled: false,
        value: null,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '── $label ──',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
        ),
      ));
      for (final o in list) {
        final name = o['full_name'] as String? ?? 'Unknown';
        final roleColor = _roleColor(o['role'] as String? ?? '');
        final roleLabel = (o['role'] as String?)?.toUpperCase() ?? '';
        items.add(DropdownMenuItem<Map<String, dynamic>>(
          value: o,
          child: Row(children: [
            _officialAvatar(o, radius: 15),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                Text(roleLabel, style: TextStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.w500)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: roleColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(roleLabel, style: TextStyle(fontSize: 9, color: roleColor, fontWeight: FontWeight.bold)),
            ),
          ]),
        ));
      }
    }

    addGroup('ADMIN', const Color(0xFF003087), admins);
    addGroup('REFEREES', Colors.orange.shade700, referees);
    addGroup('COACHES', const Color(0xFF00A651), coaches);

    return DropdownButtonFormField<Map<String, dynamic>>(
      value: _selectedNewRecipient,
      isExpanded: true,
      hint: const Text('Choose an official to message…', style: TextStyle(fontSize: 14, color: Colors.grey)),
      decoration: InputDecoration(
        filled: true, fillColor: Colors.white,
        prefixIcon: const Icon(Icons.person_search_rounded, size: 20, color: Color(0xFF003087)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF003087))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF003087), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: items,
      onChanged: (v) {
        if (v != null) setState(() => _selectedNewRecipient = v);
      },
    );
  }

  /// Small card shown after selecting an official, confirming who you're messaging
  Widget _buildSelectedOfficialCard(Map<String, dynamic> official) {
    final name = official['full_name'] as String? ?? 'Official';
    final role = official['role'] as String? ?? '';
    final roleColor = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: roleColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: roleColor.withOpacity(0.25)),
      ),
      child: Row(children: [
        _officialAvatar(official, radius: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(role.toUpperCase(), style: TextStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ])),
        Icon(Icons.arrow_forward_rounded, size: 14, color: roleColor),
        const SizedBox(width: 4),
        Text('Sending to', style: TextStyle(fontSize: 10, color: roleColor)),
      ]),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> partner) {
    final name = partner['full_name'] as String? ?? 'Unknown';
    final role = partner['role'] as String? ?? '';
    final lastMsg = partner['last_message'] as String? ?? '';
    final unread = partner['unread'] as int? ?? 0;
    final timeStr = _formatTime(partner['last_time'] as String?);

    return InkWell(
      onTap: () => _openThread(partner),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Stack(children: [
            _officialAvatar(partner, radius: 24),
            if (unread > 0)
              Positioned(
                right: 0, top: 0,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: Color(0xFF00A651), shape: BoxShape.circle),
                  child: Center(child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w500, fontSize: 14), overflow: TextOverflow.ellipsis)),
              Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              _rolePill(role),
              const SizedBox(width: 6),
              Expanded(child: Text(lastMsg, style: TextStyle(fontSize: 12, color: unread > 0 ? Colors.black87 : Colors.grey.shade500, fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal), overflow: TextOverflow.ellipsis, maxLines: 1)),
            ]),
          ])),
        ]),
      ),
    );
  }

  // ── Thread View ───────────────────────────────────────────────────────────
  Widget _buildThreadView(String myId) {
    final partner = _openedPartner!;
    final name = partner['full_name'] as String? ?? 'Official';
    final role = partner['role'] as String? ?? '';

    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
        color: Colors.white,
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _closeThread,
          ),
          _officialAvatar(partner, radius: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Row(children: [_rolePill(role)]),
          ])),
        ]),
      ),
      const Divider(height: 1),

      // Messages
      Expanded(
        child: _loadingMessages
            ? const Center(child: CircularProgressIndicator())
            : _messages.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No messages yet.\nSay hello!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                  ]))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildMessageBubble(_messages[i], myId),
                  ),
      ),

      // Input bar
      _buildInputBar(partner['id'] as String),
    ]);
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, String myId) {
    final isMine = msg['sender_id'] == myId;
    final text = msg['message'] as String? ?? '';
    final time = _formatTime(msg['created_at'] as String?);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? const Color(0xFF003087) : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Text(text, style: TextStyle(color: isMine ? Colors.white : Colors.black87, fontSize: 14, height: 1.4)),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg['is_read'] == true ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 12,
                      color: msg['is_read'] == true ? const Color(0xFF00A651) : Colors.grey.shade400,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(String recipientId) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Message…',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true, fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFF003087), width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(sending: _sending, onTap: () => _sendMessage(recipientId)),
        ]),
      ),
    );
  }

  // ── Empty State — Centered Compose Panel ─────────────────────────────────
  Widget _emptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // ── Hero icon + title ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF003087).withOpacity(0.1), const Color(0xFF003087).withOpacity(0.04)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.forum_rounded, size: 48, color: Color(0xFF003087)),
        ),
        const SizedBox(height: 16),
        const Text(
          'Officials Communication Center',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF001A4D)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Send a private message to the admin, a referee,\nor a fellow coach to get started.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5),
        ),
        const SizedBox(height: 28),

        // ── Role legend ────────────────────────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legendBadge('Admin', const Color(0xFF003087)),
          const SizedBox(width: 8),
          _legendBadge('Referee', Colors.orange.shade700),
          const SizedBox(width: 8),
          _legendBadge('Coach', const Color(0xFF00A651)),
        ]),
        const SizedBox(height: 24),

        // ── Compose card ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: const Color(0xFF003087).withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4)),
            ],
            border: Border.all(color: const Color(0xFF003087).withOpacity(0.12)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header row
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF003087).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_rounded, color: Color(0xFF003087), size: 18),
              ),
              const SizedBox(width: 10),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('New Message', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('Select recipient below', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ]),
            const Divider(height: 24),

            // Officials dropdown (role-grouped)
            _loadingOfficials
                ? const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(),
                  ))
                : _officials.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('No other officials found. Make sure admins, referees, and coaches are registered.', style: TextStyle(fontSize: 12))),
                        ]),
                      )
                    : _buildOfficialDropdown(),

            // Selected official preview
            if (_selectedNewRecipient != null) ...[
              const SizedBox(height: 12),
              _buildSelectedOfficialCard(_selectedNewRecipient!),
              const SizedBox(height: 12),
              TextField(
                controller: _msgCtrl,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type your message to ${_selectedNewRecipient!['full_name'] ?? 'the official'}…',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF003087), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : () => _sendMessage(_selectedNewRecipient!['id'] as String),
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_sending ? 'Sending…' : 'Send Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003087),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Choose an official from the dropdown above\nto start a private conversation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400, height: 1.6),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _legendBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _officialAvatar(Map<String, dynamic> official, {double radius = 20}) {
    final url = official['avatar_url'] as String?;
    final name = official['full_name'] as String? ?? '?';
    final role = official['role'] as String? ?? '';
    final color = _roleColor(role);

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: color.withOpacity(0.1),
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(0.15),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: radius * 0.7),
      ),
    );
  }

  Widget _rolePill(String role) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(role.toUpperCase(), style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return const Color(0xFF003087);
      case 'coach': return const Color(0xFF00A651);
      case 'referee': return Colors.orange.shade700;
      default: return Colors.grey;
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (diff.inDays == 1) return 'Yesterday';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}

// ── Send Button ───────────────────────────────────────────────────────────────
class _SendButton extends StatelessWidget {
  final bool sending;
  final VoidCallback onTap;
  const _SendButton({required this.sending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF003087),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: sending ? null : onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: sending
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
