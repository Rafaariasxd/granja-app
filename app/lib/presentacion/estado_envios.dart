import 'dart:async';

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
  bool _sesionVencida = false;
  StreamSubscription<bool>? _conexion;

  int get pendientes => _pendientes;
  int get enConflicto => _enConflicto;
  bool get enviando => _enviando;
  bool get ultimoEnvioFallo => _ultimoEnvioFallo;
  bool get sesionVencida => _sesionVencida;
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
    _sesionVencida = false;
    notifyListeners();
    try {
      final resultado = await _sincronizador.enviarPendientes();
      _ultimoEnvioFallo = resultado.quedanPendientes;
      _sesionVencida = resultado.sesionVencida;
      await _contar();
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  void escucharConexion(Stream<bool> hayConexion) {
    _conexion?.cancel();
    _conexion = hayConexion.where((hay) => hay).listen((_) => unawaited(enviar()));
  }

  @override
  void dispose() {
    _conexion?.cancel();
    super.dispose();
  }

  Future<void> _contar() async {
    final cambios = await _almacen.todos();
    _pendientes = cambios.where((c) => c.estado == EstadoEnvio.pendiente).length;
    _enConflicto = cambios.where((c) => c.estado == EstadoEnvio.enConflicto).length;
  }
}
