import 'dart:convert';

import '../dominio/inventario.dart';
import 'api_granja.dart';
import 'json_inventario.dart';

class BodegaGuardada {
  const BodegaGuardada({required this.actualizadoEn, required this.datos});

  final DateTime actualizadoEn;
  final String datos;
}

abstract interface class AlmacenBodega {
  Future<void> guardar(BodegaGuardada bodega);
  Future<BodegaGuardada?> ultima();
}

class AlmacenBodegaEnMemoria implements AlmacenBodega {
  BodegaGuardada? _ultima;

  @override
  Future<void> guardar(BodegaGuardada bodega) async => _ultima = bodega;

  @override
  Future<BodegaGuardada?> ultima() async => _ultima;
}

class BodegaActual {
  const BodegaActual({required this.inventario, required this.actualizadoEn, this.copiaLocal = false});

  final Inventario inventario;
  final DateTime actualizadoEn;
  final bool copiaLocal;
}

class RepositorioBodega {
  RepositorioBodega(this._api, this._almacen);

  final ApiGranja _api;
  final AlmacenBodega _almacen;

  Future<BodegaActual?> inventario(DateTime ahora) async {
    try {
      final datos = await _api.inventarioJson();
      final inventario = _leer(datos);
      await _almacen.guardar(BodegaGuardada(actualizadoEn: ahora, datos: datos));
      return BodegaActual(inventario: inventario, actualizadoEn: ahora);
    } on SesionVencida {
      rethrow;
    } on ErrorDeApi {
      final guardada = await _almacen.ultima();
      if (guardada == null) return null;
      return BodegaActual(inventario: _leer(guardada.datos), actualizadoEn: guardada.actualizadoEn, copiaLocal: true);
    }
  }

  Future<void> registrarCompra(int insumoId, int bodegaId, double bultos) =>
      _api.registrarCompra(insumoId, bodegaId: bodegaId, bultos: bultos);

  Future<void> prepararAlimento(int productoId, int desdeBodegaId, int haciaBodegaId, double kg) =>
      _api.prepararAlimento(productoId, desdeBodegaId: desdeBodegaId, haciaBodegaId: haciaBodegaId, kg: kg);

  Inventario _leer(String datos) => inventarioDesdeJson(jsonDecode(datos) as Map<String, dynamic>);
}
