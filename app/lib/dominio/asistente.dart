enum RolMensaje { usuario, asistente }

class MensajeChat {
  const MensajeChat({required this.rol, required this.texto, this.conFoto = false});

  final RolMensaje rol;
  final String texto;
  final bool conFoto;

  bool get esUsuario => rol == RolMensaje.usuario;
}

class Foto {
  const Foto({required this.bytes, required this.tipo});

  final List<int> bytes;
  final String tipo;
}

String tipoDeFoto(String nombre) {
  final extension = nombre.toLowerCase().split('.').last;
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}

const preguntasSugeridas = [
  'Una gallina está decaída y no come, ¿qué puede ser?',
  '¿Por qué puede bajar la postura de un galpón?',
  '¿Cómo cuido a las pollitas la primera semana?',
  '¿Cada cuánto se desparasitan las gallinas?',
];
