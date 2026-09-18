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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2266D5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF16233B),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE7EBF2)),
          ),
        ),
      ),
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
    final items = _sortedItems();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Car Maintenance',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Icon(Icons.directions_car_rounded, color: Color(0xFF2266D5)),
          ),
        ],
      ),
      body: _loaded
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                _buildOverview(items),
                const SizedBox(height: 28),
                const Text(
                  'Maintenance schedule',
                  style: TextStyle(
                    color: Color(0xFF16233B),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Tap an item to log service. Press and hold to clear it.',
                  style: TextStyle(color: Color(0xFF718098), fontSize: 13),
                ),
                const SizedBox(height: 14),
                for (final item in items) ...[
                  _buildTile(item),
                  const SizedBox(height: 10),
                ],
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildOverview(List<MaintenanceItem> items) {
    final setItems = items.where((item) => item.lastDone != null).length;
    final needsAttention = items.where((item) {
      final status = item.statusOn();
      return status == MaintenanceStatus.overdue || status == MaintenanceStatus.dueSoon;
    }).length;
    final attentionText = needsAttention == 0
        ? 'Everything is up to date'
        : '$needsAttention item${needsAttention == 1 ? '' : 's'} needs attention';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E5FC9), Color(0xFF4387E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332266D5),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              ),
              const Spacer(),
              Text(
                '$setItems / ${items.length} logged',
                style: const TextStyle(color: Color(0xD9FFFFFF), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            attentionText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.12,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep a simple record of the work that keeps your car running smoothly.',
            style: TextStyle(color: Color(0xD9FFFFFF), height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(MaintenanceItem item) {
    final status = item.statusOn();
    final color = statusColor(status);
    final days = item.daysUntilDue();
    final lastDone = item.lastDone;
    final nextDue = item.nextDue;
    final isSet = lastDone != null && nextDue != null;

    final statusLabel = switch (status) {
      MaintenanceStatus.notSet => 'Not logged',
      MaintenanceStatus.ok => 'On track',
      MaintenanceStatus.dueSoon => 'Due soon',
      MaintenanceStatus.overdue => 'Overdue',
    };
    final icon = switch (item.name) {
      'Oil change' => Icons.oil_barrel_rounded,
      'Tire rotation' => Icons.tire_repair_rounded,
      'Battery check' => Icons.battery_charging_full_rounded,
      'Wiper blades' => Icons.water_drop_outlined,
      _ => Icons.build_circle_outlined,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        onTap: () => _pickDate(item),
        onLongPress: () => _confirmClear(item),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 23),
        ),
        title: Text(
          item.name,
          style: const TextStyle(
            color: Color(0xFF1B2942),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            isSet
                ? 'Last service ${DateFormat.MMMd().format(lastDone)}  •  Due ${DateFormat.MMMd().format(nextDue)}'
                : 'Not set yet',
            style: const TextStyle(color: Color(0xFF718098), fontSize: 12.5),
          ),
        ),
        trailing: SizedBox(
          width: 74,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10.5),
                ),
              ),
              if (days != null) ...[
                const SizedBox(height: 5),
                Text(
                  relativeDueText(days),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
