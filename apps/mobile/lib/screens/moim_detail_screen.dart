import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/moim_response.dart';
import '../models/participant_response.dart';
import '../models/payment_response.dart';
import '../providers/auth_provider.dart';
import '../providers/moim_provider.dart';
import 'qr_payment_screen.dart';
import 'settlement_result_screen.dart';

class MoimDetailScreen extends StatefulWidget {
  final int moimId;
  const MoimDetailScreen({super.key, required this.moimId});

  @override
  State<MoimDetailScreen> createState() => _MoimDetailScreenState();
}

class _MoimDetailScreenState extends State<MoimDetailScreen> {
  final _fmt = NumberFormat('#,###', 'ko_KR');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<MoimProvider>();
      Future.wait([
        prov.loadMoim(widget.moimId),
        prov.loadParticipants(widget.moimId),
        prov.loadPayments(widget.moimId),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MoimProvider>();
    final auth = context.watch<AuthProvider>();
    final moim = prov.selectedMoim;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: prov.loading && moim == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0052FF)))
          : moim == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFF9CA3AF), size: 48),
                      const SizedBox(height: 12),
                      const Text('모임을 불러올 수 없습니다',
                          style: TextStyle(color: Color(0xFF6B7280))),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('뒤로 가기',
                            style: TextStyle(color: Color(0xFF0052FF))),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF0052FF),
                  onRefresh: () async {
                    await prov.loadMoim(widget.moimId);
                    await prov.loadParticipants(widget.moimId);
                    await prov.loadPayments(widget.moimId);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildGradientHeader(moim, context),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (moim.virtualAccountNumber != null)
                                _buildVirtualAccount(moim),
                              if (moim.virtualAccountNumber != null)
                                const SizedBox(height: 16),
                              _buildProgress(moim),
                              const SizedBox(height: 16),
                              _buildParticipants(
                                  prov.participants, moim, auth),
                              const SizedBox(height: 16),
                              _buildPayments(prov.payments),
                              const SizedBox(height: 16),
                              if (moim.status == 'OPEN' ||
                                  moim.status == 'ACTIVE' ||
                                  moim.status == 'SETTLING' ||
                                  moim.status == 'CLOSED')
                                _buildActions(moim, auth, prov),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildGradientHeader(MoimResponse moim, BuildContext context) {
    final progress = moim.depositRate.clamp(0.0, 1.0);
    final pctText = '${(progress * 100).toStringAsFixed(0)}%';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF003ED4), Color(0xFF0052FF), Color(0xFF2B7FFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nav row
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const Expanded(
                    child: Text('에스크로 상세',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                  GestureDetector(
                    onTap: moim.status == 'OPEN'
                        ? () {
                            final prov = context.read<MoimProvider>();
                            final auth = context.read<AuthProvider>();
                            final isOrganizer = moim.creatorId != null &&
                                moim.creatorId == auth.userId;
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20))),
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE5E7EB),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ListTile(
                                      leading: const Icon(
                                          Icons.share_outlined,
                                          color: Color(0xFF0052FF)),
                                      title: const Text('초대 코드 공유',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _showInviteCode(moim.inviteCode);
                                      },
                                    ),
                                    if (isOrganizer)
                                      ListTile(
                                        leading: const Icon(
                                            Icons.cancel_outlined,
                                            color: Color(0xFFEF4444)),
                                        title: const Text('모임 취소',
                                            style: TextStyle(
                                                color: Color(0xFFEF4444),
                                                fontWeight: FontWeight.w600)),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          _confirmCancelMoim(moim, prov);
                                        },
                                      ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            );
                          }
                        : null,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.more_vert,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Group identity
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(moim.emoji ?? '📋',
                          style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(moim.title,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            _statusBadgeLight(moim.status),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${moim.targetParticipantCount}명 참여',
                          style: const TextStyle(
                              color: Color(0xFFBFDBFE),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Balance card with donut gauge
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('예치된 총금액',
                                  style: TextStyle(
                                      color: Color(0xFFBFDBFE),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _fmt.format(moim.totalDeposited.toInt()),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 4, left: 4),
                                    child: Text('원',
                                        style: TextStyle(
                                            color: Color(0xFFBFDBFE),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text('목표 ',
                                      style: TextStyle(
                                          color: Color(0xFFBFDBFE),
                                          fontSize: 12)),
                                  Text(
                                    '${_fmt.format(moim.targetAmount.toInt())}원',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const Text(' · ',
                                      style: TextStyle(
                                          color: Color(0x60BFDBFE),
                                          fontSize: 12)),
                                  Text('$pctText 달성',
                                      style: const TextStyle(
                                          color: Color(0xFF86EFAC),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Donut gauge
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(64, 64),
                                painter:
                                    _DonutGaugePainter(progress),
                              ),
                              Text(pctText,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFBFDBFE)),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('0원',
                            style: TextStyle(
                                color: Color(0xFFBFDBFE), fontSize: 11)),
                        Text(
                          '${_fmt.format(moim.targetAmount.toInt())}원',
                          style: const TextStyle(
                              color: Color(0xFFBFDBFE), fontSize: 11),
                        ),
                      ],
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

  Widget _headerStat(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      );

  Widget _headerStatDivider() => Container(
        width: 1,
        height: 28,
        color: Colors.white24,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  Widget _buildVirtualAccount(MoimResponse moim) {
    final depositedCount = moim.depositPerPerson > 0
        ? (moim.totalDeposited / moim.depositPerPerson).floor()
        : 0;
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_outlined,
                    color: Color(0xFF0052FF), size: 14),
              ),
              const SizedBox(width: 10),
              const Text('가상계좌 정보',
                  style: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          // Account card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0052FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('T',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(moim.virtualAccountBank ?? '토스뱅크',
                        style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Text('모임 전용 가상계좌',
                        style: TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('계좌번호',
                              style: TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(moim.virtualAccountNumber ?? '',
                              style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                            text: moim.virtualAccountNumber ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('계좌번호가 복사되었습니다')));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFBFDBFE), width: 2),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.copy_outlined,
                                color: Color(0xFF0052FF), size: 13),
                            SizedBox(width: 4),
                            Text('복사',
                                style: TextStyle(
                                    color: Color(0xFF0052FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(color: Color(0xFFBFDBFE))),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 13, color: Color(0xFF60A5FA)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '이 계좌로 입금하면 에스크로에 자동 반영돼요. 입금자명을 본인 이름으로 설정해주세요.',
                          style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 11,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 3-grid stats
          Row(
            children: [
              _accountStat('1인 목표',
                  '${_fmt.format(moim.depositPerPerson.toInt())}원',
                  const Color(0xFFF9FAFB), const Color(0xFF374151)),
              const SizedBox(width: 8),
              _accountStat('참여 인원',
                  '${moim.targetParticipantCount}명',
                  const Color(0xFFF9FAFB), const Color(0xFF374151)),
              const SizedBox(width: 8),
              _accountStat('입금 완료',
                  '${depositedCount}명',
                  const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accountStat(
      String label, String value, Color bgColor, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(MoimResponse moim) {
    final depositedCount = moim.depositPerPerson > 0
        ? (moim.totalDeposited / moim.depositPerPerson).floor()
        : 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A0052FF),
              blurRadius: 24,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('입금 현황',
                  style: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$depositedCount/${moim.targetParticipantCount}명',
                    style: const TextStyle(
                        color: Color(0xFF0052FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: moim.targetParticipantCount > 0
                  ? (depositedCount / moim.targetParticipantCount).clamp(0.0, 1.0)
                  : 0.0,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF0052FF)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _progressStat('총 입금',
                  '${_fmt.format(moim.totalDeposited.toInt())}원',
                  const Color(0xFF00A864)),
              _progressStat('총 지출',
                  '${_fmt.format(moim.totalSpent.toInt())}원',
                  const Color(0xFFEF4444)),
              _progressStat(
                  '잔액', '${_fmt.format(moim.balance.toInt())}원',
                  const Color(0xFF0052FF)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressStat(String label, String value, Color color) => Expanded(
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      );

  Widget _buildParticipants(List<ParticipantResponse> participants,
      MoimResponse moim, AuthProvider auth) {
    final paid = participants.where((p) => p.isDeposited).toList();
    final unpaid = participants.where((p) => !p.isDeposited).toList();
    final isOrganizer = moim.creatorId != null && moim.creatorId == auth.userId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A0052FF),
              blurRadius: 24,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('멤버 입금 현황',
                    style: TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${participants.length}명',
                      style: const TextStyle(
                          color: Color(0xFF0052FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (paid.isNotEmpty) ...[
                  ...paid.map((p) =>
                      _buildParticipantTile(p, moim, auth, isOrganizer)),
                ],
                if (unpaid.isNotEmpty) ...[
                  if (paid.isNotEmpty) const SizedBox(height: 8),
                  ...unpaid.map((p) =>
                      _buildParticipantTile(p, moim, auth, isOrganizer)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(ParticipantResponse p, MoimResponse moim,
      AuthProvider auth, bool isOrganizer) {
    final isMe = p.userId == auth.userId;
    final isPaid = p.isDeposited;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isPaid
            ? const Color(0xFFF0FFF7)
            : const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaid
              ? const Color(0xFFE8EFFF)
              : const Color(0xFFFFE4B5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isPaid
                  ? const Color(0xFF00A864).withOpacity(0.15)
                  : const Color(0xFFD97706).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(p.username[0].toUpperCase(),
                  style: TextStyle(
                      color: isPaid
                          ? const Color(0xFF00A864)
                          : const Color(0xFFD97706),
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(p.username,
                        style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    if (isMe)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('나',
                            style: TextStyle(
                                color: Color(0xFF0052FF), fontSize: 10)),
                      ),
                  ],
                ),
                Text('링크스코어 ${p.linkScore}',
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 11)),
              ],
            ),
          ),
          if (!isPaid && !isMe)
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${p.username}에게 입금 요청을 보냈습니다')));
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFFD97706).withOpacity(0.4)),
                ),
                child: const Text('입금 요청',
                    style: TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            )
          else
            _depositStatusBadge(p.depositStatus),
        ],
      ),
    );
  }

  Future<void> _confirmCancelMoim(
      MoimResponse moim, MoimProvider prov) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('모임 취소',
            style: TextStyle(
                color: Color(0xFF111827), fontWeight: FontWeight.bold)),
        content: Text(
          '"${moim.title}" 모임을 취소하시겠어요?\n\n입금된 금액은 각 참여자에게 환불됩니다.',
          style: const TextStyle(color: Color(0xFF6B7280), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('아니요',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('취소하기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await prov.cancelMoim(moim.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모임이 취소되었습니다')));
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(prov.error ?? '모임 취소에 실패했습니다')));
    }
  }

  Widget _buildActions(
      MoimResponse moim, AuthProvider auth, MoimProvider prov) {
    final isOrganizer = moim.creatorId != null && moim.creatorId == auth.userId;

    Widget cancelButton() => OutlinedButton.icon(
          onPressed: prov.loading ? null : () => _confirmCancelMoim(moim, prov),
          icon: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 18),
          label: const Text('모임 취소',
              style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (moim.status == 'ACTIVE') ...[
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF0038CC), Color(0xFF0052FF)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x330052FF),
                          blurRadius: 12,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              QrPaymentScreen(moimId: widget.moimId),
                        ),
                      ).then((_) => prov.loadMoim(widget.moimId));
                    },
                    icon: const Icon(Icons.qr_code_scanner,
                        color: Colors.white, size: 18),
                    label: const Text('QR 결제',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
              if (isOrganizer) ...[
                const SizedBox(width: 10),
                Expanded(child: cancelButton()),
              ],
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (moim.status == 'ACTIVE' || moim.status == 'SETTLING')
          ElevatedButton.icon(
            onPressed: prov.loading
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Text('정산하기',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${moim.emoji ?? '📋'} ${moim.title}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 8),
                            const Text(
                              '정산을 진행하면 에스크로 잔액을 바탕으로\n자동 정산이 완료됩니다.\n\n정산 후에는 되돌릴 수 없습니다.',
                              style: TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 13),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('취소',
                                style: TextStyle(color: Color(0xFF6B7280))),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0052FF),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('정산 진행',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !mounted) return;
                    // 로딩 다이얼로그 표시
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => Dialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 32, horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                  color: Color(0xFF0052FF)),
                              const SizedBox(height: 20),
                              const Text('정산 처리 중...',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 6),
                              const Text('에스크로 잔액을 정산하고 있습니다',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    );
                    // 최소 1.5초 로딩 보장
                    final results = await Future.wait([
                      prov.settle(widget.moimId),
                      Future.delayed(const Duration(milliseconds: 1500)),
                    ]);
                    if (!mounted) return;
                    Navigator.pop(context); // 로딩 다이얼로그 닫기
                    final result = results[0] as List<ParticipantResponse>;
                    if (result.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettlementResultScreen(
                            participants: result,
                            moimTitle: moim.title,
                            moimEmoji: moim.emoji ?? '📋',
                            totalSpent: moim.totalSpent,
                            participantCount: moim.targetParticipantCount,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(prov.error ?? '정산 실패')));
                    }
                  },
            icon: const Icon(Icons.calculate_outlined, color: Colors.white),
            label: const Text('정산하기',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        if (moim.status == 'CLOSED' && moim.totalSpent > 0)
          ElevatedButton.icon(
            onPressed: () {
              final participants = prov.participants;
              if (participants.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('참여자 정보를 불러오는 중입니다.')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettlementResultScreen(
                    participants: participants,
                    moimTitle: moim.title,
                    moimEmoji: moim.emoji ?? '📋',
                    totalSpent: moim.totalSpent,
                    participantCount: moim.targetParticipantCount,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined, color: Colors.white),
            label: const Text('정산 결과 보기',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        if (moim.status == 'OPEN') ...[
          // QR 결제 + 초대 코드 (2열)
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF0038CC), Color(0xFF0052FF)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x330052FF),
                          blurRadius: 12,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              QrPaymentScreen(moimId: widget.moimId),
                        ),
                      ).then((_) => prov.loadMoim(widget.moimId));
                    },
                    icon: const Icon(Icons.qr_code_scanner,
                        color: Colors.white, size: 18),
                    label: const Text('QR 결제',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showInviteCode(moim.inviteCode),
                  icon: const Icon(Icons.share_outlined,
                      color: Color(0xFF0052FF), size: 18),
                  label: const Text('초대 코드',
                      style: TextStyle(
                          color: Color(0xFF0052FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Color(0xFF0052FF), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
          // 모임 취소 (방장만, 전폭)
          if (isOrganizer) ...[
            const SizedBox(height: 10),
            cancelButton(),
          ],
        ],
      ],
    );
  }

  Widget _buildPayments(List<PaymentResponse> payments) {
    final fmt = NumberFormat('#,###');
    final dateFmt = DateFormat('MM.dd HH:mm');

    IconData categoryIcon(String? category) {
      switch (category) {
        case '숙박':
          return Icons.hotel_outlined;
        case '교통':
          return Icons.directions_car_outlined;
        case '식비':
          return Icons.restaurant_outlined;
        case '장소':
          return Icons.place_outlined;
        case '쇼핑':
          return Icons.shopping_bag_outlined;
        default:
          return Icons.receipt_long_outlined;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A0052FF),
              blurRadius: 24,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_outlined,
                          color: Color(0xFF0052FF), size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Text('지출 내역',
                        style: TextStyle(
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('총 ${payments.length}건',
                      style: const TextStyle(
                          color: Color(0xFF0052FF), fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          if (payments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.receipt_outlined,
                        color: Color(0xFF9CA3AF), size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text('아직 지출 내역이 없어요',
                      style: TextStyle(
                          color: Color(0xFF6B7280), fontSize: 14)),
                ],
              ),
            )
          else
            ...payments.map((p) {
              final dt = DateTime.tryParse(p.approvedAt);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        categoryIcon(p.category),
                        color: const Color(0xFF0052FF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.merchantName,
                              style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (p.category != null)
                                Container(
                                  margin:
                                      const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: Text(p.category!,
                                      style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 10)),
                                ),
                              if (dt != null)
                                Text(dateFmt.format(dt.toLocal()),
                                    style: const TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '-${fmt.format(p.amount.toInt())}원',
                      style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showInviteCode(String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text('초대 코드',
                style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD0DBFF)),
              ),
              child: Text(code,
                  style: const TextStyle(
                      color: Color(0xFF0052FF),
                      fontSize: 32,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('초대 코드가 복사되었습니다')));
                },
                icon: const Icon(Icons.copy, color: Colors.white),
                label: const Text('복사하기',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0052FF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettlementDialog(List participants) {
    final fmt = NumberFormat('#,###', 'ko_KR');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('정산 완료',
            style: TextStyle(
                color: Color(0xFF111827), fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: participants.length,
            itemBuilder: (_, i) {
              final p = participants[i];
              final refund = p.refundAmount ?? 0.0;
              return ListTile(
                title: Text(p.username,
                    style: const TextStyle(color: Color(0xFF111827))),
                trailing: Text(
                  refund > 0
                      ? '+${fmt.format(refund.toInt())}원'
                      : '${fmt.format(refund.toInt())}원',
                  style: TextStyle(
                      color: refund > 0
                          ? const Color(0xFF00A864)
                          : const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _statusBadgeLight(String status) {
    final colors = {
      'OPEN': const Color(0xFF00A864),
      'ACTIVE': const Color(0xFF0052FF),
      'SETTLING': const Color(0xFF0052FF),
      'CLOSED': const Color(0xFF9CA3AF),
      'CANCELLED': const Color(0xFFEF4444),
    };
    final labels = {
      'OPEN': '입금 대기',
      'ACTIVE': '진행 중',
      'SETTLING': '진행 중',
      'CLOSED': '완료',
      'CANCELLED': '취소',
    };
    final c = colors[status] ?? const Color(0xFF9CA3AF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(labels[status] ?? status,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _statusBadge(String status) {
    final colors = {
      'OPEN': const Color(0xFF00A864),
      'ACTIVE': const Color(0xFF0052FF),
      'SETTLING': const Color(0xFF0052FF),
      'CLOSED': const Color(0xFF9CA3AF),
      'CANCELLED': const Color(0xFFEF4444),
    };
    final labels = {
      'OPEN': '입금 대기',
      'ACTIVE': '진행 중',
      'SETTLING': '진행 중',
      'CLOSED': '완료',
      'CANCELLED': '취소',
    };
    final c = colors[status] ?? const Color(0xFF9CA3AF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(labels[status] ?? status,
          style: TextStyle(
              color: c, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _depositStatusBadge(String status) {
    switch (status) {
      case 'DEPOSITED':
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF00A864).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check,
              color: Color(0xFF00A864), size: 16),
        );
      case 'OVERDUE':
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning_amber,
              color: Color(0xFFEF4444), size: 16),
        );
      case 'REFUNDED':
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF0052FF).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.undo,
              color: Color(0xFF0052FF), size: 16),
        );
      default:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.radio_button_unchecked,
              color: Color(0xFF9CA3AF), size: 16),
        );
    }
  }
}

class _DonutGaugePainter extends CustomPainter {
  final double progress;
  _DonutGaugePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3.5;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      2 * 3.14159 * progress,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DonutGaugePainter old) => old.progress != progress;
}
