import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/cola.dart';
import 'package:granja_app/datos/sincronizador.dart';
import 'package:granja_app/dominio/modelos.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final base = Uri.parse('http://granja.test/');
final manana = DateTime.utc(2026, 10, 15, 11);

RegistroDiario registro(String id, {int galpon = 1, int huevos = 4000}) =>
    RegistroDiario(id: id, galponId: galpon, fecha: DateTime.utc(2026, 10, 15), huevosTotal: huevos);

http.Response respuesta(int codigo, [String detalle = '']) =>
    http.Response.bytes(utf8.encode(jsonEncode({'detail': detalle})), codigo);

class Servidor {
  final pedidos = <String>[];
  http.Response Function(http.Request) responder = (_) => respuesta(200);

  MockClient get cliente => MockClient((peticion) async {
    pedidos.add(peticion.url.pathSegments.last);
    return responder(peticion);
  });
}

void main() {
  group('sesión', _pruebasDeSesion);

  late AlmacenEnMemoria almacen;
  late Servidor servidor;
  late Sincronizador sincronizador;

  setUp(() {
    almacen = AlmacenEnMemoria();
    servidor = Servidor();
    sincronizador = Sincronizador(almacen, ApiGranja(base, cliente: servidor.cliente));
  });

  test('lo registrado queda pendiente hasta que se envía', () async {
    await sincronizador.registrar(registro('a'), manana);
    expect((await almacen.porEnviar()).single.registro.id, 'a');

    final resultado = await sincronizador.enviarPendientes();

    expect(resultado.enviados, 1);
    expect(resultado.quedanPendientes, isFalse);
    expect(await almacen.porEnviar(), isEmpty);
    expect((await almacen.todos()).single.estado, EstadoEnvio.enviado);
  });

  test('corregir antes de enviar reemplaza el registro, no lo duplica', () async {
    await sincronizador.registrar(registro('a', huevos: 4000), manana);
    await sincronizador.registrar(registro('a', huevos: 4100), manana.add(const Duration(minutes: 5)));

    final pendientes = await almacen.porEnviar();

    expect(pendientes, hasLength(1));
    expect(pendientes.single.registro.huevosTotal, 4100);
  });

  test('se envía en el orden en que se registró', () async {
    await sincronizador.registrar(registro('segundo', galpon: 2), manana.add(const Duration(minutes: 1)));
    await sincronizador.registrar(registro('primero', galpon: 1), manana);

    await sincronizador.enviarPendientes();

    expect(servidor.pedidos, ['primero', 'segundo']);
  });

  test('sin señal se detiene y no pierde nada', () async {
    servidor.responder = (_) => throw http.ClientException('sin red');
    await sincronizador.registrar(registro('a'), manana);
    await sincronizador.registrar(registro('b', galpon: 2), manana.add(const Duration(minutes: 1)));

    final resultado = await sincronizador.enviarPendientes();

    expect(resultado.quedanPendientes, isTrue);
    expect(servidor.pedidos, ['a']);
    final pendientes = await almacen.porEnviar();
    expect(pendientes.map((c) => c.registro.id), ['a', 'b']);
    expect(pendientes.first.intentos, 1);
  });

  test('un conflicto queda marcado con el mensaje y no se reintenta', () async {
    servidor.responder = (_) => respuesta(409, 'ya hay un registro de Galpón 1 para 2026-10-15');
    await sincronizador.registrar(registro('a'), manana);

    await sincronizador.enviarPendientes();

    final cambio = (await almacen.todos()).single;
    expect(cambio.estado, EstadoEnvio.enConflicto);
    expect(cambio.mensaje, 'ya hay un registro de Galpón 1 para 2026-10-15');
    expect(await almacen.porEnviar(), isEmpty);
  });

  test('un rechazo no frena a los demás', () async {
    servidor.responder = (peticion) => peticion.url.pathSegments.last == 'a'
        ? respuesta(422, 'el galpón no tiene un lote activo ese día')
        : respuesta(200);
    await sincronizador.registrar(registro('a'), manana);
    await sincronizador.registrar(registro('b', galpon: 2), manana.add(const Duration(minutes: 1)));

    final resultado = await sincronizador.enviarPendientes();

    expect(resultado.enviados, 1);
    final estados = {for (final c in await almacen.todos()) c.registro.id: c.estado};
    expect(estados, {'a': EstadoEnvio.rechazado, 'b': EstadoEnvio.enviado});
  });

  test('un error del servidor deja el registro pendiente para después', () async {
    servidor.responder = (_) => http.Response('falló', 500);
    await sincronizador.registrar(registro('a'), manana);

    final resultado = await sincronizador.enviarPendientes();

    expect(resultado.quedanPendientes, isTrue);
    expect((await almacen.porEnviar()).single.intentos, 1);
  });

  test('una corrección después de enviar se vuelve a enviar', () async {
    await sincronizador.registrar(registro('a', huevos: 4000), manana);
    await sincronizador.enviarPendientes();
    await sincronizador.registrar(registro('a', huevos: 4100), manana.add(const Duration(hours: 2)));

    await sincronizador.enviarPendientes();

    expect(servidor.pedidos, ['a', 'a']);
    expect((await almacen.todos()).single.estado, EstadoEnvio.enviado);
  });
}

void _pruebasDeSesion() {
  late AlmacenEnMemoria almacen;
  late Servidor servidor;
  late Sincronizador sincronizador;

  setUp(() {
    almacen = AlmacenEnMemoria();
    servidor = Servidor();
    sincronizador = Sincronizador(almacen, ApiGranja(base, cliente: servidor.cliente));
  });

  test('con la sesión vencida no pierde nada y avisa para volver a entrar', () async {
    await sincronizador.registrar(registro('a'), manana);
    await sincronizador.registrar(registro('b', galpon: 2), manana);
    servidor.responder = (_) => respuesta(401, 'no autenticado');

    final resultado = await sincronizador.enviarPendientes();

    expect(resultado.sesionVencida, isTrue);
    expect(resultado.quedanPendientes, isTrue);
    expect(servidor.pedidos, ['a']);
    expect((await almacen.porEnviar()).map((c) => c.registro.id), ['a', 'b']);
  });

  test('si no tiene permiso, el cambio queda rechazado y sigue con los demás', () async {
    await sincronizador.registrar(registro('a'), manana);
    await sincronizador.registrar(registro('b', galpon: 2), manana);
    servidor.responder = (p) => p.url.pathSegments.last == 'a' ? respuesta(403, 'sin permiso') : respuesta(200);

    final resultado = await sincronizador.enviarPendientes();

    expect(resultado.enviados, 1);
    final estados = {for (final c in await almacen.todos()) c.registro.id: c.estado};
    expect(estados, {'a': EstadoEnvio.rechazado, 'b': EstadoEnvio.enviado});
  });
}
