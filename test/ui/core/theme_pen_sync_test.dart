import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/ui/core/theme.dart';

/// Set to regenerate the design file instead of asserting against it:
/// `UPDATE_PEN_VARIABLES=1 flutter test test/ui/core/theme_pen_sync_test.dart`
const _updateEnvVariable = 'UPDATE_PEN_VARIABLES';

const _penFilePath = 'design/rss_reader.pen';

/// Variables under these prefixes belong to this test; anything else in the
/// design file was added on the canvas and is left alone.
bool _isManaged(String name) =>
    name.startsWith('color.') || name.startsWith('text.');

Map<String, Color> _colorRoles(ColorScheme scheme) => {
  'primary': scheme.primary,
  'onPrimary': scheme.onPrimary,
  'primaryContainer': scheme.primaryContainer,
  'onPrimaryContainer': scheme.onPrimaryContainer,
  'secondary': scheme.secondary,
  'onSecondary': scheme.onSecondary,
  'secondaryContainer': scheme.secondaryContainer,
  'onSecondaryContainer': scheme.onSecondaryContainer,
  'surface': scheme.surface,
  'onSurface': scheme.onSurface,
  'surfaceContainerLowest': scheme.surfaceContainerLowest,
  'surfaceContainerLow': scheme.surfaceContainerLow,
  'surfaceContainer': scheme.surfaceContainer,
  'surfaceContainerHigh': scheme.surfaceContainerHigh,
  'surfaceContainerHighest': scheme.surfaceContainerHighest,
  'onSurfaceVariant': scheme.onSurfaceVariant,
  'outline': scheme.outline,
  'outlineVariant': scheme.outlineVariant,
  'error': scheme.error,
  'onError': scheme.onError,
  'errorContainer': scheme.errorContainer,
  'onErrorContainer': scheme.onErrorContainer,
  'inverseSurface': scheme.inverseSurface,
  'onInverseSurface': scheme.onInverseSurface,
  'surfaceTint': scheme.surfaceTint,
  'scrim': scheme.scrim,
};

/// `ThemeData.textTheme` carries colours only; the sizes arrive with the script
/// geometry that `Theme` applies from the locale, so a test outside a
/// `MaterialApp` has to apply it by hand or read every `fontSize` as null.
TextTheme _localizedTextTheme(ThemeData theme) =>
    ThemeData.localize(theme, theme.typography.englishLike).textTheme;

Map<String, double?> _textSizes(TextTheme text) => {
  'headlineSmall': text.headlineSmall?.fontSize,
  'titleLarge': text.titleLarge?.fontSize,
  'titleMedium': text.titleMedium?.fontSize,
  'titleSmall': text.titleSmall?.fontSize,
  'bodyLarge': text.bodyLarge?.fontSize,
  'bodyMedium': text.bodyMedium?.fontSize,
  'bodySmall': text.bodySmall?.fontSize,
  'labelLarge': text.labelLarge?.fontSize,
  'labelMedium': text.labelMedium?.fontSize,
  'labelSmall': text.labelSmall?.fontSize,
};

String _hex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Map<String, Object?> _variablesFromTheme() {
  final light = AppTheme.light();
  final dark = AppTheme.dark();
  final lightRoles = _colorRoles(light.colorScheme);
  final darkRoles = _colorRoles(dark.colorScheme);

  return {
    for (final role in lightRoles.keys)
      'color.$role': {
        'type': 'color',
        'value': [
          {
            'value': _hex(lightRoles[role]!),
            'theme': {'mode': 'light'},
          },
          {
            'value': _hex(darkRoles[role]!),
            'theme': {'mode': 'dark'},
          },
        ],
      },
    for (final entry in _textSizes(_localizedTextTheme(light)).entries)
      'text.${entry.key}.size': {'type': 'number', 'value': entry.value},
  };
}

void main() {
  test('pen.dev variables match AppTheme', () {
    final file = File(_penFilePath);
    final document =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final variables = document['variables'] as Map<String, dynamic>;
    final fromTheme = _variablesFromTheme();

    if (Platform.environment.containsKey(_updateEnvVariable)) {
      document['variables'] = {
        ...fromTheme,
        for (final entry in variables.entries)
          if (!_isManaged(entry.key)) entry.key: entry.value,
      };
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(document)}\n',
      );
      return;
    }

    final managed = {
      for (final entry in variables.entries)
        if (_isManaged(entry.key)) entry.key: entry.value,
    };

    expect(
      managed,
      fromTheme,
      reason:
          '$_penFilePath is out of sync with AppTheme. '
          'Regenerate it with $_updateEnvVariable=1.',
    );
  });
}
