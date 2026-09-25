import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Opens [CoordinatePickerDialog] and returns the picked [LatLng], or
/// null if the user closed the dialog without confirming.
Future<LatLng?> pickCoordinateOnMap(BuildContext context, LatLng initial) {
  return showDialog<LatLng>(
    context: context,
    builder: (_) => CoordinatePickerDialog(initial: initial),
  );
}

/// Dialog for picking a lat/lng: a fixed center pin plus a "use this
/// location" button, rather than tap-to-place - avoids having to
/// draw/manage a movable marker on top of the map. Shared by the
/// Eventaris form and the "Ubah Koordinat" action on the map view.
class CoordinatePickerDialog extends StatefulWidget {
  final LatLng initial;
  const CoordinatePickerDialog({super.key, required this.initial});

  @override
  State<CoordinatePickerDialog> createState() => _CoordinatePickerDialogState();
}

class _CoordinatePickerDialogState extends State<CoordinatePickerDialog> {
  MapLibreMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Geser peta agar pin berada di lokasi aset',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MapLibreMap(
                    styleString: 'https://tiles.openfreemap.org/styles/liberty',
                    initialCameraPosition: CameraPosition(target: widget.initial, zoom: 15),
                    trackCameraPosition: true,
                    onMapCreated: (c) => _controller = c,
                    myLocationEnabled: false,
                  ),
                  const Icon(Icons.location_pin, size: 40, color: Colors.redAccent),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: () {
                  final target = _controller?.cameraPosition?.target ?? widget.initial;
                  Navigator.of(context).pop(target);
                },
                child: const Text('Gunakan Lokasi Ini'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
