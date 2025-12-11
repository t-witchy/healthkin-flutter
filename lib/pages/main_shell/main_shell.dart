import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:healthkin_flutter/core/api/creature_api.dart';
import 'package:healthkin_flutter/core/provider/health_data_provider.dart';
import 'package:healthkin_flutter/core/services/fitness_sync_service.dart';
import 'package:healthkin_flutter/core/widgets/main_menu_overlay.dart';
import 'package:healthkin_flutter/pages/friends_garden/friends_garden_screen.dart';
import 'package:healthkin_flutter/pages/goals/goals_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _HomeScreen(),
      const _ProgressScreen(),
      const GoalsScreen(),
      const FriendsGardenScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFA9CF8E),
      body: SafeArea(
        child: pages[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: _NavIcon(
              assetPath: 'assets/images/home_icon.png',
            ),
            activeIcon: _NavIcon(
              assetPath: 'assets/images/home_icon.png',
              isActive: true,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _NavIcon(
              assetPath: 'assets/images/progress_icon.png',
            ),
            activeIcon: _NavIcon(
              assetPath: 'assets/images/progress_icon.png',
              isActive: true,
            ),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events),
            label: 'Goals',
          ),
          BottomNavigationBarItem(
            icon: _NavIcon(
              assetPath: 'assets/images/friends_icon.png',
            ),
            activeIcon: _NavIcon(
              assetPath: 'assets/images/friends_icon.png',
              isActive: true,
            ),
            label: 'Friends',
          ),
        ],
      ),
    );
  }
}

class _HomeScreen extends StatefulWidget {
  const _HomeScreen();

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  final CreatureApi _creatureApi = CreatureApi();
  final FitnessSyncService _fitnessSyncService = FitnessSyncService();

  ActiveCreatureResponse? _activeResponse;
  bool _isLoadingCreature = true;
  String? _creatureError;
  bool _isSyncing = false;
  String? _syncErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadActiveCreature();
  }

  Future<void> _syncHealthData() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _syncErrorMessage = null;
    });

    try {
      await _fitnessSyncService.syncNow();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health data synced')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncErrorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not sync health data right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _loadActiveCreature() async {
    try {
      final response = await _creatureApi.getActiveCreature();
      if (!mounted) return;
      setState(() {
        _activeResponse = response;
        _isLoadingCreature = false;
        _creatureError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCreature = false;
        _creatureError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthDataProvider>();

    // Kick off loading of health stats once when the screen is first built.
    if (!health.isLoading && !health.hasData) {
      Future.microtask(
        () => context.read<HealthDataProvider>().loadToday(),
      );
    }

    final stepsText =
        health.stepsToday != null ? '${health.stepsToday}' : '--';
    final exerciseText = health.exerciseMinutesToday != null
        ? '${health.exerciseMinutesToday}'
        : '--';

    final active = _activeResponse?.creature;
    final hasActive = _activeResponse?.hasActive ?? false;

    Widget creatureImage;
    String creatureName = 'Your Creature';

    if (_isLoadingCreature) {
      creatureImage = const SizedBox(
        height: 320,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    } else if (hasActive && active != null) {
      creatureName = active.displayName.isNotEmpty
          ? active.displayName
          : active.nickname.isNotEmpty
              ? active.nickname
              : active.templateName;

      if (active.imageUrl != null && active.imageUrl!.isNotEmpty) {
        creatureImage = Image.network(
          active.imageUrl!,
          height: 320,
          fit: BoxFit.contain,
        );
      } else {
        creatureImage = Image.asset(
          'assets/images/fuffles.png',
          height: 320,
        );
      }
    } else {
      // No active creature found or error – fall back to default image.
      creatureImage = Image.asset(
        'assets/images/fuffles.png',
        height: 320,
      );
      if (_creatureError != null) {
        creatureName = 'Your Creature';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () {
                  showMainMenuOverlay(context);
                },
              ),
              const Spacer(),
              if (_isSyncing)
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(
                    Icons.sync,
                    color: Colors.white,
                  ),
                  tooltip: 'Sync health data',
                  onPressed: _syncHealthData,
                ),
            ],
          ),
        ),
        if (_syncErrorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _syncErrorMessage!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),
                // Creature image (now driven by active creature)
                creatureImage,
                const SizedBox(height: 24),
                Text(
                  creatureName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 150,
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Todays Steps',
                            subtitle: 'Goal: 7500',
                            value: stepsText,
                            icon: Icons.directions_walk,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            title: 'Minutes of Exercise',
                            subtitle: 'Goal: 20 minutes',
                            value: exerciseText,
                            icon: Icons.fitness_center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF8AC193),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final String assetPath;
  final bool isActive;

  const _NavIcon({
    required this.assetPath,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.white : Colors.white70;

    return SizedBox(
      height: 28,
      width: 28,
      child: ImageIcon(
        AssetImage(assetPath),
        color: color,
      ),
    );
  }
}

class _ProgressScreen extends StatelessWidget {
  const _ProgressScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Progress',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FriendsScreen extends StatelessWidget {
  const _FriendsScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Friends',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}


