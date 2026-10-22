import 'package:flutter/material.dart';

import '../dominio/fechas.dart';
import 'fecha_texto.dart';

class InicioPantalla extends StatelessWidget {
  const InicioPantalla({super.key, this.ahora});

  final DateTime? ahora;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final hoy = fechaEnGranja(ahora ?? DateTime.now());
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
          children: [
            Text(
              fechaLarga(hoy),
              style: textos.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text('Hoy en la granja', style: textos.headlineMedium),
          ],
        ),
      ),
    );
  }
}
