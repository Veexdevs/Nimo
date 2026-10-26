import 'package:flutter/material.dart';

/// ============================================================
/// Escala global — mantém o "zoom afastado" em qualquer tela
/// ============================================================
class ZoomFit extends StatelessWidget {
  final Widget child;

  /// Largura de referência do layout (quanto maior, mais "afastado")
  final double designWidth;

  const ZoomFit({
    super.key,
    required this.child,
    this.designWidth = 640,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final scale = (c.maxWidth / designWidth).clamp(0.45, 1.0);
        if (scale >= 1.0) return child;
        return FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: designWidth,
            height: c.maxHeight / scale,
            child: child,
          ),
        );
      },
    );
  }
}
