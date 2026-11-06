import 'dart:convert';

import 'package:flutter/material.dart';

class ProfilePhotoImage extends StatelessWidget {
  const ProfilePhotoImage({
    super.key,
    required this.source,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final String source;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final commaIndex = source.indexOf(',');
    if (source.startsWith('data:image/') && commaIndex >= 0) {
      try {
        return Image.memory(
          base64Decode(source.substring(commaIndex + 1)),
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
        );
      } on FormatException {
        return fallback;
      }
    }

    return Image.network(source, fit: fit, errorBuilder: (_, _, _) => fallback);
  }
}
