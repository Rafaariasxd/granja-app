import 'package:flutter/foundation.dart';

import '../datos/api_granja.dart';
import '../datos/cola.dart';
import '../datos/huevos.dart';
import '../datos/operaciones.dart';
import '../dominio/huevos.dart';

class EstadoHuevos extends ChangeNotifier {
  EstadoHuevos(this._repositorio, {DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now;

  final RepositorioHuevos _repositorio;
  final DateTime Function() _reloj;

  HuevosActuales? _datos;
  List<OperacionBodega> _sinResolver = const [];
  bool _cargando = false;
  bool _otraVuelta = false;
  bool _sesionVencida = false;

  bool get cargando => _cargando;
  bool get sesionVencida => _sesionVencida;
  bool get sinSenal => _datos?.copiaLocal ?? false;
  List<OperacionBodega> get sinResolver => _sinResolver;
  int get porEnviar => _sinResolver.where((o) => o.estado == EstadoEnvio.pendiente).length;
  int get noRegistradas => _sinResolver.where((o) => o.estado != EstadoEnvio.pendiente).length;

  BodegaHuevo? get bodega {
    final base = _datos?.bodega;
    if (base == null) return null;
    final pendientes = _sinResolver.where((o) => o.estado == EstadoEnvio.pendiente).toList();
    if (pendientes.isEmpty) return base;
    final stock = {for (final e in base.existencias) e.categoriaId: e.huevos};
    void sumar(Map<int, int> lineas, int signo) {
      for (final MapEntry(key: c, value: h) in lineas.entries) {
        stock[c] = (stock[c] ?? 0) + signo * h;
      }
    }

    final salidasLocales = <String, SalidaHuevo>{
      for (final o in pendientes)
        if (o.tipo == TipoOperacion.huevoSalida)
          o.id: SalidaHuevo(
            id: o.id,
            fecha: o.fecha,
            tipoVenta: TipoVenta.desdeCodigo(o.tipoVenta!),
            cliente: o.contraparte ?? '',
            lineas: [
              for (final MapEntry(key: c, value: h) in o.lineas!.entries) LineaSalida(categoriaId: c, huevosSacados: h),
            ],
            sinEnviar: true,
          ),
    };
    final todas = {for (final s in base.abiertas) s.id: s, ...salidasLocales};
    final cerradas = <String>{};
    for (final o in pendientes) {
      switch (o.tipo) {
        case TipoOperacion.huevoIngreso:
          sumar({o.categoriaId!: o.huevos!}, 1);
        case TipoOperacion.huevoBaja:
          sumar({o.categoriaId!: o.huevos!}, -1);
        case TipoOperacion.huevoVenta || TipoOperacion.huevoSalida:
          sumar(o.lineas!, -1);
        case TipoOperacion.huevoCierre:
          final salida = todas[o.referencia];
          cerradas.add(o.referencia!);
          if (salida != null && o.lineas != null) {
            for (final l in salida.lineas) {
              final sobra = l.huevosSacados - (o.lineas![l.categoriaId] ?? 0);
              if (sobra > 0) sumar({l.categoriaId: sobra}, 1);
            }
          }
        default:
          break;
      }
    }
    return BodegaHuevo(
      existencias: [for (final e in base.existencias) e.con(stock[e.categoriaId] ?? 0)],
      precios: base.precios,
      abiertas: [
        for (final s in todas.values)
          if (!cerradas.contains(s.id)) s,
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
        _datos = await _repositorio.bodega(_reloj()) ?? _datos;
      } while (_otraVuelta);
    } on SesionVencida {
      _sesionVencida = true;
    } finally {
      _sinResolver = await _repositorio.sinResolver();
      _cargando = false;
      notifyListeners();
    }
  }

  String _nombre(int categoriaId) => _datos?.bodega.nombreDe(categoriaId) ?? '';

  String _resumen(Map<int, int> lineas) =>
      [for (final MapEntry(key: c, value: h) in lineas.entries) '${empaqueTexto(h)} ${_nombre(c)}'].join(', ');

  Future<String?> ingresar(int categoriaId, int huevos) => _guardar(
    () => _repositorio.guardarIngreso(categoriaId, huevos, '${empaqueTexto(huevos)} ${_nombre(categoriaId)}', _reloj()),
  );

  Future<String?> ingresarVarios(Map<int, int> lineas, String origen) => _guardar(() async {
    for (final MapEntry(key: categoria, value: huevos) in lineas.entries) {
      if (huevos <= 0) continue;
      await _repositorio.guardarIngreso(
        categoria,
        huevos,
        '${empaqueTexto(huevos)} ${_nombre(categoria)} de $origen',
        _reloj(),
      );
    }
  });

  Future<String?> darDeBaja(int categoriaId, int huevos, String nota) => _guardar(
    () => _repositorio.guardarBaja(
      categoriaId,
      huevos,
      nota,
      '${empaqueTexto(huevos)} ${_nombre(categoriaId)}',
      _reloj(),
    ),
  );

  Future<String?> vender(TipoVenta tipo, String cliente, Map<int, int> lineas, double? valorCobrado) =>
      _guardar(() => _repositorio.guardarVenta(tipo, cliente, lineas, valorCobrado, _resumen(lineas), _reloj()));

  Future<String?> sacar(TipoVenta tipo, String cliente, Map<int, int> lineas) =>
      _guardar(() => _repositorio.guardarSalida(tipo, cliente, lineas, _resumen(lineas), _reloj()));

  Future<String?> cerrar(SalidaHuevo salida, Map<int, int>? vendidos, double? valorCobrado) => _guardar(
    () => _repositorio.guardarCierre(
      salida.id,
      vendidos,
      valorCobrado,
      salida.cliente.isEmpty ? 'Salida del ${salida.fecha.day}/${salida.fecha.month}' : 'Salida de ${salida.cliente}',
      _reloj(),
    ),
  );

  Future<String?> contar(int categoriaId, int huevos) =>
      _enLinea(() => _repositorio.contar(categoriaId, huevos), 'contar');

  Future<String?> anular(SalidaHuevo salida) => _enLinea(() => _repositorio.anular(salida.id), 'anular');

  Future<void> descartar(String id) async {
    await _repositorio.descartar(id);
    _sinResolver = await _repositorio.sinResolver();
    notifyListeners();
  }

  Future<String?> _enLinea(Future<void> Function() accion, String que) async {
    try {
      await accion();
    } on SinConexion {
      return 'Sin señal: $que necesita internet. Prueba de nuevo cuando haya señal.';
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
