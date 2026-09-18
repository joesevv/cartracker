import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'maintenance_item.dart';
const _key = 'maintenance_data';
//this file allows for saving progress through json strings, obviously not that many values to keep so a db is overkill
Future<Map<String, DateTime?>> load() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  if (raw == null) return {};
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return {};
  }
  if (decoded is! Map) return {};
  final result = <String, DateTime?>{};
  for (final entry in decoded.entries) {
    final key = entry.key;
    if (key is! String) continue;
    final value = entry.value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      result[key] = parsed == null ? null : dateOnly(parsed);
    } else {
      result[key] = null;
    }
  }
  return result;
}

Future<void> save(List<MaintenanceItem> items) async {
  final prefs = await SharedPreferences.getInstance();
  final data = <String, String?>{
    for (final item in items)
      item.name: item.lastDone == null ? null : _formatDate(item.lastDone!),
  };
  await prefs.setString(_key, jsonEncode(data));
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
