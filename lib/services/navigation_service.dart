import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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

  bool _announced200m = false;
  bool _announced50m  = false;
  bool _announced10m  = false;
  bool _ledActive     = false;

  // Guard para evitar avanzar pasos múltiples veces con el mismo fix GPS
  bool _advancing = false;

  StreamSubscription<Position>? _positionSubscription;
  final StreamController<NavigationStep> _stepController =
      StreamController<NavigationStep>.broadcast();
  final StreamController<double> _distanceController =
      StreamController<double>.broadcast();

  Stream<NavigationStep> get onStepChanged => _stepController.stream;
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
    _advancing = false;
    _resetStepFlags();

    WakelockPlus.enable(); // pantalla siempre encendida durante navegación

    await voiceService.init();
    await voiceService.speak('Iniciando navegación. ${steps.first.instruction}');

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2, // más frecuente para mayor precisión
      ),
    ).listen(_onPositionUpdate);
  }

  Future<void> stopNavigation() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    state = NavigationState.idle;
    _steps = [];
    _currentStepIndex = 0;
    _advancing = false;
    WakelockPlus.disable(); // la pantalla vuelve a comportarse normal
    if (_ledActive) {
      await bluetoothService.sendCommand('STOP');
      _ledActive = false;
    }
  }

  void _onPositionUpdate(Position position) {
    if (state != NavigationState.navigating || _steps.isEmpty) return;
    if (_advancing) return; // evita procesar mientras se avanza de paso

    final step = _steps[_currentStepIndex];
    final current = LatLng(position.latitude, position.longitude);
    final distanceToEnd = _distanceBetween(current, step.endLocation);

    _distanceController.add(distanceToEnd);

    // Solo anunciar 200m si el paso es lo suficientemente largo
    if (!_announced200m && distanceToEnd <= 200 && step.distanceMeters > 180) {
      _announced200m = true;
      voiceService.announceAt200m(step.instruction);
    }

    if (!_announced50m && distanceToEnd <= 50) {
      _announced50m = true;
      voiceService.announceAt50m(step.instruction);
      bluetoothService.sendCommand(step.bluetoothCommand);
      _ledActive = true;
    }

    if (!_announced10m && distanceToEnd <= 10) {
      _announced10m = true;
      voiceService.announceNow(step.instruction);
    }

    // Umbral de completado aumentado a 25m para absorber error GPS
    // El guard _advancing evita llamadas múltiples
    if (distanceToEnd <= 25 && !_advancing) {
      _advanceToNextStep();
    }
  }

  Future<void> _advanceToNextStep() async {
    _advancing = true;

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

    if (nextStep.maneuver == ManeuverType.arrive) {
      await _onArrival();
      return;
    }

    // Pequeña pausa antes de liberar el guard para que el GPS
    // se estabilice en la nueva posición tras el giro
    await Future.delayed(const Duration(seconds: 3));
    _advancing = false;
  }

  Future<void> _onArrival() async {
    state = NavigationState.arrived;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    WakelockPlus.disable();
    await bluetoothService.sendCommand('ARRIVE');
    await voiceService.announceArrival();
  }

  void _resetStepFlags() {
    _announced200m = false;
    _announced50m  = false;
    _announced10m  = false;
  }

  double _distanceBetween(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude, a.longitude,
      b.latitude, b.longitude,
    );
  }

  void dispose() {
    _positionSubscription?.cancel();
    _stepController.close();
    _distanceController.close();
  }
}
