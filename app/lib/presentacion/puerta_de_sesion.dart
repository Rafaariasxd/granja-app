import 'package:flutter/material.dart';

import 'entrada.dart';
import 'estado_sesion.dart';

class PuertaDeSesion extends StatelessWidget {
  const PuertaDeSesion({super.key, required this.estado, required this.constructor});

  final EstadoSesion estado;
  final WidgetBuilder constructor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) {
        if (estado.cargando) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (estado.sesion == null) return EntradaPantalla(estado: estado);
        return constructor(context);
      },
    );
  }
}
