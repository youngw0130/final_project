import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

class LinkScoreScreen extends StatefulWidget {
  const LinkScoreScreen({super.key});

  @override
  State<LinkScoreScreen> createState() => _LinkScoreScreenState();
}

class _LinkScoreScreenState extends State<LinkScoreScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  double _depositReliability = 0;
  double _participationRate = 0;
  double _speedRate = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final list = await ApiClient.getLinkScoreHistory();
      if (!mounted) return;
      _computeStats(list);
      setState(() {
        _history = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _computeStats(List<Map<String, dynamic>> history) {
    final onTime = history.where((h) => h['reason'] == 'DEPOSIT_ON_TIME').length;
    final overdue = history.where((h) => h['reason'] == 'DEPOSIT_OVERDUE').length;
    final joined = history.where((h) =>
        h['reason'] == 'MOIM_JOINED' || h['reason'] == 'MOIM_CREATED').length;
    final positive = history.where((h) => (h['delta'] as num) > 0).length;

    _depositReliability =
        (onTime + overdue) == 0 ? 1.0 : onTime / (onTime + overdue);
    _participationRate = joined == 0 ? 0.0 : (joined / 5.0).clamp(0.0, 1.0);
    _speedRate = history.isEmpty ? 0.0 : (positive / history.length).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final score = auth.linkScore;
    final grade = _grade(score);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('링크스코어',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildScoreCard(score, grade),
                    const SizedBox(height: 20),
                    _buildGradeScale(score),
                    const SizedBox(height: 20),
                    _buildStats(),
                    const SizedBox(height: 20),
                    _buildBenefits(grade),
                    const SizedBox(height: 20),
                    _buildHistory(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildScoreCard(int score, _Grade grade) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [grade.color1, grade.color2]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(grade.label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, letterSpacing: 2)),
          const SizedBox(height: 20),
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(160, 160),
                  painter: _ScoreRingPainter(score / 1000),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.bold)),
                    const Text('/ 1000',
                        style: TextStyle(color: Colors.white60, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(grade.emoji,
              style: const TextStyle(fontSize: 32)),
        ],
      ),
    );
  }

  Widget _buildGradeScale(int score) {
    final grades = [
      ('🥉', 'BRONZE', 0, 600, const Color(0xFFCD7F32)),
      ('🥈', 'SILVER', 600, 700, const Color(0xFF94A3B8)),
      ('🥇', 'GOLD', 700, 800, const Color(0xFFF59E0B)),
      ('✨', 'PLATINUM', 800, 900, const Color(0xFF22C55E)),
      ('💎', 'DIAMOND', 900, 1000, const Color(0xFF6366F1)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('등급 현황',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 16),
          ...grades.map((g) {
            final isCurrent = score >= g.$3 && score < g.$4;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrent
                    ? g.$5.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isCurrent ? g.$5 : Colors.transparent),
              ),
              child: Row(
                children: [
                  Text(g.$1, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.$2,
                            style: TextStyle(
                                color: isCurrent ? g.$5 : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        Text('${g.$3} ~ ${g.$4}점',
                            style: const TextStyle(
                                color: Color(0xFF64748B), fontSize: 11)),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: g.$5,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('현재',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStats() {
    String pct(double v) => '${(v * 100).toStringAsFixed(0)}%';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('점수 구성',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 16),
          _buildStatBar('입금 성실도', _depositReliability,
              const Color(0xFF22C55E), pct(_depositReliability)),
          const SizedBox(height: 12),
          _buildStatBar('참여 횟수', _participationRate,
              const Color(0xFF6366F1), pct(_participationRate)),
          const SizedBox(height: 12),
          _buildStatBar('긍정 활동', _speedRate,
              const Color(0xFFF59E0B), pct(_speedRate)),
        ],
      ),
    );
  }

  Widget _buildStatBar(String label, double value, Color color, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 13)),
            Text(text,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: const Color(0xFF334155),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildBenefits(_Grade grade) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${grade.label} 혜택',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 12),
          ...grade.benefits.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF22C55E), size: 16),
                    const SizedBox(width: 8),
                    Text(b,
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 13)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) return const SizedBox.shrink();
    final fmt = DateFormat('MM.dd HH:mm', 'ko_KR');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('활동 내역',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 12),
          ..._history.take(10).map((h) {
            final delta = h['delta'] as int;
            final isPos = delta > 0;
            final dt = DateTime.tryParse(h['createdAt']?.toString() ?? '');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (isPos
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444))
                          .withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPos ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isPos
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h['reasonDescription']?.toString() ?? '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                        if (dt != null)
                          Text(fmt.format(dt.toLocal()),
                              style: const TextStyle(
                                  color: Color(0xFF64748B), fontSize: 11)),
                      ],
                    ),
                  ),
                  Text(
                    '${isPos ? '+' : ''}$delta',
                    style: TextStyle(
                        color: isPos
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  _Grade _grade(int score) {
    if (score >= 900) {
      return _Grade('💎 DIAMOND', '💎',
          const Color(0xFF4F46E5), const Color(0xFF7C3AED),
          ['무제한 에스크로', '즉시 정산', '수수료 면제', '프리미엄 지원']);
    }
    if (score >= 800) {
      return _Grade('✨ PLATINUM', '✨',
          const Color(0xFF059669), const Color(0xFF047857),
          ['3000만원 에스크로', '빠른 정산', '5% 버퍼 면제', '30인 모임']);
    }
    if (score >= 700) {
      return _Grade('🥇 GOLD', '🥇',
          const Color(0xFFD97706), const Color(0xFFB45309),
          ['200만원 에스크로', '5% 버퍼 면제', '15인 모임 한도', '우선 지원']);
    }
    if (score >= 600) {
      return _Grade('🥈 SILVER', '🥈',
          const Color(0xFF475569), const Color(0xFF334155),
          ['100만원 에스크로', '10인 모임 한도', '기본 지원']);
    }
    return _Grade('🥉 BRONZE', '🥉',
        const Color(0xFF78350F), const Color(0xFF92400E),
        ['50만원 에스크로', '5인 모임 한도']);
  }
}

class _Grade {
  final String label;
  final String emoji;
  final Color color1;
  final Color color2;
  final List<String> benefits;
  _Grade(this.label, this.emoji, this.color1, this.color2, this.benefits);
}

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  _ScoreRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.progress != progress;
}
