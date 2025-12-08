class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? error;

  PaymentResult({
    required this.success,
    this.transactionId,
    this.error,
  });
} 