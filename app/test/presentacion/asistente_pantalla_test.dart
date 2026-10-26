import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/asistente.dart';
import 'package:granja_app/dominio/asistente.dart';
import 'package:granja_app/presentacion/asistente.dart';
import 'package:granja_app/presentacion/estado_asistente.dart';
import 'package:granja_app/presentacion/tema.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final base = Uri.parse('http://granja.test/');

http.Response respuesta(String texto) => http.Response.bytes(
  utf8.encode(jsonEncode({'respuesta': texto})),
  200,
  headers: {'content-type': 'application/json'},
);

class Montaje {
  Montaje({http.Response Function(http.Request)? servidor}) {
    final cliente = MockClient((peticion) async {
      cuerpos.add(jsonDecode(peticion.body) as Map<String, dynamic>);
      if (servidor != null) return servidor(peticion);
      return respuesta('Puede ser falta de calcio. Revisa el alimento y el agua.');
    });
    estado = EstadoAsistente(RepositorioAsistente(ApiGranja(base, cliente: cliente)));
  }

  final cuerpos = <Map<String, dynamic>>[];
  late final EstadoAsistente estado;

  Widget app({String? pregunta, Future<Foto?> Function()? elegirFoto}) => MaterialApp(
    theme: temaGranja(),
    home: AsistentePantalla(estado: estado, pregunta: pregunta, elegirFoto: elegirFoto),
  );
}

Future<void> abrir(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin conversación muestra preguntas sugeridas y la advertencia del veterinario', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje.app());

    expect(find.text('Asistente de las aves'), findsOneWidget);
    expect(find.textContaining('No reemplaza al veterinario'), findsOneWidget);
    for (final p in preguntasSugeridas) {
      expect(find.text(p), findsOneWidget);
    }
    expect(find.byTooltip('Nueva conversación'), findsNothing);
  });

  testWidgets('una pregunta sugerida se envía y aparece la respuesta', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje.app());

    await tester.tap(find.text(preguntasSugeridas.first));
    await tester.pumpAndSettle();

    expect(find.text(preguntasSugeridas.first), findsOneWidget);
    expect(find.text('Puede ser falta de calcio. Revisa el alimento y el agua.'), findsOneWidget);
    expect(montaje.cuerpos.single, {
      'mensajes': [
        {'rol': 'usuario', 'texto': preguntasSugeridas.first},
      ],
      'imagen': null,
    });
  });

  testWidgets('la conversación se manda entera para que el asistente tenga el hilo', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje.app());

    await tester.enterText(find.byType(TextField), 'Una gallina cojea');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tiene la pata hinchada');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    final mensajes = montaje.cuerpos.last['mensajes'] as List<dynamic>;
    expect([for (final m in mensajes) (m as Map)['rol']], ['usuario', 'asistente', 'usuario']);
    expect((mensajes.last as Map)['texto'], 'Tiene la pata hinchada');
  });

  testWidgets('la pregunta que viene de un aviso ya está escrita', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje.app(pregunta: 'En el Galpón 1: Baja postura. ¿Qué hago?'));

    expect(find.text('En el Galpón 1: Baja postura. ¿Qué hago?'), findsOneWidget);
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();
    expect((montaje.cuerpos.single['mensajes'] as List).single, {
      'rol': 'usuario',
      'texto': 'En el Galpón 1: Baja postura. ¿Qué hago?',
    });
  });

  testWidgets('la foto se adjunta, se puede quitar y se manda en base64 una sola vez', (tester) async {
    final montaje = Montaje();
    const foto = Foto(bytes: [1, 2, 3], tipo: 'image/png');
    await abrir(tester, montaje.app(elegirFoto: () async => foto));

    await tester.tap(find.byTooltip('Agregar una foto'));
    await tester.pumpAndSettle();
    expect(find.text('Foto lista para enviar'), findsOneWidget);
    await tester.tap(find.byTooltip('Quitar la foto'));
    await tester.pumpAndSettle();
    expect(find.text('Foto lista para enviar'), findsNothing);

    await tester.tap(find.byTooltip('Agregar una foto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '¿Qué tiene en el ojo?');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(montaje.cuerpos.single['imagen'], {
      'tipo': 'image/png',
      'datos_base64': base64Encode([1, 2, 3]),
    });
    expect(find.text('Con foto'), findsOneWidget);
    expect(find.text('Foto lista para enviar'), findsNothing);

    await tester.enterText(find.byType(TextField), '¿Y si se le cierra?');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();
    expect(montaje.cuerpos.last['imagen'], isNull);
  });

  testWidgets('sin poder elegir fotos no aparece el botón de foto', (tester) async {
    await abrir(tester, Montaje().app());

    expect(find.byTooltip('Agregar una foto'), findsNothing);
  });

  testWidgets('no manda preguntas vacías', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje.app());

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(montaje.cuerpos, isEmpty);
  });

  testWidgets('sin señal lo dice y deja intentar de nuevo con la misma pregunta', (tester) async {
    var hayRed = false;
    final montaje = Montaje(
      servidor: (_) {
        if (!hayRed) throw http.ClientException('sin red');
        return respuesta('Separa el ave enferma.');
      },
    );
    await abrir(tester, montaje.app());

    await tester.enterText(find.byType(TextField), 'Una gallina estornuda');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();
    expect(find.text('Sin señal: el asistente necesita internet.'), findsOneWidget);
    expect(find.text('Una gallina estornuda'), findsOneWidget);

    hayRed = true;
    await tester.tap(find.text('Intentar de nuevo'));
    await tester.pumpAndSettle();

    expect(find.text('Separa el ave enferma.'), findsOneWidget);
    expect(find.text('Sin señal: el asistente necesita internet.'), findsNothing);
    expect((montaje.cuerpos.last['mensajes'] as List), hasLength(1));
  });

  testWidgets('si el servidor no tiene el asistente configurado muestra el motivo', (tester) async {
    final montaje = Montaje(
      servidor: (_) => http.Response.bytes(
        utf8.encode(jsonEncode({'detail': 'el asistente no está configurado en el servidor'})),
        503,
        headers: {'content-type': 'application/json'},
      ),
    );
    await abrir(tester, montaje.app());

    await tester.enterText(find.byType(TextField), 'Hola');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('El asistente no está configurado en el servidor.'), findsOneWidget);
  });

  testWidgets('una conversación nueva borra lo anterior', (tester) async {
    final montaje = Montaje();
    await abrir(tester, montaje.app());

    await tester.tap(find.text(preguntasSugeridas[1]));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nueva conversación'));
    await tester.pumpAndSettle();

    expect(montaje.estado.vacio, isTrue);
    expect(find.text(preguntasSugeridas[0]), findsOneWidget);
  });

  testWidgets('con la sesión vencida el estado lo marca', (tester) async {
    final montaje = Montaje(servidor: (_) => http.Response('{}', 401));
    await abrir(tester, montaje.app());

    await tester.enterText(find.byType(TextField), 'Hola');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(montaje.estado.sesionVencida, isTrue);
  });

  test('el tipo de la foto sale de la extensión', () {
    expect(tipoDeFoto('IMG_001.PNG'), 'image/png');
    expect(tipoDeFoto('foto.webp'), 'image/webp');
    expect(tipoDeFoto('foto.jpeg'), 'image/jpeg');
    expect(tipoDeFoto('sin_extension'), 'image/jpeg');
  });
}
