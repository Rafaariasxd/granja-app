import 'dart:convert';

import '../dominio/fechas.dart';
import '../dominio/ids.dart';
import '../dominio/sanidad.dart';
import 'api_granja.dart';
import 'cola_operaciones.dart';
import 'json_sanidad.dart';
import 'operaciones.dart';

class SanidadGuardada {
  const SanidadGuardada({required this.actualizadoEn, required this.datos});

  final DateTime actualizadoEn;
  final String datos;
}

abstract interface class AlmacenSanidad {
  Future<void> guardar(SanidadGuardada sanidad);
  Future<SanidadGuardada?> ultima();
}

class AlmacenSanidadEnMemoria implements AlmacenSanidad {
  SanidadGuardada? _ultima;

  @override
  Future<void> guardar(SanidadGuardada sanidad) async => _ultima = sanidad;

  @override
  Future<SanidadGuardada?> ultima() async => _ultima;
}

class SanidadActual {
  const SanidadActual({required this.panorama, required this.actualizadoEn, this.copiaLocal = false});

  final PanoramaSanidad panorama;
  final DateTime actualizadoEn;
  final bool copiaLocal;
}

class RepositorioSanidad {
  RepositorioSanidad(this._api, this._almacen, AlmacenOperaciones operaciones)
    : _operaciones = ColaDeOperaciones(_api, operaciones);

  final ApiGranja _api;
  final AlmacenSanidad _almacen;
  final ColaDeOperaciones _operaciones;

  Future<SanidadActual?> panorama(DateTime ahora) async {
    try {
      final datos = await _api.sanidadJson(fechaEnGranja(ahora));
      final panorama = _leer(datos);
      await _almacen.guardar(SanidadGuardada(actualizadoEn: ahora, datos: datos));
      return SanidadActual(panorama: panorama, actualizadoEn: ahora);
    } on SesionVencida {
      rethrow;
    } on ErrorDeApi {
      final guardada = await _almacen.ultima();
      if (guardada == null) return null;
      return SanidadActual(panorama: _leer(guardada.datos), actualizadoEn: guardada.actualizadoEn, copiaLocal: true);
    }
  }

  Future<void> guardarAplicacion(GalponSanidad galpon, TareaSanitaria tarea, DateTime fecha, DateTime ahora) =>
      _operaciones.guardar(
        OperacionBodega(
          id: nuevoIdRegistro(),
          tipo: TipoOperacion.aplicacion,
          fecha: soloDia(fecha),
          loteId: galpon.loteId,
          tareaId: tarea.tareaId,
          descripcion: '${tarea.nombre} en ${galpon.galpon}',
          guardadoEn: ahora,
        ),
      );

  Future<void> guardarPesaje(GalponSanidad galpon, double pesoG, int aves, DateTime ahora) => _operaciones.guardar(
    OperacionBodega(
      id: nuevoIdRegistro(),
      tipo: TipoOperacion.pesaje,
      fecha: fechaEnGranja(ahora),
      loteId: galpon.loteId,
      pesoG: pesoG,
      aves: aves,
      descripcion: 'Pesaje de ${galpon.galpon}: ${pesoG.round()} g',
      guardadoEn: ahora,
    ),
  );

  Future<void> deshacerAplicacion(String cumplimientoId) => _api.deshacerAplicacion(cumplimientoId);

  Future<List<OperacionBodega>> sinResolver() => _operaciones.sinResolver(tiposDeSanidad);

  Future<void> descartar(String id) => _operaciones.descartar(id);

  Future<ResultadoOperaciones> enviarOperaciones() => _operaciones.enviar();

  PanoramaSanidad _leer(String datos) => panoramaDesdeJson(jsonDecode(datos) as Map<String, dynamic>);
}
