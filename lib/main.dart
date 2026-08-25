import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'supabase_config.dart';

final supabase = Supabase.instance.client;

// Requests location permission if needed and returns the device's current
// position, or null (with a snackbar explaining why) if it's unavailable.
Future<Position?> getCurrentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    showSnack('Turn on location services to use this.', isError: true);
    return null;
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    showSnack('Location permission was denied.', isError: true);
    return null;
  }
  if (permission == LocationPermission.deniedForever) {
    showSnack('Location permission is blocked. Enable it in your device settings.', isError: true);
    return null;
  }
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
  } catch (e) {
    showSnack('Could not get your location.', isError: true);
    return null;
  }
}
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const RootApp());
}

// Shows a toast-style message from anywhere in the app, success or error,
// without needing to thread a BuildContext down through every callback.
void showSnack(String message, {bool isError = false}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? AppColors.red : AppColors.brass, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.text, fontSize: 13))),
        ],
      ),
      backgroundColor: AppColors.surface2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isError ? AppColors.red.withOpacity(0.4) : AppColors.line),
      ),
      duration: Duration(seconds: isError ? 4 : 2),
    ),
  );
}

// ---------- ROOT + AUTH GATE ----------

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Regular',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
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
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session == null) return const AuthScreen();
        return const TheRegularApp();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  bool isSignUp = false;
  bool loading = false;
  String? error;

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (isSignUp) {
        final res = await supabase.auth.signUp(
          email: emailCtrl.text.trim(),
          password: passwordCtrl.text,
          data: {'full_name': nameCtrl.text.trim()},
        );
        if (res.session == null && mounted) {
          showSnack('Check your email to confirm your account before signing in.');
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: emailCtrl.text.trim(),
          password: passwordCtrl.text,
        );
      }
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('The Regular',
                    style: TextStyle(color: AppColors.text, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(isSignUp ? 'Create an account' : 'Welcome back',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 24),
                if (isSignUp) ...[
                  _Field(label: 'Name', controller: nameCtrl, hint: 'Your name'),
                ],
                _Field(label: 'Email', controller: emailCtrl, hint: 'you@example.com'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PASSWORD',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
                      const SizedBox(height: 5),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        style: const TextStyle(color: AppColors.text),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: const TextStyle(color: AppColors.textFaint),
                          filled: true,
                          fillColor: AppColors.surface2,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
                if (error != null) ...[
                  Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                _PrimaryButton(label: isSignUp ? 'Sign up' : 'Sign in', loading: loading, onTap: submit),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => isSignUp = !isSignUp),
                  child: Text(
                    isSignUp ? 'Already have an account? Sign in' : "New here? Create an account",
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- THEME ----------

class AppColors {
  static const bg = Color(0xFF17140F);
  static const surface = Color(0xFF211C15);
  static const surface2 = Color(0xFF2B241A);
  static const brass = Color(0xFFC99A3B);
  static const red = Color(0xFFA8393B);
  static const text = Color(0xFFF3ECDD);
  static const textMuted = Color(0xFF9C9282);
  static const textFaint = Color(0xFF6E6555);
  static const line = Color(0xFF3A3225);
}

// ---------- MODELS ----------

class QueueEntry {
  final String id;
  final int ticketNo;
  final String name;
  final String barber;
  QueueEntry({required this.id, required this.ticketNo, required this.name, required this.barber});
}

class Barber {
  final String id;
  String name;
  bool active;
  Barber({required this.id, required this.name, this.active = true});
}

class Shop {
  final String id;
  final String ownerId;
  String name;
  String area;
  int price;
  int chairs;
  double rating;
  double? latitude;
  double? longitude;
  List<String> subscribers;
  List<QueueEntry> queue;
  List<Barber> staff;
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
    this.latitude,
    this.longitude,
    required this.subscribers,
    required this.queue,
    List<Barber>? staff,
    required this.nextTicket,
    this.isMine = false,
    this.subscriberCount = 0,
    this.queueCount = 0,
  }) : staff = staff ?? [];
}


// ---------- ROOT APP ----------

class TheRegularApp extends StatefulWidget {
  const TheRegularApp({super.key});
  @override
  State<TheRegularApp> createState() => _TheRegularAppState();
}

class _TheRegularAppState extends State<TheRegularApp> {
  bool isOwnerMode = false;
  bool loadingData = true;
  String? loadError;

  final List<Shop> shops = [];
  String? mySubShopId;
  QueueEntry? myTicket;
  int? myTicketPosition;
  String? myTicketShopId;
  String? ownerShopId;

  Shop? get ownerShop => shops.where((s) => s.id == ownerShopId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    setState(() {
      loadingData = true;
      loadError = null;
    });
    try {
      // 1. All shops, for customer browsing, joined with public aggregate counts.
      final shopRows = await supabase.from('shops').select();
      final statsRows = await supabase.from('shop_stats').select();
      final statsById = {for (final r in statsRows) r['shop_id'] as String: r};

      final loaded = <Shop>[];
      for (final row in shopRows) {
        final stats = statsById[row['id']];
        loaded.add(Shop(
          id: row['id'] as String,
          ownerId: row['owner_id'] as String,
          name: row['name'] as String,
          area: row['area'] as String,
          price: row['price'] as int,
          chairs: row['chairs'] as int,
          rating: (row['rating'] as num).toDouble(),
          latitude: (row['latitude'] as num?)?.toDouble(),
          longitude: (row['longitude'] as num?)?.toDouble(),
          subscribers: [],
          queue: [],
          nextTicket: row['next_ticket'] as int,
          isMine: row['owner_id'] == uid,
          subscriberCount: (stats?['subscriber_count'] as int?) ?? 0,
          queueCount: (stats?['queue_count'] as int?) ?? 0,
        ));
      }
      setState(() {
        shops.clear();
        shops.addAll(loaded);
      });

      // 2. If one of these shops is mine, load the real barber + queue detail for it.
      final mine = loaded.where((s) => s.isMine).firstOrNull;
      if (mine != null) {
        ownerShopId = mine.id;
        await _refreshOwnerShopDetail();
      }

      // 3. My active subscription, if any.
      final subRow = await supabase
          .from('subscriptions')
          .select()
          .eq('customer_id', uid)
          .eq('status', 'active')
          .maybeSingle();
      if (subRow != null) {
        setState(() => mySubShopId = subRow['shop_id'] as String);
      }

      // 4. My active queue ticket, if any.
      final ticketRow = await supabase
          .from('queue_entries')
          .select()
          .eq('customer_id', uid)
          .eq('status', 'waiting')
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
          );
          myTicketPosition = (position as num).toInt();
        });
      }
    } catch (e) {
      setState(() => loadError = "Couldn't load your data. Check your connection and try again.");
      debugPrint('Failed to load initial data: $e');
    } finally {
      if (mounted) setState(() => loadingData = false);
    }
  }

  // Re-pulls the real barbers + waiting queue for the shop I own, from Supabase.
  Future<void> _refreshOwnerShopDetail() async {
    if (ownerShopId == null) return;
    final barberRows = await supabase.from('barbers').select().eq('shop_id', ownerShopId as Object);
    final queueRows = await supabase
        .from('queue_entries')
        .select()
        .eq('shop_id', ownerShopId as Object)
        .eq('status', 'waiting')
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
            )
        ]);
      shop.queueCount = shop.queue.length;
      if (statsRow != null) shop.subscriberCount = statsRow['subscriber_count'] as int;
    });
  }

  bool subscribing = false;
  bool cancelling = false;
  bool joiningQueue = false;
  bool leavingQueue = false;

  Future<void> subscribe(String shopId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final shopName = shops.firstWhere((s) => s.id == shopId).name;
    setState(() => subscribing = true);
    try {
      await supabase.from('subscriptions').insert({'shop_id': shopId, 'customer_id': uid});
      setState(() {
        mySubShopId = shopId;
        shops.firstWhere((s) => s.id == shopId).subscriberCount += 1;
      });
      showSnack("You're subscribed to $shopName");
    } catch (e) {
      showSnack("Couldn't subscribe. Please try again.", isError: true);
      debugPrint('Failed to subscribe: $e');
    } finally {
      if (mounted) setState(() => subscribing = false);
    }
  }

  Future<void> cancelSubscription() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || mySubShopId == null) return;
    final shopId = mySubShopId!;
    setState(() => cancelling = true);
    try {
      await supabase
          .from('subscriptions')
          .update({'status': 'cancelled', 'cancelled_at': DateTime.now().toIso8601String()})
          .eq('shop_id', shopId)
          .eq('customer_id', uid)
          .eq('status', 'active');
      setState(() {
        shops.firstWhere((s) => s.id == shopId).subscriberCount -= 1;
        mySubShopId = null;
        myTicket = null;
        myTicketPosition = null;
        myTicketShopId = null;
      });
      showSnack('Subscription cancelled');
    } catch (e) {
      showSnack("Couldn't cancel your subscription. Please try again.", isError: true);
      debugPrint('Failed to cancel subscription: $e');
    } finally {
      if (mounted) setState(() => cancelling = false);
    }
  }

  String _pickBarber(Shop shop, int seed) {
    final active = shop.staff.where((b) => b.active).toList();
    if (active.isEmpty) return "Unassigned";
    return active[seed % active.length].name;
  }

  Future<void> walkIn(String shopId) async {
    final shop = shops.firstWhere((s) => s.id == shopId);
    setState(() => joiningQueue = true);
    // Only the owner's own shop has its real barber list loaded locally;
    // for any other shop, fetch active barbers fresh before picking one.
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
        );
        myTicketPosition = (position as num).toInt();
        myTicketShopId = shopId;
        shop.queueCount += 1;
      });
      showSnack("You're in line — ticket #${row['ticket_no']}");
    } on PostgrestException catch (e) {
      showSnack(e.message.contains('No active subscription') ? "You need an active subscription to walk in." : e.message,
          isError: true);
    } catch (e) {
      showSnack("Couldn't join the queue. Please try again.", isError: true);
      debugPrint('Failed to join queue: $e');
    } finally {
      if (mounted) setState(() => joiningQueue = false);
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
        subscribers: [],
        queue: [],
        nextTicket: row['next_ticket'] as int,
        isMine: true,
      );
      setState(() {
        shops.add(shop);
        ownerShopId = shop.id;
      });
      showSnack(location == null ? '$name is live (no location set)' : '$name is live');
    } catch (e) {
      setState(() => createShopError = 'Could not create shop: $e');
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
                      onAddBarber: addBarber,
                      onRemoveBarber: removeBarber,
                      onToggleBarberActive: toggleBarberActive,
                      onUpdateLocation: updateShopLocation,
                    )
                  : CustomerFlow(
                      shops: shops,
                      mySubShopId: mySubShopId,
                      myTicket: myTicket,
                      myTicketPosition: myTicketPosition,
                      myTicketShopId: myTicketShopId,
                      subscribing: subscribing,
                      cancelling: cancelling,
                      joiningQueue: joiningQueue,
                      leavingQueue: leavingQueue,
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

// ---------- LOCATION PICKER ----------
// Used both when creating a shop and when fixing a shop's location later.
// Starts centered on the device's current location if available, but the
// owner can tap anywhere on the map to move the pin — so this works whether
// or not they're physically standing in the shop right now.

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? picked;
  bool locating = false;
  final mapController = MapController();

  static const _fallback = LatLng(-26.2041, 28.0473); // Johannesburg

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      picked = widget.initial;
    } else {
      _useCurrentLocation(silent: true);
    }
  }

  Future<void> _useCurrentLocation({bool silent = false}) async {
    setState(() => locating = true);
    final pos = await getCurrentPosition();
    if (pos != null) {
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() => picked = point);
      mapController.move(point, 15);
    } else if (!silent) {
      // getCurrentPosition already showed a snackbar explaining why.
    }
    if (mounted) setState(() => locating = false);
  }

  @override
  Widget build(BuildContext context) {
    final center = picked ?? _fallback;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Set shop location', style: TextStyle(color: AppColors.text, fontSize: 16)),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              "Tap anywhere on the map to place the pin, or drag the map under it. Doesn't need to be exact.",
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: picked != null ? 15 : 11,
                    onTap: (tapPosition, point) => setState(() => picked = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.theregular.app',
                    ),
                    MarkerLayer(
                      markers: [
                        if (picked != null)
                          Marker(
                            point: picked!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on, color: AppColors.red, size: 40),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'locate',
                    backgroundColor: AppColors.surface2,
                    onPressed: locating ? null : _useCurrentLocation,
                    child: locating
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brass),
                          )
                        : const Icon(Icons.my_location, color: AppColors.brass, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _PrimaryButton(
              label: picked == null ? 'Tap the map to place a pin' : 'Confirm this location',
              onTap: picked == null ? () {} : () => Navigator.of(context).pop(picked),
            ),
          ),
        ],
      ),
    );
  }
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
            _OutlineButton(label: 'Try again', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

// ---------- CUSTOMER FLOW ----------

class CustomerFlow extends StatefulWidget {
  final List<Shop> shops;
  final String? mySubShopId;
  final QueueEntry? myTicket;
  final int? myTicketPosition;
  final String? myTicketShopId;
  final bool subscribing;
  final bool cancelling;
  final bool joiningQueue;
  final bool leavingQueue;
  final void Function(String shopId) onSubscribe;
  final VoidCallback onCancelSubscription;
  final Future<void> Function(String shopId) onWalkIn;
  final VoidCallback onLeaveQueue;

  const CustomerFlow({
    super.key,
    required this.shops,
    required this.mySubShopId,
    required this.myTicket,
    required this.myTicketPosition,
    required this.myTicketShopId,
    required this.subscribing,
    required this.cancelling,
    required this.joiningQueue,
    required this.leavingQueue,
    required this.onSubscribe,
    required this.onCancelSubscription,
    required this.onWalkIn,
    required this.onLeaveQueue,
  });

  @override
  State<CustomerFlow> createState() => _CustomerFlowState();
}

class _CustomerFlowState extends State<CustomerFlow> {
  int tab = 0; // 0 = home, 1 = ticket, 2 = account, 3 = map
  Shop? openedShop;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (openedShop != null) {
      body = ShopDetailScreen(
        shop: openedShop!,
        isSubscribed: widget.mySubShopId == openedShop!.id,
        hasOtherSub: widget.mySubShopId != null && widget.mySubShopId != openedShop!.id,
        subscribing: widget.subscribing,
        joiningQueue: widget.joiningQueue,
        cancelling: widget.cancelling,
        onBack: () => setState(() => openedShop = null),
        onSubscribe: () => widget.onSubscribe(openedShop!.id),
        onWalkIn: () async {
          final shopId = openedShop!.id;
          await widget.onWalkIn(shopId);
          if (mounted) {
            setState(() {
              openedShop = null;
              tab = 1;
            });
          }
        },
        onCancel: widget.onCancelSubscription,
      );
    } else if (tab == 1 && widget.myTicket != null) {
      final shop = widget.shops.firstWhere((s) => s.id == widget.myTicketShopId);
      body = TicketScreen(
        shop: shop,
        ticket: widget.myTicket!,
        position: widget.myTicketPosition ?? 1,
        leaving: widget.leavingQueue,
        onLeave: widget.onLeaveQueue,
      );
    } else if (tab == 2) {
      body = AccountScreen(
        shop: widget.mySubShopId == null
            ? null
            : widget.shops.firstWhere((s) => s.id == widget.mySubShopId),
        cancelling: widget.cancelling,
        onCancel: widget.onCancelSubscription,
      );
    } else if (tab == 3) {
      body = ShopMapScreen(
        shops: widget.shops,
        onOpen: (s) => setState(() => openedShop = s),
      );
    } else {
      body = ShopListScreen(
        shops: widget.shops,
        onOpen: (s) => setState(() => openedShop = s),
      );
    }

    return Column(
      children: [
        Expanded(child: body),
        if (openedShop == null)
          BottomAppBar(
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem('Home', 0),
                _navItem('Map', 3),
                _navItem('Ticket', 1, disabled: widget.myTicket == null),
                _navItem('Account', 2),
              ],
            ),
          ),
      ],
    );
  }

  Widget _navItem(String label, int index, {bool disabled = false}) {
    final active = tab == index;
    return TextButton(
      onPressed: disabled ? null : () => setState(() => tab = index),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: active ? AppColors.brass : (disabled ? AppColors.textFaint : AppColors.textMuted),
        ),
      ),
    );
  }
}

class ShopListScreen extends StatelessWidget {
  final List<Shop> shops;
  final void Function(Shop) onOpen;
  const ShopListScreen({super.key, required this.shops, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "One monthly fee. Unlimited weekly cuts. Walk in, no booking needed.",
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ...shops.map((s) => _ShopCard(shop: s, onTap: () => onOpen(s))),
      ],
    );
  }
}

class ShopMapScreen extends StatefulWidget {
  final List<Shop> shops;
  final void Function(Shop) onOpen;
  const ShopMapScreen({super.key, required this.shops, required this.onOpen});

  @override
  State<ShopMapScreen> createState() => _ShopMapScreenState();
}

class _ShopMapScreenState extends State<ShopMapScreen> {
  Position? myPosition;
  bool loading = true;
  String? error;
  final mapController = MapController();

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    setState(() {
      loading = true;
      error = null;
    });
    final pos = await getCurrentPosition();
    setState(() {
      myPosition = pos;
      loading = false;
      if (pos == null) error = "Couldn't get your location. Showing shops without centering the map.";
    });
  }

  double? _distanceKm(Shop shop) {
    if (myPosition == null || shop.latitude == null || shop.longitude == null) return null;
    final meters = Geolocator.distanceBetween(
      myPosition!.latitude,
      myPosition!.longitude,
      shop.latitude!,
      shop.longitude!,
    );
    return meters / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final located = widget.shops.where((s) => s.latitude != null && s.longitude != null).toList();
    final center = myPosition != null
        ? LatLng(myPosition!.latitude, myPosition!.longitude)
        : (located.isNotEmpty ? LatLng(located.first.latitude!, located.first.longitude!) : const LatLng(-26.2041, 28.0473)); // Johannesburg fallback

    final sorted = [...located]
      ..sort((a, b) => (_distanceKm(a) ?? 999999).compareTo(_distanceKm(b) ?? 999999));

    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brass));
    }

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(initialCenter: center, initialZoom: 13),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.theregular.app',
                  ),
                  MarkerLayer(
                    markers: [
                      if (myPosition != null)
                        Marker(
                          point: LatLng(myPosition!.latitude, myPosition!.longitude),
                          width: 20,
                          height: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.brass,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.bg, width: 3),
                            ),
                          ),
                        ),
                      for (final shop in located)
                        Marker(
                          point: LatLng(shop.latitude!, shop.longitude!),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => widget.onOpen(shop),
                            child: const Icon(Icons.content_cut, color: AppColors.red, size: 32),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (error != null)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(error!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ),
                        TextButton(
                          onPressed: _locate,
                          child: const Text('Retry', style: TextStyle(color: AppColors.brass, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: sorted.isEmpty
              ? const Center(
                  child: Text("No shops have a location set yet.", style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final shop in sorted) _NearbyShopCard(shop: shop, distanceKm: _distanceKm(shop), onTap: () => widget.onOpen(shop)),
                    if (widget.shops.length > located.length)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "${widget.shops.length - located.length} shop(s) haven't set a location yet and aren't shown here.",
                          style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _NearbyShopCard extends StatelessWidget {
  final Shop shop;
  final double? distanceKm;
  final VoidCallback onTap;
  const _NearbyShopCard({required this.shop, required this.distanceKm, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.name, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('${shop.area} · R${shop.price}/mo', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (distanceKm != null)
              Text(
                distanceKm! < 1 ? '${(distanceKm! * 1000).round()} m' : '${distanceKm!.toStringAsFixed(1)} km',
                style: const TextStyle(color: AppColors.brass, fontSize: 13, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final Shop shop;
  final VoidCallback onTap;
  const _ShopCard({required this.shop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: shop.isMine ? AppColors.brass : AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(shop.name,
                    style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
                if (shop.isMine)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.brass, borderRadius: BorderRadius.circular(4)),
                    child: const Text('YOURS',
                        style: TextStyle(color: AppColors.bg, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${shop.area} · ${shop.chairs} chairs · ${shop.rating}★',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('R${shop.price}/mo · unlimited cuts',
                    style: const TextStyle(color: AppColors.brass, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  shop.queueCount == 0 ? 'No wait' : '${shop.queueCount} in queue',
                  style: TextStyle(color: shop.queueCount == 0 ? AppColors.textFaint : AppColors.text, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ShopDetailScreen extends StatelessWidget {
  final Shop shop;
  final bool isSubscribed;
  final bool hasOtherSub;
  final bool subscribing;
  final bool joiningQueue;
  final bool cancelling;
  final VoidCallback onBack;
  final VoidCallback onSubscribe;
  final VoidCallback onWalkIn;
  final VoidCallback onCancel;

  const ShopDetailScreen({
    super.key,
    required this.shop,
    required this.isSubscribed,
    required this.hasOtherSub,
    required this.subscribing,
    required this.joiningQueue,
    required this.cancelling,
    required this.onBack,
    required this.onSubscribe,
    required this.onWalkIn,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.textMuted), onPressed: onBack),
          Text(shop.name, style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        Text('${shop.area} · ${shop.chairs} chairs · ${shop.rating}★',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 14),
        RichText(
          text: TextSpan(children: [
            TextSpan(
                text: 'R${shop.price}',
                style: const TextStyle(color: AppColors.brass, fontSize: 32, fontWeight: FontWeight.bold)),
            const TextSpan(text: ' / month', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ]),
        ),
        const Text('Includes one cut every week. Cancel anytime.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const Divider(color: AppColors.line, height: 32),
        Text(
          shop.queueCount == 0 ? 'No wait right now' : '${shop.queueCount} people in the queue right now',
          style: const TextStyle(color: AppColors.text, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (isSubscribed) ...[
          const Text("✓ YOU'RE A MEMBER HERE",
              style: TextStyle(color: AppColors.brass, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _PrimaryButton(label: 'Walk in now', onTap: onWalkIn, loading: joiningQueue),
          const SizedBox(height: 10),
          _OutlineButton(label: 'Cancel subscription', color: AppColors.red, onTap: onCancel, loading: cancelling),
        ] else if (hasOtherSub) ...[
          const Text("You're already subscribed to another shop. Cancel that one first to switch.",
              style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
        ] else
          _PrimaryButton(label: 'Subscribe — R${shop.price}/month', onTap: onSubscribe, loading: subscribing),
      ],
    );
  }
}

class TicketScreen extends StatelessWidget {
  final Shop shop;
  final QueueEntry ticket;
  final int position;
  final bool leaving;
  final VoidCallback onLeave;
  const TicketScreen({
    super.key,
    required this.shop,
    required this.ticket,
    required this.position,
    required this.leaving,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.brass.withOpacity(0.5), style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Text(shop.name,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1)),
                const SizedBox(height: 6),
                Text('${ticket.ticketNo}',
                    style: const TextStyle(color: AppColors.brass, fontSize: 56, fontWeight: FontWeight.bold)),
                Text('Position $position in line · barber ${ticket.barber}',
                    style: const TextStyle(color: AppColors.text, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Est. wait ~${position * 8} min',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _OutlineButton(label: 'Leave queue', color: AppColors.red, onTap: onLeave, loading: leaving),
        ],
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  final Shop? shop;
  final bool cancelling;
  final VoidCallback onCancel;
  const AccountScreen({super.key, required this.shop, required this.cancelling, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: shop == null
          ? const Text("No active subscription yet. Find a shop from the home tab to get started.",
              style: TextStyle(color: AppColors.textFaint, fontSize: 13))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Active subscription', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 4),
                Text(shop!.name, style: const TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 18),
                _OutlineButton(label: 'Cancel subscription', color: AppColors.red, onTap: onCancel, loading: cancelling),
              ],
            ),
    );
  }
}

// ---------- OWNER FLOW ----------

class OwnerFlow extends StatefulWidget {
  final Shop? ownerShop;
  final void Function(String name, String area, int price, int chairs, LatLng? location) onCreateShop;
  final bool creatingShop;
  final String? createShopError;
  final VoidCallback onRefresh;
  final bool refreshingQueue;
  final void Function(String queueId) onCompleteQueueEntry;
  final void Function(String name) onAddBarber;
  final void Function(String barberId) onRemoveBarber;
  final void Function(String barberId) onToggleBarberActive;
  final void Function(LatLng location) onUpdateLocation;

  const OwnerFlow({
    super.key,
    required this.ownerShop,
    required this.onCreateShop,
    required this.creatingShop,
    required this.createShopError,
    required this.onRefresh,
    required this.refreshingQueue,
    required this.onCompleteQueueEntry,
    required this.onAddBarber,
    required this.onRemoveBarber,
    required this.onToggleBarberActive,
    required this.onUpdateLocation,
  });

  @override
  State<OwnerFlow> createState() => _OwnerFlowState();
}

class _OwnerFlowState extends State<OwnerFlow> {
  final nameCtrl = TextEditingController();
  final areaCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final chairsCtrl = TextEditingController();
  LatLng? pickedLocation;
  final newBarberCtrl = TextEditingController();
  bool showStaff = false;

  @override
  Widget build(BuildContext context) {
    if (widget.ownerShop == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('List your shop', style: TextStyle(color: AppColors.text, fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Set a monthly price, and let regulars walk in without booking.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 18),
          _Field(label: 'Shop name', controller: nameCtrl, hint: 'e.g. Corner Cuts'),
          _Field(label: 'Area / suburb', controller: areaCtrl, hint: 'e.g. Rosebank'),
          Row(children: [
            Expanded(child: _Field(label: 'Price / month (R)', controller: priceCtrl, hint: '450', numeric: true)),
            const SizedBox(width: 12),
            Expanded(child: _Field(label: 'Chairs', controller: chairsCtrl, hint: '3', numeric: true)),
          ]),
          const Text('LOCATION', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 5),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final result = await Navigator.of(context).push<LatLng>(
                MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: pickedLocation)),
              );
              if (result != null) setState(() => pickedLocation = result);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(pickedLocation == null ? Icons.add_location_alt_outlined : Icons.check_circle,
                      color: pickedLocation == null ? AppColors.textMuted : AppColors.brass, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    pickedLocation == null ? 'Set on map (optional, but recommended)' : 'Location set — tap to adjust',
                    style: TextStyle(color: pickedLocation == null ? AppColors.textMuted : AppColors.text, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.createShopError != null) ...[
            Text(widget.createShopError!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
            const SizedBox(height: 8),
          ],
          _PrimaryButton(
            label: 'Create shop',
            loading: widget.creatingShop,
            onTap: () {
              final price = int.tryParse(priceCtrl.text) ?? 0;
              final chairs = int.tryParse(chairsCtrl.text) ?? 0;
              if (nameCtrl.text.isEmpty || areaCtrl.text.isEmpty || price == 0 || chairs == 0) {
                showSnack('Fill in every field first', isError: true);
                return;
              }
              widget.onCreateShop(nameCtrl.text, areaCtrl.text, price, chairs, pickedLocation);
            },
          ),
        ],
      );
    }

    final shop = widget.ownerShop!;
    final activeStaffCount = shop.staff.where((b) => b.active).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.name, style: const TextStyle(color: AppColors.text, fontSize: 19, fontWeight: FontWeight.bold)),
                  Text('${shop.area} · ${shop.chairs} chairs', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => setState(() => showStaff = !showStaff),
              style: OutlinedButton.styleFrom(
                foregroundColor: showStaff ? AppColors.brass : AppColors.textMuted,
                side: BorderSide(color: showStaff ? AppColors.brass : AppColors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(showStaff ? 'Queue' : 'Staff'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final initial = shop.latitude != null && shop.longitude != null
                ? LatLng(shop.latitude!, shop.longitude!)
                : null;
            final result = await Navigator.of(context).push<LatLng>(
              MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: initial)),
            );
            if (result != null) widget.onUpdateLocation(result);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(
                  shop.latitude == null ? Icons.location_off_outlined : Icons.location_on_outlined,
                  color: shop.latitude == null ? AppColors.red.withOpacity(0.8) : AppColors.brass,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shop.latitude == null ? "No location set — you won't show on the map" : 'Location set — tap to update',
                    style: const TextStyle(color: AppColors.text, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!showStaff) ...[
          Row(children: [
            Expanded(child: _MetricCard(label: 'Subscribers', value: '${shop.subscriberCount}')),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(label: 'Monthly revenue', value: 'R${shop.subscriberCount * shop.price}', accent: true)),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(label: 'In queue', value: '${shop.queue.length}')),
          ]),
          const SizedBox(height: 16),
          _OutlineButton(
            label: 'Refresh queue',
            loading: widget.refreshingQueue,
            onTap: widget.onRefresh,
          ),
          const SizedBox(height: 18),
          const Text("TODAY'S QUEUE", style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          if (shop.queue.isEmpty)
            const Text("Nobody's waiting right now.", style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
          ...shop.queue.map((q) => Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: '#${q.ticketNo} ', style: const TextStyle(color: AppColors.brass, fontWeight: FontWeight.bold)),
                      TextSpan(text: '${q.name} → ${q.barber}', style: const TextStyle(color: AppColors.text)),
                    ])),
                    GestureDetector(
                      onTap: () => widget.onCompleteQueueEntry(q.id),
                      child: const Text('Done', style: TextStyle(color: AppColors.textMuted, decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              )),
        ] else ...[
          Text(
            '$activeStaffCount of ${shop.staff.length} barbers on duty · ${shop.chairs} chairs',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: newBarberCtrl,
                  style: const TextStyle(color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: "Barber's name",
                    hintStyle: const TextStyle(color: AppColors.textFaint),
                    filled: true,
                    fillColor: AppColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) {
                    widget.onAddBarber(newBarberCtrl.text);
                    newBarberCtrl.clear();
                  },
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  widget.onAddBarber(newBarberCtrl.text);
                  newBarberCtrl.clear();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brass,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (shop.staff.isEmpty)
            const Text(
              "No barbers on the team yet. Add one above so walk-ins can be assigned.",
              style: TextStyle(color: AppColors.textFaint, fontSize: 13),
            ),
          ...shop.staff.map((b) {
            final onDutyCount = shop.queue.where((q) => q.barber == b.name).length;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.name,
                            style: TextStyle(
                              color: b.active ? AppColors.text : AppColors.textFaint,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            )),
                        Text(
                          b.active ? '$onDutyCount in queue now' : 'Off duty',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: b.active,
                    onChanged: (_) => widget.onToggleBarberActive(b.id),
                    activeColor: AppColors.brass,
                  ),
                  GestureDetector(
                    onTap: () => widget.onRemoveBarber(b.id),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('Remove', style: TextStyle(color: AppColors.red, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool numeric;
  const _Field({required this.label, required this.controller, required this.hint, this.numeric = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            keyboardType: numeric ? TextInputType.number : TextInputType.text,
            style: const TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textFaint),
              filled: true,
              fillColor: AppColors.surface2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  const _MetricCard({required this.label, required this.value, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: accent ? AppColors.brass : AppColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  const _PrimaryButton({required this.label, required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brass,
          foregroundColor: AppColors.bg,
          disabledBackgroundColor: AppColors.brass.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool loading;
  const _OutlineButton({required this.label, required this.onTap, this.color = AppColors.text, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: loading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color == AppColors.text ? AppColors.line : color.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: loading
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}