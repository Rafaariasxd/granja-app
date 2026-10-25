import '../dominio/modelos.dart';
import 'api_granja.dart';
import 'cola.dart';

class RegistroEncontrado {
  const RegistroEncontrado({required this.registro, required this.sinEnviar});

  final RegistroDiario registro;
  final bool sinEnviar;
}

class BuscadorRegistro {
  BuscadorRegistro(this._api, this._almacen);

  final ApiGranja _api;
  final AlmacenCambios _almacen;

  Future<RegistroEncontrado?> buscar(int galponId, DateTime fecha) async {
    final locales = (await _almacen.todos())
        .where((c) => c.registro.galponId == galponId && c.registro.fecha == fecha)
        .toList();
    final sinEnviar = locales.where((c) => c.estado == EstadoEnvio.pendiente || c.estado == EstadoEnvio.enConflicto);
    if (sinEnviar.isNotEmpty) return RegistroEncontrado(registro: sinEnviar.last.registro, sinEnviar: true);
    try {
      final remoto = await _api.registroDelDia(galponId, fecha);
      return remoto == null ? null : RegistroEncontrado(registro: remoto, sinEnviar: false);
    } on SinConexion {
      final enviados = locales.where((c) => c.estado == EstadoEnvio.enviado);
      if (enviados.isEmpty) rethrow;
      return RegistroEncontrado(registro: enviados.last.registro, sinEnviar: false);
    }
  }
}
