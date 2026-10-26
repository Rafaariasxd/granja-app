import 'modelos.dart';

enum TipoTarea { vacuna, desparasitacion, manejo }

enum EstadoTarea { aplicada, atrasada, ahora, proxima, lejana, previa }

enum NivelAlerta { urgente, revisar, info }

enum NivelPeso { bien, atencion, bajo, alto }

class TareaSanitaria {
  const TareaSanitaria({
    required this.tareaId,
    required this.nombre,
    required this.tipo,
    required this.semanaIdeal,
    required this.semanaMax,
    required this.estado,
    this.notaPlan = '',
    this.aplicadaEn,
    this.nota = '',
    this.cumplimientoId,
  });

  final int tareaId;
  final String nombre;
  final TipoTarea tipo;
  final int semanaIdeal;
  final int semanaMax;
  final String notaPlan;
  final EstadoTarea estado;
  final DateTime? aplicadaEn;
  final String nota;
  final String? cumplimientoId;

  String get cuando => semanaIdeal == semanaMax
      ? (semanaIdeal == 0 ? 'Al nacer' : 'Semana $semanaIdeal')
      : 'Semana $semanaIdeal a $semanaMax';

  bool get hecha => estado == EstadoTarea.aplicada;

  TareaSanitaria comoAplicada(DateTime fecha) => TareaSanitaria(
    tareaId: tareaId,
    nombre: nombre,
    tipo: tipo,
    semanaIdeal: semanaIdeal,
    semanaMax: semanaMax,
    notaPlan: notaPlan,
    estado: EstadoTarea.aplicada,
    aplicadaEn: fecha,
    nota: nota,
  );
}

class AlertaSanidad {
  const AlertaSanidad({
    required this.galponId,
    required this.galpon,
    required this.loteId,
    required this.tipo,
    required this.nivel,
    required this.titulo,
    required this.detalle,
    this.recomendaciones = const [],
  });

  final int galponId;
  final String galpon;
  final int loteId;
  final String tipo;
  final NivelAlerta nivel;
  final String titulo;
  final String detalle;
  final List<String> recomendaciones;
}

class PesajeLote {
  const PesajeLote({required this.id, required this.fecha, required this.pesoG, required this.avesPesadas});

  final String id;
  final DateTime fecha;
  final double pesoG;
  final int avesPesadas;
}

class ComparacionPeso {
  const ComparacionPeso({
    required this.fecha,
    required this.pesoG,
    required this.estandarG,
    required this.diferenciaPct,
    required this.nivel,
  });

  final DateTime fecha;
  final double pesoG;
  final double estandarG;
  final double diferenciaPct;
  final NivelPeso nivel;
}

class ComparacionPostura {
  const ComparacionPostura({required this.fecha, required this.realPct, required this.estandarPct});

  final DateTime fecha;
  final double realPct;
  final double estandarPct;
}

class GalponSanidad {
  const GalponSanidad({
    required this.galponId,
    required this.galpon,
    required this.loteId,
    required this.linea,
    required this.edadSemanas,
    required this.etapa,
    required this.avesVivas,
    required this.tareas,
    required this.pesajes,
    this.peso,
    this.postura,
  });

  final int galponId;
  final String galpon;
  final int loteId;
  final String linea;
  final int edadSemanas;
  final Etapa etapa;
  final int avesVivas;
  final List<TareaSanitaria> tareas;
  final List<PesajeLote> pesajes;
  final ComparacionPeso? peso;
  final ComparacionPostura? postura;

  List<TareaSanitaria> conEstado(EstadoTarea estado) => tareas.where((t) => t.estado == estado).toList();

  int get atrasadas => conEstado(EstadoTarea.atrasada).length;
}

class PanoramaSanidad {
  const PanoramaSanidad({required this.fecha, required this.alertas, required this.galpones});

  final DateTime fecha;
  final List<AlertaSanidad> alertas;
  final List<GalponSanidad> galpones;

  bool get vacio => galpones.isEmpty;

  List<AlertaSanidad> deGalpon(int galponId) => alertas.where((a) => a.galponId == galponId).toList();
}
