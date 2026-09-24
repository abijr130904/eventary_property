/// Domain model for a venue / event property.
///
/// This is intentionally a plain Dart class with no persistence or
/// network logic attached, so that later on it can be swapped for a
/// version generated from a Python/REST backend (e.g. via json
/// serialization) without touching any UI code that consumes it.
class Property {
  final String id;
  final String name;
  final String location;
  final String type;
  final int capacity;
  final double area; // in square meters
  final String description;

  /// Real-world coordinates, used to place the marker on the actual
  /// map (OpenFreeMap streets / Esri satellite imagery) via maplibre_gl.
  final double latitude;
  final double longitude;

  /// Path to a .glb asset for the real 3D model, e.g.
  /// 'assets/models/venue.glb' (the file must be declared under `assets:`
  /// in pubspec.yaml). Model3DViewer renders it with model_viewer_plus.
  /// Left null, a procedural placeholder cube is shown instead.
  final String? modelAssetPath;

  /// Asset status for the internal management dashboard, e.g. 'Tersedia',
  /// 'Booking', 'Disewa/Terjual', 'Konstruksi'. Purely informational -
  /// doesn't affect map rendering (yet).
  final String status;

  // ---- Eventaris (fixed-asset inventory) fields -----------------------
  // All optional/defaulted so existing data and code keep working
  // unchanged; only the admin dashboard's "Detail Inventaris" tab reads
  // these.

  /// Unique inventory code, e.g. 'ASG-PIK2-VN-001'.
  final String inventoryCode;

  /// Broad asset category, distinct from [type] (which is the venue's
  /// use-case like 'Ballroom'). One of [kAssetCategories].
  final String assetCategory;

  /// When the asset was acquired/built.
  final DateTime? acquisitionDate;

  /// Acquisition value in Rupiah.
  final double? acquisitionValue;

  /// Free-text reference to legal documents, e.g. certificate/HGB/PBG
  /// numbers.
  final String legalDocument;

  /// Physical condition, one of [kAssetConditions].
  final String condition;

  /// Staff/division responsible for this asset.
  final String picName;

  final DateTime? lastMaintenanceDate;
  final String lastMaintenanceNote;

  const Property({
    required this.id,
    required this.name,
    required this.location,
    required this.type,
    required this.capacity,
    required this.area,
    required this.latitude,
    required this.longitude,
    this.description = '',
    this.modelAssetPath,
    this.status = 'Tersedia',
    this.inventoryCode = '',
    this.assetCategory = 'Venue/Gedung',
    this.acquisitionDate,
    this.acquisitionValue,
    this.legalDocument = '',
    this.condition = 'Baik',
    this.picName = '',
    this.lastMaintenanceDate,
    this.lastMaintenanceNote = '',
  });

  String get capacityLabel => '$capacity People';

  String get areaLabel => '${area.toStringAsFixed(0)} m²';

  String get acquisitionValueLabel => acquisitionValue == null
      ? '-'
      : 'Rp ${acquisitionValue!.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]}.',
          )}';

  Property copyWith({
    String? id,
    String? name,
    String? location,
    String? type,
    int? capacity,
    double? area,
    double? latitude,
    double? longitude,
    String? description,
    String? modelAssetPath,
    String? status,
    String? inventoryCode,
    String? assetCategory,
    DateTime? acquisitionDate,
    double? acquisitionValue,
    String? legalDocument,
    String? condition,
    String? picName,
    DateTime? lastMaintenanceDate,
    String? lastMaintenanceNote,
  }) {
    return Property(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      type: type ?? this.type,
      capacity: capacity ?? this.capacity,
      area: area ?? this.area,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      modelAssetPath: modelAssetPath ?? this.modelAssetPath,
      status: status ?? this.status,
      inventoryCode: inventoryCode ?? this.inventoryCode,
      assetCategory: assetCategory ?? this.assetCategory,
      acquisitionDate: acquisitionDate ?? this.acquisitionDate,
      acquisitionValue: acquisitionValue ?? this.acquisitionValue,
      legalDocument: legalDocument ?? this.legalDocument,
      condition: condition ?? this.condition,
      picName: picName ?? this.picName,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      lastMaintenanceNote: lastMaintenanceNote ?? this.lastMaintenanceNote,
    );
  }
}

/// Fixed set of statuses offered in the admin dashboard's status dropdown.
const List<String> kPropertyStatuses = [
  'Tersedia',
  'Booking',
  'Disewa/Terjual',
  'Konstruksi',
];

/// Fixed set of venue/property types offered in the admin dashboard's
/// type dropdown, seeded from the existing dummy dataset.
const List<String> kPropertyTypes = [
  'Ballroom',
  'Convention Hall',
  'Outdoor',
  'Exhibition',
  'Meeting Room',
  'Event Space',
];

/// Broad fixed-asset categories for the "eventaris" (inventory) view.
const List<String> kAssetCategories = [
  'Tanah',
  'Bangunan',
  'Venue/Gedung',
  'Fasilitas MICE',
];

/// Physical condition options for the "eventaris" (inventory) view.
const List<String> kAssetConditions = [
  'Baik',
  'Rusak Ringan',
  'Rusak Berat',
];
