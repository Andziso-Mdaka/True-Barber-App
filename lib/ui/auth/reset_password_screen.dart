import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../widgets/custom_field.dart';
import '../widgets/primary_button.dart';

final supabase = Supabase.instance.client;

class ResetPasswordScreen extends StatefulWidget {
  final VoidCallback onDone;
  const ResetPasswordScreen({super.key, required this.onDone});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final passwordCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> submit() async {
    if (passwordCtrl.text.length < 6) {
      setState(() => error = 'Password must be at least 6 characters.');
      return;
    }
    if (passwordCtrl.text != confirmCtrl.text) {
      setState(() => error = "Passwords don't match.");
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await supabase.auth.updateUser(UserAttributes(password: passwordCtrl.text));
      if (mounted) {
        showSnack('Password updated.');
        widget.onDone();
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
                const Text('Set a new password',
                    style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text("Choose a new password for your account.",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 24),
                CustomField(label: 'New password', controller: passwordCtrl, hint: '••••••••', obscureText: true),
                CustomField(label: 'Confirm password', controller: confirmCtrl, hint: '••••••••', obscureText: true),
                if (error != null) ...[
                  Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                PrimaryButton(label: 'Update password', loading: loading, onTap: submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}