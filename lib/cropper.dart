import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme.dart';

/// Abre o editor de imagem (zoom + posição) e devolve os bytes recortados.
/// [aspect] = largura / altura do quadro. [outWidth] = largura final em px.
Future<Uint8List?> showImageCropper(
  BuildContext context,
  Uint8List bytes, {
  required double aspect,
  required int outWidth,
  String title = 'Ajustar imagem',
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  if (!context.mounted) return null;

  return Navigator.of(context).push<Uint8List>(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => _CropperScreen(
        image: image,
        aspect: aspect,
        outWidth: outWidth,
        title: title,
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _CropperScreen extends StatefulWidget {
  final ui.Image image;
  final double aspect;
  final int outWidth;
  final String title;

  const _CropperScreen({
    required this.image,
    required this.aspect,
    required this.outWidth,
    required this.title,
  });

  @override
  State<_CropperScreen> createState() => _CropperScreenState();
}

class _CropperScreenState extends State<_CropperScreen> {
  double _zoom = 1.0; // 1.0 (afastado) .. 4.0 (perto)
  Offset _offset = Offset.zero;
  double _startZoom = 1.0;
  bool _saving = false;
  Size _lastFrame = Size.zero;

  Size _frameSize(BoxConstraints c) {
    final maxW = c.maxWidth - 40;
    final maxH = c.maxHeight - 40;
    var w = maxW;
    var h = w / widget.aspect;
    if (h > maxH) {
      h = maxH;
      w = h * widget.aspect;
    }
    return Size(w, h);
  }

  /// Escala base: imagem cobre o quadro inteiro quando zoom = 1
  double _baseScale(Size frame) {
    return math.max(
      frame.width / widget.image.width,
      frame.height / widget.image.height,
    );
  }

  Offset _clampOffset(Offset off, Size frame) {
    final s = _baseScale(frame) * _zoom;
    final maxDx =
        math.max(0.0, (widget.image.width * s - frame.width) / 2);
    final maxDy =
        math.max(0.0, (widget.image.height * s - frame.height) / 2);
    return Offset(
      off.dx.clamp(-maxDx, maxDx),
      off.dy.clamp(-maxDy, maxDy),
    );
  }

  Future<void> _confirm(Size frame) async {
    setState(() => _saving = true);
    try {
      final s = _baseScale(frame) * _zoom;
      final img = widget.image;

      // região visível da imagem (coordenadas da imagem original)
      final srcW = frame.width / s;
      final srcH = frame.height / s;
      final srcX = img.width / 2 - _offset.dx / s - srcW / 2;
      final srcY = img.height / 2 - _offset.dy / s - srcH / 2;

      final outW = widget.outWidth;
      final outH = (outW / widget.aspect).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(srcX, srcY, srcW, srcH),
        Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final out = await recorder.endRecording().toImage(outW, outH);
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.of(context).pop(data?.buffer.asUint8List());
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NimoColors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Topo
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    'Arraste para posicionar',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: NimoColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            // Área de edição
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final frame = _frameSize(c);
                  _lastFrame = frame;
                  final s = _baseScale(frame) * _zoom;

                  return Center(
                    child: GestureDetector(
                      onScaleStart: (d) {
                        _startZoom = _zoom;
                      },
                      onScaleUpdate: (d) {
                        setState(() {
                          _zoom = (_startZoom * d.scale).clamp(1.0, 4.0);
                          _offset = _clampOffset(
                              _offset + d.focalPointDelta, frame);
                        });
                      },
                      child: Container(
                        width: frame.width,
                        height: frame.height,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                              widget.aspect == 1 ? 26 : 18),
                          border: Border.all(
                              color: NimoColors.blue, width: 2),
                        ),
                        child: CustomPaint(
                          painter: _ImagePainter(
                            image: widget.image,
                            scale: s,
                            offset: _offset,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Slider de zoom
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
              child: Row(
                children: [
                  const Icon(Icons.zoom_out,
                      size: 22, color: NimoColors.textMuted),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: NimoColors.blue,
                        inactiveTrackColor: const Color(0xFF1B1B20),
                        thumbColor: Colors.white,
                        overlayColor:
                            NimoColors.blue.withOpacity(0.15),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _zoom,
                        min: 1.0,
                        max: 4.0,
                        onChanged: (v) => setState(() {
                          _zoom = v;
                          if (_lastFrame != Size.zero) {
                            _offset = _clampOffset(_offset, _lastFrame);
                          }
                        }),
                      ),
                    ),
                  ),
                  const Icon(Icons.zoom_in,
                      size: 22, color: NimoColors.textMuted),
                ],
              ),
            ),
            // Confirmar
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
              child: GestureDetector(
                onTap: _saving || _lastFrame == Size.zero
                    ? null
                    : () => _confirm(_lastFrame),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _saving
                        ? NimoColors.blue.withOpacity(0.6)
                        : NimoColors.blue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Usar imagem',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePainter extends CustomPainter {
  final ui.Image image;
  final double scale;
  final Offset offset;

  _ImagePainter({
    required this.image,
    required this.scale,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.medium;
    final w = image.width * scale;
    final h = image.height * scale;
    final dst = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2) + offset,
      width: w,
      height: h,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(
          0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ImagePainter old) =>
      old.scale != scale || old.offset != offset || old.image != image;
}
