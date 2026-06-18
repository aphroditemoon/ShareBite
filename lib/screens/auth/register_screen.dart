import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _obscureConfirm = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    for (var c in [_nameCtrl, _emailCtrl, _phoneCtrl, _passCtrl, _confirmCtrl]) { c.dispose(); }
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text,
      phone: _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text.trim() : null,
    );
    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.error ?? 'Registration failed'),
        backgroundColor: AppTheme.secondary,
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient(),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Create account',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field(_nameCtrl, 'Full name', 'Your name', Icons.person_outline_rounded,
                            validator: (v) => v == null || v.isEmpty ? 'Name is required' : null),
                        const SizedBox(height: 16),
                        _field(_emailCtrl, 'Email address', 'you@email.com', Icons.email_outlined,
                            type: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Email is required';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            }),
                        const SizedBox(height: 16),
                        _field(_phoneCtrl, 'WhatsApp number (optional)', '+62 8xx xxxx xxxx', Icons.phone_outlined, type: TextInputType.phone),
                        const SizedBox(height: 16),
                        _field(_passCtrl, 'Password', 'Min. 6 characters', Icons.lock_outline_rounded,
                            obscure: _obscure,
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppTheme.txtSecondary(context), size: 20),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            validator: (v) => v == null || v.length < 6 ? 'Min. 6 characters' : null),
                        const SizedBox(height: 16),
                        _field(_confirmCtrl, 'Confirm password', 'Repeat your password', Icons.lock_outline_rounded,
                            obscure: _obscureConfirm,
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppTheme.txtSecondary(context), size: 20),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                            validator: (v) => v != _passCtrl.text ? 'Passwords do not match' : null),
                        const SizedBox(height: 32),
                        Consumer<AuthProvider>(
                          builder: (_, auth, __) => SizedBox(
                            width: double.infinity,
                            child: GradientButton(
                              label: 'Create account',
                              isLoading: auth.isLoading,
                              onPressed: auth.isLoading ? null : _register,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have an account? ', style: TextStyle(fontFamily: 'Nunito', color: AppTheme.txtSecondary(context), fontSize: 14, fontWeight: FontWeight.w500)),
                            GestureDetector(
                              onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                              child: Text('Sign in', style: TextStyle(fontFamily: 'Nunito', color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w800)),
                            ),
                          ],
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

  Widget _field(TextEditingController ctrl, String label, String hint, IconData icon,
      {TextInputType? type, bool obscure = false, Widget? suffixIcon, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.txtPrimary(context))),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: type,
          validator: validator,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.txtPrimary(context)),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.txtSecondary(context), size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppTheme.inputFill(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.secondary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
        ),
      ],
    );
  }
}
