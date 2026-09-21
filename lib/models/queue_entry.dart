class QueueEntry {
  final String id;
  final int ticketNo;
  final String name;
  final String barber;
  final String status;
  
  // NEW FIELDS:
  final String paymentMethod; 
  final String? serviceName;
  final int? priceCharged;

  QueueEntry({
    required this.id,
    required this.ticketNo,
    required this.name,
    required this.barber,
    required this.status,
    this.paymentMethod = 'cash',
    this.serviceName,
    this.priceCharged,
  });
}