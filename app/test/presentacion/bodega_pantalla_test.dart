import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/bodega.dart';
import 'package:granja_app/datos/operaciones.dart';
import 'package:granja_app/dominio/inventario.dart';
import 'package:granja_app/presentacion/bodega.dart';
import 'package:granja_app/presentacion/estado_bodega.dart';
import 'package:granja_app/presentacion/formato.dart';
import 'package:granja_app/presentacion/tema.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final base = Uri.parse('http://granja.test/');
final ahora = DateTime.utc(2026, 10, 25, 17);

Map<String, dynamic> sinOperacion(Map<String, dynamic> cuerpo) => {...cuerpo}..remove('operacion_id');

Map<String, Object?> insumo(int id, String nombre, String tipo, {String? etapa, double? porBulto}) => {
  'id': id,
  'nombre': nombre,
  'tipo': tipo,
  'etapa': etapa,
  'kg_por_bulto': porBulto,
};

Map<String, Object?> existencia(
  Map<String, Object?> insumo,
  double stock, {
  double? bultos,
  double? consumo,
  double? dias,
  String nivel = 'sin_datos',
}) => {
  'insumo': insumo,
  'stock_kg': stock,
  'bultos': bultos,
  'consumo_diario_kg': consumo,
  'dias': dias,
  'nivel': nivel,
};

Map<String, Object?> bodega(
  int id,
  String nombre,
  String tipo,
  List<Map<String, Object?>> existencias, {
  List<int> galpones = const [],
  List<Map<String, Object?>> etapas = const [],
}) => {
  'bodega': {'id': id, 'nombre': nombre, 'tipo': tipo},
  'galpon_ids': galpones,
  'existencias': existencias,
  'etapas': etapas,
};

Map<String, Object?> etapa(String nombre, double stock, double consumo, double dias, String nivel, int enUso) => {
  'etapa': nombre,
  'consumo_diario_kg': consumo,
  'stock_kg': stock,
  'dias': dias,
  'nivel': nivel,
  'en_uso_id': enUso,
};

Insumo insumoDe(int id, String nombre) => Insumo(id: id, nombre: nombre, tipo: TipoInsumo.materiaPrima, kgPorBulto: 50);

final tablero = {
  'bodegas': [
    bodega(
      1,
      'Bodega 1',
      'alimento',
      [
        existencia(
          insumo(3, 'Mezcla ponedora', 'alimento_preparado', etapa: 'produccion'),
          1200,
          consumo: 400,
          dias: 3,
          nivel: 'poco',
        ),
      ],
      galpones: [1, 3],
      etapas: [etapa('produccion', 1200, 400, 3, 'poco', 3)],
    ),
    bodega(
      2,
      'Bodega 2',
      'alimento',
      [
        existencia(
          insumo(4, 'Italcol levante', 'alimento_comprado', etapa: 'levante', porBulto: 40),
          400,
          bultos: 10,
          consumo: 40,
          dias: 10,
          nivel: 'bien',
        ),
      ],
      galpones: [5],
      etapas: [etapa('levante', 400, 40, 10, 'bien', 4)],
    ),
    bodega(3, 'Bodega de materia prima', 'materia_prima', [
      existencia(
        insumo(1, 'Maíz', 'materia_prima', porBulto: 50),
        675,
        bultos: 13.5,
        consumo: 240,
        dias: 2.8,
        nivel: 'poco',
      ),
      existencia(
        insumo(2, 'Soya', 'materia_prima', porBulto: 40),
        80,
        bultos: 2,
        consumo: 100,
        dias: 0.8,
        nivel: 'critico',
      ),
    ]),
  ],
  'mezclas': [
    {
      'producto_id': 3,
      'producto': 'Mezcla ponedora',
      'stock_kg': 1200.0,
      'kg_posibles': 320.0,
      'limitante_id': 2,
      'limitante': 'Soya',
      'dias': 3.8,
      'nivel': 'poco',
      'origen_id': 3,
      'origen': 'Bodega de materia prima',
    },
  ],
};

class Montaje {
  Montaje({http.Response Function(http.Request)? servidor, Object? inventario}) {
    final cliente = MockClient((peticion) async {
      peticiones.add('${peticion.method} ${peticion.url.path}');
      if (peticion.method != 'GET') cuerpos.add(jsonDecode(peticion.body) as Map<String, dynamic>);
      if (servidor != null) return servidor(peticion);
      return http.Response.bytes(utf8.encode(jsonEncode(inventario ?? tablero)), 200);
    });
    almacen = AlmacenBodegaEnMemoria();
    operaciones = AlmacenOperacionesEnMemoria();
    estado = EstadoBodega(
      RepositorioBodega(ApiGranja(base, cliente: cliente), almacen, operaciones),
      reloj: () => ahora,
    );
  }

  final peticiones = <String>[];
  final cuerpos = <Map<String, dynamic>>[];
  late final AlmacenBodegaEnMemoria almacen;
  late final AlmacenOperacionesEnMemoria operaciones;
  late final EstadoBodega estado;

  Widget get app => MaterialApp(
    theme: temaGranja(),
    home: BodegaPantalla(estado: estado),
  );
}

Future<void> abrir(WidgetTester tester, Montaje montaje) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(montaje.app);
  await tester.pumpAndSettle();
}

Future<void> elegir(WidgetTester tester, String nombre) async {
  await tester.tap(find.widgetWithText(ChoiceChip, nombre));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('las tres bodegas se eligen arriba y se empieza por la primera', (tester) async {
    await abrir(tester, Montaje());

    expect(find.widgetWithText(ChoiceChip, 'Bodega 1'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Bodega 2'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Bodega de materia prima'), findsOneWidget);
    expect(find.text('Alimenta 2 galpones.'), findsOneWidget);
    expect(find.text('Ponedora'), findsOneWidget);
    expect(find.text('Levante'), findsNothing);
  });

  testWidgets('cada bodega de alimento muestra sus propios días', (tester) async {
    await abrir(tester, Montaje());

    expect(find.text('3 días'), findsAtLeastNWidgets(1));
    expect(find.text('Hay 1.200 kg de alimento · se gastan 400 kg al día'), findsOneWidget);

    await elegir(tester, 'Bodega 2');

    expect(find.text('Levante'), findsOneWidget);
    expect(find.text('10 días'), findsAtLeastNWidgets(1));
    expect(find.text('Alimenta 1 galpón.'), findsOneWidget);
    expect(find.text('Hay 10 bultos (400 kg) de alimento · se gastan 1 bulto al día'), findsOneWidget);
    expect(find.text('Italcol levante'), findsOneWidget);
  });

  testWidgets('avisa qué se acaba y en qué bodega', (tester) async {
    await abrir(tester, Montaje());

    expect(find.text('Hay que comprar o preparar'), findsOneWidget);
    expect(find.text('Soya (Bodega de materia prima)'), findsOneWidget);
  });

  testWidgets('la bodega de materia prima muestra la mezcla posible y los bultos', (tester) async {
    await abrir(tester, Montaje());
    await elegir(tester, 'Bodega de materia prima');

    expect(find.textContaining('Lo primero que se acaba: Soya'), findsOneWidget);
    expect(find.textContaining('se pueden preparar 320 kg más'), findsOneWidget);
    expect(find.text('13 bultos y medio · 675 kg'), findsOneWidget);
    expect(find.text('2 bultos · 80 kg'), findsOneWidget);
    expect(find.text('2,8 días'), findsOneWidget);
  });

  testWidgets('registrar una compra de medio bulto manda la bodega y 0.5 bultos', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);
    await elegir(tester, 'Bodega de materia prima');

    await tester.tap(find.text('Maíz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Llegó (compra)'));
    await tester.pumpAndSettle();
    expect(find.text('Llegó Maíz'), findsOneWidget);
    expect(find.text('A Bodega de materia prima'), findsOneWidget);
    expect(find.text('1 bulto'), findsOneWidget);
    expect(find.text('Son 50 kg'), findsOneWidget);

    await tester.tap(find.byTooltip('Medio bulto menos'));
    await tester.pump();
    expect(find.text('medio bulto'), findsOneWidget);
    expect(find.text('Son 25 kg'), findsOneWidget);
    await tester.tap(find.byTooltip('Medio bulto más'));
    await tester.tap(find.byTooltip('Medio bulto más'));
    await tester.pump();
    expect(find.text('1 bulto y medio'), findsOneWidget);

    await tester.tap(find.text('Guardar compra'));
    await tester.pumpAndSettle();

    expect(montaje.peticiones, contains('POST /insumos/1/compras'));
    expect(sinOperacion(montaje.cuerpos.single), {'bodega_id': 3, 'bultos': 1.5, 'fecha': '2026-10-25'});
    expect(montaje.cuerpos.single['operacion_id'], isA<String>());
    expect(find.text('Compra guardada'), findsOneWidget);
    expect(montaje.peticiones.where((p) => p == 'GET /inventario').length, 2);
  });

  testWidgets('el alimento comprado también se compra, en su bodega', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);
    await elegir(tester, 'Bodega 2');

    await tester.tap(find.text('Italcol levante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Llegó (compra)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar compra'));
    await tester.pumpAndSettle();

    expect(montaje.peticiones, contains('POST /insumos/4/compras'));
    expect(sinOperacion(montaje.cuerpos.single), {'bodega_id': 2, 'bultos': 1, 'fecha': '2026-10-25'});
  });

  testWidgets('cada hoja tiene un botón para volver', (tester) async {
    await abrir(tester, Montaje());
    await elegir(tester, 'Bodega de materia prima');

    await tester.tap(find.text('Maíz'));
    await tester.pumpAndSettle();
    expect(find.text('Llegó (compra)'), findsOneWidget);
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Llegó (compra)'), findsNothing);
    expect(find.text('Materias primas'), findsOneWidget);
  });

  testWidgets('el alimento preparado no se compra', (tester) async {
    await abrir(tester, Montaje());

    await tester.tap(find.text('Mezcla ponedora'));
    await tester.pumpAndSettle();

    expect(find.text('Llegó (compra)'), findsNothing);
    expect(find.text('Gasté'), findsOneWidget);
    expect(find.text('Conté lo que hay'), findsOneWidget);
  });

  testWidgets('no se puede bajar de medio bulto', (tester) async {
    await abrir(tester, Montaje());
    await elegir(tester, 'Bodega de materia prima');
    await tester.tap(find.text('Maíz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Llegó (compra)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Medio bulto menos'));
    await tester.pump();

    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove)).onPressed, isNull);
  });

  testWidgets('el gasto se da en bultos y manda los bultos con su identificador', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);
    await elegir(tester, 'Bodega 2');

    await tester.tap(find.text('Italcol levante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gasté'));
    await tester.pumpAndSettle();
    expect(find.text('Gasté Italcol levante'), findsOneWidget);
    expect(find.text('De Bodega 2. Hay 10 bultos.'), findsOneWidget);
    await tester.tap(find.byTooltip('Medio bulto más'));
    await tester.tap(find.byTooltip('Medio bulto más'));
    await tester.pump();
    expect(find.text('2 bultos'), findsOneWidget);
    expect(find.text('Son 80 kg'), findsOneWidget);

    await tester.tap(find.text('Guardar lo gastado'));
    await tester.pumpAndSettle();

    expect(montaje.peticiones, contains('POST /insumos/4/gastos'));
    expect(sinOperacion(montaje.cuerpos.single), {
      'bodega_id': 2,
      'bultos': 2,
      'nota': '2 bultos de Italcol levante',
      'fecha': '2026-10-25',
    });
    expect(montaje.cuerpos.single['operacion_id'], isA<String>());
    expect(find.text('Gasto guardado'), findsOneWidget);
  });

  testWidgets('sin señal el gasto queda guardado y se envía después', (tester) async {
    var hayRed = true;
    final montaje = Montaje(
      servidor: (p) {
        if (!hayRed) throw http.ClientException('sin red');
        return p.method == 'GET'
            ? http.Response.bytes(utf8.encode(jsonEncode(tablero)), 200)
            : http.Response('{}', 201);
      },
    );
    await abrir(tester, montaje);
    await elegir(tester, 'Bodega 2');
    await tester.tap(find.text('Italcol levante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gasté'));
    await tester.pumpAndSettle();
    hayRed = false;
    await tester.tap(find.text('Guardar lo gastado'));
    await tester.pumpAndSettle();

    expect(find.text('Gasto guardado. Se envía cuando haya señal'), findsOneWidget);
    expect(find.text('1 cosa sin enviar'), findsOneWidget);
    expect((await montaje.operaciones.sinResolver()).single.descripcion, '1 bulto de Italcol levante');

    hayRed = true;
    await montaje.estado.cargar();
    await tester.pumpAndSettle();
    expect(find.text('1 cosa sin enviar'), findsNothing);
    expect(montaje.peticiones, contains('POST /insumos/4/gastos'));
  });

  testWidgets('lo que no tiene bulto se gasta en kilos', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await tester.tap(find.text('Mezcla ponedora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gasté'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.pump();
    await tester.tap(find.text('Guardar lo gastado'));
    await tester.pumpAndSettle();

    expect(sinOperacion(montaje.cuerpos.single), {
      'bodega_id': 1,
      'kg': 100,
      'nota': '100 kg de Mezcla ponedora',
      'fecha': '2026-10-25',
    });
  });

  testWidgets('contar deja el número de bultos que se contó', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);
    await elegir(tester, 'Bodega 2');

    await tester.tap(find.text('Italcol levante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conté lo que hay'));
    await tester.pumpAndSettle();
    expect(find.text('En Bodega 2. La app dice que hay 10 bultos.'), findsOneWidget);
    expect(find.text('10 bultos'), findsOneWidget);
    await tester.tap(find.byTooltip('Medio bulto menos'));
    await tester.pump();
    expect(find.text('9 bultos y medio'), findsOneWidget);

    await tester.tap(find.text('Dejar este conteo'));
    await tester.pumpAndSettle();

    expect(montaje.peticiones, contains('POST /insumos/4/ajuste'));
    expect(montaje.cuerpos.single, {'bodega_id': 2, 'bultos_reales': 9.5, 'nota': 'Conteo en la bodega'});
    expect(find.text('Conteo guardado'), findsOneWidget);
    expect(montaje.peticiones.where((p) => p == 'GET /inventario').length, 2);
  });

  testWidgets('contar sin señal avisa que necesita internet y no cierra', (tester) async {
    var hayRed = true;
    final montaje = Montaje(
      servidor: (p) {
        if (p.method == 'GET' && hayRed) return http.Response.bytes(utf8.encode(jsonEncode(tablero)), 200);
        throw http.ClientException('sin red');
      },
    );
    await abrir(tester, montaje);
    await elegir(tester, 'Bodega 2');
    await tester.tap(find.text('Italcol levante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conté lo que hay'));
    await tester.pumpAndSettle();
    hayRed = false;
    await tester.tap(find.text('Dejar este conteo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('contar necesita internet'), findsOneWidget);
    expect(find.text('Dejar este conteo'), findsOneWidget);
  });

  testWidgets('preparar manda los kilos, de dónde sale y a qué bodega va', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);
    await elegir(tester, 'Bodega de materia prima');

    await tester.tap(find.text('Preparé alimento'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '500');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bodega 2').last);
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(montaje.peticiones, contains('POST /alimentos/3/preparaciones'));
    expect(sinOperacion(montaje.cuerpos.single), {
      'desde_bodega_id': 3,
      'hacia_bodega_id': 2,
      'kg': 500,
      'fecha': '2026-10-25',
    });
    expect(find.text('Preparación guardada'), findsOneWidget);
  });

  testWidgets('si el servidor rechaza la preparación queda a la vista con su motivo y se puede descartar', (
    tester,
  ) async {
    final montaje = Montaje(
      servidor: (p) => p.method == 'POST'
          ? http.Response.bytes(
              utf8.encode('{"detail":"no alcanza la materia prima, falta: Soya (20 kg)"}'),
              422,
              headers: {'content-type': 'application/json'},
            )
          : http.Response.bytes(utf8.encode(jsonEncode(tablero)), 200),
    );
    await abrir(tester, montaje);
    await elegir(tester, 'Bodega de materia prima');

    await tester.tap(find.text('Preparé alimento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '900');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('1 no se pudo registrar'), findsOneWidget);
    await tester.tap(find.text('1 no se pudo registrar'));
    await tester.pumpAndSettle();
    expect(find.text('Preparación: 900 kg de Mezcla ponedora'), findsOneWidget);
    expect(find.text('no alcanza la materia prima, falta: Soya (20 kg)'), findsOneWidget);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Preparación: 900 kg de Mezcla ponedora'), findsNothing);
    expect(await montaje.operaciones.sinResolver(), isEmpty);
  });

  testWidgets('sin señal la compra se guarda y se envía cuando vuelve la señal', (tester) async {
    var hayRed = true;
    final montaje = Montaje(
      servidor: (p) {
        if (p.method == 'GET' && hayRed) return http.Response.bytes(utf8.encode(jsonEncode(tablero)), 200);
        if (hayRed) return http.Response('{}', 201);
        throw http.ClientException('sin red');
      },
    );
    await abrir(tester, montaje);
    await elegir(tester, 'Bodega de materia prima');
    await tester.tap(find.text('Maíz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Llegó (compra)'));
    await tester.pumpAndSettle();
    hayRed = false;

    await tester.tap(find.text('Guardar compra'));
    await tester.pumpAndSettle();

    expect(find.text('Llegó Maíz'), findsNothing);
    expect(find.text('Compra guardada. Se envía cuando haya señal'), findsOneWidget);
    expect(find.text('1 cosa sin enviar'), findsOneWidget);
    expect(find.text('Se envían solas cuando haya señal'), findsOneWidget);
    final guardada = (await montaje.operaciones.sinResolver()).single;
    expect(guardada.descripcion, '1 bulto de Maíz');

    hayRed = true;
    await montaje.estado.cargar();
    await tester.pumpAndSettle();

    expect(find.text('1 cosa sin enviar'), findsNothing);
    expect(montaje.peticiones, contains('POST /insumos/1/compras'));
    expect(montaje.cuerpos.map((c) => c['operacion_id']).toSet(), {guardada.id});
    expect(await montaje.operaciones.sinResolver(), isEmpty);
  });

  testWidgets('lo sin enviar se manda en el orden en que se guardó y se detiene si falta la señal', (tester) async {
    var hayRed = false;
    final montaje = Montaje(
      servidor: (p) {
        if (!hayRed) throw http.ClientException('sin red');
        return p.method == 'GET'
            ? http.Response.bytes(utf8.encode(jsonEncode(tablero)), 200)
            : http.Response('{}', 201);
      },
    );
    await montaje.almacen.guardar(BodegaGuardada(actualizadoEn: ahora, datos: jsonEncode(tablero)));
    await abrir(tester, montaje);
    final maiz = insumoDe(1, 'Maíz');
    await montaje.estado.registrarCompra(maiz, 3, 2);
    await montaje.estado.registrarCompra(maiz, 3, 1);
    expect(montaje.estado.porEnviar, 2);

    hayRed = true;
    await montaje.estado.cargar();

    expect(montaje.estado.porEnviar, 0);
    expect([for (final c in montaje.cuerpos) c['bultos']].reversed.take(2).toList().reversed, [2, 1]);
  });

  testWidgets('sin señal usa la última copia y lo avisa', (tester) async {
    final montaje = Montaje(servidor: (_) => http.Response('', 503));
    await montaje.almacen.guardar(BodegaGuardada(actualizadoEn: ahora, datos: jsonEncode(tablero)));

    await abrir(tester, montaje);

    expect(find.text('Sin señal'), findsOneWidget);
    expect(find.text('Ponedora'), findsOneWidget);
  });

  testWidgets('sin señal y sin copia explica que no hay datos todavía', (tester) async {
    await abrir(tester, Montaje(servidor: (_) => http.Response('', 503)));

    expect(find.text('No hay datos todavía'), findsOneWidget);
  });

  testWidgets('sin bodegas pide que el administrador las cree', (tester) async {
    await abrir(tester, Montaje(inventario: {'bodegas': <Object?>[], 'mezclas': <Object?>[]}));

    expect(find.text('No hay bodegas todavía'), findsOneWidget);
  });

  testWidgets('una bodega sin galpones lo dice', (tester) async {
    final sinGalpones = {
      'bodegas': [bodega(1, 'Bodega 1', 'alimento', [])],
      'mezclas': <Object?>[],
    };
    await abrir(tester, Montaje(inventario: sinGalpones));

    expect(find.text('Todavía no tiene galpones asignados.'), findsOneWidget);
    expect(find.text('Todavía no hay alimento en esta bodega.'), findsOneWidget);
  });

  testWidgets('con la sesión vencida el estado lo marca', (tester) async {
    final montaje = Montaje(servidor: (_) => http.Response('', 401));

    await montaje.estado.cargar();

    expect(montaje.estado.sesionVencida, isTrue);
  });

  test('bultos, kilos y días se escriben como se hablan', () {
    expect(bultosTexto(0.5), 'medio bulto');
    expect(bultosTexto(1), '1 bulto');
    expect(bultosTexto(1.5), '1 bulto y medio');
    expect(bultosTexto(3), '3 bultos');
    expect(bultosTexto(3.25), '3,3 bultos');
    expect(diasTexto(null), 'sin datos');
    expect(diasTexto(0.4), 'menos de 1 día');
    expect(diasTexto(1), '1 día');
    expect(diasTexto(2.7), '2,7 días');
    expect(diasTexto(10), '10 días');
    expect(kilos(1234.4), '1.234 kg');
  });
}
