import 'package:flutter/material.dart';
import 'platform_map_widget.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/goal.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';
import 'profile_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  dynamic _userLocation;
  bool _loading = true;
  String _errorMessage = '';

  Future<void> _getLocation() async {
    final result = await LocationService.getCurrentLocation();

    if (result.isSuccess && result.location != null) {
      setState(() {
        _userLocation = result.location;
      });

      // Get activities from Gemini API
      final appState = Provider.of<AppState>(context, listen: false);
      final gemini = GeminiService();

      try {
        final activities = await gemini.suggestActivities(
          result.location!.latitude,
          result.location!.longitude,
          appState.goals,
        );
        appState.setActivities(activities);
      } catch (e) {
        print("Error getting activities: $e");
        // Continue without activities rather than failing completely
      }

      setState(() => _loading = false);
    } else {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Unknown location error';
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Getting your location...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Location Error")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _errorMessage = '';
                  });
                  _getLocation();
                },
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Only render the map if we have a valid location
    if (_userLocation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Location Error")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.orange),
              SizedBox(height: 16),
              Text('Unable to get your location'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _errorMessage = '';
                  });
                  _getLocation();
                },
                child: Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // appBar: AppBar(title: const Text("Explore Activities")),
      body: Stack(
        children: [
          // Map widget at the bottom
          PlatformMapWidget(
            key: ValueKey(
              appState.activities.map((a) => '${a.lat},${a.lng}').join(),
            ),
            latitude: _userLocation!.latitude,
            longitude: _userLocation!.longitude,
            activities: appState.activities,
            onActivityTap: (a) => appState.completeActivity(a),
          ),
          // Overlay gecko image above the map, but below all other UI
          IgnorePointer(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/gecko_normal.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // Goals and Profile buttons in the top left
          Positioned(
            top: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FloatingActionButton(
                  heroTag: "goals_btn",
                  child: const Icon(Icons.flag),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => Container(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Goals',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...appState.goals
                                .take(5)
                                .map(
                                  (g) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      '• ' + g.title,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "profile_btn",
                  child: const Icon(Icons.person),
                  onPressed: () {
                    // For web, show the same popup as the user marker
                    // This uses a dialog for simplicity
                    showDialog(
                      context: context,
                      builder: (context) {
                        final geckoImages = [
                          'https://raw.githubusercontent.com/ssaak18/geko-assets/main/gecko1.png',
                          'https://raw.githubusercontent.com/ssaak18/geko-assets/main/gecko2.png',
                          'https://raw.githubusercontent.com/ssaak18/geko-assets/main/gecko3.png',
                          'https://raw.githubusercontent.com/ssaak18/geko-assets/main/gecko4.png',
                        ];
                        geckoImages.shuffle();
                        final geckoUrl = geckoImages.first;
                        final screenSize = MediaQuery.of(context).size;
                        final popupWidth = screenSize.width * 0.5;
                        final popupHeight = screenSize.height * 0.25;
                        final profileSize = popupHeight * 0.5;
                        return Dialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            width: popupWidth,
                            height: popupHeight,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipOval(
                                      child: Image.network(
                                        geckoUrl,
                                        width: profileSize * 0.8,
                                        height: profileSize * 0.8,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(
                                                  Icons.pets,
                                                  size: profileSize * 0.8,
                                                  color: Colors.green,
                                                ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Silly Gecko',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Your Profile',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Achievements',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 80,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: 4,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(width: 12),
                                          itemBuilder: (context, idx) {
                                            final icons = [
                                              Icons.local_cafe,
                                              Icons.park,
                                              Icons.museum,
                                              Icons.restaurant,
                                            ];
                                            final names = [
                                              'Cafe Explorer',
                                              'Park Adventurer',
                                              'Museum Enthusiast',
                                              'Restaurant Critic',
                                            ];
                                            final colors = [
                                              Colors.brown,
                                              Colors.green,
                                              Colors.blueGrey,
                                              Colors.redAccent,
                                            ];
                                            return Column(
                                              children: [
                                                Icon(
                                                  icons[idx],
                                                  size: 32,
                                                  color: colors[idx],
                                                ),
                                                Text(
                                                  'Bronze',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: colors[idx],
                                                  ),
                                                ),
                                                Text(
                                                  names[idx],
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              heroTag: "regen_btn",
              icon: const Icon(Icons.refresh),
              label: const Text("Regenerate Activities"),
              onPressed: () async {
                final appState = Provider.of<AppState>(context, listen: false);
                final gemini = GeminiService();
                // Always use all goals for variety
                final nextActivities = await gemini.suggestActivities(
                  _userLocation!.latitude,
                  _userLocation!.longitude,
                  appState.goals,
                );
                setState(() {
                  // Replace activities with new results
                  appState.setActivities(nextActivities);
                });
              },
            ),
          ),
          // (Goals and Activities numbers removed)
        ],
      ),
    );
  }
}
