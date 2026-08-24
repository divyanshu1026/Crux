import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Shows an image the user picked from their own device, on every platform
/// Crux runs on.
///
/// `Image.file` asserts outright on Flutter Web — "Image.file is not supported
/// on Flutter Web" — which crashed the whole Dashboard the moment a progress
/// photo existed. On web `image_picker` hands back a `blob:` URL, which
/// `Image.network` loads happily, so the platform decides which loader to use.
///
/// Both paths share one failure story: a picked file lives in a cache
/// directory the OS may clear, and a blob URL dies when the tab reloads. A
/// missing photo is normal, not exceptional, so it renders as a quiet
/// placeholder rather than an error.
class CxLocalImage extends StatelessWidget {
  const CxLocalImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Shown when the file is gone. Defaults to a muted broken-image tile.
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    Widget onError(BuildContext context, Object error, StackTrace? stack) =>
        placeholder ?? _defaultPlaceholder(context);

    if (kIsWeb) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: onError,
      );
    }
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: onError,
    );
  }

  Widget _defaultPlaceholder(BuildContext context) {
    final c = context.cx;
    return Container(
      width: width,
      height: height,
      color: c.surfaceHigh,
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_rounded, color: c.textTertiary),
    );
  }
}
