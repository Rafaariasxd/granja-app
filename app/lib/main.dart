import 'package:flutter/material.dart';

import 'presentacion/inicio.dart';
import 'presentacion/tema.dart';

void main() => runApp(const GranjaApp());

class GranjaApp extends StatelessWidget {
  const GranjaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Granja App', theme: temaGranja(), home: const InicioPantalla());
  }
}
