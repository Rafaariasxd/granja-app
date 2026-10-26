import 'package:flutter/foundation.dart';

import '../datos/api_granja.dart';
import '../datos/asistente.dart';
import '../dominio/asistente.dart';

class EstadoAsistente extends ChangeNotifier {
  EstadoAsistente(this._repositorio);

  final RepositorioAsistente _repositorio;

  final List<MensajeChat> _mensajes = [];
  Foto? _foto;
  Foto? _fotoEnviada;
  bool _pensando = false;
  bool _sesionVencida = false;
  String? _error;

  List<MensajeChat> get mensajes => List.unmodifiable(_mensajes);
  Foto? get foto => _foto;
  bool get pensando => _pensando;
  bool get sesionVencida => _sesionVencida;
  String? get error => _error;
  bool get vacio => _mensajes.isEmpty;

  void ponerFoto(Foto foto) {
    _foto = foto;
    notifyListeners();
  }

  void quitarFoto() {
    _foto = null;
    notifyListeners();
  }

  void nuevaConversacion() {
    _mensajes.clear();
    _foto = null;
    _fotoEnviada = null;
    _error = null;
    notifyListeners();
  }

  Future<void> preguntar(String texto) async {
    final limpio = texto.trim();
    if (limpio.isEmpty || _pensando) return;
    _mensajes.add(MensajeChat(rol: RolMensaje.usuario, texto: limpio, conFoto: _foto != null));
    _fotoEnviada = _foto;
    _foto = null;
    await _enviar();
  }

  Future<void> reintentar() => _enviar();

  Future<void> _enviar() async {
    _pensando = true;
    _error = null;
    notifyListeners();
    try {
      final respuesta = await _repositorio.preguntar(_mensajes, _fotoEnviada);
      _mensajes.add(MensajeChat(rol: RolMensaje.asistente, texto: respuesta));
      _fotoEnviada = null;
    } on SinConexion {
      _error = 'Sin señal: el asistente necesita internet.';
    } on SesionVencida {
      _sesionVencida = true;
      _error = 'La sesión se cerró, vuelve a entrar.';
    } on ErrorDeApi catch (e) {
      _error = e.mensaje.isEmpty ? 'No se pudo preguntar.' : '${e.mensaje[0].toUpperCase()}${e.mensaje.substring(1)}.';
    } finally {
      _pensando = false;
      notifyListeners();
    }
  }
}
