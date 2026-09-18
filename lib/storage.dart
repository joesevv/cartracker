import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'maintenance_item.dart';

const _vehiclesKey = 'vehicle_profiles_v2';
const _legacyKey = 'maintenance_data';

Future<List<VehicleProfile>> loadVehicles() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_vehiclesKey);
  if (raw != null) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<Map>().map((entry) => VehicleProfile.fromJson(Map<String, dynamic>.from(entry))).toList();
    } catch (_) {}
  }
  final legacy = prefs.getString(_legacyKey);
  if (legacy != null) {
    try {
      final decoded = jsonDecode(legacy);
      if (decoded is Map) {
        final items = kDefaultItems.map((item) {
          final value = decoded[item.name];
          final date = value is String ? DateTime.tryParse(value) : null;
          return date == null ? item : item.withLastDone(date);
        }).toList();
        return [newVehicle(name: 'My vehicle', description: '', mileage: 0).copyWith(items: items)];
      }
    } catch (_) {}
  }
  return [newVehicle(name: 'My vehicle', description: '', mileage: 0)];
}

Future<void> saveVehicles(List<VehicleProfile> vehicles) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_vehiclesKey, jsonEncode(vehicles.map((vehicle) => vehicle.toJson()).toList()));
}
