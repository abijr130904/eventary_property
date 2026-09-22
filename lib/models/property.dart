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
  });

  String get capacityLabel => '$capacity People';

  String get areaLabel => '${area.toStringAsFixed(0)} m²';
}
