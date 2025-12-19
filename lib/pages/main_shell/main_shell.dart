import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:healthkin_flutter/core/api/creature_api.dart';
import 'package:healthkin_flutter/core/api/fitness_api.dart';
import 'package:healthkin_flutter/core/api/goals_status_api.dart';
import 'package:healthkin_flutter/core/provider/health_data_provider.dart';
import 'package:healthkin_flutter/core/services/fitness_sync_service.dart';
import 'package:healthkin_flutter/core/widgets/main_menu_overlay.dart';
import 'package:fl_chart/fl_chart.dart';
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
  final GoalsStatusService _goalsStatusService = GoalsStatusService();

  ActiveCreatureResponse? _activeResponse;
  bool _isLoadingCreature = true;
  String? _creatureError;
  bool _isSyncing = false;
  String? _syncErrorMessage;

  /// The currently selected calendar date (normalized to have no time).
  DateTime _selectedDate = _normalizeDate(DateTime.now());

  /// Cached goal status per day for the visible weeks.
  final Map<DateTime, DailyGoalStatus> _dailyStatusCache = {};
  bool _isLoadingWeek = false;
  String? _weekErrorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDate = _normalizeDate(DateTime.now());
    _loadActiveCreature();
    _syncHealthDataOnStartup();
    _loadHealthForSelectedDate();
    _loadWeekFor(_selectedDate);
  }

  /// Trigger a one-time fitness data sync when the home screen is first
  /// created. This attempts to push the latest health stats to the backend
  /// without showing any user-facing feedback; manual sync still uses the
  /// visible button and SnackBars.
  Future<void> _syncHealthDataOnStartup() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      await _fitnessSyncService.syncNow();
    } catch (_) {
      // Errors are already logged inside FitnessSyncService; no UI feedback
      // needed on startup.
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
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

  /// Normalize a [DateTime] to a date-only value in local time.
  static DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Compute the Sunday-based start of week for the given [date].
  DateTime _startOfWeek(DateTime date) {
    final normalized = _normalizeDate(date);
    // DateTime.weekday: Monday = 1, ..., Sunday = 7.
    final int daysToSubtract = normalized.weekday % 7;
    return normalized.subtract(Duration(days: daysToSubtract));
  }

  /// Returns the 7 dates representing the week containing [anchorDate],
  /// starting on Sunday.
  List<DateTime> _weekDatesFor(DateTime anchorDate) {
    final start = _startOfWeek(anchorDate);
    return List<DateTime>.generate(
      7,
      (index) => start.add(Duration(days: index)),
    );
  }

  void _loadHealthForSelectedDate() {
    final healthProvider = context.read<HealthDataProvider>();
    healthProvider.loadForDate(_selectedDate);
  }

  Future<void> _loadWeekFor(DateTime anchorDate) async {
    if (_isLoadingWeek) return;

    setState(() {
      _isLoadingWeek = true;
      _weekErrorMessage = null;
    });

    final dates = _weekDatesFor(anchorDate);
    final Map<DateTime, DailyGoalStatus> newEntries = {};

    try {
      for (final date in dates) {
        final key = _normalizeDate(date);
        if (_dailyStatusCache.containsKey(key)) continue;

        final statuses = await _goalsStatusService.fetchProgramGoalStatus(
          date: key,
          primaryOnly: true,
        );
        UserProgramGoalStatus? primary;
        if (statuses.isNotEmpty) {
          primary = statuses.first;
        }

        // Determine whether the day's fitness goal should be considered "met"
        // for the purposes of the emoji strip.
        //
        // The backend exposes an aggregate `fitness_goal_met` flag on
        // [UserProgramGoalStatus], but programs can contain multiple fitness
        // components (e.g. steps + exercise minutes). In practice users expect
        // the flame emoji to appear as soon as their **steps** goal for the
        // day is met, even if other components (like exercise minutes) are
        // still in progress.
        //
        // To align with that expectation, we treat the day as "met" if EITHER:
        //   - the backend's aggregate `fitness_goal_met` is true, OR
        //   - any fitness component of type `steps` is marked as met.
        bool fitnessMet = primary?.fitnessGoalMet ?? false;
        if (primary != null) {
          final bool anyStepsComponentMet = primary.fitnessGoals.any(
            (component) =>
                component.goalType == 'steps' && component.met == true,
          );
          if (anyStepsComponentMet) {
            fitnessMet = true;
          }
        }

        final daily = DailyGoalStatus(
          date: key,
          hasActiveProgram: primary != null,
          fitnessGoalMet: fitnessMet,
          programTitle: primary?.programTitle,
        );

        newEntries[key] = daily;
      }

      if (mounted && newEntries.isNotEmpty) {
        setState(() {
          _dailyStatusCache.addAll(newEntries);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weekErrorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingWeek = false;
        });
      }
    }
  }

  void _goToPreviousDay() {
    final newDate = _selectedDate.subtract(const Duration(days: 1));
    _updateSelectedDate(newDate);
  }

  void _goToNextDay() {
    final today = _normalizeDate(DateTime.now());
    if (!_selectedDate.isBefore(today)) return;

    final newDate = _selectedDate.add(const Duration(days: 1));
    _updateSelectedDate(newDate);
  }

  void _updateSelectedDate(DateTime newDate) {
    final normalized = _normalizeDate(newDate);
    setState(() {
      _selectedDate = normalized;
    });
    _loadHealthForSelectedDate();
    _loadWeekFor(normalized);
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
        height: 220,
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
          height: 220,
          fit: BoxFit.contain,
        );
      } else {
        creatureImage = Image.asset(
          'assets/images/fuffles.png',
          height: 220,
        );
      }
    } else {
      // No active creature found or error – fall back to default image.
      creatureImage = Image.asset(
        'assets/images/fuffles.png',
        height: 220,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildGoalCard(),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildWeekStrip(),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                // Creature image (now driven by active creature)
                creatureImage,
                const SizedBox(height: 12),
                Text(
                  creatureName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 90,
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Steps',
                            subtitle: '',
                            value: stepsText,
                            icon: Icons.directions_walk,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            title: 'Min Exercise',
                            subtitle: '',
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

  Widget _buildGoalCard() {
    final today = _normalizeDate(DateTime.now());
    final DailyGoalStatus? todayStatus = _dailyStatusCache[today];
    final DailyGoalStatus? selectedStatus = _dailyStatusCache[_selectedDate];

    // Program title is derived from the user's primary active program for
    // "today", so that the card always reflects their main goal, even when
    // viewing past days in the streak widget.
    final String? programTitle =
        todayStatus?.programTitle ?? selectedStatus?.programTitle;

    final bool hasProgram = programTitle != null && programTitle.isNotEmpty;
    final bool hasProgramOnSelectedDate =
        selectedStatus?.hasActiveProgram ?? false;
    final bool metOnSelectedDate = selectedStatus?.fitnessGoalMet ?? false;

    final String title = hasProgram
        ? 'Goal: $programTitle'
        : 'No active goal yet';

    final String subtitle;
    if (!hasProgram) {
      subtitle = 'Pick a goal to get started.';
    } else if (!hasProgramOnSelectedDate) {
      subtitle = 'No goal active on this date.';
    } else if (metOnSelectedDate) {
      subtitle = _selectedDate == today
          ? 'You met your goal today!'
          : 'Goal met for this day.';
    } else {
      subtitle = _selectedDate == today
          ? 'Not yet met today.'
          : 'Goal not met on this day.';
    }

    final Color borderColor;
    if (!hasProgram) {
      borderColor = Colors.white24;
    } else if (metOnSelectedDate && hasProgramOnSelectedDate) {
      borderColor = const Color(0xFF0D9F6E);
    } else if (hasProgramOnSelectedDate) {
      borderColor = const Color(0xFFE57373);
    } else {
      borderColor = Colors.white38;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3E6D8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: hasProgram ? 1.5 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: !hasProgram
                  ? const Color(0xFF8AC193)
                  : (!hasProgramOnSelectedDate
                      ? const Color(0xFF8AC193)
                      : (metOnSelectedDate
                          ? const Color(0xFF0D9F6E)
                          : const Color(0xFFE57373))),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                !hasProgram
                    ? '🎯'
                    : (!hasProgramOnSelectedDate
                        ? '–'
                        : (metOnSelectedDate ? '🔥' : '💩')),
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip() {
    final weekDates = _weekDatesFor(_selectedDate);
    final today = _normalizeDate(DateTime.now());
    final bool canGoForward = _selectedDate.isBefore(today);

    String dateLabel;
    if (_selectedDate == today) {
      dateLabel = 'Today';
    } else {
      final weekdayAbbr = _weekdayAbbr(_selectedDate.weekday);
      dateLabel = '$weekdayAbbr ${_selectedDate.day}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: _goToPreviousDay,
            ),
            Expanded(
              child: Center(
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: canGoForward ? _goToNextDay : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 72,
          child: Row(
            children: [
              for (final date in weekDates)
                Expanded(
                  child: _buildDayCell(date),
                ),
            ],
          ),
        ),
        if (_isLoadingWeek)
          const Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 12,
              width: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        if (_weekErrorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _weekErrorMessage!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDayCell(DateTime date) {
    final normalized = _normalizeDate(date);
    final isSelected = normalized == _selectedDate;
    final DailyGoalStatus? status = _dailyStatusCache[normalized];
    final bool hasProgram = status?.hasActiveProgram ?? false;
    final bool met = status?.fitnessGoalMet ?? false;
    final DateTime today = _normalizeDate(DateTime.now());
    final bool isFutureDate = normalized.isAfter(today);

    String emoji;
    if (status == null) {
      emoji = '…';
    } else if (!hasProgram) {
      // No active goal for this date – show a neutral placeholder instead
      // of a "failed" poop emoji.
      emoji = '–';
    } else if (met) {
      emoji = '🔥';
    } else if (isFutureDate) {
      // For future dates, do not show failure even if data exists; use
      // a neutral marker instead.
      emoji = '–';
    } else {
      // Past or present day with an active goal that has not been met.
      emoji = '💩';
    }

    final String dow = _weekdayAbbr(normalized.weekday);
    final String dayNum = '${normalized.day}';

    final Color bgColor = isSelected ? Colors.black87 : Colors.white24;
    final Color textColor = isSelected ? Colors.white : Colors.white;

    return GestureDetector(
      onTap: () => _updateSelectedDate(normalized),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dow,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dayNum,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              emoji,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  String _weekdayAbbr(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple UI model representing whether a goal was active and met on a day.
class DailyGoalStatus {
  final DateTime date;
  final bool hasActiveProgram;
  final bool fitnessGoalMet;
  final String? programTitle;

  DailyGoalStatus({
    required this.date,
    required this.hasActiveProgram,
    required this.fitnessGoalMet,
    this.programTitle,
  });
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
    return const _ProgressContent();
  }
}

class _ProgressContent extends StatefulWidget {
  const _ProgressContent();

  @override
  State<_ProgressContent> createState() => _ProgressContentState();
}

class _ProgressContentState extends State<_ProgressContent> {
  final FitnessApi _fitnessApi = FitnessApi();

  int _weekOffset = 0;
  bool _isLoading = true;
  String? _errorMessage;
  List<WeeklyStepsPoint> _steps = const [];
  List<WeeklyMinutesPoint> _minutes = const [];

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
      final results = await Future.wait([
        _fitnessApi.fetchWeeklySteps(weekOffset: _weekOffset),
        _fitnessApi.fetchWeeklyMinutes(weekOffset: _weekOffset),
      ]);

      if (!mounted) return;
      setState(() {
        _steps = results[0] as List<WeeklyStepsPoint>;
        _minutes = results[1] as List<WeeklyMinutesPoint>;
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

  void _goToPreviousWeek() {
    setState(() {
      _weekOffset += 1;
    });
    _loadData();
  }

  void _goToNextWeek() {
    if (_weekOffset == 0) return;
    setState(() {
      _weekOffset -= 1;
    });
    _loadData();
  }

  String _weekLabel() {
    if (_weekOffset == 0) {
      return 'This Week';
    }
    if (_weekOffset == 1) {
      return 'Last Week';
    }
    return '${_weekOffset} weeks ago';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
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
              const SizedBox(width: 8),
              const Text(
                'Progress',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                    ),
                    onPressed: _goToPreviousWeek,
                  ),
                  Text(
                    _weekLabel(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                    ),
                    onPressed: _weekOffset == 0 ? null : _goToNextWeek,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        if (_isLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WeeklyLineChartCard.steps(data: _steps),
                  const SizedBox(height: 16),
                  _WeeklyLineChartCard.minutes(data: _minutes),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WeeklyLineChartCard extends StatelessWidget {
  final List<WeeklyStepsPoint>? _stepsData;
  final List<WeeklyMinutesPoint>? _minutesData;
  final bool _isSteps;

  const _WeeklyLineChartCard.steps({
    required List<WeeklyStepsPoint> data,
    super.key,
  })  : _stepsData = data,
        _minutesData = null,
        _isSteps = true;

  const _WeeklyLineChartCard.minutes({
    required List<WeeklyMinutesPoint> data,
    super.key,
  })  : _stepsData = null,
        _minutesData = data,
        _isSteps = false;

  @override
  Widget build(BuildContext context) {
    final isEmpty =
        (_isSteps ? _stepsData?.isEmpty : _minutesData?.isEmpty) ?? true;

    final title = _isSteps ? 'Weekly Steps' : 'Weekly Exercise Minutes';
    final color = _isSteps
        ? const Color(0xFF0D7F53)
        : const Color(0xFF2F4F9F); // green vs blue tone

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3E6D8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mon – Sun',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: isEmpty
                ? const Center(
                    child: Text(
                      'No data for this week yet.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  )
                : LineChart(
                    _buildChartData(color),
                  ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildChartData(Color color) {
    final spots = <FlSpot>[];
    if (_isSteps) {
      final data = _stepsData ?? const [];
      for (var i = 0; i < data.length; i++) {
        spots.add(FlSpot(i.toDouble(), data[i].totalSteps.toDouble()));
      }
    } else {
      final data = _minutesData ?? const [];
      for (var i = 0; i < data.length; i++) {
        spots.add(FlSpot(i.toDouble(), data[i].totalExerciseMinutes.toDouble()));
      }
    }

    double maxY = spots.fold<double>(
      0,
      (prev, s) => s.y > prev ? s.y : prev,
    );
    if (maxY == 0) {
      maxY = 10;
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withOpacity(0.3),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: maxY / 4,
            getTitlesWidget: (value, meta) {
              if (value < 0) return const SizedBox.shrink();
              return Text(
                value.toInt().toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              if (value < 0 || value > 6) {
                return const SizedBox.shrink();
              }
              final index = value.toInt();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  labels[index],
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(
          color: Colors.grey.withOpacity(0.4),
        ),
      ),
      minX: 0,
      maxX: 6,
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 3,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: color.withOpacity(0.2),
          ),
        ),
      ],
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


