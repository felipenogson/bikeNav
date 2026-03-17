Quiero construir una app Flutter llamada BikeNav. Es un sistema de navegación
para bicicleta que integra Google Maps Directions API, Text-to-Speech en español,
y comunicación Bluetooth con un ESP32 que controla direccionales LED físicos.

## Estructura esperada

lib/
├── main.dart
├── services/
│ ├── maps_service.dart
│ ├── bluetooth_service.dart
│ ├── navigation_service.dart
│ └── voice_service.dart
├── models/
│ └── navigation_step.dart
└── screens/
└── map_screen.dart

## Lógica de navegación

- A 200m del giro: anuncia por voz
- A 50m: anuncia por voz + activa LED vía Bluetooth
- A 10m: "Ahora, gira a la..."
- Al completar giro: apaga LED, anuncia siguiente paso
- Al llegar: ambos LEDs parpadean + "Has llegado a tu destino"

## Comandos Bluetooth al ESP32

LEFT / RIGHT / UTURN / STRAIGHT / STOP

## pubspec.yaml dependencies

- google_maps_flutter
- flutter_polyline_points
- flutter_bluetooth_serial
- geolocator
- flutter_tts
- http

Crea el proyecto completo archivo por archivo empezando por pubspec.yaml,
luego cada archivo en lib/. Después de cada archivo pregúntame si continuar.
