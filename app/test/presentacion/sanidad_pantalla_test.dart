import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/operaciones.dart';
import 'package:granja_app/datos/sanidad.dart';
import 'package:granja_app/presentacion/estado_sanidad.dart';
import 'package:granja_app/presentacion/sanidad.dart';
import 'package:granja_app/presentacion/tema.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final base = Uri.parse('http://granja.test/');
final ahora = DateTime.utc(2026, 10, 25, 17);

Map<String, Object?> tarea(
  int id,
  String nombre,
  String estado, {
  int ideal = 28,
  int maximo = 30,
  String? aplicada,
  String? cumplimiento,
  String nota = '',
}) => {
  'tarea_id': id,
  'nombre': nombre,
  'tipo': 'vacuna',
  'semana_ideal': ideal,
  'semana_max': maximo,
  'nota_plan': nota,
  'estado': estado,
  'aplicada_en': aplicada,
  'nota': '',
  'cumplimiento_id': cumplimiento,
};

Map<String, Object?> alerta(int galpon, String nombre, String tipo, String nivel, String titulo, String detalle) => {
  'galpon_id': galpon,
  'galpon': nombre,
  'lote_id': galpon,
  'tipo': tipo,
  'nivel': nivel,
  'titulo': titulo,
  'detalle': detalle,
  'recomendaciones': ['Revisar el agua', 'Avisar al veterinario'],
};

final panorama = {
  'fecha': '2026-10-25',
  'alertas': [
    alerta(
      1,
      'Galpón 1',
      'vacuna_atrasada',
      'urgente',
      'Newcastle (refuerzo en postura): atrasada',
      'Debía aplicarse en la semana 30.',
    ),
    alerta(5, 'Galpón 5', 'peso', 'revisar', 'Peso algo bajo', 'Pesan 940 g y lo esperado es 1010 g.'),
  ],
  'galpones': [
    {
      'galpon_id': 1,
      'galpon': 'Galpón 1',
      'lote_id': 1,
      'linea': 'Hy-Line Brown',
      'edad_semanas': 32,
      'etapa': 'produccion',
      'aves_vivas': 2480,
      'tareas': [
        tarea(10, 'Newcastle (refuerzo en postura)', 'atrasada', nota: 'En el agua de bebida.'),
        tarea(11, 'Marek', 'aplicada', ideal: 0, maximo: 0, aplicada: '2026-03-02', cumplimiento: 'cumpl-1'),
        tarea(12, 'Newcastle (refuerzo largo)', 'lejana', ideal: 44, maximo: 46),
      ],
      'pesajes': <Object?>[],
      'peso': null,
      'postura': {'fecha': '2026-10-24', 'real_pct': 86.0, 'estandar_pct': 95.0},
    },
    {
      'galpon_id': 5,
      'galpon': 'Galpón 5',
      'lote_id': 5,
      'linea': 'Hy-Line Brown',
      'edad_semanas': 12,
      'etapa': 'levante',
      'aves_vivas': 950,
      'tareas': [tarea(20, 'Encefalomielitis aviar', 'ahora', ideal: 10, maximo: 14)],
      'pesajes': [
        {'id': 'p1', 'fecha': '2026-10-23', 'peso_g': 940.0, 'aves_pesadas': 40},
      ],
      'peso': {
        'fecha': '2026-10-23',
        'peso_g': 940.0,
        'estandar_g': 1010.0,
        'diferencia_pct': -6.9,
        'nivel': 'atencion',
      },
      'postura': null,
    },
  ],
};

class Montaje {
  Montaje({http.Response Function(http.Request)? servidor, Object? datos}) {
    final cliente = MockClient((peticion) async {
      peticiones.add('${peticion.method} ${peticion.url.path}');
      if (peticion.body.isNotEmpty) cuerpos.add(jsonDecode(peticion.body) as Map<String, dynamic>);
      if (servidor != null) return servidor(peticion);
      if (peticion.method == 'GET') return http.Response.bytes(utf8.encode(jsonEncode(datos ?? panorama)), 200);
      return http.Response('{}', peticion.method == 'DELETE' ? 204 : 200);
    });
    almacen = AlmacenSanidadEnMemoria();
    operaciones = AlmacenOperacionesEnMemoria();
    estado = EstadoSanidad(
      RepositorioSanidad(ApiGranja(base, cliente: cliente), almacen, operaciones),
      reloj: () => ahora,
    );
  }

  final peticiones = <String>[];
  final cuerpos = <Map<String, dynamic>>[];
  late final AlmacenSanidadEnMemoria almacen;
  late final AlmacenOperacionesEnMemoria operaciones;
  late final EstadoSanidad estado;

  Widget get app => MaterialApp(
    theme: temaGranja(),
    home: SanidadPantalla(estado: estado),
  );
}

Future<void> abrir(WidgetTester tester, Montaje montaje) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(montaje.app);
  await tester.pumpAndSettle();
}

Future<void> abrirGalpon(WidgetTester tester, String nombre) async {
  await tester.tap(find.widgetWithText(Card, nombre).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra los avisos de todos los galpones, lo urgente primero', (tester) async {
    await abrir(tester, Montaje());

    expect(find.text('Avisos'), findsOneWidget);
    expect(find.text('Galpón 1: Newcastle (refuerzo en postura): atrasada'), findsOneWidget);
    expect(find.text('Galpón 5: Peso algo bajo'), findsOneWidget);
    expect(find.text('Debía aplicarse en la semana 30.'), findsOneWidget);
  });

  testWidgets('un aviso se abre y dice qué revisar, con la salvedad del veterinario', (tester) async {
    await abrir(tester, Montaje());

    expect(find.text('Revisar el agua'), findsNothing);
    await tester.tap(find.text('Galpón 5: Peso algo bajo'));
    await tester.pumpAndSettle();

    expect(find.text('Qué revisar'), findsOneWidget);
    expect(find.text('• Revisar el agua'), findsOneWidget);
    expect(find.textContaining('consulta al veterinario'), findsOneWidget);
  });

  testWidgets('cada galpón resume lo atrasado, lo que toca y el peso', (tester) async {
    await abrir(tester, Montaje());

    expect(find.text('1 atrasada'), findsOneWidget);
    expect(find.text('Toca 1'), findsOneWidget);
    expect(find.text('Peso: algo bajo'), findsOneWidget);
    expect(find.text('Hy-Line Brown · 32 semanas · Ponedora'), findsOneWidget);
    expect(find.text('Hy-Line Brown · 12 semanas · Levante'), findsOneWidget);
  });

  testWidgets('sin avisos dice que todo está al día', (tester) async {
    final sinAvisos = {...panorama, 'alertas': <Object?>[]};
    await abrir(tester, Montaje(datos: sinAvisos));

    expect(find.text('Todo al día: no hay avisos'), findsOneWidget);
    expect(find.text('Avisos'), findsNothing);
  });

  testWidgets('el detalle agrupa por estado y deja las aplicadas aparte', (tester) async {
    await abrir(tester, Montaje());
    await abrirGalpon(tester, 'Galpón 1');

    expect(find.text('Atrasadas'), findsOneWidget);
    expect(find.text('Más adelante'), findsOneWidget);
    expect(find.text('Semana 28 a 30'), findsOneWidget);
    expect(find.text('En el agua de bebida.'), findsOneWidget);
    expect(find.text('Ya aplicadas (1)'), findsOneWidget);
    expect(find.text('Postura: 86% · lo esperado es 95%'), findsOneWidget);
    expect(find.text('Todavía no hay pesajes de este lote.'), findsOneWidget);

    await tester.tap(find.text('Ya aplicadas (1)'));
    await tester.pumpAndSettle();
    expect(find.text('2 de marzo'), findsOneWidget);
  });

  testWidgets('marcar una vacuna la manda con el lote, la tarea y la fecha de hoy', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);
    await abrirGalpon(tester, 'Galpón 1');

    await tester.tap(find.text('La apliqué').first);
    await tester.pumpAndSettle();
    expect(find.text('En Galpón 1. ¿Cuándo la aplicaron?'), findsOneWidget);
    await tester.tap(find.text('Ayer'));
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(montaje.peticiones.where((p) => p.startsWith('PUT /lotes/1/cumplimientos/')), hasLength(1));
    expect(montaje.cuerpos.single, {'tarea_id': 10, 'fecha': '2026-10-24'});
    expect(find.text('Anotada: Newcastle (refuerzo en postura)'), findsOneWidget);
  });

  testWidgets('sin señal queda anotada, se ve como aplicada y se envía cuando vuelve', (tester) async {
    var hayRed = true;
    final montaje = Montaje(
      servidor: (p) {
        if (!hayRed) throw http.ClientException('sin red');
        return p.method == 'GET'
            ? http.Response.bytes(utf8.encode(jsonEncode(panorama)), 200)
            : http.Response('{}', 200);
      },
    );
    await abrir(tester, montaje);
    await abrirGalpon(tester, 'Galpón 1');
    hayRed = false;

    await tester.tap(find.text('La apliqué').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Anotada. Se envía cuando haya señal'), findsOneWidget);
    expect(find.text('Atrasadas'), findsNothing);
    expect(find.text('Ya aplicadas (2)'), findsOneWidget);
    final guardada = (await montaje.operaciones.sinResolver()).single;
    expect((guardada.tipo, guardada.loteId, guardada.tareaId), (TipoOperacion.aplicacion, 1, 10));

    hayRed = true;
    await montaje.estado.cargar();
    await tester.pumpAndSettle();

    expect(montaje.peticiones, contains('PUT /lotes/1/cumplimientos/${guardada.id}'));
    expect(await montaje.operaciones.sinResolver(), isEmpty);
  });

  testWidgets('lo sin enviar aparece arriba y se puede revisar', (tester) async {
    final montaje = Montaje(servidor: (_) => throw http.ClientException('sin red'));
    await montaje.almacen.guardar(SanidadGuardada(actualizadoEn: ahora, datos: jsonEncode(panorama)));
    await abrir(tester, montaje);
    final galpon = montaje.estado.panorama!.galpones.first;
    await montaje.estado.marcarAplicada(galpon, galpon.tareas.first, DateTime.utc(2026, 10, 25));
    await tester.pumpAndSettle();

    expect(find.text('Sin señal'), findsOneWidget);
    expect(find.text('1 cosa sin enviar'), findsOneWidget);
    await tester.tap(find.text('1 cosa sin enviar'));
    await tester.pumpAndSettle();
    expect(find.text('Vacuna: Newcastle (refuerzo en postura) en Galpón 1'), findsOneWidget);
  });

  testWidgets('si el servidor rechaza la marca queda a la vista y se puede descartar', (tester) async {
    final montaje = Montaje(
      servidor: (p) => p.method == 'GET'
          ? http.Response.bytes(utf8.encode(jsonEncode(panorama)), 200)
          : http.Response.bytes(
              utf8.encode('{"detail":"Newcastle ya estaba marcada el 2026-10-20"}'),
              409,
              headers: {'content-type': 'application/json'},
            ),
    );
    await abrir(tester, montaje);
    final galpon = montaje.estado.panorama!.galpones.first;
    await montaje.estado.marcarAplicada(galpon, galpon.tareas.first, DateTime.utc(2026, 10, 25));
    await tester.pumpAndSettle();

    expect(find.text('1 no se pudo registrar'), findsOneWidget);
    await tester.tap(find.text('1 no se pudo registrar'));
    await tester.pumpAndSettle();
    expect(find.text('Newcastle ya estaba marcada el 2026-10-20'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(await montaje.operaciones.sinResolver(), isEmpty);
  });

  testWidgets('pesar manda el promedio y las aves pesadas', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);
    await abrirGalpon(tester, 'Galpón 5');
    expect(find.text('940 g'), findsOneWidget);
    expect(find.text('Lo esperado es 1.010 g · pesaron el 23 de octubre'), findsOneWidget);
    expect(find.text('Algo bajo'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Pesé las aves'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Peso promedio'), '1020');
    await tester.pump();
    await tester.tap(find.text('Guardar pesaje'));
    await tester.pumpAndSettle();

    expect(montaje.peticiones.where((p) => p.startsWith('PUT /lotes/5/pesajes/')), hasLength(1));
    expect(montaje.cuerpos.single, {'fecha': '2026-10-25', 'peso_g': 1020, 'aves_pesadas': 30});
    expect(find.text('Pesaje guardado'), findsOneWidget);
  });

  testWidgets('no deja guardar un pesaje vacío', (tester) async {
    await abrir(tester, Montaje());
    await abrirGalpon(tester, 'Galpón 5');
    await tester.tap(find.text('Pesé las aves'));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar pesaje')).onPressed, isNull);
  });

  testWidgets('quitar una marca pide confirmación y la borra en el servidor', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje);
    await abrirGalpon(tester, 'Galpón 1');
    await tester.tap(find.text('Ya aplicadas (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Quitar esta marca?'), findsOneWidget);
    await tester.tap(find.text('Sí, quitar'));
    await tester.pumpAndSettle();

    expect(montaje.peticiones, contains('DELETE /cumplimientos/cumpl-1'));
  });

  testWidgets('quitar una marca sin señal avisa que necesita internet', (tester) async {
    var hayRed = true;
    final montaje = Montaje(
      servidor: (p) {
        if (p.method == 'GET' && hayRed) return http.Response.bytes(utf8.encode(jsonEncode(panorama)), 200);
        throw http.ClientException('sin red');
      },
    );
    await abrir(tester, montaje);
    await abrirGalpon(tester, 'Galpón 1');
    hayRed = false;
    await tester.tap(find.text('Ya aplicadas (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, quitar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('deshacer necesita internet'), findsOneWidget);
  });

  testWidgets('sin señal usa la última copia y lo avisa', (tester) async {
    final montaje = Montaje(servidor: (_) => throw http.ClientException('sin red'));
    await montaje.almacen.guardar(SanidadGuardada(actualizadoEn: ahora, datos: jsonEncode(panorama)));
    await abrir(tester, montaje);

    expect(find.text('Sin señal'), findsOneWidget);
    expect(find.text('Galpón 1'), findsOneWidget);
  });

  testWidgets('sin señal y sin copia explica que no hay datos todavía', (tester) async {
    await abrir(tester, Montaje(servidor: (_) => throw http.ClientException('sin red')));

    expect(find.text('No hay datos todavía'), findsOneWidget);
  });

  testWidgets('sin lotes activos lo dice', (tester) async {
    await abrir(tester, Montaje(datos: {'fecha': '2026-10-25', 'alertas': <Object?>[], 'galpones': <Object?>[]}));

    expect(find.text('No hay galpones con aves'), findsOneWidget);
  });

  testWidgets('con la sesión vencida el estado lo marca', (tester) async {
    final montaje = Montaje(servidor: (_) => http.Response('{}', 401));
    await abrir(tester, montaje);

    expect(montaje.estado.sesionVencida, isTrue);
  });
}
