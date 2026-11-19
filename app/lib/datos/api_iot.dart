import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../dominio/galpon_vivo.dart';

sealed class ErrorIot implements Exception {
  const ErrorIot(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

class SinConexionIot extends ErrorIot {
  const SinConexionIot() : super('Sin señal: el galpón en vivo necesita internet.');
}

class ClaveIotInvalida extends ErrorIot {
  const ClaveIotInvalida() : super('La clave del galpón no es correcta.');
}

class OrdenRechazada extends ErrorIot {
  const OrdenRechazada(super.mensaje);
}

class FalloIot extends ErrorIot {
  const FalloIot(super.mensaje);
}

abstract interface class AlmacenClaveIot {
  Future<String?> leer();
  Future<void> guardar(String clave);
  Future<void> borrar();
}

class AlmacenClaveIotSegura implements AlmacenClaveIot {
  AlmacenClaveIotSegura([FlutterSecureStorage? almacen]) : _almacen = almacen ?? const FlutterSecureStorage();

  final FlutterSecureStorage _almacen;
  static const _llave = 'clave_galpon_iot';

  @override
  Future<String?> leer() => _almacen.read(key: _llave);

  @override
  Future<void> guardar(String clave) => _almacen.write(key: _llave, value: clave);

  @override
  Future<void> borrar() => _almacen.delete(key: _llave);
}

class ApiIot {
  ApiIot(this.base, {http.Client? cliente, this.espera = const Duration(seconds: 20)})
    : _cliente = cliente ?? http.Client();

  final Uri base;
  final Duration espera;
  final http.Client _cliente;

  Future<List<DispositivoIot>> dispositivos() async {
    final datos = await _leer(base.resolve('api/dispositivos'));
    return [for (final d in datos as List) dispositivoDesdeJson(d as Map<String, Object?>)];
  }

  Future<List<AlertaIot>> alertasActivas() async {
    final datos = await _leer(base.resolve('api/alertas?abiertas=true&limite=50'));
    return [for (final a in datos as List) alertaDesdeJson(a as Map<String, Object?>)];
  }

  Future<SerieIot> serie(String dispositivo, String variable, {int horas = 24}) async {
    final url = base
        .resolve('api/dispositivos/$dispositivo/serie')
        .replace(queryParameters: {'variable': variable, 'horas': '$horas'});
    return serieDesdeJson(await _leer(url) as Map<String, Object?>);
  }

  Future<String> ordenar(String dispositivo, ComandoIot comando, String? clave) async {
    final respuesta = await _pedir(
      () => _cliente.post(
        base.resolve('api/dispositivos/$dispositivo/comandos'),
        headers: {'Content-Type': 'application/json', if (clave != null) 'Authorization': 'Bearer $clave'},
        body: jsonEncode({'accion': comando.accion, 'parametros': comando.parametros}),
      ),
    );
    final cuerpo = _json(respuesta);
    if (respuesta.statusCode == 401) throw const ClaveIotInvalida();
    if (respuesta.statusCode == 422 || respuesta.statusCode == 404) {
      throw OrdenRechazada(_detalle(cuerpo) ?? 'El dispositivo no acepta esa orden.');
    }
    if (respuesta.statusCode >= 400) throw FalloIot(_detalle(cuerpo) ?? 'No se pudo enviar la orden.');
    return (cuerpo as Map<String, Object?>)['estado'] as String? ?? 'enviado';
  }

  Future<Object?> _leer(Uri url) async {
    final respuesta = await _pedir(() => _cliente.get(url));
    if (respuesta.statusCode >= 400) throw FalloIot('El galpón respondió ${respuesta.statusCode}.');
    return _json(respuesta);
  }

  Future<http.Response> _pedir(Future<http.Response> Function() peticion) async {
    try {
      return await peticion().timeout(espera);
    } on TimeoutException {
      throw const SinConexionIot();
    } on http.ClientException {
      throw const SinConexionIot();
    } on SocketException {
      throw const SinConexionIot();
    }
  }

  Object? _json(http.Response respuesta) {
    if (respuesta.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(respuesta.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  String? _detalle(Object? cuerpo) {
    final detalle = cuerpo is Map ? cuerpo['detail'] : null;
    return detalle is String ? detalle : null;
  }
}

double _numero(Object? valor) => (valor as num).toDouble();

DateTime? _fecha(Object? valor) => valor is String ? DateTime.parse(valor) : null;

DispositivoIot dispositivoDesdeJson(Map<String, Object?> j) {
  final variables = (j['variables'] as Map<String, Object?>).entries.map((e) {
    final v = e.value as Map<String, Object?>;
    return VariableIot(
      nombre: e.key,
      unidad: v['unidad'] as String? ?? '',
      minimo: _numero(v['min'] ?? 0),
      maximo: _numero(v['max'] ?? 0),
    );
  }).toList();
  final ultimos = <String, LecturaIot>{};
  (j['ultimos'] as Map<String, Object?>? ?? {}).forEach((nombre, valor) {
    final lectura = valor as Map<String, Object?>;
    ultimos[nombre] = LecturaIot(valor: _numero(lectura['valor']), momento: DateTime.parse(lectura['ts'] as String));
  });
  return DispositivoIot(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    categoria: j['categoria'] as String? ?? '',
    protocolo: j['protocolo'] as String? ?? '',
    ubicacion: j['ubicacion'] as String? ?? '',
    descripcion: j['descripcion'] as String? ?? '',
    enLinea: j['en_linea'] == true,
    ultimoContacto: _fecha(j['ultimo_contacto']),
    variables: variables,
    ultimos: ultimos,
    acciones: [for (final a in j['acciones'] as List? ?? const []) a as String],
    estado: Map<String, Object?>.from(j['estado'] as Map? ?? const {}),
  );
}

AlertaIot alertaDesdeJson(Map<String, Object?> j) => AlertaIot(
  dispositivo: j['dispositivo'] as String,
  variable: j['variable'] as String,
  nivel: j['nivel'] as String,
  mensaje: j['mensaje'] as String,
  valorExtremo: _numero(j['valor_extremo']),
  inicio: DateTime.parse(j['inicio'] as String),
  fin: _fecha(j['fin']),
);

SerieIot serieDesdeJson(Map<String, Object?> j) {
  final resumen = j['resumen'] as Map<String, Object?>?;
  return SerieIot(
    unidad: j['unidad'] as String? ?? '',
    puntos: [
      for (final p in j['puntos'] as List)
        PuntoSerie(
          momento: DateTime.parse((p as Map<String, Object?>)['ts'] as String),
          promedio: _numero(p['promedio']),
          minimo: _numero(p['min']),
          maximo: _numero(p['max']),
        ),
    ],
    promedio: resumen == null ? null : _numero(resumen['promedio']),
    minimo: resumen == null ? null : _numero(resumen['min']),
    maximo: resumen == null ? null : _numero(resumen['max']),
  );
}
