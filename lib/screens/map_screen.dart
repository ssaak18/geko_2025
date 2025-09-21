import 'package:flutter/material.dart';
import 'platform_map_widget.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../state/app_state.dart';
import '../models/goal.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';
import 'profile_screen.dart';
import '../services/google_calendar_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  dynamic _userLocation;
  bool _loading = true;
  String _errorMessage = '';
  GoogleCalendarService _calendarService = GoogleCalendarService();
  List<Map<String, DateTime>>? _freeTimes;
  List activities = [];

  Future<void> _loadFreeTimesAndActivities() async {
    final token = await _calendarService.signInAndGetToken();
    if (token == null) {
      print("Google Sign-In failed or canceled.");
      return;
    }

    final now = DateTime.now();
    final weekLater = now.add(const Duration(days: 7));

    final busy = await _calendarService.fetchBusyTimes(token, now, weekLater);
    final free = _calendarService.computeFreeTimes(
      busy,
      now,
      now.add(const Duration(hours: 24)),
    );

    setState(() {
      _freeTimes = free;
    });

    if (_freeTimes != null && _freeTimes!.isNotEmpty && _userLocation != null) {
      final appState = Provider.of<AppState>(context, listen: false);
      final gemini = GeminiService(
        useGeminiLocationVerifier: true,
        verificationConfidenceThreshold: double.tryParse(
              dotenv.env['GEMINI_VERIFIER_CONF_THRESHOLD'] ?? '',
            ) ??
            0.5,
      );
      final nextActivities = await gemini.suggestActivities(
        _userLocation!.latitude,
        _userLocation!.longitude,
        appState.preferredGenres.isNotEmpty
            ? appState.preferredGenres
            : appState.goals.map((g) => g.title).toList(),
      );
      setState(() {
        activities = nextActivities;
      });
    }

    // Debug print
    print("Free time slots:");
    if (_freeTimes != null && _freeTimes!.isNotEmpty) {
      for (var slot in _freeTimes!) {
        print(
            "- From ${slot['start']?.toLocal()} to ${slot['end']?.toLocal()}");
      }
    } else {
      print("No free time slots found.");
    }
  }

  Future<void> _getLocation() async {
    final result = await LocationService.getCurrentLocation();

    if (result.isSuccess && result.location != null) {
      setState(() {
        _userLocation = result.location;
      });

      setState(() => _loading = false);

      // Now load free times after we have location
      _loadFreeTimesAndActivities();
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

  List<Widget> _buildActivitiesSidebar(AppState appState) {
    if (activities.isEmpty) return [const Text("No activities available")];

    List<Widget> widgets = [];

    for (var activity in activities) {
      final capitalizedTitle = activity.title.isNotEmpty
          ? activity.title[0].toUpperCase() + activity.title.substring(1)
          : activity.title;

      widgets.add(Card(
        child: ListTile(
          title: Text(capitalizedTitle),
          subtitle: Text(activity.category),
          onTap: () {
            // Optionally center map on activity
          },
        ),
      ));
    }

    return widgets;
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
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _errorMessage = '';
                  });
                  _getLocation();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_userLocation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Location Error")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('Unable to get your location'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _errorMessage = '';
                  });
                  _getLocation();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      endDrawer: Drawer(
        child: _freeTimes == null
            ? const Center(child: Text("Loading free times..."))
            : ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      "In Your Free Time...",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ..._buildActivitiesSidebar(appState),
                ],
              ),
      ),
      body: Stack(
        children: [
          PlatformMapWidget(
            key: ValueKey(
              appState.activities.map((a) => '${a.lat},${a.lng}').join(),
            ),
            latitude: _userLocation!.latitude,
            longitude: _userLocation!.longitude,
            activities: appState.activities,
            onActivityTap: (a) => appState.completeActivity(a),
          ),
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
          // Drawer button in top-right
          Positioned(
            top: 20,
            right: 20,
            child: Builder(
              builder: (context) => FloatingActionButton(
                heroTag: "drawer_btn",
                child: const Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              ),
            ),
          ),
          // Goals and Profile buttons in top-left
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
                            ...List.generate(appState.goals.length.clamp(0, 5), (i) {
                              final g = appState.goals[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  '• ' + g.title,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              );
                            }),
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
                                          itemCount: 8,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(width: 12),
                                          itemBuilder: (context, idx) {
                                            final icons = [
                                              Icons.fastfood,
                                              Icons.museum,
                                              Icons.energy_savings_leaf,
                                              Icons.toys,
                                              Icons.pest_control,
                                              Icons.music_note,
                                              Icons.local_florist,
                                              Icons.book,
                                              Icons.fitness_center
                                            ];
                                            final categories = [
                                              'cooking',
                                              'museum',
                                              'thrift store',
                                              'playground',
                                              'zoo',
                                              'music store'
                                              'garden',
                                              'bookstore',
                                              'gym',
                                            ];
                                            final names = ["Food Connoisseur", "Science Enthsusiast", "Eco Warrior", "Family Fun", "Animal Lover", "Music Aficionado", "Plant Parent", "Bookworm", "Fitness Fanatic"];
                                            final colors = [
                                              const Color.fromARGB(255, 209, 163, 65),
                                              const Color.fromARGB(255, 142, 189, 76),
                                              const Color.fromARGB(255, 118, 167, 119),
                                              const Color.fromARGB(255, 62, 160, 119),
                                              const Color.fromARGB(255, 91, 153, 185),
                                              const Color.fromARGB(255, 55, 97, 177),
                                              const Color.fromARGB(255, 127, 107, 184),
                                              const Color.fromARGB(255, 245, 130, 213),
                                              const Color.fromARGB(255, 201, 87, 129)
                                            ];
                                            return Column(
                                              children: [
                                                Icon(
                                                  icons[idx],
                                                  size: 32,
                                                  color: colors[idx],
                                                ),
                                                Text(
                                                  'Level ' + appState.getBadgeProgress(categories[idx]).toString(),
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
                final gemini = GeminiService(
                  useGeminiLocationVerifier: true,
                  verificationConfidenceThreshold: double.tryParse(
                        dotenv.env['GEMINI_VERIFIER_CONF_THRESHOLD'] ?? '',
                      ) ??
                      0.5,
                );
                final nextActivities = await gemini.suggestActivities(
                  _userLocation!.latitude,
                  _userLocation!.longitude,
                  appState.preferredGenres.isNotEmpty
                      ? appState.preferredGenres
                      : appState.goals.map((g) => g.title).toList(),
                );
                setState(() {
                  appState.setActivities(nextActivities);
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
