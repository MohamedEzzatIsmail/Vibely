// lib/layout/onboarding/onboarding_flow.dart
//
// Sequential first-launch flow:
//  Step C — Language selection (barrierDismissible: false, back button picks English)
//  Step D — Privacy consent: back button exits the app entirely. App re-shows
//            dialog on next launch until user taps "I Agree".
//  Step E — Notification permission (native OS dialog)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../layout/cubit/language/language_cubit.dart';
import '../../layout/legal/legal_screen.dart';
import '../../share/local/constants.dart';

class OnboardingFlow {
  static Future<void> run(BuildContext context) async {
    // Step C — Language
    final hasLang = await LanguageCubit.hasSavedLanguage();
    if (!hasLang) {
      if (!context.mounted) return;
      await _showLanguageDialog(context);
    }

    // Step D — Privacy (must be agreed; back exits app)
    final hasAgreed = await LanguageCubit.hasAgreedPrivacy();
    if (!hasAgreed) {
      if (!context.mounted) return;
      await _showPrivacyDialog(context);
    }

    // Step E — Notifications
    final notifStatus = await Permission.notification.status;
    if (notifStatus.isDenied) {
      await Permission.notification.request();
    }
  }

  static Future<void> _showLanguageDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BlocProvider.value(
        value: BlocProvider.of<LanguageCubit>(context),
        child: const _LanguageDialog(),
      ),
    );
  }

  static Future<void> _showPrivacyDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BlocProvider.value(
        value: BlocProvider.of<LanguageCubit>(context),
        child: const _PrivacyDialog(),
      ),
    );
  }
}

// ── Language dialog ───────────────────────────────────────────────────────────
class _LanguageDialog extends StatelessWidget {
  const _LanguageDialog();

  @override
  Widget build(BuildContext context) {
    // PopScope: back button on language dialog defaults to English
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await BlocProvider.of<LanguageCubit>(context).setEnglish();
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Dialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.language_rounded, color: kGold, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Choose Language  /  اختر اللغة',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _LangButton(
              label: 'English', flag: '🇬🇧',
              onTap: () async {
                await BlocProvider.of<LanguageCubit>(context).setEnglish();
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _LangButton(
              label: 'عربي', flag: '🇸🇦',
              onTap: () async {
                await BlocProvider.of<LanguageCubit>(context).setArabic();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  final String label, flag;
  final VoidCallback onTap;
  const _LangButton(
      {required this.label, required this.flag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: kGold, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: kGold,
        ),
        onPressed: onTap,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(flag, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Privacy dialog ────────────────────────────────────────────────────────────
// Back button exits the app. The dialog re-appears on every launch until
// the user taps "I Agree".
class _PrivacyDialog extends StatelessWidget {
  const _PrivacyDialog();

  @override
  Widget build(BuildContext context) {
    final isAr      = BlocProvider.of<LanguageCubit>(context).isArabic;
    final title     = isAr ? 'الخصوصية والسياسة' : 'Privacy & Policy';
    final body      = isAr
        ? 'قبل المتابعة، يرجى قراءة سياسة الخصوصية والموافقة عليها.'
        : 'Before you continue, please read and agree to our Privacy Policy.';
    final linkLabel = isAr ? 'سياسة الخصوصية' : 'Privacy Policy';
    final agreeBtn  = isAr ? 'أوافق' : 'I Agree';

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      // PopScope: back button exits the app entirely
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            // Exit the app — dialog will reappear on next launch
            SystemNavigator.pop();
          }
        },
        child: Dialog(
          backgroundColor: const Color(0xFF161B22),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shield_outlined, color: kGold, size: 40),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.5)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const LegalScreen(type: LegalType.privacy),
                  ),
                ),
                child: Text(linkLabel,
                    style: const TextStyle(
                        color: kGold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: kGold)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    await LanguageCubit.setPrivacyAgreed();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(agreeBtn,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
