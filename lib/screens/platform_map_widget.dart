import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

// Conditional imports
import 'map_widget_mobile.dart' if (dart.library.html) 'map_widget_web.dart';

class PlatformMapWidget extends StatelessWidget {
  final double latitude;
  final double longitude;
  final List activities;
  final Function onActivityTap;

  const PlatformMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.activities,
    required this.onActivityTap,
  });

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      latitude: latitude,
      longitude: longitude,
      activities: activities,
      onActivityTap: onActivityTap,
    );
  }
}
