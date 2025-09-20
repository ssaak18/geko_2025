import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/gemini_service.dart';
import '../state/app_state.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;

  Future<void> _generateGoals() async {
    setState(() => _loading = true);
    final gemini = GeminiService();
    final goals = await gemini.generateGoals(_controller.text);
    Provider.of<AppState>(context, listen: false).setGoals(goals);
    setState(() => _loading = false);
    Navigator.pushReplacementNamed(context, '/map');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Your Goals")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("What are your goals in life?"),
            TextField(controller: _controller, maxLines: 4),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _generateGoals,
                    child: const Text("Generate Life Goals"),
                  ),
          ],
        ),
      ),
    );
  }
}
