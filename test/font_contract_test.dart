import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Thmanyah Sans is the only application font family', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(sources, isNot(contains('Tajawal')));
    expect(sources, isNot(contains('IBMPlexSansArabic')));
    expect(sources, isNot(contains("fontFamily: 'Roboto'")));
    expect(sources, isNot(contains('PdfGoogleFonts')));
    expect(sources, contains("fontFamily: 'Thmanyah Sans'"));
  });

  test('web bootstrap and Flutter bundle include every required weight', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final index = File('web/index.html').readAsStringSync();

    for (final entry in {
      'Light': 300,
      'Regular': 400,
      'Medium': 500,
      'Bold': 700,
    }.entries) {
      expect(
        pubspec,
        contains('assets/fonts/ThmanyahSans-${entry.key}.ttf'),
      );
      expect(pubspec, contains('weight: ${entry.value}'));
      expect(
        index,
        contains('assets/assets/fonts/ThmanyahSans-${entry.key}.woff2'),
      );
      expect(index, contains('font-weight: ${entry.value}'));
    }

    expect(pubspec, contains('family: Thmanyah Sans'));
    expect(index, contains('html, body, button, input, select, textarea'));
  });
}
