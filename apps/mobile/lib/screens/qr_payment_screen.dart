import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/moim_response.dart';
import '../providers/moim_provider.dart';
import '../services/api_client.dart';

class QrPaymentScreen extends StatefulWidget {
  final int moimId;
  const QrPaymentScreen({super.key, required this.moimId});

  @override
  State<QrPaymentScreen> createState() => _QrPaymentScreenState();
}

class _QrPaymentScreenState extends State<QrPaymentScreen>
    with TickerProviderStateMixin {
  final _fmt = NumberFormat('#,###');

  static const _totalSecs = 180;
  int _remaining = 179;
  Timer? _timer;
  List<int> _authCode = [];
  late AnimationController _scanLineCtrl;

  @override
  void initState() {
    super.initState();
    _authCode = _newCode();
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MoimProvider>().loadMoim(widget.moimId);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scanLineCtrl.dispose();
    super.dispose();
  }

  List<int> _newCode() =>
      List.generate(6, (_) => math.Random().nextInt(10));

  void _startTimer() {
    _timer?.cancel();
    _remaining = 179;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_remaining > 0) {
          _remaining--;
        } else {
          _refreshCode();
        }
      });
    });
  }

  void _refreshCode() {
    setState(() {
      _authCode = _newCode();
    });
    _startTimer();
  }

  double get _timerProgress => _remaining / _totalSecs;

  Color get _timerColor {
    if (_remaining > 90) return const Color(0xFF4ADE80);
    if (_remaining > 45) return const Color(0xFFFCD34D);
    return const Color(0xFFF87171);
  }

  String get _timerText {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final moimProv = context.watch<MoimProvider>();
    final moim = moimProv.selectedMoim;

    return Scaffold(
      backgroundColor: const Color(0xFF050C1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(moim),
            if (moim != null) _buildMoimInfoCard(moim),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    _buildQrCard(),
                    const SizedBox(height: 12),
                    _buildTimerCard(),
                    const SizedBox(height: 10),
                    _buildActionButtons(),
                    const SizedBox(height: 10),
                    _buildGuideHint(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(MoimResponse? moim) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const Expanded(
            child: Column(
              children: [
                Text('모임 공금 결제',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                SizedBox(height: 2),
                Text('에스크로 가상계좌 연동',
                    style: TextStyle(
                        color: Color(0xFF93C5FD), fontSize: 12)),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.more_vert_rounded,
                color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMoimInfoCard(MoimResponse moim) {
    final available = moim.totalDeposited - moim.totalSpent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(moim.emoji ?? '🍜',
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('결제 모임',
                      style: TextStyle(
                          color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w500)),
                  Text(moim.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('가용 잔액',
                    style: TextStyle(
                        color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w500)),
                Row(
                  children: [
                    Text(_fmt.format(available.toInt()),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const Text('원',
                        style: TextStyle(
                            color: Color(0xFF93C5FD), fontSize: 11)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x59000000),
              blurRadius: 48,
              offset: Offset(0, 12)),
          BoxShadow(
              color: Color(0x33000000),
              blurRadius: 16,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_rounded,
                        color: Color(0xFF0052FF), size: 14),
                    const SizedBox(width: 4),
                    const Text('PortOne 보안 인증',
                        style: TextStyle(
                            color: Color(0xFF0052FF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF22C55E).withOpacity(0.6),
                              blurRadius: 5),
                        ],
                      ),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Icon(Icons.lock_rounded,
                        color: Color(0xFF9CA3AF), size: 12),
                    SizedBox(width: 4),
                    Text('SSL 암호화',
                        style: TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              children: [
                _buildQrDisplay(),
                const SizedBox(height: 20),
                _buildAuthCode(),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Color(0xFFCBD5E1), size: 12),
                    SizedBox(width: 4),
                    Text('점원에게 화면을 보여주세요',
                        style: TextStyle(
                            color: Color(0xFFCBD5E1), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrDisplay() {
    return AnimatedBuilder(
      animation: _scanLineCtrl,
      builder: (context, _) {
        return Container(
          width: 196,
          height: 196,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF0052FF).withOpacity(0.08)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              children: [
                Center(
                  child: CustomPaint(
                    size: const Size(184, 184),
                    painter: _QrPainter(),
                  ),
                ),
                // Corner brackets
                ..._cornerBrackets(),
                // Scan line
                Positioned(
                  top: 6 + (_scanLineCtrl.value * (196 - 18)),
                  left: 6,
                  right: 6,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF0052FF).withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _cornerBrackets() {
    const c = Color(0xFF0052FF);
    const size = 16.0;
    const thick = 2.5;
    const r = 4.0;

    Widget bracket(
        {required double? top,
        required double? left,
        required double? right,
        required double? bottom}) {
      return Positioned(
        top: top,
        left: left,
        right: right,
        bottom: bottom,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _BracketPainter(
              topLeft: top != null && left != null,
              topRight: top != null && right != null,
              bottomLeft: bottom != null && left != null,
              bottomRight: bottom != null && right != null,
              color: c,
              thickness: thick,
              radius: r,
            ),
          ),
        ),
      );
    }

    return [
      bracket(top: 6, left: 6, right: null, bottom: null),
      bracket(top: 6, left: null, right: 6, bottom: null),
      bracket(top: null, left: 6, right: null, bottom: 6),
      bracket(top: null, left: null, right: 6, bottom: 6),
    ];
  }

  Widget _buildAuthCode() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(6, (i) {
          if (i == 3) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('-',
                  style: TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            );
          }
          return Container(
            width: 36,
            height: 46,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEF2FF), width: 1.5),
            ),
            child: Center(
              child: Text('${_authCode[i]}',
                  style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTimerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_rounded,
                      color: Colors.white.withOpacity(0.85), size: 16),
                  const SizedBox(width: 8),
                  Text('보안 코드 만료까지',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              Text(_timerText,
                  style: TextStyle(
                      color: _remaining > 45 ? Colors.white : _timerColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 7,
              color: Colors.white.withOpacity(0.18),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _timerProgress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_timerColor, _timerColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('만료',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 11)),
              Text('3:00',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _refreshCode,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('코드 새로고침',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _showGuideSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x38000000),
                      blurRadius: 20,
                      offset: Offset(0, 6)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.help_outline_rounded,
                      color: Color(0xFF0052FF), size: 18),
                  SizedBox(width: 8),
                  Text('결제 방법 안내',
                      style: TextStyle(
                          color: Color(0xFF0052FF),
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.smartphone_rounded,
              color: Color(0xFF93C5FD), size: 18),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이렇게 사용하세요',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(
                  '포스기 바코드 스캐너에 QR 코드를 제시하면 가상계좌 잔액에서 자동으로 차감됩니다.',
                  style: TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 12,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGuideSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _GuideBottomSheet(
        onManualPayment: () {
          Navigator.pop(ctx);
          _showManualPaymentSheet();
        },
      ),
    );
  }

  void _showManualPaymentSheet() {
    final merchantCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = '식음료';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('결제 내역 직접 입력',
                        style: TextStyle(
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: merchantCtrl,
                  style: const TextStyle(color: Color(0xFF111827)),
                  decoration: _inputDeco('가맹점명', Icons.store_outlined),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Color(0xFF111827)),
                  decoration:
                      _inputDeco('결제 금액 (원)', Icons.payments_outlined),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['식음료', '숙박', '쇼핑', '교통', '기타']
                        .map((c) => GestureDetector(
                              onTap: () =>
                                  setSheetState(() => category = c),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: category == c
                                      ? const Color(0xFF0052FF)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(c,
                                    style: TextStyle(
                                        color: category == c
                                            ? Colors.white
                                            : const Color(0xFF374151),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      final merchant = merchantCtrl.text.trim();
                      final amount = double.tryParse(
                          amountCtrl.text.replaceAll(',', '').trim());
                      if (merchant.isEmpty || amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('가맹점명과 금액을 올바르게 입력해주세요')));
                        return;
                      }
                      try {
                        await ApiClient.createPayment(
                          moimId: widget.moimId,
                          merchantName: merchant,
                          category: category,
                          amount: amount,
                        );
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('결제가 등록되었습니다')));
                          context
                              .read<MoimProvider>()
                              .loadMoim(widget.moimId);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')));
                        }
                      }
                    },
                    child: const Text('결제 등록',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0052FF), width: 1.5)),
    );
  }
}

class _GuideBottomSheet extends StatelessWidget {
  final VoidCallback onManualPayment;
  const _GuideBottomSheet({required this.onManualPayment});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('결제 방법 안내',
                  style: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...['QR 코드 제시\n포스기 또는 카드 단말기의 QR/바코드 스캐너에 화면을 가져가세요.',
              '잔액 자동 차감\n모임 가상계좌 잔액에서 결제 금액이 즉시 차감됩니다.',
              '코드가 보이지 않을 때\n6자리 인증 코드를 점원에게 구두로 알려주세요.']
              .asMap()
              .entries
              .map((e) {
            final parts = e.value.split('\n');
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0052FF), Color(0xFF4D94FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('${e.key + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(parts[0],
                            style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(parts[1],
                            style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                                height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE4B5)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'QR 코드는 보안을 위해 3분마다 자동 갱신됩니다. 만료 전 결제를 완료하거나 코드를 새로 발급하세요.',
                    style: TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 12,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onManualPayment,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_rounded,
                      color: Color(0xFF0052FF), size: 16),
                  SizedBox(width: 8),
                  Text('결제 내역 직접 입력',
                      style: TextStyle(
                          color: Color(0xFF0052FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0052FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('확인했어요',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  static const _matrix = [
    [1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1],
    [1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1],
    [1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1],
    [1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1],
    [1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1],
    [1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1],
    [1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [1, 1, 0, 1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 1, 0, 1, 0],
    [0, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 1],
    [1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1],
    [0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0],
    [1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1],
    [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1],
    [1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0],
    [1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0],
    [1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0],
    [1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1],
    [1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 0, 1, 1],
    [1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0],
    [1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sz = size.width / _matrix.length;
    final paint = Paint()..color = const Color(0xFF0D0F1A);

    for (int y = 0; y < _matrix.length; y++) {
      for (int x = 0; x < _matrix[y].length; x++) {
        if (_matrix[y][x] == 0) continue;
        final r = math.min(1.5, sz * 0.18);
        final rect =
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x * sz + 0.5, y * sz + 0.5, sz - 1, sz - 1),
                Radius.circular(r));
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => false;
}

class _BracketPainter extends CustomPainter {
  final bool topLeft, topRight, bottomLeft, bottomRight;
  final Color color;
  final double thickness, radius;

  const _BracketPainter({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.color,
    required this.thickness,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    if (topLeft) {
      canvas.drawLine(Offset(0, h), Offset(0, radius), paint);
      canvas.drawArc(Rect.fromLTWH(0, 0, radius * 2, radius * 2),
          math.pi, math.pi / 2, false, paint);
      canvas.drawLine(Offset(radius, 0), Offset(w, 0), paint);
    }
    if (topRight) {
      canvas.drawLine(Offset(0, 0), Offset(w - radius, 0), paint);
      canvas.drawArc(
          Rect.fromLTWH(w - radius * 2, 0, radius * 2, radius * 2),
          -math.pi / 2,
          math.pi / 2,
          false,
          paint);
      canvas.drawLine(Offset(w, radius), Offset(w, h), paint);
    }
    if (bottomLeft) {
      canvas.drawLine(Offset(0, 0), Offset(0, h - radius), paint);
      canvas.drawArc(
          Rect.fromLTWH(0, h - radius * 2, radius * 2, radius * 2),
          math.pi / 2,
          math.pi / 2,
          false,
          paint);
      canvas.drawLine(Offset(radius, h), Offset(w, h), paint);
    }
    if (bottomRight) {
      canvas.drawLine(Offset(0, h), Offset(w - radius, h), paint);
      canvas.drawArc(
          Rect.fromLTWH(w - radius * 2, h - radius * 2, radius * 2, radius * 2),
          0,
          math.pi / 2,
          false,
          paint);
      canvas.drawLine(Offset(w, h - radius), Offset(w, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) => false;
}
