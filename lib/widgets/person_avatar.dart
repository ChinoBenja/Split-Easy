import 'package:flutter/material.dart';
import 'profile_photo_image.dart';

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    this.photoSource,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String name;
  final String? photoSource;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    final fallback = Text(
      initials.isEmpty ? '?' : initials,
      style: TextStyle(
        color: foregroundColor ?? colors.onSecondaryContainer,
        fontWeight: FontWeight.w700,
      ),
    );
    final source = photoSource?.trim();

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? colors.secondaryContainer,
      child: source == null || source.isEmpty
          ? fallback
          : ClipOval(
              child: SizedBox.expand(
                child: ProfilePhotoImage(
                  source: source,
                  fit: BoxFit.cover,
                  fallback: Center(child: fallback),
                ),
              ),
            ),
    );
  }
}
