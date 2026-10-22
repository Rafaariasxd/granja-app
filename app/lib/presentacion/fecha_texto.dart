const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String fechaLarga(DateTime fecha) {
  final dia = _dias[fecha.weekday - 1];
  return '${dia[0].toUpperCase()}${dia.substring(1)} ${fecha.day} de ${_meses[fecha.month - 1]}';
}
