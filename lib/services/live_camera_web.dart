import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

int _viewCount = 0;

/// Ouvre la caméra du navigateur et renvoie la photo prise (JPEG), ou null
/// si l'utilisateur annule. Aucun fichier existant ne peut être choisi.
Future<Uint8List?> captureLivePhoto(BuildContext context) =>
    showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LiveCameraDialog(),
    );

class _LiveCameraDialog extends StatefulWidget {
  const _LiveCameraDialog();

  @override
  State<_LiveCameraDialog> createState() => _LiveCameraDialogState();
}

class _LiveCameraDialogState extends State<_LiveCameraDialog> {
  final _viewType = 'live-camera-${_viewCount++}';
  final _video = web.HTMLVideoElement();
  web.MediaStream? _stream;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _video
      ..autoplay = true
      ..muted = true
      ..playsInline = true;
    _video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _video,
    );
    _start();
  }

  Future<void> _start() async {
    try {
      // Caméra arrière de préférence (téléphone), sinon la webcam.
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              video: web.MediaTrackConstraints(facingMode: 'environment'.toJS),
              audio: false.toJS,
            ),
          )
          .toDart;
      if (!mounted) {
        _stopTracks(stream);
        return;
      }
      _stream = stream;
      _video.srcObject = stream;
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Caméra indisponible. Autorisez l\'accès à la caméra dans '
              'votre navigateur, puis réessayez.',
        );
      }
    }
  }

  void _stopTracks(web.MediaStream stream) {
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }

  void _capture() {
    final vw = _video.videoWidth;
    final vh = _video.videoHeight;
    if (vw == 0 || vh == 0) return;
    // Même réduction que sur mobile : 1280 px de large au plus, JPEG 60 %.
    final scale = vw > 1280 ? 1280 / vw : 1.0;
    final canvas = web.HTMLCanvasElement()
      ..width = (vw * scale).round()
      ..height = (vh * scale).round();
    canvas.context2D.drawImage(_video, 0, 0, canvas.width, canvas.height);
    final url = canvas.toDataURL('image/jpeg', 0.6.toJS);
    Navigator.pop(context, base64Decode(url.substring(url.indexOf(',') + 1)));
  }

  @override
  void dispose() {
    final stream = _stream;
    if (stream != null) _stopTracks(stream);
    _video.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Photo de la station',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Annuler',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: ColoredBox(
                  color: Colors.black,
                  child: _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.no_photography_outlined,
                                  color: Colors.white70,
                                  size: 40,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            HtmlElementView(viewType: _viewType),
                            if (!_ready)
                              const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _ready ? _capture : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Prendre la photo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
