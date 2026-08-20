import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/google_logo.dart';
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
                SizedBox(
                  width: 168,
                  height: 168,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 168,
                        height: 168,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.accentDanger.withValues(alpha: 0.4),
                              AppColors.accentDanger.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                      Image.asset('assets/images/logo.png', width: 132),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'ฝากที',
                  style: GoogleFonts.prompt(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'ยินดีต้อนรับ',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
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
                      : const GoogleLogo(size: 18),
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
