import 'package:flutter/foundation.dart';

import '../datos/administracion.dart';
import '../datos/api_granja.dart';
import '../dominio/administracion.dart';
import '../dominio/inventario.dart';
import '../dominio/modelos.dart';

class EstadoAdministracion extends ChangeNotifier {
  EstadoAdministracion(this._repositorio);

  final RepositorioAdministracion _repositorio;

  Catalogo? _catalogo;
  bool _cargando = false;
  bool _sesionVencida = false;
  String? _problema;

  Catalogo? get catalogo => _catalogo;
  bool get cargando => _cargando;
  bool get sesionVencida => _sesionVencida;
  String? get problema => _problema;

  Future<void> cargar() async {
    if (_cargando) return;
    _cargando = true;
    _sesionVencida = false;
    _problema = null;
    notifyListeners();
    try {
      _catalogo = await _repositorio.catalogo();
    } on SesionVencida {
      _sesionVencida = true;
    } on SinConexion {
      _problema = 'Sin señal: administrar necesita internet.';
    } on ErrorDeApi catch (error) {
      _problema = error.mensaje;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<List<IngredienteFormula>?> formula(int productoId) async {
    try {
      return await _repositorio.formula(productoId);
    } on ErrorDeApi {
      return null;
    }
  }

  Future<String?> crearBodega(String nombre, TipoBodega tipo) => _accion(() => _repositorio.crearBodega(nombre, tipo));

  Future<String?> asignarGalpones(int bodegaId, List<int> galponIds) =>
      _accion(() => _repositorio.asignarGalpones(bodegaId, galponIds));

  Future<String?> crearInsumo({required String nombre, required TipoInsumo tipo, Etapa? etapa, double? kgPorBulto}) =>
      _accion(() => _repositorio.crearInsumo(nombre: nombre, tipo: tipo, etapa: etapa, kgPorBulto: kgPorBulto));

  Future<String?> definirFormula(int productoId, List<IngredienteFormula> ingredientes) =>
      _accion(() => _repositorio.definirFormula(productoId, ingredientes));

  Future<String?> ponerEnUso(int bodegaId, Etapa etapa, int insumoId) =>
      _accion(() => _repositorio.ponerEnUso(bodegaId, etapa, insumoId));

  Future<String?> _accion(Future<void> Function() accion) async {
    try {
      await accion();
    } on SinConexion {
      return 'Sin señal: esto necesita internet.';
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
}
