# 🚴 BikeNav

> Sistema de navegación inteligente para bicicleta con instrucciones por voz, mapas en tiempo real y direccionales LED físicos controlados por Bluetooth.

---

## ✨ ¿Qué hace?

BikeNav convierte tu teléfono en un navegador GPS pensado para ciclistas, conectado a un ESP32 que controla señales LED físicas en tu bici.

| Función | Descripción |
|---|---|
| 🗺️ **Navegación GPS** | Rutas en modo ciclista via Google Maps |
| 🔍 **Búsqueda de lugares** | Autocompletado estilo Google Maps |
| 🔊 **Voz en español** | Instrucciones habladas a 200m, 50m y al girar |
| 💡 **Direccionales LED** | Señales físicas en la bici vía Bluetooth |
| 📱 **Control manual** | Botones de izquierda/derecha en la app |
| 🏁 **Llegada** | Ambos LEDs parpadean + anuncio de voz |

---

## 📱 App Flutter

### 🧭 Lógica de navegación

```
📍 A 200m del giro  →  🔊 Anuncia por voz
📍 A  50m del giro  →  🔊 Voz + 💡 LED activo vía BT
📍 A  10m del giro  →  🔊 "Ahora, gira a la..."
✅ Giro completado   →  💡 LED apagado + siguiente paso
🏁 Destino llegado  →  💡💡 Ambos LEDs parpadean + voz
```

---

## 🔧 Hardware — ESP32

### 📦 Componentes necesarios

| Componente | Cantidad |
|---|---|
| ESP32 Dev Module | 1 |
| LED (cualquier color) | 2 |
| Resistencia 220Ω | 2 |
| Buzzer pasivo *(opcional)* | 1 |
| Cables dupont | varios |

### 🔌 Conexiones

```
ESP32 GPIO 25  ──►  220Ω  ──►  LED izquierdo (+)  ──►  GND
ESP32 GPIO 26  ──►  220Ω  ──►  LED derecho  (+)  ──►  GND
ESP32 GPIO  2  ──►  LED integrado (diagnóstico, ya incluido)
```

### 📡 Comandos Bluetooth

| Comando | Acción en el ESP32 |
|---|---|
| `LEFT` | 💛 Parpadea LED izquierdo (400ms) |
| `RIGHT` | 💛 Parpadea LED derecho (400ms) |
| `UTURN` | 💛💛 Ambos alternan rápido (200ms) |
| `STRAIGHT` | ⚡ Destello doble y apaga |
| `STOP` | 🔴 Apaga todos los LEDs |
| `ARRIVE` | 🎉 Ambos parpadean juntos (500ms) |

---

## 🚀 Instalación

### 1️⃣ Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/bikeNav.git
cd bikeNav
```

### 2️⃣ Configurar API Key

Copia el archivo de ejemplo y pon tu clave de Google Maps:

```bash
cp lib/config.dart.example lib/config.dart
```

Edita `lib/config.dart`:
```dart
const String googleMapsApiKey = 'TU_API_KEY_AQUI';
```

Edita `android/local.properties` y agrega:
```
GOOGLE_MAPS_API_KEY=TU_API_KEY_AQUI
```

> 💡 Necesitas habilitar **Maps SDK for Android**, **Directions API** y **Places API** en Google Cloud Console.

### 3️⃣ Instalar dependencias

```bash
flutter pub get
```

### 4️⃣ Correr la app

```bash
flutter run -d TU_DEVICE_ID
```

---

## 🤖 Firmware ESP32

El proyecto usa **PlatformIO**. Para cargar el firmware:

```bash
cd esp32
pio run --target upload
```

O si prefieres **Arduino IDE**:
1. Abre `esp32/bike_nav_esp32.ino`
2. Selecciona placa: `ESP32 Dev Module`
3. Carga el sketch ▶️

### 🔵 Parear el ESP32

1. 🔌 Enciende el ESP32 — verás 3 parpadeos del LED integrado ✅
2. 📱 En Android → Ajustes → Bluetooth → Buscar `BikeNav-ESP32`
3. 🤝 Paréalo
4. 🚴 Abre BikeNav → toca el botón 🔵 → selecciona `BikeNav-ESP32`

---

## 📁 Estructura del proyecto

```
bikeNav/
├── 📱 lib/
│   ├── main.dart
│   ├── config.dart              ← 🔒 no se sube al repo
│   ├── config.dart.example      ← plantilla de configuración
│   ├── models/
│   │   └── navigation_step.dart
│   ├── services/
│   │   ├── maps_service.dart
│   │   ├── places_service.dart
│   │   ├── bluetooth_service.dart
│   │   ├── navigation_service.dart
│   │   └── voice_service.dart
│   └── screens/
│       └── map_screen.dart
├── 🤖 esp32/
│   └── src/
│       └── main.cpp
└── 🤖 android/
    └── app/src/main/
        └── AndroidManifest.xml
```

---

## 📦 Dependencias Flutter

| Paquete | Uso |
|---|---|
| `google_maps_flutter` | 🗺️ Renderizar el mapa |
| `flutter_polyline_points` | 〰️ Dibujar la ruta |
| `geolocator` | 📍 GPS en tiempo real |
| `bluetooth_classic` | 🔵 Comunicación con ESP32 |
| `flutter_tts` | 🔊 Text-to-Speech en español |
| `http` | 🌐 Llamadas a Google APIs |

---

## 🛠️ Requisitos

- 📱 Android 8.0+ (API 26+)
- 🔵 Bluetooth clásico (SPP)
- 🌐 Conexión a internet (para mapas y rutas)
- 🔑 API Key de Google Cloud con Maps + Directions + Places habilitados

---

## 🤝 Contribuir

¡Las PRs son bienvenidas! 🎉

1. 🍴 Haz fork del repo
2. 🌿 Crea una rama: `git checkout -b feature/mi-mejora`
3. 💾 Commitea: `git commit -m 'Agrego mi mejora'`
4. 📤 Push: `git push origin feature/mi-mejora`
5. 🔁 Abre un Pull Request

---

## 📄 Licencia

MIT © 2026 — Hecho con ❤️ y ☕ para ciclistas urbanos 🚴
