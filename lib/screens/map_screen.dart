import 'dart:async';
import 'package:bluetooth_classic/models/device.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/navigation_step.dart';
import '../services/bluetooth_service.dart';
import '../services/maps_service.dart';
import '../services/navigation_service.dart';
import '../services/places_service.dart';
import '../services/voice_service.dart';
import '../config.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Servicios
  final _mapsService = MapsService(apiKey: googleMapsApiKey);
  final _placesService = PlacesService(apiKey: googleMapsApiKey);
  final _bluetoothService = BluetoothService();
  final _voiceService = VoiceService();
  late final NavigationService _navigationService;

  // Mapa
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  LatLng? _destination;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // Búsqueda
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<PlaceSuggestion> _suggestions = [];
  bool _searchActive = false;
  Timer? _debounce;

  // Estado UI
  bool _isLoading = false;
  String? _currentInstruction;
  double? _distanceToNext;
  NavigationState _navState = NavigationState.idle;

  // Señaleros manuales
  String? _activeTurn; // 'LEFT' | 'RIGHT' | null

  // Suscripciones
  StreamSubscription? _stepSub;
  StreamSubscription? _distSub;

  @override
  void initState() {
    super.initState();
    _navigationService = NavigationService(
      bluetoothService: _bluetoothService,
      voiceService: _voiceService,
    );
    _stepSub = _navigationService.onStepChanged.listen(_onStepChanged);
    _distSub = _navigationService.onDistanceUpdate.listen(_onDistanceUpdate);
    _searchController.addListener(_onSearchChanged);
    _initLocation();
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _distSub?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _navigationService.dispose();
    _voiceService.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Ubicación ──────────────────────────────────────────────

  Future<void> _initLocation() async {
    final permission = await _checkLocationPermission();
    if (!permission) return;
    final pos = await Geolocator.getCurrentPosition();
    setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition!, 16),
    );
  }

  Future<bool> _checkLocationPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      _showSnack('Permiso de ubicación denegado permanentemente');
      return false;
    }
    return perm != LocationPermission.denied;
  }

  // ── Búsqueda ───────────────────────────────────────────────

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await _placesService.autocomplete(
        query,
        bias: _currentPosition,
      );
      if (mounted) setState(() => _suggestions = results);
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _searchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _searchActive = false;
      _searchController.text = suggestion.mainText;
    });

    final location = await _placesService.getPlaceLocation(suggestion.placeId);
    if (location == null) {
      _showSnack('No se pudo obtener la ubicación');
      return;
    }
    _setDestination(location, label: suggestion.mainText);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 15));
  }

  void _setDestination(LatLng position, {String label = 'Destino'}) {
    setState(() {
      _destination = position;
      _markers = {
        Marker(
          markerId: const MarkerId('destination'),
          position: position,
          infoWindow: InfoWindow(title: label),
        ),
      };
      _polylines = {};
      _currentInstruction = null;
      _distanceToNext = null;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _searchActive = false;
    });
  }

  // ── Mapa events ────────────────────────────────────────────

  void _onMapTap(LatLng position) {
    if (_navState == NavigationState.navigating) return;
    if (_searchActive) {
      _clearSearch();
      return;
    }
    _setDestination(position);
  }

  // ── Navegación ─────────────────────────────────────────────

  Future<void> _startNavigation() async {
    if (_currentPosition == null || _destination == null) {
      _showSnack('Elige un destino primero');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final steps = await _mapsService.getDirections(
        origin: _currentPosition!,
        destination: _destination!,
      );
      final encoded = await _mapsService.getRoutePolyline(
        origin: _currentPosition!,
        destination: _destination!,
      );
      final points = _mapsService.decodePolyline(encoded);

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: Colors.blue,
            width: 5,
          ),
        };
        _currentInstruction = steps.first.instruction;
        _navState = NavigationState.navigating;
      });
      _fitRoute(points);
      await _navigationService.startNavigation(steps);
    } catch (e) {
      _showSnack('Error al calcular ruta: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _stopNavigation() async {
    await _navigationService.stopNavigation();
    setState(() {
      _navState = NavigationState.idle;
      _polylines = {};
      _markers = {};
      _destination = null;
      _currentInstruction = null;
      _distanceToNext = null;
      _searchController.clear();
    });
  }

  void _onStepChanged(NavigationStep step) {
    setState(() {
      _currentInstruction = step.instruction;
      _navState = _navigationService.state;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(step.startLocation),
    );
  }

  void _onDistanceUpdate(double distance) {
    setState(() => _distanceToNext = distance);
  }

  // ── Señaleros manuales ─────────────────────────────────────

  Future<void> _toggleTurn(String side) async {
    if (_activeTurn == side) {
      // Apagar — el estado visual se resetea siempre
      setState(() => _activeTurn = null);
      await _bluetoothService.sendCommand('STOP');
    } else {
      setState(() => _activeTurn = side);
      await _bluetoothService.sendCommand(side);
    }
  }

  // ── Bluetooth ──────────────────────────────────────────────

  Future<void> _showBluetoothDialog() async {
    final devices = await _bluetoothService.getPairedDevices();
    if (!mounted) return;
    if (devices.isEmpty) {
      _showSnack('No hay dispositivos Bluetooth pareados');
      return;
    }
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar ESP32'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (_, i) {
              final device = devices[i];
              return ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(device.name ?? 'Desconocido'),
                subtitle: Text(device.address ?? ''),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _connectBluetooth(device.address ?? '');
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _connectBluetooth(String address) async {
    try {
      await _bluetoothService.connect(address);
      _showSnack('ESP32 conectado');
      setState(() {});
    } catch (e) {
      _showSnack('Error al conectar: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────

  void _fitRoute(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── UI ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? const LatLng(40.4168, -3.7038),
              zoom: 14,
            ),
            onMapCreated: (c) => _mapController = c,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            polylines: _polylines,
            markers: _markers,
            onTap: _onMapTap,
          ),

          // Barra de búsqueda (oculta durante navegación)
          if (_navState != NavigationState.navigating)
            Positioned(
              top: topPadding + 8,
              left: 12,
              right: 12,
              child: _SearchBar(
                controller: _searchController,
                focusNode: _searchFocus,
                onTap: () => setState(() => _searchActive = true),
                onClear: _clearSearch,
                suggestions: _suggestions,
                onSuggestionSelected: _selectSuggestion,
              ),
            ),

          // Panel de instrucción (durante navegación)
          if (_currentInstruction != null)
            Positioned(
              top: topPadding + 8,
              left: 12,
              right: 12,
              child: _InstructionCard(
                instruction: _currentInstruction!,
                distanceMeters: _distanceToNext,
                arrived: _navState == NavigationState.arrived,
              ),
            ),

          // Botones de señaleros manuales
          Positioned(
            bottom: 112,
            left: 0,
            right: 0,
            child: _TurnButtons(
              activeTurn: _activeTurn,
              enabled: _bluetoothService.isConnected,
              onToggle: _toggleTurn,
            ),
          ),

          // Controles inferiores
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: _BottomControls(
              isNavigating: _navState == NavigationState.navigating,
              isLoading: _isLoading,
              btConnected: _bluetoothService.isConnected,
              hasDestination: _destination != null,
              onStart: _startNavigation,
              onStop: _stopNavigation,
              onBluetooth: _showBluetoothDialog,
              onMyLocation: _initLocation,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────

class _TurnButtons extends StatelessWidget {
  final String? activeTurn;
  final bool enabled;
  final ValueChanged<String> onToggle;

  const _TurnButtons({
    required this.activeTurn,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _TurnButton(
            label: 'Izquierda',
            icon: Icons.turn_left,
            active: activeTurn == 'LEFT',
            enabled: enabled,
            onTap: () => onToggle('LEFT'),
          ),
          _TurnButton(
            label: 'Derecha',
            icon: Icons.turn_right,
            active: activeTurn == 'RIGHT',
            enabled: enabled,
            onTap: () => onToggle('RIGHT'),
          ),
        ],
      ),
    );
  }
}

class _TurnButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  const _TurnButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.amber : Colors.white;
    final iconColor = active ? Colors.black : Colors.grey.shade700;

    return GestureDetector(
      onTap: (enabled || active) ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: active
                  ? Colors.amber.withOpacity(0.6)
                  : Colors.black26,
              blurRadius: active ? 12 : 4,
              spreadRadius: active ? 2 : 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: enabled ? iconColor : Colors.grey.shade400),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: enabled ? iconColor : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final List<PlaceSuggestion> suggestions;
  final ValueChanged<PlaceSuggestion> onSuggestionSelected;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onTap,
    required this.onClear,
    required this.suggestions,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Campo de búsqueda
        Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(28),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onTap: onTap,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '¿A dónde vamos?',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: onClear,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ),

        // Lista de sugerencias
        if (suggestions.isNotEmpty)
          Material(
            elevation: 6,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: suggestions.length > 5 ? 5 : suggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 56),
              itemBuilder: (_, i) {
                final s = suggestions[i];
                return ListTile(
                  leading: const Icon(Icons.place, color: Colors.redAccent),
                  title: Text(s.mainText,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: s.secondaryText.isNotEmpty
                      ? Text(s.secondaryText,
                          style: TextStyle(color: Colors.grey.shade600))
                      : null,
                  onTap: () => onSuggestionSelected(s),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final String instruction;
  final double? distanceMeters;
  final bool arrived;

  const _InstructionCard({
    required this.instruction,
    this.distanceMeters,
    required this.arrived,
  });

  String get _distanceText {
    if (arrived || distanceMeters == null) return '';
    final d = distanceMeters!;
    return d >= 1000
        ? '${(d / 1000).toStringAsFixed(1)} km'
        : '${d.toInt()} m';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              arrived ? Icons.flag : Icons.navigation,
              color: arrived ? Colors.green : Colors.blue,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(instruction,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  if (_distanceText.isNotEmpty)
                    Text(_distanceText,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  final bool isNavigating;
  final bool isLoading;
  final bool btConnected;
  final bool hasDestination;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onBluetooth;
  final VoidCallback onMyLocation;

  const _BottomControls({
    required this.isNavigating,
    required this.isLoading,
    required this.btConnected,
    required this.hasDestination,
    required this.onStart,
    required this.onStop,
    required this.onBluetooth,
    required this.onMyLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FloatingActionButton(
          heroTag: 'bt',
          onPressed: onBluetooth,
          backgroundColor: btConnected ? Colors.green : Colors.grey,
          child: Icon(
              btConnected ? Icons.bluetooth_connected : Icons.bluetooth),
        ),
        const SizedBox(width: 12),
        FloatingActionButton(
          heroTag: 'loc',
          onPressed: onMyLocation,
          child: const Icon(Icons.my_location),
        ),
        const Spacer(),
        if (isLoading)
          const FloatingActionButton(
            heroTag: 'loading',
            onPressed: null,
            child: CircularProgressIndicator(color: Colors.white),
          )
        else if (isNavigating)
          FloatingActionButton.extended(
            heroTag: 'stop',
            onPressed: onStop,
            backgroundColor: Colors.red,
            icon: const Icon(Icons.stop),
            label: const Text('Detener'),
          )
        else
          FloatingActionButton.extended(
            heroTag: 'start',
            onPressed: hasDestination ? onStart : null,
            backgroundColor: hasDestination ? Colors.blue : Colors.grey,
            icon: const Icon(Icons.directions_bike),
            label: const Text('Navegar'),
          ),
      ],
    );
  }
}
