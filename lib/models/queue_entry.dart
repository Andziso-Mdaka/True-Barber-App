class QueueEntry {
  final String id;
  final int ticketNo;
  final String name;
  final String barber;
  String status; // 'waiting' | 'called' | 'done' | 'left'
  QueueEntry({
    required this.id,
    required this.ticketNo,
    required this.name,
    required this.barber,
    this.status = 'waiting',
  });
}