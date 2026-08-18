import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_controller.dart';

/// Step 1: create an account by signing in with Google.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);

    final controller = context.read<AuthController>();
    await controller.signInWithGoogle();

    if (!mounted) return;
    setState(() => _loading = false);

    if (controller.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(controller.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_car_filled, size: 72),
                const SizedBox(height: 16),
                Text(
                  'ยินดีต้อนรับสู่ fark-tee',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'สร้างบัญชีเพื่อเริ่มต้นใช้งาน',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _loading ? null : _signIn,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    _loading ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบด้วย Google',
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
