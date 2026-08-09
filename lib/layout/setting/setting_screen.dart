import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../layout/cubit/cubit.dart';
import '../../layout/cubit/states.dart';
import '../../layout/login/login_screen.dart';
import '../../layout/setting/setting_notifications_section.dart';
import '../../layout/cubit/post/post_cubit.dart';
import '../../layout/cubit/chat/chat_cubit.dart';
import '../../models/user_model.dart';
import '../../share/local/constants.dart';
import '../../share/local/cashe_helper.dart';
import '../../share/style/app_colors.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MainCubit, MainStates>(
      builder: (context, state) {
        final cubit = MainCubit.get(context);
        final user = cubit.model;

        return Scaffold(
          backgroundColor: AppColors.of(context).bg,
          appBar: AppBar(
            backgroundColor: AppColors.of(context).bg,
            elevation: 0,
            title: Text(
              AppStrings.of(context).settings,
              style: TextStyle(
                  color: AppColors.of(context).text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
          body: user == null
              ? const Center(
                  child: CircularProgressIndicator(color: kGold))
              : ListView(
                  children: [
                    // ── Profile section ───────────────────────────────────
                    _SettingProfileSection(user: user),

                    // ── Appearance ────────────────────────────────────────
                    const SettingAppearanceSection(),
                    const LanguageTile(),

                    // ── Notifications ─────────────────────────────────────
                    SettingNotificationsSection(user: user),

                    // ── Privacy ───────────────────────────────────────────
                    SettingPrivacySection(user: user),

                    // ── Close Friends ─────────────────────────────────────
                    ListTile(
                      leading: Icon(Icons.star_border,
                          color: AppColors.of(context).textSub),
                      title: Text(AppStrings.of(context).closeFriends,
                          style: TextStyle(color: AppColors.of(context).text)),
                      subtitle: Text(
                        AppStrings.of(context).closeFriendsSubtitle,
                        style:
                            TextStyle(color: AppColors.of(context).textHint, fontSize: 12),
                      ),
                      trailing: Icon(Icons.chevron_right,
                          color: AppColors.of(context).textHint),
                      onTap: () =>
                          Navigator.pushNamed(context, '/close-friends'),
                    ),
                    // ── About ─────────────────────────────────────────────────────────────
                    const SettingAboutSection(),
                    const Divider(color: Colors.white12),

                    // ── Logout ────────────────────────────────────────────
                    ListTile(
                      leading:
                          const Icon(Icons.logout, color: Colors.redAccent),
                      title: Text(AppStrings.of(context).logoutLabel,
                          style: const TextStyle(color: Colors.redAccent)),
                      onTap: () => _logout(context),
                    ),

                    // ── Delete Account ────────────────────────────────────
                    ListTile(
                      leading: const Icon(Icons.delete_forever_outlined,
                          color: Colors.redAccent),
                      title: Text(AppStrings.of(context).deleteAccount,
                          style: const TextStyle(color: Colors.redAccent)),
                      subtitle: Text(
                        'Permanently removes your account and data',
                        style: TextStyle(
                            color: AppColors.of(context).textHint,
                            fontSize: 12),
                      ),
                      onTap: () => _confirmDeleteAccount(context),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    // Cancel feed stream before signing out
    PostsCubit.get(context).clearFeed();
    ChatCubit.get(context).disposeAllChats();

    await AuthService.instance.signOut();
    await CashHelper.saveData(key: 'uId', value: null);

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final passwordCtrl = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.of(context).surface,
          title: Text(
            AppStrings.of(context).deleteAccount,
            style: const TextStyle(
                color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action is permanent and cannot be undone. '
                'Enter your password to confirm.',
                style: TextStyle(
                    color: AppColors.of(context).textSub, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                obscureText: obscure,
                style: TextStyle(color: AppColors.of(context).text),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  hintStyle:
                      TextStyle(color: AppColors.of(context).textHint),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppColors.of(context).textHint),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kGold),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.of(context).textHint,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppStrings.of(context).cancel,
                  style: TextStyle(color: AppColors.of(context).textSub)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final password = passwordCtrl.text.trim();
    if (password.isEmpty) return;

    // Show loading indicator while deletion happens
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
            child: CircularProgressIndicator(color: kGold)),
      );
    }

    final cubit = MainCubit.get(context);
    await cubit.deleteAccount(password: password, context: context);

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close loading dialog

    final state = cubit.state;
    if (state is DeleteAccountSuccessState) {
      // Clear all cubits and navigate to login
      PostsCubit.get(context).clearFeed();
      ChatCubit.get(context).disposeAllChats();
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (_) => false,
      );
    } else if (state is DeleteAccountErrorState) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ── Profile summary tile ──────────────────────────────────────────────────────
class _SettingProfileSection extends StatelessWidget {
  final UserModel user;
  const _SettingProfileSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: (user.image != null && user.image!.isNotEmpty)
                ? NetworkImage(user.image!)
                : null,
            backgroundColor: Colors.white12,
            child: user.image == null || user.image!.isEmpty
                ? Icon(Icons.person, color: AppColors.of(context).textHint, size: 28)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name ?? '',
                        style: TextStyle(
                            color: AppColors.of(context).text,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isVerified == true) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: kGold, size: 15),
                    ],
                  ],
                ),
                Text(
                  user.email ?? '',
                  style: TextStyle(color: AppColors.of(context).textHint, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined,
                color: AppColors.of(context).textSub, size: 20),
            onPressed: () =>
                Navigator.pushNamed(context, '/edit-profile'),
          ),
        ],
      ),
    );
  }
}
