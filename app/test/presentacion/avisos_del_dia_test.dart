import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/dominio/huevos.dart';
import 'package:granja_app/dominio/inventario.dart';
import 'package:granja_app/dominio/sanidad.dart';
import 'package:granja_app/presentacion/avisos_del_dia.dart';
import 'package:granja_app/presentacion/cascaron.dart';
import 'package:granja_app/presentacion/tema.dart';

AlertaSanidad alerta(NivelAlerta nivel) =>
    AlertaSanidad(galponId: 1, galpon: 'Galpón 1', loteId: 1, tipo: 'x', nivel: nivel, titulo: 't', detalle: 'd');

final sanidad = PanoramaSanidad(
  fecha: DateTime.utc(2026, 10, 26),
  alertas: [
    alerta(NivelAlerta.urgente),
    alerta(NivelAlerta.urgente),
    alerta(NivelAlerta.revisar),
    alerta(NivelAlerta.info),
  ],
  galpones: const [],
);

const soya = Insumo(id: 2, nombre: 'Soya', tipo: TipoInsumo.materiaPrima, kgPorBulto: 40);

const inventario = Inventario(
  bodegas: [
    InventarioBodega(
      bodega: Bodega(id: 3, nombre: 'Materia prima', tipo: TipoBodega.materiaPrima),
      galponIds: [],
      existencias: [Existencia(insumo: soya, stockKg: 40, nivel: Nivel.critico)],
      etapas: [],
    ),
  ],
  mezclas: [],
);

final huevo = BodegaHuevo(
  existencias: const [],
  precios: const [],
  abiertas: [SalidaHuevo(id: 's', fecha: DateTime.utc(2026, 10, 25), tipoVenta: TipoVenta.cliente, lineas: const [])],
);

List<AvisoDelDia> todos() => avisosDelDia(
  sanidad: sanidad,
  inventario: inventario,
  huevo: huevo,
  pestanaBodega: 1,
  pestanaSanidad: 2,
  pestanaDinero: 3,
);

void main() {
  test('junta lo urgente y lo que hay que revisar de cada parte de la granja', () {
    expect(
      [for (final a in todos()) (a.texto, a.pestana)],
      [
        ('2 avisos urgentes de sanidad', 2),
        ('1 cosa por revisar en sanidad', 2),
        ('Se acaba en la bodega: Soya', 1),
        ('1 salida de huevo por cerrar', 3),
      ],
    );
  });

  test('sin datos o sin novedades no hay avisos', () {
    expect(avisosDelDia(pestanaBodega: 1, pestanaSanidad: 2, pestanaDinero: 3), isEmpty);
  });

  testWidgets('tocar un aviso abre su pestaña', (tester) async {
    final abiertas = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: temaGranja(),
        home: Scaffold(
          body: TarjetaAvisosDelDia(avisos: todos(), alAbrir: abiertas.add),
        ),
      ),
    );

    expect(find.text('Para hoy'), findsOneWidget);
    await tester.tap(find.text('Se acaba en la bodega: Soya'));
    await tester.tap(find.text('1 salida de huevo por cerrar'));
    expect(abiertas, [1, 3]);
  });

  testWidgets('sin avisos la tarjeta no aparece', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TarjetaAvisosDelDia(avisos: const [], alAbrir: (_) {}),
        ),
      ),
    );

    expect(find.text('Para hoy'), findsNothing);
  });

  testWidgets('el cascarón cambia de pestaña cuando se le pide y avisa cuando se toca', (tester) async {
    final pestana = ValueNotifier<int>(0);
    var sanidadAbierta = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaGranja(),
        home: Cascaron(
          pestana: pestana,
          granja: const Text('pantalla granja'),
          bodega: const Text('pantalla bodega'),
          sanidad: const Text('pantalla sanidad'),
          dinero: const Text('pantalla dinero'),
          alAbrirSanidad: () => sanidadAbierta++,
        ),
      ),
    );

    pestana.value = 2;
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
    expect(sanidadAbierta, 1);

    await tester.tap(find.text('Granja'));
    await tester.pumpAndSettle();
    expect(pestana.value, 0);

    pestana.value = 2;
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
    expect(sanidadAbierta, 2);
  });
}
