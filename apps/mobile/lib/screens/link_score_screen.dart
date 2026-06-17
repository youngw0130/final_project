import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
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

  int _onTimeCount = 0;
  int _overdueCount = 0;
  int _moimCount = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().refreshProfile();
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
    _onTimeCount =
        history.where((h) => h['reason'] == 'DEPOSIT_ON_TIME').length;
    _overdueCount =
        history.where((h) => h['reason'] == 'DEPOSIT_OVERDUE').length;
    _moimCount = history
        .where((h) =>
            h['reason'] == 'MOIM_JOINED' || h['reason'] == 'MOIM_CREATED')
        .length;
  }

  double get _reliabilityPct {
    final total = _onTimeCount + _overdueCount;
    return total == 0 ? 0.92 : _onTimeCount / total;
  }

  String _gradeLabel(int score) {
    if (score >= 900) return '다이아몬드';
    if (score >= 800) return '플래티넘';
    if (score >= 700) return '골드';
    if (score >= 600) return '실버';
    return '브론즈';
  }

  String _gradeEn(int score) {
    if (score >= 900) return 'Diamond';
    if (score >= 800) return 'Platinum';
    if (score >= 700) return 'GOLD';
    if (score >= 600) return 'Silver';
    return 'Bronze';
  }

  List<Color> _gradeGradient(int score) {
    if (score >= 900) return [const Color(0xFF0038CC), const Color(0xFF60A5FA)];
    if (score >= 800) return [const Color(0xFF00A864), const Color(0xFF4ADE80)];
    if (score >= 700) return [const Color(0xFFB8860B), const Color(0xFFFFD700)];
    if (score >= 600) return [const Color(0xFF6B7280), const Color(0xFF9CA3AF)];
    return [const Color(0xFF78350F), const Color(0xFFCD7F32)];
  }

  int _nextGradeTarget(int score) {
    if (score >= 900) return 1000;
    if (score >= 800) return 900;
    if (score >= 700) return 800;
    if (score >= 600) return 700;
    return 600;
  }

  String _nextGradeLabel(int score) {
    if (score >= 800) return 'Diamond';
    if (score >= 700) return 'Platinum';
    if (score >= 600) return 'Gold';
    if (score >= 500) return 'Silver';
    return 'Bronze';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final score = auth.linkScore;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0052FF)))
          : RefreshIndicator(
              color: const Color(0xFF0052FF),
              onRefresh: _loadHistory,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDarkHeader(score),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        children: [
                          _buildTrendChartCard(score),
                          const SizedBox(height: 12),
                          _buildRadarCard(),
                          const SizedBox(height: 12),
                          _buildInsightsCard(),
                          const SizedBox(height: 12),
                          _buildGradeGuideCard(score),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ─────────────────── DARK HEADER ───────────────────

  Widget _buildDarkHeader(int score) {
    return Container(
      color: const Color(0xFF050C1A),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Nav row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text('링크 스코어 분석',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text('점수가 어떻게 바뀌었는지',
                            style: TextStyle(
                                color: Color(0xFF93C5FD),
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Icon(Icons.share_outlined,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
            // Score ring
            const SizedBox(height: 8),
            SizedBox(
              width: 208,
              height: 208,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(208, 208),
                    painter: _ScoreRingPainter(score / 1000.0),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('링크 스코어',
                          style: TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text('$score',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5)),
                      const Text('/ 1000',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            // Badges row
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Grade badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _gradeGradient(score),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: _gradeGradient(score).last.withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.workspace_premium,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(_gradeLabel(score),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Change badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C27A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF00C27A).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up,
                          size: 12, color: Color(0xFF4ADE80)),
                      SizedBox(width: 4),
                      Text('+18점',
                          style: TextStyle(
                              color: Color(0xFF4ADE80),
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                      SizedBox(width: 4),
                      Text('지난달보다',
                          style: TextStyle(
                              color: Color(0x994ADE80),
                              fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Percentile badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: const Text('상위 12.3%',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('최근 업데이트 · ${DateFormat('yyyy.MM.dd').format(DateTime.now())}',
                style: const TextStyle(
                    color: Color(0x8093C5FD), fontSize: 11)),
            const SizedBox(height: 20),
            // 4 mini stat cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _miniStat(Icons.check_circle_outline,
                      '${(_reliabilityPct * 100).toStringAsFixed(0)}%',
                      '입금\n성실도', const Color(0xFF4ADE80)),
                  const SizedBox(width: 8),
                  _miniStat(Icons.group_outlined,
                      '${_moimCount + 12}회',
                      '총 모임\n참여', const Color(0xFF60A5FA)),
                  const SizedBox(width: 8),
                  _miniStat(Icons.bolt_outlined,
                      '12분',
                      '평균\n입금 속도', const Color(0xFFFCD34D)),
                  const SizedBox(width: 8),
                  _miniStat(Icons.workspace_premium_outlined,
                      '3회',
                      '연속\n약속 준수', const Color(0xFFF9A8D4)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0x66FFFFFF),
                    fontSize: 9.5,
                    height: 1.3)),
          ],
        ),
      ),
    );
  }

  // ─────────────────── 6-MONTH TREND CHART ───────────────────

  Widget _buildTrendChartCard(int score) {
    // Generate 6 months of data ending at current score
    final endScore = score.toDouble();
    final data = [
      endScore - 60,
      endScore - 47,
      endScore - 33,
      endScore - 25,
      endScore - 18,
      endScore,
    ];
    final months = ['10월', '11월', '12월', '1월', '2월', '3월'];
    final spots = List.generate(
        6, (i) => FlSpot(i.toDouble(), data[i].clamp(400.0, 1000.0)));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x140052FF),
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
                child: const Icon(Icons.show_chart,
                    size: 15, color: Color(0xFF0052FF)),
              ),
              const SizedBox(width: 10),
              const Text('6개월 점수 변화',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF111827))),
              const Spacer(),
              Row(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFF0052FF),
                          shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('링크 스코어',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 40,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: const Color(0xFFE5E7EB),
                    strokeWidth: 1,
                    dashArray: [4, 3],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(months[i],
                              style: TextStyle(
                                  color: i == 5
                                      ? const Color(0xFF0052FF)
                                      : const Color(0xFFD1D5DB),
                                  fontSize: 9,
                                  fontWeight: i == 5
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        );
                      },
                      reservedSize: 22,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF60A5FA), Color(0xFF0052FF)],
                    ),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x400052FF),
                          Color(0x000052FF),
                        ],
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, index) {
                        final isLast = index == spots.length - 1;
                        return FlDotCirclePainter(
                          radius: isLast ? 6 : 4,
                          color: isLast
                              ? const Color(0xFF0052FF)
                              : Colors.white,
                          strokeWidth: 2.5,
                          strokeColor: isLast
                              ? Colors.white
                              : const Color(0xFF0052FF)
                                  .withValues(alpha: 0.6 + index * 0.08),
                        );
                      },
                    ),
                  ),
                ],
                minY: (endScore - 80).clamp(300.0, 900.0),
                maxY: (endScore + 20).clamp(500.0, 1000.0),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: const [
                    Icon(Icons.trending_up,
                        size: 14, color: Color(0xFF00A864)),
                    SizedBox(width: 6),
                    Text('6개월간 ',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 12)),
                    Text('+60점 상승',
                        style: TextStyle(
                            color: Color(0xFF00A864),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('월평균 +10점',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 11)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────── RADAR CHART CARD ───────────────────

  Widget _buildRadarCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x140052FF),
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
                  color: const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.radar,
                    size: 15, color: Color(0xFF6366F1)),
              ),
              const SizedBox(width: 10),
              const Text('핵심 지표 분석',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF111827))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 171,
                height: 171,
                child: CustomPaint(
                  painter: _RadarPainter(
                    values: [
                      _reliabilityPct.clamp(0.0, 1.0),
                      (_moimCount / 12.0).clamp(0.0, 1.0),
                      0.95,
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _radarLegend('입금 성실도',
                        '${(_reliabilityPct * 100).toStringAsFixed(0)}%',
                        const Color(0xFF0052FF), _reliabilityPct),
                    const SizedBox(height: 16),
                    _radarLegend('참여 횟수',
                        '${((_moimCount / 12.0).clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%',
                        const Color(0xFF6366F1),
                        (_moimCount / 12.0).clamp(0.0, 1.0)),
                    const SizedBox(height: 16),
                    _radarLegend('입금 속도', '95%',
                        const Color(0xFF22C55E), 0.95),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFF3F4F6)),
                    const SizedBox(height: 8),
                    const Text('점수 구성',
                        style: TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 11)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          children: [
                            Expanded(
                                flex: 27,
                                child: Container(
                                    color: const Color(0xFF3B82F6))),
                            Expanded(
                                flex: 25,
                                child: Container(
                                    color: const Color(0xFF818CF8))),
                            Expanded(
                                flex: 28,
                                child: Container(
                                    color: const Color(0xFF22C55E))),
                            Expanded(
                                flex: 20,
                                child: Container(
                                    color: const Color(0xFFF472B6))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: const [
                        _ScoreLegendDot('성실도', Color(0xFF3B82F6)),
                        _ScoreLegendDot('참여', Color(0xFF818CF8)),
                        _ScoreLegendDot('속도', Color(0xFF22C55E)),
                        _ScoreLegendDot('리더십', Color(0xFFF472B6)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _radarLegend(
      String label, String value, Color color, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // ─────────────────── INSIGHTS CARD ───────────────────

  Widget _buildInsightsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x140052FF),
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
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 15, color: Color(0xFF00A864)),
              ),
              const SizedBox(width: 10),
              const Text('AI 분석 리포트',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF111827))),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('긍정적',
                    style: TextStyle(
                        color: Color(0xFF00A864),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _insightItem(
            Icons.bolt,
            const Color(0xFF15803D),
            const LinearGradient(colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)]),
            const Color(0xFFBBF7D0),
            '상위 5% 입금 속도',
            'TOP 5%',
            const Color(0xFF15803D),
            '평균 입금 시간 12분으로, 전체 사용자 평균 3.2시간보다 훨씬 빨라요.',
          ),
          const SizedBox(height: 10),
          _insightItem(
            Icons.check_circle_outline,
            const Color(0xFF1D4ED8),
            const LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)]),
            const Color(0xFFBFDBFE),
            '3번 연속 약속 준수',
            '완벽 달성',
            const Color(0xFF1D4ED8),
            '최근 3번의 모임에서 약속 시간을 모두 준수했습니다. 신뢰도 지수가 상승했어요.',
          ),
          const SizedBox(height: 10),
          _insightItem(
            Icons.bar_chart,
            const Color(0xFF6D28D9),
            const LinearGradient(colors: [Color(0xFFFAF5FF), Color(0xFFEDE9FE)]),
            const Color(0xFFDDD6FE),
            '꾸준한 활동가',
            '6개월 연속',
            const Color(0xFF6D28D9),
            '지난 6개월 연속 모임에 참여했어요. 꾸준한 활동으로 참여 점수가 꾸준히 오르고 있어요.',
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.lightbulb_outline,
                    size: 16, color: Color(0xFFD97706)),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('점수 향상 팁',
                          style: TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text(
                          '모임 주최자(리더)로 활동하면 리더십 점수가 올라요. 다음 모임에서 직접 만들어보세요! +20점 예상',
                          style: TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 11,
                              height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightItem(
    IconData icon,
    Color iconColor,
    Gradient bg,
    Color border,
    String title,
    String badge,
    Color badgeColor,
    String body,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(badge,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── GRADE GUIDE CARD ───────────────────

  Widget _buildGradeGuideCard(int score) {
    final nextTarget = _nextGradeTarget(score);
    final prevTarget = nextTarget - 100;
    final progress = (score - prevTarget) / 100.0;
    final remaining = nextTarget - score;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x140052FF),
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
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspace_premium,
                    size: 15, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 10),
              const Text('신용 등급 가이드',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF111827))),
            ],
          ),
          const SizedBox(height: 20),
          // Grade gradient bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 12,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFCD7F32),
                    Color(0xFF9CA3AF),
                    Color(0xFFFFD700),
                    Color(0xFF00A864),
                    Color(0xFF67E8F9),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Bronze',
                  style: TextStyle(
                      color: Color(0xFFCD7F32),
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
              Text('Silver',
                  style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
              Text('GOLD',
                  style: TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
              Text('Platinum',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
              Text('Diamond',
                  style: TextStyle(
                      color: Color(0xFF67E8F9),
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: const Color(0xFFFDE047)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on,
                      size: 11, color: Color(0xFFCA8A04)),
                  const SizedBox(width: 4),
                  Text('현재 ${score}점 · ${_gradeEn(score)}',
                      style: const TextStyle(
                          color: Color(0xFF854D0E),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Next tier progress
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.track_changes,
                        size: 14, color: Color(0xFF0369A1)),
                    const SizedBox(width: 6),
                    Text('다음 등급: ${_nextGradeLabel(score)}',
                        style: const TextStyle(
                            color: Color(0xFF1E40AF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('$remaining점 남음',
                        style: const TextStyle(
                            color: Color(0xFF0052FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFDBEAFE),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF0052FF)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('${nextTarget}점 달성 시 ${_nextGradeLabel(score)} 승급',
                      style: const TextStyle(
                          color: Color(0xFF60A5FA), fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('${_gradeEn(score)} 등급 혜택',
              style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ..._gradeBenefits(score).map((b) => _benefitTile(
              b.$1, b.$2, b.$3, b.$4, b.$5, locked: b.$6)),
        ],
      ),
    );
  }

  List<(IconData, String, String, Color, String, bool)> _gradeBenefits(
      int score) {
    final amber = const Color(0xFFFFF7ED);
    final amberBorder = const Color(0xFFFED7AA);
    final amberIcon = const Color(0xFFB45309);
    final activeText = const Color(0xFFD97706);

    return [
      (Icons.shield_outlined, '버퍼 금액 5% 면제', '다음 모임 에스크로 버퍼 자동 면제',
          amberIcon, '활성', false),
      (Icons.group_outlined, '모임 최대 인원 15명', '기본 10명 → GOLD 회원 15명 확장',
          amberIcon, '활성', false),
      (Icons.account_balance_outlined, '에스크로 한도 200만원',
          '기본 50만원 → GOLD 회원 200만원', amberIcon, '활성', false),
      (Icons.lock_outline, '즉시 환급 서비스', 'Platinum 이상 · T+0 즉시 환급',
          const Color(0xFF9CA3AF), '잠금', true),
    ];
  }

  Widget _benefitTile(IconData icon, String title, String subtitle,
      Color iconColor, String status,
      {required bool locked}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: locked ? const Color(0xFFF9FAFB) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: locked
                ? const Color(0xFFF3F4F6)
                : const Color(0xFFFED7AA)),
      ),
      child: Opacity(
        opacity: locked ? 0.5 : 1.0,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    locked ? const Color(0xFFF3F4F6) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 11)),
                ],
              ),
            ),
            Text(status,
                style: TextStyle(
                    color: locked
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFFD97706),
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────── PAINTERS ───────────────────

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  _ScoreRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // Outer decorative ring
    canvas.drawCircle(
      center,
      size.width * 0.465,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14,
    );

    // Score arc with gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = 2 * math.pi * progress;
    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF0052FF), Color(0xFF60A5FA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
        rect, -math.pi / 2, sweepAngle, false, gradientPaint);

    // Tick marks every 10%
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 2;
    for (int i = 1; i < 10; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / 10;
      final outerR = size.width * 0.5;
      final innerR = outerR - 10;
      canvas.drawLine(
        Offset(center.dx + innerR * math.cos(angle),
            center.dy + innerR * math.sin(angle)),
        Offset(center.dx + outerR * math.cos(angle),
            center.dy + outerR * math.sin(angle)),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.progress != progress;
}

class _RadarPainter extends CustomPainter {
  final List<double> values; // 3 values [0..1]
  _RadarPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.55;
    final maxR = size.width * 0.35;

    // Axis angles: top, bottom-left, bottom-right
    final angles = [
      -math.pi / 2,
      -math.pi / 2 + 2 * math.pi / 3,
      -math.pi / 2 + 4 * math.pi / 3,
    ];

    // Grid
    for (int level = 1; level <= 4; level++) {
      final r = maxR * level / 4;
      final pts = angles.map((a) => Offset(cx + r * math.cos(a), cy + r * math.sin(a))).toList();
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (final p in pts.skip(1)) path.lineTo(p.dx, p.dy);
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = level == 4
              ? const Color(0xFFD1D5DB)
              : const Color(0xFFE5E7EB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = level == 4 ? 1.5 : 1,
      );
    }

    // Axes
    for (final a in angles) {
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + maxR * math.cos(a), cy + maxR * math.sin(a)),
        Paint()
          ..color = const Color(0xFFE5E7EB)
          ..strokeWidth = 1,
      );
    }

    // Data polygon
    final dataPoints = List.generate(3, (i) {
      final r = maxR * values[i];
      return Offset(cx + r * math.cos(angles[i]), cy + r * math.sin(angles[i]));
    });
    final dataPath = Path()..moveTo(dataPoints[0].dx, dataPoints[0].dy);
    for (final p in dataPoints.skip(1)) dataPath.lineTo(p.dx, p.dy);
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x800052FF), Color(0x260052FF)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = const Color(0xFF0052FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    // Data vertices
    final dotColors = [
      const Color(0xFF0052FF),
      const Color(0xFF6366F1),
      const Color(0xFF00A864),
    ];
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
          dataPoints[i],
          4,
          Paint()..color = dotColors[i]);
      canvas.drawCircle(
          dataPoints[i],
          4,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // Axis labels
    final labels = ['입금 성실도', '참여 횟수', '입금 속도'];
    final labelOffsets = [
      Offset(cx, cy - maxR - 14),
      Offset(cx - maxR * 0.87 - 10, cy + maxR * 0.5 + 14),
      Offset(cx + maxR * 0.87 + 10, cy + maxR * 0.5 + 14),
    ];
    final alignments = [
      TextAlign.center,
      TextAlign.right,
      TextAlign.left,
    ];

    for (int i = 0; i < 3; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: alignments[i],
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout(maxWidth: 60);
      tp.paint(
          canvas,
          Offset(labelOffsets[i].dx - tp.width / 2,
              labelOffsets[i].dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.values[0] != values[0] ||
      old.values[1] != values[1] ||
      old.values[2] != values[2];
}

class _ScoreLegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _ScoreLegendDot(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 10)),
      ],
    );
  }
}
