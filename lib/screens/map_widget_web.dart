import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
  final PopupController _popupController = PopupController();

  @override
  Widget build(BuildContext context) {
    final markers = widget.activities
        .map<Marker>((a) => Marker(
              point: latlng.LatLng(a.lat, a.lng),
              width: 40,
              height: 40,
              child: Icon(Icons.location_on, color: Colors.red, size: 40),
            ))
        .toList();

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
                Activity? activity;
                try {
                  activity = widget.activities.firstWhere(
                    (a) => a.lat == marker.point.latitude && a.lng == marker.point.longitude,
                  );
                } catch (e) {
                  activity = null;
                }
                if (activity == null) return const SizedBox.shrink();
                return Card(
                  margin: const EdgeInsets.only(bottom: 40),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(activity.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Location: (${activity.lat.toStringAsFixed(4)}, ${activity.lng.toStringAsFixed(4)})'),
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
