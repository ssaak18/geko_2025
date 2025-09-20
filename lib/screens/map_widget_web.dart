import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:flutter_map/flutter_map.dart';

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
    return FlutterMap(
      options: MapOptions(
        center: latlng.LatLng(latitude, longitude),
        zoom: 12,
        interactiveFlags: InteractiveFlag.all, // Enable all gestures (scroll, zoom, rotate)
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
        ),
        MarkerLayer(
          markers: activities
              .map<Marker>((a) => Marker(
                    point: latlng.LatLng(a.lat, a.lng),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => onActivityTap(a),
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
