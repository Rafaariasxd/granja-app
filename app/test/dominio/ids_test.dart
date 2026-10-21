import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/dominio/ids.dart';

final formatoUuid4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

void main() {
  test('el id es un UUID versión 4 en minúsculas, como lo espera el servidor', () {
    for (var i = 0; i < 200; i++) {
      expect(nuevoIdRegistro(), matches(formatoUuid4));
    }
  });

  test('no se repite', () {
    final ids = {for (var i = 0; i < 1000; i++) nuevoIdRegistro()};
    expect(ids, hasLength(1000));
  });

  test('con la misma semilla sale el mismo id, para poder probarlo', () {
    expect(nuevoIdRegistro(Random(7)), nuevoIdRegistro(Random(7)));
  });
}
