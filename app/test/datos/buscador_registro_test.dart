import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/buscador_registro.dart';
import 'package:granja_app/datos/cola.dart';
import 'package:granja_app/dominio/modelos.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final hoy = DateTime.utc(2026, 10, 25);
final base = Uri.parse('http://granja.test/');

RegistroDiario registro(String id, {int huevos = 1400, int galpon = 3, DateTime? fecha}) =>
    RegistroDiario(id: id, galponId: galpon, fecha: fecha ?? hoy, huevosTotal: huevos);

CambioRegistro cambio(RegistroDiario r, EstadoEnvio estado, {int minutos = 0}) =>
    CambioRegistro(registro: r, guardadoEn: DateTime.utc(2026, 10, 25, 12, minutos), estado: estado);

http.Response remoto(String id, {int huevos = 1500}) => http.Response.bytes(
  utf8.encode(
    jsonEncode([
      {
        'id': id,
        'lote_id': 8,
        'fecha': '2026-10-25',
        'huevos_total': huevos,
        'huevos_rotos': 0,
        'mortalidad': 0,
        'alimento_kg': 0,
      },
    ]),
  ),
  200,
);

BuscadorRegistro buscador(AlmacenEnMemoria almacen, http.Response Function() servidor, [List<String>? llamadas]) {
  final cliente = MockClient((p) async {
    llamadas?.add(p.url.path);
    return servidor();
  });
  return BuscadorRegistro(ApiGranja(base, cliente: cliente), almacen);
}

void main() {
  test('un registro que aún no se envió se corrige desde el teléfono, sin preguntar al servidor', () async {
    final almacen = AlmacenEnMemoria()..guardar(cambio(registro('a'), EstadoEnvio.pendiente));
    final llamadas = <String>[];

    final encontrado = await buscador(almacen, () => http.Response('', 500), llamadas).buscar(3, hoy);

    expect(encontrado!.registro.id, 'a');
    expect(encontrado.sinEnviar, isTrue);
    expect(llamadas, isEmpty);
  });

  test('uno en conflicto también se trae del teléfono', () async {
    final almacen = AlmacenEnMemoria()..guardar(cambio(registro('a'), EstadoEnvio.enConflicto));
    expect((await buscador(almacen, () => http.Response('', 500)).buscar(3, hoy))!.sinEnviar, isTrue);
  });

  test('si no hay nada sin enviar, manda lo que tiene el servidor', () async {
    final almacen = AlmacenEnMemoria()..guardar(cambio(registro('a'), EstadoEnvio.enviado));

    final encontrado = await buscador(almacen, () => remoto('a', huevos: 1500)).buscar(3, hoy);

    expect(encontrado!.registro.huevosTotal, 1500);
    expect(encontrado.sinEnviar, isFalse);
  });

  test('sin señal usa el último que ya se había enviado', () async {
    final almacen = AlmacenEnMemoria()
      ..guardar(cambio(registro('a', huevos: 1300), EstadoEnvio.enviado))
      ..guardar(cambio(registro('b', huevos: 1400), EstadoEnvio.enviado, minutos: 5));
    final cliente = MockClient((_) async => throw http.ClientException('sin red'));

    final encontrado = await BuscadorRegistro(ApiGranja(base, cliente: cliente), almacen).buscar(3, hoy);

    expect(encontrado!.registro.id, 'b');
    expect(encontrado.sinEnviar, isFalse);
  });

  test('sin señal y sin nada guardado avisa que no hay conexión', () async {
    final cliente = MockClient((_) async => throw http.ClientException('sin red'));
    final buscar = BuscadorRegistro(ApiGranja(base, cliente: cliente), AlmacenEnMemoria()).buscar(3, hoy);

    await expectLater(buscar, throwsA(isA<SinConexion>()));
  });

  test('si el registro no existe en ninguna parte devuelve nada', () async {
    final encontrado = await buscador(AlmacenEnMemoria(), () => http.Response('[]', 200)).buscar(3, hoy);

    expect(encontrado, isNull);
  });

  test('un registro de otro galpón u otro día no se confunde', () async {
    final almacen = AlmacenEnMemoria()
      ..guardar(cambio(registro('a', galpon: 4), EstadoEnvio.pendiente))
      ..guardar(cambio(registro('b', fecha: DateTime.utc(2026, 10, 24)), EstadoEnvio.pendiente));

    final encontrado = await buscador(almacen, () => http.Response('[]', 200)).buscar(3, hoy);

    expect(encontrado, isNull);
  });
}
