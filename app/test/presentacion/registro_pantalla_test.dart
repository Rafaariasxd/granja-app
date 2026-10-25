import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/cola.dart';
import 'package:granja_app/datos/sincronizador.dart';
import 'package:granja_app/dominio/modelos.dart';
import 'package:granja_app/presentacion/estado_envios.dart';
import 'package:granja_app/presentacion/formulario_registro.dart';
import 'package:granja_app/presentacion/registro.dart';
import 'package:granja_app/presentacion/tema.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const galpon = ResumenGalpon(
  galponId: 3,
  nombre: 'Galpón 3',
  capacidadAves: 5000,
  avesVivas: 1612,
  ocupacionPct: 32,
  loteId: 8,
  etapa: Etapa.produccion,
  edadSemanas: 45,
  linea: 'Lohmann',
);

final ahora = DateTime.utc(2026, 10, 21, 17);

class Montaje {
  Montaje({int estado = 200, this.borrar}) {
    final cliente = MockClient((peticion) async {
      enviados.add(jsonDecode(peticion.body) as Map<String, dynamic>);
      return http.Response.bytes(utf8.encode('{}'), estado);
    });
    final almacen = AlmacenEnMemoria();
    final api = ApiGranja(Uri.parse('http://granja.test/'), cliente: cliente);
    envios = EstadoEnvios(Sincronizador(almacen, api), almacen);
    formulario = FormularioRegistro(galpon: galpon, fecha: DateTime.utc(2026, 10, 21));
  }

  final enviados = <Map<String, dynamic>>[];
  late final EstadoEnvios envios;
  late final FormularioRegistro formulario;
  bool? resultado;
  final Future<String?> Function()? borrar;

  Widget get app => MaterialApp(
    theme: temaGranja(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => resultado = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => RegistroPantalla(
                formulario: formulario,
                envios: envios,
                reloj: () => ahora,
                corrigiendo: borrar != null,
                alBorrar: borrar,
              ),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
}

Future<void> abrir(WidgetTester tester, Montaje montaje) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(montaje.app);
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> guardar(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Guardar'));
  await tester.tap(find.text('Guardar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra el galpón y no deja guardar sin huevos', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    expect(find.text('Galpón 3'), findsOneWidget);
    expect(find.text('Lohmann · 45 semanas · 1.612 aves'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });

  testWidgets('en menos de un minuto: huevos, rotos, muertas y guardar', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await tester.enterText(find.byType(TextField).first, '1405');
    await tester.tap(find.byTooltip('Un huevo roto más'));
    await tester.tap(find.byTooltip('Un huevo roto más'));
    await tester.tap(find.byTooltip('Una gallina muerta más'));
    await tester.enterText(find.byType(TextField).last, '180');
    await tester.pump();
    expect(find.text('Postura de hoy: 87,2%'), findsOneWidget);

    await guardar(tester);

    expect(montaje.resultado, isTrue);
    expect(montaje.enviados.single['huevos_total'], 1405);
    expect(montaje.enviados.single['huevos_rotos'], 2);
    expect(montaje.enviados.single['mortalidad'], 1);
    expect(montaje.enviados.single['alimento_kg'], 180);
  });

  testWidgets('sin señal se guarda en el teléfono y queda pendiente', (tester) async {
    final montaje = Montaje(estado: 503);
    await abrir(tester, montaje);

    await tester.enterText(find.byType(TextField).first, '1405');
    await tester.pump();
    await guardar(tester);

    expect(montaje.resultado, isTrue);
    expect(montaje.envios.pendientes, 1);
  });

  testWidgets('el contador de rotos no baja de cero', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    final menos = find.widgetWithIcon(IconButton, Icons.remove).first;
    expect(tester.widget<IconButton>(menos).onPressed, isNull);
  });

  testWidgets('más rotos que huevos avisa y no deja guardar', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await tester.enterText(find.byType(TextField).first, '1');
    await tester.tap(find.byTooltip('Un huevo roto más'));
    await tester.tap(find.byTooltip('Un huevo roto más'));
    await tester.pump();

    expect(find.text('Revisa los datos'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });

  testWidgets('volver sin guardar no envía nada', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await tester.tap(find.byTooltip('Volver al inicio'));
    await tester.pumpAndSettle();

    expect(montaje.resultado, isFalse);
    expect(montaje.enviados, isEmpty);
  });

  testWidgets('quien no puede borrar no ve el botón', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    expect(find.text('Borrar este registro'), findsNothing);
  });

  testWidgets('al corregir se avisa y el administrador puede borrar tras confirmar', (tester) async {
    var borrados = 0;
    final montaje = Montaje(
      borrar: () async {
        borrados++;
        return null;
      },
    );
    await abrir(tester, montaje);

    expect(find.textContaining('Corrigiendo el registro de hoy'), findsOneWidget);
    await tester.ensureVisible(find.text('Borrar este registro'));
    await tester.tap(find.text('Borrar este registro'));
    await tester.pumpAndSettle();
    expect(find.text('¿Borrar este registro?'), findsOneWidget);
    await tester.tap(find.text('Sí, borrar'));
    await tester.pumpAndSettle();

    expect(borrados, 1);
    expect(montaje.resultado, isTrue);
  });

  testWidgets('si dice que no, no se borra nada', (tester) async {
    var borrados = 0;
    final montaje = Montaje(
      borrar: () async {
        borrados++;
        return null;
      },
    );
    await abrir(tester, montaje);

    await tester.ensureVisible(find.text('Borrar este registro'));
    await tester.tap(find.text('Borrar este registro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No, dejarlo'));
    await tester.pumpAndSettle();

    expect(borrados, 0);
    expect(find.text('Guardar'), findsOneWidget);
  });

  testWidgets('si no se pudo borrar muestra el motivo y no cierra', (tester) async {
    final montaje = Montaje(borrar: () async => 'Sin señal: borrar necesita internet.');
    await abrir(tester, montaje);

    await tester.ensureVisible(find.text('Borrar este registro'));
    await tester.tap(find.text('Borrar este registro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, borrar'));
    await tester.pumpAndSettle();

    expect(find.text('Sin señal: borrar necesita internet.'), findsOneWidget);
    expect(montaje.resultado, isNull);
  });
}
