import 'package:flutter/foundation.dart';

import '../datos/api_granja.dart';
import '../datos/bodega.dart';
import '../dominio/inventario.dart';

class EstadoBodega extends ChangeNotifier {
  EstadoBodega(this._repositorio, {DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now;

  final RepositorioBodega _repositorio;
  final DateTime Function() _reloj;

  BodegaActual? _datos;
  bool _cargando = false;
  bool _sesionVencida = false;

  bool get cargando => _cargando;
  bool get sesionVencida => _sesionVencida;
  bool get sinSenal => _datos?.copiaLocal ?? false;
  Inventario? get inventario => _datos?.inventario;

  Future<void> cargar() async {
    if (_cargando) return;
    _cargando = true;
    _sesionVencida = false;
    notifyListeners();
    try {
      _datos = await _repositorio.inventario(_reloj()) ?? _datos;
    } on SesionVencida {
      _sesionVencida = true;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<String?> registrarCompra(int insumoId, int bodegaId, double bultos) =>
      _accion(() => _repositorio.registrarCompra(insumoId, bodegaId, bultos));

  Future<String?> prepararAlimento(int productoId, int desdeBodegaId, int haciaBodegaId, double kg) =>
      _accion(() => _repositorio.prepararAlimento(productoId, desdeBodegaId, haciaBodegaId, kg));

  Future<String?> _accion(Future<void> Function() accion) async {
    try {
      await accion();
    } on SinConexion {
      return 'No hay señal. Esto se guarda cuando haya internet; inténtalo de nuevo.';
    } on SesionVencida {
      _sesionVencida = true;
      notifyListeners();
      return 'La sesión se cerró, vuelve a entrar.';
    } on ErrorDeApi catch (error) {
      return error.mensaje;
    }
    await cargar();
    return null;
  }
}
