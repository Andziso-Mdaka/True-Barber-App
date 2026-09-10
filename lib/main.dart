import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'controllers/app_provider.dart';

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
        
        // Wrap the app in Provider only when logged in. 
        // This ensures data is cleared when the user logs out.
        return ChangeNotifierProvider(
          create: (_) => AppProvider(),
          child: const TheRegularApp(),
        );
      },
    );
  }
}

// Notice how this is now a StatelessWidget! 
// All the state and lifecycle logic was moved to AppProvider.
class TheRegularApp extends StatelessWidget {
  const TheRegularApp({super.key});

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
    // This tells the UI to rebuild whenever AppProvider calls notifyListeners()
    final provider = context.watch<AppProvider>();

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
              isSelected: [!provider.isOwnerMode, provider.isOwnerMode],
              onPressed: (i) => provider.setOwnerMode(i == 1),
              selectedColor: AppColors.bg,
              fillColor: AppColors.brass,
              color: AppColors.textMuted,
              constraints: const BoxConstraints(minHeight: 32, minWidth: 70),
              children: const [Text('Customer'), Text('Owner')],
            ),
          ),
          if (provider.isAdmin)
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
                      provider.refreshPendingShopCount();
                    },
                  ),
                  if (provider.pendingShopCount > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          '${provider.pendingShopCount}',
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
      body: provider.loadingData
          ? const Center(child: CircularProgressIndicator(color: AppColors.brass))
          : provider.loadError != null
              ? _ErrorState(message: provider.loadError!, onRetry: provider.loadInitialData)
              : provider.isOwnerMode
                  ? const OwnerFlow() // No more 20 arguments!
                  : const CustomerFlow(), // Clean and simple!
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
            CustomOutlineButton(label: 'Try again', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}