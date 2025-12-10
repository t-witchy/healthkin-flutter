import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:healthkin_flutter/core/provider/auth_provider.dart';
import 'package:healthkin_flutter/core/provider/health_data_provider.dart';
import 'package:healthkin_flutter/core/repositories/auth_repository.dart';
import 'package:healthkin_flutter/pages/main_shell/main_shell.dart';
import 'package:healthkin_flutter/pages/sign_in_page/sign_in_page.dart';
import 'package:healthkin_flutter/pages/sign_up_page/sign_up_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            authRepository: AuthRepository(),
          ),
        ),
        ChangeNotifierProvider<HealthDataProvider>(
          create: (_) => HealthDataProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'HealthKin',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFA9CF8E),
          ),
          scaffoldBackgroundColor: const Color(0xFFA9CF8E),
        ),
        initialRoute: '/login',
        routes: {
          '/login': (_) => const LoginPage(),
          '/register': (_) => const RegisterPage(),
          '/main': (_) => const MainShell(),
        },
      ),
    );
  }
}


