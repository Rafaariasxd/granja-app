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

  Future<List<TareaDePlan>?> plan(int razaId) async {
    try {
      return await _repositorio.plan(razaId);
    } on ErrorDeApi {
      return null;
    }
  }

  Future<List<PuntoDeCurva>?> curva(int razaId) async {
    try {
      return await _repositorio.curva(razaId);
    } on ErrorDeApi {
      return null;
    }
  }

  Future<String?> crearCategoriaHuevo(String nombre) => _accion(() => _repositorio.crearCategoriaHuevo(nombre));

  Future<String?> cambiarCategoriaHuevo(int id, {String? nombre, bool? activa}) =>
      _accion(() => _repositorio.cambiarCategoriaHuevo(id, nombre: nombre, activa: activa));

  Future<String?> fijarPrecioHuevo(int categoriaId, {double? caja, double? carton, double? mayorista}) =>
      _accion(() => _repositorio.fijarPrecioHuevo(categoriaId, caja: caja, carton: carton, mayorista: mayorista));

  Future<String?> crearRaza(String nombre, String? plantilla) =>
      _accion(() => _repositorio.crearRaza(nombre, plantilla));

  Future<String?> renombrarRaza(int razaId, String nombre) => _accion(() => _repositorio.renombrarRaza(razaId, nombre));

  Future<String?> guardarPlan(int razaId, List<TareaDePlan> tareas) =>
      _accion(() => _repositorio.guardarPlan(razaId, tareas));

  Future<String?> guardarCurva(int razaId, List<PuntoDeCurva> puntos) =>
      _accion(() => _repositorio.guardarCurva(razaId, puntos));

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
