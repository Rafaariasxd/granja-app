import 'package:flutter/material.dart';

import 'datos/almacen_sesion_segura.dart';
import 'datos/api_granja.dart';
import 'datos/servicio_sesion.dart';
import 'presentacion/estado_sesion.dart';
import 'presentacion/inicio.dart';
import 'presentacion/puerta_de_sesion.dart';
import 'presentacion/tema.dart';

const _urlApi = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiGranja(Uri.parse(_urlApi));
  final estado = EstadoSesion(ServicioSesion(api, AlmacenSesionSegura()))..iniciar();
  runApp(GranjaApp(estado: estado));
}

class GranjaApp extends StatelessWidget {
  const GranjaApp({super.key, required this.estado});

  final EstadoSesion estado;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Granja App',
      theme: temaGranja(),
      home: PuertaDeSesion(estado: estado, constructor: (_) => const InicioPantalla()),
    );
  }
}
