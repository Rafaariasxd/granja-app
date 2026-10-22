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
