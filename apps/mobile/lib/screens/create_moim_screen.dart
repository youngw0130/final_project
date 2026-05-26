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
  int _step = 0;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _inviteCodeCtrl = TextEditingController();
  DateTime? _scheduledAt;
  String _emoji = '🍻';

  double _depositPerPerson = 50000;
  int _participantCount = 5;
  double _bufferRate = 0.07;

  static const _emojis = ['🍻', '🏕️', '🎾', '🎂', '🎮', '✈️', '🍽️', '🎵'];
  static const _quickDeposits = [20000.0, 30000.0, 50000.0, 100000.0];
  static const _quickBuffers = [0.05, 0.07, 0.10];

  double get _targetAmount =>
      _depositPerPerson * _participantCount * (1 + _bufferRate);

  @override
  void initState() {
    super.initState();
    _inviteCodeCtrl.text = _generateCode();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _inviteCodeCtrl.dispose();
    super.dispose();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (i) => chars[(DateTime.now().millisecondsSinceEpoch + i * 7) % chars.length]).join();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('모임 이름을 입력해주세요')));
      return;
    }
    final data = {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'emoji': _emoji,
      'scheduledAt': _scheduledAt?.toIso8601String(),
      'depositPerPerson': _depositPerPerson,
      'bufferRate': _bufferRate,
      'targetParticipantCount': _participantCount,
      'inviteCode': _inviteCodeCtrl.text.trim(),
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('새 모임 만들기',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _step == 0
                  ? _buildStep1()
                  : _step == 1
                      ? _buildStep2()
                      : _buildStep3(),
            ),
          ),
          _buildNavButtons(loading),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    const labels = ['기본 정보', '에스크로 설정', '초대'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(3, (i) {
          final active = i == _step;
          final done = i < _step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: done || active
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        labels[i],
                        style: TextStyle(
                          color: active
                              ? const Color(0xFF6366F1)
                              : done
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < 2) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('어떤 모임인가요?',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _label('모임 유형'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _emojis.map((e) {
            final sel = e == _emoji;
            return GestureDetector(
              onTap: () => setState(() => _emoji = e),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: sel
                      ? const Color(0xFF6366F1).withOpacity(0.2)
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF334155),
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Center(child: Text(e, style: const TextStyle(fontSize: 24))),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _label('모임 이름 *'),
        const SizedBox(height: 8),
        _textField(
          controller: _titleCtrl,
          hint: '예: 강남역 회식',
          maxLength: 30,
        ),
        const SizedBox(height: 16),
        _label('설명 (선택)'),
        const SizedBox(height: 8),
        _textField(
          controller: _descCtrl,
          hint: '모임에 대한 간단한 설명',
          maxLines: 2,
          maxLength: 100,
        ),
        const SizedBox(height: 16),
        _label('일정 (선택)'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                      primary: Color(0xFF6366F1)),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _scheduledAt = picked);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: Color(0xFF64748B), size: 18),
                const SizedBox(width: 10),
                Text(
                  _scheduledAt != null
                      ? DateFormat('yyyy년 MM월 dd일').format(_scheduledAt!)
                      : '날짜를 선택해주세요',
                  style: TextStyle(
                    color: _scheduledAt != null
                        ? Colors.white
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('에스크로를 설정해주세요',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _label('1인당 입금액'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickDeposits.map((d) {
            final sel = d == _depositPerPerson;
            return GestureDetector(
              onTap: () => setState(() => _depositPerPerson = d),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF334155),
                  ),
                ),
                child: Text(
                  '${_fmt.format(d.toInt())}원',
                  style: TextStyle(
                    color: sel ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _label('참여 인원'),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton(
              onPressed: _participantCount > 2
                  ? () => setState(() => _participantCount--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline,
                  color: Color(0xFF6366F1)),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1)),
                ),
                child: Center(
                  child: Text(
                    '$_participantCount명',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: _participantCount < 20
                  ? () => setState(() => _participantCount++)
                  : null,
              icon: const Icon(Icons.add_circle_outline,
                  color: Color(0xFF6366F1)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _label('버퍼 비율'),
        const SizedBox(height: 4),
        const Text(
          '예상치 못한 추가 비용을 위한 여유 금액입니다',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          children: _quickBuffers.map((b) {
            final sel = b == _bufferRate;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _bufferRate = b),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF334155),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${(b * 100).toInt()}%${b == 0.07 ? ' 추천' : ''}',
                      style: TextStyle(
                        color: sel ? Colors.white : const Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            children: [
              _summaryRow('1인당 입금액',
                  '${_fmt.format(_depositPerPerson.toInt())}원'),
              const SizedBox(height: 8),
              _summaryRow('참여 인원', '$_participantCount명'),
              const SizedBox(height: 8),
              _summaryRow('버퍼', '${(_bufferRate * 100).toInt()}%'),
              const Divider(color: Color(0xFF334155), height: 20),
              _summaryRow(
                '총 에스크로',
                '${_fmt.format(_targetAmount.toInt())}원',
                bold: true,
                highlight: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('초대 설정',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _label('초대 코드'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _inviteCodeCtrl,
                maxLength: 10,
                style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]'))
                ],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () =>
                  setState(() => _inviteCodeCtrl.text = _generateCode()),
              icon: const Icon(Icons.refresh, color: Color(0xFF6366F1)),
            ),
            IconButton(
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: _inviteCodeCtrl.text));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('초대코드가 복사됐습니다')));
              },
              icon: const Icon(Icons.copy, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6366F1).withOpacity(0.15),
                const Color(0xFF7C3AED).withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('모임 요약',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 12),
              _summaryRow('모임명', _titleCtrl.text.isEmpty ? '(미입력)' : _titleCtrl.text),
              const SizedBox(height: 6),
              _summaryRow('유형', _emoji),
              const SizedBox(height: 6),
              _summaryRow('인원', '$_participantCount명'),
              const SizedBox(height: 6),
              _summaryRow('1인 입금', '${_fmt.format(_depositPerPerson.toInt())}원'),
              const SizedBox(height: 6),
              _summaryRow('총 에스크로', '${_fmt.format(_targetAmount.toInt())}원',
                  bold: true, highlight: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavButtons(bool loading) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                  side: const BorderSide(color: Color(0xFF334155)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('이전'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: loading
                  ? null
                  : () {
                      if (_step < 2) {
                        setState(() => _step++);
                      } else {
                        _submit();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _step < 2 ? '다음' : '모임 만들기',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
          fontWeight: FontWeight.w500));

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF475569)),
        counterStyle: const TextStyle(color: Color(0xFF475569)),
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
    );
  }

  Widget _summaryRow(String label, String value,
      {bool bold = false, bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        Text(value,
            style: TextStyle(
              color: highlight ? const Color(0xFF6366F1) : Colors.white,
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            )),
      ],
    );
  }
}
