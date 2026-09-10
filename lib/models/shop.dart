import 'barber.dart';
import 'queue_entry.dart';
import 'review.dart';

class Shop {
  final String id;
  final String ownerId;
  final List<String> services;
  String name;
  String area;
  int price;
  int chairs;
  double rating;
  double? latitude;
  double? longitude;
  String status;
  String? photoUrl;
  List<String> portfolioUrls; // <-- NEW
  List<String> subscribers;
  List<QueueEntry> queue;
  List<Barber> staff;
  List<Review> reviews;
  int nextTicket;
  bool isMine;
  int subscriberCount;
  int queueCount;

  Shop({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.area,
    required this.price,
    required this.chairs,
    required this.rating,
    required this.services,
    this.latitude,
    this.longitude,
    this.status = 'pending',
    this.photoUrl,
    this.portfolioUrls = const [],
    this.reviews = const [],
    required this.subscribers,
    required this.queue,
    List<Barber>? staff,
    required this.nextTicket,
    this.isMine = false,
    this.subscriberCount = 0,
    this.queueCount = 0,
  }) : staff = staff ?? [];
}