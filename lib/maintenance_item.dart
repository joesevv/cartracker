import 'dart:math';

enum MaintenanceStatus { notSet, ok, dueSoon, overdue }

class ServiceRecord {
  final DateTime date;
  final int mileage;
  final String notes;
  final double? cost;

  const ServiceRecord({required this.date, required this.mileage, this.notes = '', this.cost});

  Map<String, Object?> toJson() => {
        'date': date.toIso8601String(), 'mileage': mileage, 'notes': notes, 'cost': cost,
      };

  factory ServiceRecord.fromJson(Map<String, dynamic> json) => ServiceRecord(
        date: dateOnly(DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now()),
        mileage: (json['mileage'] as num?)?.round() ?? 0,
        notes: json['notes'] as String? ?? '', cost: (json['cost'] as num?)?.toDouble(),
      );
}

class MaintenanceItem {
  final String name;
  final int intervalMonths;
  final int intervalMiles;
  final DateTime? lastDone;
  final int? lastMileage;
  final List<ServiceRecord> history;

  const MaintenanceItem({
    required this.name, required this.intervalMonths, required this.intervalMiles,
    this.lastDone, this.lastMileage, this.history = const [],
  });

  MaintenanceItem withHistory(List<ServiceRecord> value) {
    final sorted = [...value]..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.isEmpty ? null : sorted.first;
    return MaintenanceItem(
      name: name, intervalMonths: intervalMonths, intervalMiles: intervalMiles,
      lastDone: latest?.date, lastMileage: latest?.mileage, history: sorted,
    );
  }

  MaintenanceItem withLastDone(DateTime? value) => MaintenanceItem(
        name: name, intervalMonths: intervalMonths, intervalMiles: intervalMiles,
        lastDone: value == null ? null : dateOnly(value), lastMileage: lastMileage,
        history: value == null ? const [] : [ServiceRecord(date: value, mileage: lastMileage ?? 0)],
      );

  DateTime? get nextDueDate => lastDone == null ? null : addMonths(lastDone!, intervalMonths);
  int? get nextDueMileage => lastMileage == null ? null : lastMileage! + intervalMiles;

  int? daysUntilDue([DateTime? now]) {
    final due = nextDueDate;
    if (due == null) return null;
    final today = dateOnly(now ?? DateTime.now());
    return DateTime.utc(due.year, due.month, due.day)
        .difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  }

  int? milesUntilDue(int mileage) {
    final due = nextDueMileage;
    return due == null ? null : due - mileage;
  }

  MaintenanceStatus statusOn({DateTime? now, required int mileage}) {
    final days = daysUntilDue(now);
    final miles = milesUntilDue(mileage);
    if (days == null && miles == null) return MaintenanceStatus.notSet;
    if ((days != null && days < 0) || (miles != null && miles < 0)) return MaintenanceStatus.overdue;
    if ((days != null && days <= 30) || (miles != null && miles <= 500)) return MaintenanceStatus.dueSoon;
    return MaintenanceStatus.ok;
  }

  Map<String, Object?> toJson() => {'name': name, 'history': history.map((record) => record.toJson()).toList()};

  factory MaintenanceItem.fromJson(Map<String, dynamic> json, MaintenanceItem template) {
    final rawHistory = json['history'] as List? ?? const [];
    return template.withHistory(rawHistory.whereType<Map>()
        .map((entry) => ServiceRecord.fromJson(Map<String, dynamic>.from(entry))).toList());
  }
}

class VehicleProfile {
  final String id;
  final String name;
  final String description;
  final int mileage;
  final List<MaintenanceItem> items;

  const VehicleProfile({required this.id, required this.name, required this.description, required this.mileage, required this.items});

  VehicleProfile copyWith({String? name, String? description, int? mileage, List<MaintenanceItem>? items}) => VehicleProfile(
    id: id, name: name ?? this.name, description: description ?? this.description,
    mileage: mileage ?? this.mileage, items: items ?? this.items,
  );

  Map<String, Object?> toJson() => {
    'id': id, 'name': name, 'description': description, 'mileage': mileage,
    'items': items.map((item) => item.toJson()).toList(),
  };

  factory VehicleProfile.fromJson(Map<String, dynamic> json) {
    final storedItems = (json['items'] as List? ?? const []).whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry)).toList();
    return VehicleProfile(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'My vehicle', description: json['description'] as String? ?? '',
      mileage: (json['mileage'] as num?)?.round() ?? 0,
      items: kDefaultItems.map((template) {
        final saved = storedItems.where((item) => item['name'] == template.name);
        return saved.isEmpty ? template : MaintenanceItem.fromJson(saved.first, template);
      }).toList(),
    );
  }
}

const List<MaintenanceItem> kDefaultItems = [
  MaintenanceItem(name: 'Oil change', intervalMonths: 6, intervalMiles: 5000),
  MaintenanceItem(name: 'Tire rotation', intervalMonths: 6, intervalMiles: 6000),
  MaintenanceItem(name: 'Alignment check', intervalMonths: 12, intervalMiles: 12000),
  MaintenanceItem(name: 'Brake pads check', intervalMonths: 12, intervalMiles: 12000),
  MaintenanceItem(name: 'Cabin air filter', intervalMonths: 12, intervalMiles: 15000),
  MaintenanceItem(name: 'Engine air filter', intervalMonths: 12, intervalMiles: 15000),
  MaintenanceItem(name: 'Battery check', intervalMonths: 12, intervalMiles: 12000),
  MaintenanceItem(name: 'Wiper blades', intervalMonths: 12, intervalMiles: 12000),
];

VehicleProfile newVehicle({required String name, required String description, int mileage = 0}) => VehicleProfile(
  id: DateTime.now().microsecondsSinceEpoch.toString(), name: name, description: description,
  mileage: mileage, items: List.of(kDefaultItems),
);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  return DateTime(year, month, min(d.day, DateTime(year, month + 1, 0).day));
}

String relativeDueText(int daysUntilDue) {
  if (daysUntilDue == 0) return 'Due today';
  if (daysUntilDue > 0) return daysUntilDue == 1 ? 'in 1 day' : daysUntilDue < 60 ? 'in $daysUntilDue days' : 'in ${daysUntilDue ~/ 30} months';
  final overdue = -daysUntilDue;
  return overdue == 1 ? '1 day overdue' : overdue < 60 ? '$overdue days overdue' : '${overdue ~/ 30} months overdue';
}
