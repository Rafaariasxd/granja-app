import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/cola.dart';
import 'package:granja_app/datos/sincronizador.dart';
import 'package:granja_app/dominio/modelos.dart';
import 'package:granja_app/presentacion/estado_envios.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final ahora = DateTime.utc(2026, 10, 21, 12);

RegistroDiario registro(String id, {int galpon = 1}) =>
    RegistroDiario(id: id, galponId: galpon, fecha: DateTime.utc(2026, 10, 21), huevosTotal: 1405);

http.Response ok() => http.Response.bytes(utf8.encode('{}'), 200);

EstadoEnvios crear(Future<http.Response> Function(http.Request) servidor) {
  final almacen = AlmacenEnMemoria();
  final api = ApiGranja(Uri.parse('http://granja.test/'), cliente: MockClient(servidor));
  return EstadoEnvios(Sincronizador(almacen, api), almacen);
}

void main() {
  test('con señal, guardar envía enseguida y queda todo enviado', () async {
    final estado = crear((_) async => ok());
    await estado.guardar(registro('a'), ahora);
    expect(estado.todoEnviado, isTrue);
    expect(estado.ultimoEnvioFallo, isFalse);
  });

  test('sin señal queda en el celular y lo cuenta', () async {
    final estado = crear((_) async => throw http.ClientException('sin red'));
    await estado.guardar(registro('a'), ahora);
    await estado.guardar(registro('b', galpon: 2), ahora);
    expect(estado.pendientes, 2);
    expect(estado.ultimoEnvioFallo, isTrue);
    expect(estado.todoEnviado, isFalse);
  });

  test('un conflicto se cuenta aparte para mostrarlo', () async {
    final estado = crear((_) async => http.Response.bytes(utf8.encode(jsonEncode({'detail': 'ya hay'})), 409));
    await estado.guardar(registro('a'), ahora);
    expect(estado.pendientes, 0);
    expect(estado.enConflicto, 1);
    expect(estado.todoEnviado, isFalse);
  });

  test('dos envíos al mismo tiempo no mandan el registro dos veces', () async {
    var pedidos = 0;
    final respuesta = Completer<http.Response>();
    final almacen = AlmacenEnMemoria();
    final api = ApiGranja(
      Uri.parse('http://granja.test/'),
      cliente: MockClient((_) {
        pedidos++;
        return respuesta.future;
      }),
    );
    final estado = EstadoEnvios(Sincronizador(almacen, api), almacen);
    await Sincronizador(almacen, api).registrar(registro('a'), ahora);

    final primero = estado.enviar();
    final segundo = estado.enviar();
    respuesta.complete(ok());
    await Future.wait([primero, segundo]);

    expect(pedidos, 1);
    expect(estado.todoEnviado, isTrue);
  });

  test('avisa a la pantalla mientras envía y al terminar', () async {
    final estado = crear((_) async => ok());
    final enviandoVisto = <bool>[];
    estado.addListener(() => enviandoVisto.add(estado.enviando));
    await estado.guardar(registro('a'), ahora);
    expect(enviandoVisto, [false, true, false]);
  });

  test('cuando vuelve la señal envía lo que quedó en el celular', () async {
    var haySenal = false;
    final estado = crear((_) async => haySenal ? ok() : throw http.ClientException('sin red'));
    final conexion = StreamController<bool>();
    estado.escucharConexion(conexion.stream);
    await estado.guardar(registro('a'), ahora);
    expect(estado.pendientes, 1);

    haySenal = true;
    conexion.add(true);
    await pumpEventQueue();

    expect(estado.todoEnviado, isTrue);
    await conexion.close();
    estado.dispose();
  });

  test('perder la señal no intenta enviar', () async {
    var pedidos = 0;
    final estado = crear((_) async {
      pedidos++;
      return ok();
    });
    final conexion = StreamController<bool>();
    estado.escucharConexion(conexion.stream);

    conexion.add(false);
    await pumpEventQueue();

    expect(pedidos, 0);
    await conexion.close();
    estado.dispose();
  });
}
