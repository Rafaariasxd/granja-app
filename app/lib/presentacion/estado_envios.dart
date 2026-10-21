import 'package:flutter/foundation.dart';

import '../datos/cola.dart';
import '../datos/sincronizador.dart';
import '../dominio/modelos.dart';

class EstadoEnvios extends ChangeNotifier {
  EstadoEnvios(this._sincronizador, this._almacen);

  final Sincronizador _sincronizador;
  final AlmacenCambios _almacen;

  int _pendientes = 0;
  int _enConflicto = 0;
  bool _enviando = false;
  bool _ultimoEnvioFallo = false;

  int get pendientes => _pendientes;
  int get enConflicto => _enConflicto;
  bool get enviando => _enviando;
  bool get ultimoEnvioFallo => _ultimoEnvioFallo;
  bool get todoEnviado => _pendientes == 0 && _enConflicto == 0;

  Future<void> guardar(RegistroDiario registro, DateTime ahora) async {
    await _sincronizador.registrar(registro, ahora);
    await _contar();
    notifyListeners();
    await enviar();
  }

  Future<void> enviar() async {
    if (_enviando) return;
    _enviando = true;
    notifyListeners();
    try {
      final resultado = await _sincronizador.enviarPendientes();
      _ultimoEnvioFallo = resultado.quedanPendientes;
      await _contar();
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  Future<void> _contar() async {
    final cambios = await _almacen.todos();
    _pendientes = cambios.where((c) => c.estado == EstadoEnvio.pendiente).length;
    _enConflicto = cambios.where((c) => c.estado == EstadoEnvio.enConflicto).length;
  }
}
