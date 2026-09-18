import 'dart:math';
//this file handles all the arithemetic related to calculating the output time, wanted to keep it seperate from ui so no bugs
enum MaintenanceStatus { notSet, ok, dueSoon, overdue }
class MaintenanceItem {
  final String name;
  final int intervalMonths;
  final DateTime? lastDone;

  const MaintenanceItem({
    required this.name,
    required this.intervalMonths,
    this.lastDone,
  });

  MaintenanceItem withLastDone(DateTime? value) => MaintenanceItem(
    name: name,
    intervalMonths: intervalMonths,
    lastDone: value == null ? null : dateOnly(value),
  );

  DateTime? get nextDue =>
      lastDone == null ? null : addMonths(lastDone!, intervalMonths);

  /// days from today to next due, overdue=negative
  int? daysUntilDue([DateTime? now]) {
    final due = nextDue;
    if (due == null) return null;
    final today = dateOnly(now ?? DateTime.now());
    return DateTime.utc(due.year, due.month, due.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;
  }

  MaintenanceStatus statusOn([DateTime? now]) {
    final days = daysUntilDue(now);
    if (days == null) return MaintenanceStatus.notSet;
    if (days < 0) return MaintenanceStatus.overdue;
    if (days <= 30) return MaintenanceStatus.dueSoon;
    return MaintenanceStatus.ok;
  }
}

const List<MaintenanceItem> kDefaultItems = [
  MaintenanceItem(name: 'Oil change', intervalMonths: 6),
  MaintenanceItem(name: 'Tire rotation', intervalMonths: 6),
  MaintenanceItem(name: 'Alignment check', intervalMonths: 12),
  MaintenanceItem(name: 'Brake pads check', intervalMonths: 12),
  MaintenanceItem(name: 'Cabin air filter', intervalMonths: 12),
  MaintenanceItem(name: 'Engine air filter', intervalMonths: 12),
  MaintenanceItem(name: 'Battery check', intervalMonths: 12),
  MaintenanceItem(name: 'Wiper blades', intervalMonths: 12),
];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
//proper arithmetic for calendar months as some have different amount of days in them
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final day = min(d.day, daysInMonth);
  return DateTime(year, month, day);
}

/// "Due today", "in 1 day", "in N days", "in M months",
/// "1 day overdue", "N days overdue", "M months overdue"
String relativeDueText(int daysUntilDue) {
  if (daysUntilDue == 0) return 'Due today';
  if (daysUntilDue > 0) {
    if (daysUntilDue == 1) return 'in 1 day';
    if (daysUntilDue < 60) return 'in $daysUntilDue days';
    return 'in ${daysUntilDue ~/ 30} months';
  }
  final overdue = -daysUntilDue;
  if (overdue == 1) return '1 day overdue';
  if (overdue < 60) return '$overdue days overdue';
  return '${overdue ~/ 30} months overdue';
}
