import 'package:flutter/foundation.dart';

import '../datos/api_granja.dart';
import '../datos/cola.dart';
import '../datos/operaciones.dart';
import '../datos/sanidad.dart';
import '../dominio/fechas.dart';
import '../dominio/sanidad.dart';

class EstadoSanidad extends ChangeNotifier {
  EstadoSanidad(this._repositorio, {DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now;

  final RepositorioSanidad _repositorio;
  final DateTime Function() _reloj;

  SanidadActual? _datos;
  List<OperacionBodega> _sinResolver = const [];
  bool _cargando = false;
  bool _otraVuelta = false;
  bool _sesionVencida = false;

  bool get cargando => _cargando;
  bool get sesionVencida => _sesionVencida;
  bool get sinSenal => _datos?.copiaLocal ?? false;
  DateTime get hoy => fechaEnGranja(_reloj());
  List<OperacionBodega> get sinResolver => _sinResolver;
  int get porEnviar => _sinResolver.where((o) => o.estado == EstadoEnvio.pendiente).length;
  int get noRegistradas => _sinResolver.where((o) => o.estado != EstadoEnvio.pendiente).length;

  PanoramaSanidad? get panorama {
    final base = _datos?.panorama;
    if (base == null) return null;
    final pendientes = _sinResolver.where(
      (o) => o.tipo == TipoOperacion.aplicacion && o.estado == EstadoEnvio.pendiente,
    );
    if (pendientes.isEmpty) return base;
    return PanoramaSanidad(
      fecha: base.fecha,
      alertas: base.alertas,
      galpones: [
        for (final g in base.galpones)
          GalponSanidad(
            galponId: g.galponId,
            galpon: g.galpon,
            loteId: g.loteId,
            linea: g.linea,
            edadSemanas: g.edadSemanas,
            etapa: g.etapa,
            avesVivas: g.avesVivas,
            pesajes: g.pesajes,
            peso: g.peso,
            postura: g.postura,
            tareas: [
              for (final t in g.tareas)
                () {
                  final op = pendientes.where((o) => o.loteId == g.loteId && o.tareaId == t.tareaId).firstOrNull;
                  return op == null ? t : t.comoAplicada(op.fecha);
                }(),
            ],
          ),
      ],
    );
  }

  Future<void> cargar() async {
    if (_cargando) {
      _otraVuelta = true;
      return;
    }
    _cargando = true;
    _sesionVencida = false;
    notifyListeners();
    try {
      do {
        _otraVuelta = false;
        await _repositorio.enviarOperaciones();
        _datos = await _repositorio.panorama(_reloj()) ?? _datos;
      } while (_otraVuelta);
    } on SesionVencida {
      _sesionVencida = true;
    } finally {
      _sinResolver = await _repositorio.sinResolver();
      _cargando = false;
      notifyListeners();
    }
  }

  Future<String?> marcarAplicada(GalponSanidad galpon, TareaSanitaria tarea, DateTime fecha) =>
      _guardar(() => _repositorio.guardarAplicacion(galpon, tarea, fecha, _reloj()));

  Future<String?> pesar(GalponSanidad galpon, double pesoG, int aves) =>
      _guardar(() => _repositorio.guardarPesaje(galpon, pesoG, aves, _reloj()));

  Future<String?> deshacer(TareaSanitaria tarea) async {
    final id = tarea.cumplimientoId;
    if (id == null) return null;
    try {
      await _repositorio.deshacerAplicacion(id);
    } on SinConexion {
      return 'Sin señal: deshacer necesita internet. Prueba de nuevo cuando haya señal.';
    } on SesionVencida {
      _sesionVencida = true;
      notifyListeners();
      return 'La sesión se cerró, vuelve a entrar.';
    } on ErrorDeApi catch (error) {
      return error.mensaje;
    }
    await cargar();
    return null;
  }

  Future<void> descartar(String id) async {
    await _repositorio.descartar(id);
    _sinResolver = await _repositorio.sinResolver();
    notifyListeners();
  }

  Future<String?> _guardar(Future<void> Function() guardar) async {
    try {
      await guardar();
    } on Object {
      return 'No se pudo guardar en el teléfono. Inténtalo de nuevo.';
    }
    await cargar();
    return null;
  }
}
