import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/cola.dart';
import 'package:granja_app/datos/resumen.dart';
import 'package:granja_app/datos/sincronizador.dart';
import 'package:granja_app/dominio/modelos.dart';
import 'package:granja_app/presentacion/estado_envios.dart';
import 'package:granja_app/presentacion/estado_inicio.dart';
import 'package:granja_app/presentacion/formato.dart';
import 'package:granja_app/presentacion/inicio.dart';
import 'package:granja_app/presentacion/tema.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final base = Uri.parse('http://granja.test/');
final ahora = DateTime.utc(2026, 10, 21, 17);

Map<String, Object?> galpon(
  int id, {
  int? lote,
  String? etapa,
  int? semanas,
  int vivas = 0,
  double? postura,
  int? huevos,
  String? linea,
}) => {
  'galpon_id': id,
  'nombre': 'Galpón $id',
  'capacidad_aves': 5000,
  'lote_id': lote,
  'etapa': etapa,
  'edad_semanas': semanas,
  'aves_vivas': vivas,
  'ocupacion_pct': 0.0,
  'postura_pct': postura,
  'linea': linea,
  'huevos_del_dia': huevos,
};

final tablero = [
  galpon(1, lote: 7, etapa: 'produccion', semanas: 32, vivas: 2476, postura: 86.0, huevos: 2130, linea: 'Hy-Line'),
  galpon(2),
  galpon(3, lote: 8, etapa: 'produccion', semanas: 45, vivas: 1612, linea: 'Lohmann'),
  galpon(5, lote: 9, etapa: 'levante', semanas: 12, vivas: 948, huevos: 0, linea: 'Hy-Line'),
  galpon(4),
];

class Montaje {
  Montaje(Object? Function(http.Request) servidor) {
    final cliente = MockClient((peticion) async {
      final cuerpo = servidor(peticion);
      if (cuerpo is http.Response) return cuerpo;
      return http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), 200);
    });
    final api = ApiGranja(base, cliente: cliente);
    final almacen = AlmacenEnMemoria();
    envios = EstadoEnvios(Sincronizador(almacen, api), almacen);
    almacenResumen = AlmacenResumenEnMemoria();
    estado = EstadoInicio(RepositorioResumen(api, almacenResumen), reloj: () => ahora);
  }

  late final EstadoEnvios envios;
  late final AlmacenResumenEnMemoria almacenResumen;
  late final EstadoInicio estado;
  final registrados = <String>[];

  Widget get app => MaterialApp(
    theme: temaGranja(),
    home: InicioPantalla(
      estado: estado,
      envios: envios,
      alRegistrar: (g) => registrados.add(g.nombre),
      nombreUsuario: 'Mamá',
      alSalir: () {},
    ),
  );
}

void main() {
  testWidgets('muestra el día de la granja, el total de huevos y las aves', (tester) async {
    final montaje = Montaje((_) => tablero);
    await tester.pumpWidget(montaje.app);
    await tester.pumpAndSettle();

    expect(find.text('Hoy en la granja'), findsOneWidget);
    expect(find.text('Miércoles 21 de octubre'), findsOneWidget);
    expect(find.text('2.130'), findsOneWidget);
    expect(find.text('5.036 aves vivas en 3 galpones'), findsOneWidget);
    expect(find.text('Todo enviado'), findsOneWidget);
  });

  testWidgets('cada galpón con lote dice si ya se registró hoy', (tester) async {
    final montaje = Montaje((_) => tablero);
    await tester.pumpWidget(montaje.app);
    await tester.pumpAndSettle();

    expect(find.text('Hy-Line · 32 semanas · 2.476 aves'), findsOneWidget);
    expect(find.text('86%'), findsOneWidget);
    expect(find.text('postura · 2.130 huevos'), findsOneWidget);
    expect(find.text('Lohmann · 45 semanas · 1.612 aves'), findsOneWidget);
    expect(find.text('Falta hoy'), findsOneWidget);
    expect(find.text('Hy-Line · 12 semanas · levante · 948 aves'), findsOneWidget);
    expect(find.text('Al día'), findsNWidgets(2));
  });

  testWidgets('los galpones vacíos se juntan en una sola línea y no piden registro', (tester) async {
    final montaje = Montaje((_) => tablero);
    await tester.pumpWidget(montaje.app);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.textContaining('Vacíos'), 200);
    expect(find.text('Vacíos: galpones 2 y 4'), findsOneWidget);
    expect(find.text('Registrar hoy'), findsOneWidget);
  });

  testWidgets('Registrar hoy abre el registro de ese galpón', (tester) async {
    final montaje = Montaje((_) => tablero);
    await tester.pumpWidget(montaje.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar hoy'));
    await tester.tap(find.text('Falta 1 galpón'));

    expect(montaje.registrados, ['Galpón 3', 'Galpón 3']);
  });

  testWidgets('cuando todo está registrado lo dice y no ofrece registrar', (tester) async {
    final montaje = Montaje((_) => [tablero.first, tablero[3]]);
    await tester.pumpWidget(montaje.app);
    await tester.pumpAndSettle();

    expect(find.text('Todo registrado'), findsOneWidget);
    expect(find.text('Registrar hoy'), findsNothing);
  });

  testWidgets('sin señal usa la copia guardada y lo avisa', (tester) async {
    final montaje = Montaje((_) => http.Response('', 503));
    await montaje.almacenResumen.guardar(
      ResumenGuardado(
        fecha: DateTime.utc(2026, 10, 21),
        actualizadoEn: ahora,
        galpones: const [
          ResumenGalpon(
            galponId: 1,
            nombre: 'Galpón 1',
            capacidadAves: 5000,
            avesVivas: 2476,
            ocupacionPct: 0,
            loteId: 7,
            huevosDelDia: 2130,
          ),
        ],
      ),
    );
    await tester.pumpWidget(montaje.app);
    await tester.pumpAndSettle();

    expect(find.text('Sin señal'), findsOneWidget);
    expect(find.text('2.130'), findsOneWidget);
  });

  testWidgets('sin señal y sin copia explica que no hay datos todavía', (tester) async {
    final montaje = Montaje((_) => http.Response('', 503));
    await tester.pumpWidget(montaje.app);
    await tester.pumpAndSettle();

    expect(find.text('No hay datos todavía'), findsOneWidget);
  });

  testWidgets('un registro sin enviar se ve arriba como pendiente', (tester) async {
    final montaje = Montaje((p) => p.method == 'PUT' ? http.Response('', 503) : tablero);
    await montaje.envios.guardar(
      RegistroDiario(id: 'a', galponId: 3, fecha: DateTime.utc(2026, 10, 21), huevosTotal: 1400),
      ahora,
    );
    await tester.pumpWidget(montaje.app);
    await tester.pumpAndSettle();

    expect(find.text('1 sin enviar'), findsOneWidget);
    expect(find.text('Todo enviado'), findsNothing);
  });

  testWidgets('un registro en conflicto se avisa como por revisar', (tester) async {
    final montaje = Montaje((p) => p.method == 'PUT' ? http.Response('{"detail":"ya hay un registro"}', 409) : tablero);
    await montaje.envios.guardar(
      RegistroDiario(id: 'a', galponId: 3, fecha: DateTime.utc(2026, 10, 21), huevosTotal: 1400),
      ahora,
    );
    await tester.pumpWidget(montaje.app);
    await tester.pumpAndSettle();

    expect(find.text('1 por revisar'), findsOneWidget);
  });

  test('los miles se separan con punto', () {
    expect(miles(0), '0');
    expect(miles(948), '948');
    expect(miles(2130), '2.130');
    expect(miles(1234567), '1.234.567');
  });
}
