import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinStorage {
  static const _pinKey = 'user_pin';
  static final _storage = FlutterSecureStorage();

  static Future<void> savePin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  static Future<String?> getPin() async {
    return await _storage.read(key: _pinKey);
  }

  static Future<void> deletePin() async {
    await _storage.delete(key: _pinKey);
  }
}

