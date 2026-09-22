# Eventary — Flutter Web Prototype

Prototype frontend for an event/property visualization platform:
**Map → Select Property → Property Details → 3D Preview**.

No backend, no database, no API keys — everything runs on local
dummy data (`lib/data/dummy_properties.dart`).

## What's included

```
lib/
├── main.dart                     # App entry point
├── models/
│   └── property.dart             # Property data model
├── data/
│   └── dummy_properties.dart     # 7 dummy venues (local data), one with a 3D model
├── screens/
│   └── home_screen.dart          # Dashboard: sidebar + map + detail panel
├── widgets/
│   ├── sidebar.dart               # Left nav (Dashboard/Properties/Events/Settings)
│   ├── property_map.dart          # Mock map + clickable markers
│   ├── property_card.dart         # Marker popup card ("View Details")
│   ├── property_detail.dart       # Full detail panel
│   └── model_3d_viewer.dart       # Real .glb viewer (model_viewer_plus) + placeholder cube fallback
└── theme/
    └── app_theme.dart              # Colors, radii, shadows, ThemeData
assets/
└── models/
    └── TerasKantorTechnoGIS_web.glb   # Blender model, textures shrunk for the web (~11 MB)
tools/
└── optimize_glb.py               # Shrinks textures inside a .glb (Pillow)
pubspec.yaml
```

## Why there's no `web/`, `android/`, etc. folder here

Those platform folders are auto-generated boilerplate that `flutter
create` writes for your specific installed Flutter SDK version. It's
more reliable to let your own Flutter install generate them fresh
than to ship a copy here that might not match your SDK. Setup below
handles that in step 1.

## How to run it

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install)
installed and `flutter doctor` reporting Chrome/web support available.

1. **Scaffold a fresh Flutter project** (this generates the `web/`,
   `android/`, etc. platform folders for your SDK version):
   ```bash
   flutter create eventary_prototype
   cd eventary_prototype
   ```

2. **Replace the generated `lib/` folder and `pubspec.yaml`** with the
   ones from this package — copy this package's `lib/` directory,
   `assets/` directory and `pubspec.yaml` into the project, overwriting
   the generated versions.

3. **Get packages.** This version uses a real vector map via
   `maplibre_gl` (MapLibre GL Native / MapLibre GL JS) — free, no API
   key needed, with two style sources: OpenFreeMap "Liberty" for the
   street/3D-buildings view, and a small raster style built at runtime
   as a JSON string (Esri World Imagery) for satellite. `pubspec.yaml`
   already lists `maplibre_gl`, so:
   ```bash
   flutter pub get
   ```
   If that reports a version conflict (package versions move fast),
   run this instead to let pub pick the latest compatible version:
   ```bash
   flutter pub add maplibre_gl
   ```

4. **Platform setup (Android/iOS only).** If you're only targeting
   Chrome/web, skip this step — `maplibre_gl` needs no web-specific
   setup. For Android/iOS, follow the plugin's short "Getting
   Started" platform guide (minimum SDK versions, iOS permissions
   entry) at https://maplibre.org/flutter-maplibre-gl/.

5. **Load the 3D viewer script (web only).** `model_viewer_plus` needs
   one line in the `<head>` of the generated `web/index.html`:
   ```html
   <script type="module" src="./assets/packages/model_viewer_plus/assets/model-viewer.min.js" defer></script>
   ```
   Without it the 3D area stays empty (no error in Flutter, but the
   browser console shows `model-viewer` is not defined).

6. **Run in Chrome:**
   ```bash
   flutter run -d chrome
   ```
   Or build a static release bundle:
   ```bash
   flutter build web
   # output in build/web — serve with any static file server
   ```

## Using the prototype

- The map is a real, pannable/zoomable/rotatable vector map with
  actual building footprints. Toggle **globe (🌐)** on the right side
  of the map to switch to a genuine spherical globe projection — real
  round-Earth rendering via MapLibre, no Cesium/iframe needed (web
  only; falls back to a flat map automatically on Android/iOS, since
  MapLibre Native doesn't support it there yet). Toggle **"3D"** to
  tilt the camera and see buildings rendered as extrusions. Toggle
  **Map / Satellite** to switch to Esri satellite imagery — no API key
  needed for any of these.
- Click any marker (a small circle) on the map to see a quick info
  popup.
- Click **"View Details"** to open the full property panel with the
  3D preview area.
- Drag inside the 3D area to rotate. For a venue with a real model
  ("Teras Kantor TechnoGIS") scroll to zoom and use the fullscreen icon;
  the placeholder cube also has zoom/reset buttons in its toolbar.
- Use the search bar and type filter chips above the map to narrow
  down the venue list.
- On narrow windows, the sidebar collapses into a drawer (tap the
  menu icon top-left).

## Note on the real map

Unlike the rest of the prototype, map tiles are fetched live from
OpenFreeMap / Esri over the internet, so an internet connection is
needed while running the app (this is the only part of the prototype
that isn't fully offline/local). Switching between Map and Satellite
reloads the underlying map style, so the camera briefly resets to the
last known position/zoom — this is a MapLibre style-reload
characteristic, not a bug. Markers are plain colored `Circle`
annotations (not custom icons per venue type) because `maplibre_gl`
renders annotations natively rather than as arbitrary Flutter
widgets — swapping in custom icon images later is possible via
`controller.addImage()` + `SymbolOptions` if you want per-type marker
icons.

## About the 3D preview

`Property.modelAssetPath` decides what the 3D area shows:

- **Set** (e.g. `assets/models/TerasKantorTechnoGIS_web.glb`): the real
  `.glb` is rendered with `model_viewer_plus` (Google's `<model-viewer>`).
  Drag to orbit, scroll to zoom, right-drag to pan.
- **Null**: the interactive placeholder cube from the earlier prototype.

The flow is still Map → click marker → popup → **View Details** → detail
panel with the 3D preview. The **View 3D** button (and the fullscreen icon)
opens the same viewer in a large dialog.

### Adding another Blender model

1. In Blender: **File → Export → glTF 2.0**, format **glTF Binary (.glb)**.
   Apply modifiers/transforms first, keep 1 Blender unit = 1 metre, and put
   the object's origin at the centre of its base.
2. Shrink it for the web (textures are usually 90 % of the file size):
   ```bash
   pip install pillow numpy
   python3 tools/optimize_glb.py my_model.glb assets/models/my_model_web.glb
   ```
   Use `--max-size 2048` if textures look too soft. Better still, export
   from Blender with JPEG textures at 1024 px (Export dialog → Material →
   Images) and skip this step.
3. Set `modelAssetPath: 'assets/models/my_model_web.glb'` on the property.

`assets/models/` is declared in `pubspec.yaml`, so no other change is needed.

If the model doesn't appear, open the browser DevTools → Network tab and
check whether the `.glb` request fails (wrong path / 404), and the Console
for `model-viewer` errors.

## Extending toward a real backend later

Everything data-related is isolated behind two seams so a Python/REST
backend can be dropped in later with minimal UI changes:

- `Property` (in `models/property.dart`) is a plain data class — it
  can be generated from JSON without changing any widget.
- `dummyProperties` (in `data/dummy_properties.dart`) is the single
  place returning `List<Property>` — replace it with a repository
  class that calls your future API, and `home_screen.dart` doesn't
  need to know the difference.
