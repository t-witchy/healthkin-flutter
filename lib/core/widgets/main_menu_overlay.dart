import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:healthkin_flutter/core/api/auth_token_api.dart';
import 'package:healthkin_flutter/core/provider/auth_provider.dart';

Future<void> showMainMenuOverlay(BuildContext context) async {
  final rootContext = context;
  bool isLoggingOut = false;
  String? errorMessage;

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    barrierLabel: 'Menu',
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.5,
          heightFactor: 1.0,
          child: Material(
            color: Colors.white,
            elevation: 8,
            child: StatefulBuilder(
              builder: (menuContext, setState) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Menu',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            tooltip: 'Collapse',
                            onPressed: () =>
                                Navigator.of(menuContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Logout'),
                      onTap: isLoggingOut
                          ? null
                          : () async {
                              setState(() {
                                isLoggingOut = true;
                                errorMessage = null;
                              });

                              try {
                                final api = AuthTokenApi();
                                await api.logout();

                                // Reset auth provider state.
                                rootContext.read<AuthProvider>().logout();

                                Navigator.of(menuContext).pop();
                                Navigator.of(rootContext)
                                    .pushNamedAndRemoveUntil(
                                  '/login',
                                  (route) => false,
                                );
                              } catch (e) {
                                setState(() {
                                  isLoggingOut = false;
                                  errorMessage = e.toString();
                                });
                              }
                            },
                    ),
                    if (errorMessage != null) ...[
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Text(
                          'Error:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    if (isLoggingOut) ...[
                      const SizedBox(height: 8),
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offsetAnimation = Tween<Offset>(
        begin: const Offset(-1.0, 0.0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
      );
      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
  );
}


