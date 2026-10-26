import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as ruta;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'datos/administracion.dart';
import 'datos/almacen_sesion_segura.dart';
import 'datos/asistente.dart';
import 'datos/almacen_sqlite.dart';
import 'datos/api_granja.dart';
import 'datos/base_local.dart';
import 'datos/bodega.dart';
import 'datos/finanzas.dart';
import 'datos/huevos.dart';
import 'datos/buscador_registro.dart';
import 'datos/resumen.dart';
import 'datos/sanidad.dart';
import 'datos/servicio_sesion.dart';
import 'datos/sincronizador.dart';
import 'dominio/asistente.dart';
import 'dominio/modelos.dart';
import 'presentacion/administrar.dart';
import 'presentacion/al_reanudar.dart';
import 'presentacion/asistente.dart';
import 'presentacion/bodega.dart';
import 'presentacion/cascaron.dart';
import 'presentacion/estado_administracion.dart';
import 'presentacion/estado_asistente.dart';
import 'presentacion/estado_bodega.dart';
import 'presentacion/dinero.dart';
import 'presentacion/estado_envios.dart';
import 'presentacion/estado_finanzas.dart';
import 'presentacion/estado_huevos.dart';
import 'presentacion/huevo.dart';
import 'presentacion/seccion_dinero.dart';
import 'presentacion/estado_inicio.dart';
import 'presentacion/estado_sanidad.dart';
import 'presentacion/estado_sesion.dart';
import 'presentacion/formulario_registro.dart';
import 'presentacion/inicio.dart';
import 'presentacion/puerta_de_sesion.dart';
import 'presentacion/registro.dart';
import 'presentacion/sanidad.dart';
import 'presentacion/tema.dart';
import 'presentacion/hoja.dart';

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
  final bodega = EstadoBodega(RepositorioBodega(api, AlmacenBodegaSqlite(base), AlmacenOperacionesSqlite(base)));
  final sanidad = EstadoSanidad(RepositorioSanidad(api, AlmacenSanidadSqlite(base), AlmacenOperacionesSqlite(base)));
  final dinero = EstadoFinanzas(RepositorioFinanzas(api, AlmacenFinanzasSqlite(base), AlmacenOperacionesSqlite(base)));
  final huevos = EstadoHuevos(RepositorioHuevos(api, AlmacenHuevosSqlite(base), AlmacenOperacionesSqlite(base)));
  final asistente = EstadoAsistente(RepositorioAsistente(api));
  final administracion = EstadoAdministracion(RepositorioAdministracion(api));
  sesion
    ..vigilar(envios, () => envios.sesionVencida)
    ..vigilar(inicio, () => inicio.sesionVencida)
    ..vigilar(bodega, () => bodega.sesionVencida)
    ..vigilar(sanidad, () => sanidad.sesionVencida)
    ..vigilar(dinero, () => dinero.sesionVencida)
    ..vigilar(huevos, () => huevos.sesionVencida)
    ..vigilar(asistente, () => asistente.sesionVencida)
    ..vigilar(administracion, () => administracion.sesionVencida);
  runApp(
    GranjaApp(
      sesion: sesion,
      envios: envios,
      inicio: inicio,
      bodega: bodega,
      sanidad: sanidad,
      dinero: dinero,
      huevos: huevos,
      asistente: asistente,
      administracion: administracion,
      api: api,
      buscador: BuscadorRegistro(api, almacen),
    ),
  );
}

class GranjaApp extends StatelessWidget {
  const GranjaApp({
    super.key,
    required this.sesion,
    required this.envios,
    required this.inicio,
    required this.bodega,
    required this.sanidad,
    required this.dinero,
    required this.huevos,
    required this.asistente,
    required this.administracion,
    required this.api,
    required this.buscador,
  });

  final EstadoSesion sesion;
  final EstadoEnvios envios;
  final EstadoInicio inicio;
  final EstadoBodega bodega;
  final EstadoSanidad sanidad;
  final EstadoFinanzas dinero;
  final EstadoHuevos huevos;
  final EstadoAsistente asistente;
  final EstadoAdministracion administracion;
  final ApiGranja api;
  final BuscadorRegistro buscador;

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
            sanidad.cargar();
            dinero.cargar();
            huevos.cargar();
            if (sesion.sesion?.esAdministrador ?? false) administracion.cargar();
          },
          child: Cascaron(
            alAbrirBodega: bodega.cargar,
            alAbrirSanidad: sanidad.cargar,
            alAbrirDinero: () {
              huevos.cargar();
              dinero.cargar();
            },
            granja: InicioPantalla(
              estado: inicio,
              envios: envios,
              nombreUsuario: sesion.sesion?.nombre,
              alSalir: sesion.salir,
              alRegistrar: (galpon) => _registrar(contexto, galpon),
              alCorregir: (galpon) => _corregir(contexto, galpon),
            ),
            bodega: BodegaPantalla(estado: bodega),
            sanidad: SanidadPantalla(estado: sanidad, alPreguntar: (pregunta) => _preguntar(contexto, pregunta)),
            dinero: SeccionDinero(
              huevo: HuevoPantalla(estado: huevos),
              cuentas: DineroPantalla(estado: dinero, esAdministrador: sesion.sesion?.esAdministrador ?? false),
              alCambiar: (_) => dinero.cargar(),
            ),
            administrar: (sesion.sesion?.esAdministrador ?? false) ? AdministrarPantalla(estado: administracion) : null,
            alAbrirAdministrar: administracion.cargar,
          ),
        ),
      ),
    );
  }

  Future<void> _preguntar(BuildContext context, String? pregunta) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (contexto) =>
          AsistentePantalla(estado: asistente, pregunta: pregunta, elegirFoto: () => _elegirFoto(contexto)),
    ),
  );

  Future<Foto?> _elegirFoto(BuildContext context) async {
    final selector = ImagePicker();
    var fuente = ImageSource.gallery;
    if (selector.supportsImageSource(ImageSource.camera)) {
      final elegida = await abrirHoja<ImageSource>(
        context: context,
        builder: (contexto) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tomar una foto', style: TextStyle(fontSize: 18)),
                onTap: () => Navigator.of(contexto).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de la galería', style: TextStyle(fontSize: 18)),
                onTap: () => Navigator.of(contexto).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (elegida == null) return null;
      fuente = elegida;
    }
    final archivo = await selector.pickImage(source: fuente, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
    if (archivo == null) return null;
    return Foto(bytes: await archivo.readAsBytes(), tipo: tipoDeFoto(archivo.name));
  }

  Future<void> _registrar(BuildContext context, ResumenGalpon galpon) async {
    final formulario = FormularioRegistro(
      galpon: galpon,
      fecha: inicio.hoy,
      kgPorBulto: bodega.kgPorBultoDelGalpon(galpon.galponId, galpon.etapa),
    );
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegistroPantalla(formulario: formulario, envios: envios),
      ),
    );
    if (guardado == true) await inicio.cargar();
  }

  Future<void> _corregir(BuildContext context, ResumenGalpon galpon) async {
    RegistroEncontrado? encontrado;
    String? problema;
    try {
      encontrado = await buscador.buscar(galpon.galponId, inicio.hoy);
    } on SinConexion {
      problema = 'Sin señal: para corregir un registro que ya se envió hace falta internet.';
    } on ErrorDeApi catch (error) {
      problema = error.mensaje;
    }
    if (!context.mounted) return;
    if (encontrado == null) {
      _avisar(context, problema ?? 'No se encontró el registro de hoy de ${galpon.nombre}.');
      return;
    }
    final hallado = encontrado;
    final puedeBorrar = (sesion.sesion?.esAdministrador ?? false) && !hallado.sinEnviar;
    final formulario = FormularioRegistro(
      galpon: galpon,
      fecha: inicio.hoy,
      anterior: hallado.registro,
      kgPorBulto: bodega.kgPorBultoDelGalpon(galpon.galponId, galpon.etapa),
    );
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegistroPantalla(
          formulario: formulario,
          envios: envios,
          corrigiendo: true,
          alBorrar: puedeBorrar ? () => _borrar(hallado.registro.id) : null,
        ),
      ),
    );
    if (guardado == true) await inicio.cargar();
  }

  Future<String?> _borrar(String id) async {
    try {
      await api.borrarRegistro(id);
    } on SinConexion {
      return 'Sin señal: borrar necesita internet.';
    } on SesionVencida {
      unawaited(sesion.sesionVencida());
      return 'La sesión se cerró, vuelve a entrar.';
    } on ErrorDeApi catch (error) {
      return error.mensaje;
    }
    return null;
  }

  void _avisar(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }
}
