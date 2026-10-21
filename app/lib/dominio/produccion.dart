import 'dart:math';

import 'fechas.dart';
import 'modelos.dart';

const semanaInicioLevante = 6;
const semanaInicioProduccion = 18;

int edadSemanas(DateTime fechaNacimiento, DateTime fecha) {
  final dias = soloDia(fecha).difference(soloDia(fechaNacimiento)).inDays;
  if (dias < 0) {
    throw ArgumentError('la fecha es anterior al nacimiento del lote');
  }
  return dias ~/ 7;
}

Etapa etapa(
  DateTime fechaNacimiento,
  DateTime fecha, {
  int inicioLevante = semanaInicioLevante,
  int inicioProduccion = semanaInicioProduccion,
}) {
  final semanas = edadSemanas(fechaNacimiento, fecha);
  if (semanas < inicioLevante) return Etapa.cria;
  if (semanas < inicioProduccion) return Etapa.levante;
  return Etapa.produccion;
}

int avesVivas(int avesIniciales, int mortalidadAcumulada) => max(avesIniciales - mortalidadAcumulada, 0);

double porcentaje(int parte, int total) {
  if (total <= 0) return 0;
  final numerador = parte * 1000;
  var decimas = numerador ~/ total;
  final resto = numerador % total;
  if (resto * 2 > total || (resto * 2 == total && decimas.isOdd)) {
    decimas += 1;
  }
  return decimas / 10;
}

double posturaPct(int huevos, int aves) => porcentaje(huevos, aves);

double ocupacionPct(int aves, int capacidad) => porcentaje(aves, capacidad);

bool bajaPostura(List<DiaPostura> dias, {double umbralPuntos = 5, int diasSeguidos = 3}) {
  if (dias.length < diasSeguidos) return false;
  final ordenados = [...dias]..sort((a, b) => a.fecha.compareTo(b.fecha));
  final ultimos = ordenados.sublist(ordenados.length - diasSeguidos);
  return ultimos.every((d) => d.estandarPct - d.realPct > umbralPuntos);
}
