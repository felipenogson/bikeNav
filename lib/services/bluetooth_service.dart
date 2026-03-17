import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';

const String _kSppUuid = '00001101-0000-1000-8000-00805F9B34FB';

class BluetoothService {
  final _bt = BluetoothClassic();
  bool _connected = false;

  bool get isConnected => _connected;

  Future<List<Device>> getPairedDevices() async {
    await _bt.initPermissions();
    return await _bt.getPairedDevices();
  }

  Future<void> connect(String address) async {
    if (_connected) await disconnect();
    await _bt.connect(address, _kSppUuid);
    _connected = true;
  }

  /// Envía un comando al ESP32. No toca _connected si falla el write
  /// para que el botón siga siendo interactivo.
  Future<void> sendCommand(String command) async {
    if (!_connected) return;
    await _bt.write('$command\n');
  }

  Future<void> disconnect() async {
    try {
      await _bt.disconnect();
    } catch (_) {}
    _connected = false;
  }
}
