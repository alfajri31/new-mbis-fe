import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Form-field label where a trailing "*" (required marker) is rendered in red
/// so wajib fields stand out (user feedback).
///
/// Call sites keep embedding the star in the label string (e.g.
/// `'Nama Customer *'`); this splits it off and colors it.
Widget fieldLabel(
  String label, {
  TextStyle style = const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
}) {
  final trimmed = label.trimRight();
  if (!trimmed.endsWith('*')) return Text(label, style: style);
  final base = trimmed.substring(0, trimmed.length - 1).trimRight();
  return Text.rich(TextSpan(
    text: base,
    style: style,
    children: [
      TextSpan(text: ' *', style: style.copyWith(color: AppColors.errorRed)),
    ],
  ));
}
