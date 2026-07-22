// lib/layout/login/login_screen.dart — Arabic strings wired
import '../../layout/home.dart';
import '../../share/local/components.dart';
import '../../share/local/cashe_helper.dart';
import '../../share/local/constants.dart';
import '../../share/local/app_strings.dart';
import '../../share/style/app_colors.dart';
import '../../utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/cubit.dart';
import '../register/register_screen.dart';
import '../register/email_verification_screen.dart';
import 'forgot_password_screen.dart';
import 'cubit/login_cubit.dart';
import 'cubit/login_states.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  // Tracks whether this is the very first login ever on this device
  bool _isFirstTime = false;

  @override
  void initState() {
    super.initState();
    // If 'uId' was never saved, this is a first-time user
    final savedUid = CashHelper.getData(key: 'uId');
    final seenBefore = CashHelper.getData(key: 'hasLoggedInBefore') ?? false;
    _isFirstTime = (savedUid == null || savedUid == '') && !seenBefore;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c  = AppColors.of(context);
    final s  = AppStrings.of(context);
    return BlocProvider(
      create: (_) => LoginCubit(),
      child: BlocConsumer<LoginCubit, LoginStates>(
        listener: (context, state) {
          if (state is LoginSuccessState) {
            // Mark that the user has logged in at least once
            CashHelper.saveData(key: 'hasLoggedInBefore', value: true);
            CashHelper.saveData(key: 'uId', value: state.uid).then((_) {
              navigateAndReplacement(context, const HomeScreen());
              MainCubit.get(context).initializeApp();
            });
          }
          if (state is LoginNeedsVerificationState) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text(
                  'Please verify your email before logging in.'),
              backgroundColor: const Color(0xFFb8934e),
              behavior: SnackBarBehavior.floating,
            ));
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmailVerificationScreen(email: state.email),
              ),
            );
          }
          if (state is LoginErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.error),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        builder: (context, state) {
          final cubit     = LoginCubit.get(context);
          final isLoading = state is LoginLoadingState;
          return Scaffold(
            backgroundColor: c.bg,
            appBar: AppBar(
              backgroundColor: c.bg,
              elevation: 0,
              centerTitle: true,
              title: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat, color: kGold),
                const SizedBox(width: 8),
                Text('VIBELY',
                    style: TextStyle(
                        color: c.text, fontWeight: FontWeight.bold, fontSize: 18)),
              ]),
            ),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // First time → "Welcome", returning → "Welcome back"
                    Text(_isFirstTime ? s.welcomeFirst : s.welcomeBack,
                        style: TextStyle(
                            color: c.text, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_isFirstTime ? s.welcomeFirstSubtitle : s.loginSubtitle,
                        style: TextStyle(color: c.textHint, fontSize: 14)),
                    const SizedBox(height: 40),
                    // Email — auto text direction
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      validator: Validators.email,
                      style: TextStyle(color: c.isDark ? Colors.white : Colors.grey, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: s.emailAddress,
                        labelStyle: TextStyle(color: c.isDark ? Colors.white : Colors.grey),
                        prefixIcon: Icon(Icons.email_outlined, color: c.isDark ? Colors.white : Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Password
                    buildTextForm(
                      label: s.passwordLabel,
                      type: TextInputType.visiblePassword,
                      preIcon: Icons.lock_outline,
                      suffIcon: cubit.suffix,
                      isPassword: cubit.isPassword,
                      Visable: cubit.showPassword,
                      textController: _passwordCtrl,
                      valid: Validators.password,
                      fieldColor: c.isDark ? Colors.white : Colors.grey,
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            navigateTo(context, const ForgotPasswordScreen()),
                        child: Text(s.forgotPassword,
                            style: const TextStyle(color: kGold, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    isLoading
                        ? const Center(
                        child: CircularProgressIndicator(color: kGold))
                        : buildLoginButton(
                      text: s.login,
                      function: () {
                        if (_formKey.currentState!.validate()) {
                          cubit.userLogin(
                            email:    _emailCtrl.text.trim(),
                            password: _passwordCtrl.text,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 28),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(s.noAccount,
                          style: TextStyle(color: c.textSub, fontSize: 14)),
                      TextButton(
                        onPressed: () =>
                            navigateTo(context, const RegisterScreen()),
                        child: Text(s.registerNow,
                            style: const TextStyle(
                                color: kGold,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}