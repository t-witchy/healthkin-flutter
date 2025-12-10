import 'package:flutter/material.dart';

import 'package:healthkin_flutter/core/repositories/auth_repository.dart';

/// Provider / ChangeNotifier that holds authentication state.
class AuthProvider extends ChangeNotifier {
  final AuthRepository authRepository;

  bool isLoading = false;
  String? errorMessage;
  bool isLoggedIn = false;
  int? userId;

  AuthProvider({
    required this.authRepository,
  });

  /// Attempt to log the user in via [AuthRepository.login].
  ///
  /// NOTE: Currently this is a spoofed login that does not hit the backend.
  /// It simply waits briefly and marks the user as logged in so that the
  /// UI can be developed without a live server.
  Future<void> login(
    BuildContext context,
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    // Spoofed login: simulate a short network delay, then mark logged in.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    isLoggedIn = true;
    userId = 1;
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }

  /// Simple logout that clears all in-memory auth state.
  void logout() {
    isLoading = false;
    errorMessage = null;
    isLoggedIn = false;
    userId = null;
    notifyListeners();
  }
}

