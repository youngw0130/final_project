import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

const _kBlue = Color(0xFF0052FF);
const _kBg = Color(0xFFF0F4FF);

const _banks = [
  '국민은행', '신한은행', '우리은행', '하나은행', '농협은행',
  '기업은행', '카카오뱅크', '토스뱅크', 'SC제일은행', '씨티은행',
];

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // 기본 정보
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _obscure = true;

  // 계좌 정보
  String? _selectedBank;
  final _accountNumCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();

  // 약관 동의
  bool _termsService = false;
  bool _termsPrivacy = false;
  bool _termsFinance = false;
  bool _termsThirdParty = false;
  bool _termsMarketing = false;

  bool _loading = false;

  bool get _allRequired =>
      _termsService && _termsPrivacy && _termsFinance && _termsThirdParty;

  bool get _allTerms => _allRequired && _termsMarketing;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _accountNumCtrl.dispose();
    _accountHolderCtrl.dispose();
    super.dispose();
  }

  void _toggleAll(bool? value) {
    if (value == null) return;
    setState(() {
      _termsService = value;
      _termsPrivacy = value;
      _termsFinance = value;
      _termsThirdParty = value;
      _termsMarketing = value;
    });
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_allRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 약관에 모두 동의해 주세요.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().signup(
            username: _usernameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            realName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
            phoneNumber: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            refundBank: _selectedBank,
            refundAccountNumber: _accountNumCtrl.text.trim().isNotEmpty
                ? _accountNumCtrl.text.trim()
                : null,
            refundAccountHolder: _accountHolderCtrl.text.trim().isNotEmpty
                ? _accountHolderCtrl.text.trim()
                : null,
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

  void _showTermsDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(content, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인', style: TextStyle(color: _kBlue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF111827)),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('회원가입',
            style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBasicInfoCard(),
                const SizedBox(height: 16),
                _buildAccountCard(),
                const SizedBox(height: 16),
                _buildTermsCard(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
                const SizedBox(height: 16),
                _buildLoginLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────── Card 1: 기본 정보 ────────────────

  Widget _buildBasicInfoCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.person_outline, '기본 정보'),
          const SizedBox(height: 20),
          _buildField(
            controller: _usernameCtrl,
            label: '아이디 *',
            hint: '영문, 숫자 조합 (3자 이상)',
            icon: Icons.badge_outlined,
            validator: (v) {
              if (v == null || v.isEmpty) return '아이디를 입력해주세요';
              if (v.length < 3) return '3자 이상 입력해주세요';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _emailCtrl,
            label: '이메일 *',
            hint: 'example@email.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return '이메일을 입력해주세요';
              if (!v.contains('@')) return '올바른 이메일 형식이 아닙니다';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _passwordCtrl,
            label: '비밀번호 *',
            hint: '8자 이상',
            icon: Icons.lock_outline,
            obscure: _obscure,
            suffix: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF9CA3AF),
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return '비밀번호를 입력해주세요';
              if (v.length < 8) return '8자 이상 입력해주세요';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _nameCtrl,
            label: '이름 (실명) *',
            hint: '홍길동',
            icon: Icons.person_outline,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '이름을 입력해주세요';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _phoneCtrl,
            label: '휴대폰 번호 *',
            hint: '010-0000-0000',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '휴대폰 번호를 입력해주세요';
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ──────────────── Card 2: 환불 계좌 정보 ────────────────

  Widget _buildAccountCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.account_balance_outlined, '환불 · 출금 계좌 정보'),
          const SizedBox(height: 4),
          const Text(
            '모임 취소 시 환불 및 회비 출금에 사용됩니다.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('은행 *',
                  style: TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedBank,
                hint: const Text('은행 선택',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.account_balance_outlined,
                      color: Color(0xFF9CA3AF), size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kBlue, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFEF4444)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: _banks
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedBank = v),
                validator: (v) => v == null ? '은행을 선택해주세요' : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _accountNumCtrl,
            label: '계좌번호 *',
            hint: '숫자만 입력',
            icon: Icons.credit_card_outlined,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '계좌번호를 입력해주세요';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _accountHolderCtrl,
            label: '예금주명 *',
            hint: '홍길동',
            icon: Icons.person_pin_outlined,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '예금주명을 입력해주세요';
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ──────────────── Card 3: 약관 동의 ────────────────

  Widget _buildTermsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.gavel_outlined, '약관 동의'),
          const SizedBox(height: 12),
          _buildAllAgreeRow(),
          const Divider(height: 24, color: Color(0xFFE5E7EB)),
          _buildTermsRow(
            label: '[필수] 서비스 이용약관',
            value: _termsService,
            onChanged: (v) => setState(() => _termsService = v ?? false),
            termsTitle: '서비스 이용약관',
            termsContent:
                'Credit-N 서비스 이용에 관한 조건, 모임 생성, 회비 납부 및 에스크로 정산 규칙을 규정합니다.\n\n제1조 (목적) 이 약관은 Credit-N(이하 "서비스")의 이용에 관한 제반 사항을 규정함을 목적으로 합니다.\n\n제2조 (정의) "에스크로"란 제3자가 거래 당사자들 사이의 거래를 보증하는 서비스를 말합니다.\n\n제3조 (서비스 이용) 이용자는 본 약관에 동의함으로써 서비스를 이용할 수 있습니다.',
          ),
          _buildTermsRow(
            label: '[필수] 개인정보 수집 및 이용 동의',
            value: _termsPrivacy,
            onChanged: (v) => setState(() => _termsPrivacy = v ?? false),
            termsTitle: '개인정보 수집 및 이용 동의',
            termsContent:
                '수집 항목: 이름, 이메일, 휴대폰 번호, 계좌 정보\n수집 목적: 회원 관리, 에스크로 정산, 서비스 제공\n보유 기간: 회원 탈퇴 후 5년\n\n이용자는 동의를 거부할 권리가 있으나, 필수 항목 미동의 시 서비스 이용이 제한될 수 있습니다.',
          ),
          _buildTermsRow(
            label: '[필수] 전자금융거래 이용약관',
            value: _termsFinance,
            onChanged: (v) => setState(() => _termsFinance = v ?? false),
            termsTitle: '전자금융거래 이용약관',
            termsContent:
                '제1조 (목적) 이 약관은 Credit-N이 제공하는 에스크로 서비스 및 가상계좌 입금 등 전자금융거래에 관한 권리·의무 및 책임 사항을 규정합니다.\n\n제2조 (에스크로) 에스크로 서비스 이용 중 발생하는 환불은 등록된 계좌로 처리됩니다.\n\n제3조 (책임 한계) 이용자의 부주의로 인한 손해는 서비스 제공자가 책임지지 않습니다.',
          ),
          _buildTermsRow(
            label: '[필수] 개인정보 제3자 제공 동의',
            value: _termsThirdParty,
            onChanged: (v) => setState(() => _termsThirdParty = v ?? false),
            termsTitle: '개인정보 제3자 제공 동의',
            termsContent:
                '제공 받는 자: PortOne(포트원) V2 및 연동 PG사\n제공 목적: 가상계좌 발급, 결제 인증, 에스크로 정산 처리\n제공 항목: 이름, 계좌 정보, 전화번호\n보유 기간: 거래 완료 후 5년\n\n이용자는 동의를 거부할 수 있으나, 미동의 시 결제 서비스 이용이 불가합니다.',
          ),
          _buildTermsRow(
            label: '[선택] 마케팅 정보 수신 동의',
            value: _termsMarketing,
            onChanged: (v) => setState(() => _termsMarketing = v ?? false),
            termsTitle: '마케팅 정보 수신 동의',
            termsContent:
                '수신 내용: 신규 기능(결제 혜택 등), 이벤트, 프로모션 안내\n수신 방법: 앱 푸시 알림, 이메일\n\n선택 동의 항목으로 거부하셔도 서비스 이용에 불이익이 없습니다. 동의 후에도 마이페이지에서 철회할 수 있습니다.',
            optional: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAllAgreeRow() {
    return GestureDetector(
      onTap: () => _toggleAll(!_allTerms),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: _allTerms,
              tristate: false,
              activeColor: _kBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: _toggleAll,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            '전체 동의 (선택 항목 포함)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsRow({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String termsTitle,
    required String termsContent,
    bool optional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              activeColor: _kBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: optional ? const Color(0xFF6B7280) : const Color(0xFF374151),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _showTermsDialog(termsTitle, termsContent),
            child: const Text(
              '보기',
              style: TextStyle(
                fontSize: 12,
                color: _kBlue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── 공통 위젯 ────────────────

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0038CC), _kBlue],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x330052FF), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: ElevatedButton(
          onPressed: _loading ? null : _signup,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('가입하기',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('이미 계정이 있으신가요?',
            style: TextStyle(color: Color(0xFF6B7280))),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('로그인',
              style: TextStyle(
                  color: _kBlue, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A0052FF), blurRadius: 24, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _cardHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _kBlue, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: Color(0xFF111827)),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon:
                Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBlue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }
}
