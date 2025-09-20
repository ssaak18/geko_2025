import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';
import 'profile_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;
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
      appBar: AppBar(title: const Text("Explore Activities")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userLocation!,
              zoom: 12,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: appState.activities
                .map((a) => Marker(
                      markerId: MarkerId(a.id),
                      position: LatLng(a.lat, a.lng),
                      infoWindow: InfoWindow(
                        title: a.title,
                        snippet: 'Tap to complete this activity',
                        onTap: () => appState.completeActivity(a),
                      ),
                    ))
                .toSet(),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton(
              heroTag: "profile_btn",
              child: const Icon(Icons.person),
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => const ProfileScreen(),
              ),
            ),
          ),
          // Show goals count
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag, color: Colors.blue, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '${appState.goals.length} Goals',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          // Show activities count
          Positioned(
            bottom: 80,
            left: 20,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_activity, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '${appState.activities.length} Activities',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}