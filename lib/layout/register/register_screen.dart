// lib/layout/register/register_screen.dart
//
// Changes from original:
//  • All four validators now return proper error strings (no more print+return null).
//  • Added optional profile photo picker with camera/gallery choice sheet.
//  • Avatar preview shown above the form so users see their chosen photo.
//  • Image picked locally; passed to RegisterCubit.userRegister so it can
//    upload it instead of the bundled default_avatar.png.
//  • RegisterScreen is now a StatefulWidget to hold the picked File state.
//  • Styling kept identical to the rest of the dark app (0xFF0D1117 bg, kGold btn).

import 'dart:io';
import '../../share/style/app_colors.dart';

import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../share/local/components.dart';
import '../../share/local/constants.dart';
import '../../utils/validators.dart';
import 'cubit/register_cubit.dart';
import 'cubit/register_states.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController    = TextEditingController();
  final _formKey            = GlobalKey<FormState>();
  File? _pickedImage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Avatar picker ─────────────────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
              title: Text(AppStrings.of(context).takePhoto, style: TextStyle(color: AppColors.of(context).text)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.white70),
              title: Text(AppStrings.of(context).chooseFromGallery, style: TextStyle(color: AppColors.of(context).text)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RegisterCubit(),
      child: BlocConsumer<RegisterCubit, RegisterStates>(
        listener: (context, state) {
          if (state is RegisterNeedsVerificationState) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: RegisterCubit.get(context),
                  child: EmailVerificationScreen(email: state.email),
                ),
              ),
            );
          } else if (state is RegisterErrorState) {
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
          final cubit = RegisterCubit.get(context);
          final isLoading = state is RegisterLoadingStates;

          return Scaffold(
            backgroundColor: AppColors.of(context).bg,
            appBar: AppBar(
              backgroundColor: AppColors.of(context).bg,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_ios,
                    color: AppColors.of(context).isDark ? Colors.white70 : const Color(0xFFe5c687)),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat, color: kGold),
                  const SizedBox(width: 8),
                  Text('VIBELY',
                      style: TextStyle(
                          color: AppColors.of(context).text,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ],
              ),
              centerTitle: true,
            ),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.of(context).createAccount,
                        style: TextStyle(
                            color: AppColors.of(context).text,
                            fontSize: 32,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.of(context).registerSubtitle,
                        style: TextStyle(color: AppColors.of(context).textHint, fontSize: 14),
                      ),
                      const SizedBox(height: 32),

                      // ── Avatar picker ──────────────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: AppColors.of(context).surface,
                                backgroundImage: _pickedImage != null
                                    ? FileImage(_pickedImage!)
                                    :  AssetImage('assets/images/default_avatar.png'),
                                child: _pickedImage == null
                                    ? const Icon(Icons.person,
                                    color: Colors.white38, size: 44)
                                    : null,
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                  color: kGold,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.camera_alt,
                                    color: Colors.black, size: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          AppStrings.of(context).addProfilePhoto,
                          style: TextStyle(color: AppColors.of(context).textHint, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Name ───────────────────────────────────────────
                      TextFormField(
                        controller: _nameController,
                        keyboardType: TextInputType.name,
                        textDirection: TextDirection.ltr,
                        validator: Validators.displayName,
                        style: TextStyle(color: AppColors.of(context).isDark ? Colors.white : Colors.grey, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: AppStrings.of(context).fullName,
                          labelStyle: TextStyle(color: AppColors.of(context).isDark ? Colors.white : Colors.grey),
                          prefixIcon: Icon(Icons.person_outline, color: AppColors.of(context).isDark ? Colors.white : Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Email ──────────────────────────────────────────
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        validator: Validators.email,
                        style: TextStyle(color: AppColors.of(context).isDark ? Colors.white : Colors.grey, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: AppStrings.of(context).emailAddress,
                          labelStyle: TextStyle(color: AppColors.of(context).isDark ? Colors.white : Colors.grey),
                          prefixIcon: Icon(Icons.email_outlined, color: AppColors.of(context).isDark ? Colors.white : Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Password ───────────────────────────────────────
                      buildTextForm(
                        label: AppStrings.of(context).passwordLabel,
                        type: TextInputType.visiblePassword,
                        preIcon: Icons.lock_outline,
                        suffIcon: cubit.suffix,
                        Visable: cubit.showPassword,
                        isPassword: cubit.isPassword,
                        textController: _passwordController,
                        valid: Validators.password,
                        fieldColor: AppColors.of(context).isDark ? Colors.white : Colors.grey,
                      ),
                      const SizedBox(height: 20),

                      // ── Phone ──────────────────────────────────────────
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        validator: Validators.phone,
                        style: TextStyle(color: AppColors.of(context).isDark ? Colors.white : Colors.grey, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: AppStrings.of(context).phoneOptional,
                          labelStyle: TextStyle(color: AppColors.of(context).isDark ? Colors.white : Colors.grey),
                          prefixIcon: Icon(Icons.phone_outlined, color: AppColors.of(context).isDark ? Colors.white : Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // ── Submit ─────────────────────────────────────────
                      isLoading
                          ? const Center(
                          child: CircularProgressIndicator(color: kGold))
                          : buildLoginButton(
                        text: AppStrings.of(context).createAccount,
                        function: () {
                          if (_formKey.currentState!.validate()) {
                            cubit.userRegister(
                              name: _nameController.text.trim(),
                              email: _emailController.text.trim(),
                              password: _passwordController.text,
                              phone: _phoneController.text.trim(),
                              avatarFile: _pickedImage,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      // ── Already have account ───────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(AppStrings.of(context).alreadyHaveAccount,
                              style: TextStyle(color: AppColors.of(context).textSub)),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(AppStrings.of(context).signIn,
                                style: const TextStyle(color: kGold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}