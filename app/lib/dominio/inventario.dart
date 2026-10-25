import 'modelos.dart';

enum Nivel { bien, poco, critico, sinDatos }

enum TipoInsumo { materiaPrima, alimentoComprado, alimentoPreparado }

enum TipoBodega { alimento, materiaPrima }

class Insumo {
  const Insumo({required this.id, required this.nombre, required this.tipo, this.etapa, this.kgPorBulto});

  final int id;
  final String nombre;
  final TipoInsumo tipo;
  final Etapa? etapa;
  final double? kgPorBulto;
}

class Bodega {
  const Bodega({required this.id, required this.nombre, required this.tipo});

  final int id;
  final String nombre;
  final TipoBodega tipo;
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
    required this.origenId,
    required this.origen,
    this.dias,
  });

  final int productoId;
  final String producto;
  final double stockKg;
  final double kgPosibles;
  final String limitante;
  final double? dias;
  final Nivel nivel;
  final int origenId;
  final String origen;
}

class InventarioBodega {
  const InventarioBodega({
    required this.bodega,
    required this.galponIds,
    required this.existencias,
    required this.etapas,
  });

  final Bodega bodega;
  final List<int> galponIds;
  final List<Existencia> existencias;
  final List<CoberturaEtapa> etapas;

  List<Existencia> get urgentes => existencias.where((e) => e.nivel == Nivel.critico).toList();
}

class Inventario {
  const Inventario({required this.bodegas, required this.mezclas});

  final List<InventarioBodega> bodegas;
  final List<MezclaPosible> mezclas;

  bool get vacio => bodegas.isEmpty;

  List<InventarioBodega> get deAlimento => bodegas.where((b) => b.bodega.tipo == TipoBodega.alimento).toList();

  List<MezclaPosible> mezclasDe(int bodegaId) => mezclas.where((m) => m.origenId == bodegaId).toList();

  List<(Bodega, Existencia)> get urgentes => [
    for (final b in bodegas)
      for (final e in b.urgentes) (b.bodega, e),
  ];
}
