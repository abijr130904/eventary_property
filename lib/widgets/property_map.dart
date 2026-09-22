import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/property.dart';
import '../theme/app_theme.dart';
import 'model_3d_viewer.dart';

enum MapLayerMode { streets, satellite }

const LatLng _initialCenter = LatLng(-7.7830, 110.3900);
const double _initialZoom = 12.5;

/// Real, interactive vector map rendered natively via `maplibre_gl`
/// (MapLibre Native on Android/iOS, MapLibre GL JS on Web) - no API
/// key required for either tile source used here:
///
/// - Streets: OpenFreeMap ("liberty" style) - free vector tiles.
/// - Satellite: Esri World Imagery, added as a raw raster style.
///
/// Because this uses a real map engine (not a flat raster viewer),
/// the camera also supports genuine pitch/tilt for a 3D-ish
/// perspective, which is the main reason this replaced the earlier
/// `flutter_map` version.
class PropertyMap extends StatefulWidget {
  final List<Property> properties;
  final Property? selectedProperty;
  final ValueChanged<Property> onMarkerTap;

  const PropertyMap({
    super.key,
    required this.properties,
    required this.onMarkerTap,
    this.selectedProperty,
  });

  @override
  State<PropertyMap> createState() => _PropertyMapState();
}

class _PropertyMapState extends State<PropertyMap> {
  MapLibreMapController? _controller;
  MapLayerMode _mode = MapLayerMode.streets;
  bool _tilted = false;
  bool _globe = false;
  CameraPosition _camera = const CameraPosition(target: _initialCenter, zoom: _initialZoom);

  final Map<String, Circle> _circleByPropertyId = {};
  final Map<String, Property> _propertyByCircleId = {};
  final Map<String, Symbol> _labelByPropertyId = {};

  // Screen-space position of the currently selected property, used to
  // float a mini 3D preview directly above its marker. Recomputed on
  // every camera change (pan/zoom/tilt/rotate) so it tracks the marker
  // in real time instead of only when the camera settles.
  math.Point<double>? _modelScreenPos;
  int _screenPosRequestId = 0;

  static const String _streetsStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  /// Built as a raw JSON string (not `asset://...`) so it loads
  /// correctly on every platform - the `asset://` scheme used by
  /// maplibre_gl for bundled Flutter assets is Android/iOS-only and
  /// silently fails to load a style on Flutter Web.
  static String _satelliteStyleJson() {
    final style = {
      'version': 8,
      'sources': {
        'esri-satellite': {
          'type': 'raster',
          'tiles': [
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          ],
          'tileSize': 256,
          'attribution': 'Esri, Maxar, Earthstar Geographics',
        },
      },
      'layers': [
        {
          'id': 'esri-satellite-layer',
          'type': 'raster',
          'source': 'esri-satellite',
          'minzoom': 0,
          'maxzoom': 19,
        },
      ],
    };
    return jsonEncode(style);
  }

  @override
  void didUpdateWidget(covariant PropertyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProperty?.id != widget.selectedProperty?.id) {
      _applySelectionHighlight(previous: oldWidget.selectedProperty);
      _updateModelScreenPosition();
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.onCircleTapped.remove(_handleCircleTap);
      controller.removeListener(_onCameraChanged);
    }
    super.dispose();
  }

  void _onCameraChanged() {
    // Fired on every camera move (not just once it settles) since the
    // controller is a ChangeNotifier - keeps the floating 3D preview
    // glued to its marker while panning/zooming/tilting.
    _updateModelScreenPosition();
  }

  Future<void> _updateModelScreenPosition() async {
    final controller = _controller;
    final property = widget.selectedProperty;
    if (controller == null || property == null) {
      if (_modelScreenPos != null && mounted) {
        setState(() => _modelScreenPos = null);
      }
      return;
    }
    // Discards stale responses if several of these are in flight at once
    // (e.g. a burst of camera-move events during a fast drag).
    final requestId = ++_screenPosRequestId;
    try {
      final point = await controller.toScreenLocation(
        LatLng(property.latitude, property.longitude),
      );
      if (!mounted || requestId != _screenPosRequestId) return;
      setState(() {
        _modelScreenPos = math.Point(point.x.toDouble(), point.y.toDouble());
      });
    } catch (_) {
      // Can happen transiently while a style (re)load is in progress
      // (e.g. right after switching Map <-> Satellite); safe to ignore,
      // the next camera event will retry.
    }
  }

  String _colorForType(String type) {
    switch (type) {
      case 'Ballroom':
        return '#E17055';
      case 'Convention Hall':
        return '#0984E3';
      case 'Outdoor':
        return '#00B894';
      case 'Exhibition':
        return '#FDCB6E';
      case 'Meeting Room':
        return '#636E72';
      default:
        return '#2D3436';
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    // Switching Map <-> Satellite recreates the controller (see the
    // ValueKey(_mode) on MapLibreMap below), so the old one's listener
    // must be detached before swapping in the new one.
    _controller?.removeListener(_onCameraChanged);
    _controller = controller;
    controller.onCircleTapped.add(_handleCircleTap);
    controller.addListener(_onCameraChanged);
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    // The camera position itself doesn't change on a style reload, but
    // the controller instance does, so refresh against the new one.
    _updateModelScreenPosition();

    // Style reloads (e.g. switching Map <-> Satellite) reset the
    // projection/sky back to flat mercator, so re-apply globe mode
    // here too - this is a MapLibre style-reload characteristic.
    if (_globe) {
      await _applyGlobeProjection(controller, true);
    }

    _circleByPropertyId.clear();
    _propertyByCircleId.clear();
    _labelByPropertyId.clear();

    for (final property in widget.properties) {
      final selected = property.id == widget.selectedProperty?.id;
      final geometry = LatLng(property.latitude, property.longitude);
      final circle = await controller.addCircle(
        CircleOptions(
          geometry: geometry,
          circleRadius: selected ? 13 : 9,
          circleColor: selected ? '#6C5CE7' : _colorForType(property.type),
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2.2,
          circleOpacity: 0.95,
        ),
      );
      _circleByPropertyId[property.id] = circle;
      _propertyByCircleId[circle.id] = property;

      final label = await controller.addSymbol(
        SymbolOptions(
          geometry: geometry,
          textField: property.name,
          textSize: 12,
          textOffset: const Offset(0, 1.4), // below the circle
          textAnchor: 'top',
          textColor: '#1B2136',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.2,
        ),
      );
      _labelByPropertyId[property.id] = label;
    }
  }

  void _handleCircleTap(Circle circle) {
    final property = _propertyByCircleId[circle.id];
    if (property != null) widget.onMarkerTap(property);
  }

  Future<void> _applySelectionHighlight({Property? previous}) async {
    final controller = _controller;
    if (controller == null) return;

    if (previous != null) {
      final circle = _circleByPropertyId[previous.id];
      if (circle != null) {
        await controller.updateCircle(
          circle,
          CircleOptions(circleRadius: 9, circleColor: _colorForType(previous.type)),
        );
      }
    }
    final selected = widget.selectedProperty;
    if (selected != null) {
      final circle = _circleByPropertyId[selected.id];
      if (circle != null) {
        await controller.updateCircle(
          circle,
          const CircleOptions(circleRadius: 13, circleColor: '#6C5CE7'),
        );
      }
    }
  }

  void _onCameraIdle() {
    final position = _controller?.cameraPosition;
    if (position != null) _camera = position;
  }

  void _switchMode(MapLayerMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
  }

  void _zoomBy(double delta) {
    _controller?.animateCamera(CameraUpdate.zoomBy(delta));
  }

  void _recenter() {
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _initialCenter, zoom: _initialZoom, tilt: 0, bearing: 0),
      ),
    );
    setState(() => _tilted = false);
  }

  void _toggleTilt() {
    final next = !_tilted;
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _camera.target,
          zoom: _camera.zoom,
          tilt: next ? 55 : 0,
          bearing: next ? 30 : 0,
        ),
      ),
    );
    setState(() => _tilted = next);
  }

  /// Globe projection (MapLibre GL JS 5+) - real spherical Earth
  /// rendering, no Cesium/iframe needed. Web-only: MapLibre Native on
  /// Android/iOS doesn't implement it yet, so this is a no-op there.
  Future<void> _applyGlobeProjection(MapLibreMapController controller, bool enabled) async {
    try {
      await controller.setProjection(enabled ? 'globe' : 'mercator');
      if (enabled) {
        await controller.setSky(
          const SkyProperties(
            skyColor: '#1B2136',
            horizonColor: '#6C5CE7',
            fogColor: '#E9ECF7',
            fogGroundBlend: 0.5,
            horizonFogBlend: 0.6,
            skyHorizonBlend: 0.7,
          ),
        );
      }
    } catch (_) {
      // Thrown on Android/iOS (UnsupportedError) - safe to ignore,
      // the map just stays flat there.
    }
  }

  Future<void> _toggleGlobe() async {
    final controller = _controller;
    final next = !_globe;
    setState(() => _globe = next);
    if (controller != null) {
      await _applyGlobeProjection(controller, next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedProperty;
    final modelScreenPos = _modelScreenPos;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                // Keying by mode forces a clean style reload (with a fresh
                // controller) when switching Map <-> Satellite, since the
                // two use entirely different style sources.
                child: MapLibreMap(
                  key: ValueKey(_mode),
                  styleString: _mode == MapLayerMode.satellite ? _satelliteStyleJson() : _streetsStyleUrl,
                  initialCameraPosition: _camera,
                  trackCameraPosition: true,
                  onMapCreated: _onMapCreated,
                  onStyleLoadedCallback: _onStyleLoaded,
                  onCameraIdle: _onCameraIdle,
                  myLocationEnabled: false,
                  compassEnabled: false,
                  attributionButtonPosition: AttributionButtonPosition.bottomLeft,
                ),
              ),
              if (selected != null && modelScreenPos != null)
                _FloatingModelPreview(
                  // One instance per property: switching selection swaps
                  // the widget (and its 3D viewer) instead of reusing state
                  // meant for a different model.
                  key: ValueKey(selected.id),
                  property: selected,
                  anchor: modelScreenPos,
                  mapSize: constraints.biggest,
                ),
              Positioned(
                right: 16,
                bottom: 16,
                child: _MapControls(
                  mode: _mode,
                  tilted: _tilted,
                  onModeChanged: _switchMode,
                  onZoomIn: () => _zoomBy(1),
                  onZoomOut: () => _zoomBy(-1),
                  onToggleTilt: _toggleTilt,
                  onRecenter: _recenter,
                  globe: _globe,
                  onToggleGlobe: _toggleGlobe,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Mini 3D preview that floats directly above a property's marker on the
/// map, tracking [anchor] (its screen-space position) as the camera moves.
///
/// This is a screen-space "billboard": it stays flat and doesn't tilt or
/// rotate with the map's own 3D perspective, but it's genuinely pinned to
/// the marker's location, not to a fixed corner of the screen.
class _FloatingModelPreview extends StatelessWidget {
  final Property property;
  final math.Point<double> anchor;
  final Size mapSize;

  static const double _width = 210;
  static const double _height = 150;
  static const double _gap = 16; // gap between marker and bubble
  static const double _tailSize = 14;

  const _FloatingModelPreview({
    super.key,
    required this.property,
    required this.anchor,
    required this.mapSize,
  });

  @override
  Widget build(BuildContext context) {
    // Off the visible map area entirely (scrolled/tilted out of view) ->
    // don't draw a preview dangling off in space.
    final bool offscreen = anchor.x < -_width ||
        anchor.x > mapSize.width + _width ||
        anchor.y < -_height ||
        anchor.y > mapSize.height + _height;
    if (offscreen) return const SizedBox.shrink();

    // Anchor horizontally on the marker, clamped so the bubble stays
    // fully inside the map viewport.
    final double maxLeft = math.max(8.0, mapSize.width - _width - 8);
    final double left = (anchor.x - _width / 2).clamp(8.0, maxLeft);

    // Prefer floating above the marker; flip below it if there isn't
    // enough room at the top of the map.
    double top = anchor.y - _height - _gap;
    final bool flipBelow = top < 8;
    if (flipBelow) top = anchor.y + _gap;

    final double tailCenterX = anchor.x.clamp(left + 24, left + _width - 24);

    return Stack(
      children: [
        // Small triangular tail connecting the bubble to the marker.
        Positioned(
          left: tailCenterX - _tailSize / 2,
          top: flipBelow ? top - _tailSize / 2 : top + _height - _tailSize / 2,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: _tailSize,
              height: _tailSize,
              decoration: const BoxDecoration(
                color: AppColors.charcoal,
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: _width,
          height: _height,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.floating,
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Model3DViewer(property: property, compact: true),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: _MiniIconButton(
                    icon: Icons.fullscreen,
                    tooltip: 'Fullscreen',
                    onTap: () => showModelFullscreen(context, property),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Icon(icon, size: 14, color: Colors.white.withOpacity(0.9)),
        ),
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  final MapLayerMode mode;
  final bool tilted;
  final bool globe;
  final ValueChanged<MapLayerMode> onModeChanged;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onToggleTilt;
  final VoidCallback onRecenter;
  final VoidCallback onToggleGlobe;

  const _MapControls({
    required this.mode,
    required this.tilted,
    required this.globe,
    required this.onModeChanged,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onToggleTilt,
    required this.onRecenter,
    required this.onToggleGlobe,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Streets / Satellite toggle
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: AppShadows.subtle,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeButton(
                label: 'Map',
                icon: Icons.map_outlined,
                selected: mode == MapLayerMode.streets,
                onTap: () => onModeChanged(MapLayerMode.streets),
              ),
              _ModeButton(
                label: 'Satellite',
                icon: Icons.satellite_alt_outlined,
                selected: mode == MapLayerMode.satellite,
                onTap: () => onModeChanged(MapLayerMode.satellite),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Globe projection toggle
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: AppShadows.subtle,
          ),
          child: IconButton(
            tooltip: globe ? 'Flat map' : 'Globe view (web only)',
            icon: Icon(Icons.public, size: 18, color: globe ? AppColors.accent : AppColors.textSecondary),
            onPressed: onToggleGlobe,
          ),
        ),
        const SizedBox(height: 10),
        // 3D tilt toggle
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: AppShadows.subtle,
          ),
          child: IconButton(
            tooltip: tilted ? 'Flat view' : '3D tilt view',
            icon: Icon(Icons.view_in_ar_outlined, size: 18, color: tilted ? AppColors.accent : AppColors.textSecondary),
            onPressed: onToggleTilt,
          ),
        ),
        const SizedBox(height: 10),
        // Zoom + recenter
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: AppShadows.subtle,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.add, size: 18), onPressed: onZoomIn),
              Container(height: 1, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 8)),
              IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: onZoomOut),
              Container(height: 1, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 8)),
              IconButton(icon: const Icon(Icons.my_location, size: 16), onPressed: onRecenter),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
