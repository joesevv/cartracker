import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'maintenance_item.dart';
import 'storage.dart' as storage;

void main() => runApp(const CarMaintenanceApp());

class CarMaintenanceApp extends StatelessWidget {
  const CarMaintenanceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Car Maintenance',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2266D5)),
          scaffoldBackgroundColor: const Color(0xFFF5F7FB),
          cardTheme: CardThemeData(
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

Color statusColor(MaintenanceStatus status) => switch (status) {
      MaintenanceStatus.notSet => const Color(0xFF8190A5),
      MaintenanceStatus.ok => const Color(0xFF138A64),
      MaintenanceStatus.dueSoon => const Color(0xFFE88A18),
      MaintenanceStatus.overdue => const Color(0xFFD54343),
    };

int statusRank(MaintenanceStatus status) => switch (status) {
      MaintenanceStatus.overdue => 0,
      MaintenanceStatus.dueSoon => 1,
      MaintenanceStatus.ok => 2,
      MaintenanceStatus.notSet => 3,
    };

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<VehicleProfile> _vehicles = [];
  String? _selectedVehicleId;
  bool _loaded = false;

  VehicleProfile get _vehicle => _vehicles.firstWhere((vehicle) => vehicle.id == _selectedVehicleId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final vehicles = await storage.loadVehicles();
    if (!mounted) return;
    setState(() {
      _vehicles = vehicles;
      _selectedVehicleId = vehicles.first.id;
      _loaded = true;
    });
  }

  Future<void> _save() => storage.saveVehicles(_vehicles);

  Future<void> _replaceVehicle(VehicleProfile updated) async {
    setState(() => _vehicles = [for (final vehicle in _vehicles) if (vehicle.id == updated.id) updated else vehicle]);
    await _save();
  }

  List<MaintenanceItem> _sortedItems() {
    final sorted = [..._vehicle.items];
    sorted.sort((a, b) {
      final byStatus = statusRank(a.statusOn(mileage: _vehicle.mileage)).compareTo(statusRank(b.statusOn(mileage: _vehicle.mileage)));
      if (byStatus != 0) return byStatus;
      return (a.nextDueDate ?? DateTime(9999)).compareTo(b.nextDueDate ?? DateTime(9999));
    });
    return sorted;
  }

  Future<void> _showVehicleEditor({VehicleProfile? editing}) async {
    final name = TextEditingController(text: editing?.name ?? '');
    final description = TextEditingController(text: editing?.description ?? '');
    final mileage = TextEditingController(text: editing?.mileage.toString() ?? '');
    final result = await showDialog<VehicleProfile>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editing == null ? 'Add vehicle' : 'Edit vehicle'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Vehicle name', hintText: 'e.g. Weekend car')),
            TextField(controller: description, decoration: const InputDecoration(labelText: 'Year, make & model', hintText: 'e.g. 2022 Honda Civic')),
            TextField(controller: mileage, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current mileage')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final label = name.text.trim();
              if (label.isEmpty) return;
              final miles = int.tryParse(mileage.text.replaceAll(',', '')) ?? 0;
              Navigator.pop(context, editing?.copyWith(name: label, description: description.text.trim(), mileage: miles) ?? newVehicle(name: label, description: description.text.trim(), mileage: miles));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose(); description.dispose(); mileage.dispose();
    if (result == null || !mounted) return;
    if (editing == null) {
      setState(() { _vehicles = [..._vehicles, result]; _selectedVehicleId = result.id; });
      await _save();
    } else {
      await _replaceVehicle(result);
    }
  }

  Future<void> _editMileage() async {
    final controller = TextEditingController(text: _vehicle.mileage.toString());
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update mileage'),
        content: TextField(controller: controller, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Odometer reading')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text.replaceAll(',', ''))), child: const Text('Update'))],
      ),
    );
    controller.dispose();
    if (value != null && value >= 0) await _replaceVehicle(_vehicle.copyWith(mileage: value));
  }

  Future<void> _showServiceSheet(MaintenanceItem item) async {
    final notes = TextEditingController();
    final mileage = TextEditingController(text: _vehicle.mileage.toString());
    var serviceDate = dateOnly(DateTime.now());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCED6E2), borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 20),
            Text(item.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Every ${item.intervalMonths} months or ${NumberFormat.decimalPattern().format(item.intervalMiles)} miles', style: const TextStyle(color: Color(0xFF718098))),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now(), initialDate: serviceDate);
                if (picked != null) setSheetState(() => serviceDate = picked);
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(DateFormat.yMMMMd().format(serviceDate)),
            ),
            const SizedBox(height: 10),
            TextField(controller: mileage, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Mileage at service', prefixIcon: Icon(Icons.speed_rounded))),
            const SizedBox(height: 10),
            TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.notes_rounded))),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: () async {
                final miles = int.tryParse(mileage.text.replaceAll(',', ''));
                if (miles == null || miles < 0) return;
                final records = [...item.history, ServiceRecord(date: serviceDate, mileage: miles, notes: notes.text.trim())];
                final updatedItems = [for (final current in _vehicle.items) if (current.name == item.name) current.withHistory(records) else current];
                await _replaceVehicle(_vehicle.copyWith(items: updatedItems, mileage: miles > _vehicle.mileage ? miles : _vehicle.mileage));
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.check_circle_outline_rounded), label: const Text('Log service'),
            )),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            if (item.history.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Service history', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              ...item.history.take(4).map((record) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(radius: 17, child: Icon(Icons.build_rounded, size: 16)),
                title: Text(DateFormat.yMMMd().format(record.date)),
                subtitle: Text(record.notes.isEmpty ? '${NumberFormat.decimalPattern().format(record.mileage)} mi' : record.notes),
              )),
            ],
          ]),
        ),
      ),
    );
    notes.dispose(); mileage.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final items = _sortedItems();
    final attention = items.where((item) => item.statusOn(mileage: _vehicle.mileage) != MaintenanceStatus.ok).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Maintenance', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        actions: [PopupMenuButton<String>(
          icon: const Icon(Icons.directions_car_rounded),
          onSelected: (id) { if (id == 'add') { _showVehicleEditor(); } else if (id == 'edit') { _showVehicleEditor(editing: _vehicle); } else { setState(() => _selectedVehicleId = id); } },
          itemBuilder: (context) => [
            for (final vehicle in _vehicles) CheckedPopupMenuItem(value: vehicle.id, checked: vehicle.id == _selectedVehicleId, child: Text(vehicle.name)),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'add', child: ListTile(leading: Icon(Icons.add), title: Text('Add vehicle'), contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit current vehicle'), contentPadding: EdgeInsets.zero)),
          ],
        )],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        _vehicleHero(attention), const SizedBox(height: 26),
        const Text('Maintenance schedule', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF16233B))),
        const SizedBox(height: 5), const Text('Log each service to keep time and mileage intervals accurate.', style: TextStyle(color: Color(0xFF718098), fontSize: 13)),
        const SizedBox(height: 14),
        for (final item in items) ...[_buildTile(item), const SizedBox(height: 10)],
      ]),
    );
  }

  Widget _vehicleHero(int attention) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF1E5FC9), Color(0xFF4387E9)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_vehicle.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
      if (_vehicle.description.isNotEmpty) Text(_vehicle.description, style: const TextStyle(color: Color(0xD9FFFFFF))),
      const SizedBox(height: 20),
      Row(children: [
        const Icon(Icons.speed_rounded, color: Colors.white), const SizedBox(width: 8),
        Text('${NumberFormat.decimalPattern().format(_vehicle.mileage)} mi', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const Spacer(), TextButton(onPressed: _editMileage, child: const Text('UPDATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
      ]),
      const Divider(color: Color(0x55FFFFFF)), const SizedBox(height: 4),
      Text(attention == 0 ? 'Everything is on track' : '$attention item${attention == 1 ? '' : 's'} need attention', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _buildTile(MaintenanceItem item) {
    final status = item.statusOn(mileage: _vehicle.mileage);
    final color = statusColor(status);
    final miles = item.milesUntilDue(_vehicle.mileage);
    final days = item.daysUntilDue();
    final label = switch (status) { MaintenanceStatus.notSet => 'Not logged', MaintenanceStatus.ok => 'On track', MaintenanceStatus.dueSoon => 'Due soon', MaintenanceStatus.overdue => 'Overdue' };
    return Card(child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9), onTap: () => _showServiceSheet(item),
      leading: Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.build_circle_outlined, color: color)),
      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1B2942))),
      subtitle: Text(item.lastDone == null ? 'No services logged yet' : '${DateFormat.MMMd().format(item.lastDone!)}  •  ${NumberFormat.decimalPattern().format(item.lastMileage ?? 0)} mi', style: const TextStyle(color: Color(0xFF718098), fontSize: 12.5)),
      trailing: SizedBox(width: 78, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10.5))),
        if (miles != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text('${NumberFormat.compact().format(miles.abs())} mi ${miles < 0 ? 'over' : 'left'}', style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600))) else if (days != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(relativeDueText(days), style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600))),
      ])),
    ));
  }
}
