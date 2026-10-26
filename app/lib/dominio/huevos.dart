const huevosPorCarton = 30;
const cartonesPorCaja = 12;
const huevosPorCaja = huevosPorCarton * cartonesPorCaja;

class Empaque {
  const Empaque(this.cajas, this.cartones, this.sueltos);

  final int cajas;
  final int cartones;
  final int sueltos;
}

int aHuevos({int cajas = 0, int cartones = 0, int huevos = 0}) =>
    cajas * huevosPorCaja + cartones * huevosPorCarton + huevos;

Empaque empacar(int huevos) {
  final signo = huevos < 0 ? -1 : 1;
  var resto = huevos.abs();
  final cajas = resto ~/ huevosPorCaja;
  resto %= huevosPorCaja;
  return Empaque(signo * cajas, signo * (resto ~/ huevosPorCarton), signo * (resto % huevosPorCarton));
}

String _parte(int n, String uno, String varios) => n == 1 ? '1 $uno' : '$n $varios';

String empaqueTexto(int huevos) {
  if (huevos == 0) return 'Nada';
  final e = empacar(huevos.abs());
  final partes = [
    if (e.cajas > 0) _parte(e.cajas, 'caja', 'cajas'),
    if (e.cartones > 0) _parte(e.cartones, 'cartón', 'cartones'),
    if (e.sueltos > 0) _parte(e.sueltos, 'huevo', 'huevos'),
  ];
  final texto = partes.length == 1
      ? partes.single
      : '${partes.sublist(0, partes.length - 1).join(', ')} y ${partes.last}';
  return huevos < 0 ? 'Faltan $texto' : texto;
}

enum TipoVenta {
  cliente('cliente', 'Cliente', 'Precio de la caja'),
  particular('particular', 'Particular', 'Precio del cartón'),
  mayorista('mayorista', 'Mayorista', 'Por encargo, más barato');

  const TipoVenta(this.codigo, this.nombre, this.detalle);

  final String codigo;
  final String nombre;
  final String detalle;

  static TipoVenta desdeCodigo(String codigo) => TipoVenta.values.firstWhere((t) => t.codigo == codigo);
}

class PrecioHuevo {
  const PrecioHuevo({required this.categoriaId, this.precioCaja, this.precioCarton, this.precioMayorista});

  final int categoriaId;
  final double? precioCaja;
  final double? precioCarton;
  final double? precioMayorista;
}

double? precioDeLosHuevos(int huevos, TipoVenta tipo, PrecioHuevo? precio) {
  if (precio == null || huevos <= 0) return null;
  return switch (tipo) {
    TipoVenta.particular => precio.precioCarton == null ? null : precio.precioCarton! * huevos / huevosPorCarton,
    TipoVenta.cliente => precio.precioCaja == null ? null : precio.precioCaja! * huevos / huevosPorCaja,
    TipoVenta.mayorista => precio.precioMayorista == null ? null : precio.precioMayorista! * huevos / huevosPorCaja,
  };
}

double? totalSugerido(Map<int, int> huevosPorCategoria, TipoVenta tipo, Map<int, PrecioHuevo> precios) {
  var total = 0.0;
  for (final MapEntry(key: categoria, value: huevos) in huevosPorCategoria.entries) {
    if (huevos <= 0) continue;
    final valor = precioDeLosHuevos(huevos, tipo, precios[categoria]);
    if (valor == null) return null;
    total += valor;
  }
  return total;
}

class ExistenciaHuevo {
  const ExistenciaHuevo({
    required this.categoriaId,
    required this.categoria,
    required this.activa,
    required this.huevos,
  });

  final int categoriaId;
  final String categoria;
  final bool activa;
  final int huevos;

  ExistenciaHuevo con(int huevos) =>
      ExistenciaHuevo(categoriaId: categoriaId, categoria: categoria, activa: activa, huevos: huevos);
}

class LineaSalida {
  const LineaSalida({required this.categoriaId, required this.huevosSacados, this.huevosVendidos, this.valor});

  final int categoriaId;
  final int huevosSacados;
  final int? huevosVendidos;
  final double? valor;
}

class SalidaHuevo {
  const SalidaHuevo({
    required this.id,
    required this.fecha,
    required this.tipoVenta,
    required this.lineas,
    this.cliente = '',
    this.sinEnviar = false,
  });

  final String id;
  final DateTime fecha;
  final TipoVenta tipoVenta;
  final String cliente;
  final List<LineaSalida> lineas;
  final bool sinEnviar;

  int get huevos => lineas.fold(0, (suma, l) => suma + l.huevosSacados);
}

class BodegaHuevo {
  const BodegaHuevo({required this.existencias, required this.precios, required this.abiertas});

  final List<ExistenciaHuevo> existencias;
  final List<PrecioHuevo> precios;
  final List<SalidaHuevo> abiertas;

  int get total => existencias.fold(0, (suma, e) => suma + e.huevos);

  Map<int, PrecioHuevo> get preciosPorCategoria => {for (final p in precios) p.categoriaId: p};

  String nombreDe(int categoriaId) {
    for (final e in existencias) {
      if (e.categoriaId == categoriaId) return e.categoria;
    }
    return 'Categoría $categoriaId';
  }

  int huevosDe(int categoriaId) {
    for (final e in existencias) {
      if (e.categoriaId == categoriaId) return e.huevos;
    }
    return 0;
  }
}
