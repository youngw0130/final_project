class ParticipantResponse {
  final int userId;
  final String username;
  final int linkScore;
  final double depositAmount;
  final String depositStatus;
  final String? refundBank;
  final String? refundAccountNumber;
  final double? refundAmount;
  final double? shareAmount;

  ParticipantResponse({
    required this.userId,
    required this.username,
    required this.linkScore,
    required this.depositAmount,
    required this.depositStatus,
    this.refundBank,
    this.refundAccountNumber,
    this.refundAmount,
    this.shareAmount,
  });

  factory ParticipantResponse.fromJson(Map<String, dynamic> json) =>
      ParticipantResponse(
        userId: (json['userId'] as int?) ?? 0,
        username: (json['username'] as String?) ?? '',
        linkScore: (json['linkScore'] as int?) ?? 0,
        depositAmount: ((json['depositAmount'] ?? 0) as num).toDouble(),
        depositStatus: (json['depositStatus'] as String?) ?? 'PENDING',
        refundBank: json['refundBank'] as String?,
        refundAccountNumber: json['refundAccountNumber'] as String?,
        refundAmount: json['refundAmount'] != null
            ? (json['refundAmount'] as num).toDouble()
            : null,
        shareAmount: json['shareAmount'] != null
            ? (json['shareAmount'] as num).toDouble()
            : null,
      );

  bool get isDeposited => depositStatus == 'DEPOSITED';
}
