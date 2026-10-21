import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const prohibidos = [
  'package:flutter/',
  'package:granja_app/datos/',
  'package:granja_app/presentacion/',
  '../datos/',
  '../presentacion/',
];

void main() {
  test('el dominio no depende de Flutter ni de las otras capas', () {
    final archivos = Directory('lib/dominio').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
    expect(archivos, isNotEmpty);
    for (final archivo in archivos) {
      for (final linea in archivo.readAsLinesSync().where((l) => l.startsWith('import '))) {
        for (final prohibido in prohibidos) {
          expect(linea.contains(prohibido), isFalse, reason: '${archivo.path} importa $prohibido');
        }
      }
    }
  });
}
