import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/moim_provider.dart';
import '../models/moim_response.dart';
import '../models/participant_response.dart';
import '../models/payment_response.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _fmt = NumberFormat('#,###');
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prov = context.read<MoimProvider>();
      await prov.loadMyMoims();
      if (prov.moims.isNotEmpty) {
        final firstId = prov.moims.first.id;
        await Future.wait([
          prov.loadPayments(firstId),
          prov.loadParticipants(firstId),
        ]);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    final prov = context.read<MoimProvider>();
    await prov.loadMyMoims();
    if (prov.moims.isNotEmpty) {
      final firstId = prov.moims.first.id;
      await Future.wait([
        prov.loadPayments(firstId),
        prov.loadParticipants(firstId),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final moimProv = context.watch<MoimProvider>();

    // 대시보드 상단 카드 = ACTIVE 우선, 없으면 첫 번째 모임
    final activeMoim = moimProv.moims.isNotEmpty
        ? (moimProv.moims.firstWhere(
            (m) => m.status == 'ACTIVE',
            orElse: () => moimProv.moims.first,
          ))
        : null;
    final allMoims = moimProv.moims;
    final participants = moimProv.participants;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      floatingActionButton: _buildFab(activeMoim),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomAppBar(activeMoim),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0052FF),
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroHeader(auth),
                Transform.translate(
                  offset: const Offset(0, -16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (moimProv.loading && activeMoim == null)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(
                                  color: Color(0xFF0052FF)),
                            ),
                          )
                        else if (activeMoim != null)
                          _buildActiveEscrowCard(activeMoim, participants)
                        else
                          _buildEmptyCard(),
                        const SizedBox(height: 16),
                        _buildQuickActionsCard(activeMoim),
                        const SizedBox(height: 16),
                        _buildNettingBanner(),
                        const SizedBox(height: 16),
                        _buildActivityHistory(moimProv.payments),
                        const SizedBox(height: 16),
                        if (allMoims.isNotEmpty)
                          _buildOtherGroupsCard(allMoims),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFab(MoimResponse? activeMoim) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x660052FF), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: activeMoim != null
              ? () => context.push('/moims/${activeMoim.id}/pay')
              : () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('먼저 모임에 참여하세요')),
                  ),
          child: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  BottomAppBar _buildBottomAppBar(MoimResponse? activeMoim) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      elevation: 0,
      padding: EdgeInsets.zero,
      height: 64,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_rounded, '홈', true, () {}),
            _navItem(Icons.group_add_outlined, '모임 만들기', false,
                () => context.push('/moims/create')),
            // 중앙 FAB 공간 + "QR 결제" 라벨
            SizedBox(
              width: 72,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text('QR 결제',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  SizedBox(height: 6),
                ],
              ),
            ),
            _navItem(
              Icons.receipt_long_outlined,
              '정산 내역',
              false,
              () {
                if (activeMoim != null) {
                  context.push('/moims/${activeMoim.id}');
                }
              },
            ),
            _navItem(Icons.person_outline_rounded, '내 정보', false,
                _showProfileDialog),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
      IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    color: active
                        ? const Color(0xFF0052FF)
                        : const Color(0xFF9CA3AF),
                    size: 24),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        color: active
                            ? const Color(0xFF0052FF)
                            : const Color(0xFF9CA3AF),
                        fontSize: 11,
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.normal)),
              ],
            ),
          ),
          if (active)
            Positioned(
              top: -4,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0052FF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(AuthProvider auth) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF003ED4), Color(0xFF0052FF), Color(0xFF2B7FFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('안녕하세요 👋',
                      style: TextStyle(
                          color: Color(0xFFBFD7FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('${auth.username ?? ''} 님',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 20),
                  ),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF87171),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF0052FF), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildLinkScoreCard(auth.linkScore),
        ],
      ),
    );
  }

  Widget _buildLinkScoreCard(int score) {
    final progress = (score / 1000.0).clamp(0.0, 1.0);
    final gradeName = _gradeName(score);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('링크 스코어',
                            style: TextStyle(
                                color: Color(0xFFBFD7FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(gradeName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$score',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                height: 1)),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4, left: 4),
                          child: Text('/ 1000',
                              style: TextStyle(
                                  color: Color(0xFF93C5FD), fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.arrow_upward,
                            color: Color(0xFF86EFAC), size: 12),
                        SizedBox(width: 4),
                        Text('+18점',
                            style: TextStyle(
                                color: Color(0xFF86EFAC),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Text('지난달보다',
                            style: TextStyle(
                                color: Color(0xFF93C5FD), fontSize: 12)),
                      ],
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
                        painter: _ScoreRingPainter(progress),
                        child: Center(
                          child: Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('신용도',
                        style: TextStyle(
                            color: Color(0xFF93C5FD), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('낮음',
                      style: TextStyle(
                          color: Color(0xFF93C5FD), fontSize: 11)),
                  Text('보통',
                      style: TextStyle(
                          color: Color(0xFF93C5FD), fontSize: 11)),
                  Text('좋음',
                      style: TextStyle(
                          color: Color(0xFF93C5FD), fontSize: 11)),
                  Text('아주 좋음',
                      style: TextStyle(
                          color: Color(0xFF93C5FD), fontSize: 11)),
                ],
              ),
              const SizedBox(height: 4),
              LayoutBuilder(builder: (ctx, constraints) {
                return Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 8,
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Colors.white, Color(0xFFBFD7FF)]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('0',
                      style: TextStyle(
                          color: Color(0xFF93C5FD), fontSize: 11)),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text('$score',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Text('1000',
                      style: TextStyle(
                          color: Color(0xFF93C5FD), fontSize: 11)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveEscrowCard(MoimResponse moim, List<ParticipantResponse> participants) {
    final statusColor = _statusColor(moim.status);
    final statusLabel = _statusLabel(moim.status);
    final progress = moim.depositRate.clamp(0.0, 1.0);
    final paidCount = participants.isNotEmpty
        ? participants.where((p) => p.isDeposited).length
        : (progress * moim.targetParticipantCount).round();
    final displayParticipants = participants.isNotEmpty
        ? participants.take(5).toList()
        : <ParticipantResponse>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A0052FF), blurRadius: 24, offset: Offset(0, 4)),
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
                child: const Icon(Icons.account_balance_wallet_outlined,
                    color: Color(0xFF0052FF), size: 16),
              ),
              const SizedBox(width: 8),
              const Text('에스크로 가상계좌',
                  style: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const Spacer(),
              _statusBadge(statusLabel, statusColor, moim.status == 'ACTIVE'),
            ],
          ),
          const SizedBox(height: 12),
          const Text('모임명',
              style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () async {
              await Future.delayed(const Duration(milliseconds: 350));
              if (context.mounted) context.push('/moims/${moim.id}');
            },
            child: Text('${moim.emoji ?? '🎉'} ${moim.title}',
                style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFEEF2FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('가상계좌 잔액',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_fmt.format(moim.totalDeposited.toInt()),
                        style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4, left: 4),
                      child: Text('원',
                          style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('목표 ',
                        style: TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 12)),
                    Text('${_fmt.format(moim.targetAmount.toInt())}원',
                        style: const TextStyle(
                            color: Color(0xFF0052FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const Text(' · ',
                        style: TextStyle(
                            color: Color(0xFFD1D5DB), fontSize: 12)),
                    Text(
                        '${(progress * 100).toStringAsFixed(0)}% 달성',
                        style: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('입금 현황',
                  style: TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Text('$paidCount / ${moim.targetParticipantCount}명 완료',
                  style: const TextStyle(
                      color: Color(0xFF0052FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ...( displayParticipants.isNotEmpty
                ? displayParticipants.map((p) {
                    final paid = p.isDeposited;
                    final isKorean = RegExp(r'[가-힣]').hasMatch(p.username);
                    final nameLabel = isKorean
                        ? p.username.substring(0, p.username.length >= 2 ? 2 : 1)
                        : p.username.isNotEmpty
                            ? p.username[0].toUpperCase()
                            : '?';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: paid
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: paid
                                    ? const Color(0xFFBFD7FF)
                                    : const Color(0xFFE5E7EB),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                nameLabel,
                                style: TextStyle(
                                  color: paid
                                      ? Colors.white
                                      : const Color(0xFF9CA3AF),
                                  fontSize: isKorean ? 11 : 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: paid
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFD1D5DB),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList()
                : List.generate(
                    moim.targetParticipantCount.clamp(0, 5),
                    (i) {
                      final paid = i < paidCount;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: paid
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFFF3F4F6),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: paid
                                      ? const Color(0xFFBFD7FF)
                                      : const Color(0xFFE5E7EB),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: paid
                                        ? Colors.white
                                        : const Color(0xFF9CA3AF),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: paid
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFFD1D5DB),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
              ),
              const Spacer(),
              if (paidCount < moim.targetParticipantCount)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.notifications_outlined,
                          size: 12, color: Color(0xFF0052FF)),
                      SizedBox(width: 4),
                      Text('재촉하기',
                          style: TextStyle(
                              color: Color(0xFF0052FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: moim.targetParticipantCount > 0
                  ? (paidCount / moim.targetParticipantCount).clamp(0.0, 1.0)
                  : progress,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0052FF)),
              minHeight: 8,
            ),
          ),
          if (moim.virtualAccountNumber != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('가상 계좌번호',
                            style: TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 11)),
                        Text(
                            '${moim.virtualAccountBank ?? ''} ${moim.virtualAccountNumber ?? ''}',
                            style: const TextStyle(
                                color: Color(0xFF374151),
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(
                          text: moim.virtualAccountNumber!));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('계좌번호가 복사되었습니다'),
                              duration: Duration(seconds: 1)));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('복사',
                          style: TextStyle(
                              color: Color(0xFF0052FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color, bool live) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(MoimResponse? activeMoim) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A0052FF), blurRadius: 24, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('퀵 액션',
              style: TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: activeMoim != null
                ? () => context.push('/moims/${activeMoim.id}/pay')
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x3D0052FF),
                      blurRadius: 20,
                      offset: Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('결제용 QR 생성',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                height: 1.2)),
                        SizedBox(height: 2),
                        Text('가상계좌 잔액으로 바로 결제',
                            style: TextStyle(
                                color: Color(0xFFBFD7FF), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _secondaryAction(Icons.add_circle_outline_rounded, '모임 만들기', () {
                context.push('/moims/create');
              }),
              const SizedBox(width: 12),
              _secondaryAction(Icons.add_rounded, '입금하기', () {
                if (activeMoim?.virtualAccountNumber != null) {
                  Clipboard.setData(ClipboardData(
                      text: activeMoim!.virtualAccountNumber!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('계좌번호가 복사되었습니다'),
                      duration: Duration(seconds: 1)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('참여 중인 모임이 없습니다'),
                      duration: Duration(seconds: 1)));
                }
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _secondaryAction(Icons.people_outline_rounded, '멤버 초대', () {
                if (activeMoim != null) {
                  _showInviteDialog(activeMoim.inviteCode);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('참여 중인 모임이 없습니다'),
                      duration: Duration(seconds: 1)));
                }
              }),
              const SizedBox(width: 12),
              _secondaryAction(Icons.receipt_long_outlined, '정산하기', () {
                if (activeMoim != null) {
                  context.push('/moims/${activeMoim.id}');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('정산할 모임이 없습니다. 먼저 모임을 만들어보세요'),
                      duration: Duration(seconds: 2)));
                }
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _secondaryAction(
      IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 8,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Icon(icon,
                    color: const Color(0xFF6B7280), size: 20),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNettingBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFEFF6FF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDEE8FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt_rounded,
                color: Color(0xFF0052FF), size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('넷팅 자동 정산 예약됨',
                    style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('모임 종료 시 잔액이 1/n로 자동 환급돼요',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text('D-2',
                style: TextStyle(
                    color: Color(0xFFD97706),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityHistory(List<PaymentResponse> payments) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A0052FF), blurRadius: 24, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('최근 활동 내역',
                  style: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Text('전체 보기',
                  style: TextStyle(
                      color: Color(0xFF0052FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          if (payments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('아직 결제 내역이 없어요',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 13)),
              ),
            )
          else
            ...payments.take(5).map(_buildActivityItem),
        ],
      ),
    );
  }

  Widget _buildActivityItem(PaymentResponse payment) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code,
                  color: Color(0xFFF87171), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(payment.merchantName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      if (payment.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(payment.category!,
                              style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 11)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_formatDate(payment.approvedAt),
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 11)),
                ],
              ),
            ),
            Text('-${_fmt.format(payment.amount.toInt())}원',
                style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
        Container(
          height: 1,
          margin:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          color: const Color(0xFFF9FAFB),
        ),
      ],
    );
  }

  Widget _buildOtherGroupsCard(List<MoimResponse> moims) {
    // 상태별 정렬: ACTIVE → OPEN → SETTLING → CLOSED → CANCELLED
    final sorted = [...moims]..sort((a, b) {
        const order = {'ACTIVE': 0, 'OPEN': 1, 'SETTLING': 2, 'CLOSED': 3, 'CANCELLED': 4};
        return (order[a.status] ?? 9).compareTo(order[b.status] ?? 9);
      });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A0052FF), blurRadius: 24, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('모임 목록',
                      style: TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${sorted.length}',
                        style: const TextStyle(
                            color: Color(0xFF0052FF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.push('/moims/create'),
                child: const Text('+ 새 모임',
                    style: TextStyle(
                        color: Color(0xFF0052FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...sorted.map(_buildOtherGroupItem),
        ],
      ),
    );
  }

  Widget _buildOtherGroupItem(MoimResponse moim) {
    final statusColor = _statusColor(moim.status);
    final statusLabel = _statusLabel(moim.status);
    final isActive = moim.status == 'ACTIVE';
    final isOpen = moim.status == 'OPEN';

    return GestureDetector(
      onTap: () async {
        await Future.delayed(const Duration(milliseconds: 350));
        if (context.mounted) context.push('/moims/${moim.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFEEF2FF)
              : isOpen
                  ? const Color(0xFFF0FFF7)
                  : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(color: const Color(0xFF0052FF).withOpacity(0.25))
              : isOpen
                  ? Border.all(color: const Color(0xFF00A864).withOpacity(0.25))
                  : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isActive
                      ? [const Color(0xFF0038CC), const Color(0xFF0052FF)]
                      : isOpen
                          ? [const Color(0xFF00A864), const Color(0xFF34D399)]
                          : [const Color(0xFF9CA3AF), const Color(0xFF6B7280)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(moim.emoji ?? '🎉',
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(moim.title,
                      style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(
                      '${moim.targetParticipantCount}명 · ${_fmt.format(moim.totalDeposited.toInt())}원 적립',
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _statusBadge(statusLabel, statusColor, false),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A0052FF), blurRadius: 24, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.group_outlined,
                color: Color(0xFF0052FF), size: 32),
          ),
          const SizedBox(height: 16),
          const Text('아직 참여 중인 모임이 없어요',
              style: TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 6),
          const Text('새 모임을 만들거나 초대코드로 참여해보세요',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0052FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => context.push('/moims/create'),
                child: const Text('모임 만들기'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0052FF)),
                  foregroundColor: const Color(0xFF0052FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showJoinDialog(context),
                child: const Text('모임 참여'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('초대 코드',
            style: TextStyle(
                color: Color(0xFF111827), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(code,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: Color(0xFF0052FF))),
            ),
            const SizedBox(height: 12),
            const Text('이 코드를 친구에게 공유하세요',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('초대 코드가 복사되었습니다')));
            },
            child: const Text('복사',
                style: TextStyle(color: Color(0xFF0052FF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('모임 참여',
            style: TextStyle(
                color: Color(0xFF111827), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: codeCtrl,
          style: const TextStyle(color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: '초대코드 6자리',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: const Color(0xFFF0F4FF),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF0052FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
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
                    SnackBar(
                        content:
                            Text(provider.error ?? '참여에 실패했습니다')));
              }
            },
            child: const Text('참여하기'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    final auth = context.read<AuthProvider>();
    final score = auth.linkScore;
    final grade = _gradeName(score);
    final gradeColor = score >= 900
        ? const Color(0xFF06B6D4)
        : score >= 800
            ? const Color(0xFF8B5CF6)
            : score >= 700
                ? const Color(0xFFD97706)
                : score >= 600
                    ? const Color(0xFF6B7280)
                    : const Color(0xFFB45309);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더 (그라디언트)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF003ED4), Color(0xFF0052FF), Color(0xFF2B7FFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (auth.username ?? 'U').substring(0, 1),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${auth.username ?? ''} 님',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: gradeColor.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.4)),
                                ),
                                child: Text(
                                  grade,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '링크스코어 $score점',
                                style: const TextStyle(
                                    color: Color(0xFFBFD7FF), fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 스크롤 가능 콘텐츠
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  children: [
                    // 링크스코어 카드
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/link-score');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDEE8FF)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0052FF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.analytics_outlined,
                                  color: Color(0xFF0052FF), size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('링크 스코어 분석',
                                      style: TextStyle(
                                          color: Color(0xFF111827),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  SizedBox(height: 2),
                                  Text('상세 분석 및 등급 혜택 확인',
                                      style: TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: Color(0xFF9CA3AF)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 메뉴 리스트
                    _profileMenuItem(
                      Icons.notifications_outlined,
                      '알림 설정',
                      '결제·정산 알림 관리',
                      const Color(0xFF6366F1),
                      () => Navigator.pop(ctx),
                    ),
                    _profileMenuItem(
                      Icons.security_outlined,
                      '보안 설정',
                      '비밀번호, 생체인증 관리',
                      const Color(0xFF10B981),
                      () => Navigator.pop(ctx),
                    ),
                    _profileMenuItem(
                      Icons.help_outline_rounded,
                      '고객센터',
                      '문의 및 도움말',
                      const Color(0xFFF59E0B),
                      () => Navigator.pop(ctx),
                    ),
                    const SizedBox(height: 8),
                    // 로그아웃 버튼
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await auth.logout();
                        if (mounted) context.go('/login');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.logout_rounded,
                                  color: Color(0xFFEF4444), size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Text('로그아웃',
                                style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileMenuItem(
      IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  String _gradeName(int score) {
    if (score >= 800) return '아주 좋음';
    if (score >= 600) return '좋음';
    if (score >= 400) return '보통';
    return '낮음';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return const Color(0xFF00A864);
      case 'ACTIVE':
        return const Color(0xFF0052FF);
      case 'SETTLING':
        return const Color(0xFFD97706);
      case 'CLOSED':
        return const Color(0xFF9CA3AF);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'OPEN':
        return '입금 대기';
      case 'ACTIVE':
        return '진행 중';
      case 'SETTLING':
        return '진행 중';
      case 'CLOSED':
        return '완료';
      default:
        return status;
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MM.dd HH:mm').format(dt.toLocal());
    } catch (_) {
      return dateStr;
    }
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  _ScoreRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -2.356,
      4.712,
      false,
      bgPaint,
    );

    if (progress > 0) {
      final fgPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -2.356,
        4.712 * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.progress != progress;
}
