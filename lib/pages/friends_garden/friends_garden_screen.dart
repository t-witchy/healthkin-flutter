import 'dart:math';

import 'package:flutter/material.dart';

import 'package:healthkin_flutter/core/api/creature_api.dart';
import 'package:healthkin_flutter/core/api/friends_api.dart';

class FriendsGardenScreen extends StatefulWidget {
  const FriendsGardenScreen({super.key});

  @override
  State<FriendsGardenScreen> createState() => _FriendsGardenScreenState();
}

class _FriendsGardenScreenState extends State<FriendsGardenScreen> {
  final CreatureApi _creatureApi = CreatureApi();
  final FriendsApi _friendsApi = FriendsApi();
  final Random _random = Random();

  bool _isLoading = true;
  String? _errorMessage;

  late List<_CreatureSlot> _slots;
  late List<int> _anchorIndices;

  static const List<Offset> _anchorPositions = [
    Offset(0.15, 0.25),
    Offset(0.65, 0.22),
    Offset(0.30, 0.50),
    Offset(0.70, 0.55),
    Offset(0.20, 0.75),
    Offset(0.60, 0.78),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final activeFuture = _creatureApi.getActiveCreature();
      final friendsFuture = _friendsApi.fetchFriendsActiveCreatures();

      final activeResponse = await activeFuture;
      final friends = await friendsFuture;

      final List<_CreatureSlot> slots = [];

      if (activeResponse.hasActive && activeResponse.creature != null) {
        final me = activeResponse.creature!;
        final name = me.displayName.isNotEmpty
            ? me.displayName
            : me.nickname.isNotEmpty
                ? me.nickname
                : me.templateName;
        if (me.imageUrl != null && me.imageUrl!.isNotEmpty) {
          slots.add(
            _CreatureSlot(
              imageUrl: me.imageUrl!,
              label: name,
            ),
          );
        }
      }

      final shuffledFriends = List<FriendActiveCreature>.from(friends)
        ..shuffle(_random);
      for (final f in shuffledFriends) {
        if (slots.length >= 4) break;
        if (f.creatureImageUrl.isEmpty) continue;
        slots.add(
          _CreatureSlot(
            imageUrl: f.creatureImageUrl,
            label: f.creatureNickname.isNotEmpty
                ? '${f.creatureNickname} (${f.friendName})'
                : f.friendName,
          ),
        );
      }

      if (slots.isEmpty) {
        _slots = const [];
        _anchorIndices = const [];
      } else {
        _slots = slots;
        final availableIndices = List<int>.generate(
          _anchorPositions.length,
          (i) => i,
        )..shuffle(_random);
        final count = min(4, _slots.length);
        _anchorIndices = availableIndices.take(count).toList();
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _showInviteModal() async {
    final rootContext = context;
    final TextEditingController emailController = TextEditingController();
    String? localError;
    bool isSending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: bottomInset + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Invite a Friend',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Friend\'s email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      localError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: isSending
                          ? null
                          : () async {
                              final email = emailController.text.trim();
                              if (email.isEmpty) {
                                setSheetState(() {
                                  localError = 'Please enter an email address.';
                                });
                                return;
                              }

                              setSheetState(() {
                                isSending = true;
                                localError = null;
                              });

                              try {
                                await _friendsApi.sendFriendInvite(email);
                                if (!mounted) return;
                                Navigator.of(sheetContext).pop();
                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invitation sent!'),
                                  ),
                                );
                              } catch (e) {
                                setSheetState(() {
                                  isSending = false;
                                  localError = e.toString();
                                });
                              }
                            },
                      child: isSending
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Send',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA9CF8E),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/garden.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: _buildGardenContent(),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _showInviteModal,
                      child: const Text(
                        'Invite Friends',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildGardenContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_slots.isEmpty || _anchorIndices.isEmpty) {
      return const Center(
        child: Text(
          'No creatures to show yet.\nInvite some friends!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double creatureSize = 110;
        final List<Widget> positioned = [];

        for (int i = 0; i < _anchorIndices.length && i < _slots.length; i++) {
          final slot = _slots[i];
          final anchor = _anchorPositions[_anchorIndices[i]];
          final left =
              anchor.dx * constraints.maxWidth - creatureSize / 2.0;
          final top =
              anchor.dy * constraints.maxHeight - creatureSize / 2.0;

          positioned.add(
            Positioned(
              left: left.clamp(0.0, constraints.maxWidth - creatureSize),
              top: top.clamp(0.0, constraints.maxHeight - creatureSize - 40),
              width: creatureSize,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: creatureSize,
                    width: creatureSize,
                    child: Image.network(
                      slot.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slot.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Stack(children: positioned);
      },
    );
  }
}

class _CreatureSlot {
  final String imageUrl;
  final String label;

  _CreatureSlot({
    required this.imageUrl,
    required this.label,
  });
}


