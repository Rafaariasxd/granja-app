import 'package:flutter/foundation.dart';

import '../datos/api_granja.dart';
import '../datos/cola.dart';
import '../datos/finanzas.dart';
import '../datos/operaciones.dart';
import '../dominio/fechas.dart';
import '../dominio/finanzas.dart';

class EstadoFinanzas extends ChangeNotifier {
  EstadoFinanzas(this._repositorio, {DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now {
    _mes = primerDiaDelMes(fechaEnGranja(_reloj()));
  }

  final RepositorioFinanzas _repositorio;
  final DateTime Function() _reloj;

  late DateTime _mes;
  FinanzasActuales? _datos;
  List<OperacionBodega> _sinResolver = const [];
  bool _cargando = false;
  bool _otraVuelta = false;
  bool _sesionVencida = false;

  DateTime get mes => _mes;
  bool get esMesActual => _mes == primerDiaDelMes(fechaEnGranja(_reloj()));
  bool get cargando => _cargando;
  bool get sesionVencida => _sesionVencida;
  bool get sinSenal => _datos?.copiaLocal ?? false;
  PanoramaDinero? get panorama => _datos?.panorama;
  List<OperacionBodega> get sinResolver => _sinResolver;
  int get porEnviar => _sinResolver.where((o) => o.estado == EstadoEnvio.pendiente).length;
  int get noRegistradas => _sinResolver.where((o) => o.estado != EstadoEnvio.pendiente).length;

  Future<void> irAlMes(DateTime mes) async {
    _mes = primerDiaDelMes(mes);
    _datos = null;
    notifyListeners();
    await cargar();
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
        final nuevos = await _repositorio.panorama(_mes, _reloj());
        if (nuevos != null && (nuevos.copiaLocal ? nuevos.panorama.mes == _mes : true)) _datos = nuevos;
      } while (_otraVuelta);
    } on SesionVencida {
      _sesionVencida = true;
    } finally {
      _sinResolver = await _repositorio.sinResolver();
      _cargando = false;
      notifyListeners();
    }
  }

  Future<String?> venderHuevos({
    required CategoriaHuevo categoria,
    required int huevos,
    required double valor,
    String cliente = '',
  }) => _guardar(
    rubro: Rubro.ventaHuevo,
    valor: valor,
    descripcion: '$huevos huevos ${categoria.nombre}',
    categoriaId: categoria.id,
    huevos: huevos,
    cliente: cliente,
  );

  Future<String?> venderGallinas({required int gallinas, required double valor, int? loteId, String cliente = ''}) =>
      _guardar(
        rubro: Rubro.ventaGallinas,
        valor: valor,
        descripcion: '$gallinas gallinas',
        nota: '$gallinas gallinas',
        loteId: loteId,
        cliente: cliente,
      );

  Future<String?> gastar({required Rubro rubro, required double valor, String nota = '', int? loteId}) => _guardar(
    rubro: rubro,
    valor: valor,
    descripcion: nota.isEmpty ? rubro.nombre : '${rubro.nombre}: $nota',
    nota: nota,
    loteId: loteId,
  );

  Future<String?> borrar(MovimientoDinero movimiento) async {
    try {
      await _repositorio.borrar(movimiento.id);
    } on SinConexion {
      return 'Sin señal: borrar necesita internet.';
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

  Future<String?> _guardar({
    required Rubro rubro,
    required double valor,
    required String descripcion,
    String nota = '',
    int? loteId,
    int? categoriaId,
    int? huevos,
    String cliente = '',
  }) async {
    try {
      await _repositorio.guardarMovimiento(
        rubro: rubro,
        valor: valor,
        ahora: _reloj(),
        descripcion: descripcion,
        nota: nota,
        loteId: loteId,
        categoriaId: categoriaId,
        huevos: huevos,
        contraparte: cliente,
      );
    } on Object {
      return 'No se pudo guardar en el teléfono. Inténtalo de nuevo.';
    }
    await cargar();
    return null;
  }
}
