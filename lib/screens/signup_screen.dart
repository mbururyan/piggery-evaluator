import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

/// DEBUG-ONLY test-account screen. Only reachable from the login screen
/// in debug builds (see kDebugMode there). Deleted in Phase 5, when admins
/// create accounts from the web app.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);

    String? error;
    try {
      await AuthService.instance.signUp(
        fullName: _nameCtrl.text,
        username: _usernameCtrl.text,
        email: _emailCtrl.text,
        phone: _phoneCtrl.text,
        password: _passwordCtrl.text,
      );
      // createUser signs the new account in automatically. Sign straight
      // back out, so the tester goes through the real login screen, which
      // is the flow we're actually testing.
      await AuthService.instance.signOut();
    } on AuthException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Something went wrong. Try again';
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.alert),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test account created. Log in with it now'),
        backgroundColor: AppColors.green,
      ),
    );
    Navigator.of(context).pop(); // back to login
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      );

  Widget _eye(bool obscured, VoidCallback toggle) => IconButton(
        icon: Icon(obscured
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined),
        onPressed: toggle,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // The ribbon makes a debug build impossible to mistake for the
            // real thing, e.g. if a screenshot ends up in a demo deck.
            Container(
              width: double.infinity,
              color: AppColors.amber,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Text(
                'DEBUG BUILD ONLY · NOT IN RELEASE APKs',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.white,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUnfocus,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Create test account',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Always created as an EO. Admins come from the web app.',
                            style:
                                TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                          const SizedBox(height: 24),

                          _fieldLabel('Full name'),
                          TextFormField(
                            controller: _nameCtrl,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                                hintText: 'e.g. Jane Kamau'),
                            validator: (v) =>
                                Validators.required(v, 'Full name'),
                          ),
                          const SizedBox(height: 16),

                          _fieldLabel('Username'),
                          TextFormField(
                            controller: _usernameCtrl,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                                hintText: 'Lowercase, e.g. jkamau'),
                            validator: Validators.username,
                          ),
                          const SizedBox(height: 16),

                          _fieldLabel('Email'),
                          TextFormField(
                            controller: _emailCtrl,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: const InputDecoration(
                                hintText: 'name@example.com'),
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 16),

                          _fieldLabel('Phone'),
                          TextFormField(
                            controller: _phoneCtrl,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                                hintText: '07xx or 01xx, or +254...'),
                            validator: Validators.kenyanPhone,
                          ),
                          const SizedBox(height: 16),

                          _fieldLabel('Password'),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'At least 8 characters with a number',
                              suffixIcon: _eye(
                                  _obscurePassword,
                                  () => setState(() =>
                                      _obscurePassword = !_obscurePassword)),
                            ),
                            validator: Validators.password,
                          ),
                          const SizedBox(height: 16),

                          _fieldLabel('Confirm password'),
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            // The match check runs live while typing, so
                            // this one field overrides the form's on-blur rule.
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            decoration: InputDecoration(
                              hintText: 'Repeat the password',
                              suffixIcon: _eye(
                                  _obscureConfirm,
                                  () => setState(() =>
                                      _obscureConfirm = !_obscureConfirm)),
                            ),
                            validator: (v) => Validators.confirmPassword(
                                v, _passwordCtrl.text),
                          ),
                          const SizedBox(height: 24),

                          ElevatedButton(
                            onPressed: _submitting ? null : _submit,
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.white),
                                  )
                                : const Text('Create account'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Back to login',
                                style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}