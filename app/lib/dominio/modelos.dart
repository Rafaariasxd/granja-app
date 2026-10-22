enum Etapa { cria, levante, produccion }

class Galpon {
  const Galpon({required this.id, required this.nombre, required this.capacidadAves, this.activo = true});

  final int id;
  final String nombre;
  final int capacidadAves;
  final bool activo;
}

class Lote {
  const Lote({
    required this.id,
    required this.galponId,
    required this.lineaId,
    required this.fechaNacimiento,
    required this.fechaIngreso,
    required this.avesIniciales,
    this.fechaSalida,
  });

  final int id;
  final int galponId;
  final int lineaId;
  final DateTime fechaNacimiento;
  final DateTime fechaIngreso;
  final int avesIniciales;
  final DateTime? fechaSalida;
}

class RegistroDiario {
  const RegistroDiario({
    required this.id,
    required this.galponId,
    required this.fecha,
    required this.huevosTotal,
    this.huevosRotos = 0,
    this.mortalidad = 0,
    this.alimentoKg = 0,
  });

  final String id;
  final int galponId;
  final DateTime fecha;
  final int huevosTotal;
  final int huevosRotos;
  final int mortalidad;
  final double alimentoKg;
}

class DiaPostura {
  const DiaPostura({required this.fecha, required this.realPct, required this.estandarPct});

  final DateTime fecha;
  final double realPct;
  final double estandarPct;
}

class ResumenGalpon {
  const ResumenGalpon({
    required this.galponId,
    required this.nombre,
    required this.capacidadAves,
    required this.avesVivas,
    required this.ocupacionPct,
    this.loteId,
    this.etapa,
    this.edadSemanas,
    this.posturaPct,
  });

  final int galponId;
  final String nombre;
  final int capacidadAves;
  final int avesVivas;
  final double ocupacionPct;
  final int? loteId;
  final Etapa? etapa;
  final int? edadSemanas;
  final double? posturaPct;

  bool get vacio => loteId == null;
}
