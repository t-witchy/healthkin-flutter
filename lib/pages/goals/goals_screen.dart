import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:healthkin_flutter/core/api/friends_api.dart';
import 'package:healthkin_flutter/core/api/goals_api.dart';
import 'package:healthkin_flutter/core/provider/auth_provider.dart';
import 'package:healthkin_flutter/core/services/fitness_sync_service.dart';
import 'package:healthkin_flutter/core/widgets/main_menu_overlay.dart';

enum GoalCategoryFilter { all, steps, exercise }

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final GoalsApi _api = GoalsApi();
  final FriendsApi _friendsApi = FriendsApi();
  final FitnessSyncService _fitnessSyncService = FitnessSyncService();

  bool _isLoading = true;
  bool _isEnrolling = false;
  bool _isStopping = false;
  bool _isSyncing = false;
  String? _errorMessage;
  String? _syncErrorMessage;

  List<UserGoal> _activeGoals = <UserGoal>[];
  List<GoalProgram> _availableGoals = <GoalProgram>[];
  GoalCategoryFilter _filter = GoalCategoryFilter.all;

  @override
  void initState() {
    super.initState();
    _loadGoals();
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
      // The service itself swallows most errors, but if something bubbles up
      // we still want a user-visible message.
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

  Future<void> _loadGoals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final activeFuture = _api.fetchActiveGoals();
      final availableFuture = _api.fetchAvailableGoals();

      final active = await activeFuture;
      final available = await availableFuture;

      if (!mounted) return;
      setState(() {
        _activeGoals = active;
        _availableGoals = available;
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

  void _setFilter(GoalCategoryFilter filter) {
    setState(() {
      if (_filter == filter) {
        _filter = GoalCategoryFilter.all;
      } else {
        _filter = filter;
      }
    });
  }

  List<GoalProgram> get _filteredAvailableGoals {
    switch (_filter) {
      case GoalCategoryFilter.steps:
        return _availableGoals.where((g) => g.hasStepsComponent).toList();
      case GoalCategoryFilter.exercise:
        return _availableGoals
            .where((g) => g.hasExerciseMinutesComponent)
            .toList();
      case GoalCategoryFilter.all:
      default:
        return _availableGoals;
    }
  }

  Future<void> _enrollInGoal(GoalProgram program) async {
    if (_isEnrolling || _isStopping) return;
    setState(() {
      _isEnrolling = true;
    });

    try {
      await _api.enrollInGoal(programId: program.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal updated')),
      );

      await _loadGoals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() {
        _isEnrolling = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isEnrolling = false;
        });
      }
    }
  }

  Future<void> _stopGoal(UserGoal goal) async {
    if (_isStopping || _isEnrolling) return;
    setState(() {
      _isStopping = true;
    });

    try {
      await _api.stopGoal(goal.userProgramId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal stopped')),
      );

      await _loadGoals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() {
        _isStopping = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStopping = false;
        });
      }
    }
  }

  Future<void> _showChallengeModal(UserGoal mainGoal) async {
    // Safety: ensure the goal is still active before allowing invites/challenges.
    final isStillActive = _activeGoals.any(
      (g) => g.userProgramId == mainGoal.userProgramId,
    );
    if (!isStillActive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You need to start this goal before inviting a friend.',
            ),
          ),
        );
      }
      return;
    }

    // Preload friends (prefer full friends list by user id), pending
    // challenges, and pending email invitations for this program.
    List<FriendActiveCreature> friends = const [];
    List<GoalChallenge> pending = const [];
    List<String> pendingEmails = const [];
    String? initialError;

    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.userId;

      if (userId != null) {
        friends = await _friendsApi.fetchFriendsForUser(userId);
      } else {
        friends = await _friendsApi.fetchFriendsActiveCreatures();
      }
      pending = await _api.fetchPendingChallenges();
      pendingEmails = await _api.fetchPendingChallengeEmails(
        programId: mainGoal.program.id,
      );
    } catch (e) {
      initialError = e.toString();
    }

    if (!mounted) return;

    final TextEditingController emailController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        bool isSending = false;
        bool isAccepting = false;
        String? error = initialError;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final bottomInset =
                MediaQuery.of(sheetContext).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: bottomInset + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Challenge a Friend',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Your Friends',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (friends.isEmpty)
                      const Text(
                        'No friends yet. Invite someone by email below.',
                        style: TextStyle(fontSize: 13),
                      )
                    else
                      Column(
                        children: [
                          for (final f in friends)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    const Color(0xFF2F9467),
                                backgroundImage:
                                    (f.creatureImageUrl.isNotEmpty)
                                        ? NetworkImage(
                                            f.creatureImageUrl,
                                          )
                                        : null,
                                child: f.creatureImageUrl.isEmpty
                                    ? const Icon(
                                        Icons.pets,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              title: Text(f.friendName),
                              subtitle: Text(
                                f.creatureNickname.isNotEmpty
                                    ? f.creatureNickname
                                    : 'No creature nickname',
                              ),
                              trailing: TextButton(
                                onPressed: isSending || isAccepting
                                    ? null
                                    : () async {
                                        setSheetState(() {
                                          isSending = true;
                                          error = null;
                                        });
                                        try {
                                          await _api.createChallenge(
                                            programId:
                                                mainGoal.program.id,
                                            friendId: f.friendId,
                                          );
                                          if (!mounted) return;
                                          Navigator.of(sheetContext)
                                              .pop();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Challenge sent to ${f.friendName}',
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          setSheetState(() {
                                            isSending = false;
                                            error = e.toString();
                                          });
                                        }
                                      },
                                child: const Text('Challenge'),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Pending Email Invites',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (pendingEmails.isEmpty)
                      const Text(
                        'No pending email invitations for this goal.',
                        style: TextStyle(fontSize: 13),
                      )
                    else
                      Column(
                        children: [
                          for (final email in pendingEmails)
                            ListTile(
                              leading: const Icon(
                                Icons.email_outlined,
                                color: Color(0xFF2F9467),
                              ),
                              title: Text(email),
                              subtitle: const Text(
                                'Invitation sent',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Pending Challenges',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (pending.isEmpty)
                      const Text(
                        'You have no pending challenges.',
                        style: TextStyle(fontSize: 13),
                      )
                    else
                      Column(
                        children: [
                          for (final c in pending)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    const Color(0xFF2F9467),
                                backgroundImage:
                                    (c.challenger.activeCreatureImageUrl !=
                                                null &&
                                            c.challenger
                                                .activeCreatureImageUrl!
                                                .isNotEmpty)
                                        ? NetworkImage(
                                            c.challenger
                                                .activeCreatureImageUrl!,
                                          )
                                        : null,
                                child: (c.challenger
                                                .activeCreatureImageUrl ==
                                            null ||
                                        c
                                            .challenger
                                            .activeCreatureImageUrl!
                                            .isEmpty)
                                    ? const Icon(
                                        Icons.pets,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              title: Text(
                                  c.challenger.displayName),
                              subtitle: Text(c.program.title),
                              trailing: TextButton(
                                onPressed: isSending || isAccepting
                                    ? null
                                    : () async {
                                        setSheetState(() {
                                          isAccepting = true;
                                          error = null;
                                        });
                                        try {
                                          await _api
                                              .acceptChallenge(c.id);
                                          if (!mounted) return;
                                          Navigator.of(sheetContext)
                                              .pop();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Challenge accepted',
                                              ),
                                            ),
                                          );
                                          await _loadGoals();
                                        } catch (e) {
                                          setSheetState(() {
                                            isAccepting = false;
                                            error = e.toString();
                                          });
                                        }
                                      },
                                child: const Text('Accept'),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Invite by Email',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Friend email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: isSending || isAccepting
                            ? null
                            : () async {
                                final email =
                                    emailController.text.trim();
                                if (email.isEmpty) {
                                  setSheetState(() {
                                    error =
                                        'Please enter an email address.';
                                  });
                                  return;
                                }
                                setSheetState(() {
                                  isSending = true;
                                  error = null;
                                });
                                try {
                                  await _friendsApi
                                      .sendFriendInvite(email);
                                  if (!mounted) return;
                                  Navigator.of(sheetContext).pop();
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Invitation sent!'),
                                    ),
                                  );
                                } catch (e) {
                                  setSheetState(() {
                                    isSending = false;
                                    error = e.toString();
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Send Invitation',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = _activeGoals.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFA9CF8E),
      body: SafeArea(
        child: Column(
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
                  const SizedBox(width: 8),
                  Text(
                    hasActive ? 'Your Goals' : 'Select a Goal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_isSyncing)
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
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
            if (!hasActive)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'You don’t currently have an active goal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
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
                        onPressed: _loadGoals,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadGoals,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      if (hasActive) _buildActiveGoalsSection(),
                      const SizedBox(height: 16),
                      _buildCategoriesSection(),
                      const SizedBox(height: 12),
                      _buildAvailableGoalsSection(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveGoalsSection() {
    if (_activeGoals.isEmpty) return const SizedBox.shrink();
    final mainGoal = _activeGoals.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Goal',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _ActiveGoalCard(
          userGoal: mainGoal,
          onStop: () => _stopGoal(mainGoal),
          onInviteFriend: (!mainGoal.isWithFriend && mainGoal.friend == null)
              ? () => _showChallengeModal(mainGoal)
              : null,
          isMutating: _isEnrolling || _isStopping,
        ),
        if (_activeGoals.length > 1) ...[
          const SizedBox(height: 12),
          const Text(
            'Other Active Goals',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final g in _activeGoals.skip(1))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SmallGoalCard(
                userGoal: g,
                onStop: () => _stopGoal(g),
                onInviteFriend:
                    (!g.isWithFriend && g.friend == null)
                        ? () => _showChallengeModal(g)
                        : null,
                isMutating: _isEnrolling || _isStopping,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categories',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _CategoryChip(
              label: 'Steps',
              icon: Icons.local_fire_department,
              selected: _filter == GoalCategoryFilter.steps,
              onTap: () => _setFilter(GoalCategoryFilter.steps),
            ),
            const SizedBox(width: 12),
            _CategoryChip(
              label: 'Exercise',
              icon: Icons.fitness_center,
              selected: _filter == GoalCategoryFilter.exercise,
              onTap: () => _setFilter(GoalCategoryFilter.exercise),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvailableGoalsSection() {
    final goals = _filteredAvailableGoals;
    final activeProgramIds =
        _activeGoals.map((g) => g.program.id).toSet();

    if (goals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Text(
          'No additional goals available right now.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        for (final goal in goals)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AvailableGoalCard(
              program: goal,
              hasActiveGoal: activeProgramIds.contains(goal.id),
              isEnrolling: _isEnrolling,
              onPressed: () => _enrollInGoal(goal),
            ),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? Colors.white : Colors.white.withOpacity(0.8);
    final iconBg = selected ? const Color(0xFF0D9F6E) : const Color(0xFF399A6A);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveGoalCard extends StatelessWidget {
  final UserGoal userGoal;
  final VoidCallback onStop;
  final VoidCallback? onInviteFriend;
  final bool isMutating;

  const _ActiveGoalCard({
    required this.userGoal,
    required this.onStop,
    this.onInviteFriend,
    this.isMutating = false,
  });

  @override
  Widget build(BuildContext context) {
    final friend = userGoal.friend;
    final withFriend = userGoal.isWithFriend && friend != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE3E6D8),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF2F9467),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.directions_walk,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userGoal.program.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                if (withFriend) ...[
                  const SizedBox(height: 4),
                  Text(
                    'With ${friend.displayName}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE57373),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: isMutating ? null : onStop,
                  child: const Text(
                    'Stop',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (onInviteFriend != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0D7F53)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: isMutating ? null : onInviteFriend,
                    child: const Text(
                      'Invite a friend',
                      style: TextStyle(
                        color: Color(0xFF0D7F53),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallGoalCard extends StatelessWidget {
  final UserGoal userGoal;
   final VoidCallback onStop;
   final VoidCallback? onInviteFriend;
   final bool isMutating;

  const _SmallGoalCard({
    required this.userGoal,
    required this.onStop,
    this.onInviteFriend,
    this.isMutating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE3E6D8),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.flag,
            color: Colors.black87,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              userGoal.program.title,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: isMutating ? null : onStop,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE57373),
                ),
                child: const Text(
                  'Stop',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onInviteFriend != null)
                TextButton(
                  onPressed: isMutating ? null : onInviteFriend,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0D7F53),
                  ),
                  child: const Text(
                    'Invite',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvailableGoalCard extends StatelessWidget {
  final GoalProgram program;
  final bool hasActiveGoal;
  final bool isEnrolling;
  final VoidCallback onPressed;

  const _AvailableGoalCard({
    required this.program,
    required this.hasActiveGoal,
    required this.isEnrolling,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isSteps = program.hasStepsComponent;
    final isExercise = program.hasExerciseMinutesComponent;

    IconData icon = Icons.flag;
    if (isSteps) {
      icon = Icons.directions_walk;
    } else if (isExercise) {
      icon = Icons.fitness_center;
    }

    final buttonLabel = hasActiveGoal ? 'Change Goal' : 'Start';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE3E6D8),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF2F9467),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              program.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D7F53),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: isEnrolling ? null : onPressed,
            icon: const Icon(
              Icons.play_arrow,
              size: 16,
              color: Colors.white,
            ),
            label: Text(
              buttonLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

