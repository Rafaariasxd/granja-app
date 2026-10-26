import 'dart:convert';

import '../dominio/fechas.dart';
import '../dominio/finanzas.dart';
import '../dominio/ids.dart';
import 'api_granja.dart';
import 'cola_operaciones.dart';
import 'json.dart';
import 'json_finanzas.dart';
import 'operaciones.dart';

class FinanzasGuardadas {
  const FinanzasGuardadas({required this.actualizadoEn, required this.datos});

  final DateTime actualizadoEn;
  final String datos;
}

abstract interface class AlmacenFinanzas {
  Future<void> guardar(FinanzasGuardadas finanzas);
  Future<FinanzasGuardadas?> ultima();
}

class AlmacenFinanzasEnMemoria implements AlmacenFinanzas {
  FinanzasGuardadas? _ultima;

  @override
  Future<void> guardar(FinanzasGuardadas finanzas) async => _ultima = finanzas;

  @override
  Future<FinanzasGuardadas?> ultima() async => _ultima;
}

class FinanzasActuales {
  const FinanzasActuales({required this.panorama, required this.actualizadoEn, this.copiaLocal = false});

  final PanoramaDinero panorama;
  final DateTime actualizadoEn;
  final bool copiaLocal;
}

class RepositorioFinanzas {
  RepositorioFinanzas(this._api, this._almacen, AlmacenOperaciones operaciones)
    : _operaciones = ColaDeOperaciones(_api, operaciones);

  final ApiGranja _api;
  final AlmacenFinanzas _almacen;
  final ColaDeOperaciones _operaciones;

  Future<FinanzasActuales?> panorama(DateTime mes, DateTime ahora) async {
    try {
      final desde = fechaIso(primerDiaDelMes(mes));
      final hasta = fechaIso(ultimoDiaDelMes(mes));
      final resumen = jsonDecode(await _api.resumenFinanzasJson(desde, hasta));
      final movimientos = jsonDecode(await _api.movimientosJson(desde, hasta));
      final categorias = jsonDecode(await _api.categoriasHuevoJson());
      final galpones = await _api.resumen(fechaEnGranja(ahora));
      final datos = jsonEncode({
        'mes': desde,
        'resumen': resumen,
        'movimientos': movimientos,
        'categorias': categorias,
        'lotes': [
          for (final g in galpones)
            if (g.loteId != null) {'id': g.loteId, 'galpon': g.nombre},
        ],
      });
      await _almacen.guardar(FinanzasGuardadas(actualizadoEn: ahora, datos: datos));
      return FinanzasActuales(panorama: _leer(datos), actualizadoEn: ahora);
    } on SesionVencida {
      rethrow;
    } on ErrorDeApi {
      final guardada = await _almacen.ultima();
      if (guardada == null) return null;
      return FinanzasActuales(panorama: _leer(guardada.datos), actualizadoEn: guardada.actualizadoEn, copiaLocal: true);
    }
  }

  Future<void> guardarMovimiento({
    required Rubro rubro,
    required double valor,
    required DateTime ahora,
    required String descripcion,
    String nota = '',
    int? loteId,
    int? categoriaId,
    int? huevos,
    String contraparte = '',
  }) => _operaciones.guardar(
    OperacionBodega(
      id: nuevoIdRegistro(),
      tipo: TipoOperacion.dinero,
      fecha: fechaEnGranja(ahora),
      descripcion: descripcion,
      guardadoEn: ahora,
      rubro: rubro.codigo,
      valor: valor,
      loteId: loteId,
      categoriaId: categoriaId,
      huevos: huevos,
      contraparte: contraparte,
      nota: nota,
    ),
  );

  Future<void> borrar(String id) => _api.borrarMovimiento(id);

  Future<void> crearCategoria(String nombre) => _api.crearCategoriaHuevo(nombre);

  Future<void> cambiarCategoria(int id, {String? nombre, bool? activa}) =>
      _api.cambiarCategoriaHuevo(id, nombre: nombre, activa: activa);

  Future<List<OperacionBodega>> sinResolver() => _operaciones.sinResolver(tiposDeDinero);

  Future<void> descartar(String id) => _operaciones.descartar(id);

  Future<ResultadoOperaciones> enviarOperaciones() => _operaciones.enviar();

  PanoramaDinero _leer(String datos) => panoramaDineroDesdeJson(jsonDecode(datos) as Map<String, dynamic>);
}
