import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/finanzas.dart';
import 'package:granja_app/datos/operaciones.dart';
import 'package:granja_app/presentacion/dinero.dart';
import 'package:granja_app/presentacion/estado_finanzas.dart';
import 'package:granja_app/presentacion/tema.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final base = Uri.parse('http://granja.test/');
final ahora = DateTime.utc(2026, 10, 25, 17);

final categorias = [
  {'id': 1, 'nombre': 'AA', 'activa': true},
  {'id': 2, 'nombre': 'A', 'activa': true},
  {'id': 3, 'nombre': 'Roto', 'activa': false},
];

Map<String, Object?> movimiento(
  String id,
  String fecha,
  String rubro,
  num valor, {
  String descripcion = '',
  int? lote,
  int? categoria,
  int? huevos,
  String contraparte = '',
}) => {
  'id': id,
  'fecha': fecha,
  'rubro': rubro,
  'valor': valor,
  'descripcion': descripcion,
  'lote_id': lote,
  'categoria_id': categoria,
  'cantidad_huevos': huevos,
  'contraparte': contraparte,
  'tipo': rubro.startsWith('venta') ? 'ingreso' : 'egreso',
};

final resumen = {
  'desde': '2026-10-01',
  'hasta': '2026-10-31',
  'ingresos': 5000000,
  'egresos': 3000000,
  'utilidad': 2000000,
  'por_rubro': [
    {'rubro': 'venta_huevo', 'total': 5000000},
    {'rubro': 'alimento', 'total': 3000000},
  ],
  'huevos': [
    {'categoria_id': 1, 'categoria': 'AA', 'huevos': 12000, 'valor': 3600000, 'precio_por_huevo': 300.0},
    {'categoria_id': 2, 'categoria': 'A', 'huevos': 7000, 'valor': 1400000, 'precio_por_huevo': 200.0},
  ],
  'por_lote': [
    {'lote_id': 1, 'galpon': 'Galpón 1', 'ingresos': 4000000, 'egresos': 1000000, 'utilidad': 3000000},
    {'lote_id': null, 'galpon': 'Sin asignar', 'ingresos': 1000000, 'egresos': 2000000, 'utilidad': -1000000},
  ],
};

final movimientos = [
  movimiento('m1', '2026-10-20', 'venta_huevo', 3600000, categoria: 1, huevos: 12000, contraparte: 'La Esperanza'),
  movimiento('m2', '2026-10-12', 'alimento', 3000000, descripcion: 'Camión de ponedora', lote: 1),
];

final galpones = [
  {
    'galpon_id': 1,
    'nombre': 'Galpón 1',
    'capacidad_aves': 6000,
    'aves_vivas': 2480,
    'ocupacion_pct': 41.3,
    'lote_id': 1,
    'etapa': 'produccion',
    'edad_semanas': 32,
    'postura_pct': null,
    'linea': 'Hy-Line Brown',
    'huevos_del_dia': null,
  },
  {
    'galpon_id': 2,
    'nombre': 'Galpón 2',
    'capacidad_aves': 2000,
    'aves_vivas': 0,
    'ocupacion_pct': 0,
    'lote_id': null,
    'etapa': null,
    'edad_semanas': null,
    'postura_pct': null,
    'linea': null,
    'huevos_del_dia': null,
  },
];

class Montaje {
  Montaje({http.Response Function(http.Request)? servidor, List<Object?>? categoriasDelServidor}) {
    final cliente = MockClient((peticion) async {
      final ruta = peticion.url.path;
      peticiones.add('${peticion.method} $ruta');
      if (peticion.body.isNotEmpty) cuerpos.add(jsonDecode(peticion.body) as Map<String, dynamic>);
      if (servidor != null) return servidor(peticion);
      if (peticion.method != 'GET') return http.Response('{}', peticion.method == 'DELETE' ? 204 : 200);
      final cuerpo = switch (ruta) {
        '/finanzas/resumen' => resumen,
        '/finanzas' => movimientos,
        '/categorias-huevo' => categoriasDelServidor ?? categorias,
        '/galpones/resumen' => galpones,
        _ => {'detail': 'no existe'},
      };
      return http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), 200);
    });
    almacen = AlmacenFinanzasEnMemoria();
    operaciones = AlmacenOperacionesEnMemoria();
    estado = EstadoFinanzas(
      RepositorioFinanzas(ApiGranja(base, cliente: cliente), almacen, operaciones),
      reloj: () => ahora,
    );
  }

  final peticiones = <String>[];
  final cuerpos = <Map<String, dynamic>>[];
  late final AlmacenFinanzasEnMemoria almacen;
  late final AlmacenOperacionesEnMemoria operaciones;
  late final EstadoFinanzas estado;

  Widget app({bool admin = true}) => MaterialApp(
    theme: temaGranja(),
    home: DineroPantalla(estado: estado, esAdministrador: admin),
  );
}

Future<void> abrir(WidgetTester tester, Montaje montaje, {bool admin = true}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(montaje.app(admin: admin));
  await tester.pumpAndSettle();
}

Future<void> pulsar(WidgetTester tester, Finder buscador) async {
  await tester.tap(buscador);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra la ganancia del mes con lo que entró y lo que salió', (tester) async {
    await abrir(tester, Montaje());

    expect(find.text('octubre 2026'), findsOneWidget);
    expect(find.text('Ganancia del mes'), findsOneWidget);
    expect(find.text('\$ 2.000.000'), findsOneWidget);
    expect(find.text('\$ 5.000.000'), findsOneWidget);
    expect(find.text('\$ 3.000.000'), findsAtLeastNWidgets(1));
  });

  testWidgets('si hay pérdida lo dice con todas sus letras', (tester) async {
    final perdida = {...resumen, 'ingresos': 1000000, 'egresos': 1500000, 'utilidad': -500000};
    final montaje = Montaje(
      servidor: (p) => http.Response.bytes(
        utf8.encode(
          jsonEncode(switch (p.url.path) {
            '/finanzas/resumen' => perdida,
            '/finanzas' => <Object?>[],
            '/categorias-huevo' => categorias,
            _ => galpones,
          }),
        ),
        200,
      ),
    );
    await abrir(tester, montaje);

    expect(find.text('Pérdida del mes'), findsOneWidget);
    expect(find.text('\$ 500.000'), findsOneWidget);
    expect(find.text('Todavía no hay movimientos este mes.'), findsOneWidget);
  });

  testWidgets('detalla los huevos por categoría con el precio de cada huevo', (tester) async {
    await abrir(tester, Montaje());

    expect(find.text('Huevos vendidos'), findsOneWidget);
    expect(find.text('12.000 huevos · \$ 300 c/u'), findsOneWidget);
    expect(find.text('7.000 huevos · \$ 200 c/u'), findsOneWidget);
  });

  testWidgets('la ganancia por galpón muestra también lo que no está asignado', (tester) async {
    await abrir(tester, Montaje());

    expect(find.text('Ganancia por galpón'), findsOneWidget);
    expect(find.text('Entró \$ 4.000.000 · salió \$ 1.000.000'), findsOneWidget);
    expect(find.text('Sin asignar'), findsOneWidget);
    expect(find.text('\$ -1.000.000'), findsOneWidget);
  });

  testWidgets('lista los movimientos con su signo y su cliente', (tester) async {
    await abrir(tester, Montaje());

    expect(find.text('12.000 huevos AA'), findsOneWidget);
    expect(find.text('+ \$ 3.600.000'), findsOneWidget);
    expect(find.textContaining('La Esperanza'), findsOneWidget);
    expect(find.text('Camión de ponedora'), findsOneWidget);
    expect(find.text('- \$ 3.000.000'), findsOneWidget);
  });

  testWidgets('vender huevos en cubetas manda los huevos, el total y la categoría', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Vendí huevos'));
    expect(find.widgetWithText(ChoiceChip, 'Roto'), findsNothing);
    await pulsar(tester, find.widgetWithText(ChoiceChip, 'A'));
    await tester.enterText(find.widgetWithText(TextField, '¿Cuántas cubetas?'), '10');
    await tester.enterText(find.widgetWithText(TextField, 'Total cobrado'), '60000');
    await tester.enterText(find.widgetWithText(TextField, 'Cliente (opcional)'), 'Doña Rosa');
    await tester.pump();
    expect(find.text('Son 300 huevos'), findsOneWidget);
    expect(find.text('\$ 60.000 · \$ 200 cada huevo'), findsOneWidget);
    await pulsar(tester, find.text('Guardar venta'));

    expect(montaje.peticiones.where((p) => p.startsWith('PUT /finanzas/')), hasLength(1));
    expect(montaje.cuerpos.single, {
      'fecha': '2026-10-25',
      'rubro': 'venta_huevo',
      'valor': 60000,
      'descripcion': '',
      'lote_id': null,
      'categoria_id': 2,
      'cantidad_huevos': 300,
      'contraparte': 'Doña Rosa',
    });
    expect(find.text('Venta guardada'), findsOneWidget);
  });

  testWidgets('también se puede vender por huevos sueltos', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Vendí huevos'));
    await pulsar(tester, find.widgetWithText(ChoiceChip, 'Huevos'));
    await tester.enterText(find.widgetWithText(TextField, '¿Cuántos huevos?'), '45');
    await tester.enterText(find.widgetWithText(TextField, 'Total cobrado'), '13500');
    await tester.pump();
    await pulsar(tester, find.text('Guardar venta'));

    expect(montaje.cuerpos.single['cantidad_huevos'], 45);
    expect(montaje.cuerpos.single['categoria_id'], 1);
  });

  testWidgets('no deja guardar una venta sin cantidad o sin total', (tester) async {
    await abrir(tester, Montaje());
    await pulsar(tester, find.text('Vendí huevos'));

    FilledButton boton() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar venta'));
    expect(boton().onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, '¿Cuántas cubetas?'), '10');
    await tester.pump();
    expect(boton().onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Total cobrado'), '60000');
    await tester.pump();
    expect(boton().onPressed, isNotNull);
  });

  testWidgets('sin categorías de huevo no se puede vender y dice qué hacer', (tester) async {
    await abrir(tester, Montaje(categoriasDelServidor: []));

    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Vendí huevos')).onPressed, isNull);
    expect(find.textContaining('crear las categorías en Administrar'), findsOneWidget);
  });

  testWidgets('vender gallinas guarda la cantidad en el detalle y el galpón de donde salieron', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Vendí gallinas'));
    await tester.enterText(find.widgetWithText(TextField, '¿Cuántas gallinas?'), '200');
    await tester.enterText(find.widgetWithText(TextField, 'Total cobrado'), '1600000');
    await tester.pump();
    await pulsar(tester, find.widgetWithText(ChoiceChip, 'Galpón 1'));
    expect(find.widgetWithText(ChoiceChip, 'Galpón 2'), findsNothing);
    await pulsar(tester, find.text('Guardar venta'));

    expect(montaje.cuerpos.single['rubro'], 'venta_gallinas');
    expect(montaje.cuerpos.single['descripcion'], '200 gallinas');
    expect(montaje.cuerpos.single['lote_id'], 1);
    expect(montaje.cuerpos.single['valor'], 1600000);
  });

  testWidgets('un gasto elige el rubro y puede ser de un galpón', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Gasté'));
    expect(find.widgetWithText(ChoiceChip, 'Venta de huevo'), findsNothing);
    await pulsar(tester, find.widgetWithText(ChoiceChip, 'Vacunas y medicinas'));
    await tester.enterText(find.widgetWithText(TextField, '¿Cuánto fue?'), '215000');
    await tester.enterText(find.widgetWithText(TextField, 'Detalle (opcional)'), 'Newcastle');
    await tester.pump();
    await pulsar(tester, find.widgetWithText(ChoiceChip, 'Galpón 1'));
    await pulsar(tester, find.text('Guardar gasto'));

    expect(montaje.cuerpos.single['rubro'], 'vacunas_medicinas');
    expect(montaje.cuerpos.single['descripcion'], 'Newcastle');
    expect(montaje.cuerpos.single['valor'], 215000);
    expect(montaje.cuerpos.single['lote_id'], 1);
    expect(find.text('Gasto guardado'), findsOneWidget);
  });

  testWidgets('sin señal una venta queda guardada y se envía sola cuando vuelve', (tester) async {
    var hayRed = true;
    final montaje = Montaje(
      servidor: (p) {
        if (!hayRed) throw http.ClientException('sin red');
        final cuerpo = switch (p.url.path) {
          '/finanzas/resumen' => resumen,
          '/finanzas' => movimientos,
          '/categorias-huevo' => categorias,
          '/galpones/resumen' => galpones,
          _ => <String, Object?>{},
        };
        return http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), 200);
      },
    );
    await abrir(tester, montaje);
    hayRed = false;

    await pulsar(tester, find.text('Vendí huevos'));
    await tester.enterText(find.widgetWithText(TextField, '¿Cuántas cubetas?'), '2');
    await tester.enterText(find.widgetWithText(TextField, 'Total cobrado'), '18000');
    await tester.pump();
    await pulsar(tester, find.text('Guardar venta'));

    expect(find.text('Venta guardada. Se envía cuando haya señal'), findsOneWidget);
    expect(find.text('1 cosa sin enviar'), findsOneWidget);
    final guardada = (await montaje.operaciones.sinResolver()).single;
    expect(
      (guardada.tipo, guardada.rubro, guardada.valor, guardada.huevos),
      (TipoOperacion.dinero, 'venta_huevo', 18000, 60),
    );

    hayRed = true;
    await montaje.estado.cargar();
    await tester.pumpAndSettle();
    expect(montaje.peticiones, contains('PUT /finanzas/${guardada.id}'));
    expect(await montaje.operaciones.sinResolver(), isEmpty);
  });

  testWidgets('el administrador borra un movimiento tras confirmar', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Camión de ponedora'));
    expect(find.text('- \$ 3.000.000'), findsAtLeastNWidgets(1));
    await pulsar(tester, find.text('Borrar'));
    expect(find.text('¿Borrar este movimiento?'), findsOneWidget);
    await pulsar(tester, find.text('Sí, borrar'));

    expect(montaje.peticiones, contains('DELETE /finanzas/m2'));
    expect(find.text('Movimiento borrado'), findsOneWidget);
  });

  testWidgets('quien registra puede ver el movimiento pero no borrarlo', (tester) async {
    await abrir(tester, Montaje(), admin: false);

    await pulsar(tester, find.text('Camión de ponedora'));
    expect(find.text('Borrar'), findsNothing);
    expect(find.text('Detalle'), findsOneWidget);
  });

  testWidgets('los botones de mes cambian el periodo y no pasan del mes actual', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);
    await pulsar(tester, find.byTooltip('Mes anterior'));

    expect(find.text('septiembre 2026'), findsOneWidget);
    expect(montaje.peticiones.where((p) => p == 'GET /finanzas/resumen'), hasLength(2));
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNotNull);
  });

  testWidgets('sin señal usa la última copia y lo avisa', (tester) async {
    final montaje = Montaje(servidor: (_) => throw http.ClientException('sin red'));
    await montaje.almacen.guardar(
      FinanzasGuardadas(
        actualizadoEn: ahora,
        datos: jsonEncode({
          'mes': '2026-10-01',
          'resumen': resumen,
          'movimientos': movimientos,
          'categorias': categorias,
          'lotes': [
            {'id': 1, 'galpon': 'Galpón 1'},
          ],
        }),
      ),
    );
    await abrir(tester, montaje);

    expect(find.text('Sin señal'), findsOneWidget);
    expect(find.text('Ganancia del mes'), findsOneWidget);
  });

  testWidgets('sin señal y sin copia explica que no hay datos todavía', (tester) async {
    await abrir(tester, Montaje(servidor: (_) => throw http.ClientException('sin red')));

    expect(find.text('No hay datos todavía'), findsOneWidget);
  });

  testWidgets('con la sesión vencida el estado lo marca', (tester) async {
    final montaje = Montaje(servidor: (_) => http.Response('{}', 401));
    await abrir(tester, montaje);

    expect(montaje.estado.sesionVencida, isTrue);
  });
}
