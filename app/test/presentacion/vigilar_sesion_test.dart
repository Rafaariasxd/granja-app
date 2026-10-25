import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/servicio_sesion.dart';
import 'package:granja_app/presentacion/estado_sesion.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class Fuente extends ChangeNotifier {
  bool vencida = false;

  void avisar() => notifyListeners();
}

Future<EstadoSesion> conSesion() async {
  final cliente = MockClient(
    (_) async => http.Response.bytes(
      utf8.encode(jsonEncode({'token': 't', 'usuario_id': 1, 'nombre': 'Mamá', 'rol': 'registrador'})),
      200,
    ),
  );
  final estado = EstadoSesion(
    ServicioSesion(ApiGranja(Uri.parse('http://granja.test/'), cliente: cliente), AlmacenSesionEnMemoria()),
  );
  await estado.entrar('Mamá', '729104');
  return estado;
}

void main() {
  test('una fuente con la bandera vieja no saca de la sesión cuando avisa otra', () async {
    final estado = await conSesion();
    final vieja = Fuente()..vencida = true;
    final nueva = Fuente();
    estado
      ..vigilar(vieja, () => vieja.vencida)
      ..vigilar(nueva, () => nueva.vencida);

    nueva.avisar();
    await Future<void>.delayed(Duration.zero);

    expect(estado.sesion, isNotNull);
  });

  test('cuando la fuente dice que la sesión venció se cierra y se avisa', () async {
    final estado = await conSesion();
    final fuente = Fuente();
    estado.vigilar(fuente, () => fuente.vencida);

    fuente
      ..vencida = true
      ..avisar();
    await Future<void>.delayed(Duration.zero);

    expect(estado.sesion, isNull);
    expect(estado.error, 'La sesión se cerró. Vuelve a entrar.');
  });

  test('sin sesión abierta no hace nada', () async {
    final estado = EstadoSesion(ServicioSesion(ApiGranja(Uri.parse('http://granja.test/')), AlmacenSesionEnMemoria()));
    final fuente = Fuente()..vencida = true;
    estado.vigilar(fuente, () => fuente.vencida);

    fuente.avisar();
    await Future<void>.delayed(Duration.zero);

    expect(estado.error, isNull);
  });
}
