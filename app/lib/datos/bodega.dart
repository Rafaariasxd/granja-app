import 'dart:convert';

import '../dominio/fechas.dart';
import '../dominio/ids.dart';
import '../dominio/inventario.dart';
import 'api_granja.dart';
import 'cola.dart';
import 'json.dart';
import 'json_inventario.dart';
import 'operaciones.dart';

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

class Cantidad {
  const Cantidad.bultos(this.valor) : enBultos = true;
  const Cantidad.kilos(this.valor) : enBultos = false;

  final double valor;
  final bool enBultos;
}

class ResultadoOperaciones {
  const ResultadoOperaciones({required this.quedanPendientes, this.sesionVencida = false});

  final bool quedanPendientes;
  final bool sesionVencida;
}

class RepositorioBodega {
  RepositorioBodega(this._api, this._almacen, this._operaciones);

  final ApiGranja _api;
  final AlmacenBodega _almacen;
  final AlmacenOperaciones _operaciones;

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

  Future<void> guardarCompra(Insumo insumo, int bodegaId, double bultos, String descripcion, DateTime ahora) =>
      _operaciones.guardar(
        OperacionBodega(
          id: nuevoIdRegistro(),
          tipo: TipoOperacion.compra,
          fecha: fechaEnGranja(ahora),
          insumoId: insumo.id,
          bodegaId: bodegaId,
          bultos: bultos,
          descripcion: descripcion,
          guardadoEn: ahora,
        ),
      );

  Future<void> guardarPreparacion(
    MezclaPosible mezcla,
    int haciaBodegaId,
    double kg,
    String descripcion,
    DateTime ahora,
  ) => _operaciones.guardar(
    OperacionBodega(
      id: nuevoIdRegistro(),
      tipo: TipoOperacion.preparacion,
      fecha: fechaEnGranja(ahora),
      insumoId: mezcla.productoId,
      bodegaId: mezcla.origenId,
      haciaBodegaId: haciaBodegaId,
      kg: kg,
      descripcion: descripcion,
      guardadoEn: ahora,
    ),
  );

  Future<void> guardarGasto(Insumo insumo, int bodegaId, Cantidad cantidad, String descripcion, DateTime ahora) =>
      _operaciones.guardar(
        OperacionBodega(
          id: nuevoIdRegistro(),
          tipo: TipoOperacion.gasto,
          fecha: fechaEnGranja(ahora),
          insumoId: insumo.id,
          bodegaId: bodegaId,
          bultos: cantidad.enBultos ? cantidad.valor : null,
          kg: cantidad.enBultos ? null : cantidad.valor,
          descripcion: descripcion,
          guardadoEn: ahora,
        ),
      );

  Future<void> contar(Insumo insumo, int bodegaId, Cantidad cantidad) => _api.ajustarStock(
    insumo.id,
    bodegaId: bodegaId,
    bultos: cantidad.enBultos ? cantidad.valor : null,
    kg: cantidad.enBultos ? null : cantidad.valor,
    nota: 'Conteo en la bodega',
  );

  Future<List<OperacionBodega>> sinResolver() => _operaciones.sinResolver();

  Future<void> descartar(String id) => _operaciones.quitar(id);

  Future<ResultadoOperaciones> enviarOperaciones() async {
    for (final operacion in await _operaciones.porEnviar()) {
      try {
        await _enviar(operacion);
        await _operaciones.quitar(operacion.id);
      } on DatosRechazados catch (error) {
        await _operaciones.guardar(operacion.con(estado: EstadoEnvio.rechazado, mensaje: error.mensaje));
      } on SinPermiso catch (error) {
        await _operaciones.guardar(operacion.con(estado: EstadoEnvio.rechazado, mensaje: error.mensaje));
      } on RegistroEnConflicto catch (error) {
        await _operaciones.guardar(operacion.con(estado: EstadoEnvio.enConflicto, mensaje: error.mensaje));
      } on SesionVencida catch (error) {
        await _operaciones.guardar(operacion.con(estado: EstadoEnvio.pendiente, mensaje: error.mensaje));
        return const ResultadoOperaciones(quedanPendientes: true, sesionVencida: true);
      } on ErrorDeApi catch (error) {
        await _operaciones.guardar(operacion.con(estado: EstadoEnvio.pendiente, mensaje: error.mensaje));
        return const ResultadoOperaciones(quedanPendientes: true);
      }
    }
    return const ResultadoOperaciones(quedanPendientes: false);
  }

  Future<void> _enviar(OperacionBodega operacion) => switch (operacion.tipo) {
    TipoOperacion.compra => _api.registrarCompra(
      operacion.insumoId,
      operacionId: operacion.id,
      bodegaId: operacion.bodegaId,
      bultos: operacion.bultos!,
      fecha: fechaIso(operacion.fecha),
    ),
    TipoOperacion.gasto => _api.registrarGasto(
      operacion.insumoId,
      operacionId: operacion.id,
      bodegaId: operacion.bodegaId,
      bultos: operacion.bultos,
      kg: operacion.kg,
      nota: operacion.descripcion,
      fecha: fechaIso(operacion.fecha),
    ),
    TipoOperacion.preparacion => _api.prepararAlimento(
      operacion.insumoId,
      operacionId: operacion.id,
      desdeBodegaId: operacion.bodegaId,
      haciaBodegaId: operacion.haciaBodegaId!,
      kg: operacion.kg!,
      fecha: fechaIso(operacion.fecha),
    ),
  };

  Inventario _leer(String datos) => inventarioDesdeJson(jsonDecode(datos) as Map<String, dynamic>);
}
