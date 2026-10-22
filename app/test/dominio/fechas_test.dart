import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/dominio/fechas.dart';

void main() {
  test('de noche en Colombia sigue siendo el mismo día', () {
    expect(fechaEnGranja(DateTime.utc(2026, 10, 22, 1, 30)), DateTime.utc(2026, 10, 21));
  });

  test('de día la fecha coincide', () {
    expect(fechaEnGranja(DateTime.utc(2026, 10, 21, 15)), DateTime.utc(2026, 10, 21));
  });
}
