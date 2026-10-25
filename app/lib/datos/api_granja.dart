import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../dominio/modelos.dart';
import '../dominio/sesion.dart';
import 'json.dart';

sealed class ErrorDeApi implements Exception {
  const ErrorDeApi(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

class SinConexion extends ErrorDeApi {
  const SinConexion() : super('no hay conexión con el servidor');
}

class RegistroEnConflicto extends ErrorDeApi {
  const RegistroEnConflicto(super.mensaje);
}

class DatosRechazados extends ErrorDeApi {
  const DatosRechazados(super.mensaje);
}

class CredencialesInvalidas extends ErrorDeApi {
  const CredencialesInvalidas(super.mensaje);
}

class CuentaBloqueada extends ErrorDeApi {
  const CuentaBloqueada(super.mensaje);
}

class SesionVencida extends ErrorDeApi {
  const SesionVencida() : super('la sesión se cerró, vuelve a entrar');
}

class SinPermiso extends ErrorDeApi {
  const SinPermiso(super.mensaje);
}

class ErrorDelServidor extends ErrorDeApi {
  const ErrorDelServidor(super.mensaje);
}

class ApiGranja {
  ApiGranja(Uri base, {http.Client? cliente, this.espera = const Duration(seconds: 15)})
    : base = base.path.endsWith('/') ? base : base.replace(path: '${base.path}/'),
      _cliente = cliente ?? http.Client();

  final Uri base;
  final Duration espera;
  final http.Client _cliente;
  String? token;

  Future<Sesion> iniciarSesion(String nombre, String pin) async {
    final respuesta = await _enviar(
      () => _cliente.post(
        base.resolve('sesion'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nombre': nombre, 'pin': pin}),
      ),
      alEntrar: true,
    );
    final datos = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
    final sesion = Sesion(
      token: datos['token'] as String,
      nombre: datos['nombre'] as String,
      rol: Rol.values.byName(datos['rol'] as String),
    );
    token = sesion.token;
    return sesion;
  }

  Future<void> cerrarSesion() async {
    try {
      await _enviar(() => _cliente.delete(base.resolve('sesion'), headers: _autorizacion()));
    } on ErrorDeApi catch (_) {
    } finally {
      token = null;
    }
  }

  Future<void> borrarRegistro(String id) async {
    await _enviar(() => _cliente.delete(base.resolve('registros/$id'), headers: _autorizacion()));
  }

  Future<String> inventarioJson() async {
    final respuesta = await _enviar(() => _cliente.get(base.resolve('inventario'), headers: _autorizacion()));
    return utf8.decode(respuesta.bodyBytes);
  }

  Future<void> registrarCompra(
    int insumoId, {
    required String operacionId,
    required int bodegaId,
    required double bultos,
    required String fecha,
  }) => _mandar('POST', 'insumos/$insumoId/compras', {
    'operacion_id': operacionId,
    'bodega_id': bodegaId,
    'bultos': bultos,
    'fecha': fecha,
  });

  Future<void> prepararAlimento(
    int productoId, {
    required String operacionId,
    required int desdeBodegaId,
    required int haciaBodegaId,
    required double kg,
    required String fecha,
  }) => _mandar('POST', 'alimentos/$productoId/preparaciones', {
    'operacion_id': operacionId,
    'desde_bodega_id': desdeBodegaId,
    'hacia_bodega_id': haciaBodegaId,
    'kg': kg,
    'fecha': fecha,
  });

  Future<String> galponesJson() => _leerJson('galpones');

  Future<String> insumosJson() => _leerJson('insumos');

  Future<String> formulaJson(int productoId) => _leerJson('alimentos/$productoId/formula');

  Future<void> crearBodega(String nombre, String tipo) => _mandar('POST', 'bodegas', {'nombre': nombre, 'tipo': tipo});

  Future<void> asignarGalpones(int bodegaId, List<int> galponIds) =>
      _mandar('PUT', 'bodegas/$bodegaId/galpones', {'galpon_ids': galponIds});

  Future<void> crearInsumo(Map<String, Object?> insumo) => _mandar('POST', 'insumos', insumo);

  Future<void> definirFormula(int productoId, List<Map<String, Object?>> ingredientes) =>
      _mandar('PUT', 'alimentos/$productoId/formula', ingredientes);

  Future<void> definirAlimentoEnUso(int bodegaId, String etapa, int insumoId) =>
      _mandar('PUT', 'bodegas/$bodegaId/alimento-en-uso/$etapa', {'insumo_id': insumoId});

  Future<String> _leerJson(String ruta) async {
    final respuesta = await _enviar(() => _cliente.get(base.resolve(ruta), headers: _autorizacion()));
    return utf8.decode(respuesta.bodyBytes);
  }

  Future<void> _mandar(String metodo, String ruta, Object cuerpo) async {
    await _enviar(() async {
      final peticion = http.Request(metodo, base.resolve(ruta))
        ..headers.addAll({'Content-Type': 'application/json', ..._autorizacion()})
        ..body = jsonEncode(cuerpo);
      return http.Response.fromStream(await _cliente.send(peticion));
    });
  }

  Map<String, String> _autorizacion() => {if (token != null) 'Authorization': 'Bearer $token'};

  Future<List<ResumenGalpon>> resumen(DateTime fecha) async {
    final url = base.resolve('galpones/resumen').replace(queryParameters: {'fecha': fechaIso(fecha)});
    final respuesta = await _enviar(() => _cliente.get(url, headers: _autorizacion()));
    final lista = jsonDecode(utf8.decode(respuesta.bodyBytes)) as List<dynamic>;
    return [for (final item in lista) resumenDesdeJson(item as Map<String, dynamic>)];
  }

  Future<RegistroDiario?> registroDelDia(int galponId, DateTime fecha) async {
    final url = base
        .resolve('registros')
        .replace(queryParameters: {'galpon_id': '$galponId', 'fecha': fechaIso(fecha)});
    final respuesta = await _enviar(() => _cliente.get(url, headers: _autorizacion()));
    final lista = jsonDecode(utf8.decode(respuesta.bodyBytes)) as List<dynamic>;
    if (lista.isEmpty) return null;
    return registroDesdeJson(lista.single as Map<String, dynamic>, galponId);
  }

  Future<void> guardarRegistro(RegistroDiario registro) async {
    await _enviar(
      () => _cliente.put(
        base.resolve('registros/${registro.id}'),
        headers: {'Content-Type': 'application/json', ..._autorizacion()},
        body: jsonEncode(registroAJson(registro)),
      ),
    );
  }

  Future<http.Response> _enviar(Future<http.Response> Function() peticion, {bool alEntrar = false}) async {
    final http.Response respuesta;
    try {
      respuesta = await peticion().timeout(espera);
    } on http.ClientException {
      throw const SinConexion();
    } on TimeoutException {
      throw const SinConexion();
    }
    final codigo = respuesta.statusCode;
    if (codigo >= 200 && codigo < 300) return respuesta;
    final detalle = _detalle(respuesta);
    if (codigo == 401) throw alEntrar ? CredencialesInvalidas(detalle) : const SesionVencida();
    if (codigo == 429) throw CuentaBloqueada(detalle);
    if (codigo == 403) throw SinPermiso(detalle);
    if (codigo == 409) throw RegistroEnConflicto(detalle);
    if (codigo == 404 || codigo == 422) throw DatosRechazados(detalle);
    throw ErrorDelServidor(detalle);
  }

  String _detalle(http.Response respuesta) {
    Object? cuerpo;
    try {
      cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes));
    } on FormatException {
      cuerpo = null;
    }
    if (cuerpo is Map<String, dynamic> && cuerpo['detail'] is String) {
      return cuerpo['detail'] as String;
    }
    return 'el servidor respondió ${respuesta.statusCode}';
  }
}
