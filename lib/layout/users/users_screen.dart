import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

import '../../layout/cubit/cubit.dart';
import '../../layout/cubit/states.dart';
import 'package:flutter/material.dart';
import '../../share/style/app_colors.dart';
import '../../share/local/app_strings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../share/local/constants.dart';

part 'profile_hero_widgets.dart';
part 'profile_detail_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  PROFILE SCREEN  –  Professional & Modern redesign
// ══════════════════════════════════════════════════════════════════════════════

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MainCubit, MainStates>(
      listener: (context, state) {
        if (state is UpdateProfileSuccessState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.of(context).profileUpdated),
              backgroundColor: const Color(0xFF2e7d32),
            ),
          );
        } else if (state is UpdateProfileErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = MainCubit.get(context);
        final model = cubit.model;
        final profileImage = cubit.profileImage;
        final coverImage   = cubit.coverImage;

        // Only show spinner on first load (model not yet fetched).
        // Once model is loaded, never block the UI again — even on refresh.
        if (model == null) {
          return Scaffold(
            backgroundColor: AppColors.of(context).bg,
            body: const Center(
              child: const CircularProgressIndicator(color: Color(0xFFe5c687)),
            ),
          );
        }

        if (state is MainGetUserDataErrorStates) {
          return Scaffold(
            backgroundColor: AppColors.of(context).bg,
            body: Center(
              child: Text(
                'Failed to load profile\n${state.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.of(context).bg,
          body: RefreshIndicator(
            color: const Color(0xFFe5c687),
            backgroundColor: AppColors.of(context).surface,
            onRefresh: () async {
              final uid = model.uid;
              if (uid != null) await cubit.getUserData(uid);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Hero cover + avatar (always LTR) ─────────────────────
                SliverToBoxAdapter(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: _ProfileHero(
                      model: model,
                      profileImage: profileImage,
                      coverImage: coverImage,
                      onAvatarTap: () => _showImageOptions(context),
                      onCoverTap:  () => _showImageOptions(context),
                    ),
                  ),
                ),

                // ── Name / bio / stats (always LTR) ──────────────────────
                SliverToBoxAdapter(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: _ProfileInfo(model: model),
                  ),
                ),

                // ── Action buttons ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _ProfileActions(
                    showConfirm: profileImage != null || coverImage != null,
                    onEdit: () => _openEditBottomSheet(context, model),
                    onConfirm: cubit.uploadImagesToSupabase,
                  ),
                ),

                // ── Divider ───────────────────────────────────────────────
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: Colors.white10,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Info rows ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _ProfileDetails(model: model),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Image picker bottom sheet ─────────────────────────────────────────────
  void _showImageOptions(BuildContext context) {
    final cubit = MainCubit.get(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _OptionTile(
              icon: Icons.person_rounded,
              label: 'Change Profile Photo',
              onTap: () async {
                Navigator.pop(context);
                await Future.delayed(const Duration(milliseconds: 200));
                cubit.pickProfileImage();
              },
            ),
            _OptionTile(
              icon: Icons.panorama_rounded,
              label: 'Change Cover Photo',
              onTap: () async {
                Navigator.pop(context);
                await Future.delayed(const Duration(milliseconds: 200));
                cubit.pickCoverImage();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Edit profile bottom sheet ─────────────────────────────────────────────
  void _openEditBottomSheet(BuildContext context, dynamic model) {
    final cubit = MainCubit.get(context);

    final nameParts = (model.name ?? '').split(' ');
    final firstCtrl = TextEditingController(
        text: nameParts.isNotEmpty ? nameParts[0] : '');
    final lastCtrl  = TextEditingController(
        text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');
    final bioCtrl   = TextEditingController(text: model.bio   ?? '');
    final phoneCtrl = TextEditingController(text: model.phone ?? '');
    final currentPassCtrl = TextEditingController();
    final passCtrl  = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24, right: 24, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.of(context).editProfileTitle,
              style: const TextStyle(
                color: Color(0xFFe5c687),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _editField(context, firstCtrl, 'First Name', Icons.person_outline)),
                const SizedBox(width: 12),
                Expanded(child: _editField(context, lastCtrl, 'Last Name', Icons.person_outline)),
              ],
            ),
            const SizedBox(height: 14),
            _editField(context, bioCtrl, 'Bio', Icons.info_outline, maxLines: 2),
            const SizedBox(height: 14),
            _editField(context, phoneCtrl, 'Phone', Icons.phone_outlined),
            const SizedBox(height: 14),
            _editField(context, currentPassCtrl, 'Current Password (to change password)', Icons.lock_outline,
                isPassword: true),
            const SizedBox(height: 14),
            _editField(context, passCtrl, 'New Password (leave blank to keep)', Icons.lock_reset_outlined,
                isPassword: true),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFe5c687),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  final combined =
                  '${firstCtrl.text.trim()} ${lastCtrl.text.trim()}'.trim();
                  cubit.updateProfileData(
                    name:            combined,
                    bio:             bioCtrl.text.trim(),
                    phone:           phoneCtrl.text.trim(),
                    currentPassword: currentPassCtrl.text.trim(),
                    password:        passCtrl.text.trim(),
                    context:         context,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(
      BuildContext context,
      TextEditingController ctrl,
      String label,
      IconData icon, {
        bool isPassword = false,
        int maxLines = 1,
      }) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword,
      maxLines: maxLines,
      style: TextStyle(color: AppColors.of(context).text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        filled: true,
        fillColor: AppColors.of(context).elevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFe5c687), width: 1.5),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
