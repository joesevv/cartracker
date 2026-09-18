import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'maintenance_item.dart';
import 'storage.dart' as storage;

void main() {
  runApp(const CarMaintenanceApp());
}

class CarMaintenanceApp extends StatelessWidget {
  const CarMaintenanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Maintenance',
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

Color statusColor(MaintenanceStatus status) {
  switch (status) {
    case MaintenanceStatus.notSet:
      return Colors.grey;
    case MaintenanceStatus.ok:
      return Colors.green;
    case MaintenanceStatus.dueSoon:
      return Colors.amber;
    case MaintenanceStatus.overdue:
      return Colors.red;
  }
}

int statusRank(MaintenanceStatus status) {
  switch (status) {
    case MaintenanceStatus.overdue:
      return 0;
    case MaintenanceStatus.dueSoon:
      return 1;
    case MaintenanceStatus.ok:
      return 2;
    case MaintenanceStatus.notSet:
      return 3;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MaintenanceItem> _items = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await storage.load();
    if (!mounted) return;
    setState(() {
      _items = kDefaultItems
          .map((item) => item.withLastDone(saved[item.name]))
          .toList();
      _loaded = true;
    });
  }

  Future<void> _setLastDone(MaintenanceItem item, DateTime? value) async {
    setState(() {
      _items = [
        for (final current in _items)
          current.name == item.name ? current.withLastDone(value) : current,
      ];
    });
    await storage.save(_items);
  }

  Future<void> _pickDate(MaintenanceItem item) async {
    final today = dateOnly(DateTime.now());
    final first = DateTime(today.year - 10, today.month, today.day);
    var init = item.lastDone ?? today;
    if (init.isBefore(first)) init = first;
    if (init.isAfter(today)) init = today;
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: first,
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    await _setLastDone(item, picked);
  }

  Future<void> _confirmClear(MaintenanceItem item) async {
    if (item.lastDone == null) return;
    final cleared = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear "${item.name}"?'),
        content: const Text('This will reset the last-done date.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (cleared != true || !mounted) return;
    await _setLastDone(item, null);
  }

  List<MaintenanceItem> _sortedItems() {
    final defaultOrder = <String, int>{
      for (var i = 0; i < kDefaultItems.length; i++) kDefaultItems[i].name: i,
    };
    final sorted = [..._items];
    sorted.sort((a, b) {
      final byStatus = statusRank(
        a.statusOn(),
      ).compareTo(statusRank(b.statusOn()));
      if (byStatus != 0) return byStatus;
      final dueA = a.nextDue;
      final dueB = b.nextDue;
      if (dueA != null && dueB != null) {
        final byDue = dueA.compareTo(dueB);
        if (byDue != 0) return byDue;
      }
      return (defaultOrder[a.name] ?? 0).compareTo(defaultOrder[b.name] ?? 0);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Car Maintenance')),
      body: _loaded
          ? ListView(
        children: [for (final item in _sortedItems()) _buildTile(item)],
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildTile(MaintenanceItem item) {
    final status = item.statusOn();
    final color = statusColor(status);
    final days = item.daysUntilDue();
    final lastDone = item.lastDone;
    final nextDue = item.nextDue;
    final isSet = lastDone != null && nextDue != null;

    return ListTile(
      onTap: () => _pickDate(item),
      onLongPress: () => _confirmClear(item),
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(item.name),
      isThreeLine: isSet,
      subtitle: Text(
        isSet
            ? 'Last done: ${DateFormat.yMMMd().format(lastDone)}\n'
            'Due: ${DateFormat.yMMMd().format(nextDue)}'
            : 'Not set yet',
      ),
      trailing: days == null
          ? null
          : Text(relativeDueText(days), style: TextStyle(color: color)),
    );
  }
}
