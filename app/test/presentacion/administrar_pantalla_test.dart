import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/administracion.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/presentacion/administrar.dart';
import 'package:granja_app/presentacion/cascaron.dart';
import 'package:granja_app/presentacion/estado_administracion.dart';
import 'package:granja_app/presentacion/tema.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'bodega_pantalla_test.dart' show insumo, tablero;

final servidorBase = Uri.parse('http://granja.test/');

final insumos = [
  insumo(1, 'Maíz', 'materia_prima', porBulto: 50),
  insumo(2, 'Soya', 'materia_prima', porBulto: 40),
  insumo(3, 'Mezcla ponedora', 'alimento_preparado', etapa: 'produccion'),
  insumo(4, 'Italcol levante', 'alimento_comprado', etapa: 'levante', porBulto: 40),
  insumo(6, 'Italcol ponedora', 'alimento_comprado', etapa: 'produccion', porBulto: 40),
];

final galpones = [
  for (final (id, nombre) in [(1, 'Galpón 1'), (2, 'Galpón 2'), (3, 'Galpón 3'), (5, 'Galpón 5')])
    {'id': id, 'nombre': nombre, 'capacidad_aves': 6000, 'activo': true},
];

http.Response _json(Object cuerpo, [int codigo = 200]) => http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), codigo);

class Montaje {
  Montaje({this.respuestaAlGuardar}) {
    final cliente = MockClient((peticion) async {
      final ruta = peticion.url.path;
      if (peticion.method != 'GET') {
        envios.add('${peticion.method} $ruta');
        cuerpos.add(jsonDecode(peticion.body));
        return respuestaAlGuardar?.call(peticion) ?? _json({});
      }
      return switch (ruta) {
        '/inventario' => _json(tablero),
        '/insumos' => _json(insumos),
        '/galpones' => _json(galpones),
        '/lineas' => _json([
          {'id': 1, 'nombre': 'Hy-Line Brown', 'revisada': false},
          {'id': 2, 'nombre': 'Lohmann Brown', 'revisada': true},
        ]),
        '/lineas/plantillas' => _json(['Hy-Line Brown', 'Lohmann Brown']),
        '/huevos' => _json({
          'existencias': <Object?>[],
          'precios': [
            {'categoria_id': 1, 'precio_caja': 120000.0, 'precio_carton': 12000.0, 'precio_mayorista': null},
          ],
          'abiertas': <Object?>[],
        }),
        '/categorias-huevo' => _json([
          {'id': 1, 'nombre': 'AA', 'activa': true, 'orden': 1},
          {'id': 2, 'nombre': 'Roto', 'activa': false, 'orden': 2},
          {'id': 3, 'nombre': 'Jumbo', 'activa': true, 'orden': 3},
        ]),
        '/lineas/1/plan' => _json([
          {
            'id': 10,
            'nombre': 'Marek',
            'tipo': 'vacuna',
            'semana_ideal': 0,
            'semana_max': 0,
            'nota': 'En la incubadora',
          },
          {'id': 11, 'nombre': 'Gumboro', 'tipo': 'vacuna', 'semana_ideal': 2, 'semana_max': 3, 'nota': ''},
        ]),
        '/lineas/1/curva' => _json([
          {'semana': 18, 'postura_pct': 6.0, 'peso_g': 1470.0},
          {'semana': 30, 'postura_pct': 95.0, 'peso_g': null},
        ]),
        '/alimentos/3/formula' => _json([
          {'insumo_id': 1, 'porcentaje': 55.0},
          {'insumo_id': 2, 'porcentaje': 45.0},
        ]),
        _ => _json({'detail': 'no existe'}, 404),
      };
    });
    estado = EstadoAdministracion(RepositorioAdministracion(ApiGranja(servidorBase, cliente: cliente)));
  }

  final http.Response Function(http.Request)? respuestaAlGuardar;
  final envios = <String>[];
  final cuerpos = <Object?>[];
  late final EstadoAdministracion estado;

  Widget get app => MaterialApp(
    theme: temaGranja(),
    home: AdministrarPantalla(estado: estado),
  );
}

Future<void> abrir(WidgetTester tester, Montaje montaje) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(montaje.app);
  await tester.pumpAndSettle();
}

Future<void> abrirAlto(WidgetTester tester, Montaje montaje) async {
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(montaje.app);
  await tester.pumpAndSettle();
}

Future<void> pulsar(WidgetTester tester, Finder buscador) async {
  await tester.tap(buscador);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra las bodegas con sus galpones y los insumos', (tester) async {
    await abrir(tester, Montaje());

    expect(find.text('Administrar'), findsOneWidget);
    expect(find.text('Bodega 1'), findsOneWidget);
    expect(find.text('Galpón 1, Galpón 3'), findsOneWidget);
    expect(find.text('Galpón 5'), findsOneWidget);
    expect(find.text('Bodega de materia prima'), findsOneWidget);
    expect(find.text('Maíz'), findsOneWidget);
    expect(find.text('Materia prima · bulto de 50 kg'), findsOneWidget);
    expect(find.text('Alimento que preparamos · Ponedora'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Fórmula'), findsOneWidget);
  });

  testWidgets('crea una bodega con su tipo', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Nueva bodega'));
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Crear bodega')).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Bodega de preparados');
    await tester.pump();
    await pulsar(tester, find.widgetWithText(ChoiceChip, 'Materia prima'));
    await pulsar(tester, find.widgetWithText(FilledButton, 'Crear bodega'));

    expect(montaje.envios, ['POST /bodegas']);
    expect(montaje.cuerpos.single, {'nombre': 'Bodega de preparados', 'tipo': 'materia_prima'});
    expect(find.text('Bodega creada'), findsOneWidget);
  });

  testWidgets('cambia los galpones que comen de una bodega', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.widgetWithText(OutlinedButton, 'Galpones').first);
    await pulsar(tester, find.widgetWithText(CheckboxListTile, 'Galpón 2'));
    await pulsar(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(montaje.envios, ['PUT /bodegas/1/galpones']);
    expect(montaje.cuerpos.single, {
      'galpon_ids': [1, 2, 3],
    });
  });

  testWidgets('una materia prima pide los kilos del bulto antes de guardar', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Nuevo insumo'));
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Calcio');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Crear insumo')).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Kilos por bulto'), '25,5');
    await tester.pump();
    await pulsar(tester, find.widgetWithText(FilledButton, 'Crear insumo'));

    expect(montaje.envios, ['POST /insumos']);
    expect(montaje.cuerpos.single, {'nombre': 'Calcio', 'tipo': 'materia_prima', 'etapa': null, 'kg_por_bulto': 25.5});
  });

  testWidgets('un alimento preparado pide la etapa y el bulto es opcional', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Nuevo insumo'));
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Mezcla levante');
    await pulsar(tester, find.widgetWithText(ChoiceChip, 'Alimento que preparamos'));
    expect(find.widgetWithText(TextField, 'Kilos por bulto (si lo manejan en bultos)'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Crear insumo')).onPressed, isNull);

    await pulsar(tester, find.widgetWithText(ChoiceChip, 'Levante'));
    await pulsar(tester, find.widgetWithText(FilledButton, 'Crear insumo'));

    expect(montaje.cuerpos.single, {
      'nombre': 'Mezcla levante',
      'tipo': 'alimento_preparado',
      'etapa': 'levante',
      'kg_por_bulto': null,
    });
  });

  testWidgets('un alimento preparado puede llevar el peso del bulto', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Nuevo insumo'));
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Mezcla levante');
    await pulsar(tester, find.widgetWithText(ChoiceChip, 'Alimento que preparamos'));
    await pulsar(tester, find.widgetWithText(ChoiceChip, 'Levante'));
    await tester.enterText(find.widgetWithText(TextField, 'Kilos por bulto (si lo manejan en bultos)'), '40');
    await tester.pump();
    await pulsar(tester, find.widgetWithText(FilledButton, 'Crear insumo'));

    expect((montaje.cuerpos.single! as Map)['kg_por_bulto'], 40);
  });

  testWidgets('la fórmula trae lo guardado y solo se guarda cuando suma 100', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.widgetWithText(OutlinedButton, 'Fórmula'));
    expect(find.text('Suma: 100%'), findsOneWidget);
    expect(find.text('Completa'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Maíz'), '50');
    await tester.pump();
    expect(find.text('Suma: 95%'), findsOneWidget);
    expect(find.text('Falta'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar fórmula')).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Maíz'), '60,5');
    await tester.enterText(find.widgetWithText(TextField, 'Soya'), '39,5');
    await tester.pump();
    await pulsar(tester, find.widgetWithText(FilledButton, 'Guardar fórmula'));

    expect(montaje.envios, ['PUT /alimentos/3/formula']);
    expect(montaje.cuerpos.single, [
      {'insumo_id': 1, 'porcentaje': 60.5},
      {'insumo_id': 2, 'porcentaje': 39.5},
    ]);
  });

  testWidgets('cambia el alimento en uso de una etapa', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.widgetWithText(OutlinedButton, 'Alimento en uso').first);
    await pulsar(tester, find.widgetWithText(ChoiceChip, 'Italcol ponedora'));
    await pulsar(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(montaje.envios, ['PUT /bodegas/1/alimento-en-uso/produccion']);
    expect(montaje.cuerpos.single, {'insumo_id': 6});
  });

  testWidgets('si el servidor rechaza, la hoja sigue abierta con el motivo', (tester) async {
    final montaje = Montaje(respuestaAlGuardar: (_) => _json({'detail': 'ya existe una bodega con ese nombre'}, 409));
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Nueva bodega'));
    await tester.enterText(find.byType(TextField), 'Bodega 1');
    await tester.pump();
    await pulsar(tester, find.widgetWithText(FilledButton, 'Crear bodega'));

    expect(find.text('ya existe una bodega con ese nombre'), findsOneWidget);
    expect(find.text('Nueva bodega'), findsWidgets);
    expect(find.text('Bodega creada'), findsNothing);
  });

  testWidgets('lista las razas y marca las que nadie ha revisado', (tester) async {
    await abrirAlto(tester, Montaje());

    expect(find.text('Hy-Line Brown'), findsOneWidget);
    expect(find.text('Lohmann Brown'), findsOneWidget);
    expect(find.text('Valores sin revisar'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Vacunas'), findsNWidgets(2));
    expect(find.widgetWithText(OutlinedButton, 'Curva'), findsNWidgets(2));
  });

  testWidgets('crea una raza con los valores de referencia', (tester) async {
    final montaje = Montaje();
    await abrirAlto(tester, montaje);

    await pulsar(tester, find.text('Nueva raza'));
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Crear raza')).onPressed, isNull);
    await pulsar(tester, find.widgetWithText(ChoiceChip, 'Lohmann Brown'));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Lohmann Brown');
    await tester.enterText(find.byType(TextField), 'Lohmann Brown 2');
    await tester.pump();
    await pulsar(tester, find.widgetWithText(FilledButton, 'Crear raza'));

    expect(montaje.envios, ['POST /lineas']);
    expect(montaje.cuerpos.single, {'nombre': 'Lohmann Brown 2', 'plantilla': 'Lohmann Brown'});
    expect(find.text('Raza creada'), findsOneWidget);
  });

  testWidgets('una raza en blanco no manda plantilla', (tester) async {
    final montaje = Montaje();
    await abrirAlto(tester, montaje);

    await pulsar(tester, find.text('Nueva raza'));
    await tester.enterText(find.byType(TextField), 'Dekalb');
    await tester.pump();
    await pulsar(tester, find.widgetWithText(FilledButton, 'Crear raza'));

    expect(montaje.cuerpos.single, {'nombre': 'Dekalb', 'plantilla': null});
  });

  testWidgets('cambia el nombre de una raza', (tester) async {
    final montaje = Montaje();
    await abrirAlto(tester, montaje);

    await pulsar(tester, find.byTooltip('Cambiar el nombre de Hy-Line Brown'));
    await tester.enterText(find.byType(TextField), 'Hy-Line W-36');
    await tester.pump();
    await pulsar(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(montaje.envios, ['PATCH /lineas/1']);
    expect(montaje.cuerpos.single, {'nombre': 'Hy-Line W-36'});
  });

  testWidgets('el plan muestra las vacunas, deja quitar y agregar, y guarda con los ids que ya tenían', (tester) async {
    final montaje = Montaje();
    await abrirAlto(tester, montaje);

    await pulsar(tester, find.widgetWithText(OutlinedButton, 'Vacunas').first);
    expect(find.text('Vacunas de Hy-Line Brown'), findsOneWidget);
    expect(find.text('Al nacer · Vacuna'), findsOneWidget);
    expect(find.text('Semana 2 a 3 · Vacuna'), findsOneWidget);

    await pulsar(tester, find.byTooltip('Quitar Marek'));
    expect(find.text('Marek'), findsNothing);

    await pulsar(tester, find.text('Agregar vacuna o cuidado'));
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Aceptar')).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Viruela');
    await tester.enterText(find.widgetWithText(TextField, 'Semana ideal'), '6');
    await tester.enterText(find.widgetWithText(TextField, 'Semana máxima'), '4');
    await tester.pump();
    expect(find.text('La semana máxima no puede ser menor que la ideal.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Aceptar')).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Semana máxima'), '8');
    await tester.pump();
    await pulsar(tester, find.widgetWithText(FilledButton, 'Aceptar'));
    expect(find.text('Semana 6 a 8 · Vacuna'), findsOneWidget);

    await pulsar(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(montaje.envios, ['PUT /lineas/1/plan']);
    expect(montaje.cuerpos.single, [
      {'id': 11, 'nombre': 'Gumboro', 'tipo': 'vacuna', 'semana_ideal': 2, 'semana_max': 3, 'nota': ''},
      {'id': null, 'nombre': 'Viruela', 'tipo': 'vacuna', 'semana_ideal': 6, 'semana_max': 8, 'nota': ''},
    ]);
  });

  testWidgets('volver en una hoja encima de otra cierra solo la de arriba', (tester) async {
    final montaje = Montaje();
    await abrirAlto(tester, montaje);

    await pulsar(tester, find.widgetWithText(OutlinedButton, 'Vacunas').first);
    await pulsar(tester, find.text('Agregar vacuna o cuidado'));
    expect(find.text('Nueva vacuna o cuidado'), findsOneWidget);
    await pulsar(tester, find.text('Volver').last);
    expect(find.text('Nueva vacuna o cuidado'), findsNothing);
    expect(find.text('Vacunas de Hy-Line Brown'), findsOneWidget);
    await pulsar(tester, find.text('Volver'));
    expect(find.text('Vacunas de Hy-Line Brown'), findsNothing);
    expect(montaje.envios, isEmpty);
  });

  testWidgets('se puede cambiar una vacuna del plan', (tester) async {
    final montaje = Montaje();
    await abrirAlto(tester, montaje);

    await pulsar(tester, find.widgetWithText(OutlinedButton, 'Vacunas').first);
    await pulsar(tester, find.byTooltip('Cambiar Gumboro'));
    await tester.enterText(find.widgetWithText(TextField, 'Semana máxima'), '4');
    await pulsar(tester, find.widgetWithText(ChoiceChip, 'Desparasitación'));
    await pulsar(tester, find.widgetWithText(FilledButton, 'Aceptar'));
    await pulsar(tester, find.widgetWithText(FilledButton, 'Guardar'));

    final enviadas = (montaje.cuerpos.single! as List).cast<Map<String, dynamic>>();
    expect(enviadas.firstWhere((t) => t['id'] == 11), {
      'id': 11,
      'nombre': 'Gumboro',
      'tipo': 'desparasitacion',
      'semana_ideal': 2,
      'semana_max': 4,
      'nota': '',
    });
  });

  testWidgets('la curva se edita como texto y se valida antes de enviar', (tester) async {
    final montaje = Montaje();
    await abrirAlto(tester, montaje);

    await pulsar(tester, find.widgetWithText(OutlinedButton, 'Curva').first);
    expect(find.text('Curva de Hy-Line Brown'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '18 6 1470\n30 95');

    await tester.enterText(find.byType(TextField), '18 6 1470\n30 mucho');
    await pulsar(tester, find.widgetWithText(FilledButton, 'Guardar'));
    expect(find.textContaining('Línea 2'), findsOneWidget);
    expect(montaje.envios, isEmpty);

    await tester.enterText(find.byType(TextField), '20 45,5 1560\n30 95');
    await pulsar(tester, find.widgetWithText(FilledButton, 'Guardar'));

    expect(montaje.envios, ['PUT /lineas/1/curva']);
    expect(montaje.cuerpos.single, [
      {'semana': 20, 'postura_pct': 45.5, 'peso_g': 1560},
      {'semana': 30, 'postura_pct': 95, 'peso_g': null},
    ]);
  });

  testWidgets('lista las categorías de huevo, crea una y cambia el nombre', (tester) async {
    final montaje = Montaje();
    await abrirAlto(tester, montaje);

    expect(find.text('AA'), findsOneWidget);
    expect(find.text('Roto'), findsOneWidget);
    await pulsar(tester, find.text('Nueva categoría'));
    await tester.enterText(find.byType(TextField), 'Jumbo');
    await tester.pump();
    await pulsar(tester, find.widgetWithText(FilledButton, 'Crear categoría'));
    expect(montaje.envios, ['POST /categorias-huevo']);
    expect(montaje.cuerpos.single, {'nombre': 'Jumbo'});

    await pulsar(tester, find.byTooltip('Cambiar el nombre de AA'));
    await tester.enterText(find.byType(TextField), 'Extra');
    await tester.pump();
    await pulsar(tester, find.widgetWithText(FilledButton, 'Guardar'));
    expect(montaje.envios.last, 'PATCH /categorias-huevo/1');
    expect(montaje.cuerpos.last, {'nombre': 'Extra'});
  });

  testWidgets('los precios del huevo se ven en cada categoría y se cambian', (tester) async {
    final montaje = Montaje();
    await abrirAlto(tester, montaje);

    expect(find.text('caja \$ 120.000 · cartón \$ 12.000'), findsOneWidget);
    expect(find.text('Sin precios todavía'), findsNWidgets(2));
    await pulsar(tester, find.widgetWithText(OutlinedButton, 'Precios').first);
    expect(find.text('A clientes, cada cartón sale a \$ 10.000'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Precio de la caja al mayorista'), '108000');
    await tester.pump();
    await pulsar(tester, find.text('Guardar precios'));

    expect(montaje.envios, ['PUT /huevos/precios/1']);
    expect(montaje.cuerpos.single, {
      'categoria_id': 1,
      'precio_caja': 120000,
      'precio_carton': 12000,
      'precio_mayorista': 108000,
    });
  });

  testWidgets('los tamaños se reordenan con las flechas', (tester) async {
    final montaje = Montaje();
    await abrirAlto(tester, montaje);

    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_upward).first).onPressed, isNull);
    await pulsar(tester, find.byTooltip('Subir Jumbo'));
    await pulsar(tester, find.byTooltip('Subir Jumbo'));

    expect(montaje.envios.take(2), ['PATCH /categorias-huevo/3', 'PATCH /categorias-huevo/2']);
    expect(montaje.cuerpos.take(2), [
      {'orden': 2},
      {'orden': 3},
    ]);
  });

  testWidgets('una categoría se apaga y se prende con el interruptor', (tester) async {
    final montaje = Montaje();
    await abrirAlto(tester, montaje);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(montaje.envios, ['PATCH /categorias-huevo/1']);
    expect(montaje.cuerpos.single, {'activa': false});
  });

  testWidgets('el menú de abajo solo trae Administrar cuando se le da la pantalla', (tester) async {
    Widget montar(Widget? administrar) => MaterialApp(
      theme: temaGranja(),
      home: Cascaron(
        granja: const Text('granja'),
        bodega: const Text('bodega'),
        sanidad: const Text('sanidad'),
        dinero: const Text('dinero'),
        administrar: administrar,
      ),
    );

    await tester.pumpWidget(montar(null));
    expect(find.text('Administrar'), findsNothing);

    await tester.pumpWidget(montar(const Text('panel')));
    expect(find.text('Administrar'), findsOneWidget);
  });
}
