import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/huevos.dart';
import 'package:granja_app/datos/operaciones.dart';
import 'package:granja_app/presentacion/estado_huevos.dart';
import 'package:granja_app/presentacion/hoja.dart';
import 'package:granja_app/presentacion/huevo.dart';
import 'package:granja_app/presentacion/tema.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final base = Uri.parse('http://granja.test/');
final ahora = DateTime.utc(2026, 10, 25, 17);

Map<String, Object?> existencia(int id, String nombre, int huevos) => {
  'categoria_id': id,
  'categoria': nombre,
  'activa': true,
  'huevos': huevos,
  'cajas': 0,
  'cartones': 0,
  'sueltos': 0,
};

final salidaAbierta = {
  'id': 'salida-1',
  'fecha': '2026-10-24',
  'tipo_venta': 'cliente',
  'cliente': 'Tienda La Esperanza',
  'estado': 'abierta',
  'cerrada_el': null,
  'valor_total': null,
  'lineas': [
    {'categoria_id': 1, 'huevos_sacados': 1080, 'huevos_vendidos': null, 'valor': null},
  ],
};

Map<String, Object?> bodega({List<Object?>? abiertas, List<Object?>? precios}) => {
  'existencias': [existencia(1, 'AA', 4440), existencia(2, 'A', 2880), existencia(3, 'B', 0)],
  'precios':
      precios ??
      [
        {'categoria_id': 1, 'precio_caja': 120000.0, 'precio_carton': 12000.0, 'precio_mayorista': 108000.0},
        {'categoria_id': 2, 'precio_caja': 96000.0, 'precio_carton': null, 'precio_mayorista': null},
      ],
  'abiertas': abiertas ?? [salidaAbierta],
};

class Montaje {
  Montaje({http.Response Function(http.Request)? servidor, Map<String, Object?>? datos}) {
    final cliente = MockClient((peticion) async {
      peticiones.add('${peticion.method} ${peticion.url.path}');
      if (peticion.body.isNotEmpty) cuerpos.add(jsonDecode(peticion.body) as Map<String, dynamic>);
      if (servidor != null) return servidor(peticion);
      if (peticion.method == 'GET') return http.Response.bytes(utf8.encode(jsonEncode(datos ?? bodega())), 200);
      return http.Response('{}', 200);
    });
    almacen = AlmacenHuevosEnMemoria();
    operaciones = AlmacenOperacionesEnMemoria();
    estado = EstadoHuevos(
      RepositorioHuevos(ApiGranja(base, cliente: cliente), almacen, operaciones),
      reloj: () => ahora,
    );
  }

  final peticiones = <String>[];
  final cuerpos = <Map<String, dynamic>>[];
  late final AlmacenHuevosEnMemoria almacen;
  late final AlmacenOperacionesEnMemoria operaciones;
  late final EstadoHuevos estado;

  Widget get app => MaterialApp(
    theme: temaGranja(),
    home: Scaffold(body: HuevoPantalla(estado: estado)),
  );
}

Future<void> abrir(WidgetTester tester, Montaje montaje) async {
  tester.view.physicalSize = const Size(900, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(montaje.app);
  await tester.pumpAndSettle();
}

Future<void> pulsar(WidgetTester tester, Finder buscador) async {
  await tester.ensureVisible(buscador);
  await tester.tap(buscador);
  await tester.pumpAndSettle();
}

Future<void> escribir(WidgetTester tester, String etiqueta, String texto) async {
  final porClave = find.byKey(ValueKey(etiqueta));
  final campo = porClave.evaluate().isNotEmpty ? porClave : find.widgetWithText(TextField, etiqueta);
  await tester.ensureVisible(campo);
  await tester.enterText(campo, texto);
  await tester.pump();
}

http.Response Function(http.Request) servidorCon(bool Function() hayRed) => (p) {
  if (!hayRed()) throw http.ClientException('sin red');
  return p.method == 'GET' ? http.Response.bytes(utf8.encode(jsonEncode(bodega())), 200) : http.Response('{}', 200);
};

void main() {
  testWidgets('muestra lo que hay en cajas y cartones, en total y por tamaño', (tester) async {
    await abrir(tester, Montaje());

    expect(find.text('Bodega del huevo'), findsOneWidget);
    expect(find.text('20 cajas y 4 cartones'), findsOneWidget);
    expect(find.text('12 cajas y 4 cartones'), findsOneWidget);
    expect(find.text('8 cajas'), findsOneWidget);
    expect(find.text('Nada'), findsOneWidget);
    expect(find.text('4.440 huevos'), findsOneWidget);
  });

  testWidgets('lo que entra se escribe en cajas y cartones y se manda en huevos', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('12 cajas y 4 cartones'));
    await pulsar(tester, find.text('Entró a la bodega'));
    expect(find.text('Entró huevo AA'), findsOneWidget);
    await escribir(tester, 'Cartones', '26');
    expect(find.text('Son 2 cajas y 2 cartones (780 huevos)'), findsOneWidget);
    await escribir(tester, 'Huevos', '15');
    await pulsar(tester, find.text('Guardar'));

    expect(montaje.peticiones, contains('POST /huevos/ingresos'));
    final cuerpo = montaje.cuerpos.single;
    expect((cuerpo['categoria_id'], cuerpo['huevos'], cuerpo['fecha']), (1, 795, '2026-10-25'));
    expect(cuerpo['operacion_id'], isA<String>());
    expect(find.text('Huevo guardado en la bodega'), findsOneWidget);
  });

  testWidgets('sin señal lo que entra se suma de una vez y se envía después', (tester) async {
    var hayRed = true;
    final montaje = Montaje(servidor: servidorCon(() => hayRed));
    await abrir(tester, montaje);
    hayRed = false;

    await pulsar(tester, find.text('8 cajas'));
    await pulsar(tester, find.text('Entró a la bodega'));
    await escribir(tester, 'Cajas', '2');
    await pulsar(tester, find.text('Guardar'));

    expect(find.text('Huevo guardado en la bodega. Se envía cuando haya señal'), findsOneWidget);
    expect(find.text('10 cajas'), findsOneWidget);
    expect(find.text('1 cosa sin enviar'), findsOneWidget);

    hayRed = true;
    await montaje.estado.cargar();
    await tester.pumpAndSettle();
    expect(montaje.peticiones.where((p) => p == 'POST /huevos/ingresos'), hasLength(2));
    expect(await montaje.operaciones.sinResolver(), isEmpty);
  });

  testWidgets('dar de baja no deja pasar de lo que hay y lleva la nota', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('8 cajas'));
    await pulsar(tester, find.text('Se rompieron o dañaron'));
    await escribir(tester, 'Cajas', '9');
    expect(find.text('No hay tanto huevo.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Dar de baja')).onPressed, isNull);
    await escribir(tester, 'Cajas', '');
    await escribir(tester, 'Cartones', '2');
    await escribir(tester, '¿Qué pasó? (opcional)', 'se cayeron');
    await pulsar(tester, find.text('Dar de baja'));

    final cuerpo = montaje.cuerpos.single;
    expect((cuerpo['categoria_id'], cuerpo['huevos'], cuerpo['nota']), (2, 60, 'se cayeron'));
  });

  testWidgets('contar deja el número contado y acepta cero', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('8 cajas'));
    await pulsar(tester, find.text('Conté lo que hay'));
    expect(find.text('La app dice que hay 8 cajas.'), findsOneWidget);
    await escribir(tester, 'Cajas', '0');
    await pulsar(tester, find.text('Dejar este conteo'));

    expect(montaje.peticiones, contains('POST /huevos/conteos'));
    expect(montaje.cuerpos.single, {'categoria_id': 2, 'huevos': 0, 'nota': 'Conteo en la bodega'});
  });

  testWidgets('vender a un cliente sugiere el total con el precio de la caja', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Vender'));
    expect(find.text('B · hay nada'), findsNothing);
    await escribir(tester, 'AA Cajas', '2');
    await escribir(tester, 'AA Cartones', '4');
    expect(find.text('Según los precios: \$ 280.000'), findsOneWidget);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Total cobrado')).controller!.text, '280000');
    await escribir(tester, 'Nombre (opcional)', 'Doña Rosa');
    await pulsar(tester, find.text('Guardar venta'));

    expect(montaje.peticiones.where((p) => p.startsWith('PUT /huevos/ventas/')), hasLength(1));
    expect(montaje.cuerpos.single, {
      'fecha': '2026-10-25',
      'tipo_venta': 'cliente',
      'cliente': 'Doña Rosa',
      'lineas': [
        {'categoria_id': 1, 'huevos': 840},
      ],
      'valor_cobrado': 280000,
    });
    expect(find.text('Venta guardada'), findsOneWidget);
  });

  testWidgets('al particular se le sugiere el precio del cartón', (tester) async {
    await abrir(tester, Montaje());

    await pulsar(tester, find.text('Vender'));
    await pulsar(tester, find.text('Particular'));
    await escribir(tester, 'AA Cartones', '2');
    expect(find.text('Según los precios: \$ 24.000'), findsOneWidget);
  });

  testWidgets('si falta un precio hay que escribir el total', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Vender'));
    await pulsar(tester, find.text('Particular'));
    await escribir(tester, 'A Cartones', '3');
    expect(find.textContaining('Falta el precio'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar venta')).onPressed, isNull);
    await escribir(tester, 'Total cobrado', '33000');
    await pulsar(tester, find.text('Guardar venta'));

    expect(montaje.cuerpos.single['valor_cobrado'], 33000);
  });

  testWidgets('no deja vender más huevo del que hay', (tester) async {
    await abrir(tester, Montaje());

    await pulsar(tester, find.text('Vender'));
    await escribir(tester, 'A Cajas', '9');
    expect(find.text('No hay tanto huevo A.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar venta')).onPressed, isNull);
  });

  testWidgets('sacar huevo para vender lo descuenta y queda por cerrar', (tester) async {
    var hayRed = true;
    final montaje = Montaje(servidor: servidorCon(() => hayRed));
    await abrir(tester, montaje);
    hayRed = false;

    await pulsar(tester, find.text('Sacar huevo para vender'));
    await pulsar(tester, find.text('Mayorista'));
    await escribir(tester, 'AA Cajas', '5');
    expect(find.text('Si se vende todo serían \$ 540.000'), findsOneWidget);
    await escribir(tester, 'Nombre (opcional)', 'Distribuidora');
    await pulsar(tester, find.text('Guardar salida'));

    expect(find.text('7 cajas y 4 cartones'), findsOneWidget);
    expect(find.text('Distribuidora · Mayorista'), findsOneWidget);
    expect(find.text('Sin enviar'), findsOneWidget);
    final guardada = (await montaje.operaciones.sinResolver()).single;
    expect((guardada.tipo, guardada.tipoVenta), (TipoOperacion.huevoSalida, 'mayorista'));
    expect(guardada.lineas, {1: 1800});
  });

  testWidgets('cerrar una salida en la que se vendió todo', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    expect(find.text('Salidas por cerrar'), findsOneWidget);
    expect(find.text('Tienda La Esperanza · Cliente'), findsOneWidget);
    expect(find.text('AA: 3 cajas'), findsOneWidget);
    await pulsar(tester, find.text('Cerrar la salida'));
    expect(find.text('Según los precios: \$ 360.000'), findsOneWidget);
    await pulsar(tester, find.widgetWithText(FilledButton, 'Cerrar salida'));

    expect(montaje.peticiones, contains('POST /huevos/salidas/salida-1/cierre'));
    expect(montaje.cuerpos.single, {'fecha': '2026-10-25', 'vendidos': null, 'valor_cobrado': 360000});
    expect(find.text('Salida cerrada'), findsOneWidget);
  });

  testWidgets('cerrar una salida en la que sobró huevo manda lo vendido', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Cerrar la salida'));
    await pulsar(tester, find.text('Sobró huevo'));
    await escribir(tester, 'Volvió AA Cajas', '1');
    await escribir(tester, 'Volvió AA Cartones', '6');
    expect(find.text('Se vendieron 1 caja y 6 cartones'), findsOneWidget);
    expect(find.text('Según los precios: \$ 180.000'), findsOneWidget);
    await pulsar(tester, find.widgetWithText(FilledButton, 'Cerrar salida'));

    expect(montaje.cuerpos.single['vendidos'], [
      {'categoria_id': 1, 'huevos': 540},
    ]);
    expect(montaje.cuerpos.single['valor_cobrado'], 180000);
  });

  testWidgets('no puede volver más huevo del que salió', (tester) async {
    await abrir(tester, Montaje());

    await pulsar(tester, find.text('Cerrar la salida'));
    await pulsar(tester, find.text('Sobró huevo'));
    await escribir(tester, 'Volvió AA Cajas', '4');
    expect(find.text('No puede volver más de lo que salió.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Cerrar salida')).onPressed, isNull);
  });

  testWidgets('si vuelve todo no se cobra nada', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Cerrar la salida'));
    await pulsar(tester, find.text('Sobró huevo'));
    await escribir(tester, 'Volvió AA Cajas', '3');
    expect(find.text('No se vendió nada: todo vuelve a la bodega.'), findsOneWidget);
    await pulsar(tester, find.widgetWithText(FilledButton, 'Cerrar salida'));

    expect(montaje.cuerpos.single['valor_cobrado'], isNull);
    expect(montaje.cuerpos.single['vendidos'], [
      {'categoria_id': 1, 'huevos': 0},
    ]);
  });

  testWidgets('sin señal el cierre devuelve a la bodega lo que sobró de una vez', (tester) async {
    var hayRed = true;
    final montaje = Montaje(servidor: servidorCon(() => hayRed));
    await abrir(tester, montaje);
    hayRed = false;

    await pulsar(tester, find.text('Cerrar la salida'));
    await pulsar(tester, find.text('Sobró huevo'));
    await escribir(tester, 'Volvió AA Cajas', '1');
    await pulsar(tester, find.widgetWithText(FilledButton, 'Cerrar salida'));

    expect(find.text('Salidas por cerrar'), findsNothing);
    expect(find.text('13 cajas y 4 cartones'), findsOneWidget);
    expect(find.text('Salida cerrada. Se envía cuando haya señal'), findsOneWidget);
  });

  testWidgets('anular una salida pide confirmación y necesita señal', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);

    await pulsar(tester, find.text('Cerrar la salida'));
    await pulsar(tester, find.text('Anular salida'));
    expect(find.text('¿Anular esta salida?'), findsOneWidget);
    await pulsar(tester, find.text('Sí, anular'));

    expect(montaje.peticiones, contains('POST /huevos/salidas/salida-1/anulacion'));
  });

  testWidgets('sin señal y sin copia explica que no hay datos todavía', (tester) async {
    await abrir(tester, Montaje(servidor: (_) => throw http.ClientException('sin red')));

    expect(find.text('No hay datos todavía'), findsOneWidget);
  });

  testWidgets('sin señal usa la última copia', (tester) async {
    final montaje = Montaje(servidor: (_) => throw http.ClientException('sin red'));
    await montaje.almacen.guardar(HuevosGuardados(actualizadoEn: ahora, datos: jsonEncode(bodega())));
    await abrir(tester, montaje);

    expect(find.text('Sin señal'), findsOneWidget);
    expect(find.text('20 cajas y 4 cartones'), findsOneWidget);
  });

  testWidgets('con la sesión vencida el estado lo marca', (tester) async {
    final montaje = Montaje(servidor: (_) => http.Response('{}', 401));
    await abrir(tester, montaje);

    expect(montaje.estado.sesionVencida, isTrue);
  });

  group('huevo del día', () {
    Future<bool?> abrirHojaDelDia(WidgetTester tester, Montaje montaje, int recogidos) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await montaje.estado.cargar();
      bool? resultado;
      await tester.pumpWidget(
        MaterialApp(
          theme: temaGranja(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => resultado = await abrirHoja<bool>(
                context: context,
                builder: (_) => HojaHuevoDelDia(estado: montaje.estado, origen: 'Galpón 1', recogidos: recogidos),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return resultado;
    }

    testWidgets('lo clasificado por tamaño entra a la bodega, una entrada por tamaño', (tester) async {
      final montaje = Montaje();
      await abrirHojaDelDia(tester, montaje, 1398);

      expect(find.textContaining('se recogieron 1.398 huevos'), findsOneWidget);
      await escribir(tester, 'AA Cajas', '3');
      await escribir(tester, 'A Cartones', '10');
      expect(find.text('Van 3 cajas y 10 cartones (1.380 de 1.398 huevos)'), findsOneWidget);
      await pulsar(tester, find.text('Guardar en la bodega'));

      final ingresos = [for (final c in montaje.cuerpos) (c['categoria_id'], c['huevos'])];
      expect(ingresos, [(1, 1080), (2, 300)]);
      expect(montaje.peticiones.where((p) => p == 'POST /huevos/ingresos'), hasLength(2));
      expect(find.text('Guardar en la bodega'), findsNothing);
    });

    testWidgets('ahora no cierra sin guardar nada', (tester) async {
      final montaje = Montaje();
      await abrirHojaDelDia(tester, montaje, 1398);

      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar en la bodega')).onPressed, isNull);
      await pulsar(tester, find.text('Ahora no'));

      expect(find.text('Guardar en la bodega'), findsNothing);
      expect(montaje.cuerpos, isEmpty);
    });

    testWidgets('avisa si se pasa más huevo del recogido', (tester) async {
      final montaje = Montaje();
      await abrirHojaDelDia(tester, montaje, 300);

      await escribir(tester, 'AA Cajas', '1');
      expect(find.textContaining('Es más de lo que se recogió'), findsOneWidget);
    });

    testWidgets('solo muestra los tamaños activos', (tester) async {
      final datos = bodega();
      (datos['existencias'] as List).add({...existencia(4, 'Roto', 0), 'activa': false});
      final montaje = Montaje(datos: datos);
      await abrirHojaDelDia(tester, montaje, 100);

      expect(find.byKey(const ValueKey('AA Cajas')), findsOneWidget);
      expect(find.byKey(const ValueKey('Roto Cajas')), findsNothing);
    });
  });
}
