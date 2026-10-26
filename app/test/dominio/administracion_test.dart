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

  group('curva de la raza', () {
    test('lee una semana por línea con postura y peso opcional', () {
      final leida = leerCurva('30 95 1890\n18 6,5\n\n 20;45;1560 ');
      expect(leida.esValida, isTrue);
      expect([for (final p in leida.puntos) p.semana], [18, 20, 30]);
      expect(leida.puntos.first.posturaPct, 6.5);
      expect(leida.puntos.first.pesoG, isNull);
      expect(leida.puntos.last.pesoG, 1890);
    });

    test('dice en qué línea está el error', () {
      expect(leerCurva('30 95\nabc 3').error, contains('Línea 2'));
      expect(leerCurva('30').error, contains('Línea 1'));
      expect(leerCurva('30 95 1800 7').error, contains('Línea 1'));
      expect(leerCurva('30 101').error, contains('0 a 100'));
      expect(leerCurva('30 90 0').error, contains('peso'));
      expect(leerCurva('30 90\n30 91').error, contains('repetida'));
      expect(leerCurva('-1 90').error, isNotNull);
    });

    test('vacía es válida y ida y vuelta conserva los datos', () {
      expect(leerCurva('').puntos, isEmpty);
      const puntos = [PuntoDeCurva(semana: 18, posturaPct: 6, pesoG: 1470), PuntoDeCurva(semana: 30, posturaPct: 95.5)];
      expect(curvaComoTexto(puntos), '18 6 1470\n30 95.5');
      final vuelta = leerCurva(curvaComoTexto(puntos)).puntos;
      expect([for (final p in vuelta) (p.semana, p.posturaPct, p.pesoG)], [(18, 6.0, 1470.0), (30, 95.5, null)]);
    });
  });
}
