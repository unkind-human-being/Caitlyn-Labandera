import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'data/app_store.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.initialize();
  runApp(CaitlynApp(store: store));
}

class CaitlynApp extends StatefulWidget {
  const CaitlynApp({super.key, required this.store});
  final AppStore store;

  @override
  State<CaitlynApp> createState() => _CaitlynAppState();
}

class _CaitlynAppState extends State<CaitlynApp> {
  // Require a fresh login on every app launch (no 'remember me' for the MVP).
  bool _signedIn = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Caitlyn Laundry Shop',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: _signedIn
            ? HomeShell(
                store: widget.store,
                onLogout: () => setState(() => _signedIn = false),
              )
            : LoginScreen(
                auth: widget.store.auth,
                onSignedIn: () => setState(() => _signedIn = true),
              ),
      );
}
