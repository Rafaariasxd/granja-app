import 'dart:convert';

import '../dominio/asistente.dart';
import 'api_granja.dart';

class RepositorioAsistente {
  RepositorioAsistente(this._api);

  final ApiGranja _api;

  Future<String> preguntar(List<MensajeChat> mensajes, Foto? foto) => _api.preguntarAlAsistente({
    'mensajes': [
      for (final m in mensajes) {'rol': m.esUsuario ? 'usuario' : 'asistente', 'texto': m.texto},
    ],
    'imagen': foto == null ? null : {'tipo': foto.tipo, 'datos_base64': base64Encode(foto.bytes)},
  });
}
