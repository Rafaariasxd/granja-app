import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_iot.dart';
import 'package:granja_app/presentacion/estado_galpon_vivo.dart';
import 'package:granja_app/presentacion/galpon_vivo.dart';
import 'package:granja_app/presentacion/tema.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../datos/api_iot_test.dart' as datos;

class ClaveEnMemoria implements AlmacenClaveIot {
  String? clave;

  @override
  Future<String?> leer() async => clave;

  @override
  Future<void> guardar(String nueva) async => clave = nueva;

  @override
  Future<void> borrar() async => clave = null;
}

class Servidor {
  final ordenes = <Map<String, Object?>>[];

  http.Client cliente() => MockClient((p) async {
    final ruta = p.url.path;
    if (ruta.endsWith('/comandos')) {
      if (p.headers['Authorization'] != 'Bearer buena') return datos.json({'detail': 'Clave'}, 401);
      ordenes.add(jsonDecode(p.body) as Map<String, Object?>);
      return datos.json({'estado': 'enviado'}, 202);
    }
    if (ruta.endsWith('/alertas')) return datos.json(datos.alertasJson);
    if (ruta.endsWith('/serie')) return datos.json(datos.serieJson);
    return datos.json(datos.dispositivosJson);
  });
}

Widget envolver(Widget hijo) => MaterialApp(theme: temaGranja(), home: hijo);

void main() {
  testWidgets('la tarjeta del inicio resume el galpón y abre la pantalla', (tester) async {
    final estado = EstadoGalponVivo(
      ApiIot(Uri.parse('https://g.test'), cliente: Servidor().cliente()),
      ClaveEnMemoria(),
    );
    await estado.cargar();
    var abierta = false;
    await tester.pumpWidget(
      envolver(
        Scaffold(
          body: TarjetaGalponVivo(estado: estado, alAbrir: () => abierta = true),
        ),
      ),
    );
    expect(find.text('Galpón en vivo'), findsOneWidget);
    expect(find.text('24,1 °C'), findsOneWidget);
    expect(find.text('2 de 3 equipos conectados'), findsOneWidget);
    expect(find.textContaining('1 alerta crítica: Amoníaco sobre 25 ppm'), findsOneWidget);
    await tester.tap(find.text('Galpón en vivo'));
    expect(abierta, isTrue);
  });

  testWidgets('desde la pantalla se abre un equipo, se ve su gráfica y se le manda una orden con clave', (
    tester,
  ) async {
    final servidor = Servidor();
    final clave = ClaveEnMemoria();
    final estado = EstadoGalponVivo(ApiIot(Uri.parse('https://g.test'), cliente: servidor.cliente()), clave);
    await tester.pumpWidget(envolver(GalponVivoPantalla(estado: estado, puedeControlar: true)));
    await tester.pumpAndSettle();

    expect(find.text('Galpón 1'), findsOneWidget);
    expect(find.text('Apagado'), findsOneWidget);
    expect(find.textContaining('Amoníaco llegó a 27,4'), findsOneWidget);

    await tester.tap(find.text('Ventiladores galpón 1'));
    await tester.pumpAndSettle();
    expect(find.text('Últimas 24 horas'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    final automatico = find.widgetWithText(OutlinedButton, 'Automático');
    await tester.ensureVisible(automatico);
    await tester.tap(automatico);
    await tester.pumpAndSettle();
    expect(find.text('Clave del galpón'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'buena');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(servidor.ordenes.single, {
      'accion': 'modo',
      'parametros': {'auto': true},
    });
    expect(clave.clave, 'buena');
    expect(find.textContaining('Orden enviada'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('abrir la pantalla desde la tarjeta del inicio no avisa en medio de la construcción', (tester) async {
    final estado = EstadoGalponVivo(
      ApiIot(Uri.parse('https://g.test'), cliente: Servidor().cliente()),
      ClaveEnMemoria(),
    );
    await estado.cargar();
    await tester.pumpWidget(
      envolver(
        Builder(
          builder: (contexto) => Scaffold(
            body: TarjetaGalponVivo(
              estado: estado,
              alAbrir: () => Navigator.of(contexto).push(
                MaterialPageRoute<void>(builder: (_) => GalponVivoPantalla(estado: estado, puedeControlar: false)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Galpón en vivo'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Ventiladores galpón 1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('quien no administra ve los datos pero no los controles', (tester) async {
    final estado = EstadoGalponVivo(
      ApiIot(Uri.parse('https://g.test'), cliente: Servidor().cliente()),
      ClaveEnMemoria(),
    );
    await tester.pumpWidget(envolver(GalponVivoPantalla(estado: estado, puedeControlar: false)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ambiente galpón 1'));
    await tester.pumpAndSettle();
    expect(find.text('Últimas 24 horas'), findsOneWidget);
    expect(find.text('Controlar'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
