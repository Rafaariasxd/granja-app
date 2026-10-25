import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/bodega.dart';
import 'package:granja_app/presentacion/bodega.dart';
import 'package:granja_app/presentacion/estado_bodega.dart';
import 'package:granja_app/presentacion/formato.dart';
import 'package:granja_app/presentacion/tema.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final base = Uri.parse('http://granja.test/');
final ahora = DateTime.utc(2026, 10, 25, 17);

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

final tablero = {
  'existencias': [
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
    existencia(
      insumo(3, 'Mezcla ponedora', 'alimento_preparado', etapa: 'produccion'),
      1200,
      consumo: 400,
      dias: 3,
      nivel: 'poco',
    ),
    existencia(insumo(4, 'Italcol levante', 'alimento_comprado', etapa: 'levante', porBulto: 40), 400, bultos: 10),
  ],
  'etapas': [
    {
      'etapa': 'produccion',
      'consumo_diario_kg': 400.0,
      'stock_kg': 1200.0,
      'dias': 3.0,
      'nivel': 'poco',
      'en_uso_id': 3,
    },
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
    estado = EstadoBodega(RepositorioBodega(ApiGranja(base, cliente: cliente), almacen), reloj: () => ahora);
  }

  final peticiones = <String>[];
  final cuerpos = <Map<String, dynamic>>[];
  late final AlmacenBodegaEnMemoria almacen;
  late final EstadoBodega estado;

  Widget get app => MaterialApp(
    theme: temaGranja(),
    home: BodegaPantalla(estado: estado),
  );
}

Future<void> abrir(WidgetTester tester, Montaje montaje) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(montaje.app);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra los días que alcanza el alimento de cada etapa', (tester) async {
    await abrir(tester, Montaje());

    expect(find.text('Ponedora'), findsOneWidget);
    expect(find.text('3 días'), findsAtLeastNWidgets(1));
    expect(find.text('Hay 1.200 kg de alimento · se gastan 400 kg al día'), findsOneWidget);
  });

  testWidgets('avisa qué se acaba y qué materia prima limita la mezcla', (tester) async {
    await abrir(tester, Montaje());

    expect(find.text('Hay que comprar o preparar'), findsOneWidget);
    expect(find.text('Soya'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Lo primero que se acaba: Soya'), findsOneWidget);
    expect(find.textContaining('se pueden preparar 320 kg más'), findsOneWidget);
  });

  testWidgets('las materias primas dicen los bultos, incluido el medio', (tester) async {
    await abrir(tester, Montaje());
    await tester.scrollUntilVisible(find.text('Maíz'), 200);

    expect(find.text('13 bultos y medio · 675 kg'), findsOneWidget);
    expect(find.text('2 bultos · 80 kg'), findsOneWidget);
    expect(find.text('2,8 días'), findsOneWidget);
  });

  testWidgets('registrar una compra de medio bulto manda 0.5 bultos', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);
    await tester.scrollUntilVisible(find.text('Maíz'), 200);

    await tester.tap(find.text('Maíz'));
    await tester.pumpAndSettle();
    expect(find.text('Llegó Maíz'), findsOneWidget);
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
    expect(montaje.cuerpos.single, {'bultos': 1.5});
    expect(find.text('Compra guardada'), findsOneWidget);
    expect(montaje.peticiones.where((p) => p == 'GET /inventario').length, 2);
  });

  testWidgets('no se puede bajar de medio bulto', (tester) async {
    await abrir(tester, Montaje());
    await tester.scrollUntilVisible(find.text('Maíz'), 200);
    await tester.tap(find.text('Maíz'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Medio bulto menos'));
    await tester.pump();

    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove)).onPressed, isNull);
  });

  testWidgets('preparar alimento manda los kilos', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await tester.tap(find.text('Preparé alimento'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '500');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(montaje.peticiones, contains('POST /alimentos/3/preparaciones'));
    expect(montaje.cuerpos.single, {'kg': 500});
    expect(find.text('Preparación guardada'), findsOneWidget);
  });

  testWidgets('si falta materia prima muestra lo que dice el servidor y no cierra', (tester) async {
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

    await tester.tap(find.text('Preparé alimento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '900');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('no alcanza la materia prima, falta: Soya (20 kg)'), findsOneWidget);
    expect(find.text('Preparé Mezcla ponedora'), findsOneWidget);
  });

  testWidgets('sin señal una compra explica que hace falta internet', (tester) async {
    var llamadas = 0;
    final montaje = Montaje(
      servidor: (p) {
        if (p.method == 'GET' && llamadas++ == 0) return http.Response.bytes(utf8.encode(jsonEncode(tablero)), 200);
        throw http.ClientException('sin red');
      },
    );
    await abrir(tester, montaje);
    await tester.scrollUntilVisible(find.text('Maíz'), 200);
    await tester.tap(find.text('Maíz'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar compra'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No hay señal'), findsOneWidget);
    expect(find.text('Llegó Maíz'), findsOneWidget);
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

  testWidgets('una bodega sin insumos pide que el administrador los cree', (tester) async {
    await abrir(tester, Montaje(inventario: {'existencias': [], 'etapas': [], 'mezclas': []}));

    expect(find.text('La bodega está vacía'), findsOneWidget);
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
