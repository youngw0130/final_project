import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().login(
            _usernameCtrl.text.trim(),
            _passwordCtrl.text,
          );
      if (mounted) context.go('/dashboard');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                const Text(
                  'Credit-N',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1),
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '신뢰 기반 그룹 정산 서비스',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
                const SizedBox(height: 56),
                _buildField(
                  controller: _usernameCtrl,
                  label: '아이디',
                  hint: 'username',
                  icon: Icons.person_outline,
                  validator: (v) =>
                      v == null || v.isEmpty ? '아이디를 입력해주세요' : null,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _passwordCtrl,
                  label: '비밀번호',
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? '비밀번호를 입력해주세요' : null,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('로그인',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('계정이 없으신가요?',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      child: const Text('회원가입',
                          style: TextStyle(color: Color(0xFF6366F1))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF475569)),
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1)),
            ),
          ),
        ),
      ],
    );
  }
}
