import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/property.dart';
import '../theme/app_theme.dart';
import '../widgets/coordinate_picker_dialog.dart';

/// Internal dashboard for managing the property/venue dataset: a
/// searchable table plus add/edit/delete, backed by the same in-memory
/// list HomeScreen already holds (no backend yet - see onAdd/onUpdate/
/// onDelete, which just mutate that list via setState in the parent).
class AdminDashboardScreen extends StatefulWidget {
  final List<Property> properties;
  final ValueChanged<Property> onAdd;
  final ValueChanged<Property> onUpdate;
  final ValueChanged<String> onDelete; // by property id
  final ValueChanged<Property>? onViewOnMap;

  const AdminDashboardScreen({
    super.key,
    required this.properties,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
    this.onViewOnMap,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _query = '';

  List<Property> get _filtered {
    if (_query.isEmpty) return widget.properties;
    final q = _query.toLowerCase();
    return widget.properties
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.location.toLowerCase().contains(q) ||
            p.type.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _openForm({Property? existing}) async {
    final result = await showDialog<Property>(
      context: context,
      builder: (_) => _PropertyFormDialog(existing: existing),
    );
    if (result == null) return;
    if (existing == null) {
      widget.onAdd(result);
    } else {
      widget.onUpdate(result);
    }
  }

  Future<void> _confirmDelete(Property property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus aset?'),
        content: Text('"${property.name}" akan dihapus dari daftar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete(property.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Eventaris (Inventaris Aset)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Aset'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 19, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Cari nama, lokasi, atau tipe...',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: _filtered.isEmpty
                ? const Center(child: Text('Tidak ada aset yang cocok.'))
                : _buildInventoryTable(),
          ),
        ),
      ],
    );
  }

  Widget _actionCell(Property property) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onViewOnMap != null)
          IconButton(
            icon: const Icon(Icons.map_outlined, size: 18),
            tooltip: 'Lihat di Peta',
            onPressed: () => widget.onViewOnMap!(property),
          ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: 'Edit',
          onPressed: () => _openForm(existing: property),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
          tooltip: 'Hapus',
          onPressed: () => _confirmDelete(property),
        ),
      ],
    );
  }

  Widget _buildInventoryTable() {
    final dateFmt = (DateTime? d) =>
        d == null ? '-' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Nama')),
            DataColumn(label: Text('Kode Inventaris')),
            DataColumn(label: Text('Kategori Aset')),
            DataColumn(label: Text('Tgl. Perolehan')),
            DataColumn(label: Text('Nilai Perolehan')),
            DataColumn(label: Text('Dokumen Legal')),
            DataColumn(label: Text('Kondisi')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('PIC')),
            DataColumn(label: Text('Perawatan Terakhir')),
            DataColumn(label: Text('Aksi')),
          ],
          rows: [
            for (final property in _filtered)
              DataRow(
                cells: [
                  DataCell(Text(property.name)),
                  DataCell(Text(property.inventoryCode.isEmpty ? '-' : property.inventoryCode)),
                  DataCell(Text(property.assetCategory)),
                  DataCell(Text(dateFmt(property.acquisitionDate))),
                  DataCell(Text(property.acquisitionValueLabel)),
                  DataCell(Text(property.legalDocument.isEmpty ? '-' : property.legalDocument)),
                  DataCell(_ConditionBadge(condition: property.condition)),
                  DataCell(_StatusBadge(status: property.status)),
                  DataCell(Text(property.picName.isEmpty ? '-' : property.picName)),
                  DataCell(Text(
                    property.lastMaintenanceDate == null
                        ? '-'
                        : '${dateFmt(property.lastMaintenanceDate)}'
                            '${property.lastMaintenanceNote.isEmpty ? '' : ' - ${property.lastMaintenanceNote}'}',
                  )),
                  DataCell(_actionCell(property)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'Tersedia':
        return Colors.green;
      case 'Booking':
        return Colors.orange;
      case 'Disewa/Terjual':
        return Colors.blueGrey;
      case 'Konstruksi':
        return Colors.brown;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status, style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _ConditionBadge extends StatelessWidget {
  final String condition;
  const _ConditionBadge({required this.condition});

  Color get _color {
    switch (condition) {
      case 'Baik':
        return Colors.green;
      case 'Rusak Ringan':
        return Colors.orange;
      case 'Rusak Berat':
        return Colors.red;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(condition, style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Add/edit form. Returns the resulting [Property] via Navigator.pop,
/// or null if cancelled. When [existing] is passed, its id/model asset
/// path are preserved (not user-editable here) and every field is
/// pre-filled for editing.
class _PropertyFormDialog extends StatefulWidget {
  final Property? existing;
  const _PropertyFormDialog({this.existing});

  @override
  State<_PropertyFormDialog> createState() => _PropertyFormDialogState();
}

class _PropertyFormDialogState extends State<_PropertyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _capacity;
  late final TextEditingController _area;
  late final TextEditingController _description;
  late String _type;
  late String _status;
  late double _latitude;
  late double _longitude;

  // Eventaris (fixed-asset inventory) fields.
  late final TextEditingController _inventoryCode;
  late final TextEditingController _acquisitionValue;
  late final TextEditingController _legalDocument;
  late final TextEditingController _picName;
  late final TextEditingController _lastMaintenanceNote;
  late final TextEditingController _latitudeText;
  late final TextEditingController _longitudeText;
  late String _assetCategory;
  late String _condition;
  DateTime? _acquisitionDate;
  DateTime? _lastMaintenanceDate;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _location = TextEditingController(text: p?.location ?? '');
    _capacity = TextEditingController(text: p != null ? '${p.capacity}' : '');
    _area = TextEditingController(text: p != null ? '${p.area}' : '');
    _description = TextEditingController(text: p?.description ?? '');
    _type = p?.type ?? kPropertyTypes.first;
    _status = p?.status ?? kPropertyStatuses.first;
    _latitude = p?.latitude ?? -7.7830;
    _longitude = p?.longitude ?? 110.3900;
    _latitudeText = TextEditingController(text: _latitude.toStringAsFixed(6));
    _longitudeText = TextEditingController(text: _longitude.toStringAsFixed(6));

    _inventoryCode = TextEditingController(text: p?.inventoryCode ?? '');
    _acquisitionValue = TextEditingController(
      text: p?.acquisitionValue != null ? '${p!.acquisitionValue}' : '',
    );
    _legalDocument = TextEditingController(text: p?.legalDocument ?? '');
    _picName = TextEditingController(text: p?.picName ?? '');
    _lastMaintenanceNote = TextEditingController(text: p?.lastMaintenanceNote ?? '');
    _assetCategory = p?.assetCategory ?? kAssetCategories.first;
    _condition = p?.condition ?? kAssetConditions.first;
    _acquisitionDate = p?.acquisitionDate;
    _lastMaintenanceDate = p?.lastMaintenanceDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _capacity.dispose();
    _area.dispose();
    _description.dispose();
    _inventoryCode.dispose();
    _acquisitionValue.dispose();
    _legalDocument.dispose();
    _picName.dispose();
    _lastMaintenanceNote.dispose();
    _latitudeText.dispose();
    _longitudeText.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isAcquisition}) async {
    final initial = (isAcquisition ? _acquisitionDate : _lastMaintenanceDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isAcquisition) {
        _acquisitionDate = picked;
      } else {
        _lastMaintenanceDate = picked;
      }
    });
  }

  Future<void> _pickOnMap() async {
    final picked = await pickCoordinateOnMap(context, LatLng(_latitude, _longitude));
    if (picked != null) {
      setState(() {
        _latitude = picked.latitude;
        _longitude = picked.longitude;
        _latitudeText.text = _latitude.toStringAsFixed(6);
        _longitudeText.text = _longitude.toStringAsFixed(6);
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final result = Property(
      id: widget.existing?.id ?? 'p${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      location: _location.text.trim(),
      type: _type,
      capacity: int.tryParse(_capacity.text.trim()) ?? 0,
      area: double.tryParse(_area.text.trim()) ?? 0,
      latitude: double.tryParse(_latitudeText.text.trim()) ?? _latitude,
      longitude: double.tryParse(_longitudeText.text.trim()) ?? _longitude,
      description: _description.text.trim(),
      modelAssetPath: widget.existing?.modelAssetPath,
      status: _status,
      inventoryCode: _inventoryCode.text.trim(),
      assetCategory: _assetCategory,
      acquisitionDate: _acquisitionDate,
      acquisitionValue: double.tryParse(_acquisitionValue.text.trim()),
      legalDocument: _legalDocument.text.trim(),
      condition: _condition,
      picName: _picName.text.trim(),
      lastMaintenanceDate: _lastMaintenanceDate,
      lastMaintenanceNote: _lastMaintenanceNote.text.trim(),
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEdit ? 'Edit Aset' : 'Tambah Aset',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'Nama'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _location,
                          decoration: const InputDecoration(labelText: 'Lokasi (alamat/kawasan)'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _type,
                          decoration: const InputDecoration(labelText: 'Tipe'),
                          items: [
                            for (final t in kPropertyTypes) DropdownMenuItem(value: t, child: Text(t)),
                          ],
                          onChanged: (v) => setState(() => _type = v ?? _type),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: [
                            for (final s in kPropertyStatuses) DropdownMenuItem(value: s, child: Text(s)),
                          ],
                          onChanged: (v) => setState(() => _status = v ?? _status),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _capacity,
                                decoration: const InputDecoration(labelText: 'Kapasitas (orang)'),
                                keyboardType: TextInputType.number,
                                validator: (v) => (int.tryParse(v?.trim() ?? '') == null) ? 'Angka' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _area,
                                decoration: const InputDecoration(labelText: 'Luas (m²)'),
                                keyboardType: TextInputType.number,
                                validator: (v) => (double.tryParse(v?.trim() ?? '') == null) ? 'Angka' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _description,
                          decoration: const InputDecoration(labelText: 'Deskripsi'),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latitudeText,
                                decoration: const InputDecoration(labelText: 'Latitude'),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                validator: (v) => (double.tryParse(v?.trim() ?? '') == null) ? 'Angka' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _longitudeText,
                                decoration: const InputDecoration(labelText: 'Longitude'),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                validator: (v) => (double.tryParse(v?.trim() ?? '') == null) ? 'Angka' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _pickOnMap,
                            icon: const Icon(Icons.map_outlined, size: 16),
                            label: const Text('Pilih di peta'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text('Detail Inventaris (Eventaris)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _inventoryCode,
                          decoration: const InputDecoration(
                            labelText: 'Kode Inventaris',
                            hintText: 'mis. ASG-PIK2-VN-001',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _assetCategory,
                          decoration: const InputDecoration(labelText: 'Kategori Aset'),
                          items: [
                            for (final c in kAssetCategories) DropdownMenuItem(value: c, child: Text(c)),
                          ],
                          onChanged: (v) => setState(() => _assetCategory = v ?? _assetCategory),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _DatePickerField(
                                label: 'Tanggal Perolehan',
                                value: _acquisitionDate,
                                onTap: () => _pickDate(isAcquisition: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _acquisitionValue,
                                decoration: const InputDecoration(labelText: 'Nilai Perolehan (Rp)'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _legalDocument,
                          decoration: const InputDecoration(
                            labelText: 'Dokumen Legal',
                            hintText: 'No. sertifikat/HGB/PBG',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _condition,
                                decoration: const InputDecoration(labelText: 'Kondisi'),
                                items: [
                                  for (final c in kAssetConditions) DropdownMenuItem(value: c, child: Text(c)),
                                ],
                                onChanged: (v) => setState(() => _condition = v ?? _condition),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _picName,
                                decoration: const InputDecoration(labelText: 'PIC / Penanggung Jawab'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _DatePickerField(
                          label: 'Perawatan Terakhir',
                          value: _lastMaintenanceDate,
                          onTap: () => _pickDate(isAcquisition: false),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastMaintenanceNote,
                          decoration: const InputDecoration(labelText: 'Catatan Perawatan'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submit,
                      child: Text(_isEdit ? 'Simpan' : 'Tambah'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DatePickerField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text =
        value == null ? 'Pilih tanggal' : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text, style: const TextStyle(fontSize: 13.5)),
            const Icon(Icons.calendar_today_outlined, size: 16),
          ],
        ),
      ),
    );
  }
}
