import 'package:google_maps_flutter/google_maps_flutter.dart';

enum ManeuverType { left, right, uTurn, straight, arrive }

class NavigationStep {
  final String instruction;
  final double distanceMeters;
  final LatLng startLocation;
  final LatLng endLocation;
  final ManeuverType maneuver;

  NavigationStep({
    required this.instruction,
    required this.distanceMeters,
    required this.startLocation,
    required this.endLocation,
    required this.maneuver,
  });

  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    final start = json['start_location'];
    final end = json['end_location'];
    final maneuverStr = (json['maneuver'] as String?) ?? '';

    return NavigationStep(
      instruction: _stripHtml(json['html_instructions'] as String),
      distanceMeters: (json['distance']['value'] as num).toDouble(),
      startLocation: LatLng(
        (start['lat'] as num).toDouble(),
        (start['lng'] as num).toDouble(),
      ),
      endLocation: LatLng(
        (end['lat'] as num).toDouble(),
        (end['lng'] as num).toDouble(),
      ),
      maneuver: _parseManeuver(maneuverStr),
    );
  }

  static ManeuverType _parseManeuver(String maneuver) {
    if (maneuver.contains('left')) return ManeuverType.left;
    if (maneuver.contains('right')) return ManeuverType.right;
    if (maneuver.contains('uturn') || maneuver.contains('u-turn')) {
      return ManeuverType.uTurn;
    }
    return ManeuverType.straight;
  }

  static String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
  }

  String get bluetoothCommand {
    switch (maneuver) {
      case ManeuverType.left:
        return 'LEFT';
      case ManeuverType.right:
        return 'RIGHT';
      case ManeuverType.uTurn:
        return 'UTURN';
      case ManeuverType.arrive:
        return 'STOP';
      case ManeuverType.straight:
        return 'STRAIGHT';
    }
  }
}
