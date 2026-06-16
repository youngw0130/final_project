class PaymentResponse {
  final int id;
  final int moimId;
  final String merchantName;
  final String? category;
  final double amount;
  final String approvedAt;
  final String status;

  PaymentResponse({
    required this.id,
    required this.moimId,
    required this.merchantName,
    this.category,
    required this.amount,
    required this.approvedAt,
    required this.status,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      id: json['id'] as int,
      moimId: (json['moimId'] as int?) ?? 0,
      merchantName: (json['merchantName'] as String?) ?? '',
      category: json['category'] as String?,
      amount: ((json['amount'] ?? 0) as num).toDouble(),
      approvedAt: (json['approvedAt'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'APPROVED',
    );
  }
}
