import '../dominio/modelos.dart';
import '../dominio/sanidad.dart';
import 'json.dart';

double? _numero(Object? valor) => (valor as num?)?.toDouble();

DateTime? _fecha(Object? valor) => valor == null ? null : fechaDesdeIso(valor as String);

NivelAlerta _nivelAlerta(String texto) => switch (texto) {
  'urgente' => NivelAlerta.urgente,
  'revisar' => NivelAlerta.revisar,
  _ => NivelAlerta.info,
};

NivelPeso _nivelPeso(String texto) => switch (texto) {
  'bajo' => NivelPeso.bajo,
  'atencion' => NivelPeso.atencion,
  'alto' => NivelPeso.alto,
  _ => NivelPeso.bien,
};

TipoTarea _tipoTarea(String texto) => switch (texto) {
  'vacuna' => TipoTarea.vacuna,
  'desparasitacion' => TipoTarea.desparasitacion,
  _ => TipoTarea.manejo,
};

EstadoTarea _estadoTarea(String texto) => switch (texto) {
  'aplicada' => EstadoTarea.aplicada,
  'atrasada' => EstadoTarea.atrasada,
  'ahora' => EstadoTarea.ahora,
  'proxima' => EstadoTarea.proxima,
  'previa' => EstadoTarea.previa,
  _ => EstadoTarea.lejana,
};

TareaSanitaria _tarea(Map<String, dynamic> t) => TareaSanitaria(
  tareaId: t['tarea_id'] as int,
  nombre: t['nombre'] as String,
  tipo: _tipoTarea(t['tipo'] as String),
  semanaIdeal: t['semana_ideal'] as int,
  semanaMax: t['semana_max'] as int,
  notaPlan: t['nota_plan'] as String? ?? '',
  estado: _estadoTarea(t['estado'] as String),
  aplicadaEn: _fecha(t['aplicada_en']),
  nota: t['nota'] as String? ?? '',
  cumplimientoId: t['cumplimiento_id'] as String?,
);

AlertaSanidad _alerta(Map<String, dynamic> a) => AlertaSanidad(
  galponId: a['galpon_id'] as int,
  galpon: a['galpon'] as String,
  loteId: a['lote_id'] as int,
  tipo: a['tipo'] as String,
  nivel: _nivelAlerta(a['nivel'] as String),
  titulo: a['titulo'] as String,
  detalle: a['detalle'] as String,
  recomendaciones: [for (final r in (a['recomendaciones'] as List<dynamic>? ?? const [])) r as String],
);

PesajeLote _pesaje(Map<String, dynamic> p) => PesajeLote(
  id: p['id'] as String,
  fecha: fechaDesdeIso(p['fecha'] as String),
  pesoG: _numero(p['peso_g'])!,
  avesPesadas: p['aves_pesadas'] as int,
);

GalponSanidad _galpon(Map<String, dynamic> g) {
  final peso = g['peso'] as Map<String, dynamic>?;
  final postura = g['postura'] as Map<String, dynamic>?;
  return GalponSanidad(
    galponId: g['galpon_id'] as int,
    galpon: g['galpon'] as String,
    loteId: g['lote_id'] as int,
    linea: g['linea'] as String,
    edadSemanas: g['edad_semanas'] as int,
    etapa: Etapa.values.byName(g['etapa'] as String),
    avesVivas: g['aves_vivas'] as int,
    tareas: [for (final t in g['tareas'] as List<dynamic>) _tarea(t as Map<String, dynamic>)],
    pesajes: [for (final p in g['pesajes'] as List<dynamic>) _pesaje(p as Map<String, dynamic>)],
    peso: peso == null
        ? null
        : ComparacionPeso(
            fecha: fechaDesdeIso(peso['fecha'] as String),
            pesoG: _numero(peso['peso_g'])!,
            estandarG: _numero(peso['estandar_g'])!,
            diferenciaPct: _numero(peso['diferencia_pct'])!,
            nivel: _nivelPeso(peso['nivel'] as String),
          ),
    postura: postura == null
        ? null
        : ComparacionPostura(
            fecha: fechaDesdeIso(postura['fecha'] as String),
            realPct: _numero(postura['real_pct'])!,
            estandarPct: _numero(postura['estandar_pct'])!,
          ),
  );
}

PanoramaSanidad panoramaDesdeJson(Map<String, dynamic> json) => PanoramaSanidad(
  fecha: fechaDesdeIso(json['fecha'] as String),
  alertas: [for (final a in json['alertas'] as List<dynamic>) _alerta(a as Map<String, dynamic>)],
  galpones: [for (final g in json['galpones'] as List<dynamic>) _galpon(g as Map<String, dynamic>)],
);
