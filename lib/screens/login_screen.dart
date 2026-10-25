import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/auth_service.dart';
import '../widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth, required this.onSignedIn});
  final AuthService auth;
  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final valid = await widget.auth.authenticate(
        _username.text.trim(), _password.text,
      );
      if (!mounted) return;
      if (valid) {
        widget.onSignedIn();
      } else {
        setState(() => _error = 'Incorrect username or password. Please try again.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to sign in. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 420;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: AppColors.background)),
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 360,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.navy, AppColors.navySoft, Color(0xFF164C68)],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: const Stack(
                children: [
                  Positioned(top: 92, left: -40,
                    child: _Bubble(size: 165, opacity: 0.05)),
                  Positioned(top: 10, right: -35,
                    child: _Bubble(size: 210, opacity: 0.08)),
                  Positioned(top: 210, right: 45,
                    child: _Bubble(size: 48, opacity: 0.09)),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(compact ? 18 : 26, 30, compact ? 18 : 26, 26),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [        
                      Container(
                        width: 138,
                        height: 138,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white70,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/logo.jpg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),
                      const Text('Caitlyn Laundry Shop',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white,
                            fontSize: 26, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 7),
                      const Text('Clean laundry. Organized business.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFE0F0F7), fontSize: 13)),
                      const SizedBox(height: 30),
                      SurfaceCard(
                        padding: EdgeInsets.all(compact ? 21 : 27),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Welcome back',
                                style: TextStyle(fontSize: 24,
                                    fontWeight: FontWeight.w900, color: AppColors.navy)),
                              const SizedBox(height: 5),
                              const Text('Sign in to manage your laundry shop.',
                                style: TextStyle(fontSize: 13, color: AppColors.muted)),
                              const SizedBox(height: 27),
                              const Text('Username', style: TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 9),
                              TextFormField(
                                controller: _username,
                                autofocus: false,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.person_outline),
                                  hintText: 'Enter your username',
                                ),
                                validator: (value) => value == null || value.trim().isEmpty
                                    ? 'Enter your username.' : null,
                              ),
                              const SizedBox(height: 18),
                              const Text('Password', style: TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 9),
                              TextFormField(
                                controller: _password,
                                obscureText: _hidden,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _signIn(),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  hintText: 'Enter your password',
                                  suffixIcon: IconButton(
                                    tooltip: _hidden ? 'Show password' : 'Hide password',
                                    icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: () => setState(() => _hidden = !_hidden),
                                  ),
                                ),
                                validator: (value) => value == null || value.isEmpty
                                    ? 'Enter your password.' : null,
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 15),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE8EB),
                                    borderRadius: BorderRadius.circular(12)),
                                  child: Row(children: [
                                    const Icon(Icons.error_outline,
                                        size: 19, color: AppColors.danger),
                                    const SizedBox(width: 9),
                                    Expanded(child: Text(_error!,
                                      style: const TextStyle(color: AppColors.danger, fontSize: 12))),
                                  ]),
                                ),
                              ],
                              const SizedBox(height: 27),
                              SizedBox(
                                width: double.infinity,
                                height: 53,
                                child: FilledButton.icon(
                                  onPressed: _loading ? null : _signIn,
                                  icon: _loading
                                      ? const SizedBox(width: 18, height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.login_rounded),
                                  label: Text(_loading ? 'Signing in...' : 'Sign in',
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.lock_outline, color: AppColors.muted, size: 16),
                        SizedBox(width: 7),
                        Flexible(child: Text('Offline access • Data stored on this device',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted, fontSize: 12))),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
          border: Border.all(color: Colors.white.withOpacity(opacity)),
        ),
      );
}
