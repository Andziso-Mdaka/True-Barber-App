import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/utils.dart';
import '../core/firebase_web_config.dart';
import '../core/notification_helper.dart';
import '../models/shop.dart';
import '../models/barber.dart';
import '../models/queue_entry.dart';
import '../models/review.dart';

final supabase = Supabase.instance.client;

class AppProvider extends ChangeNotifier {
  // --- STATE VARIABLES ---
  bool isOwnerMode = false;
  bool loadingData = true;
  bool isAdmin = false;
  int pendingShopCount = 0;
  String? loadError;

  final List<Shop> shops = [];
  Set<String> mySubShopIds = {};
  QueueEntry? myTicket;
  int? myTicketPosition;
  String? myTicketShopId;
  String? ownerShopId;

  Shop? get ownerShop => shops.where((s) => s.id == ownerShopId).firstOrNull;

  // Loading states for buttons
  bool refreshingShops = false;
  bool subscribing = false;
  String? cancellingShopId;
  bool joiningQueue = false;
  bool leavingQueue = false;
  bool refreshingTicket = false;
  bool creatingShop = false;
  String? createShopError;
  bool uploadingPhoto = false;
  bool refreshingQueue = false;
  bool uploadingPortfolio = false; 

  // Push Notifications
  bool notificationsEnabled = false;
  bool checkingNotificationPermission = true;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _openedAppMessageSub;
  StreamSubscription<String>? _tokenRefreshSub;

  AppProvider() {
    loadInitialData();
    setupPushNotifications();
  }

  void setOwnerMode(bool value) {
    isOwnerMode = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _foregroundMessageSub?.cancel();
    _openedAppMessageSub?.cancel();
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  // --- INITIALIZATION ---
  Future<void> loadInitialData() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    
    loadingData = true;
    loadError = null;
    notifyListeners();
    
    try {
      final loaded = await _fetchShops();
      shops.clear();
      shops.addAll(loaded.where((s) => s.status == 'approved' || s.isMine));

      final mine = loaded.where((s) => s.isMine).firstOrNull;
      if (mine != null) {
        ownerShopId = mine.id;
        await refreshOwnerShopDetail();
      }

      final subRows = await supabase
          .from('subscriptions')
          .select()
          .eq('customer_id', uid)
          .eq('status', 'active');
      mySubShopIds = {for (final r in subRows) r['shop_id'] as String};

      final ticketRow = await supabase
          .from('queue_entries')
          .select()
          .eq('customer_id', uid)
          .inFilter('status', ['waiting', 'called'])
          .maybeSingle();
          
      if (ticketRow != null) {
        final shopId = ticketRow['shop_id'] as String;
        final position = await supabase.rpc('queue_position', params: {'p_shop_id': shopId});
        myTicketShopId = shopId;
        myTicket = QueueEntry(
          id: ticketRow['id'] as String,
          ticketNo: ticketRow['ticket_no'] as int,
          name: ticketRow['display_name'] as String,
          barber: ticketRow['barber_id'] == null ? 'Next available' : '',
          status: ticketRow['status'] as String,
        );
        myTicketPosition = (position as num).toInt();
      }

      final profileRow = await supabase.from('profiles').select('is_admin').eq('id', uid).maybeSingle();
      final admin = profileRow?['is_admin'] as bool? ?? false;
      if (admin) {
        isAdmin = true;
        await refreshPendingShopCount();
      }
    } catch (e) {
      loadError = "Couldn't load your data. Check your connection and try again.";
      debugPrint('Failed to load initial data: $e');
    } finally {
      loadingData = false;
      notifyListeners();
    }
  }

  Future<List<Shop>> _fetchShops() async {
    final uid = supabase.auth.currentUser?.id;
    final shopRows = await supabase.from('shops').select();
    final statsRows = await supabase.from('shop_stats').select();
    final statsById = {for (final r in statsRows) r['shop_id'] as String: r};
    // Notice the select() now joins the profiles table
    final reviewRows = await supabase.from('reviews').select('*, profiles(full_name)').order('created_at', ascending: false);
    final reviewsByShop = <String, List<Review>>{};
    for (final r in reviewRows) {
      final rev = Review(
        id: r['id'] as String,
        customerId: r['customer_id'] as String,
        // Grab the joined profile name
        customerName: r['profiles'] != null ? r['profiles']['full_name'] as String? ?? 'Regular' : 'Regular',
        rating: r['rating'] as int,
        comment: r['comment'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
      reviewsByShop.putIfAbsent(r['shop_id'] as String, () => []).add(rev);
    }

    return [
      for (final row in shopRows)
        Shop(
          id: row['id'] as String,
          ownerId: row['owner_id'] as String,
          name: row['name'] as String,
          area: row['area'] as String,
          price: row['price'] as int,
          chairs: row['chairs'] as int,
          rating: (row['rating'] as num).toDouble(),
          latitude: (row['latitude'] as num?)?.toDouble(),
          longitude: (row['longitude'] as num?)?.toDouble(),
          status: row['status'] as String? ?? 'pending',
          photoUrl: row['photo_url'] as String?,
          portfolioUrls: List<String>.from(row['portfolio_urls'] ?? []),
          reviews: reviewsByShop[row['id']] ?? [],
          services: List<String>.from(row['services'] ?? []),
          subscribers: [],
          queue: [],
          nextTicket: row['next_ticket'] as int,
          isMine: row['owner_id'] == uid,
          subscriberCount: (statsById[row['id']]?['subscriber_count'] as int?) ?? 0,
          queueCount: (statsById[row['id']]?['queue_count'] as int?) ?? 0,
        ),
    ];
  }

  Future<void> refreshShops() async {
    refreshingShops = true;
    notifyListeners();
    try {
      final loaded = await _fetchShops();
      shops.clear();
      shops.addAll(loaded.where((s) => s.status == 'approved' || s.isMine));
    } catch (e) {
      showSnack("Couldn't refresh shops. Check your connection.", isError: true);
    } finally {
      refreshingShops = false;
      notifyListeners();
    }
  }

  // --- CUSTOMER ACTIONS ---
  Future<void> subscribe(String shopId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    subscribing = true;
    notifyListeners();
    try {
      final origin = kIsWeb ? Uri.base.origin : 'https://example.com';
      final response = await supabase.functions.invoke(
        'create-payfast-checkout',
        body: {'shop_id': shopId, 'return_url': origin, 'cancel_url': origin},
      );
      final checkoutUrl = response.data is Map ? response.data['checkout_url'] as String? : null;
      if (checkoutUrl == null) throw Exception('No checkout URL returned');
      
      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        webOnlyWindowName: kIsWeb ? '_self' : null,
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
      if (!launched) showSnack("Couldn't open the payment page.", isError: true);
    } catch (e) {
      showSnack("Couldn't start checkout. Please try again.", isError: true);
    } finally {
      subscribing = false;
      notifyListeners();
    }
  }

  Future<void> cancelSubscription(String shopId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || !mySubShopIds.contains(shopId)) return;
    cancellingShopId = shopId;
    notifyListeners();
    try {
      final response = await supabase.functions.invoke('cancel-payfast-subscription', body: {'shop_id': shopId});
      if (response.status != 200) throw Exception('Cancel failed');
      
      shops.firstWhere((s) => s.id == shopId).subscriberCount -= 1;
      mySubShopIds = {...mySubShopIds}..remove(shopId);
      if (myTicketShopId == shopId) {
        myTicket = null;
        myTicketPosition = null;
        myTicketShopId = null;
      }
      showSnack('Subscription cancelled');
    } catch (e) {
      showSnack("Couldn't cancel your subscription. Please try again.", isError: true);
    } finally {
      cancellingShopId = null;
      notifyListeners();
    }
  }

  Future<void> walkIn(String shopId) async {
    final shop = shops.firstWhere((s) => s.id == shopId);
    joiningQueue = true;
    notifyListeners();
    
    List<Barber> activeStaff = shop.staff.where((b) => b.active).toList();
    if (activeStaff.isEmpty && !shop.isMine) {
      try {
        final rows = await supabase.from('barbers').select().eq('shop_id', shopId).eq('active', true);
        activeStaff = [for (final b in rows) Barber(id: b['id'] as String, name: b['name'] as String)];
      } catch (e) {
        debugPrint('Failed to fetch barbers: $e');
      }
    }
    
    final barberId = activeStaff.isEmpty ? null : activeStaff[DateTime.now().millisecondsSinceEpoch % activeStaff.length].id;

    try {
      final row = await supabase.rpc('join_queue', params: {'p_shop_id': shopId, 'p_barber_id': barberId});
      final position = await supabase.rpc('queue_position', params: {'p_shop_id': shopId});
      final barberName = barberId == null ? 'Unassigned' : activeStaff.firstWhere((b) => b.id == barberId).name;
      
      myTicket = QueueEntry(
        id: row['id'] as String,
        ticketNo: row['ticket_no'] as int,
        name: row['display_name'] as String,
        barber: barberName,
        status: row['status'] as String,
      );
      myTicketPosition = (position as num).toInt();
      myTicketShopId = shopId;
      shop.queueCount += 1;
      showSnack("You're in line — ticket #${row['ticket_no']}");
    } on PostgrestException catch (e) {
      final message = e.message.contains('No active subscription')
          ? "You need an active subscription to walk in."
          : e.message.contains('Already in another queue')
              ? "You're already in a queue at another shop. Leave that one first."
              : e.message;
      showSnack(message, isError: true);
    } catch (e) {
      showSnack("Couldn't join the queue. Please try again.", isError: true);
    } finally {
      joiningQueue = false;
      notifyListeners();
    }
  }

  Future<void> refreshTicket() async {
    if (myTicket == null || myTicketShopId == null) return;
    refreshingTicket = true;
    notifyListeners();
    try {
      final row = await supabase.from('queue_entries').select().eq('id', myTicket!.id).maybeSingle();
      if (row == null || !['waiting', 'called'].contains(row['status'])) {
        myTicket = null;
        myTicketPosition = null;
        myTicketShopId = null;
        showSnack("Looks like you've been served — enjoy the cut!");
      } else {
        final position = await supabase.rpc('queue_position', params: {'p_shop_id': myTicketShopId});
        myTicket!.status = row['status'] as String;
        myTicketPosition = (position as num).toInt();
      }
    } catch (e) {
      showSnack("Couldn't refresh your ticket.", isError: true);
    } finally {
      refreshingTicket = false;
      notifyListeners();
    }
  }

  Future<void> leaveQueue() async {
    if (myTicket == null || myTicketShopId == null) return;
    final shopId = myTicketShopId!;
    leavingQueue = true;
    notifyListeners();
    try {
      await supabase.from('queue_entries').update({'status': 'left'}).eq('id', myTicket!.id);
      shops.firstWhere((s) => s.id == shopId).queueCount -= 1;
      myTicket = null;
      myTicketPosition = null;
      myTicketShopId = null;
      showSnack('Left the queue');
    } catch (e) {
      showSnack("Couldn't leave the queue. Please try again.", isError: true);
    } finally {
      leavingQueue = false;
      notifyListeners();
    }
  }

  // --- OWNER ACTIONS ---
  Future<void> refreshOwnerShopDetail() async {
    if (ownerShopId == null) return;
    final barberRows = await supabase.from('barbers').select().eq('shop_id', ownerShopId as Object);
    final queueRows = await supabase
        .from('queue_entries')
        .select()
        .eq('shop_id', ownerShopId as Object)
        .inFilter('status', ['waiting', 'called'])
        .order('ticket_no');
    final statsRow = await supabase.from('shop_stats').select().eq('shop_id', ownerShopId as Object).maybeSingle();
    final barbersById = {for (final b in barberRows) b['id'] as String: b['name'] as String};
    
    final shop = ownerShop;
    if (shop == null) return;
    
    shop.staff
      ..clear()
      ..addAll([for (final b in barberRows) Barber(id: b['id'] as String, name: b['name'] as String, active: b['active'] as bool)]);
    shop.queue
      ..clear()
      ..addAll([
        for (final q in queueRows)
          QueueEntry(
            id: q['id'] as String,
            ticketNo: q['ticket_no'] as int,
            name: q['display_name'] as String,
            barber: barbersById[q['barber_id']] ?? 'Unassigned',
            status: q['status'] as String,
          )
      ]);
    shop.queueCount = shop.queue.length;
    if (statsRow != null) shop.subscriberCount = statsRow['subscriber_count'] as int;
    notifyListeners();
  }

  Future<void> createShop(String name, String area, int price, int chairs, LatLng? location) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    creatingShop = true;
    createShopError = null;
    notifyListeners();
    try {
      final row = await supabase.from('shops').insert({
        'owner_id': uid,
        'name': name,
        'area': area,
        'price': price,
        'chairs': chairs,
        'latitude': location?.latitude,
        'longitude': location?.longitude,
      }).select().single();
      
      final shop = Shop(
        id: row['id'] as String, ownerId: uid, name: row['name'] as String, area: row['area'] as String,
        price: row['price'] as int, chairs: row['chairs'] as int, rating: (row['rating'] as num).toDouble(),
        latitude: (row['latitude'] as num?)?.toDouble(), longitude: (row['longitude'] as num?)?.toDouble(),
        status: row['status'] as String? ?? 'pending', portfolioUrls: [], reviews: [], services: List<String>.from(row['services'] ?? []), subscribers: [], queue: [], nextTicket: row['next_ticket'] as int, isMine: true,
      );
      shops.add(shop);
      ownerShopId = shop.id;
      showSnack('$name submitted — it will show up for customers once approved');
    } catch (e) {
      createShopError = e.toString().contains('one_shop_per_owner') ? 'Your account already has a shop.' : 'Could not create shop: $e';
      showSnack('Could not create shop', isError: true);
    } finally {
      creatingShop = false;
      notifyListeners();
    }
  }

  Future<void> updateShopLocation(LatLng location) async {
    if (ownerShop == null) return;
    try {
      await supabase.from('shops').update({'latitude': location.latitude, 'longitude': location.longitude}).eq('id', ownerShop!.id);
      ownerShop!.latitude = location.latitude;
      ownerShop!.longitude = location.longitude;
      notifyListeners();
      showSnack('Location updated');
    } catch (e) {
      showSnack("Couldn't update location.", isError: true);
    }
  }

  Future<void> uploadShopPhoto() async {
    if (ownerShop == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;

    uploadingPhoto = true;
    notifyListeners();
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final path = '${ownerShop!.id}/cover.$ext';

      await supabase.storage.from('shop-photos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = supabase.storage.from('shop-photos').getPublicUrl(path);
      final bustedUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await supabase.from('shops').update({'photo_url': bustedUrl}).eq('id', ownerShop!.id);
      ownerShop!.photoUrl = bustedUrl;
      showSnack('Photo updated');
    } catch (e) {
      showSnack("Couldn't upload photo. Please try again.", isError: true);
      debugPrint('Failed to upload shop photo: $e');
    } finally {
      uploadingPhoto = false;
      notifyListeners();
    }
  }

  Future<void> uploadPortfolioPhoto() async {
    if (ownerShop == null) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    uploadingPortfolio = true;
    notifyListeners();
    
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      // Use timestamp so every image has a unique name in the array
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext'; 
      final path = '${ownerShop!.id}/$fileName';

      await supabase.storage.from('shop-portfolios').uploadBinary(path, bytes);
      final publicUrl = supabase.storage.from('shop-portfolios').getPublicUrl(path);

      // Append to the local list, then update Supabase
      final updatedList = List<String>.from(ownerShop!.portfolioUrls)..add(publicUrl);
      await supabase.from('shops').update({'portfolio_urls': updatedList}).eq('id', ownerShop!.id);
      
      ownerShop!.portfolioUrls = updatedList;
      showSnack('Added to portfolio');
    } catch (e) {
      showSnack("Couldn't upload photo.", isError: true);
      debugPrint('Portfolio upload failed: $e');
    } finally {
      uploadingPortfolio = false;
      notifyListeners();
    }
  }

  Future<void> refreshOwnerShop() async {
    refreshingQueue = true;
    notifyListeners();
    try {
      await refreshOwnerShopDetail();
    } catch (e) {
      showSnack('Refresh failed.', isError: true);
    } finally {
      refreshingQueue = false;
      notifyListeners();
    }
  }

  Future<void> callCustomer(String queueId) async {
    if (ownerShop == null) return;
    try {
      await supabase.from('queue_entries').update({'status': 'called'}).eq('id', queueId);
      ownerShop!.queue.firstWhere((q) => q.id == queueId).status = 'called';
      notifyListeners();
      showSnack('Customer called');
    } catch (e) {
      showSnack("Couldn't call that customer.", isError: true);
    }
  }

  Future<void> completeQueueEntry(String queueId) async {
    if (ownerShop == null) return;
    try {
      await supabase.from('queue_entries').update({'status': 'done', 'completed_at': DateTime.now().toIso8601String()}).eq('id', queueId);
      ownerShop!.queue.removeWhere((q) => q.id == queueId);
      ownerShop!.queueCount = ownerShop!.queue.length;
      notifyListeners();
      showSnack('Marked done');
    } catch (e) {
      showSnack("Couldn't update that ticket.", isError: true);
    }
  }

  Future<void> addBarber(String name) async {
    if (ownerShop == null || name.trim().isEmpty) return;
    try {
      final row = await supabase.from('barbers').insert({'shop_id': ownerShop!.id, 'name': name.trim()}).select().single();
      ownerShop!.staff.add(Barber(id: row['id'] as String, name: row['name'] as String, active: row['active'] as bool));
      notifyListeners();
      showSnack('${name.trim()} added to the team');
    } catch (e) {
      showSnack("Couldn't add barber.", isError: true);
    }
  }

  Future<void> removeBarber(String barberId) async {
    if (ownerShop == null) return;
    try {
      await supabase.from('barbers').delete().eq('id', barberId);
      ownerShop!.staff.removeWhere((b) => b.id == barberId);
      notifyListeners();
      showSnack('Barber removed');
    } catch (e) {
      showSnack("Couldn't remove barber.", isError: true);
    }
  }

  Future<void> toggleBarberActive(String barberId) async {
    if (ownerShop == null) return;
    final barber = ownerShop!.staff.firstWhere((b) => b.id == barberId);
    final newActive = !barber.active;
    try {
      await supabase.from('barbers').update({'active': newActive}).eq('id', barberId);
      barber.active = newActive;
      notifyListeners();
    } catch (e) {
      showSnack("Couldn't update barber status.", isError: true);
    }
  }

  Future<void> refreshPendingShopCount() async {
    if (!isAdmin) return;
    try {
      final rows = await supabase.from('shops').select('id').eq('status', 'pending');
      pendingShopCount = rows.length;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh pending shop count: $e');
    }
  }

  // --- NOTIFICATIONS ---
  Future<void> setupPushNotifications() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized || settings.authorizationStatus == AuthorizationStatus.provisional) {
        notificationsEnabled = true;
        notifyListeners();
        await _registerDeviceToken();
      }
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((_) => _registerDeviceToken());

      _foregroundMessageSub = FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification != null) {
          showLocalNotification(id: notification.hashCode, title: notification.title, body: notification.body);
          if (kIsWeb) showSnack('${notification.title ?? "You're up!"} ${notification.body ?? ""}'.trim());
        }
        refreshTicket();
      });

      _openedAppMessageSub = FirebaseMessaging.onMessageOpenedApp.listen((_) => refreshTicket());
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) refreshTicket();
    } catch (e) {
      debugPrint('Push notification setup failed: $e');
    } finally {
      checkingNotificationPermission = false;
      notifyListeners();
    }
  }

  Future<void> requestNotificationPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized || settings.authorizationStatus == AuthorizationStatus.provisional;
      notificationsEnabled = granted;
      notifyListeners();
      if (granted) {
        await _registerDeviceToken();
        showSnack("Notifications enabled.");
      } else {
        showSnack("Notifications weren't enabled.", isError: true);
      }
    } catch (e) {
      showSnack("Couldn't enable notifications right now.", isError: true);
    }
  }

  Future<void> _registerDeviceToken() async {
    final uid = supabase.auth.currentUser?.id;
    final token = await FirebaseMessaging.instance.getToken(vapidKey: kIsWeb ? webPushVapidKey : null);
    if (uid == null || token == null) return;
    try {
      await supabase.from('device_tokens').upsert({
        'token': token, 'user_id': uid, 'platform': defaultTargetPlatform.name, 'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to register device token: $e');
    }
  }

 Future<void> submitReview(String shopId, int rating, String? comment) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      // .select() returns the new row instantly so we can update the UI without reloading everything
      final newRow = await supabase.from('reviews').insert({
        'shop_id': shopId,
        'customer_id': uid,
        'rating': rating,
        'comment': comment?.trim().isEmpty == true ? null : comment,
      }).select('*, profiles(full_name)').single();

      final shopIndex = shops.indexWhere((s) => s.id == shopId);
      if (shopIndex != -1) {
        shops[shopIndex].reviews.insert(0, Review(
          id: newRow['id'],
          customerId: uid,
          customerName: newRow['profiles'] != null ? newRow['profiles']['full_name'] ?? 'You' : 'You',
          rating: rating,
          comment: newRow['comment'],
          createdAt: DateTime.parse(newRow['created_at']),
        ));
        
        // Quick local math to update the stars instantly
        final totalStars = shops[shopIndex].reviews.fold(0, (sum, r) => sum + r.rating);
        shops[shopIndex].rating = totalStars / shops[shopIndex].reviews.length;
        notifyListeners(); 
      }
      showSnack('Thanks for the review!');
    } catch (e) {
      showSnack("Couldn't submit review.", isError: true);
      debugPrint('Review failed: $e');
    }
  }
}

