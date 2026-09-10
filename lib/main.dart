import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Core
import 'core/theme.dart';
import 'core/utils.dart';
import 'core/supabase_config.dart';
import 'core/firebase_options.dart';
import 'core/notification_helper.dart';

// Models
import 'models/shop.dart';
import 'models/barber.dart';
import 'models/queue_entry.dart';

// UI - Auth
import 'ui/auth/auth_screen.dart';
import 'ui/auth/reset_password_screen.dart';

// UI - Customer
import 'ui/customer/customer_flow.dart';

// UI - Owner
import 'ui/owner/admin_screen.dart';
import 'ui/owner/owner_flow.dart';

// UI - Widgets
import 'ui/widgets/outline_button.dart';

final supabase = Supabase.instance.client;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Nothing to do here: system notification handles it.
}

bool isPasswordRecoveryLink = false;

void _detectPasswordRecoveryLink() {
  if (!kIsWeb) return;
  final uri = Uri.base;
  final fragmentParams = Uri.splitQueryString(uri.fragment);
  isPasswordRecoveryLink = uri.queryParameters['type'] == 'recovery' || fragmentParams['type'] == 'recovery';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _detectPasswordRecoveryLink();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await initNotifications();

  runApp(const RootApp());
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Regular',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey, // Provided by core/utils.dart
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.brass,
          surface: AppColors.surface,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool showResetPassword = isPasswordRecoveryLink;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        setState(() => showResetPassword = true);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (showResetPassword) {
          return ResetPasswordScreen(onDone: () => setState(() => showResetPassword = false));
        }
        final session = supabase.auth.currentSession;
        if (session == null) return const AuthScreen();
        return const TheRegularApp();
      },
    );
  }
}

class TheRegularApp extends StatefulWidget {
  const TheRegularApp({super.key});
  @override
  State<TheRegularApp> createState() => _TheRegularAppState();
}

class _TheRegularAppState extends State<TheRegularApp> {
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupPushNotifications();
  }

  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _openedAppMessageSub;
  StreamSubscription<String>? _tokenRefreshSub;

  bool notificationsEnabled = false;
  bool checkingNotificationPermission = true;

  Future<void> _setupPushNotifications() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        setState(() => notificationsEnabled = true);
        await _registerDeviceToken();
      }
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((_) => _registerDeviceToken());

      _foregroundMessageSub = FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification != null) {
          showLocalNotification(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
          );
          if (kIsWeb) {
            showSnack('${notification.title ?? "You're up!"} ${notification.body ?? ""}'.trim());
          }
        }
        refreshTicket();
      });

      _openedAppMessageSub = FirebaseMessaging.onMessageOpenedApp.listen((_) => refreshTicket());
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) refreshTicket();
    } catch (e) {
      debugPrint('Push notification setup failed: $e');
    } finally {
      if (mounted) setState(() => checkingNotificationPermission = false);
    }
  }

  Future<void> requestNotificationPermission() async {
    debugPrint('[push] Enable notifications tapped');
    try {
      debugPrint('[push] calling requestPermission...');
      final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      debugPrint('[push] requestPermission returned: ${settings.authorizationStatus}');
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      setState(() => notificationsEnabled = granted);
      if (granted) {
        debugPrint('[push] granted, registering device token...');
        await _registerDeviceToken();
        debugPrint('[push] device token registered');
        showSnack("Notifications enabled — you'll be alerted when it's your turn.");
      } else {
        showSnack("Notifications weren't enabled. You can still check your ticket manually.", isError: true);
      }
    } catch (e, st) {
      showSnack("Couldn't enable notifications right now.", isError: true);
      debugPrint('[push] FAILED: $e');
      debugPrint('[push] stack: $st');
    }
  }

  Future<void> _registerDeviceToken() async {
    final uid = supabase.auth.currentUser?.id;
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb ? webPushVapidKey : null,
    );
    if (uid == null || token == null) return;
    try {
      await supabase.from('device_tokens').upsert({
        'token': token,
        'user_id': uid,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to register device token: $e');
    }
  }

  @override
  void dispose() {
    _foregroundMessageSub?.cancel();
    _openedAppMessageSub?.cancel();
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  Future<List<Shop>> _fetchShops() async {
    final uid = supabase.auth.currentUser?.id;
    final shopRows = await supabase.from('shops').select();
    final statsRows = await supabase.from('shop_stats').select();
    final statsById = {for (final r in statsRows) r['shop_id'] as String: r};

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
          subscribers: [],
          queue: [],
          nextTicket: row['next_ticket'] as int,
          isMine: row['owner_id'] == uid,
          subscriberCount: (statsById[row['id']]?['subscriber_count'] as int?) ?? 0,
          queueCount: (statsById[row['id']]?['queue_count'] as int?) ?? 0,
        ),
    ];
  }

  bool refreshingShops = false;

  Future<void> refreshShops() async {
    setState(() => refreshingShops = true);
    try {
      final loaded = await _fetchShops();
      setState(() {
        shops.clear();
        shops.addAll(loaded.where((s) => s.status == 'approved' || s.isMine));
      });
    } catch (e) {
      showSnack("Couldn't refresh shops. Check your connection.", isError: true);
      debugPrint('Failed to refresh shops: $e');
    } finally {
      if (mounted) setState(() => refreshingShops = false);
    }
  }

  Future<void> _loadInitialData() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    setState(() {
      loadingData = true;
      loadError = null;
    });
    try {
      final loaded = await _fetchShops();
      setState(() {
        shops.clear();
        shops.addAll(loaded.where((s) => s.status == 'approved' || s.isMine));
      });

      final mine = loaded.where((s) => s.isMine).firstOrNull;
      if (mine != null) {
        ownerShopId = mine.id;
        await _refreshOwnerShopDetail();
      }

      final subRows = await supabase
          .from('subscriptions')
          .select()
          .eq('customer_id', uid)
          .eq('status', 'active');
      setState(() => mySubShopIds = {for (final r in subRows) r['shop_id'] as String});

      final ticketRow = await supabase
          .from('queue_entries')
          .select()
          .eq('customer_id', uid)
          .inFilter('status', ['waiting', 'called'])
          .maybeSingle();
      if (ticketRow != null) {
        final shopId = ticketRow['shop_id'] as String;
        final position = await supabase.rpc('queue_position', params: {'p_shop_id': shopId});
        setState(() {
          myTicketShopId = shopId;
          myTicket = QueueEntry(
            id: ticketRow['id'] as String,
            ticketNo: ticketRow['ticket_no'] as int,
            name: ticketRow['display_name'] as String,
            barber: ticketRow['barber_id'] == null ? 'Next available' : '',
            status: ticketRow['status'] as String,
          );
          myTicketPosition = (position as num).toInt();
        });
      }

      final profileRow = await supabase.from('profiles').select('is_admin').eq('id', uid).maybeSingle();
      final admin = profileRow?['is_admin'] as bool? ?? false;
      if (admin) {
        final pendingRows = await supabase.from('shops').select('id').eq('status', 'pending');
        setState(() {
          isAdmin = true;
          pendingShopCount = pendingRows.length;
        });
      }
    } catch (e) {
      setState(() => loadError = "Couldn't load your data. Check your connection and try again.");
      debugPrint('Failed to load initial data: $e');
    } finally {
      if (mounted) setState(() => loadingData = false);
    }
  }

  Future<void> _refreshOwnerShopDetail() async {
    if (ownerShopId == null) return;
    final barberRows = await supabase.from('barbers').select().eq('shop_id', ownerShopId as Object);
    final queueRows = await supabase
        .from('queue_entries')
        .select()
        .eq('shop_id', ownerShopId as Object)
        .inFilter('status', ['waiting', 'called'])
        .order('ticket_no');
    final statsRow = await supabase.from('shop_stats').select().eq('shop_id', ownerShopId as Object).maybeSingle();
    final barbersById = {
      for (final b in barberRows) b['id'] as String: b['name'] as String,
    };
    final shop = ownerShop;
    if (shop == null) return;
    setState(() {
      shop.staff
        ..clear()
        ..addAll([
          for (final b in barberRows) Barber(id: b['id'] as String, name: b['name'] as String, active: b['active'] as bool)
        ]);
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
    });
  }

  bool subscribing = false;
  String? cancellingShopId;
  bool joiningQueue = false;
  bool leavingQueue = false;

  Future<void> subscribe(String shopId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => subscribing = true);
    try {
      final origin = kIsWeb ? Uri.base.origin : 'https://example.com';
      final response = await supabase.functions.invoke(
        'create-payfast-checkout',
        body: {'shop_id': shopId, 'return_url': origin, 'cancel_url': origin},
      );
      final checkoutUrl = response.data is Map ? response.data['checkout_url'] as String? : null;
      if (checkoutUrl == null) {
        throw Exception('No checkout URL returned: ${response.data}');
      }
      debugPrint('[payfast] checkout URL: $checkoutUrl');
      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        webOnlyWindowName: kIsWeb ? '_self' : null,
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
      if (!launched) {
        showSnack("Couldn't open the payment page.", isError: true);
      }
    } catch (e) {
      showSnack("Couldn't start checkout. Please try again.", isError: true);
      debugPrint('Failed to start PayFast checkout: $e');
    } finally {
      if (mounted) setState(() => subscribing = false);
    }
  }

  Future<void> cancelSubscription(String shopId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || !mySubShopIds.contains(shopId)) return;
    setState(() => cancellingShopId = shopId);
    try {
      final response = await supabase.functions.invoke(
        'cancel-payfast-subscription',
        body: {'shop_id': shopId},
      );
      if (response.status != 200) {
        throw Exception('Cancel failed: ${response.data}');
      }
      setState(() {
        shops.firstWhere((s) => s.id == shopId).subscriberCount -= 1;
        mySubShopIds = {...mySubShopIds}..remove(shopId);
        if (myTicketShopId == shopId) {
          myTicket = null;
          myTicketPosition = null;
          myTicketShopId = null;
        }
      });
      showSnack('Subscription cancelled');
    } catch (e) {
      showSnack("Couldn't cancel your subscription. Please try again.", isError: true);
      debugPrint('Failed to cancel subscription: $e');
    } finally {
      if (mounted) setState(() => cancellingShopId = null);
    }
  }

  Future<void> walkIn(String shopId) async {
    final shop = shops.firstWhere((s) => s.id == shopId);
    setState(() => joiningQueue = true);
    List<Barber> activeStaff = shop.staff.where((b) => b.active).toList();
    if (activeStaff.isEmpty && !shop.isMine) {
      try {
        final rows = await supabase.from('barbers').select().eq('shop_id', shopId).eq('active', true);
        activeStaff = [for (final b in rows) Barber(id: b['id'] as String, name: b['name'] as String)];
      } catch (e) {
        debugPrint('Failed to fetch barbers: $e');
      }
    }
    final barberId = activeStaff.isEmpty
        ? null
        : activeStaff[DateTime.now().millisecondsSinceEpoch % activeStaff.length].id;

    try {
      final row = await supabase.rpc('join_queue', params: {
        'p_shop_id': shopId,
        'p_barber_id': barberId,
      });
      final position = await supabase.rpc('queue_position', params: {'p_shop_id': shopId});
      final barberName = barberId == null
          ? 'Unassigned'
          : activeStaff.firstWhere((b) => b.id == barberId).name;
      setState(() {
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
      });
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
      debugPrint('Failed to join queue: $e');
    } finally {
      if (mounted) setState(() => joiningQueue = false);
    }
  }

  bool refreshingTicket = false;

  Future<void> refreshTicket() async {
    if (myTicket == null || myTicketShopId == null) return;
    setState(() => refreshingTicket = true);
    try {
      final row = await supabase.from('queue_entries').select().eq('id', myTicket!.id).maybeSingle();
      if (row == null || !['waiting', 'called'].contains(row['status'])) {
        setState(() {
          myTicket = null;
          myTicketPosition = null;
          myTicketShopId = null;
        });
        showSnack("Looks like you've been served — enjoy the cut!");
      } else {
        final position = await supabase.rpc('queue_position', params: {'p_shop_id': myTicketShopId});
        setState(() {
          myTicket!.status = row['status'] as String;
          myTicketPosition = (position as num).toInt();
        });
      }
    } catch (e) {
      showSnack("Couldn't refresh your ticket.", isError: true);
      debugPrint('Failed to refresh ticket: $e');
    } finally {
      if (mounted) setState(() => refreshingTicket = false);
    }
  }

  Future<void> leaveQueue() async {
    if (myTicket == null || myTicketShopId == null) return;
    final shopId = myTicketShopId!;
    setState(() => leavingQueue = true);
    try {
      await supabase.from('queue_entries').update({'status': 'left'}).eq('id', myTicket!.id);
      setState(() {
        shops.firstWhere((s) => s.id == shopId).queueCount -= 1;
        myTicket = null;
        myTicketPosition = null;
        myTicketShopId = null;
      });
      showSnack('Left the queue');
    } catch (e) {
      showSnack("Couldn't leave the queue. Please try again.", isError: true);
      debugPrint('Failed to leave queue: $e');
    } finally {
      if (mounted) setState(() => leavingQueue = false);
    }
  }

  bool creatingShop = false;
  String? createShopError;

  Future<void> createShop(String name, String area, int price, int chairs, LatLng? location) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    setState(() {
      creatingShop = true;
      createShopError = null;
    });
    try {
      final row = await supabase
          .from('shops')
          .insert({
            'owner_id': uid,
            'name': name,
            'area': area,
            'price': price,
            'chairs': chairs,
            'latitude': location?.latitude,
            'longitude': location?.longitude,
          })
          .select()
          .single();
      final shop = Shop(
        id: row['id'] as String,
        ownerId: uid,
        name: row['name'] as String,
        area: row['area'] as String,
        price: row['price'] as int,
        chairs: row['chairs'] as int,
        rating: (row['rating'] as num).toDouble(),
        latitude: (row['latitude'] as num?)?.toDouble(),
        longitude: (row['longitude'] as num?)?.toDouble(),
        status: row['status'] as String? ?? 'pending',
        subscribers: [],
        queue: [],
        nextTicket: row['next_ticket'] as int,
        isMine: true,
      );
      setState(() {
        shops.add(shop);
        ownerShopId = shop.id;
      });
      showSnack('$name submitted — it will show up for customers once approved');
    } catch (e) {
      final message = e.toString().contains('one_shop_per_owner')
          ? 'Your account already has a shop.'
          : 'Could not create shop: $e';
      setState(() => createShopError = message);
      showSnack('Could not create shop', isError: true);
    } finally {
      if (mounted) setState(() => creatingShop = false);
    }
  }

  Future<void> updateShopLocation(LatLng location) async {
    if (ownerShop == null) return;
    try {
      await supabase
          .from('shops')
          .update({'latitude': location.latitude, 'longitude': location.longitude})
          .eq('id', ownerShop!.id);
      setState(() {
        ownerShop!.latitude = location.latitude;
        ownerShop!.longitude = location.longitude;
      });
      showSnack('Location updated');
    } catch (e) {
      showSnack("Couldn't update location. Please try again.", isError: true);
      debugPrint('Failed to update shop location: $e');
    }
  }

  bool uploadingPhoto = false;

  Future<void> uploadShopPhoto() async {
    if (ownerShop == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;

    setState(() => uploadingPhoto = true);
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
      setState(() => ownerShop!.photoUrl = bustedUrl);
      showSnack('Photo updated');
    } catch (e) {
      showSnack("Couldn't upload photo. Please try again.", isError: true);
      debugPrint('Failed to upload shop photo: $e');
    } finally {
      if (mounted) setState(() => uploadingPhoto = false);
    }
  }

  bool refreshingQueue = false;

  Future<void> refreshOwnerShop() async {
    setState(() => refreshingQueue = true);
    try {
      await _refreshOwnerShopDetail();
    } catch (e) {
      showSnack('Refresh failed. Check your connection.', isError: true);
      debugPrint('Failed to refresh owner shop: $e');
    } finally {
      if (mounted) setState(() => refreshingQueue = false);
    }
  }

  Future<void> callCustomer(String queueId) async {
    if (ownerShop == null) return;
    try {
      await supabase.from('queue_entries').update({'status': 'called'}).eq('id', queueId);
      setState(() {
        final entry = ownerShop!.queue.firstWhere((q) => q.id == queueId);
        entry.status = 'called';
      });
      showSnack('Customer called');
    } catch (e) {
      showSnack("Couldn't call that customer. Please try again.", isError: true);
      debugPrint('Failed to call customer: $e');
    }
  }

  Future<void> completeQueueEntry(String queueId) async {
    if (ownerShop == null) return;
    try {
      await supabase
          .from('queue_entries')
          .update({'status': 'done', 'completed_at': DateTime.now().toIso8601String()})
          .eq('id', queueId);
      setState(() {
        ownerShop!.queue.removeWhere((q) => q.id == queueId);
        ownerShop!.queueCount = ownerShop!.queue.length;
      });
      showSnack('Marked done');
    } catch (e) {
      showSnack("Couldn't update that ticket. Please try again.", isError: true);
      debugPrint('Failed to complete queue entry: $e');
    }
  }

  Future<void> addBarber(String name) async {
    if (ownerShop == null || name.trim().isEmpty) return;
    try {
      final row = await supabase
          .from('barbers')
          .insert({'shop_id': ownerShop!.id, 'name': name.trim()})
          .select()
          .single();
      setState(() {
        ownerShop!.staff.add(Barber(id: row['id'] as String, name: row['name'] as String, active: row['active'] as bool));
      });
      showSnack('${name.trim()} added to the team');
    } catch (e) {
      showSnack("Couldn't add barber. Please try again.", isError: true);
      debugPrint('Failed to add barber: $e');
    }
  }

  Future<void> removeBarber(String barberId) async {
    if (ownerShop == null) return;
    try {
      await supabase.from('barbers').delete().eq('id', barberId);
      setState(() => ownerShop!.staff.removeWhere((b) => b.id == barberId));
      showSnack('Barber removed');
    } catch (e) {
      showSnack("Couldn't remove barber. Please try again.", isError: true);
      debugPrint('Failed to remove barber: $e');
    }
  }

  Future<void> toggleBarberActive(String barberId) async {
    if (ownerShop == null) return;
    final barber = ownerShop!.staff.firstWhere((b) => b.id == barberId);
    final newActive = !barber.active;
    try {
      await supabase.from('barbers').update({'active': newActive}).eq('id', barberId);
      setState(() => barber.active = newActive);
    } catch (e) {
      showSnack("Couldn't update barber status.", isError: true);
      debugPrint('Failed to update barber: $e');
    }
  }

  Future<void> _refreshPendingShopCount() async {
    if (!isAdmin) return;
    try {
      final rows = await supabase.from('shops').select('id').eq('status', 'pending');
      if (mounted) setState(() => pendingShopCount = rows.length);
    } catch (e) {
      debugPrint('Failed to refresh pending shop count: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      showSnack('Sign out failed. Please try again.', isError: true);
      debugPrint('Failed to sign out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'The Regular',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ToggleButtons(
              borderRadius: BorderRadius.circular(20),
              isSelected: [!isOwnerMode, isOwnerMode],
              onPressed: (i) => setState(() => isOwnerMode = i == 1),
              selectedColor: AppColors.bg,
              fillColor: AppColors.brass,
              color: AppColors.textMuted,
              constraints: const BoxConstraints(minHeight: 32, minWidth: 70),
              children: const [Text('Customer'), Text('Owner')],
            ),
          ),
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shield_outlined, color: AppColors.textMuted, size: 20),
                    tooltip: 'Admin',
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminScreen()));
                      _refreshPendingShopCount();
                    },
                  ),
                  if (pendingShopCount > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          '$pendingShopCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textMuted, size: 20),
            onPressed: signOut,
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: loadingData
          ? const Center(child: CircularProgressIndicator(color: AppColors.brass))
          : loadError != null
              ? _ErrorState(message: loadError!, onRetry: _loadInitialData)
              : isOwnerMode
                  ? OwnerFlow(
                      ownerShop: ownerShop,
                      onCreateShop: createShop,
                      creatingShop: creatingShop,
                      createShopError: createShopError,
                      onRefresh: refreshOwnerShop,
                      refreshingQueue: refreshingQueue,
                      onCompleteQueueEntry: completeQueueEntry,
                      onCallCustomer: callCustomer,
                      onAddBarber: addBarber,
                      onRemoveBarber: removeBarber,
                      onToggleBarberActive: toggleBarberActive,
                      onUpdateLocation: updateShopLocation,
                      onUploadPhoto: uploadShopPhoto,
                      uploadingPhoto: uploadingPhoto,
                    )
                  : CustomerFlow(
                      shops: shops,
                      mySubShopIds: mySubShopIds,
                      myTicket: myTicket,
                      myTicketPosition: myTicketPosition,
                      myTicketShopId: myTicketShopId,
                      subscribing: subscribing,
                      cancellingShopId: cancellingShopId,
                      joiningQueue: joiningQueue,
                      leavingQueue: leavingQueue,
                      refreshingShops: refreshingShops,
                      onRefreshShops: refreshShops,
                      notificationsEnabled: notificationsEnabled,
                      checkingNotificationPermission: checkingNotificationPermission,
                      onEnableNotifications: requestNotificationPermission,
                      refreshingTicket: refreshingTicket,
                      onRefreshTicket: refreshTicket,
                      onSubscribe: subscribe,
                      onCancelSubscription: cancelSubscription,
                      onWalkIn: walkIn,
                      onLeaveQueue: leaveQueue,
                    ),
    );
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.textFaint, size: 36),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            CustomOutlineButton(label: 'Try again', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}