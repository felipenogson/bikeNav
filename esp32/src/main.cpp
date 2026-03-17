/**
 * BikeNav ESP32 — Controlador de direccionales LED
 *
 * Conexiones:
 *   GPIO 25 → 220Ω → LED izquierdo → GND
 *   GPIO 26 → 220Ω → LED derecho  → GND
 *   GPIO 2  → LED integrado (diagnóstico)
 */

#include "BluetoothSerial.h"

#define PIN_LED_LEFT    25
#define PIN_LED_RIGHT   26
#define PIN_LED_BUILTIN  2   // LED azul/rojo integrado del ESP32

#define BLINK_TURN    400
#define BLINK_UTURN   200
#define BLINK_ARRIVE  500

enum LedMode { MODE_OFF, MODE_LEFT, MODE_RIGHT, MODE_UTURN, MODE_ARRIVE };

// Forward declarations (requerido por C++ / PlatformIO)
void readBluetooth();
void handleCommand(const String& cmd);
void setMode(LedMode mode);
void updateLeds();
void blinkBoth(int times, int ms);

BluetoothSerial SerialBT;

LedMode  currentMode    = MODE_OFF;
uint32_t lastBlink      = 0;
bool     blinkState     = false;
bool     uturnLeft      = true;

// Buffer para armar el comando byte a byte
String cmdBuffer = "";

// ── Setup ──────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);

  pinMode(PIN_LED_LEFT,    OUTPUT);
  pinMode(PIN_LED_RIGHT,   OUTPUT);
  pinMode(PIN_LED_BUILTIN, OUTPUT);

  digitalWrite(PIN_LED_LEFT,    LOW);
  digitalWrite(PIN_LED_RIGHT,   LOW);
  digitalWrite(PIN_LED_BUILTIN, LOW);

  SerialBT.begin("BikeNav-ESP32");
  Serial.println("=== BikeNav listo. Esperando conexion BT... ===");

  // Parpadeo de inicio para confirmar que el firmware cargó
  for (int i = 0; i < 3; i++) {
    digitalWrite(PIN_LED_BUILTIN, HIGH); delay(150);
    digitalWrite(PIN_LED_BUILTIN, LOW);  delay(150);
  }
}

// ── Loop ───────────────────────────────────────────────────────
void loop() {
  readBluetooth();
  updateLeds();
}

// ── Lectura robusta por buffer ─────────────────────────────────
void readBluetooth() {
  while (SerialBT.available()) {
    char c = (char)SerialBT.read();

    if (c == '\n' || c == '\r') {
      cmdBuffer.trim();
      if (cmdBuffer.length() > 0) {
        Serial.print("CMD recibido: [");
        Serial.print(cmdBuffer);
        Serial.println("]");

        // Pulso en LED integrado para confirmar recepción
        digitalWrite(PIN_LED_BUILTIN, HIGH);
        delay(50);
        digitalWrite(PIN_LED_BUILTIN, LOW);

        handleCommand(cmdBuffer);
        cmdBuffer = "";
      }
    } else {
      cmdBuffer += c;
      // Seguridad: si el buffer crece demasiado sin '\n', lo limpiamos
      if (cmdBuffer.length() > 32) cmdBuffer = "";
    }
  }
}

// ── Manejo de comandos ─────────────────────────────────────────
void handleCommand(const String& cmd) {
  if      (cmd == "LEFT")     setMode(MODE_LEFT);
  else if (cmd == "RIGHT")    setMode(MODE_RIGHT);
  else if (cmd == "UTURN")    setMode(MODE_UTURN);
  else if (cmd == "ARRIVE")   setMode(MODE_ARRIVE);
  else if (cmd == "STOP")     setMode(MODE_OFF);
  else if (cmd == "STRAIGHT") {
    blinkBoth(2, 100);
    setMode(MODE_OFF);
  }
  else {
    Serial.print("Comando desconocido: ");
    Serial.println(cmd);
  }
}

// ── Cambio de modo ─────────────────────────────────────────────
void setMode(LedMode mode) {
  currentMode = mode;
  blinkState  = false;
  uturnLeft   = true;
  lastBlink   = millis();
  digitalWrite(PIN_LED_LEFT,  LOW);
  digitalWrite(PIN_LED_RIGHT, LOW);
}

// ── Actualización no-bloqueante de LEDs ───────────────────────
void updateLeds() {
  uint32_t now = millis();

  switch (currentMode) {
    case MODE_LEFT:
      if (now - lastBlink >= BLINK_TURN) {
        lastBlink  = now;
        blinkState = !blinkState;
        digitalWrite(PIN_LED_LEFT,  blinkState ? HIGH : LOW);
        digitalWrite(PIN_LED_RIGHT, LOW);
      }
      break;

    case MODE_RIGHT:
      if (now - lastBlink >= BLINK_TURN) {
        lastBlink  = now;
        blinkState = !blinkState;
        digitalWrite(PIN_LED_RIGHT, blinkState ? HIGH : LOW);
        digitalWrite(PIN_LED_LEFT,  LOW);
      }
      break;

    case MODE_UTURN:
      if (now - lastBlink >= BLINK_UTURN) {
        lastBlink = now;
        uturnLeft = !uturnLeft;
        digitalWrite(PIN_LED_LEFT,  uturnLeft ? HIGH : LOW);
        digitalWrite(PIN_LED_RIGHT, uturnLeft ? LOW  : HIGH);
      }
      break;

    case MODE_ARRIVE:
      if (now - lastBlink >= BLINK_ARRIVE) {
        lastBlink  = now;
        blinkState = !blinkState;
        digitalWrite(PIN_LED_LEFT,  blinkState ? HIGH : LOW);
        digitalWrite(PIN_LED_RIGHT, blinkState ? HIGH : LOW);
      }
      break;

    case MODE_OFF:
    default:
      break;
  }
}

// ── Destello doble bloqueante (STRAIGHT) ──────────────────────
void blinkBoth(int times, int ms) {
  for (int i = 0; i < times; i++) {
    digitalWrite(PIN_LED_LEFT,  HIGH);
    digitalWrite(PIN_LED_RIGHT, HIGH);
    delay(ms);
    digitalWrite(PIN_LED_LEFT,  LOW);
    digitalWrite(PIN_LED_RIGHT, LOW);
    delay(ms);
  }
}
