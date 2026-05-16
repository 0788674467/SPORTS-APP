import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/auth/auth_provider.dart' as auth;
import '../../core/theme/app_theme.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _errorMsg;

  late AnimationController _ballController;
  late Animation<double> _ballBounce;

  @override
  void initState() {
    super.initState();
    _ballController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _ballBounce = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _ballController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _ballController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final authProvider = context.read<auth.AuthProvider>();
    final error = await authProvider.signIn(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _errorMsg = error);
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: isWide ? _buildWideLayout(size) : _buildNarrowLayout(size),
    );
  }

  // ── Wide layout: hero on left, form on right ─────────────────────────────
  Widget _buildWideLayout(Size size) {
    return Row(
      children: [
        // Left: full hero panel
        Expanded(
          child: _buildHeroPanel(size, full: true),
        ),
        // Right: form panel on light background
        Expanded(
          child: Container(
            color: AppColors.background,
            child: Center(child: _buildFormCard(true)),
          ),
        ),
      ],
    );
  }

  // ── Narrow layout: hero header + form below ──────────────────────────────
  Widget _buildNarrowLayout(Size size) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroPanel(size, full: false),
          _buildFormCard(false),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Hero panel — matches spectator dashboard hero exactly ────────────────
  Widget _buildHeroPanel(Size size, {required bool full}) {
    final panelHeight = full ? size.height : (size.height * 0.38).clamp(240.0, 340.0);
    return SizedBox(
      height: panelHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Trophy background
          Image.asset(
            'assets/trophy.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          // Navy gradient overlay — same as spectator hero
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xCC001A4D),
                  Color(0xB3003087),
                  Color(0xD9001A4D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top bar: ball badge + title + back ──────────────
                  Row(
                    children: [
                      Container(
                        width: full ? 72 : 44,
                        height: full ? 72 : 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.mmwNavy,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Image.asset(
                              'assets/images/mmulogo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('MMU SOCCER LEAGUE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: full ? 18 : 12, // Larger on desktop
                                  letterSpacing: full ? 2.5 : 1.5)),
                          Text('2026 Season • Premier Grade',
                              style: TextStyle(
                                  color: AppColors.mmwGold,
                                  fontWeight: FontWeight.w700,
                                  fontSize: full ? 14 : 9, // Larger on desktop
                                  letterSpacing: 1.5)),
                        ],
                      ),
                      const Spacer(),
                      // Back arrow if pushed onto stack
                      if (Navigator.of(context).canPop())
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 100), // Adjusted margin 
                  // ── App logo is now removed from the background centre per request ─────────────────
                  // We already have the logo in the top margin row above.

                  // ── Headline ─────────────────────────────────────────
                  Text(
                    full
                        ? 'Mountains of the\nMoon University'
                        : 'Welcome Back!',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.15),
                  ),
                  const SizedBox(height: 10),
                  // ── Live badge + subtitle ────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.mmwGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('● LIVE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      Text('Season 2026 underway',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Stats row (wide mode only) ────────────────────
                  if (full) ...[
                    Row(
                      children: [
                        _statChip('8', 'Teams'),
                        const SizedBox(width: 10),
                        _statChip('56', 'Matches'),
                        const SizedBox(width: 10),
                        _statChip('120+', 'Players'),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: AppColors.mmwGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                    letterSpacing: 0.5)),
          ],
        ),
      );

  // ── Form card — white card on background ─────────────────────────────────
  Widget _buildFormCard(bool full) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        padding: const EdgeInsets.all(28),
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Centered App Logo + Title (Responsive)
              Center(
                child: Column(
                  children: [
                    Container(
                      width: full ? 80 : 64,
                      height: full ? 80 : 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.mmwNavy,
                        border: Border.all(
                          color: AppColors.mmwGold.withOpacity(0.5),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.mmwNavy.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/images/mmulogo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'UNILEAGUE',
                      style: GoogleFonts.orbitron(
                        fontSize: full ? 26 : 20, // Responsive font size
                        fontWeight: FontWeight.w900,
                        letterSpacing: full ? 4 : 2,
                        color: AppColors.mmwNavy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Error message
              if (_errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF9A9A)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFD32F2F), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_errorMsg!,
                            style: const TextStyle(
                                color: Color(0xFFC62828), fontSize: 13))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // Email field
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: AppColors.textDark, fontSize: 15),
                decoration: _fieldDeco('Email address', Icons.email_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your email';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password field
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                style: const TextStyle(color: AppColors.textDark, fontSize: 15),
                decoration: _fieldDeco('Password', Icons.lock_outline_rounded).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textMid,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your password';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // Sign in button
              _SignInButton(loading: _loading, onTap: _submit),
              const SizedBox(height: 20),

              // Sign up link
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  ),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: AppColors.textMid, fontSize: 14),
                      children: [
                        TextSpan(text: 'New to MMU Soccer? '),
                        TextSpan(
                          text: 'Create account',
                          style: TextStyle(
                            color: AppColors.mmwGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textMid, fontSize: 14),
      prefixIcon:
          Icon(icon, color: AppColors.mmwNavy.withOpacity(0.4), size: 20),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

/// ─── Sign In Button (MMU Navy + Gold shimmer) ────────────────────────────────
class _SignInButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _SignInButton({required this.loading, required this.onTap});
  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _shimmer = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (_, child) => CustomPaint(
          painter: _ShimmerBorderPainter(_shimmer.value),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Material(
            color: AppColors.mmwNavy,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: widget.loading ? null : widget.onTap,
              splashColor: AppColors.mmwGold.withOpacity(0.2),
              child: Center(
                child: widget.loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.login_rounded,
                              size: 20, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Sign In',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerBorderPainter extends CustomPainter {
  final double pos;
  _ShimmerBorderPainter(this.pos);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(13));
    final shader = LinearGradient(
      colors: const [
        AppColors.mmwNavy,
        AppColors.mmwGold,
        AppColors.mmwGreen,
        AppColors.mmwNavy,
      ],
      stops: const [0.0, 0.4, 0.6, 1.0],
      begin: Alignment(-1 + pos * 2, 0),
      end: Alignment(pos * 2, 0),
    ).createShader(rect);

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(_ShimmerBorderPainter old) => old.pos != pos;
}
