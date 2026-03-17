import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/navigation_step.dart';

class MapsService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  final String apiKey;

  MapsService({required this.apiKey});

  Future<List<NavigationStep>> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'bicycling',
      'language': 'es',
      'key': apiKey,
    });

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Error al obtener ruta: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String;

    if (status != 'OK') {
      throw Exception('Google Directions API error: $status');
    }

    final legs = data['routes'][0]['legs'][0];
    final stepsJson = legs['steps'] as List<dynamic>;

    final steps = stepsJson
        .map((s) => NavigationStep.fromJson(s as Map<String, dynamic>))
        .toList();

    // Añadir paso de llegada
    final lastStep = steps.last;
    steps.add(NavigationStep(
      instruction: 'Has llegado a tu destino',
      distanceMeters: 0,
      startLocation: lastStep.endLocation,
      endLocation: lastStep.endLocation,
      maneuver: ManeuverType.arrive,
    ));

    return steps;
  }

  /// Decodifica una polyline encoded de Google Maps en lista de LatLng
  List<LatLng> decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  /// Devuelve la polyline encoded de la ruta completa
  Future<String> getRoutePolyline({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'bicycling',
      'language': 'es',
      'key': apiKey,
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Error al obtener polyline: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['routes'][0]['overview_polyline']['points'] as String;
  }
}
