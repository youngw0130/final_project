import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/participant_response.dart';
import '../providers/auth_provider.dart';

class SettlementResultScreen extends StatelessWidget {
  final List<ParticipantResponse> participants;
  final String moimTitle;
  final String moimEmoji;
  final double totalSpent;
  final int participantCount;

  const SettlementResultScreen({
    super.key,
    required this.participants,
    required this.moimTitle,
    required this.moimEmoji,
    required this.totalSpent,
    required this.participantCount,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final auth = context.watch<AuthProvider>();
    final me = participants.where((p) => p.userId == auth.userId).firstOrNull;
    final myRefund = me?.refundAmount ?? 0.0;
    final myDeposit = me?.depositAmount ?? 0.0;
    final sharePerPerson =
        participantCount > 0 ? totalSpent / participantCount : 0.0;
    final now = DateFormat('yyyy.MM.dd HH:mm:ss').format(DateTime.now());
    final receiptNo =
        'CN-${DateFormat('yyyyMMdd').format(DateTime.now())}-${(1000 + participants.length * 7).toString().padLeft(4, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF0052FF),
      body: Column(
        children: [
          // ── HEADER ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF003ED4), Color(0xFF0052FF), Color(0xFF2B7FFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back,
                                color: Colors.white, size: 20),
                          ),
                        ),
                        const Expanded(
                          child: Text('정산 리포트',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.share_outlined,
                              color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                  // Success indicator
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  blurRadius: 0,
                                  spreadRadius: 12),
                              BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  blurRadius: 0,
                                  spreadRadius: 24),
                            ],
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 44),
                        ),
                        const SizedBox(height: 16),
                        const Text('정산 완료! 🎉',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        const Text('모든 정산이 완료됐어요',
                            style: TextStyle(
                                color: Color(0xFFBFDBFE),
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.access_time,
                                size: 12,
                                color: Color(0x99BFDBFE)),
                            const SizedBox(width: 6),
                            Text('$now 처리완료',
                                style: const TextStyle(
                                    color: Color(0x99BFDBFE),
                                    fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── SCROLLABLE CONTENT ──
          Expanded(
            child: Container(
              color: const Color(0xFFF0F4FF),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    // Receipt card
                    _buildReceiptCard(
                        fmt, me, myRefund, myDeposit, sharePerPerson,
                        receiptNo, now),
                    const SizedBox(height: 12),
                    // Netting card
                    _buildNettingCard(participantCount),
                    const SizedBox(height: 12),
                    // Link score card
                    _buildLinkScoreCard(fmt),
                    const SizedBox(height: 20),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.share_outlined,
                                color: Color(0xFF0052FF), size: 16),
                            label: const Text('정산 내역 공유',
                                style: TextStyle(
                                    color: Color(0xFF0052FF),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(
                                  color: Color(0xFFBFDBFE), width: 2),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.go('/dashboard'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0052FF),
                                      Color(0xFF4D94FF)
                                    ]),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x550052FF),
                                      blurRadius: 24,
                                      offset: Offset(0, 8)),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.home_rounded,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('홈으로 돌아가기',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(
    NumberFormat fmt,
    ParticipantResponse? me,
    double myRefund,
    double myDeposit,
    double sharePerPerson,
    String receiptNo,
    String now,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        color: const Color(0xFFFAF9F7),
        child: Column(
          children: [
            // Perforated top edge simulation
            Container(
              height: 14,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0038CC), Color(0xFF2B7FFF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('CREDIT-N',
                                style: TextStyle(
                                    color: Color(0xFFB0ACA4),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.5)),
                            Text('에스크로 정산 영수증',
                                style: TextStyle(
                                    color: Color(0xFFC4C0B8), fontSize: 11)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('영수증 번호',
                                style: TextStyle(
                                    color: Color(0xFFC4C0B8), fontSize: 11)),
                            Text(receiptNo,
                                style: const TextStyle(
                                    color: Color(0xFF9C9890),
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _receiptDivider(),
                  // Meeting info
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0EDE8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(moimEmoji,
                                style: const TextStyle(fontSize: 20)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(moimTitle,
                                style: const TextStyle(
                                    color: Color(0xFF2D2A25),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            Text(
                                '${DateFormat('yyyy.MM.dd').format(DateTime.now())} · $participantCount명 참여',
                                style: const TextStyle(
                                    color: Color(0xFFA09C94),
                                    fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _receiptDivider(),
                  // Expense breakdown
                  const SizedBox(height: 16),
                  const Text('지출 내역',
                      style: TextStyle(
                          color: Color(0xFFA09C94),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  const SizedBox(height: 12),
                  _receiptRow('총 지출액 (QR 결제 합산)',
                      '${fmt.format(totalSpent.toInt())}원'),
                  const SizedBox(height: 8),
                  _receiptRow('참여 인원', '$participantCount명'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: const [
                            Text('1인 분담금',
                                style: TextStyle(
                                    color: Color(0xFF6B6760),
                                    fontSize: 14)),
                            SizedBox(width: 6),
                            // ÷N badge
                          ],
                        ),
                      ),
                      Text('${fmt.format(sharePerPerson.toInt())}원',
                          style: const TextStyle(
                              color: Color(0xFF2D2A25),
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _receiptDividerBold(),
                  // Settlement calculation
                  const SizedBox(height: 16),
                  const Text('정산 계산',
                      style: TextStyle(
                          color: Color(0xFFA09C94),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  const SizedBox(height: 12),
                  _receiptRow('내 예치금', '${fmt.format(myDeposit.toInt())}원'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('내 분담금',
                          style: TextStyle(
                              color: Color(0xFF6B6760), fontSize: 14)),
                      Text(
                          '−${fmt.format(sharePerPerson.toInt())}원',
                          style: const TextStyle(
                              color: Color(0xFFC0392B),
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 2,
                    color: const Color(0xFFA09C94),
                  ),
                  // Refund hero
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Text('최종 환급액 · 내 계좌로 입금',
                            style: TextStyle(
                                color: Color(0xFFA09C94),
                                fontSize: 11,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(fmt.format(myRefund.toInt()),
                                style: const TextStyle(
                                    color: Color(0xFF0052FF),
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -2)),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6, left: 4),
                              child: Text('원',
                                  style: TextStyle(
                                      color: Color(0xFF0052FF),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A864).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.north_east,
                                  size: 13, color: Color(0xFF00A864)),
                              const SizedBox(width: 6),
                              Text(
                                  '예치금 ${fmt.format(myDeposit.toInt())}원 → 환급 ${fmt.format(myRefund.toInt())}원',
                                  style: const TextStyle(
                                      color: Color(0xFF00A864),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _receiptDivider(),
                  // Refund account
                  if (me?.refundBank != null || me?.refundAccountNumber != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEB00),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text('K',
                                  style: TextStyle(
                                      color: Color(0xFF3C1E1E),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('환급 계좌',
                                    style: TextStyle(
                                        color: Color(0xFFA09C94),
                                        fontSize: 11)),
                                Text(
                                    '${me?.refundBank ?? ''} ${me?.refundAccountNumber ?? ''}',
                                    style: const TextStyle(
                                        color: Color(0xFF2D2A25),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A864).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFF00A864)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Text('입금 예정',
                                style: TextStyle(
                                    color: Color(0xFF00A864),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  _receiptDivider(),
                  // Transaction ID + stamp
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('거래 ID',
                                style: TextStyle(
                                    color: Color(0xFFC4C0B8), fontSize: 11)),
                            Text('$receiptNo-${participantCount}316',
                                style: const TextStyle(
                                    color: Color(0xFFA09C94),
                                    fontSize: 11,
                                    fontFamily: 'monospace')),
                            const Text('PortOne Escrow Settlement',
                                style: TextStyle(
                                    color: Color(0xFFC4C0B8), fontSize: 10)),
                          ],
                        ),
                        const Spacer(),
                        // Settled stamp
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF0052FF).withValues(alpha: 0.4),
                                width: 2),
                          ),
                          child: Center(
                            child: Text('정산\n완료',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: const Color(0xFF0052FF)
                                        .withValues(alpha: 0.55),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNettingCard(int count) {
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shuffle,
                    size: 15, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text('넷팅 알고리즘 효과',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF111827))),
            ],
          ),
          const SizedBox(height: 16),
          // Flow diagram
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Before
              Column(
                children: [
                  ...List.generate(
                      count.clamp(1, 5),
                      (_) => Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                                child: Text('😊', style: TextStyle(fontSize: 16))),
                          )),
                  const SizedBox(height: 4),
                  const Text('각자',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 10)),
                ],
              ),
              const SizedBox(width: 8),
              // CN hub
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x4D7C3AED),
                        blurRadius: 14,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.shuffle, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: Color(0xFF7C3AED)),
              const Icon(Icons.chevron_right,
                  color: Color(0xFF7C3AED)),
              const SizedBox(width: 4),
              // After
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.check_circle,
                              size: 14, color: Color(0xFF7C3AED)),
                          SizedBox(width: 4),
                          Text('자동 정산 완료',
                              style: TextStyle(
                                  color: Color(0xFF6D28D9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('1번 일괄 처리',
                          style: TextStyle(
                              color: Color(0xFF7C3AED),
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF3F0FF), Color(0xFFEEF2FF)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0D9FF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, size: 18, color: Color(0xFF7C3AED)),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          color: Color(0xFF4C1D95),
                          fontSize: 13,
                          height: 1.4),
                      children: [
                        const TextSpan(text: '복잡한 송금 '),
                        TextSpan(
                          text: '$count번',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900),
                        ),
                        const TextSpan(text: '을 크레딧-N이 '),
                        const TextSpan(
                          text: '1번으로',
                          style: TextStyle(
                              color: Color(0xFF7C3AED),
                              fontWeight: FontWeight.w900),
                        ),
                        const TextSpan(text: ' 줄였어요!'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkScoreCard(NumberFormat fmt) {
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.trending_up,
                    size: 15, color: Color(0xFF0052FF)),
              ),
              const SizedBox(width: 10),
              const Text('링크 스코어 업데이트',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF111827))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_upward,
                        size: 11, color: Color(0xFF00A864)),
                    SizedBox(width: 4),
                    Text('+15점',
                        style: TextStyle(
                            color: Color(0xFF00A864),
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Column(
                    children: [
                      Text('이전 점수',
                          style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 11)),
                      SizedBox(height: 4),
                      Text('727',
                          style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 24,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward,
                          size: 16, color: Color(0xFF00A864)),
                    ),
                    const SizedBox(height: 4),
                    const Text('+15',
                        style: TextStyle(
                            color: Color(0xFF00A864),
                            fontSize: 11,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEEF2FF), Color(0xFFDBEAFE)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFBFDBFE), width: 2),
                  ),
                  child: const Column(
                    children: [
                      Text('현재 점수',
                          style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 11)),
                      SizedBox(height: 4),
                      Text('742',
                          style: TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontSize: 24,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEEF6FF), Color(0xFFDBEAFE)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.workspace_premium,
                    size: 16, color: Color(0xFF0052FF)),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('스코어 리워드 이유',
                          style: TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                          '약속을 잘 지켜서 링크 스코어가 +15점 올랐어요!\n기한 내 입금 완료 +10점 · 전액 사용 완료 +5점',
                          style: TextStyle(
                              color: Color(0xFF6B7280),
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

  Widget _receiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF6B6760), fontSize: 14)),
        Text(value,
            style: const TextStyle(
                color: Color(0xFF2D2A25),
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _receiptDivider() => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 0),
        color: const Color(0xFFE8E5E1),
      );

  Widget _receiptDividerBold() => Container(
        height: 2,
        margin: const EdgeInsets.symmetric(vertical: 0),
        color: const Color(0xFFD4D0CC),
      );
}
