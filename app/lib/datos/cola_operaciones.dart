import '../dominio/finanzas.dart';
import 'api_granja.dart';
import 'cola.dart';
import 'json.dart';
import 'json_finanzas.dart';
import 'operaciones.dart';

class ResultadoOperaciones {
  const ResultadoOperaciones({required this.quedanPendientes, this.sesionVencida = false});

  final bool quedanPendientes;
  final bool sesionVencida;
}

class ColaDeOperaciones {
  ColaDeOperaciones(this._api, this._almacen);

  final ApiGranja _api;
  final AlmacenOperaciones _almacen;

  Future<void> guardar(OperacionBodega operacion) => _almacen.guardar(operacion);

  Future<List<OperacionBodega>> sinResolver(Set<TipoOperacion> tipos) async => [
    for (final o in await _almacen.sinResolver())
      if (tipos.contains(o.tipo)) o,
  ];

  Future<void> descartar(String id) => _almacen.quitar(id);

  Future<ResultadoOperaciones> enviar() async {
    for (final operacion in await _almacen.porEnviar()) {
      try {
        await _enviar(operacion);
        await _almacen.quitar(operacion.id);
      } on DatosRechazados catch (error) {
        await _almacen.guardar(operacion.con(estado: EstadoEnvio.rechazado, mensaje: error.mensaje));
      } on SinPermiso catch (error) {
        await _almacen.guardar(operacion.con(estado: EstadoEnvio.rechazado, mensaje: error.mensaje));
      } on RegistroEnConflicto catch (error) {
        await _almacen.guardar(operacion.con(estado: EstadoEnvio.enConflicto, mensaje: error.mensaje));
      } on SesionVencida catch (error) {
        await _almacen.guardar(operacion.con(estado: EstadoEnvio.pendiente, mensaje: error.mensaje));
        return const ResultadoOperaciones(quedanPendientes: true, sesionVencida: true);
      } on ErrorDeApi catch (error) {
        await _almacen.guardar(operacion.con(estado: EstadoEnvio.pendiente, mensaje: error.mensaje));
        return const ResultadoOperaciones(quedanPendientes: true);
      }
    }
    return const ResultadoOperaciones(quedanPendientes: false);
  }

  Future<void> _enviar(OperacionBodega operacion) => switch (operacion.tipo) {
    TipoOperacion.compra => _api.registrarCompra(
      operacion.insumoId!,
      operacionId: operacion.id,
      bodegaId: operacion.bodegaId!,
      bultos: operacion.bultos!,
      fecha: fechaIso(operacion.fecha),
    ),
    TipoOperacion.gasto => _api.registrarGasto(
      operacion.insumoId!,
      operacionId: operacion.id,
      bodegaId: operacion.bodegaId!,
      bultos: operacion.bultos,
      kg: operacion.kg,
      nota: operacion.descripcion,
      fecha: fechaIso(operacion.fecha),
    ),
    TipoOperacion.preparacion => _api.prepararAlimento(
      operacion.insumoId!,
      operacionId: operacion.id,
      desdeBodegaId: operacion.bodegaId!,
      haciaBodegaId: operacion.haciaBodegaId!,
      kg: operacion.kg!,
      fecha: fechaIso(operacion.fecha),
    ),
    TipoOperacion.aplicacion => _api.marcarAplicada(
      operacion.loteId!,
      cumplimientoId: operacion.id,
      tareaId: operacion.tareaId!,
      fecha: fechaIso(operacion.fecha),
    ),
    TipoOperacion.dinero => _api.guardarMovimiento(
      operacion.id,
      movimientoAJson(
        MovimientoDinero(
          id: operacion.id,
          fecha: operacion.fecha,
          rubro: Rubro.desdeCodigo(operacion.rubro!),
          valor: operacion.valor!,
          descripcion: operacion.nota ?? '',
          loteId: operacion.loteId,
          categoriaId: operacion.categoriaId,
          cantidadHuevos: operacion.huevos,
          contraparte: operacion.contraparte ?? '',
        ),
      ),
    ),
    TipoOperacion.pesaje => _api.registrarPesaje(
      operacion.loteId!,
      pesajeId: operacion.id,
      fecha: fechaIso(operacion.fecha),
      pesoG: operacion.pesoG!,
      aves: operacion.aves!,
    ),
  };
}
