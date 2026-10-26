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

  testWidgets('el menú de abajo solo trae Administrar cuando se le da la pantalla', (tester) async {
    Widget montar(Widget? administrar) => MaterialApp(
      theme: temaGranja(),
      home: Cascaron(granja: const Text('granja'), bodega: const Text('bodega'), administrar: administrar),
    );

    await tester.pumpWidget(montar(null));
    expect(find.text('Administrar'), findsNothing);

    await tester.pumpWidget(montar(const Text('panel')));
    expect(find.text('Administrar'), findsOneWidget);
  });
}
