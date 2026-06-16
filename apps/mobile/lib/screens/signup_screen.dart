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

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0; // 0: 기본 정보, 1: 계좌 정보, 2: 약관 동의

  final _formKey0 = GlobalKey<FormState>(); // 기본 정보
  final _formKey1 = GlobalKey<FormState>(); // 계좌 정보

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

  late final AnimationController _animCtrl;
  late Animation<Offset> _slideIn;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _updateAnimation();
    _animCtrl.forward(from: 1.0); // start fully visible
  }

  void _updateAnimation() {
    _slideIn = Tween<Offset>(
      begin: Offset(_forward ? 1.0 : -1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _accountNumCtrl.dispose();
    _accountHolderCtrl.dispose();
    super.dispose();
  }

  void _go(int next) {
    _forward = next > _step;
    _updateAnimation();
    setState(() => _step = next);
    _animCtrl.forward(from: 0);
  }

  void _onNext() {
    if (_step == 0) {
      if (!_formKey0.currentState!.validate()) return;
      _go(1);
    } else if (_step == 1) {
      if (!_formKey1.currentState!.validate()) return;
      _go(2);
    } else {
      _signup();
    }
  }

  void _onBack() {
    if (_step == 0) {
      context.go('/login');
    } else {
      _go(_step - 1);
    }
  }

  Future<void> _signup() async {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('네트워크 오류가 발생했습니다. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showTermsDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(content,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
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

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final stepLabels = ['기본 정보', '계좌 정보', '약관 동의'];

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF111827)),
          onPressed: _onBack,
        ),
        title: Text(
          stepLabels[_step],
          style: const TextStyle(
              color: Color(0xFF111827), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: SlideTransition(
                position: _slideIn,
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: _buildCurrentStep(),
                  ),
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // 스텝 인디케이터
  // ─────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            _stepCircle(i),
            if (i < 2) _stepLine(i),
          ],
        ],
      ),
    );
  }

  Widget _stepCircle(int index) {
    final done = index < _step;
    final active = index == _step;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active ? _kBlue : const Color(0xFFE5E7EB),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ['기본 정보', '계좌 정보', '약관 동의'][index],
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? _kBlue : const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _stepLine(int index) {
    final done = index < _step;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: done ? _kBlue : const Color(0xFFE5E7EB),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // 현재 스텝 컨텐츠
  // ─────────────────────────────────────────────────────

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildStep0();
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────────────
  // Step 0: 기본 정보
  // ─────────────────────────────────────────────────────

  Widget _buildStep0() {
    return Form(
      key: _formKey0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
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

  // ─────────────────────────────────────────────────────
  // Step 1: 환불·출금 계좌 정보
  // ─────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoBox(
            icon: Icons.info_outline,
            text: '모임 취소 시 환불 및 방장의 최종 출금에 사용되는 계좌입니다.',
          ),
          const SizedBox(height: 24),
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
                    style:
                        TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.account_balance_outlined,
                      color: Color(0xFF9CA3AF), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: _kBlue, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFEF4444)),
                  ),
                ),
                items: _banks
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedBank = v),
                validator: (v) => v == null ? '은행을 선택해주세요' : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
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

  // ─────────────────────────────────────────────────────
  // Step 2: 약관 동의
  // ─────────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoBox(
          icon: Icons.gavel_outlined,
          text: '서비스 이용을 위해 아래 약관을 확인하고 동의해 주세요.',
        ),
        const SizedBox(height: 20),

        // 전체 동의
        _termsTile(
          label: '전체 동의 (선택 항목 포함)',
          value: _allTerms,
          bold: true,
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _termsService = v;
              _termsPrivacy = v;
              _termsFinance = v;
              _termsThirdParty = v;
              _termsMarketing = v;
            });
          },
        ),

        const Divider(height: 28, color: Color(0xFFE5E7EB)),

        _termsTile(
          label: '[필수] 서비스 이용약관',
          value: _termsService,
          onChanged: (v) => setState(() => _termsService = v ?? false),
          onView: () => _showTermsDialog(
            '서비스 이용약관',
            'Credit-N 서비스 이용에 관한 조건, 모임 생성, 회비 납부 및 에스크로 정산 규칙을 규정합니다.\n\n제1조 (목적) 이 약관은 Credit-N(이하 "서비스")의 이용에 관한 제반 사항을 규정함을 목적으로 합니다.\n\n제2조 (정의) "에스크로"란 제3자가 거래 당사자들 사이의 거래를 보증하는 서비스를 말합니다.',
          ),
        ),
        _termsTile(
          label: '[필수] 개인정보 수집 및 이용 동의',
          value: _termsPrivacy,
          onChanged: (v) => setState(() => _termsPrivacy = v ?? false),
          onView: () => _showTermsDialog(
            '개인정보 수집 및 이용 동의',
            '수집 항목: 이름, 이메일, 휴대폰 번호, 계좌 정보\n수집 목적: 회원 관리, 에스크로 정산, 서비스 제공\n보유 기간: 회원 탈퇴 후 5년\n\n이용자는 동의를 거부할 권리가 있으나, 필수 항목 미동의 시 서비스 이용이 제한될 수 있습니다.',
          ),
        ),
        _termsTile(
          label: '[필수] 전자금융거래 이용약관',
          value: _termsFinance,
          onChanged: (v) => setState(() => _termsFinance = v ?? false),
          onView: () => _showTermsDialog(
            '전자금융거래 이용약관',
            '제1조 (목적) 이 약관은 Credit-N이 제공하는 에스크로 서비스 및 가상계좌 입금 등 전자금융거래에 관한 권리·의무 및 책임 사항을 규정합니다.\n\n제2조 (에스크로) 에스크로 서비스 이용 중 발생하는 환불은 등록된 계좌로 처리됩니다.',
          ),
        ),
        _termsTile(
          label: '[필수] 개인정보 제3자 제공 동의',
          value: _termsThirdParty,
          onChanged: (v) => setState(() => _termsThirdParty = v ?? false),
          onView: () => _showTermsDialog(
            '개인정보 제3자 제공 동의',
            '제공 받는 자: PortOne(포트원) V2 및 연동 PG사\n제공 목적: 가상계좌 발급, 결제 인증, 에스크로 정산 처리\n제공 항목: 이름, 계좌 정보, 전화번호\n보유 기간: 거래 완료 후 5년',
          ),
        ),
        _termsTile(
          label: '[선택] 마케팅 정보 수신 동의',
          value: _termsMarketing,
          optional: true,
          onChanged: (v) => setState(() => _termsMarketing = v ?? false),
          onView: () => _showTermsDialog(
            '마케팅 정보 수신 동의',
            '수신 내용: 신규 기능(결제 혜택 등), 이벤트, 프로모션 안내\n수신 방법: 앱 푸시 알림, 이메일\n\n선택 동의 항목으로 거부하셔도 서비스 이용에 불이익이 없습니다.',
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // 하단 버튼 바
  // ─────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final isLast = _step == 2;
    final label = isLast ? '가입하기' : '다음';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0038CC), _kBlue],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x330052FF),
                      blurRadius: 10,
                      offset: Offset(0, 4)),
                ],
              ),
              child: ElevatedButton(
                onPressed: _loading ? null : _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(label,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
              ),
            ),
          ),
          if (_step == 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('이미 계정이 있으신가요?',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                TextButton(
                  onPressed: () => context.go('/login'),
                  style:
                      TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                  child: const Text('로그인',
                      style: TextStyle(
                          color: _kBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // 공통 위젯
  // ─────────────────────────────────────────────────────

  Widget _infoBox({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kBlue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF374151),
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _termsTile({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
    bool bold = false,
    bool optional = false,
    VoidCallback? onView,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              activeColor: _kBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: bold ? 14 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                color: optional
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF111827),
              ),
            ),
          ),
          if (onView != null)
            GestureDetector(
              onTap: onView,
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
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _kBlue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }
}
