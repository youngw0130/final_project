import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/moim_response.dart';
import '../models/payment_response.dart';
import '../providers/auth_provider.dart';
import '../providers/moim_provider.dart';
import '../services/api_client.dart';
import 'package:provider/provider.dart';

class QrPaymentScreen extends StatefulWidget {
  final int moimId;
  const QrPaymentScreen({super.key, required this.moimId});

  @override
  State<QrPaymentScreen> createState() => _QrPaymentScreenState();
}

class _QrPaymentScreenState extends State<QrPaymentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _fmt = NumberFormat('#,###', 'ko_KR');

  // 결제 폼
  final _merchantCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _selectedCategory = '식음료';
  bool _paying = false;
  String? _payError;

  // 결제 내역
  List<PaymentResponse> _payments = [];
  bool _loadingPayments = false;

  static const _categories = ['식음료', '숙박', '쇼핑', '교통', '기타'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index == 1 && !_tabs.indexIsChanging) _loadPayments();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MoimProvider>().loadMoim(widget.moimId);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() => _loadingPayments = true);
    try {
      final list = await ApiClient.getPayments(widget.moimId);
      if (mounted) setState(() => _payments = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loadingPayments = false);
    }
  }

  Future<void> _submitPayment(MoimResponse moim) async {
    final merchant = _merchantCtrl.text.trim();
    final amountText = _amountCtrl.text.replaceAll(',', '').trim();

    if (merchant.isEmpty) {
      setState(() => _payError = '가맹점명을 입력해주세요');
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _payError = '올바른 금액을 입력해주세요');
      return;
    }
    if (amount > moim.balance) {
      setState(() => _payError = '잔액(${_fmt.format(moim.balance.toInt())}원)이 부족합니다');
      return;
    }

    setState(() {
      _paying = true;
      _payError = null;
    });

    try {
      await ApiClient.createPayment(
        moimId: widget.moimId,
        merchantName: merchant,
        category: _selectedCategory,
        amount: amount,
      );
      if (!mounted) return;
      await Future.wait([
        context.read<MoimProvider>().loadMoim(widget.moimId),
        context.read<AuthProvider>().refreshProfile(),
      ]);
      _merchantCtrl.clear();
      _amountCtrl.clear();
      setState(() => _selectedCategory = '식음료');
      _showSuccessOverlay(merchant, amount);
    } on ApiException catch (e) {
      if (mounted) setState(() => _payError = e.message);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _showSuccessOverlay(String merchant, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Color(0xFF22C55E), size: 40),
              ),
              const SizedBox(height: 20),
              const Text('결제 완료',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(merchant,
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 14)),
              const SizedBox(height: 4),
              Text('${_fmt.format(amount.toInt())}원',
                  style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('확인'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moim = context.watch<MoimProvider>().selectedMoim;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          moim != null ? '${moim.title} · QR 결제' : 'QR 결제',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF6366F1),
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: const Color(0xFF64748B),
          tabs: const [
            Tab(text: '결제하기'),
            Tab(text: '결제 내역'),
          ],
        ),
      ),
      body: moim == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : moim.status != 'ACTIVE'
              ? _buildNotActive(moim.status)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildPayTab(moim),
                    _buildHistoryTab(),
                  ],
                ),
    );
  }

  Widget _buildNotActive(String status) {
    final msg = status == 'OPEN'
        ? '모든 참여자가 입금을 완료해야\nQR 결제를 사용할 수 있습니다.'
        : status == 'CLOSED' || status == 'SETTLING'
            ? '이미 정산이 완료된 모임입니다.'
            : 'QR 결제를 사용할 수 없는 상태입니다.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == 'OPEN'
                  ? Icons.lock_outline
                  : Icons.check_circle_outline,
              color: const Color(0xFF64748B),
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 15, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildPayTab(MoimResponse moim) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildQrPlaceholder(moim),
          const SizedBox(height: 24),
          _buildBalanceCard(moim),
          const SizedBox(height: 24),
          _buildPayForm(moim),
        ],
      ),
    );
  }

  Widget _buildQrPlaceholder(MoimResponse moim) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          // QR 패턴 시뮬레이션
          Container(
            width: 160,
            height: 160,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _QrPattern(seed: widget.moimId),
          ),
          const SizedBox(height: 16),
          Text(moim.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 4),
          Text('에스크로 가상계좌 QR',
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('진행 중',
                style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(MoimResponse moim) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('사용 가능 잔액',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text('${_fmt.format(moim.balance.toInt())}원',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('총 지출',
                  style: TextStyle(color: Colors.white60, fontSize: 11)),
              const SizedBox(height: 4),
              Text('${_fmt.format(moim.totalSpent.toInt())}원',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayForm(MoimResponse moim) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('결제 정보 입력',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 20),
          _label('가맹점명'),
          const SizedBox(height: 8),
          _textField(
            controller: _merchantCtrl,
            hint: '예: 라멘야 부산본점',
          ),
          const SizedBox(height: 16),
          _label('카테고리'),
          const SizedBox(height: 8),
          _categorySelector(),
          const SizedBox(height: 16),
          _label('금액'),
          const SizedBox(height: 8),
          _amountField(),
          if (_payError != null) ...[
            const SizedBox(height: 12),
            Text(_payError!,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _paying ? null : () => _submitPayment(moim),
            icon: _paying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.qr_code_scanner),
            label: Text(_paying ? '결제 처리 중...' : 'QR 결제 승인'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF334155),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_loadingPayments) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }
    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined,
                color: Color(0xFF334155), size: 56),
            const SizedBox(height: 16),
            const Text('결제 내역이 없습니다',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadPayments,
              icon: const Icon(Icons.refresh, color: Color(0xFF6366F1)),
              label: const Text('불러오기',
                  style: TextStyle(color: Color(0xFF6366F1))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF6366F1)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPayments,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _payments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildPaymentTile(_payments[i]),
      ),
    );
  }

  Widget _buildPaymentTile(PaymentResponse p) {
    final dt = DateTime.tryParse(p.approvedAt);
    final dateStr = dt != null
        ? DateFormat('MM.dd HH:mm', 'ko_KR').format(dt.toLocal())
        : p.approvedAt;
    final categoryIcon = _categoryIcon(p.category);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(categoryIcon,
                color: const Color(0xFF6366F1), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.merchantName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 3),
                Text('${p.category ?? '기타'} · $dateStr',
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
          Text('${_fmt.format(p.amount.toInt())}원',
              style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ],
      ),
    );
  }

  IconData _categoryIcon(String? category) {
    switch (category) {
      case '식음료':
        return Icons.restaurant_outlined;
      case '숙박':
        return Icons.hotel_outlined;
      case '쇼핑':
        return Icons.shopping_bag_outlined;
      case '교통':
        return Icons.directions_bus_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13));

  Widget _textField({
    required TextEditingController controller,
    required String hint,
  }) =>
      TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF475569)),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF6366F1)),
          ),
        ),
      );

  Widget _categorySelector() => Row(
        children: _categories
            .map((cat) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedCategory == cat
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedCategory == cat
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF334155),
                        ),
                      ),
                      child: Text(cat,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _selectedCategory == cat
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ))
            .toList(),
      );

  Widget _amountField() => TextField(
        controller: _amountCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          _ThousandsSeparatorFormatter(),
        ],
        style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: const TextStyle(color: Color(0xFF475569)),
          suffixText: '원',
          suffixStyle:
              const TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF6366F1)),
          ),
        ),
      );
}

// 천 단위 구분 포매터
class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    if (next.text.isEmpty) return next;
    final digits = next.text.replaceAll(',', '');
    final num = int.tryParse(digits);
    if (num == null) return old;
    final formatted = NumberFormat('#,###', 'ko_KR').format(num);
    return next.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// QR 패턴 시뮬레이션 위젯
class _QrPattern extends StatelessWidget {
  final int seed;
  const _QrPattern({required this.seed});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _QrPainter(seed: seed));
  }
}

class _QrPainter extends CustomPainter {
  final int seed;
  const _QrPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    const cells = 11;
    final cell = size.width / cells;

    // 고정 파인더 패턴 (좌상, 우상, 좌하)
    _drawFinder(canvas, paint, 0, 0, cell);
    _drawFinder(canvas, paint, cells - 7, 0, cell);
    _drawFinder(canvas, paint, 0, cells - 7, cell);

    // seed 기반 데이터 영역
    for (int r = 0; r < cells; r++) {
      for (int c = 0; c < cells; c++) {
        if (_isFinder(r, c, cells)) continue;
        final hash = (seed * 31 + r * 17 + c * 13) % 3;
        if (hash == 0) {
          canvas.drawRect(
              Rect.fromLTWH(c * cell, r * cell, cell - 1, cell - 1), paint);
        }
      }
    }
  }

  void _drawFinder(Canvas canvas, Paint paint, int col, int row, double cell) {
    // 외부 7×7
    paint.color = Colors.black;
    canvas.drawRect(
        Rect.fromLTWH(col * cell, row * cell, 7 * cell, 7 * cell), paint);
    // 내부 흰색 5×5
    paint.color = Colors.white;
    canvas.drawRect(
        Rect.fromLTWH((col + 1) * cell, (row + 1) * cell, 5 * cell, 5 * cell),
        paint);
    // 중심 3×3
    paint.color = Colors.black;
    canvas.drawRect(
        Rect.fromLTWH((col + 2) * cell, (row + 2) * cell, 3 * cell, 3 * cell),
        paint);
  }

  bool _isFinder(int r, int c, int cells) =>
      (r < 7 && c < 7) ||
      (r < 7 && c >= cells - 7) ||
      (r >= cells - 7 && c < 7);

  @override
  bool shouldRepaint(covariant _QrPainter old) => old.seed != seed;
}
