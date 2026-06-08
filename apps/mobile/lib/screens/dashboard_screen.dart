import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/moim_provider.dart';
import '../models/moim_response.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _fmt = NumberFormat('#,###');
  final _scrollCtrl = ScrollController();
  final _moimsKey = GlobalKey();
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MoimProvider>().loadMyMoims();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final moimProv = context.watch<MoimProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => moimProv.loadMyMoims(),
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(auth),
                const SizedBox(height: 20),
                _buildLinkScoreCard(auth.linkScore),
                const SizedBox(height: 16),
                _buildQuickActions(context),
                const SizedBox(height: 24),
                _buildMoimsList(moimProv, key: _moimsKey),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
      floatingActionButton: _navIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/moims/create'),
              backgroundColor: const Color(0xFF6366F1),
              icon: const Icon(Icons.add),
              label: const Text('모임 만들기'),
            )
          : null,
    );
  }

  Widget _buildHeader(AuthProvider auth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '안녕하세요, ${auth.username ?? ''}님 👋',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('오늘도 신뢰 있는 정산을 시작해봐요',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Color(0xFF64748B)),
          onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (mounted) context.go('/login');
          },
        ),
      ],
    );
  }

  Widget _buildLinkScoreCard(int score) {
    final grade = _getGrade(score);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('나의 링크스코어',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$score',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text(' / 1000',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(grade,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/link-score'),
            child: Column(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CustomPaint(
                    painter: _ScoreRingPainter(score / 1000),
                    child: Center(
                      child: Text(
                        '${(score / 10).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('상세보기',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        _quickBtn(Icons.group_add, '모임 참여', () => _showJoinDialog(context)),
        const SizedBox(width: 12),
        _quickBtn(Icons.list_alt, '내 모임', () {
          Scrollable.ensureVisible(
            _moimsKey.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }),
        const SizedBox(width: 12),
        _quickBtn(Icons.analytics_outlined, '링크스코어',
            () => context.push('/link-score')),
      ],
    );
  }

  Widget _quickBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF6366F1), size: 24),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoimsList(MoimProvider prov, {Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('내 모임',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (prov.loading)
          const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)))
        else if (prov.moims.isEmpty)
          _buildEmptyState()
        else
          ...prov.moims.map((m) => _buildMoimCard(m)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: const Column(
        children: [
          Icon(Icons.group_outlined, color: Color(0xFF475569), size: 48),
          SizedBox(height: 12),
          Text('아직 참여 중인 모임이 없어요',
              style: TextStyle(color: Color(0xFF94A3B8))),
          SizedBox(height: 4),
          Text('새 모임을 만들거나 초대코드로 참여해보세요',
              style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMoimCard(MoimResponse moim) {
    final statusColor = _statusColor(moim.status);
    final statusLabel = _statusLabel(moim.status);
    final progress = moim.depositRate.clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => context.push('/moims/${moim.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(moim.emoji ?? '🎉', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(moim.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text('초대코드: ${moim.inviteCode}',
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_fmt.format(moim.totalDeposited.toInt())}원 / ${_fmt.format(moim.targetAmount.toInt())}원',
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF334155),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return NavigationBar(
      backgroundColor: const Color(0xFF1E293B),
      selectedIndex: _navIndex,
      onDestinationSelected: (i) {
        setState(() => _navIndex = i);
        if (i == 1) context.push('/link-score');
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: '홈',
        ),
        NavigationDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics),
          label: '링크스코어',
        ),
      ],
    );
  }

  void _showJoinDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('모임 참여', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: codeCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '초대코드 6자리',
            hintStyle: const TextStyle(color: Color(0xFF475569)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF334155))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1)),
            onPressed: () async {
              final code = codeCtrl.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              final provider = context.read<MoimProvider>();
              final messenger = ScaffoldMessenger.of(context);
              final router = GoRouter.of(context);
              final moim = await provider.joinMoim(inviteCode: code);
              if (!mounted) return;
              if (moim != null) {
                router.push('/moims/${moim.id}');
              } else {
                messenger.showSnackBar(
                    SnackBar(content: Text(provider.error ?? '참여에 실패했습니다')));
              }
            },
            child: const Text('참여하기',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getGrade(int score) {
    if (score >= 900) return '💎 DIAMOND';
    if (score >= 800) return '🔮 PLATINUM';
    if (score >= 700) return '🥇 GOLD';
    if (score >= 600) return '🥈 SILVER';
    return '🥉 BRONZE';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return const Color(0xFF10B981);
      case 'ACTIVE':
        return const Color(0xFF3B82F6);
      case 'SETTLING':
        return const Color(0xFFF59E0B);
      case 'CLOSED':
        return const Color(0xFF64748B);
      case 'CANCELLED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'OPEN':
        return '모집중';
      case 'ACTIVE':
        return '진행중';
      case 'SETTLING':
        return '정산중';
      case 'CLOSED':
        return '완료';
      case 'CANCELLED':
        return '취소됨';
      default:
        return status;
    }
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  _ScoreRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 6.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      progress * 6.2832,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.progress != progress;
}
