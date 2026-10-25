import 'modelos.dart';

enum Nivel { bien, poco, critico, sinDatos }

enum TipoInsumo { materiaPrima, alimentoComprado, alimentoPreparado }

class Insumo {
  const Insumo({required this.id, required this.nombre, required this.tipo, this.etapa, this.kgPorBulto});

  final int id;
  final String nombre;
  final TipoInsumo tipo;
  final Etapa? etapa;
  final double? kgPorBulto;
}

class Existencia {
  const Existencia({
    required this.insumo,
    required this.stockKg,
    required this.nivel,
    this.bultos,
    this.consumoDiarioKg,
    this.dias,
  });

  final Insumo insumo;
  final double stockKg;
  final double? bultos;
  final double? consumoDiarioKg;
  final double? dias;
  final Nivel nivel;
}

class CoberturaEtapa {
  const CoberturaEtapa({
    required this.etapa,
    required this.stockKg,
    required this.nivel,
    this.consumoDiarioKg,
    this.dias,
    this.enUsoId,
  });

  final Etapa etapa;
  final double stockKg;
  final double? consumoDiarioKg;
  final double? dias;
  final Nivel nivel;
  final int? enUsoId;
}

class MezclaPosible {
  const MezclaPosible({
    required this.productoId,
    required this.producto,
    required this.stockKg,
    required this.kgPosibles,
    required this.limitante,
    required this.nivel,
    this.dias,
  });

  final int productoId;
  final String producto;
  final double stockKg;
  final double kgPosibles;
  final String limitante;
  final double? dias;
  final Nivel nivel;
}

class Inventario {
  const Inventario({required this.existencias, required this.etapas, required this.mezclas});

  final List<Existencia> existencias;
  final List<CoberturaEtapa> etapas;
  final List<MezclaPosible> mezclas;

  List<Existencia> get materiasPrimas => _de(TipoInsumo.materiaPrima);

  List<Existencia> get alimentos => existencias.where((e) => e.insumo.tipo != TipoInsumo.materiaPrima).toList();

  Existencia? existencia(int insumoId) {
    for (final e in existencias) {
      if (e.insumo.id == insumoId) return e;
    }
    return null;
  }

  List<Existencia> get urgentes => existencias.where((e) => e.nivel == Nivel.critico).toList();

  bool get vacio => existencias.isEmpty;

  List<Existencia> _de(TipoInsumo tipo) => existencias.where((e) => e.insumo.tipo == tipo).toList();
}
