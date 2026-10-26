import 'package:flutter/foundation.dart';

import '../datos/api_granja.dart';
import '../datos/bodega.dart';
import '../datos/cola.dart';
import '../datos/operaciones.dart';
import '../dominio/inventario.dart';
import '../dominio/modelos.dart';
import 'formato.dart';

class EstadoBodega extends ChangeNotifier {
  EstadoBodega(this._repositorio, {DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now;

  final RepositorioBodega _repositorio;
  final DateTime Function() _reloj;

  BodegaActual? _datos;
  List<OperacionBodega> _sinResolver = const [];
  bool _cargando = false;
  bool _otraVuelta = false;
  bool _sesionVencida = false;

  bool get cargando => _cargando;
  bool get sesionVencida => _sesionVencida;
  bool get sinSenal => _datos?.copiaLocal ?? false;
  Inventario? get inventario => _datos?.inventario;
  List<OperacionBodega> get sinResolver => _sinResolver;
  int get porEnviar => _sinResolver.where((o) => o.estado == EstadoEnvio.pendiente).length;
  int get noRegistradas => _sinResolver.where((o) => o.estado != EstadoEnvio.pendiente).length;

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
        _datos = await _repositorio.inventario(_reloj()) ?? _datos;
      } while (_otraVuelta);
    } on SesionVencida {
      _sesionVencida = true;
    } finally {
      _sinResolver = await _repositorio.sinResolver();
      _cargando = false;
      notifyListeners();
    }
  }

  Future<String?> registrarCompra(Insumo insumo, int bodegaId, double bultos) => _guardar(
    () => _repositorio.guardarCompra(insumo, bodegaId, bultos, '${bultosTexto(bultos)} de ${insumo.nombre}', _reloj()),
  );

  Future<String?> prepararAlimento(MezclaPosible mezcla, int haciaBodegaId, double kg) => _guardar(
    () => _repositorio.guardarPreparacion(mezcla, haciaBodegaId, kg, '${kilos(kg)} de ${mezcla.producto}', _reloj()),
  );

  Future<String?> registrarGasto(Insumo insumo, int bodegaId, Cantidad cantidad) => _guardar(
    () => _repositorio.guardarGasto(insumo, bodegaId, cantidad, '${_texto(cantidad)} de ${insumo.nombre}', _reloj()),
  );

  Future<String?> contar(Insumo insumo, int bodegaId, Cantidad cantidad) async {
    try {
      await _repositorio.contar(insumo, bodegaId, cantidad);
    } on SinConexion {
      return 'Sin señal: contar necesita internet. Prueba de nuevo cuando haya señal.';
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

  double? kgPorBultoDelGalpon(int galponId, Etapa? etapa) => inventario?.kgPorBultoDelGalpon(galponId, etapa);

  String _texto(Cantidad cantidad) => cantidad.enBultos ? bultosTexto(cantidad.valor) : kilos(cantidad.valor);

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
