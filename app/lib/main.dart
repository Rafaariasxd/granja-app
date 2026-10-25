import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as ruta;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'datos/almacen_sesion_segura.dart';
import 'datos/almacen_sqlite.dart';
import 'datos/api_granja.dart';
import 'datos/base_local.dart';
import 'datos/bodega.dart';
import 'datos/resumen.dart';
import 'datos/servicio_sesion.dart';
import 'datos/sincronizador.dart';
import 'dominio/modelos.dart';
import 'presentacion/al_reanudar.dart';
import 'presentacion/bodega.dart';
import 'presentacion/cascaron.dart';
import 'presentacion/estado_bodega.dart';
import 'presentacion/estado_envios.dart';
import 'presentacion/estado_inicio.dart';
import 'presentacion/estado_sesion.dart';
import 'presentacion/formulario_registro.dart';
import 'presentacion/inicio.dart';
import 'presentacion/puerta_de_sesion.dart';
import 'presentacion/registro.dart';
import 'presentacion/tema.dart';

const _urlApi = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final base = await abrirBaseLocal(databaseFactory, ruta.join(await getDatabasesPath(), 'granja.db'));
  final api = ApiGranja(Uri.parse(_urlApi));
  final almacen = AlmacenSqlite(base);
  final sesion = EstadoSesion(ServicioSesion(api, AlmacenSesionSegura()))..iniciar();
  final envios = EstadoEnvios(Sincronizador(almacen, api), almacen);
  final inicio = EstadoInicio(RepositorioResumen(api, AlmacenResumenSqlite(base)));
  final bodega = EstadoBodega(RepositorioBodega(api, AlmacenBodegaSqlite(base)));
  void cerrarSiVencio() {
    if ((envios.sesionVencida || inicio.sesionVencida || bodega.sesionVencida) && sesion.sesion != null)
      sesion.sesionVencida();
  }

  envios.addListener(cerrarSiVencio);
  inicio.addListener(cerrarSiVencio);
  bodega.addListener(cerrarSiVencio);
  runApp(GranjaApp(sesion: sesion, envios: envios, inicio: inicio, bodega: bodega));
}

class GranjaApp extends StatelessWidget {
  const GranjaApp({super.key, required this.sesion, required this.envios, required this.inicio, required this.bodega});

  final EstadoSesion sesion;
  final EstadoEnvios envios;
  final EstadoInicio inicio;
  final EstadoBodega bodega;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Granja App',
      theme: temaGranja(),
      home: PuertaDeSesion(
        estado: sesion,
        constructor: (contexto) => AlReanudar(
          alVolver: () {
            envios.enviar();
            inicio.cargar();
            bodega.cargar();
          },
          child: Cascaron(
            alAbrirBodega: bodega.cargar,
            granja: InicioPantalla(
              estado: inicio,
              envios: envios,
              nombreUsuario: sesion.sesion?.nombre,
              alSalir: sesion.salir,
              alRegistrar: (galpon) => _registrar(contexto, galpon),
            ),
            bodega: BodegaPantalla(estado: bodega),
          ),
        ),
      ),
    );
  }

  Future<void> _registrar(BuildContext context, ResumenGalpon galpon) async {
    final formulario = FormularioRegistro(galpon: galpon, fecha: inicio.hoy);
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegistroPantalla(formulario: formulario, envios: envios),
      ),
    );
    if (guardado == true) await inicio.cargar();
  }
}
