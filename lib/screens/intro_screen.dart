import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/gemini_service.dart';
import '../state/app_state.dart';
import 'dart:math';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  late AnimationController _pulseController;

  final List<String> _allSuggestions = [
    'learn a new language',
    'travel the world',
    'get fit and healthy',
    'start a business',
    'learn to cook',
    'read more books',
    'make new friends',
    'learn an instrument',
    'volunteer more',
    'save money',
    'learn to code',
    'write a book',
    'run a marathon',
    'learn photography',
    'grow a garden',
    'meditate daily',
    'learn to dance',
    'build stronger relationships',
    'develop a skill',
    'explore nature',
    'practice mindfulness',
    'create art',
    'help others',
    'stay organized',
  ];

  List<String> _suggestions = [];
  final List<bool> _suggestionsUsed = [];

  @override
  void initState() {
    super.initState();
    // Pulse animation controller (slower, continuous in and out)
    _pulseController = AnimationController(
      duration: const Duration(seconds: 4), // Slower
      vsync: this,
    )..repeat(reverse: true);
    // Randomly select 4 suggestions from the larger list
    _selectRandomSuggestions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _selectRandomSuggestions() {
    final random = Random();
    final shuffled = List<String>.from(_allSuggestions)..shuffle(random);
    _suggestions = shuffled.take(4).toList();

    // Initialize usage tracking
    _suggestionsUsed.clear();
    for (int i = 0; i < _suggestions.length; i++) {
      _suggestionsUsed.add(false);
    }
  }

  Future<void> _generateGoals() async {
    setState(() => _loading = true);
    final gemini = GeminiService();
    final goals = await gemini.generateGoals(_controller.text);
    Provider.of<AppState>(context, listen: false).setGoals(goals);
    setState(() => _loading = false);
    Navigator.pushReplacementNamed(context, '/map');
  }

  void _addSuggestion(int index) {
    final currentText = _controller.text;
    final newText = currentText.isEmpty
        ? _suggestions[index]
        : '$currentText, ${_suggestions[index]}';
    _controller.text = newText;

    // Find a new suggestion not currently shown
    final Set<String> currentSet = _suggestions.toSet();
    final List<String> unused = _allSuggestions
        .where((s) => !currentSet.contains(s))
        .toList();
    if (unused.isNotEmpty) {
      unused.shuffle();
      setState(() {
        _suggestions[index] = unused.first;
      });
    } else {
      // If all suggestions are used, just keep the current one (or optionally blank it)
      setState(() {
        // Optionally: _suggestions[index] = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E6D3), // Light tan background
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/gecko_normal.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Logo at top
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 20),
                  child: Image.asset(
                    'assets/images/geko.png',
                    height: 140, // Increased size
                    fit: BoxFit.contain,
                  ),
                ),

                // Spacer to center content vertically
                const Spacer(),

                // Title and circles section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      // Title text
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'where do you want to explore?',
                          style: TextStyle(
                            fontFamily: 'Cursive',
                            fontSize: 44,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3B4C62), // Dark blue
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(
                        height: 40,
                      ), // Space between title and circles
                      // 4 circles in a horizontal row - closer together
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          if (index >= _suggestions.length ||
                              _suggestionsUsed[index]) {
                            return Container(
                              width: 150,
                              height: 100,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                            ); // Empty space with margin
                          }

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                // Smooth continuous in and out (slower, not offset by index)
                                final pulseScale =
                                    1.0 +
                                    (sin(_pulseController.value * 2 * pi) *
                                        0.13);
                                return Transform.scale(
                                  scale: pulseScale,
                                  child: GestureDetector(
                                    onTap: () => _addSuggestion(index),
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF3B4C62,
                                        ), // Dark blue
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Text(
                                            _suggestions[index],
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              fontFamily: 'Cursive',
                                              height: 1.2,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                // Spacer to center content vertically
                const Spacer(),

                // Text input at bottom
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 16, fontFamily: 'Cursive'),
                    decoration: InputDecoration(
                      hintText:
                          'click the suggestion circles or type your own goals...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontFamily: 'Cursive',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Generate button
                _loading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFC3562D),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _controller.text.trim().isNotEmpty
                            ? _generateGoals
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC3562D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          'start the adventure!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cursive',
                          ),
                        ),
                      ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
