import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/presentacion/inicio.dart';
import 'package:granja_app/presentacion/tema.dart';

void main() {
  testWidgets('el inicio muestra el día de la granja', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: temaGranja(),
        home: InicioPantalla(ahora: DateTime.utc(2026, 10, 22, 1, 30)),
      ),
    );
    expect(find.text('Hoy en la granja'), findsOneWidget);
    expect(find.text('Miércoles 21 de octubre'), findsOneWidget);
  });
}
