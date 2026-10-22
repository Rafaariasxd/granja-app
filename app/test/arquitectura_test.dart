import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const prohibidos = {
  'dominio': [
    'package:flutter/',
    'package:http/',
    'package:granja_app/datos/',
    'package:granja_app/presentacion/',
    '../datos/',
    '../presentacion/',
  ],
  'datos': ['package:flutter/', 'package:granja_app/presentacion/', '../presentacion/'],
};

void main() {
  prohibidos.forEach((capa, importacionesProhibidas) {
    test('$capa no importa lo que no le corresponde', () {
      final archivos = Directory('lib/$capa').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
      expect(archivos, isNotEmpty);
      for (final archivo in archivos) {
        for (final linea in archivo.readAsLinesSync().where((l) => l.startsWith('import '))) {
          for (final prohibida in importacionesProhibidas) {
            expect(linea.contains(prohibida), isFalse, reason: '${archivo.path} importa $prohibida');
          }
        }
      }
    });
  });
}
