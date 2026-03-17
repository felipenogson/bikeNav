import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });
}

class PlacesService {
  final String apiKey;

  PlacesService({required this.apiKey});

  Future<List<PlaceSuggestion>> autocomplete(String input,
      {LatLng? bias}) async {
    if (input.trim().isEmpty) return [];

    final params = <String, String>{
      'input': input,
      'language': 'es',
      'key': apiKey,
    };

    if (bias != null) {
      params['location'] = '${bias.latitude},${bias.longitude}';
      params['radius'] = '50000'; // 50 km de radio preferente
    }

    final uri = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/autocomplete/json')
        .replace(queryParameters: params);

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final data = json.decode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return [];

    return (data['predictions'] as List).map((p) {
      final structured = p['structured_formatting'] as Map<String, dynamic>;
      return PlaceSuggestion(
        placeId: p['place_id'] as String,
        mainText: structured['main_text'] as String,
        secondaryText: (structured['secondary_text'] as String?) ?? '',
      );
    }).toList();
  }

  Future<LatLng?> getPlaceLocation(String placeId) async {
    final uri = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/details/json')
        .replace(queryParameters: {
      'place_id': placeId,
      'fields': 'geometry',
      'key': apiKey,
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) return null;

    final data = json.decode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final loc =
        data['result']['geometry']['location'] as Map<String, dynamic>;
    return LatLng(
      (loc['lat'] as num).toDouble(),
      (loc['lng'] as num).toDouble(),
    );
  }
}
