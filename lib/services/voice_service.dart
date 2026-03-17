import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _tts.stop();
  }

  // Anuncios predefinidos según distancia
  Future<void> announceAt200m(String instruction) async {
    await speak('En 200 metros, $instruction');
  }

  Future<void> announceAt50m(String instruction) async {
    await speak('En 50 metros, $instruction');
  }

  Future<void> announceNow(String instruction) async {
    await speak('Ahora, $instruction');
  }

  Future<void> announceArrival() async {
    await speak('Has llegado a tu destino');
  }
}
