import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/dominio/modelos.dart';
import 'package:granja_app/dominio/resumen_dia.dart';

ResumenGalpon galpon(int id, {int? lote, int vivas = 0, int? huevos}) => ResumenGalpon(
  galponId: id,
  nombre: 'Galpón $id',
  capacidadAves: 5000,
  avesVivas: vivas,
  ocupacionPct: 0,
  loteId: lote,
  huevosDelDia: huevos,
);

void main() {
  final resumen = ResumenDelDia([
    galpon(1, lote: 10, vivas: 2476, huevos: 2130),
    galpon(2),
    galpon(3, lote: 11, vivas: 1612),
    galpon(5, lote: 12, vivas: 948, huevos: 0),
  ]);

  test('suma huevos y aves solo de los galpones con lote', () {
    expect(resumen.huevos, 2130);
    expect(resumen.avesVivas, 5036);
    expect(resumen.conLote, hasLength(3));
  });

  test('faltan los galpones con lote sin registro; un cero registrado cuenta como registrado', () {
    expect(resumen.faltan.map((g) => g.nombre), ['Galpón 3']);
    expect(resumen.todoRegistrado, isFalse);
  });

  test('los galpones vacíos no cuentan como faltantes', () {
    expect(resumen.vacios.map((g) => g.galponId), [2]);
    expect(ResumenDelDia([galpon(1, lote: 1, huevos: 10), galpon(2)]).todoRegistrado, isTrue);
  });

  test('sin ningún lote no hay nada por registrar', () {
    expect(ResumenDelDia([galpon(1)]).todoRegistrado, isFalse);
    expect(ResumenDelDia([galpon(1)]).faltan, isEmpty);
  });
}
