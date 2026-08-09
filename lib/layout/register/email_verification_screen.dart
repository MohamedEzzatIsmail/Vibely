import 'dart:async';
import '../../share/style/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../share/local/cashe_helper.dart';
import '../home.dart';
import '../login/login_screen.dart';
import '../../services/auth_service.dart';
import 'cubit/register_cubit.dart';
import 'cubit/register_states.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _pollTimer;
  bool   _checking  = false;
  int    _countdown = 30;
  Timer? _cdTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _startCooldown();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cdTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      final verified = await context.read<RegisterCubit>().checkEmailVerified();
      if (verified && mounted) _onVerified();
    });
  }

  void _startCooldown() {
    _countdown = 30;
    _cdTimer   = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) _countdown--;
      });
    });
  }

  Future<void> _onVerified() async {
    _pollTimer?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await CashHelper.saveData(key: 'uID', value: user.uid);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
            (_) => false,
      );
    }
  }

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    final verified = await context.read<RegisterCubit>().checkEmailVerified();
    if (!mounted) return;
    setState(() => _checking = false);
    if (verified) {
      _onVerified();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(context).emailNotVerifiedYet),
        backgroundColor: const Color(0xFFb8934e),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RegisterCubit, RegisterStates>(
      listener: (context, state) {
        if (state is RegisterVerificationResent) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppStrings.of(context).verificationEmailResent),
            backgroundColor: Colors.green,
          ));
          _startCooldown();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.of(context).bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                      color: AppColors.of(context).surface, shape: BoxShape.circle),
                  child: const Icon(Icons.mark_email_unread_rounded,
                      color: Color(0xFFe5c687), size: 38),
                ),
                const SizedBox(height: 24),
                Text(AppStrings.of(context).checkYourEmail,
                    style: TextStyle(color: AppColors.of(context).text,
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  'We sent a verification link to\n${widget.email}\n\n'
                      'Tap the link in the email, then come back here.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.of(context).surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFe5c687), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Don't see it? Check your spam/junk folder — if you find it there, mark it as \"Not spam\" so future emails land in your inbox.",
                          style: TextStyle(color: AppColors.of(context).textHint, fontSize: 12.5, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _checking ? null : _checkNow,
                    child: _checking
                        ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2))
                        : const Text("I've verified — Continue",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _countdown > 0
                      ? null
                      : () => context.read<RegisterCubit>().resendVerification(),
                  child: Text(
                    _countdown > 0
                        ? 'Resend email in ${_countdown}s'
                        : 'Resend verification email',
                    style: TextStyle(
                      color: _countdown > 0 ? Colors.grey : const Color(0xFFe5c687),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await AuthService.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => LoginScreen()),
                          (_) => false,
                    );
                  },
                  child: Text(AppStrings.of(context).backToSignIn,
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}