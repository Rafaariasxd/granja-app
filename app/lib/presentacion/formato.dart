String miles(int numero) {
  final texto = numero.abs().toString();
  final buffer = StringBuffer(numero < 0 ? '-' : '');
  for (var i = 0; i < texto.length; i++) {
    if (i > 0 && (texto.length - i) % 3 == 0) buffer.write('.');
    buffer.write(texto[i]);
  }
  return buffer.toString();
}

String porcentaje(double valor) => '${valor.round()}%';

String decimal(double valor) {
  final texto = valor.toStringAsFixed(1);
  return (texto.endsWith('.0') ? texto.substring(0, texto.length - 2) : texto).replaceAll('.', ',');
}

String pesos(double valor) => '\$ ${miles(valor.round())}';

String kilos(double kg) => '${miles(kg.round())} kg';

String cantidadTexto(double kg, double? kgPorBulto) => kgPorBulto == null ? kilos(kg) : bultosTexto(kg / kgPorBulto);

String bultosTexto(double bultos) {
  final enteros = bultos.floor();
  final resto = bultos - enteros;
  final unidad = enteros == 1 ? 'bulto' : 'bultos';
  if (resto < 0.05) return '$enteros $unidad';
  if ((resto - 0.5).abs() < 0.05) return enteros == 0 ? 'medio bulto' : '$enteros $unidad y medio';
  return '${decimal(bultos)} bultos';
}

String diasTexto(double? dias) {
  if (dias == null) return 'sin datos';
  if (dias < 1) return 'menos de 1 día';
  if (dias == 1) return '1 día';
  return '${decimal(dias)} días';
}
