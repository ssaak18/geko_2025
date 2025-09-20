import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(latitude, longitude),
        zoom: 12,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      markers: activities
          .map((a) => Marker(
                markerId: MarkerId(a.id),
                position: LatLng(a.lat, a.lng),
                infoWindow: InfoWindow(
                  title: a.title,
                  snippet: 'Tap to complete this activity',
                  onTap: () => onActivityTap(a),
                ),
              ))
          .toSet(),
    );
  }
}
