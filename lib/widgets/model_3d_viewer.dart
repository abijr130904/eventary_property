import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../models/property.dart';
import '../theme/app_theme.dart';

/// 3D preview for a property.
///
/// * If [Property.modelAssetPath] is set, the real `.glb` model (exported
///   from Blender) is rendered with `model_viewer_plus`, which wraps
///   Google's `<model-viewer>` web component. Orbit / zoom / pan are handled
///   by the component itself (drag, scroll, right-drag).
/// * If it is null, an interactive placeholder cube is drawn instead, so a
///   property without a model still gets a 3D-looking preview.
///
/// The badge, toolbar and fullscreen dialog around the viewer are shared.
class Model3DViewer extends StatelessWidget {
  final Property property;
  final bool compact;

  /// True when the viewer is shown inside the fullscreen dialog: hides the
  /// fullscreen button (no dialog on top of a dialog) and leaves room for
  /// the dialog's close button.
  final bool inDialog;

  const Model3DViewer({
    super.key,
    required this.property,
    this.compact = false,
    this.inDialog = false,
  });

  @override
  Widget build(BuildContext context) {
    final path = property.modelAssetPath;
    if (path == null || path.isEmpty) {
      return _PlaceholderViewer(
        property: property,
        compact: compact,
        inDialog: inDialog,
      );
    }
    return _GlbViewer(
      // One viewer per model file: switching between two properties that
      // both have a model reloads the viewer with the new file.
      key: ValueKey(path),
      property: property,
      assetPath: path,
      compact: compact,
      inDialog: inDialog,
    );
  }
}

/// Opens the 3D preview in a large dialog. Used by the fullscreen button on
/// the inline viewer and by the "View 3D" button in the detail panel.
void showModelFullscreen(BuildContext context, Property property) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.75),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.charcoal,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg - 4),
              child: SizedBox(
                width: 900,
                height: 620,
                child: Model3DViewer(property: property, inDialog: true),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IconButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Real model (.glb)
// ---------------------------------------------------------------------------

class _GlbViewer extends StatefulWidget {
  final Property property;
  final String assetPath;
  final bool compact;
  final bool inDialog;

  const _GlbViewer({
    super.key,
    required this.property,
    required this.assetPath,
    required this.compact,
    required this.inDialog,
  });

  @override
  State<_GlbViewer> createState() => _GlbViewerState();
}

class _GlbViewerState extends State<_GlbViewer> {
  // Built once per viewer. HomeScreen rebuilds on every keystroke in the
  // search box and on every marker tap; reusing the same widget instance
  // keeps those rebuilds from reaching the underlying <model-viewer>.
  late final Widget _viewer = ModelViewer(
    src: widget.assetPath,
    alt: '3D model of ${widget.property.name}',
    ar: false,
    autoRotate: true,
    cameraControls: true,
    environmentImage: 'neutral', // evenly lit, so interiors aren't too dark
    backgroundColor: AppColors.charcoal,
    debugLogging: false,
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        color: AppColors.charcoal,
        child: Stack(
          children: [
            Positioned.fill(child: _viewer),
            const Positioned(
              left: 14,
              top: 14,
              child: IgnorePointer(child: _Badge(text: '3D model')),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    'Drag to rotate, scroll to zoom',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
            // model-viewer has its own orbit/zoom controls, so the only
            // toolbar action left is fullscreen.
            if (!widget.compact && !widget.inDialog)
              Positioned(
                right: 10,
                top: 10,
                child: _Toolbar(
                  onFullscreen: () =>
                      showModelFullscreen(context, widget.property),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder cube (used when a property has no .glb yet)
// ---------------------------------------------------------------------------

/// Lightweight, *actually interactive* pseudo-3D box drawn with a
/// [CustomPainter] and manual perspective projection. Drag to rotate; the
/// toolbar zooms / resets / goes fullscreen.
class _PlaceholderViewer extends StatefulWidget {
  final Property property;
  final bool compact;
  final bool inDialog;

  const _PlaceholderViewer({
    required this.property,
    required this.compact,
    required this.inDialog,
  });

  @override
  State<_PlaceholderViewer> createState() => _PlaceholderViewerState();
}

class _PlaceholderViewerState extends State<_PlaceholderViewer>
    with SingleTickerProviderStateMixin {
  double _rotY = -0.5;
  double _rotX = -0.35;
  double _zoom = 1.0;
  Offset _pan = Offset.zero;
  late AnimationController _autoRotate;

  @override
  void initState() {
    super.initState();
    _autoRotate = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _autoRotate.addListener(_onTick);
  }

  void _onTick() {
    // Gentle idle rotation so the placeholder feels alive; any manual
    // drag temporarily "wins" because onPanUpdate sets _rotY directly
    // and the small per-tick delta below is imperceptible next to a
    // drag gesture.
    setState(() {
      _rotY += 0.0009;
    });
  }

  @override
  void dispose() {
    _autoRotate.removeListener(_onTick);
    _autoRotate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.navyDark, AppColors.charcoal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  setState(() {
                    _rotY += details.delta.dx * 0.01;
                    _rotX = (_rotX - details.delta.dy * 0.01)
                        .clamp(-1.2, 1.2);
                  });
                },
                child: CustomPaint(
                  painter: _CubePainter(
                    rotX: _rotX,
                    rotY: _rotY,
                    zoom: _zoom,
                    pan: _pan,
                  ),
                ),
              ),
            ),
            // Placeholder badge
            Positioned(
              left: 14,
              top: 14,
              child: _Badge(text: 'PLACEHOLDER · .GLB READY'),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: Text(
                  '3D model for "${widget.property.name}" not loaded yet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            if (!widget.compact)
              Positioned(
                // In the dialog the close button sits in the top-right
                // corner, so shift the toolbar left of it.
                right: widget.inDialog ? 56 : 10,
                top: 10,
                child: _Toolbar(
                  onZoomIn: () =>
                      setState(() => _zoom = (_zoom + 0.15).clamp(0.5, 2.5)),
                  onZoomOut: () =>
                      setState(() => _zoom = (_zoom - 0.15).clamp(0.5, 2.5)),
                  onReset: () => setState(() {
                    _rotX = -0.35;
                    _rotY = -0.5;
                    _zoom = 1.0;
                    _pan = Offset.zero;
                  }),
                  onFullscreen: widget.inDialog
                      ? null
                      : () => showModelFullscreen(context, widget.property),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Small pill toolbar. Every action is optional; a button is only drawn
/// when its callback is provided.
class _Toolbar extends StatelessWidget {
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onReset;
  final VoidCallback? onFullscreen;

  const _Toolbar({
    this.onZoomIn,
    this.onZoomOut,
    this.onReset,
    this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final zoomIn = onZoomIn;
    final zoomOut = onZoomOut;
    final reset = onReset;
    final fullscreen = onFullscreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (zoomIn != null)
            _ToolButton(icon: Icons.add, onTap: zoomIn, tooltip: 'Zoom in'),
          if (zoomOut != null)
            _ToolButton(icon: Icons.remove, onTap: zoomOut, tooltip: 'Zoom out'),
          if (reset != null)
            _ToolButton(
                icon: Icons.refresh_rounded,
                onTap: reset,
                tooltip: 'Reset rotation'),
          if (fullscreen != null)
            _ToolButton(
                icon: Icons.fullscreen, onTap: fullscreen, tooltip: 'Fullscreen'),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _ToolButton({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 16, color: Colors.white.withOpacity(0.85)),
        ),
      ),
    );
  }
}

/// Draws a shaded cube using manual 3D -> 2D projection. This is the
/// "dummy 3D representation" - no external 3D engine required, but
/// genuinely responds to rotation/zoom input.
class _CubePainter extends CustomPainter {
  final double rotX;
  final double rotY;
  final double zoom;
  final Offset pan;

  _CubePainter({required this.rotX, required this.rotY, required this.zoom, required this.pan});

  static const List<List<double>> _vertices = [
    [-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1],
    [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1],
  ];

  static const List<List<int>> _faces = [
    [4, 5, 6, 7], // front
    [0, 1, 5, 4], // bottom
    [1, 2, 6, 5], // right
  ];

  static const List<double> _faceShade = [1.0, 0.62, 0.8];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2 + pan.dx, size.height / 2 + pan.dy);
    final scale = (math.min(size.width, size.height) / 4.6) * zoom;

    final cosY = math.cos(rotY), sinY = math.sin(rotY);
    final cosX = math.cos(rotX), sinX = math.sin(rotX);

    final projected = <Offset>[];
    final depths = <double>[];

    for (final v in _vertices) {
      double x = v[0], y = v[1], z = v[2];
      // rotate around Y axis
      final x1 = x * cosY + z * sinY;
      final z1 = -x * sinY + z * cosY;
      // rotate around X axis
      final y2 = y * cosX - z1 * sinX;
      final z2 = y * sinX + z1 * cosX;

      final perspective = 4 / (4 + z2);
      projected.add(Offset(center.dx + x1 * scale * perspective, center.dy + y2 * scale * perspective));
      depths.add(z2);
    }

    final facesWithDepth = <MapEntry<int, double>>[];
    for (int i = 0; i < _faces.length; i++) {
      final avgZ = _faces[i].map((idx) => depths[idx]).reduce((a, b) => a + b) / 4;
      facesWithDepth.add(MapEntry(i, avgZ));
    }
    facesWithDepth.sort((a, b) => b.value.compareTo(a.value));

    for (final entry in facesWithDepth) {
      final face = _faces[entry.key];
      final path = Path()..moveTo(projected[face[0]].dx, projected[face[0]].dy);
      for (final idx in face.skip(1)) {
        path.lineTo(projected[idx].dx, projected[idx].dy);
      }
      path.close();

      final shade = _faceShade[entry.key];
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          colors: [
            AppColors.accent.withOpacity(0.9 * shade),
            AppColors.accentSecondary.withOpacity(0.9 * shade),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(path.getBounds());

      canvas.drawPath(path, paint);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withOpacity(0.18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CubePainter oldDelegate) {
    return oldDelegate.rotX != rotX ||
        oldDelegate.rotY != rotY ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan;
  }
}
