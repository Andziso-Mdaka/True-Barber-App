class Review {
  final String id;
  final String customerId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.customerId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });
}