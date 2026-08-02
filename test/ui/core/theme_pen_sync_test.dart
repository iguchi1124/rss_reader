import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/ui/core/theme.dart';

/// Set to regenerate the design file instead of asserting against it:
/// `UPDATE_PEN_VARIABLES=1 flutter test test/ui/core/theme_pen_sync_test.dart`
const _updateEnvVariable = 'UPDATE_PEN_VARIABLES';

const _penFilePath = 'design/rss_reader.pen';

Map<String, Color> _colorRoles(ColorScheme scheme) => {
  'primary': scheme.primary,
  'primaryContainer': scheme.primaryContainer,
  'onPrimaryContainer': scheme.onPrimaryContainer,
  'surface': scheme.surface,
  'onSurface': scheme.onSurface,
  'surfaceContainerHighest': scheme.surfaceContainerHighest,
  'onSurfaceVariant': scheme.onSurfaceVariant,
  'outline': scheme.outline,
  'outlineVariant': scheme.outlineVariant,
  'error': scheme.error,
  'surfaceTint': scheme.surfaceTint,
};

Map<String, double?> _textSizes(TextTheme text) => {
  'headlineSmall': text.headlineSmall?.fontSize,
  'titleLarge': text.titleLarge?.fontSize,
  'titleMedium': text.titleMedium?.fontSize,
  'titleSmall': text.titleSmall?.fontSize,
  'bodyLarge': text.bodyLarge?.fontSize,
  'bodyMedium': text.bodyMedium?.fontSize,
  'bodySmall': text.bodySmall?.fontSize,
  'labelLarge': text.labelLarge?.fontSize,
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
    for (final entry in _textSizes(light.textTheme).entries)
      'text.${entry.key}.size': {'type': 'number', 'value': entry.value},
  };
}

void main() {
  test('pen.dev variables match AppTheme', () {
    final file = File(_penFilePath);
    final document =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final fromTheme = _variablesFromTheme();

    if (Platform.environment.containsKey(_updateEnvVariable)) {
      document['variables'] = fromTheme;
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(document)}\n',
      );
      return;
    }

    expect(
      document['variables'],
      fromTheme,
      reason:
          '$_penFilePath is out of sync with AppTheme. '
          'Regenerate it with $_updateEnvVariable=1.',
    );
  });
}
