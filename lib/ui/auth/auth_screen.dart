import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../widgets/custom_field.dart';
import '../widgets/primary_button.dart';

final supabase = Supabase.instance.client;

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
  bool isForgotPassword = false;
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

  Future<void> sendPasswordReset() async {
    if (emailCtrl.text.trim().isEmpty) {
      setState(() => error = 'Enter your email first.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await supabase.auth.resetPasswordForEmail(
        emailCtrl.text.trim(),
        // On web, send them back to this same app. On mobile this falls back
        // to Supabase's default redirect since there's no deep link set up
        // yet to catch it — the link will open in a browser instead of the app.
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
      if (mounted) {
        showSnack('Check your email for a password reset link.');
        setState(() => isForgotPassword = false);
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
                Text(
                  isForgotPassword ? 'Reset your password' : (isSignUp ? 'Create an account' : 'Welcome back'),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 24),
                if (isForgotPassword) ...[
                  const Text(
                    "Enter your email and we'll send you a link to reset your password.",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  CustomField(label: 'Email', controller: emailCtrl, hint: 'you@example.com'),
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                    const SizedBox(height: 8),
                  ],
                  PrimaryButton(label: 'Send reset link', loading: loading, onTap: sendPasswordReset),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() {
                      isForgotPassword = false;
                      error = null;
                    }),
                    child: const Text('Back to sign in', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ),
                ] else ...[
                  if (isSignUp) ...[
                    CustomField(label: 'Name', controller: nameCtrl, hint: 'Your name'),
                  ],
                  CustomField(label: 'Email', controller: emailCtrl, hint: 'you@example.com'),
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
                  if (!isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() {
                          isForgotPassword = true;
                          error = null;
                        }),
                        child: const Text('Forgot password?', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ),
                    ),
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                    const SizedBox(height: 8),
                  ],
                  PrimaryButton(label: isSignUp ? 'Sign up' : 'Sign in', loading: loading, onTap: submit),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() {
                      isSignUp = !isSignUp;
                      error = null;
                    }),
                    child: Text(
                      isSignUp ? 'Already have an account? Sign in' : "New here? Create an account",
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}