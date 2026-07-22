// lib/layout/login/forgot_password_screen.dart — fully theme-aware + translated
//
// Hardened for real-world use:
//  • Catches ALL failures, not just FirebaseAuthException — a stray
//    PlatformException or network blip used to leave the button spinning
//    forever with no feedback ("nothing happens" when tested).
//  • Never reveals whether an email is registered (shows the same
//    "check your email" success state for 'user-not-found' too) — this is
//    both the standard security practice and avoids user confusion when
//    testing with an address that isn't registered.
//  • Adds a 30s resend cooldown, matching the email-verification screen.
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../share/style/app_colors.dart';
import '../../share/local/constants.dart';
import '../../share/local/app_strings.dart';
import '../cubit/language/language_cubit.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _ctrl = TextEditingController();
  final _key  = GlobalKey<FormState>();
  bool    _sent     = false;
  bool    _loading  = false;
  String? _error;
  int     _countdown = 0;
  Timer?  _cdTimer;

  @override
  void dispose() {
    _ctrl.dispose();
    _cdTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cdTimer?.cancel();
    setState(() => _countdown = 30);
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) _countdown--;
      });
      if (_countdown == 0) _cdTimer?.cancel();
    });
  }

  Future<void> _send() async {
    if (!_sent && !_key.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _ctrl.text.trim());
      if (!mounted) return;
      setState(() { _sent = true; _loading = false; });
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        // Don't reveal whether an account exists for this address —
        // show the same success state either way.
        setState(() { _sent = true; _loading = false; });
        _startCooldown();
        return;
      }
      setState(() {
        _error = e.message ?? 'Could not send the reset email. Please try again.';
        _loading = false;
      });
    } catch (_) {
      // Anything else (network blip, platform channel error, etc.) — never
      // let the button just silently stop doing anything.
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please check your connection and try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c   = AppColors.of(context);
    final s   = AppStrings.of(context);
    final isAr = BlocProvider.of<LanguageCubit>(context).isArabic;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
      ),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: _sent
            ? _SentState(
                c: c, s: s, isAr: isAr,
                countdown: _countdown,
                loading: _loading,
                onResend: _send,
              )
            : _FormBody(
                ctrl: _ctrl, formKey: _key,
                loading: _loading, error: _error,
                onSend: _send, c: c, s: s, isAr: isAr),
      ),
    );
  }
}

// ── Sent confirmation ────────────────────────────────────────────────────────
class _SentState extends StatelessWidget {
  final AppColors c;
  final AppStrings s;
  final bool isAr;
  final int countdown;
  final bool loading;
  final VoidCallback onResend;
  const _SentState({
    required this.c, required this.s, required this.isAr,
    required this.countdown, required this.loading, required this.onResend,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.mark_email_read_rounded, color: kGold, size: 72),
      const SizedBox(height: 24),
      Text(
        isAr ? 'تحقق من بريدك الإلكتروني' : 'Check your email',
        style: TextStyle(
            color: c.text, fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      Text(
        isAr
            ? 'إذا كان هذا البريد مسجلاً لدينا، فسنرسل رابط إعادة تعيين كلمة المرور إليه.'
            : "If that email is registered with us, we've sent a password "
              'reset link to it.',
        textAlign: TextAlign.center,
        style: TextStyle(color: c.textSub, fontSize: 14, height: 1.6),
      ),
      const SizedBox(height: 20),
      TextButton(
        onPressed: (countdown > 0 || loading) ? null : onResend,
        child: Text(
          countdown > 0
              ? (isAr ? 'إعادة الإرسال خلال $countdown ثانية' : 'Resend in ${countdown}s')
              : (isAr ? 'إعادة إرسال الرابط' : 'Resend link'),
          style: TextStyle(
            color: countdown > 0 ? c.textHint : kGold,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kGold, foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
          onPressed: () => Navigator.pop(context),
          child: Text(
            isAr ? 'العودة لتسجيل الدخول' : 'Back to Login',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    ],
  );
}

// ── Form ─────────────────────────────────────────────────────────────────────
class _FormBody extends StatelessWidget {
  final TextEditingController ctrl;
  final GlobalKey<FormState>  formKey;
  final bool    loading;
  final String? error;
  final VoidCallback onSend;
  final AppColors  c;
  final AppStrings s;
  final bool isAr;

  const _FormBody({
    required this.ctrl, required this.formKey, required this.loading,
    required this.error, required this.onSend,
    required this.c, required this.s, required this.isAr,
  });

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_reset_rounded, color: kGold, size: 52),
        const SizedBox(height: 20),
        Text(
          isAr ? 'نسيت كلمة المرور؟' : 'Forgot Password?',
          style: TextStyle(
              color: c.text, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          isAr
              ? 'أدخل بريدك الإلكتروني وسنرسل لك رابط الاستعادة.'
              : "Enter your email and we'll send you a reset link.",
          style: TextStyle(color: c.textSub, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: c.text, fontSize: 14),
          validator: (v) => (v == null || !v.contains('@'))
              ? (isAr ? 'أدخل بريداً صحيحاً' : 'Enter a valid email')
              : null,
          decoration: InputDecoration(
            labelText: isAr ? 'البريد الإلكتروني' : 'Email address',
            labelStyle: TextStyle(color: c.textHint),
            prefixIcon: Icon(Icons.email_outlined, color: c.textHint),
            filled: true,
            fillColor: c.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kGold, width: 1.5)),
            errorStyle: const TextStyle(color: Colors.redAccent),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kGold, foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
            onPressed: loading ? null : onSend,
            child: loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2))
                : Text(
                    isAr ? 'إرسال رابط الاستعادة' : 'Send Reset Link',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    ),
  );
}
