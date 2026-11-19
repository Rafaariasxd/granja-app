import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_iot.dart';
import 'package:granja_app/dominio/galpon_vivo.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final dispositivosJson = [
  {
    'id': 'galpon1-ambiente',
    'nombre': 'Ambiente galpón 1',
    'categoria': 'Gemelo digital',
    'origen': 'Python',
    'protocolo': 'MQTT',
    'ubicacion': 'Galpón 1',
    'descripcion': 'Temperatura y humedad dentro del galpón.',
    'variables': {
      'temperatura': {'unidad': '°C', 'min': 15, 'max': 40},
      'humedad': {'unidad': '%', 'min': 30, 'max': 100},
    },
    'acciones': ['apagar', 'encender', 'intervalo', 'calibrar', 'reiniciar_calibracion'],
    'en_linea': true,
    'ultimo_contacto': '2026-11-19T07:17:54+00:00',
    'estado': {'encendido': true, 'intervalo_s': 60, 'calibracion': <String, Object?>{}},
    'ultimos': {
      'temperatura': {'ts': '2026-11-19T07:17:54+00:00', 'valor': 24.06},
      'humedad': {'ts': '2026-11-19T07:17:54+00:00', 'valor': 76.5},
    },
  },
  {
    'id': 'galpon1-ventilacion',
    'nombre': 'Ventiladores galpón 1',
    'categoria': 'Gemelo digital',
    'protocolo': 'MQTT',
    'ubicacion': 'Galpón 1',
    'descripcion': 'Extractores.',
    'variables': {
      'velocidad': {'unidad': '%', 'min': 0, 'max': 100},
      'modo_auto': {'unidad': '1/0', 'min': 0, 'max': 1},
    },
    'acciones': ['apagar', 'encender', 'velocidad', 'modo'],
    'en_linea': true,
    'ultimo_contacto': '2026-11-19T07:17:53+00:00',
    'estado': {'encendido': true, 'intervalo_s': 60, 'modo': 'auto'},
    'ultimos': {
      'velocidad': {'ts': '2026-11-19T07:17:53+00:00', 'valor': 80},
      'modo_auto': {'ts': '2026-11-19T07:17:53+00:00', 'valor': 1},
    },
  },
  {
    'id': 'galpon1-gases',
    'nombre': 'Gases galpón 1',
    'categoria': 'Gemelo digital',
    'protocolo': 'MQTT',
    'ubicacion': 'Galpón 1',
    'descripcion': 'Amoníaco y CO2.',
    'variables': {
      'amoniaco': {'unidad': 'ppm', 'min': 0, 'max': 60},
    },
    'acciones': ['apagar', 'encender'],
    'en_linea': false,
    'ultimo_contacto': null,
    'estado': {'encendido': false},
    'ultimos': <String, Object?>{},
  },
];

final alertasJson = [
  {
    'id': 7,
    'regla': 4,
    'dispositivo': 'galpon1-gases',
    'variable': 'amoniaco',
    'nivel': 'crítica',
    'mensaje': 'Amoníaco sobre 25 ppm',
    'valor': 26.0,
    'valor_extremo': 27.4,
    'inicio': '2026-11-18T13:50:01+00:00',
    'fin': null,
  },
];

final serieJson = {
  'dispositivo': 'galpon1-ambiente',
  'variable': 'temperatura',
  'unidad': '°C',
  'paso_s': 300,
  'resumen': {'promedio': 24.1, 'min': 19.5, 'max': 31.8, 'lecturas': 3},
  'puntos': [
    {'ts': '2026-11-18T08:00:00+00:00', 'promedio': 20.0, 'min': 19.5, 'max': 20.4, 'n': 1},
    {'ts': '2026-11-18T14:00:00+00:00', 'promedio': 31.0, 'min': 30.2, 'max': 31.8, 'n': 1},
    {'ts': '2026-11-18T20:00:00+00:00', 'promedio': 22.0, 'min': 21.5, 'max': 22.3, 'n': 1},
  ],
};

http.Response json(Object? cuerpo, [int estado = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), estado, headers: {'content-type': 'application/json'});

void main() {
  final base = Uri.parse('https://galpon.test');

  test('lee dispositivos con sus variables, últimos valores y estado', () async {
    final api = ApiIot(base, cliente: MockClient((p) async => json(dispositivosJson)));
    final lista = await api.dispositivos();
    expect(lista.map((d) => d.id), ['galpon1-ambiente', 'galpon1-ventilacion', 'galpon1-gases']);
    final ambiente = lista.first;
    expect(ambiente.valor('temperatura'), 24.06);
    expect(ambiente.variables.first.unidad, '°C');
    expect(ambiente.enLinea, isTrue);
    expect(lista.last.encendido, isFalse);
    expect(lista.last.ultimoContacto, isNull);
    expect(lista[1].permite('velocidad'), isTrue);
  });

  test('lee alertas activas y la serie con su resumen', () async {
    final api = ApiIot(
      base,
      cliente: MockClient((p) async {
        if (p.url.path.endsWith('alertas')) {
          expect(p.url.queryParameters['abiertas'], 'true');
          return json(alertasJson);
        }
        expect(p.url.queryParameters, {'variable': 'temperatura', 'horas': '24'});
        return json(serieJson);
      }),
    );
    final alertas = await api.alertasActivas();
    expect(alertas.single.critica, isTrue);
    expect(alertas.single.valorExtremo, 27.4);
    final serie = await api.serie('galpon1-ambiente', 'temperatura');
    expect(serie.puntos, hasLength(3));
    expect(serie.maximo, 31.8);
  });

  test('una orden lleva la clave y devuelve si salió por MQTT o quedó en cola', () async {
    late http.Request enviada;
    final api = ApiIot(
      base,
      cliente: MockClient((p) async {
        enviada = p;
        return json({'estado': 'enviado'}, 202);
      }),
    );
    final estado = await api.ordenar(
      'galpon1-ventilacion',
      const ComandoIot(accion: 'velocidad', parametros: {'valor': 70}),
      'secreta',
    );
    expect(estado, 'enviado');
    expect(enviada.headers['Authorization'], 'Bearer secreta');
    expect(jsonDecode(enviada.body), {
      'accion': 'velocidad',
      'parametros': {'valor': 70},
    });
  });

  test('traduce los errores de la API', () async {
    Future<void> ordenarCon(http.Response respuesta) => ApiIot(
      base,
      cliente: MockClient((_) async => respuesta),
    ).ordenar('x', const ComandoIot(accion: 'apagar'), null);

    await expectLater(ordenarCon(json({'detail': 'no'}, 401)), throwsA(isA<ClaveIotInvalida>()));
    await expectLater(
      ordenarCon(json({'detail': 'Acción no permitida'}, 422)),
      throwsA(isA<OrdenRechazada>().having((e) => e.mensaje, 'mensaje', 'Acción no permitida')),
    );
    final caido = ApiIot(base, cliente: MockClient((_) async => throw http.ClientException('sin red')));
    await expectLater(caido.dispositivos(), throwsA(isA<SinConexionIot>()));
  });
}
