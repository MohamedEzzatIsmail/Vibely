import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';
import '../../share/style/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../layout/cubit/theme/theme_cubit.dart';
import '../../layout/cubit/language/language_cubit.dart';
import '../../models/user_model.dart';
import '../../share/local/constants.dart';

class SettingNotificationsSection extends StatefulWidget {
  final UserModel user;

  const SettingNotificationsSection({super.key, required this.user});

  @override
  State<SettingNotificationsSection> createState() => _SettingNotificationsSectionState();
}

class _SettingNotificationsSectionState extends State<SettingNotificationsSection> {
  late bool _notificationsEnabled;
  late bool _notifyOnPostLike;
  late bool _notifyOnComment;
  late bool _notifyOnCommentLike;
  late bool _notifyOnReply;
  late bool _notifyOnMessage;
  late bool _notifyOnFollow;
  late bool _notifyOnMention;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.user.notificationsEnabled;
    _notifyOnPostLike     = widget.user.notifyOnPostLike;
    _notifyOnComment      = widget.user.notifyOnComment;
    _notifyOnCommentLike  = widget.user.notifyOnCommentLike;
    _notifyOnReply        = widget.user.notifyOnReply;
    _notifyOnMessage      = widget.user.notifyOnMessage;
    _notifyOnFollow       = widget.user.notifyOnFollow;
    _notifyOnMention      = widget.user.notifyOnMention;
  }

  Future<void> _update(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // These stay on the public doc — NotificationService.send() needs to
    // read the RECIPIENT's own preferences from whoever else is triggering
    // a notification, which only works if they're readable cross-user.
    await FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .update(data);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: s.sectionNotifications),
        _ToggleTile(
          icon: Icons.notifications_active_outlined,
          label: s.enableNotifications,
          value: _notificationsEnabled,
          onChanged: (v) { setState(() => _notificationsEnabled = v); _update({'notificationsEnabled': v}); },
        ),
        _ToggleTile(
          icon: Icons.thumb_up_outlined,
          label: s.notifyPostLikes,
          value: _notifyOnPostLike,
          onChanged: (v) { setState(() => _notifyOnPostLike = v); _update({'notifyOnPostLike': v}); },
        ),
        _ToggleTile(
          icon: Icons.comment_outlined,
          label: s.notifyComments,
          value: _notifyOnComment,
          onChanged: (v) { setState(() => _notifyOnComment = v); _update({'notifyOnComment': v}); },
        ),
        _ToggleTile(
          icon: Icons.favorite_outline,
          label: s.notifyCommentLikes,
          value: _notifyOnCommentLike,
          onChanged: (v) { setState(() => _notifyOnCommentLike = v); _update({'notifyOnCommentLike': v}); },
        ),
        _ToggleTile(
          icon: Icons.reply_outlined,
          label: s.notifyCommentReplies,
          value: _notifyOnReply,
          onChanged: (v) { setState(() => _notifyOnReply = v); _update({'notifyOnReply': v}); },
        ),
        _ToggleTile(
          icon: Icons.chat_bubble_outline,
          label: s.notifyNewMessages,
          value: _notifyOnMessage,
          onChanged: (v) { setState(() => _notifyOnMessage = v); _update({'notifyOnMessage': v}); },
        ),
        _ToggleTile(
          icon: Icons.person_add_outlined,
          label: s.notifyNewFollowers,
          value: _notifyOnFollow,
          onChanged: (v) { setState(() => _notifyOnFollow = v); _update({'notifyOnFollow': v}); },
        ),
        _ToggleTile(
          icon: Icons.alternate_email,
          label: s.notifyMentions,
          subtitle: s.notifyMentionsSubtitle,
          value: _notifyOnMention,
          onChanged: (v) { setState(() => _notifyOnMention = v); _update({'notifyOnMention': v}); },
        ),
      ],
    );
  }
}

// ── Privacy section ───────────────────────────────────────────────────────────
class SettingPrivacySection extends StatefulWidget {
  final UserModel user;

  const SettingPrivacySection({super.key, required this.user});

  @override
  State<SettingPrivacySection> createState() => _SettingPrivacySectionState();
}

class _SettingPrivacySectionState extends State<SettingPrivacySection> {
  late bool _isPrivateAccount;
  late bool _hideEmail;
  late bool _hidePhone;

  @override
  void initState() {
    super.initState();
    _isPrivateAccount = widget.user.isPrivateAccount;
    _hideEmail        = widget.user.hideEmail;
    _hidePhone        = widget.user.hidePhone;
  }

  Future<void> _updatePublic(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('Users').doc(uid).update(data);
  }

  /// Toggling hideEmail/hidePhone needs two writes: the toggle itself goes
  /// on the private doc, and the public doc's email/phone MIRROR has to be
  /// updated in lockstep (nulled when hiding, restored to the real value
  /// when un-hiding) — that mirror is what actually keeps the value out of
  /// reach for other users, not the toggle by itself.
  Future<void> _updateVisibility({
    required String toggleField,
    required bool hidden,
    required String mirrorField,
    required String? realValue,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDoc = FirebaseFirestore.instance.collection('Users').doc(uid);
    await userDoc
        .collection('private')
        .doc('data')
        .set({toggleField: hidden}, SetOptions(merge: true));
    await userDoc.update({mirrorField: hidden ? null : realValue});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: s.sectionPrivacy),
        _ToggleTile(
          icon: Icons.lock_outline,
          label: s.privateAccount,
          subtitle: s.privateAccountSubtitle,
          value: _isPrivateAccount,
          onChanged: (v) { setState(() => _isPrivateAccount = v); _updatePublic({'isPrivateAccount': v}); },
        ),
        _ToggleTile(
          icon: Icons.email_outlined,
          label: s.hideEmail,
          value: _hideEmail,
          onChanged: (v) {
            setState(() => _hideEmail = v);
            _updateVisibility(
                toggleField: 'hideEmail',
                hidden: v,
                mirrorField: 'email',
                realValue: widget.user.email);
          },
        ),
        _ToggleTile(
          icon: Icons.phone_outlined,
          label: s.hidePhone,
          value: _hidePhone,
          onChanged: (v) {
            setState(() => _hidePhone = v);
            _updateVisibility(
                toggleField: 'hidePhone',
                hidden: v,
                mirrorField: 'phone',
                realValue: widget.user.phone);
          },
        ),
        ListTile(
          leading:
          Icon(Icons.block, color: AppColors.of(context).textSub, size: 22),
          title: Text(s.blockedAccountsLabel,
              style: TextStyle(color: AppColors.of(context).text)),
          trailing:
          Icon(Icons.chevron_right, color: AppColors.of(context).textHint),
          onTap: () => Navigator.pushNamed(context, '/blocked-users'),
        ),
      ],
    );
  }
}

// ── Appearance section ────────────────────────────────────────────────────────
class SettingAppearanceSection extends StatelessWidget {
  const SettingAppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: AppStrings.of(context).appearance),
        const _AppearanceTile(),
      ],
    );
  }
}

class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, state) {
        final isDark = state is DarkThemeState;
        return ListTile(
          leading: Icon(
            isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            color: AppColors.of(context).textSub,
          ),
          title: Text(AppStrings.of(context).darkMode,
              style: TextStyle(color: AppColors.of(context).text)),
          trailing: Switch(
            value: isDark,
            activeColor: kGold,
            onChanged: (_) => ThemeCubit.get(context).toggle(),
          ),
        );
      },
    );
  }
}

// ── Language tile ─────────────────────────────────────────────────────────────
class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LanguageCubit, LanguageState>(
      builder: (context, state) {
        final isAr    = state.locale.languageCode == 'ar';
        final current = isAr ? 'عربي' : 'English';
        final flag    = isAr ? '🇸🇦' : '🇬🇧';
        return ListTile(
          leading: Icon(Icons.language_rounded, color: AppColors.of(context).textSub),
          title: Text(AppStrings.of(context).language,
              style: TextStyle(color: AppColors.of(context).text)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(current,
                style: TextStyle(color: AppColors.of(context).textSub, fontSize: 13)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppColors.of(context).textHint, size: 18),
          ]),
          onTap: () => _showLanguagePicker(context),
        );
      },
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => BlocProvider.value(
        value: BlocProvider.of<LanguageCubit>(context),
        child: _LanguagePicker(),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = BlocProvider.of<LanguageCubit>(context);
    final isAr  = cubit.isArabic;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(AppStrings.of(context).chooseLanguage + '  /  اختر اللغة',
              style: TextStyle(color: AppColors.of(context).text,
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _PickerOption(
            flag: '🇬🇧', label: 'English',
            selected: !isAr,
            onTap: () async {
              await cubit.setEnglish();
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
          _PickerOption(
            flag: '🇸🇦', label: 'عربي',
            selected: isAr,
            onTap: () async {
              await cubit.setArabic();
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final String flag, label;
  final bool selected;
  final VoidCallback onTap;
  const _PickerOption(
      {required this.flag, required this.label,
        required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? kGold.withValues(alpha: 0.12)
              : AppColors.of(context).bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? kGold.withValues(alpha: 0.5) : Colors.white12),
        ),
        child: Row(children: [
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: TextStyle(
                  color: selected ? kGold : Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w500))),
          if (selected)
            const Icon(Icons.check_circle_rounded, color: kGold, size: 20),
        ]),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFe5c687),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.of(context).textSub, size: 22),
      title:
      Text(label, style: TextStyle(color: AppColors.of(context).text)),
      subtitle: subtitle != null
          ? Text(subtitle!,
          style: TextStyle(
              color: AppColors.of(context).textHint, fontSize: 12))
          : null,
      trailing: Switch(
        value: value,
        activeColor: kGold,
        onChanged: onChanged,
      ),
    );
  }
}

// ── About US Section  ────────────────────────────────────────────────────────────
class SettingAboutSection extends StatelessWidget {
  const SettingAboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.of(context).isDark;
    final s = AppStrings.of(context);
    final innovaAsset = isDark
        ? 'assets/app_icon/innova.png'
        : 'assets/app_icon/innova_dark.png';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: s.sectionAbout),
        // App version
        ListTile(
          leading: Icon(Icons.info_outline, color: AppColors.of(context).textSub, size: 22),
          title: Text(s.versionLabel, style: TextStyle(color: AppColors.of(context).text)),
          trailing: Text('1.0.0', style: TextStyle(color: AppColors.of(context).textHint, fontSize: 13)),
        ),
        // Made by Innova
        ListTile(
          leading: Icon(Icons.business_outlined, color: AppColors.of(context).textSub, size: 22),
          title: Text(s.madeByLabel, style: TextStyle(color: AppColors.of(context).text)),
          trailing: Image.asset(
            innovaAsset,
            height: 40,
            color: isDark ? Colors.white54 : null,
          ),
        ),
        // Terms
        ListTile(
          leading: Icon(Icons.description_outlined, color: AppColors.of(context).textSub, size: 22),
          title: Text(s.termsOfService, style: TextStyle(color: AppColors.of(context).text)),
          trailing: Icon(Icons.chevron_right, color: AppColors.of(context).textHint),
          onTap: () => Navigator.pushNamed(context, '/terms'),
        ),
        // Privacy policy
        ListTile(
          leading: Icon(Icons.privacy_tip_outlined, color: AppColors.of(context).textSub, size: 22),
          title: Text(s.privacyPolicy, style: TextStyle(color: AppColors.of(context).text)),
          trailing: Icon(Icons.chevron_right, color: AppColors.of(context).textHint),
          onTap: () => Navigator.pushNamed(context, '/privacy-policy'),
        ),
        const SizedBox(height: 8),
        // Innova logo centered at bottom of section
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Image.asset(
              innovaAsset,
              height: 80,
              color: isDark ? Colors.white24 : null,
            ),
          ),
        ),
      ],
    );
  }
}