import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/moim_provider.dart';

class CreateMoimScreen extends StatefulWidget {
  const CreateMoimScreen({super.key});

  @override
  State<CreateMoimScreen> createState() => _CreateMoimScreenState();
}

class _CreateMoimScreenState extends State<CreateMoimScreen> {
  final _fmt = NumberFormat('#,###');
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DateTime? _scheduledAt;
  String _emoji = '🍻';
  double _depositPerPerson = 0;
  int _participantCount = 5;
  double _bufferRate = 0.07;
  String _inviteCode = '';
  String _customBuffer = '';

  static const _emojis = [
    ('🍻', '회식'),
    ('🏕️', '여행'),
    ('🎾', '스포츠'),
    ('🎂', '파티'),
    ('🎮', '게임'),
    ('✈️', '기타'),
  ];

  static const _quickDeposits = [20000.0, 30000.0, 50000.0, 100000.0];

  double get _targetAmount =>
      _depositPerPerson * _participantCount * (1 + _bufferRate);

  @override
  void initState() {
    super.initState();
    _inviteCode = _generateCode();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
            6,
            (i) => chars[
                (DateTime.now().millisecondsSinceEpoch + i * 13) %
                    chars.length])
        .join();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('모임 이름을 입력해주세요')));
      return;
    }
    if (_depositPerPerson <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('1인당 예치금을 입력해주세요')));
      return;
    }
    final data = {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      'emoji': _emoji,
      'scheduledAt': _scheduledAt?.toIso8601String(),
      'depositPerPerson': _depositPerPerson,
      'bufferRate': _bufferRate,
      'targetParticipantCount': _participantCount,
      'inviteCode': _inviteCode,
    };
    final moim = await context.read<MoimProvider>().createMoim(data);
    if (mounted) {
      if (moim != null) {
        context.pushReplacement('/moims/${moim.id}');
      } else {
        final err = context.read<MoimProvider>().error;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err ?? '모임 생성에 실패했습니다')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<MoimProvider>().loading;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildGradientHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Column(
                  children: [
                    _buildBasicInfoCard(),
                    const SizedBox(height: 12),
                    _buildEscrowCard(),
                    const SizedBox(height: 12),
                    _buildAccountPreviewCard(),
                    const SizedBox(height: 12),
                    _buildInviteCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomCta(loading),
    );
  }

  Widget _buildGradientHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF003ED4), Color(0xFF0052FF), Color(0xFF2B7FFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Column(
        children: [
          // Nav
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              const Column(
                children: [
                  Text('새 모임 만들기',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  SizedBox(height: 2),
                  Text('에스크로 가상계좌 자동 발급',
                      style: TextStyle(
                          color: Color(0xFF93C5FD), fontSize: 12)),
                ],
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.help_outline_rounded,
                    color: Colors.white, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepDot(1, '기본 정보', true),
              Container(
                width: 32,
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.white.withOpacity(0.35),
              ),
              _stepDot(2, '에스크로', false),
              Container(
                width: 32,
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.white.withOpacity(0.35),
              ),
              _stepDot(3, '초대', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepDot(int num, String label, bool active) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withOpacity(0.25),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$num',
                style: TextStyle(
                    color: active
                        ? const Color(0xFF0052FF)
                        : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: active
                    ? Colors.white
                    : Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal)),
      ],
    );
  }

  Widget _buildBasicInfoCard() {
    return _card(
      icon: Icons.edit_rounded,
      title: '기본 정보',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('모임 유형'),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _emojis
                  .map((e) => _emojiChip(e.$1, e.$2))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel('모임 이름'),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            maxLength: 30,
            style: const TextStyle(
                color: Color(0xFF111827), fontSize: 14),
            decoration: _formInputDeco('예: 라멘야 모임'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('날짜'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now()
                              .add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (d != null) {
                          setState(() => _scheduledAt = d);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 14,
                                color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 6),
                            Text(
                              _scheduledAt != null
                                  ? DateFormat('yyyy-MM-dd')
                                      .format(_scheduledAt!)
                                  : '2025-03-22',
                              style: const TextStyle(
                                  color: Color(0xFF374151),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('시간'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 14, color: Color(0xFF9CA3AF)),
                          SizedBox(width: 6),
                          Text('19:00',
                              style: TextStyle(
                                  color: Color(0xFF374151),
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _sectionLabel('장소 (선택)'),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            style: const TextStyle(
                color: Color(0xFF111827), fontSize: 14),
            decoration: _formInputDeco('예: 라멘야 부산본점',
                prefixIcon: Icons.location_on_outlined),
          ),
        ],
      ),
    );
  }

  Widget _emojiChip(String emoji, String label) {
    final sel = _emoji == emoji;
    return GestureDetector(
      onTap: () => setState(() => _emoji = emoji),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFEEF2FF) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? const Color(0xFF0052FF) : const Color(0xFFE5E7EB),
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: sel
                        ? const Color(0xFF0052FF)
                        : const Color(0xFF6B7280),
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildEscrowCard() {
    return _card(
      icon: Icons.account_balance_wallet_outlined,
      title: '에스크로 설정',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('1인당 예치금'),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(
                color: Color(0xFF111827), fontSize: 14),
            onChanged: (v) {
              final n = double.tryParse(v.replaceAll(',', '')) ?? 0;
              setState(() => _depositPerPerson = n);
            },
            decoration: _formInputDeco('0',
                suffix: const Text('원',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500))),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickDeposits.map((d) {
              final sel = d == _depositPerPerson;
              return GestureDetector(
                onTap: () => setState(() => _depositPerPerson = d),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF0052FF)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFF0052FF)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Text(
                    '${_fmt.format(d.toInt())}원',
                    style: TextStyle(
                        color: sel
                            ? Colors.white
                            : const Color(0xFF374151),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _sectionLabel('참여 인원 목표'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _participantCount > 2
                      ? () => setState(() => _participantCount--)
                      : null,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x0D000000),
                            blurRadius: 6,
                            offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Icon(Icons.remove_rounded,
                        color: Color(0xFF374151), size: 18),
                  ),
                ),
                Row(
                  children: [
                    Text('$_participantCount',
                        style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const Text(' 명',
                        style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                GestureDetector(
                  onTap: _participantCount < 20
                      ? () => setState(() => _participantCount++)
                      : null,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0052FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('예치금 버퍼 (Buffer)'),
              const Text('5~10% 권장',
                  style: TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _bufferChip(0.05, '5%', '보수적'),
              const SizedBox(width: 8),
              _bufferChip(0.07, '7%', '권장 ✓'),
              const SizedBox(width: 8),
              _bufferChip(0.10, '10%', '여유있게'),
              const SizedBox(width: 8),
              _bufferChipCustom(),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE4B5)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFD97706), size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '결제가 예치금을 초과할 경우를 대비한 추가 여유 자금이에요. 모임 종료 후 미사용 버퍼는 전액 환급됩니다.',
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('예상 에스크로 계산',
                        style: TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Icon(Icons.calculate_outlined,
                        color: Color(0xFF3B82F6), size: 16),
                  ],
                ),
                const SizedBox(height: 12),
                _calcRow('1인 예치금',
                    _depositPerPerson > 0
                        ? '${_fmt.format(_depositPerPerson.toInt())}원'
                        : '—'),
                _calcRow('참여 인원', '$_participantCount명'),
                _calcRow('버퍼 (${(_bufferRate * 100).toInt()}%)',
                    _depositPerPerson > 0
                        ? '+${_fmt.format((_depositPerPerson * _participantCount * _bufferRate).toInt())}원'
                        : '—'),
                Divider(
                    color: const Color(0xFFBFD7FF).withOpacity(0.5),
                    height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('총 에스크로 목표',
                        style: TextStyle(
                            color: Color(0xFF1E40AF),
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    Text(
                      _depositPerPerson > 0
                          ? '${_fmt.format(_targetAmount.toInt())}원'
                          : '—원',
                      style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('= 예치금 × 인원 × (1 + 버퍼)',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: Color(0xFF93C5FD), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bufferChip(double val, String pct, String sub) {
    final sel = _bufferRate == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _bufferRate = val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF0052FF) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel
                  ? const Color(0xFF0052FF)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            children: [
              Text(pct,
                  style: TextStyle(
                      color: sel ? Colors.white : const Color(0xFF374151),
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              Text(sub,
                  style: TextStyle(
                      color: sel
                          ? Colors.white.withOpacity(0.8)
                          : const Color(0xFF9CA3AF),
                      fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bufferChipCustom() {
    final sel = ![0.05, 0.07, 0.10].contains(_bufferRate);
    return Expanded(
      child: GestureDetector(
        onTap: () => _showCustomBufferDialog(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF0052FF) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel
                  ? const Color(0xFF0052FF)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            children: [
              Text(sel ? '${(_bufferRate * 100).toInt()}%' : '직접',
                  style: TextStyle(
                      color: sel ? Colors.white : const Color(0xFF374151),
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              Text('입력',
                  style: TextStyle(
                      color: sel
                          ? Colors.white.withOpacity(0.8)
                          : const Color(0xFF9CA3AF),
                      fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomBufferDialog() {
    final ctrl = TextEditingController(
        text: ![0.05, 0.07, 0.10].contains(_bufferRate)
            ? '${(_bufferRate * 100).toInt()}'
            : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('버퍼 직접 입력',
            style: TextStyle(color: Color(0xFF111827))),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '숫자 입력',
            suffix: const Text('%'),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0052FF)),
            onPressed: () {
              final v = int.tryParse(ctrl.text);
              if (v != null && v >= 1 && v <= 30) {
                setState(() => _bufferRate = v / 100.0);
              }
              Navigator.pop(ctx);
            },
            child: const Text('확인',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _calcRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF4B5563), fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAccountPreviewCard() {
    return _card(
      icon: Icons.account_balance_outlined,
      title: '가상계좌 발급 프리뷰',
      badge: _badgeLive('자동 발급'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 6,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Text('P',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('PortOne',
                              style: TextStyle(
                                  color: Color(0xFF4338CA),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                          SizedBox(width: 4),
                          Text('연동',
                              style: TextStyle(
                                  color: Color(0xFF818CF8), fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        '모임 생성 시 PortOne을 통해 전용 가상계좌가 즉시 발급됩니다.',
                        style: TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 12,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  style: BorderStyle.solid),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('T',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('토스뱅크 (모임 전용)',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 12)),
                      Text('1000 - ???? - ????',
                          style: TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ],
                  ),
                ),
                const Text('생성 후 확정',
                    style: TextStyle(
                        color: Color(0xFFD1D5DB), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...[
            '입금 즉시 에스크로에 자동 반영',
            'QR 결제 시 가상계좌 잔액에서 직접 차감',
            '모임 종료 후 잔액 넷팅 알고리즘으로 자동 환급',
          ].map((text) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Color(0xFF00A864), size: 12),
                    ),
                    const SizedBox(width: 10),
                    Text(text,
                        style: const TextStyle(
                            color: Color(0xFF374151), fontSize: 12)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildInviteCard() {
    return _card(
      icon: Icons.people_outline_rounded,
      title: '친구 초대',
      badge: const Text('모임 생성 후에도 가능',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('참여 코드 (미리보기)'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ..._inviteCode.split('').asMap().entries.map((e) {
                if (e.key == 3) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('-',
                        style: TextStyle(
                            color: Color(0xFFD1D5DB),
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                  );
                }
                return Container(
                  width: 38,
                  height: 46,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFC7D2FE), width: 1.5),
                  ),
                  child: Center(
                    child: Text(e.value,
                        style: const TextStyle(
                            color: Color(0xFF0052FF),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace')),
                  ),
                );
              }).toList(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('코드가 복사되었습니다')));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.copy_rounded,
                          color: Color(0xFF0052FF), size: 14),
                      SizedBox(width: 6),
                      Text('코드 복사',
                          style: TextStyle(
                              color: Color(0xFF0052FF),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(
                    () => _inviteCode = _generateCode()),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.refresh_rounded,
                          color: Color(0xFF6B7280), size: 14),
                      SizedBox(width: 6),
                      Text('재생성',
                          style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text('6자리 코드로 친구가 모임에 참여할 수 있어요',
                style: TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? badge,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A0052FF),
              blurRadius: 24,
              offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF0052FF), size: 16),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              if (badge != null) ...[
                const Spacer(),
                badge,
              ],
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _badgeLive(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00A864).withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: Color(0xFF00A864), shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  color: Color(0xFF00A864),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: FontWeight.w600));
  }

  InputDecoration _formInputDeco(String hint,
      {Widget? suffix, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      suffix: suffix,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: const Color(0xFF9CA3AF), size: 18)
          : null,
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      counterText: '',
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0052FF), width: 1.5)),
    );
  }

  Widget _buildBottomCta(bool loading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00F0F4FF), Color(0xFFF0F4FF)],
          stops: [0.0, 0.3],
        ),
        color: Color(0xFFF0F4FF),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 8,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(_emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      _titleCtrl.text.isEmpty
                          ? '모임 이름 입력 중...'
                          : _titleCtrl.text,
                      style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('$_participantCount명',
                        style: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 12)),
                    const Text(' · ',
                        style: TextStyle(
                            color: Color(0xFFD1D5DB), fontSize: 12)),
                    Text(
                      _depositPerPerson > 0
                          ? '${_fmt.format(_targetAmount.toInt())}원'
                          : '—원',
                      style: const TextStyle(
                          color: Color(0xFF0052FF),
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: loading ? null : _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0038CC),
                      Color(0xFF0052FF),
                      Color(0xFF2B7FFF)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x660052FF),
                        blurRadius: 30,
                        offset: Offset(0, 10)),
                  ],
                ),
                child: loading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Text('모임 만들기',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('생성 즉시 PortOne 가상계좌가 발급됩니다',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
        ],
      ),
    );
  }
}
