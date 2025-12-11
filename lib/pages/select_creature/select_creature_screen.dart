import 'package:flutter/material.dart';

import 'package:healthkin_flutter/core/api/creature_api.dart';
import 'package:healthkin_flutter/core/models/creature_models.dart';
import 'package:healthkin_flutter/core/widgets/main_menu_overlay.dart';

class SelectCreatureScreen extends StatefulWidget {
  const SelectCreatureScreen({super.key});

  @override
  State<SelectCreatureScreen> createState() => _SelectCreatureScreenState();
}

class _SelectCreatureScreenState extends State<SelectCreatureScreen> {
  final CreatureApi _api = CreatureApi();
  final PageController _pageController = PageController(viewportFraction: 0.8);
  final TextEditingController _nicknameController = TextEditingController();

  bool _isLoading = true;
  bool _isPosting = false;
  String? _errorMessage;

  List<CreatureTemplate> _creatures = <CreatureTemplate>[];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchTemplates();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _fetchTemplates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final templates = await _api.fetchCreatureTemplates();
      if (!mounted) return;

      setState(() {
        _creatures = templates;
        _isLoading = false;
        _currentIndex = 0;
      });

      if (_creatures.isNotEmpty) {
        _nicknameController.text = _creatures.first.name;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= _creatures.length) return;

    final previousName =
        _currentIndex >= 0 && _currentIndex < _creatures.length
            ? _creatures[_currentIndex].name
            : null;
    final currentText = _nicknameController.text.trim();

    setState(() {
      _currentIndex = index;
    });

    // If the nickname equals the previous creature name or is empty,
    // automatically update it to the new creature's name.
    if (previousName == null ||
        currentText.isEmpty ||
        currentText == previousName) {
      _nicknameController.text = _creatures[index].name;
    }
  }

  CreatureTemplate? get _selectedCreature {
    if (_currentIndex < 0 || _currentIndex >= _creatures.length) {
      return null;
    }
    return _creatures[_currentIndex];
  }

  Future<void> _onGoPressed() async {
    final creature = _selectedCreature;
    if (creature == null || _isPosting) return;

    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a nickname.'),
        ),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      final result = await _api.chooseFirstCreature(
        creatureId: creature.id,
        nickname: nickname,
      );

      if (!mounted) return;

      setState(() {
        _isPosting = false;
      });

      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPosting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  void _goToPrevious() {
    if (_currentIndex <= 0) return;
    final newIndex = _currentIndex - 1;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _onPageChanged(newIndex);
  }

  void _goToNext() {
    if (_currentIndex >= _creatures.length - 1) return;
    final newIndex = _currentIndex + 1;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _onPageChanged(newIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA9CF8E),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Select Your Avatar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _buildContent(),
                  ),
                  const SizedBox(height: 16),
                  _buildGoButton(),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () {
                  showMainMenuOverlay(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
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
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchTemplates,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_creatures.isEmpty) {
      return const Center(
        child: Text(
          'No creatures available.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final creature = _selectedCreature!;

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _creatures.length,
                itemBuilder: (context, index) {
                  final item = _creatures[index];
                  final isCurrent = index == _currentIndex;

                  return AnimatedScale(
                    scale: isCurrent ? 1.0 : 0.9,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                color: Colors.white.withOpacity(0.4),
                                child: item.imageUrl != null &&
                                        item.imageUrl!.isNotEmpty
                                    ? Image.network(
                                        item.imageUrl!,
                                        fit: BoxFit.contain,
                                      )
                                    : const Icon(
                                        Icons.pets,
                                        size: 96,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (item.description != null &&
                            item.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item.description!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              Positioned(
                left: 0,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                  ),
                  onPressed: _currentIndex > 0 ? _goToPrevious : null,
                ),
              ),
              Positioned(
                right: 0,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                  ),
                  onPressed:
                      _currentIndex < _creatures.length - 1 ? _goToNext : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Your Nickname',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nicknameController,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: creature.name,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoButton() {
    final isDisabled =
        _isLoading || _isPosting || _creatures.isEmpty || _selectedCreature == null;

    return SafeArea(
      top: false,
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
          onPressed: isDisabled ? null : _onGoPressed,
          child: _isPosting
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Go',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}


