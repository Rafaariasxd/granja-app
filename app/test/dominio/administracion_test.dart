import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/dominio/administracion.dart';

void main() {
  group('fórmula', () {
    test('suma 100 con decimales', () {
      expect(formulaCompleta([60.5, 39.5]), isTrue);
      expect(formulaCompleta([33.33, 33.33, 33.34]), isTrue);
    });

    test('no es completa si falta o se pasa', () {
      expect(formulaCompleta([55, 22, 10]), isFalse);
      expect(formulaCompleta([60, 41]), isFalse);
      expect(formulaCompleta([]), isFalse);
    });

    test('suma los porcentajes', () {
      expect(sumaDeFormula([55, 22, 10, 10, 3]), 100);
    });
  });

  group('leerNumero', () {
    test('acepta coma o punto', () {
      expect(leerNumero('25,5'), 25.5);
      expect(leerNumero(' 40.25 '), 40.25);
    });

    test('lo vacío o inválido es nulo', () {
      expect(leerNumero(''), isNull);
      expect(leerNumero('  '), isNull);
      expect(leerNumero('1.2.3'), isNull);
      expect(leerNumero(','), isNull);
    });
  });
}
