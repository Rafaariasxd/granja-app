import 'dart:convert';

import '../dominio/fechas.dart';
import '../dominio/huevos.dart';
import '../dominio/ids.dart';
import 'api_granja.dart';
import 'cola_operaciones.dart';
import 'json_huevos.dart';
import 'operaciones.dart';

class HuevosGuardados {
  const HuevosGuardados({required this.actualizadoEn, required this.datos});

  final DateTime actualizadoEn;
  final String datos;
}

abstract interface class AlmacenHuevos {
  Future<void> guardar(HuevosGuardados huevos);
  Future<HuevosGuardados?> ultima();
}

class AlmacenHuevosEnMemoria implements AlmacenHuevos {
  HuevosGuardados? _ultima;

  @override
  Future<void> guardar(HuevosGuardados huevos) async => _ultima = huevos;

  @override
  Future<HuevosGuardados?> ultima() async => _ultima;
}

class HuevosActuales {
  const HuevosActuales({required this.bodega, required this.actualizadoEn, this.copiaLocal = false});

  final BodegaHuevo bodega;
  final DateTime actualizadoEn;
  final bool copiaLocal;
}

class RepositorioHuevos {
  RepositorioHuevos(this._api, this._almacen, AlmacenOperaciones operaciones)
    : _operaciones = ColaDeOperaciones(_api, operaciones);

  final ApiGranja _api;
  final AlmacenHuevos _almacen;
  final ColaDeOperaciones _operaciones;

  Future<HuevosActuales?> bodega(DateTime ahora) async {
    try {
      final datos = await _api.huevosJson();
      final bodega = _leer(datos);
      await _almacen.guardar(HuevosGuardados(actualizadoEn: ahora, datos: datos));
      return HuevosActuales(bodega: bodega, actualizadoEn: ahora);
    } on SesionVencida {
      rethrow;
    } on ErrorDeApi {
      final guardada = await _almacen.ultima();
      if (guardada == null) return null;
      return HuevosActuales(bodega: _leer(guardada.datos), actualizadoEn: guardada.actualizadoEn, copiaLocal: true);
    }
  }

  Future<void> _guardar(
    TipoOperacion tipo,
    DateTime ahora,
    String descripcion, {
    int? categoriaId,
    int? huevos,
    String? nota,
    Map<int, int>? lineas,
    TipoVenta? tipoVenta,
    String? cliente,
    double? valor,
    String? referencia,
  }) => _operaciones.guardar(
    OperacionBodega(
      id: nuevoIdRegistro(),
      tipo: tipo,
      fecha: fechaEnGranja(ahora),
      descripcion: descripcion,
      guardadoEn: ahora,
      categoriaId: categoriaId,
      huevos: huevos,
      nota: nota,
      lineas: lineas,
      tipoVenta: tipoVenta?.codigo,
      contraparte: cliente,
      valor: valor,
      referencia: referencia,
    ),
  );

  Future<void> guardarIngreso(int categoriaId, int huevos, String descripcion, DateTime ahora) =>
      _guardar(TipoOperacion.huevoIngreso, ahora, descripcion, categoriaId: categoriaId, huevos: huevos);

  Future<void> guardarBaja(int categoriaId, int huevos, String nota, String descripcion, DateTime ahora) =>
      _guardar(TipoOperacion.huevoBaja, ahora, descripcion, categoriaId: categoriaId, huevos: huevos, nota: nota);

  Future<void> guardarVenta(
    TipoVenta tipo,
    String cliente,
    Map<int, int> lineas,
    double? valorCobrado,
    String descripcion,
    DateTime ahora,
  ) => _guardar(
    TipoOperacion.huevoVenta,
    ahora,
    descripcion,
    lineas: lineas,
    tipoVenta: tipo,
    cliente: cliente,
    valor: valorCobrado,
  );

  Future<void> guardarSalida(
    TipoVenta tipo,
    String cliente,
    Map<int, int> lineas,
    String descripcion,
    DateTime ahora,
  ) => _guardar(TipoOperacion.huevoSalida, ahora, descripcion, lineas: lineas, tipoVenta: tipo, cliente: cliente);

  Future<void> guardarCierre(
    String salidaId,
    Map<int, int>? vendidos,
    double? valorCobrado,
    String descripcion,
    DateTime ahora,
  ) => _guardar(
    TipoOperacion.huevoCierre,
    ahora,
    descripcion,
    referencia: salidaId,
    lineas: vendidos,
    valor: valorCobrado,
  );

  Future<void> contar(int categoriaId, int huevos) => _api.contarHuevo(categoriaId, huevos, 'Conteo en la bodega');

  Future<void> anular(String salidaId) => _api.anularSalida(salidaId);

  Future<List<OperacionBodega>> sinResolver() => _operaciones.sinResolver(tiposDeHuevo);

  Future<void> descartar(String id) => _operaciones.descartar(id);

  Future<ResultadoOperaciones> enviarOperaciones() => _operaciones.enviar();

  BodegaHuevo _leer(String datos) => bodegaHuevoDesdeJson(jsonDecode(datos) as Map<String, dynamic>);
}
