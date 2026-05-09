import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart' as auth;
import '../../core/theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1
  Uint8List? _profileImage;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _teamCtrl = TextEditingController(); // Coach team name

  // Step 2
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  // Step 3
  String _selectedRole = 'spectator';
  // shown when coach is selected

  bool _loading = false;
  String? _errorMsg;
  bool _success = false;

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  static const _roles = [
    {'value': 'coach', 'label': 'Coach', 'icon': Icons.sports, 'desc': 'Manage team & lineups', 'color': 0xFF1B5E20},
    {'value': 'referee', 'label': 'Referee', 'icon': Icons.sports_handball, 'desc': 'Officiate matches', 'color': 0xFF1A237E},
    {'value': 'spectator', 'label': 'Spectator / Fan', 'icon': Icons.people_outline, 'desc': 'Follow the action', 'color': 0xFF4A148C},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _profileImage = bytes);
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!(_step1Key.currentState?.validate() ?? false)) return;
    } else if (_currentStep == 1) {
      if (!(_step2Key.currentState?.validate() ?? false)) return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _errorMsg = null; });

    final authProvider = context.read<auth.AuthProvider>();
    final error = await authProvider.signUp(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
      _nameCtrl.text.trim(),
      _selectedRole,
      phone: _phoneCtrl.text.trim(),
      teamName: _selectedRole == 'coach' ? _teamCtrl.text.trim() : null,
      profileImage: _profileImage,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (error != null) _errorMsg = error;
      else _success = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _success
            ? _buildSuccess()
            : Column(
                children: [
                  _buildTopBar(),
                  _buildStepIndicator(),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStep1(),
                        _buildStep2(),
                        _buildStep3(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: AppColors.mmwNavy,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: _currentStep == 0 ? () => Navigator.pop(context) : _prevStep,
          ),
          // ball.jpeg badge — matches spectator header
          Image.asset(
            'assets/images/logo.png',
            height: 32,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('MMU SOCCER LEAGUE',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                Text('Join the 2026 Season',
                    style: TextStyle(
                        color: AppColors.mmwGold,
                        fontWeight: FontWeight.w700,
                        fontSize: 8)),
              ],
            ),
          ),
          const Icon(Icons.sports_soccer, color: AppColors.mmwGold, size: 24),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: AppColors.mmwNavy,
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 14),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? AppColors.mmwGreen
                        : (isActive ? AppColors.mmwGold : Colors.white24),
                    border: isActive
                        ? Border.all(color: AppColors.mmwGold, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                        : Text('${i + 1}', style: TextStyle(
                            color: isActive ? AppColors.mmwNavy : Colors.white54,
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                if (i < 2) Expanded(
                  child: Container(
                    height: 2,
                    color: i < _currentStep
                        ? AppColors.mmwGreen
                        : Colors.white24,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.mmwNavy.withOpacity(0.08),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildStep1() {
    return _buildCard(
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.mmwNavy)),
            const SizedBox(height: 4),
            Text('Let people know who you are', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),

            // Photo picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.mmwNavy.withOpacity(0.08),
                      backgroundImage: _profileImage != null ? MemoryImage(_profileImage!) : null,
                      child: _profileImage == null
                          ? Icon(Icons.person_rounded, size: 52, color: AppColors.mmwNavy.withOpacity(0.4))
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.mmwNavy,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text('Tap to add photo', style: TextStyle(color: Colors.grey.shade500, fontSize: 12))),
            const SizedBox(height: 24),

            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.textDark, fontSize: 15),
              decoration: _fieldDeco('Full Name', Icons.person_outline),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.textDark, fontSize: 15),
              decoration: _fieldDeco('Phone Number', Icons.phone_outlined),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your phone number' : null,
            ),
            const SizedBox(height: 28),

            _nextBtn('Continue →'),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return _buildCard(
      child: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.mmwNavy)),
            const SizedBox(height: 4),
            Text('Create your login credentials', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),

            if (_errorMsg != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                child: Row(children: [
                  Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMsg!, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.textDark, fontSize: 15),
              decoration: _fieldDeco('Email address', Icons.email_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your email';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              style: const TextStyle(color: AppColors.textDark, fontSize: 15),
              decoration: _fieldDeco('Password', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey.shade500, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              style: const TextStyle(color: AppColors.textDark, fontSize: 15),
              decoration: _fieldDeco('Confirm Password', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey.shade500, size: 20),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) => v != _passwordCtrl.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 28),

            _nextBtn('Continue →'),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sports_soccer, size: 28, color: AppColors.mmwNavy),
              SizedBox(width: 10),
              const Text('Your Role', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.mmwNavy)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Select how you participate in MMU Soccer', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 24),

          ...(_roles.map((role) {
            final isSelected = _selectedRole == role['value'];
            final color = Color(role['color'] as int);
            return GestureDetector(
              onTap: () => setState(() => _selectedRole = role['value'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.08) : Colors.grey.shade50,
                  border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: isSelected ? 2 : 1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? color : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(role['icon'] as IconData, size: 20, color: isSelected ? Colors.white : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(role['label'] as String, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? color : Colors.black87)),
                        Text(role['desc'] as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                    const Spacer(),
                    if (isSelected) Icon(Icons.check_circle_rounded, color: color, size: 22),
                  ],
                ),
              ),
            );
          })),

          // Team name field – only for coaches
          if (_selectedRole == 'coach') ...[
            const SizedBox(height: 4),
            TextField(
              controller: _teamCtrl,
              style: const TextStyle(color: AppColors.textDark, fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Team Name (the team you coach)',
                hintText: 'e.g. Lions FC',
                prefixIcon: const Icon(Icons.shield_rounded, size: 18),
                filled: true, fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.mmwNavy, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_selectedRole == 'coach' || _selectedRole == 'referee')
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, color: Colors.amber.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Coach & Referee accounts require admin approval before access is granted.', style: TextStyle(color: Colors.amber.shade800, fontSize: 12))),
              ]),
            ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mmwNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.emoji_events_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final isPending = _selectedRole == 'coach' || _selectedRole == 'referee';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.mmwNavy.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(isPending ? Icons.pending_actions_rounded : Icons.check_circle_outline_rounded,
                  size: 72, color: AppColors.mmwNavy),
            ),
            const SizedBox(height: 28),
            Text(
              isPending ? 'Application Submitted! ✅' : 'Welcome to MMU Soccer! ⚽',
              style: const TextStyle(color: AppColors.mmwNavy, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.mmwNavy.withOpacity(0.06), borderRadius: BorderRadius.circular(16)),
              child: Text(
                isPending
                    ? 'Your account is pending admin approval. You\'ll receive access once the MMU Soccer admin reviews your registration.'
                    : 'Your account has been created. Please verify your email then sign in.',
                style: const TextStyle(color: AppColors.textDark, fontSize: 14, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mmwNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back to Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nextBtn(String label) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _nextStep,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mmwNavy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }

  InputDecoration _fieldDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textMid),
      prefixIcon: Icon(icon, color: AppColors.mmwNavy.withOpacity(0.4), size: 20),
      filled: true,
      fillColor: AppColors.cardBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.mmwNavy, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ─── Field Painter removed — using background image instead ──────────────────

