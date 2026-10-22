import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/servicio_sesion.dart';
import 'package:granja_app/presentacion/entrada.dart';
import 'package:granja_app/presentacion/estado_sesion.dart';
import 'package:granja_app/presentacion/puerta_de_sesion.dart';
import 'package:granja_app/presentacion/tema.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final base = Uri.parse('http://granja.test/');

http.Response json(Object cuerpo, int codigo) => http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), codigo);

EstadoSesion estadoCon(http.Response Function() responder, [AlmacenSesionEnMemoria? almacen]) {
  final api = ApiGranja(base, cliente: MockClient((_) async => responder()));
  return EstadoSesion(ServicioSesion(api, almacen ?? AlmacenSesionEnMemoria()));
}

Widget app(EstadoSesion estado) => MaterialApp(
  theme: temaGranja(),
  home: PuertaDeSesion(
    estado: estado,
    constructor: (_) => const Scaffold(body: Text('dentro')),
  ),
);

Future<void> escribir(WidgetTester tester, String nombre, String pin) async {
  await tester.enterText(find.widgetWithText(TextField, 'Nombre'), nombre);
  await tester.enterText(find.widgetWithText(TextField, 'PIN'), pin);
  await tester.pump();
}

void main() {
  final correcta = json({'token': 't', 'usuario_id': 1, 'nombre': 'Mamá', 'rol': 'registrador'}, 200);

  testWidgets('sin sesión guardada se pide nombre y PIN, y con ellos se entra', (tester) async {
    final estado = estadoCon(() => correcta);
    await estado.iniciar();
    await tester.pumpWidget(app(estado));

    expect(find.byType(EntradaPantalla), findsOneWidget);
    await escribir(tester, 'Mamá', '729104');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('dentro'), findsOneWidget);
  });

  testWidgets('el botón espera a tener nombre y los 6 números', (tester) async {
    final estado = estadoCon(() => correcta);
    await estado.iniciar();
    await tester.pumpWidget(app(estado));

    await escribir(tester, 'Mamá', '7291');
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await escribir(tester, 'Mamá', '729104');
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });

  testWidgets('el PIN solo admite números y como máximo 6', (tester) async {
    final estado = estadoCon(() => correcta);
    await estado.iniciar();
    await tester.pumpWidget(app(estado));

    await escribir(tester, 'Mamá', '72a91x04999');

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'PIN')).controller!.text, '729104');
  });

  testWidgets('un PIN malo muestra el mensaje y se queda en la entrada', (tester) async {
    final estado = estadoCon(() => json({'detail': 'nombre o PIN incorrectos'}, 401));
    await estado.iniciar();
    await tester.pumpWidget(app(estado));

    await escribir(tester, 'Mamá', '000001');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Nombre o PIN incorrectos.'), findsOneWidget);
    expect(find.text('dentro'), findsNothing);
  });

  testWidgets('con la sesión guardada entra directo, sin pedir PIN', (tester) async {
    final almacen = AlmacenSesionEnMemoria();
    await ServicioSesion(ApiGranja(base, cliente: MockClient((_) async => correcta)), almacen).entrar('Mamá', '729104');
    final estado = estadoCon(() => json([], 200), almacen);
    await estado.iniciar();
    await tester.pumpWidget(app(estado));

    expect(find.text('dentro'), findsOneWidget);
  });

  testWidgets('si la sesión vence vuelve a la entrada con el aviso', (tester) async {
    final estado = estadoCon(() => correcta);
    await estado.iniciar();
    await estado.entrar('Mamá', '729104');
    await tester.pumpWidget(app(estado));
    expect(find.text('dentro'), findsOneWidget);

    await estado.sesionVencida();
    await tester.pump();

    expect(find.text('La sesión se cerró. Vuelve a entrar.'), findsOneWidget);
    expect(find.byType(EntradaPantalla), findsOneWidget);
  });

  testWidgets('sin señal explica por qué no deja entrar', (tester) async {
    final api = ApiGranja(base, cliente: MockClient((_) async => throw http.ClientException('sin red')));
    final estado = EstadoSesion(ServicioSesion(api, AlmacenSesionEnMemoria()));
    await estado.iniciar();
    await tester.pumpWidget(app(estado));

    await escribir(tester, 'Mamá', '729104');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sin señal'), findsOneWidget);
  });
}
