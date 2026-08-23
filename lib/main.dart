import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const RootApp());
}

// ---------- ROOT + AUTH GATE ----------

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Regular',
      debugShowCheckedModeBanner: false,
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
        await supabase.auth.signUp(
          email: emailCtrl.text.trim(),
          password: passwordCtrl.text,
          data: {'full_name': nameCtrl.text.trim()},
        );
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
                _PrimaryButton(label: loading ? 'Please wait…' : (isSignUp ? 'Sign up' : 'Sign in'), onTap: loading ? () {} : submit),
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
  String name;
  String area;
  int price;
  int chairs;
  double rating;
  List<String> subscribers;
  List<QueueEntry> queue;
  List<Barber> staff;
  int nextTicket;
  bool isMine;

  Shop({
    required this.id,
    required this.name,
    required this.area,
    required this.price,
    required this.chairs,
    required this.rating,
    required this.subscribers,
    required this.queue,
    List<Barber>? staff,
    required this.nextTicket,
    this.isMine = false,
  }) : staff = staff ?? [];
}

final demoNames = ["Palesa", "Sam", "Bheki", "Grace", "Trevor", "Nomsa", "Andile"];

// ---------- ROOT APP ----------

class TheRegularApp extends StatefulWidget {
  const TheRegularApp({super.key});
  @override
  State<TheRegularApp> createState() => _TheRegularAppState();
}

class _TheRegularAppState extends State<TheRegularApp> {
  bool isOwnerMode = false;
  bool loadingOwnerShop = true;

  @override
  void initState() {
    super.initState();
    _loadOwnerShop();
  }

  Future<void> _loadOwnerShop() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final shopRow = await supabase.from('shops').select().eq('owner_id', uid).maybeSingle();
      if (shopRow != null) {
        final barberRows = await supabase.from('barbers').select().eq('shop_id', shopRow['id']);
        final shop = Shop(
          id: shopRow['id'] as String,
          name: shopRow['name'] as String,
          area: shopRow['area'] as String,
          price: shopRow['price'] as int,
          chairs: shopRow['chairs'] as int,
          rating: (shopRow['rating'] as num).toDouble(),
          subscribers: [],
          queue: [],
          staff: [
            for (final b in barberRows) Barber(id: b['id'] as String, name: b['name'] as String, active: b['active'] as bool)
          ],
          nextTicket: shopRow['next_ticket'] as int,
          isMine: true,
        );
        setState(() {
          shops.add(shop);
          ownerShopId = shop.id;
        });
      }
    } catch (e) {
      // If this fails (offline, RLS issue, etc.) the owner just sees the signup form again.
      debugPrint('Failed to load owner shop: $e');
    } finally {
      if (mounted) setState(() => loadingOwnerShop = false);
    }
  }

  final List<Shop> shops = [
    Shop(
      id: "s1",
      name: "Fade Culture",
      area: "Melville",
      price: 450,
      chairs: 4,
      rating: 4.8,
      subscribers: ["Lindiwe", "Brendan", "Tumi", "Kyle", "Ayanda"],
      queue: [
        QueueEntry(id: "q1", ticketNo: 41, name: "Tumi", barber: "Sipho"),
        QueueEntry(id: "q2", ticketNo: 42, name: "Kyle", barber: "Thabo"),
      ],
      staff: [
        Barber(id: "b1", name: "Sipho"),
        Barber(id: "b2", name: "Thabo"),
        Barber(id: "b3", name: "Ren"),
        Barber(id: "b4", name: "Kabelo"),
      ],
      nextTicket: 43,
    ),
    Shop(
      id: "s2",
      name: "Braamfontein Barber Co.",
      area: "Braamfontein",
      price: 380,
      chairs: 3,
      rating: 4.6,
      subscribers: ["Zanele", "Mpho"],
      queue: [],
      staff: [
        Barber(id: "b5", name: "Nkosi"),
        Barber(id: "b6", name: "Junior"),
        Barber(id: "b7", name: "Zola"),
      ],
      nextTicket: 18,
    ),
    Shop(
      id: "s3",
      name: "Sandton Gents",
      area: "Sandton",
      price: 650,
      chairs: 6,
      rating: 4.9,
      subscribers: ["Craig", "Sibusiso", "Werner", "Katlego", "Neo", "Dean", "Bongani"],
      queue: [QueueEntry(id: "q3", ticketNo: 105, name: "Neo", barber: "Kabelo")],
      staff: [
        Barber(id: "b8", name: "Kabelo"),
        Barber(id: "b9", name: "Sipho"),
        Barber(id: "b10", name: "Thabo"),
        Barber(id: "b11", name: "Ren"),
        Barber(id: "b12", name: "Nkosi"),
        Barber(id: "b13", name: "Junior"),
      ],
      nextTicket: 106,
    ),
  ];

  String? mySubShopId;
  QueueEntry? myTicket;
  String? myTicketShopId;
  String? ownerShopId;

  Shop? get ownerShop => shops.where((s) => s.id == ownerShopId).firstOrNull;

  void subscribe(String shopId) {
    setState(() {
      mySubShopId = shopId;
      shops.firstWhere((s) => s.id == shopId).subscribers.add("You");
    });
  }

  void cancelSubscription() {
    setState(() {
      if (mySubShopId != null) {
        shops.firstWhere((s) => s.id == mySubShopId).subscribers.remove("You");
      }
      mySubShopId = null;
      myTicket = null;
      myTicketShopId = null;
    });
  }

  String _pickBarber(Shop shop, int seed) {
    final active = shop.staff.where((b) => b.active).toList();
    if (active.isEmpty) return "Unassigned";
    return active[seed % active.length].name;
  }

  void walkIn(String shopId) {
    final shop = shops.firstWhere((s) => s.id == shopId);
    final barber = _pickBarber(shop, DateTime.now().millisecondsSinceEpoch);
    final entry = QueueEntry(
      id: "t${DateTime.now().millisecondsSinceEpoch}",
      ticketNo: shop.nextTicket,
      name: "You",
      barber: barber,
    );
    setState(() {
      shop.queue.add(entry);
      shop.nextTicket += 1;
      myTicket = entry;
      myTicketShopId = shopId;
    });
  }

  void leaveQueue() {
    setState(() {
      if (myTicketShopId != null && myTicket != null) {
        shops.firstWhere((s) => s.id == myTicketShopId).queue.removeWhere((q) => q.id == myTicket!.id);
      }
      myTicket = null;
      myTicketShopId = null;
    });
  }

  bool creatingShop = false;
  String? createShopError;

  Future<void> createShop(String name, String area, int price, int chairs) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    setState(() {
      creatingShop = true;
      createShopError = null;
    });
    try {
      final row = await supabase
          .from('shops')
          .insert({'owner_id': uid, 'name': name, 'area': area, 'price': price, 'chairs': chairs})
          .select()
          .single();
      final shop = Shop(
        id: row['id'] as String,
        name: row['name'] as String,
        area: row['area'] as String,
        price: row['price'] as int,
        chairs: row['chairs'] as int,
        rating: (row['rating'] as num).toDouble(),
        subscribers: [],
        queue: [],
        nextTicket: row['next_ticket'] as int,
        isMine: true,
      );
      setState(() {
        shops.add(shop);
        ownerShopId = shop.id;
      });
    } catch (e) {
      setState(() => createShopError = 'Could not create shop: $e');
    } finally {
      if (mounted) setState(() => creatingShop = false);
    }
  }

  void simulateSubscriber() {
    if (ownerShop == null) return;
    final name = demoNames[DateTime.now().millisecondsSinceEpoch % demoNames.length];
    setState(() => ownerShop!.subscribers.add("$name ${DateTime.now().second}"));
  }

  void simulateWalkIn() {
    if (ownerShop == null) return;
    final name = demoNames[DateTime.now().millisecondsSinceEpoch % demoNames.length];
    final barber = _pickBarber(ownerShop!, DateTime.now().second);
    setState(() {
      ownerShop!.queue.add(QueueEntry(
        id: "q${DateTime.now().millisecondsSinceEpoch}",
        ticketNo: ownerShop!.nextTicket,
        name: name,
        barber: barber,
      ));
      ownerShop!.nextTicket += 1;
    });
  }

  void completeQueueEntry(String queueId) {
    if (ownerShop == null) return;
    setState(() => ownerShop!.queue.removeWhere((q) => q.id == queueId));
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
    } catch (e) {
      debugPrint('Failed to add barber: $e');
    }
  }

  Future<void> removeBarber(String barberId) async {
    if (ownerShop == null) return;
    try {
      await supabase.from('barbers').delete().eq('id', barberId);
      setState(() => ownerShop!.staff.removeWhere((b) => b.id == barberId));
    } catch (e) {
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
      debugPrint('Failed to update barber: $e');
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
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
      body: loadingOwnerShop
          ? const Center(child: CircularProgressIndicator(color: AppColors.brass))
          : isOwnerMode
              ? OwnerFlow(
                  ownerShop: ownerShop,
                  onCreateShop: createShop,
                  creatingShop: creatingShop,
                  createShopError: createShopError,
                  onSimulateSubscriber: simulateSubscriber,
                  onSimulateWalkIn: simulateWalkIn,
                  onCompleteQueueEntry: completeQueueEntry,
                  onAddBarber: addBarber,
                  onRemoveBarber: removeBarber,
                  onToggleBarberActive: toggleBarberActive,
                )
              : CustomerFlow(
                  shops: shops,
                  mySubShopId: mySubShopId,
                  myTicket: myTicket,
                  myTicketShopId: myTicketShopId,
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

// ---------- CUSTOMER FLOW ----------

class CustomerFlow extends StatefulWidget {
  final List<Shop> shops;
  final String? mySubShopId;
  final QueueEntry? myTicket;
  final String? myTicketShopId;
  final void Function(String shopId) onSubscribe;
  final VoidCallback onCancelSubscription;
  final void Function(String shopId) onWalkIn;
  final VoidCallback onLeaveQueue;

  const CustomerFlow({
    super.key,
    required this.shops,
    required this.mySubShopId,
    required this.myTicket,
    required this.myTicketShopId,
    required this.onSubscribe,
    required this.onCancelSubscription,
    required this.onWalkIn,
    required this.onLeaveQueue,
  });

  @override
  State<CustomerFlow> createState() => _CustomerFlowState();
}

class _CustomerFlowState extends State<CustomerFlow> {
  int tab = 0; // 0 = home, 1 = ticket, 2 = account
  Shop? openedShop;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (openedShop != null) {
      body = ShopDetailScreen(
        shop: openedShop!,
        isSubscribed: widget.mySubShopId == openedShop!.id,
        hasOtherSub: widget.mySubShopId != null && widget.mySubShopId != openedShop!.id,
        onBack: () => setState(() => openedShop = null),
        onSubscribe: () => widget.onSubscribe(openedShop!.id),
        onWalkIn: () {
          widget.onWalkIn(openedShop!.id);
          setState(() {
            openedShop = null;
            tab = 1;
          });
        },
        onCancel: widget.onCancelSubscription,
      );
    } else if (tab == 1 && widget.myTicket != null) {
      final shop = widget.shops.firstWhere((s) => s.id == widget.myTicketShopId);
      body = TicketScreen(shop: shop, ticket: widget.myTicket!, onLeave: widget.onLeaveQueue);
    } else if (tab == 2) {
      body = AccountScreen(
        shop: widget.mySubShopId == null
            ? null
            : widget.shops.firstWhere((s) => s.id == widget.mySubShopId),
        onCancel: widget.onCancelSubscription,
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
                  shop.queue.isEmpty ? 'No wait' : '${shop.queue.length} in queue',
                  style: TextStyle(color: shop.queue.isEmpty ? AppColors.textFaint : AppColors.text, fontSize: 13),
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
  final VoidCallback onBack;
  final VoidCallback onSubscribe;
  final VoidCallback onWalkIn;
  final VoidCallback onCancel;

  const ShopDetailScreen({
    super.key,
    required this.shop,
    required this.isSubscribed,
    required this.hasOtherSub,
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
          shop.queue.isEmpty ? 'No wait right now' : '${shop.queue.length} people in the queue right now',
          style: const TextStyle(color: AppColors.text, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (isSubscribed) ...[
          const Text("✓ YOU'RE A MEMBER HERE",
              style: TextStyle(color: AppColors.brass, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _PrimaryButton(label: 'Walk in now', onTap: onWalkIn),
          const SizedBox(height: 10),
          _OutlineButton(label: 'Cancel subscription', color: AppColors.red, onTap: onCancel),
        ] else if (hasOtherSub) ...[
          const Text("You're already subscribed to another shop. Cancel that one first to switch.",
              style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
        ] else
          _PrimaryButton(label: 'Subscribe — R${shop.price}/month', onTap: onSubscribe),
      ],
    );
  }
}

class TicketScreen extends StatelessWidget {
  final Shop shop;
  final QueueEntry ticket;
  final VoidCallback onLeave;
  const TicketScreen({super.key, required this.shop, required this.ticket, required this.onLeave});

  @override
  Widget build(BuildContext context) {
    final position = shop.queue.indexWhere((q) => q.id == ticket.id) + 1;
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
          _OutlineButton(label: 'Leave queue', color: AppColors.red, onTap: onLeave),
        ],
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  final Shop? shop;
  final VoidCallback onCancel;
  const AccountScreen({super.key, required this.shop, required this.onCancel});

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
                _OutlineButton(label: 'Cancel subscription', color: AppColors.red, onTap: onCancel),
              ],
            ),
    );
  }
}

// ---------- OWNER FLOW ----------

class OwnerFlow extends StatefulWidget {
  final Shop? ownerShop;
  final void Function(String name, String area, int price, int chairs) onCreateShop;
  final bool creatingShop;
  final String? createShopError;
  final VoidCallback onSimulateSubscriber;
  final VoidCallback onSimulateWalkIn;
  final void Function(String queueId) onCompleteQueueEntry;
  final void Function(String name) onAddBarber;
  final void Function(String barberId) onRemoveBarber;
  final void Function(String barberId) onToggleBarberActive;

  const OwnerFlow({
    super.key,
    required this.ownerShop,
    required this.onCreateShop,
    required this.creatingShop,
    required this.createShopError,
    required this.onSimulateSubscriber,
    required this.onSimulateWalkIn,
    required this.onCompleteQueueEntry,
    required this.onAddBarber,
    required this.onRemoveBarber,
    required this.onToggleBarberActive,
  });

  @override
  State<OwnerFlow> createState() => _OwnerFlowState();
}

class _OwnerFlowState extends State<OwnerFlow> {
  final nameCtrl = TextEditingController();
  final areaCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final chairsCtrl = TextEditingController();
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
          const SizedBox(height: 8),
          if (widget.createShopError != null) ...[
            Text(widget.createShopError!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
            const SizedBox(height: 8),
          ],
          _PrimaryButton(
            label: widget.creatingShop ? 'Creating…' : 'Create shop',
            onTap: widget.creatingShop
                ? () {}
                : () {
                    final price = int.tryParse(priceCtrl.text) ?? 0;
                    final chairs = int.tryParse(chairsCtrl.text) ?? 0;
                    if (nameCtrl.text.isEmpty || areaCtrl.text.isEmpty || price == 0 || chairs == 0) return;
                    widget.onCreateShop(nameCtrl.text, areaCtrl.text, price, chairs);
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
        if (!showStaff) ...[
          Row(children: [
            Expanded(child: _MetricCard(label: 'Subscribers', value: '${shop.subscribers.length}')),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(label: 'Monthly revenue', value: 'R${shop.subscribers.length * shop.price}', accent: true)),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(label: 'In queue', value: '${shop.queue.length}')),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _OutlineButton(label: '+ Test subscriber', onTap: widget.onSimulateSubscriber)),
            const SizedBox(width: 10),
            Expanded(child: _OutlineButton(label: '+ Test walk-in', onTap: widget.onSimulateWalkIn)),
          ]),
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
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brass,
          foregroundColor: AppColors.bg,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _OutlineButton({required this.label, required this.onTap, this.color = AppColors.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color == AppColors.text ? AppColors.line : color.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}