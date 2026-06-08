import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/moim_response.dart';
import '../models/participant_response.dart';
import '../providers/auth_provider.dart';
import '../providers/moim_provider.dart';
import 'qr_payment_screen.dart';

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
      prov.loadMoim(widget.moimId);
      prov.loadParticipants(widget.moimId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MoimProvider>();
    final auth = context.watch<AuthProvider>();
    final moim = prov.selectedMoim;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(moim?.title ?? '모임 상세',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (moim != null && moim.status == 'OPEN')
            TextButton(
              onPressed: () => _showInviteCode(moim.inviteCode),
              child: const Text('초대', style: TextStyle(color: Color(0xFF6366F1))),
            ),
        ],
      ),
      body: prov.loading && moim == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : moim == null
              ? const Center(
                  child: Text('모임을 불러올 수 없습니다',
                      style: TextStyle(color: Color(0xFF94A3B8))))
              : RefreshIndicator(
                  onRefresh: () async {
                    await prov.loadMoim(widget.moimId);
                    await prov.loadParticipants(widget.moimId);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(moim),
                        const SizedBox(height: 20),
                        if (moim.virtualAccountNumber != null)
                          _buildVirtualAccount(moim),
                        const SizedBox(height: 20),
                        _buildProgress(moim),
                        const SizedBox(height: 20),
                        _buildParticipants(prov.participants, moim, auth),
                        const SizedBox(height: 20),
                        if (moim.status == 'OPEN' || moim.status == 'ACTIVE')
                          _buildActions(moim, auth, prov),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader(MoimResponse moim) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(moim.emoji ?? '📋', style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(moim.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    if (moim.description != null && moim.description!.isNotEmpty)
                      Text(moim.description!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              _statusBadge(moim.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statItem('목표', '${_fmt.format(moim.targetAmount.toInt())}원'),
              _statItem('1인당', '${_fmt.format(moim.depositPerPerson.toInt())}원'),
              _statItem('인원', '${moim.targetParticipantCount}명'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(label,
                style:
                    const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      );

  Widget _buildVirtualAccount(MoimResponse moim) {
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
          const Row(
            children: [
              Icon(Icons.account_balance_outlined,
                  color: Color(0xFF6366F1), size: 18),
              SizedBox(width: 8),
              Text('가상계좌',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(moim.virtualAccountBank ?? '',
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(moim.virtualAccountNumber ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: moim.virtualAccountNumber ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('계좌번호가 복사되었습니다')));
                },
                icon: const Icon(Icons.copy_outlined,
                    color: Color(0xFF6366F1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              '${_fmt.format(moim.depositPerPerson.toInt())}원을 위 계좌로 입금해주세요',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildProgress(MoimResponse moim) {
    final depositedCount = moim.depositPerPerson > 0
        ? (moim.totalDeposited / moim.depositPerPerson).floor()
        : 0;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('입금 현황',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              Text('$depositedCount/${moim.targetParticipantCount}명',
                  style: const TextStyle(
                      color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: moim.depositRate.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFF334155),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _progressStat(
                  '총 입금', '${_fmt.format(moim.totalDeposited.toInt())}원',
                  const Color(0xFF22C55E)),
              _progressStat(
                  '총 지출', '${_fmt.format(moim.totalSpent.toInt())}원',
                  const Color(0xFFEF4444)),
              _progressStat(
                  '잔액', '${_fmt.format(moim.balance.toInt())}원',
                  const Color(0xFF6366F1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressStat(String label, String value, Color color) => Column(
        children: [
          Text(label,
              style:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      );

  Widget _buildParticipants(List<ParticipantResponse> participants,
      MoimResponse moim, AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('참여자',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text('${participants.length}명',
                    style: const TextStyle(color: Color(0xFF6366F1))),
              ],
            ),
          ),
          const Divider(color: Color(0xFF334155), height: 1),
          ...participants.map((p) => _buildParticipantTile(p, moim, auth)),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(
      ParticipantResponse p, MoimResponse moim, AuthProvider auth) {
    final isMe = p.userId == auth.userId;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: p.isDeposited
            ? const Color(0xFF22C55E).withOpacity(0.2)
            : const Color(0xFF334155),
        child: Text(p.username[0].toUpperCase(),
            style: TextStyle(
                color: p.isDeposited
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF94A3B8),
                fontWeight: FontWeight.bold)),
      ),
      title: Row(
        children: [
          Text(p.username,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          if (isMe)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('나',
                  style: TextStyle(
                      color: Color(0xFF6366F1), fontSize: 10)),
            ),
        ],
      ),
      subtitle: Text('링크스코어 ${p.linkScore}',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      trailing: _depositStatusBadge(p.depositStatus),
    );
  }

  Widget _buildActions(
      MoimResponse moim, AuthProvider auth, MoimProvider prov) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (moim.status == 'ACTIVE') ...[
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QrPaymentScreen(moimId: widget.moimId),
                ),
              ).then((_) => prov.loadMoim(widget.moimId));
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('QR 결제'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (moim.status == 'ACTIVE' || moim.status == 'SETTLING')
          ElevatedButton.icon(
            onPressed: prov.loading
                ? null
                : () async {
                    final result = await prov.settle(widget.moimId);
                    if (!mounted) return;
                    if (result.isNotEmpty) {
                      _showSettlementDialog(result);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(prov.error ?? '정산 실패')));
                    }
                  },
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('정산 시작'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF475569),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        if (moim.status == 'OPEN') ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showInviteCode(moim.inviteCode),
            icon: const Icon(Icons.share_outlined,
                color: Color(0xFF6366F1)),
            label: const Text('초대 코드 공유',
                style: TextStyle(color: Color(0xFF6366F1))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF6366F1)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }

  void _showInviteCode(String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('초대 코드',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(code,
                  style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 32,
                      letterSpacing: 6,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('초대 코드가 복사되었습니다')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('복사하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
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
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('정산 완료',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    style: const TextStyle(color: Colors.white)),
                trailing: Text(
                  refund > 0
                      ? '+${fmt.format(refund.toInt())}원'
                      : '${fmt.format(refund.toInt())}원',
                  style: TextStyle(
                      color: refund > 0
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인',
                style: TextStyle(color: Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final colors = {
      'OPEN': const Color(0xFF22C55E),
      'ACTIVE': const Color(0xFF3B82F6),
      'SETTLING': const Color(0xFFF59E0B),
      'CLOSED': const Color(0xFF94A3B8),
      'CANCELLED': const Color(0xFFEF4444),
    };
    final labels = {
      'OPEN': '입금 대기',
      'ACTIVE': '진행 중',
      'SETTLING': '정산 중',
      'CLOSED': '종료',
      'CANCELLED': '취소',
    };
    final c = colors[status] ?? const Color(0xFF94A3B8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
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
        return const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 20);
      case 'OVERDUE':
        return const Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 20);
      case 'REFUNDED':
        return const Icon(Icons.undo, color: Color(0xFF6366F1), size: 20);
      default:
        return const Icon(Icons.radio_button_unchecked,
            color: Color(0xFF64748B), size: 20);
    }
  }
}
