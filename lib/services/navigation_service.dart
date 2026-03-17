import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/navigation_step.dart';
import 'bluetooth_service.dart';
import 'voice_service.dart';

enum NavigationState { idle, navigating, arrived }

class NavigationService {
  final BluetoothService bluetoothService;
  final VoiceService voiceService;

  NavigationState state = NavigationState.idle;

  List<NavigationStep> _steps = [];
  int _currentStepIndex = 0;

  // Flags para evitar anuncios repetidos por umbral
  bool _announced200m = false;
  bool _announced50m = false;
  bool _announced10m = false;
  bool _ledActive = false;

  StreamSubscription<Position>? _positionSubscription;
  final StreamController<NavigationStep> _stepController =
      StreamController<NavigationStep>.broadcast();
  final StreamController<double> _distanceController =
      StreamController<double>.broadcast();

  /// Stream que emite el paso actual cuando cambia
  Stream<NavigationStep> get onStepChanged => _stepController.stream;

  /// Stream que emite la distancia al siguiente paso en metros
  Stream<double> get onDistanceUpdate => _distanceController.stream;

  NavigationStep? get currentStep =>
      _steps.isEmpty ? null : _steps[_currentStepIndex];

  NavigationService({
    required this.bluetoothService,
    required this.voiceService,
  });

  Future<void> startNavigation(List<NavigationStep> steps) async {
    await stopNavigation();

    _steps = steps;
    _currentStepIndex = 0;
    state = NavigationState.navigating;
    _resetStepFlags();

    await voiceService.init();
    await voiceService.speak(
        'Iniciando navegación. ${steps.first.instruction}');

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // actualiza cada 5 metros
      ),
    ).listen(_onPositionUpdate);
  }

  Future<void> stopNavigation() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    state = NavigationState.idle;
    _steps = [];
    _currentStepIndex = 0;
    if (_ledActive) {
      await bluetoothService.sendCommand('STOP');
      _ledActive = false;
    }
  }

  void _onPositionUpdate(Position position) {
    if (state != NavigationState.navigating || _steps.isEmpty) return;

    final step = _steps[_currentStepIndex];
    final current = LatLng(position.latitude, position.longitude);
    final distanceToEnd = _distanceBetween(current, step.endLocation);

    _distanceController.add(distanceToEnd);

    // Lógica de anuncios por distancia
    if (!_announced200m && distanceToEnd <= 200) {
      _announced200m = true;
      voiceService.announceAt200m(step.instruction);
    }

    if (!_announced50m && distanceToEnd <= 50) {
      _announced50m = true;
      voiceService.announceAt50m(step.instruction);
      // Activar LED en el ESP32
      bluetoothService.sendCommand(step.bluetoothCommand);
      _ledActive = true;
    }

    if (!_announced10m && distanceToEnd <= 10) {
      _announced10m = true;
      voiceService.announceNow(step.instruction);
    }

    // Detectar que el giro fue completado (llegamos al punto final del paso)
    if (distanceToEnd <= 15) {
      _advanceToNextStep();
    }
  }

  Future<void> _advanceToNextStep() async {
    // Apagar LED al completar el giro
    if (_ledActive) {
      await bluetoothService.sendCommand('STOP');
      _ledActive = false;
    }

    _currentStepIndex++;

    if (_currentStepIndex >= _steps.length) {
      await _onArrival();
      return;
    }

    final nextStep = _steps[_currentStepIndex];
    _resetStepFlags();
    _stepController.add(nextStep);

    // Si el siguiente paso es llegada, manejarlo directamente
    if (nextStep.maneuver == ManeuverType.arrive) {
      await _onArrival();
    }
  }

  Future<void> _onArrival() async {
    state = NavigationState.arrived;
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    // Ambos LEDs parpadean
    await bluetoothService.sendCommand('STOP');
    await voiceService.announceArrival();
  }

  void _resetStepFlags() {
    _announced200m = false;
    _announced50m = false;
    _announced10m = false;
  }

  /// Calcula distancia en metros entre dos LatLng usando Geolocator
  double _distanceBetween(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  void dispose() {
    _positionSubscription?.cancel();
    _stepController.close();
    _distanceController.close();
  }
}
