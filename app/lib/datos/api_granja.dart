import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../dominio/modelos.dart';
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

  Future<List<ResumenGalpon>> resumen(DateTime fecha) async {
    final url = base.resolve('galpones/resumen').replace(queryParameters: {'fecha': fechaIso(fecha)});
    final respuesta = await _enviar(() => _cliente.get(url));
    final lista = jsonDecode(utf8.decode(respuesta.bodyBytes)) as List<dynamic>;
    return [for (final item in lista) resumenDesdeJson(item as Map<String, dynamic>)];
  }

  Future<RegistroDiario?> registroDelDia(int galponId, DateTime fecha) async {
    final url = base
        .resolve('registros')
        .replace(queryParameters: {'galpon_id': '$galponId', 'fecha': fechaIso(fecha)});
    final respuesta = await _enviar(() => _cliente.get(url));
    final lista = jsonDecode(utf8.decode(respuesta.bodyBytes)) as List<dynamic>;
    if (lista.isEmpty) return null;
    return registroDesdeJson(lista.single as Map<String, dynamic>, galponId);
  }

  Future<void> guardarRegistro(RegistroDiario registro) async {
    await _enviar(
      () => _cliente.put(
        base.resolve('registros/${registro.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(registroAJson(registro)),
      ),
    );
  }

  Future<http.Response> _enviar(Future<http.Response> Function() peticion) async {
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
