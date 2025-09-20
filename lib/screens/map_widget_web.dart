import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../state/app_state.dart';
import '../services/gemini_service.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:latlong2/latlong.dart' as latlng;
import '../models/activity.dart';
import 'package:flutter_map/flutter_map.dart';

class MapWidget extends StatefulWidget {
  final double latitude;
  final double longitude;
  final List activities;
  final Function onActivityTap;

  const MapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.activities,
    required this.onActivityTap,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  // Hardcoded badge categories and tiers
  final List<Map<String, dynamic>> badgeCategories = [
    {
      'name': 'Cafe Explorer',
      'icon': Icons.local_cafe,
      'tiers': [
        {'tier': 'Bronze', 'count': 10},
        {'tier': 'Silver', 'count': 50},
        {'tier': 'Gold', 'count': 100},
        {'tier': 'Platinum', 'count': 250},
      ],
    },
    {
      'name': 'Park Adventurer',
      'icon': Icons.park,
      'tiers': [
        {'tier': 'Bronze', 'count': 5},
        {'tier': 'Silver', 'count': 25},
        {'tier': 'Gold', 'count': 75},
        {'tier': 'Platinum', 'count': 200},
      ],
    },
    {
      'name': 'Museum Enthusiast',
      'icon': Icons.museum,
      'tiers': [
        {'tier': 'Bronze', 'count': 3},
        {'tier': 'Silver', 'count': 10},
        {'tier': 'Gold', 'count': 30},
        {'tier': 'Platinum', 'count': 100},
      ],
    },
    {
      'name': 'Restaurant Critic',
      'icon': Icons.restaurant,
      'tiers': [
        {'tier': 'Bronze', 'count': 10},
        {'tier': 'Silver', 'count': 50},
        {'tier': 'Gold', 'count': 150},
        {'tier': 'Platinum', 'count': 300},
      ],
    },
    {
      'name': 'Trailblazer',
      'icon': Icons.directions_walk,
      'tiers': [
        {'tier': 'Bronze', 'count': 5},
        {'tier': 'Silver', 'count': 20},
        {'tier': 'Gold', 'count': 50},
        {'tier': 'Platinum', 'count': 150},
      ],
    },
    {
      'name': 'Library Scholar',
      'icon': Icons.local_library,
      'tiers': [
        {'tier': 'Bronze', 'count': 2},
        {'tier': 'Silver', 'count': 8},
        {'tier': 'Gold', 'count': 20},
        {'tier': 'Platinum', 'count': 50},
      ],
    },
    {
      'name': 'Beachcomber',
      'icon': Icons.beach_access,
      'tiers': [
        {'tier': 'Bronze', 'count': 3},
        {'tier': 'Silver', 'count': 12},
        {'tier': 'Gold', 'count': 30},
        {'tier': 'Platinum', 'count': 80},
      ],
    },
    {
      'name': 'Fitness Fanatic',
      'icon': Icons.fitness_center,
      'tiers': [
        {'tier': 'Bronze', 'count': 10},
        {'tier': 'Silver', 'count': 40},
        {'tier': 'Gold', 'count': 100},
        {'tier': 'Platinum', 'count': 250},
      ],
    },
    {
      'name': 'Art Lover',
      'icon': Icons.brush,
      'tiers': [
        {'tier': 'Bronze', 'count': 5},
        {'tier': 'Silver', 'count': 20},
        {'tier': 'Gold', 'count': 60},
        {'tier': 'Platinum', 'count': 150},
      ],
    },
    {
      'name': 'Historic Site Seeker',
      'icon': Icons.account_balance,
      'tiers': [
        {'tier': 'Bronze', 'count': 2},
        {'tier': 'Silver', 'count': 10},
        {'tier': 'Gold', 'count': 25},
        {'tier': 'Platinum', 'count': 60},
      ],
    },
    {
      'name': 'Hiking Hero',
      'icon': Icons.terrain,
      'tiers': [
        {'tier': 'Bronze', 'count': 5},
        {'tier': 'Silver', 'count': 20},
        {'tier': 'Gold', 'count': 50},
        {'tier': 'Platinum', 'count': 120},
      ],
    },
    {
      'name': 'Biking Buff',
      'icon': Icons.directions_bike,
      'tiers': [
        {'tier': 'Bronze', 'count': 10},
        {'tier': 'Silver', 'count': 40},
        {'tier': 'Gold', 'count': 100},
        {'tier': 'Platinum', 'count': 200},
      ],
    },
    {
      'name': 'Running Rookie',
      'icon': Icons.directions_run,
      'tiers': [
        {'tier': 'Bronze', 'count': 10},
        {'tier': 'Silver', 'count': 50},
        {'tier': 'Gold', 'count': 150},
        {'tier': 'Platinum', 'count': 300},
      ],
    },
    {
      'name': 'Climbing Champ',
      'icon': Icons.filter_hdr,
      'tiers': [
        {'tier': 'Bronze', 'count': 3},
        {'tier': 'Silver', 'count': 15},
        {'tier': 'Gold', 'count': 40},
        {'tier': 'Platinum', 'count': 100},
      ],
    },
    {
      'name': 'Swimming Star',
      'icon': Icons.pool,
      'tiers': [
        {'tier': 'Bronze', 'count': 5},
        {'tier': 'Silver', 'count': 20},
        {'tier': 'Gold', 'count': 60},
        {'tier': 'Platinum', 'count': 150},
      ],
    },
    {
      'name': 'Shopping Specialist',
      'icon': Icons.shopping_cart,
      'tiers': [
        {'tier': 'Bronze', 'count': 10},
        {'tier': 'Silver', 'count': 40},
        {'tier': 'Gold', 'count': 100},
        {'tier': 'Platinum', 'count': 250},
      ],
    },
    {
      'name': 'Cinema Fan',
      'icon': Icons.movie,
      'tiers': [
        {'tier': 'Bronze', 'count': 3},
        {'tier': 'Silver', 'count': 12},
        {'tier': 'Gold', 'count': 30},
        {'tier': 'Platinum', 'count': 80},
      ],
    },
    {
      'name': 'Zoo Visitor',
      'icon': Icons.pets,
      'tiers': [
        {'tier': 'Bronze', 'count': 2},
        {'tier': 'Silver', 'count': 8},
        {'tier': 'Gold', 'count': 20},
        {'tier': 'Platinum', 'count': 50},
      ],
    },
    {
      'name': 'Playground Pro',
      'icon': Icons.child_care,
      'tiers': [
        {'tier': 'Bronze', 'count': 5},
        {'tier': 'Silver', 'count': 20},
        {'tier': 'Gold', 'count': 60},
        {'tier': 'Platinum', 'count': 150},
      ],
    },
  ];
  final PopupController _popupController = PopupController();
  bool _userPopupVisible = false;

  @override
  Widget build(BuildContext context) {
    final activityMarkers = widget.activities
        .map<Marker>(
          (a) => Marker(
            point: latlng.LatLng(a.lat, a.lng),
            width: 40,
            height: 40,
            child: Icon(Icons.location_on, color: Colors.red, size: 40),
          ),
        )
        .toList();

    final userMarker = Marker(
      key: const ValueKey('user_marker'),
      point: latlng.LatLng(widget.latitude, widget.longitude),
      width: 44,
      height: 44,
      child: Icon(Icons.person_pin_circle, color: Colors.blue, size: 44),
    );

    final markers = <Marker>[userMarker, ...activityMarkers];

    return FlutterMap(
      options: MapOptions(
        center: latlng.LatLng(widget.latitude, widget.longitude),
        zoom: 12,
        interactiveFlags: InteractiveFlag.all,
        onTap: (_, __) => _popupController.hideAllPopups(),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
        ),
        PopupMarkerLayerWidget(
          options: PopupMarkerLayerOptions(
            markers: markers,
            popupController: _popupController,
            markerTapBehavior: MarkerTapBehavior.togglePopup(),
            popupDisplayOptions: PopupDisplayOptions(
              builder: (BuildContext context, Marker marker) {
                // Hide user popup state if any other popup is shown
                if (!(marker.point.latitude == widget.latitude &&
                    marker.point.longitude == widget.longitude)) {
                  if (_userPopupVisible) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _userPopupVisible = false;
                      });
                    });
                  }
                }
                // // If user marker, show gecko profile
                // if (marker.point.latitude == widget.latitude &&
                //     marker.point.longitude == widget.longitude) {
                //   final geckoImages = [
                //     'https://raw.githubusercontent.com/ssaak18/geko-assets/main/gecko1.png',
                //     'https://raw.githubusercontent.com/ssaak18/geko-assets/main/gecko2.png',
                //     'https://raw.githubusercontent.com/ssaak18/geko-assets/main/gecko3.png',
                //     'https://raw.githubusercontent.com/ssaak18/geko-assets/main/gecko4.png',
                //   ];
                //   final geckoUrl = (geckoImages..shuffle()).first;
                //   final screenSize = MediaQuery.of(context).size;
                //   final popupWidth = screenSize.width * 0.5;
                //   final popupHeight = screenSize.height * 0.25;
                //   final profileSize = popupHeight * 0.5;
                //   return Card(
                //     elevation: 8,
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(16),
                //     ),
                //     child: Container(
                //       width: popupWidth,
                //       height: popupHeight,
                //       padding: const EdgeInsets.all(16),
                //       child: Row(
                //         crossAxisAlignment: CrossAxisAlignment.start,
                //         children: [
                //           // Profile picture and name (top left, ~1/6 of popup)
                //           Column(
                //             crossAxisAlignment: CrossAxisAlignment.start,
                //             children: [
                //               ClipOval(
                //                 child: Image.network(
                //                   geckoUrl,
                //                   width: profileSize * 0.8,
                //                   height: profileSize * 0.8,
                //                   fit: BoxFit.cover,
                //                   errorBuilder: (context, error, stackTrace) =>
                //                       Icon(
                //                         Icons.pets,
                //                         size: profileSize * 0.8,
                //                         color: Colors.green,
                //                       ),
                //                 ),
                //               ),
                //               const SizedBox(height: 8),
                //               const Text(
                //                 'Silly Gecko',
                //                 style: TextStyle(
                //                   fontWeight: FontWeight.bold,
                //                   fontSize: 18,
                //                 ),
                //               ),
                //             ],
                //           ),
                //           const SizedBox(width: 24),
                //           // Rest of the popup (badges, etc.)
                //           Expanded(
                //             child: Column(
                //               crossAxisAlignment: CrossAxisAlignment.start,
                //               children: [
                //                 const Text(
                //                   'Your Profile1',
                //                   style: TextStyle(
                //                     fontWeight: FontWeight.bold,
                //                     fontSize: 22,
                //                   ),
                //                 ),
                //                 const SizedBox(height: 16),
                //                 // Badges grid
                //                 const Text(
                //                   'Achievements',
                //                   style: TextStyle(
                //                     fontWeight: FontWeight.bold,
                //                     fontSize: 18,
                //                   ),
                //                 ),
                //                 const SizedBox(height: 8),
                //                 SizedBox(
                //                   height: 80,
                //                   child: ListView.separated(
                //                     scrollDirection: Axis.horizontal,
                //                     itemCount: badgeCategories.length,
                //                     separatorBuilder: (_, __) =>
                //                         const SizedBox(width: 12),
                //                     itemBuilder: (context, idx) {
                //                       final cat = badgeCategories[idx];
                //                       // For demo, always show bronze badge as collected
                //                       final tier = cat['tiers'][0];
                //                       final color =
                //                           {
                //                             'Bronze': Colors.brown,
                //                             'Silver': Colors.grey,
                //                             'Gold': Colors.amber,
                //                             'Platinum': Colors.blueGrey,
                //                           }[tier['tier']] ??
                //                           Colors.black;
                //                       return Column(
                //                         children: [
                //                           Icon(
                //                             cat['icon'],
                //                             size: 32,
                //                             color: color,
                //                           ),
                //                           Text(
                //                             tier['tier'],
                //                             style: TextStyle(
                //                               fontWeight: FontWeight.bold,
                //                               color: color,
                //                             ),
                //                           ),
                //                           Text(
                //                             cat['name'],
                //                             style: const TextStyle(
                //                               fontSize: 10,
                //                             ),
                //                           ),
                //                         ],
                //                       );
                //                     },
                //                   ),
                //                 ),
                //               ],
                //             ),
                //           ),
                //         ],
                //       ),
                //     ),
                //   );
                // }
                // ...existing code for activity popups...
                Activity? activity;
                try {
                  activity = widget.activities.firstWhere(
                    (a) =>
                        a.lat == marker.point.latitude &&
                        a.lng == marker.point.longitude,
                  );
                } catch (e) {
                  activity = null;
                }
                if (activity == null) return const SizedBox.shrink();
                final appState = Provider.of<AppState>(context, listen: false);
                return Card(
                  margin: const EdgeInsets.only(bottom: 40),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Location: (${activity.lat.toStringAsFixed(4)}, ${activity.lng.toStringAsFixed(4)})',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Category: ${activity.category}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () async {
                            if (activity != null) {
                              appState.completeActivity(activity);
                              // Regenerate a new activity for this category
                              final gemini = GeminiService(
                                useGeminiLocationVerifier: true,
                                verificationConfidenceThreshold: double.tryParse(dotenv.env['GEMINI_VERIFIER_CONF_THRESHOLD'] ?? '') ?? 0.5,
                              );
                              final genres = appState.preferredGenres.isNotEmpty ? appState.preferredGenres : appState.goals.map((g) => g.title).toList();
                              final newActs = await gemini.suggestActivities(
                                activity.lat,
                                activity.lng,
                                genres,
                              );
                              // Find a new activity in the same category
                              final next = newActs.firstWhere(
                                (a) =>
                                    activity != null &&
                                    a.category == activity.category,
                                orElse: () => newActs.isNotEmpty
                                    ? newActs[0]
                                    : Activity(
                                        id: 'none',
                                        title: 'No activity found',
                                        lat: activity?.lat ?? 0.0,
                                        lng: activity?.lng ?? 0.0,
                                        goalId: '',
                                        category: activity?.category ?? 'Other',
                                      ),
                              );
                              if (next.id != 'none') {
                                appState.addActivity(next);
                              }
                              _popupController.hideAllPopups();
                            }
                          },
                          child: const Text('Complete'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
