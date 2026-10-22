import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/dominio/modelos.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final base = Uri.parse('http://granja.test/api');

http.Response json(Object cuerpo, int codigo) => http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), codigo);

final registro = RegistroDiario(
  id: '6f1c2a8e-1b7e-4d0f-9a51-3c2e4b5d6f70',
  galponId: 1,
  fecha: DateTime.utc(2026, 10, 15),
  huevosTotal: 4000,
  mortalidad: 3,
  alimentoKg: 280.5,
);

void main() {
  test('el resumen trae los galpones con y sin lote', () async {
    late Uri pedida;
    final cliente = MockClient((peticion) async {
      pedida = peticion.url;
      return json([
        {
          'galpon_id': 1,
          'nombre': 'Galpón 1',
          'capacidad_aves': 6000,
          'lote_id': 7,
          'etapa': 'produccion',
          'edad_semanas': 32,
          'aves_vivas': 4950,
          'ocupacion_pct': 82.5,
          'postura_pct': 80.8,
        },
        {
          'galpon_id': 2,
          'nombre': 'Galpón 2',
          'capacidad_aves': 2000,
          'lote_id': null,
          'etapa': null,
          'edad_semanas': null,
          'aves_vivas': 0,
          'ocupacion_pct': 0,
          'postura_pct': null,
        },
      ], 200);
    });

    final resumen = await ApiGranja(base, cliente: cliente).resumen(DateTime.utc(2026, 10, 15));

    expect(pedida.path, '/api/galpones/resumen');
    expect(pedida.queryParameters['fecha'], '2026-10-15');
    expect(resumen.first.nombre, 'Galpón 1');
    expect(resumen.first.etapa, Etapa.produccion);
    expect(resumen.first.posturaPct, 80.8);
    expect(resumen.last.vacio, isTrue);
    expect(resumen.last.ocupacionPct, 0.0);
  });

  test('guardar el registro hace PUT con el id que generó el celular', () async {
    late http.Request enviada;
    final cliente = MockClient((peticion) async {
      enviada = peticion;
      return json({}, 200);
    });

    await ApiGranja(base, cliente: cliente).guardarRegistro(registro);

    expect(enviada.method, 'PUT');
    expect(enviada.url.path, '/api/registros/6f1c2a8e-1b7e-4d0f-9a51-3c2e4b5d6f70');
    expect(jsonDecode(enviada.body), {
      'id': '6f1c2a8e-1b7e-4d0f-9a51-3c2e4b5d6f70',
      'galpon_id': 1,
      'fecha': '2026-10-15',
      'huevos_total': 4000,
      'huevos_rotos': 0,
      'mortalidad': 3,
      'alimento_kg': 280.5,
    });
  });

  test('un 409 es un registro en conflicto con el mensaje del servidor', () async {
    final cliente = MockClient((_) async => json({'detail': 'ya hay un registro de Galpón 1 para 2026-10-15'}, 409));
    expect(
      () => ApiGranja(base, cliente: cliente).guardarRegistro(registro),
      throwsA(
        isA<RegistroEnConflicto>().having(
          (e) => e.mensaje,
          'mensaje',
          'ya hay un registro de Galpón 1 para 2026-10-15',
        ),
      ),
    );
  });

  test('un 422 son datos rechazados', () async {
    final cliente = MockClient(
      (_) async => json({'detail': 'el galpón Galpón 2 no tiene un lote activo ese día'}, 422),
    );
    expect(() => ApiGranja(base, cliente: cliente).guardarRegistro(registro), throwsA(isA<DatosRechazados>()));
  });

  test('sin red es SinConexion', () async {
    final cliente = MockClient((_) async => throw http.ClientException('sin red'));
    expect(() => ApiGranja(base, cliente: cliente).resumen(DateTime.utc(2026, 10, 15)), throwsA(isA<SinConexion>()));
  });

  test('trae el registro del día para poder corregirlo con el mismo id', () async {
    late Uri pedida;
    final cliente = MockClient((peticion) async {
      pedida = peticion.url;
      return json([
        {
          'id': '6f1c2a8e-1b7e-4d0f-9a51-3c2e4b5d6f70',
          'lote_id': 7,
          'fecha': '2026-10-15',
          'huevos_total': 4000,
          'huevos_rotos': 12,
          'mortalidad': 3,
          'alimento_kg': 280.5,
        },
      ], 200);
    });

    final encontrado = await ApiGranja(base, cliente: cliente).registroDelDia(1, DateTime.utc(2026, 10, 15));

    expect(pedida.path, '/api/registros');
    expect(pedida.queryParameters, {'galpon_id': '1', 'fecha': '2026-10-15'});
    expect(encontrado!.id, '6f1c2a8e-1b7e-4d0f-9a51-3c2e4b5d6f70');
    expect(encontrado.galponId, 1);
    expect(encontrado.huevosRotos, 12);
    expect(encontrado.alimentoKg, 280.5);
  });

  test('si ese día no hay registro no devuelve nada', () async {
    final cliente = MockClient((_) async => json([], 200));
    expect(await ApiGranja(base, cliente: cliente).registroDelDia(1, DateTime.utc(2026, 10, 15)), isNull);
  });

  test('un error raro del servidor no se confunde con un conflicto', () async {
    final cliente = MockClient((_) async => http.Response('falló', 500));
    expect(
      () => ApiGranja(base, cliente: cliente).resumen(DateTime.utc(2026, 10, 15)),
      throwsA(isA<ErrorDelServidor>()),
    );
  });
}
