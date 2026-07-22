/// ProfessorOS – Avatar color helper.
/// Generates consistent pastel background colors from user name hash.

import 'package:flutter/material.dart';

class AvatarHelper {
  AvatarHelper._();

  /// List of pastel colours for avatar backgrounds.
  static const List<Color> _pastelColors = [
    Color(0xFFCCFBF1), // teal pastel
    Color(0xFFDDD6FE), // violet pastel
    Color(0xFFFBCFE8), // pink pastel
    Color(0xFFFDE68A), // yellow pastel
    Color(0xFFBFDBFE), // blue pastel
    Color(0xFFA7F3D0), // green pastel
    Color(0xFFFED7AA), // orange pastel
    Color(0xFFE9D5FF), // purple pastel
  ];

  /// Get a consistent pastel color for a given name.
  static Color colorFor(String name) {
    final hash = name.hashCode.abs();
    return _pastelColors[hash % _pastelColors.length];
  }

  /// Get the initials (up to 2 chars) from a full name.
  static String initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
