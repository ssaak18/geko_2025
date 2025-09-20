import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Container(
      padding: const EdgeInsets.all(20),
      height: 300,
      child: Column(
        children: [
          const Text("Your Badges", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: appState.goals.length,
              itemBuilder: (_, i) {
                final g = appState.goals[i];
                return ListTile(
                  title: Text(g.title),
                  trailing: Text("⭐ ${g.progress}"),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
