import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/servicio_sesion.dart';
import 'package:granja_app/dominio/sesion.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final base = Uri.parse('http://granja.test/');

http.Response json(Object cuerpo, int codigo) => http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), codigo);

final sesionOk = {'token': 'abc123', 'usuario_id': 2, 'nombre': 'Mamá', 'rol': 'registrador'};

void main() {
  test('entrar guarda el token y los pedidos siguientes lo llevan', () async {
    final autorizaciones = <String?>[];
    final cliente = MockClient((peticion) async {
      autorizaciones.add(peticion.headers['Authorization']);
      if (peticion.url.path == '/sesion') {
        expect(jsonDecode(peticion.body), {'nombre': 'Mamá', 'pin': '729104'});
        return json(sesionOk, 200);
      }
      return json([], 200);
    });
    final api = ApiGranja(base, cliente: cliente);

    final sesion = await api.iniciarSesion('Mamá', '729104');
    await api.resumen(DateTime.utc(2026, 10, 15));

    expect(sesion.rol, Rol.registrador);
    expect(autorizaciones, [null, 'Bearer abc123']);
  });

  test('un PIN incorrecto no se confunde con una sesión vencida', () async {
    final api = ApiGranja(base, cliente: MockClient((_) async => json({'detail': 'nombre o PIN incorrectos'}, 401)));
    await expectLater(api.iniciarSesion('Mamá', '000001'), throwsA(isA<CredencialesInvalidas>()));
  });

  test('el bloqueo por intentos llega como cuenta bloqueada', () async {
    final api = ApiGranja(base, cliente: MockClient((_) async => json({'detail': 'espera 15 minutos'}, 429)));
    await expectLater(api.iniciarSesion('Mamá', '729104'), throwsA(isA<CuentaBloqueada>()));
  });

  test('un 401 con la sesión abierta es sesión vencida y un 403 es falta de permiso', () async {
    var codigo = 401;
    final api = ApiGranja(base, cliente: MockClient((_) async => json({'detail': 'x'}, codigo)));
    await expectLater(api.resumen(DateTime.utc(2026, 10, 15)), throwsA(isA<SesionVencida>()));
    codigo = 403;
    await expectLater(api.borrarRegistro('a'), throwsA(isA<SinPermiso>()));
  });

  test('borrar un registro llama al DELETE con el token', () async {
    late http.Request pedida;
    final api = ApiGranja(
      base,
      cliente: MockClient((peticion) async {
        pedida = peticion;
        return http.Response('', 204);
      }),
    )..token = 'abc123';

    await api.borrarRegistro('6f1c');

    expect(pedida.method, 'DELETE');
    expect(pedida.url.path, '/registros/6f1c');
    expect(pedida.headers['Authorization'], 'Bearer abc123');
  });

  group('servicio de sesión', () {
    late AlmacenSesionEnMemoria almacen;
    late ApiGranja api;
    late ServicioSesion servicio;
    late List<String> pedidos;

    setUp(() {
      almacen = AlmacenSesionEnMemoria();
      pedidos = [];
      api = ApiGranja(
        base,
        cliente: MockClient((peticion) async {
          pedidos.add('${peticion.method} ${peticion.url.path}');
          return peticion.method == 'POST' ? json(sesionOk, 200) : http.Response('', 204);
        }),
      );
      servicio = ServicioSesion(api, almacen);
    });

    test('la sesión queda guardada y se recupera al abrir la app', () async {
      await servicio.entrar('  Mamá ', '729104');

      final otro = ServicioSesion(ApiGranja(base, cliente: MockClient((_) async => json([], 200))), almacen);
      final recuperada = await otro.restaurar();

      expect(recuperada?.nombre, 'Mamá');
      expect(otro.actual?.token, 'abc123');
    });

    test('al salir se borra del teléfono aunque no haya señal', () async {
      await servicio.entrar('Mamá', '729104');
      final sinSenal = ServicioSesion(
        ApiGranja(base, cliente: MockClient((_) async => throw http.ClientException('sin red'))),
        almacen,
      );
      await sinSenal.restaurar();

      await sinSenal.salir();

      expect(await almacen.leer(), isNull);
      expect(sinSenal.actual, isNull);
    });

    test('descartar borra la sesión sin avisar al servidor', () async {
      await servicio.entrar('Mamá', '729104');
      pedidos.clear();

      await servicio.descartar();

      expect(pedidos, isEmpty);
      expect(await almacen.leer(), isNull);
      expect(api.token, isNull);
    });
  });

  test('una sesión guardada a medias o con rol raro no se acepta', () {
    expect(Sesion.desdeMapa({'token': 'a', 'nombre': 'x', 'rol': 'dios'}), isNull);
    expect(Sesion.desdeMapa({'token': '', 'nombre': 'x', 'rol': 'registrador'}), isNull);
    expect(Sesion.desdeMapa({'token': 'a', 'nombre': null, 'rol': 'registrador'}), isNull);
    expect(Sesion.desdeMapa({'token': 'a', 'nombre': 'x', 'rol': 'administrador'})?.esAdministrador, isTrue);
  });
}
