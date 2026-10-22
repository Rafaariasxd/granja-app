import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/dominio/modelos.dart';
import 'package:granja_app/dominio/produccion.dart';

final nacimiento = DateTime.utc(2026, 1, 1);

List<DiaPostura> dias(List<double> reales, {double estandar = 93}) => [
  for (var i = 0; i < reales.length; i++)
    DiaPostura(
      fecha: nacimiento.add(Duration(days: i)),
      realPct: reales[i],
      estandarPct: estandar,
    ),
];

void main() {
  test('edad en semanas completas', () {
    expect(edadSemanas(nacimiento, nacimiento), 0);
    expect(edadSemanas(nacimiento, nacimiento.add(const Duration(days: 13))), 1);
    expect(edadSemanas(nacimiento, nacimiento.add(const Duration(days: 14))), 2);
  });

  test('una fecha antes del nacimiento es un error', () {
    expect(() => edadSemanas(nacimiento, nacimiento.subtract(const Duration(days: 1))), throwsArgumentError);
  });

  test('etapa según la edad', () {
    final casos = {0: Etapa.cria, 5: Etapa.cria, 6: Etapa.levante, 17: Etapa.levante, 18: Etapa.produccion};
    casos.forEach((semanas, esperada) {
      expect(etapa(nacimiento, nacimiento.add(Duration(days: semanas * 7))), esperada);
    });
  });

  test('etapa con cortes personalizados', () {
    expect(etapa(nacimiento, nacimiento.add(const Duration(days: 17 * 7)), inicioProduccion: 16), Etapa.produccion);
  });

  test('las aves vivas no bajan de cero', () {
    expect(avesVivas(5000, 120), 4880);
    expect(avesVivas(100, 150), 0);
  });

  test('postura y ocupación', () {
    expect(posturaPct(4300, 5000), 86.0);
    expect(posturaPct(4000, 4950), 80.8);
    expect(posturaPct(10, 0), 0.0);
    expect(ocupacionPct(4500, 6000), 75.0);
  });

  test('el redondeo en empate va al par, como en el servidor', () {
    expect(porcentaje(1, 16), 6.2);
    expect(porcentaje(3, 16), 18.8);
  });

  test('baja postura tres días seguidos', () {
    expect(bajaPostura(dias([92, 86, 85, 87])), isTrue);
  });

  test('un día bueno reinicia la alerta', () {
    expect(bajaPostura(dias([86, 85, 92])), isFalse);
  });

  test('justo en el umbral no alerta', () {
    expect(bajaPostura(dias([88, 88, 88])), isFalse);
  });

  test('con pocos días no alerta', () {
    expect(bajaPostura(dias([80, 80])), isFalse);
  });

  test('el orden de entrada no importa', () {
    expect(bajaPostura(dias([92, 86, 85, 87]).reversed.toList()), isTrue);
  });
}
