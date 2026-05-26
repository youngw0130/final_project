class MoimResponse {
  final int id;
  final String title;
  final String? description;
  final String? emoji;
  final String status;
  final double targetAmount;
  final double totalDeposited;
  final double totalSpent;
  final double depositPerPerson;
  final double bufferRate;
  final int targetParticipantCount;
  final String inviteCode;
  final String? virtualAccountNumber;
  final String? virtualAccountBank;
  final String? scheduledAt;
  final String createdAt;

  MoimResponse({
    required this.id,
    required this.title,
    this.description,
    this.emoji,
    required this.status,
    required this.targetAmount,
    required this.totalDeposited,
    required this.totalSpent,
    required this.depositPerPerson,
    required this.bufferRate,
    required this.targetParticipantCount,
    required this.inviteCode,
    this.virtualAccountNumber,
    this.virtualAccountBank,
    this.scheduledAt,
    required this.createdAt,
  });

  factory MoimResponse.fromJson(Map<String, dynamic> json) => MoimResponse(
        id: json['id'] as int,
        title: json['title'] as String,
        description: json['description'] as String?,
        emoji: json['emoji'] as String?,
        status: json['status'] as String,
        targetAmount: (json['targetAmount'] as num).toDouble(),
        totalDeposited: (json['totalDeposited'] as num).toDouble(),
        totalSpent: (json['totalSpent'] as num).toDouble(),
        depositPerPerson: (json['depositPerPerson'] as num).toDouble(),
        bufferRate: (json['bufferRate'] as num).toDouble(),
        targetParticipantCount: json['targetParticipantCount'] as int,
        inviteCode: json['inviteCode'] as String,
        virtualAccountNumber: json['virtualAccountNumber'] as String?,
        virtualAccountBank: json['virtualAccountBank'] as String?,
        scheduledAt: json['scheduledAt'] as String?,
        createdAt: json['createdAt'] as String,
      );

  double get balance => totalDeposited - totalSpent;
  double get depositRate =>
      targetAmount > 0 ? totalDeposited / targetAmount : 0;
}
