// lib/layout/edit_profile/edit_profile_screen.dart
//
// Full-page edit profile screen (previously only existed as a bottom sheet
// inside users_screen.dart — the Settings tile navigated to /edit-profile
// which had no registered route, causing a crash).
//
// Reuses MainCubit.updateProfileData() and uploadImagesToSupabase() exactly
// as the existing bottom-sheet did — no cubit changes needed.
// Styling matches the app's dark theme exactly.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../layout/cubit/cubit.dart';
import '../../layout/cubit/states.dart';
import '../../share/local/constants.dart';
import '../../share/style/app_colors.dart';
import '../../utils/validators.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey          = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _currentPassCtrl;
  late TextEditingController _newPassCtrl;

  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _hasChanges     = false;

  @override
  void initState() {
    super.initState();
    final model = MainCubit.get(context).model;
    _nameCtrl        = TextEditingController(text: model?.name  ?? '');
    _bioCtrl         = TextEditingController(text: model?.bio   ?? '');
    _phoneCtrl       = TextEditingController(text: model?.phone ?? '');
    _currentPassCtrl = TextEditingController();
    _newPassCtrl     = TextEditingController();

    for (final c in [_nameCtrl, _bioCtrl, _phoneCtrl, _currentPassCtrl, _newPassCtrl]) {
      c.addListener(() => setState(() => _hasChanges = true));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.of(context).surface,
        title: Text(AppStrings.of(context).discardChanges,
            style: TextStyle(color: AppColors.of(context).text)),
        content: Text(
            AppStrings.of(context).discardChangesBody,
            style: TextStyle(color: AppColors.of(context).textSub)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.of(context).stay, style: TextStyle(color: kGold))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppStrings.of(context).discard,
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    return result ?? false;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final cubit = MainCubit.get(context);

    // Upload any newly picked images first, then update text fields
    final hasImages = cubit.profileImage != null || cubit.coverImage != null;
    if (hasImages) {
      cubit.uploadImagesToSupabase().then((_) {
        if (!mounted) return;
        cubit.updateProfileData(
          name:            _nameCtrl.text.trim(),
          bio:             _bioCtrl.text.trim(),
          phone:           _phoneCtrl.text.trim(),
          currentPassword: _currentPassCtrl.text.trim(),
          password:        _newPassCtrl.text.trim(),
          context:         context,
        );
      });
    } else {
      cubit.updateProfileData(
        name:            _nameCtrl.text.trim(),
        bio:             _bioCtrl.text.trim(),
        phone:           _phoneCtrl.text.trim(),
        currentPassword: _currentPassCtrl.text.trim(),
        password:        _newPassCtrl.text.trim(),
        context:         context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          if (await _onWillPop()) {
            if (mounted) Navigator.pop(context);
          }
        }
      },
      child: BlocConsumer<MainCubit, MainStates>(
        listener: (context, state) {
          if (state is UpdateProfileSuccessState) {
            setState(() => _hasChanges = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.of(context).profileUpdated),
                backgroundColor: const Color(0xFF2e7d32),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pop(context);
          } else if (state is UpdateProfileErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final cubit    = MainCubit.get(context);
          final model    = cubit.model;
          final isLoading = state is UpdateProfileLoadingState;

          return Scaffold(
            backgroundColor: AppColors.of(context).bg,
            appBar: AppBar(
              backgroundColor: AppColors.of(context).bg,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    color: AppColors.of(context).isDark ? Colors.white70 : const Color(0xFFe5c687)),
                onPressed: () async {
                  if (await _onWillPop()) Navigator.pop(context);
                },
              ),
              title: Text(AppStrings.of(context).editProfileTitle,
                  style: TextStyle(
                      color: AppColors.of(context).text,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              actions: [
                isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: kGold, strokeWidth: 2)),
                      )
                    : TextButton(
                        onPressed: _save,
                        child: Text(AppStrings.of(context).save,
                            style: TextStyle(
                                color: kGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ),
              ],
            ),
            body: model == null
                ? const Center(
                    child: CircularProgressIndicator(color: kGold))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Avatar + cover pickers ──────────────────────
                          _AvatarSection(cubit: cubit, model: model),
                          const SizedBox(height: 28),

                          // ── Section label ───────────────────────────────
                          _sectionLabel('Basic Info'),
                          const SizedBox(height: 10),

                          // Name
                          _Field(
                            controller: _nameCtrl,
                            label: 'Display Name',
                            icon: Icons.person_outline,
                            validator: Validators.displayName,
                          ),
                          const SizedBox(height: 14),

                          // Bio — onChanged forces a rebuild so the counter
                          // updates live as the user types (was a static bug)
                          _Field(
                            controller: _bioCtrl,
                            label: 'Bio',
                            icon: Icons.info_outline,
                            maxLines: 3,
                            validator: Validators.bio,
                            helperText: '${_bioCtrl.text.length}/150',
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 14),

                          // Phone
                          _Field(
                            controller: _phoneCtrl,
                            label: 'Phone',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: Validators.phone,
                          ),
                          const SizedBox(height: 28),

                          // ── Change password ─────────────────────────────
                          _sectionLabel('Change Password'),
                          const SizedBox(height: 4),
                          Text(
                            'Leave both fields blank to keep your current password.',
                            style: TextStyle(
                                color: AppColors.of(context).textHint, fontSize: 12),
                          ),
                          const SizedBox(height: 12),

                          _Field(
                            controller: _currentPassCtrl,
                            label: 'Current Password',
                            icon: Icons.lock_outline,
                            obscure: _obscureCurrent,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureCurrent
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.white38,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscureCurrent = !_obscureCurrent),
                            ),
                          ),
                          const SizedBox(height: 14),

                          _Field(
                            controller: _newPassCtrl,
                            label: 'New Password',
                            icon: Icons.lock_reset_outlined,
                            obscure: _obscureNew,
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              return Validators.password(v);
                            },
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNew
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.white38,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureNew = !_obscureNew),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // ── Save button ─────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kGold,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: isLoading ? null : _save,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.black, strokeWidth: 2))
                                  : Text(AppStrings.of(context).saveChanges,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: kGold,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      );
}

// ── Avatar + cover section ────────────────────────────────────────────────────
class _AvatarSection extends StatelessWidget {
  final MainCubit cubit;
  final dynamic model;
  const _AvatarSection({required this.cubit, required this.model});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white10,
                backgroundImage: cubit.profileImage != null
                    ? FileImage(cubit.profileImage!)
                    : (model?.image != null && model!.image!.isNotEmpty)
                        ? CachedNetworkImageProvider(model!.image!)
                            as ImageProvider
                        : null,
                child: (cubit.profileImage == null &&
                        (model?.image == null || model!.image!.isEmpty))
                    ? const Icon(Icons.person,
                        color: Colors.white38, size: 46)
                    : null,
              ),
              GestureDetector(
                onTap: () => cubit.pickProfileImage(ctx: context),
                child: Container(
                  decoration: const BoxDecoration(
                      color: kGold, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(7),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.black, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => cubit.pickCoverImage(ctx: context),
            icon: const Icon(Icons.panorama_outlined,
                color: kGold, size: 18),
            label: Text(AppStrings.of(context).changeCoverPhotoBtn,
                style: const TextStyle(color: kGold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Generic styled field ──────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final int maxLines;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final String? helperText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure        = false,
    this.maxLines       = 1,
    this.keyboardType,
    this.validator,
    this.helperText,
    this.suffixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextFormField(
      controller:    controller,
      obscureText:   obscure,
      maxLines:      obscure ? 1 : maxLines,
      keyboardType:  keyboardType,
      validator:     validator,
      onChanged:     onChanged,
      style: TextStyle(color: c.text, fontSize: 14),
      decoration: InputDecoration(
        labelText:   label,
        labelStyle:  TextStyle(color: c.textHint, fontSize: 13),
        helperText:  helperText,
        helperStyle: TextStyle(color: c.textHint, fontSize: 11),
        prefixIcon:  Icon(icon, color: c.textHint, size: 20),
        suffixIcon:  suffixIcon,
        filled:      true,
        fillColor:   c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kGold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
      ),
    );
  }
}
