enum Rubro {
  ventaHuevo('venta_huevo', 'Venta de huevo', true),
  ventaGallinas('venta_gallinas', 'Venta de gallinas', true),
  otrosIngresos('otros_ingresos', 'Otros ingresos', true),
  alimento('alimento', 'Alimento', false),
  materiaPrima('materia_prima', 'Materia prima', false),
  vacunasMedicinas('vacunas_medicinas', 'Vacunas y medicinas', false),
  pollitas('pollitas', 'Pollitas', false),
  manoDeObra('mano_de_obra', 'Mano de obra', false),
  servicios('servicios', 'Servicios', false),
  mantenimiento('mantenimiento', 'Mantenimiento', false),
  otrosEgresos('otros_egresos', 'Otros gastos', false);

  const Rubro(this.codigo, this.nombre, this.esIngreso);

  final String codigo;
  final String nombre;
  final bool esIngreso;

  static Rubro desdeCodigo(String codigo) => Rubro.values.firstWhere((r) => r.codigo == codigo);

  static List<Rubro> get deGasto => Rubro.values.where((r) => !r.esIngreso).toList();
}

class CategoriaHuevo {
  const CategoriaHuevo({required this.id, required this.nombre, required this.activa, this.orden = 0});

  final int id;
  final String nombre;
  final bool activa;
  final int orden;
}

class MovimientoDinero {
  const MovimientoDinero({
    required this.id,
    required this.fecha,
    required this.rubro,
    required this.valor,
    this.descripcion = '',
    this.loteId,
    this.categoriaId,
    this.cantidadHuevos,
    this.contraparte = '',
  });

  final String id;
  final DateTime fecha;
  final Rubro rubro;
  final double valor;
  final String descripcion;
  final int? loteId;
  final int? categoriaId;
  final int? cantidadHuevos;
  final String contraparte;

  bool get esIngreso => rubro.esIngreso;
}

class TotalRubro {
  const TotalRubro({required this.rubro, required this.total});

  final Rubro rubro;
  final double total;
}

class VentaPorCategoria {
  const VentaPorCategoria({required this.categoria, required this.huevos, required this.valor, this.precioPorHuevo});

  final String categoria;
  final int huevos;
  final double valor;
  final double? precioPorHuevo;
}

class ResultadoLote {
  const ResultadoLote({required this.galpon, required this.ingresos, required this.egresos});

  final String galpon;
  final double ingresos;
  final double egresos;

  double get utilidad => ingresos - egresos;
}

class ResumenFinanzas {
  const ResumenFinanzas({
    required this.desde,
    required this.hasta,
    required this.ingresos,
    required this.egresos,
    required this.porRubro,
    required this.huevos,
    required this.porLote,
  });

  final DateTime desde;
  final DateTime hasta;
  final double ingresos;
  final double egresos;
  final List<TotalRubro> porRubro;
  final List<VentaPorCategoria> huevos;
  final List<ResultadoLote> porLote;

  double get utilidad => ingresos - egresos;
}

class LoteBasico {
  const LoteBasico({required this.id, required this.galpon});

  final int id;
  final String galpon;
}

class PanoramaDinero {
  const PanoramaDinero({
    required this.mes,
    required this.resumen,
    required this.movimientos,
    required this.categorias,
    required this.lotes,
  });

  final DateTime mes;
  final ResumenFinanzas resumen;
  final List<MovimientoDinero> movimientos;
  final List<CategoriaHuevo> categorias;
  final List<LoteBasico> lotes;

  List<CategoriaHuevo> get categoriasActivas => categorias.where((c) => c.activa).toList();

  String? galponDelLote(int? loteId) {
    for (final l in lotes) {
      if (l.id == loteId) return l.galpon;
    }
    return null;
  }
}

const huevosPorCubeta = 30;

DateTime primerDiaDelMes(DateTime fecha) => DateTime.utc(fecha.year, fecha.month);

DateTime ultimoDiaDelMes(DateTime fecha) => DateTime.utc(fecha.year, fecha.month + 1, 0);

DateTime mesAnterior(DateTime mes) => DateTime.utc(mes.year, mes.month - 1);

DateTime mesSiguiente(DateTime mes) => DateTime.utc(mes.year, mes.month + 1);
