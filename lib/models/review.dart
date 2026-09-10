class Review {
  final String id;
  final String customerId;
  final String customerName; // <-- Add this
  final int rating;
  final String? comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.customerId,
    required this.customerName, // <-- Add this
    required this.rating,
    this.comment,
    required this.createdAt,
  });
}