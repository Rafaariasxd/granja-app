import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/dominio/galpon_vivo.dart';

DispositivoIot equipo(String id) => DispositivoIot(
  id: id,
  nombre: id,
  categoria: '',
  protocolo: '',
  ubicacion: '',
  descripcion: '',
  enLinea: true,
  ultimoContacto: null,
  variables: const [],
  ultimos: const {},
  acciones: const [],
  estado: const {},
);

void main() {
  test('formatea números al estilo colombiano', () {
    expect(numeroCorto(24.06), '24,1');
    expect(numeroCorto(4496), '4.496');
    expect(numeroCorto(2.85), '2,85');
    expect(numeroCorto(80), '80');
    expect(numeroCorto(-1234.4), '-1.234');
  });

  test('las variables 1/0 se muestran como Sí o No', () {
    const luces = VariableIot(nombre: 'luces', unidad: '1/0', minimo: 0, maximo: 1);
    const nivel = VariableIot(nombre: 'nivel', unidad: '%', minimo: 0, maximo: 100);
    expect(valorConUnidad(1, luces), 'Sí');
    expect(valorConUnidad(0, luces), 'No');
    expect(valorConUnidad(50.41, nivel), '50,4 %');
    expect(valorConUnidad(null, nivel), '—');
  });

  test('agrupa los equipos por zona y deja los desconocidos al final', () {
    final grupos = agruparDispositivos([equipo('tanque-agua'), equipo('raro'), equipo('galpon1-ambiente')]);
    expect(grupos.map((g) => g.titulo), ['Galpón 1', 'Agua, alimento y energía', 'Otros']);
    expect(grupos.last.dispositivos.single.id, 'raro');
  });

  test('nombres legibles y tiempo transcurrido', () {
    expect(nombreVariable('amoniaco'), 'Amoníaco');
    expect(nombreVariable('algo_nuevo'), 'Algo nuevo');
    final ahora = DateTime(2026, 11, 19, 12);
    expect(haceCuanto(ahora.subtract(const Duration(seconds: 30)), ahora), 'hace un momento');
    expect(haceCuanto(ahora.subtract(const Duration(minutes: 12)), ahora), 'hace 12 min');
    expect(haceCuanto(ahora.subtract(const Duration(days: 6)), ahora), 'hace 6 días');
    expect(haceCuanto(null, ahora), 'nunca');
  });
}
