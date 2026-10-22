import '../dominio/fechas.dart';
import '../dominio/modelos.dart';

String fechaIso(DateTime fecha) => soloDia(fecha).toIso8601String().substring(0, 10);

DateTime fechaDesdeIso(String texto) => DateTime.parse('${texto}T00:00:00Z');

Map<String, Object> registroAJson(RegistroDiario registro) => {
  'id': registro.id,
  'galpon_id': registro.galponId,
  'fecha': fechaIso(registro.fecha),
  'huevos_total': registro.huevosTotal,
  'huevos_rotos': registro.huevosRotos,
  'mortalidad': registro.mortalidad,
  'alimento_kg': registro.alimentoKg,
};

RegistroDiario registroDesdeJson(Map<String, dynamic> json, int galponId) => RegistroDiario(
  id: json['id'] as String,
  galponId: galponId,
  fecha: fechaDesdeIso(json['fecha'] as String),
  huevosTotal: json['huevos_total'] as int,
  huevosRotos: json['huevos_rotos'] as int,
  mortalidad: json['mortalidad'] as int,
  alimentoKg: (json['alimento_kg'] as num).toDouble(),
);

Map<String, Object?> resumenAJson(ResumenGalpon resumen) => {
  'galpon_id': resumen.galponId,
  'nombre': resumen.nombre,
  'capacidad_aves': resumen.capacidadAves,
  'aves_vivas': resumen.avesVivas,
  'ocupacion_pct': resumen.ocupacionPct,
  'lote_id': resumen.loteId,
  'etapa': resumen.etapa?.name,
  'edad_semanas': resumen.edadSemanas,
  'postura_pct': resumen.posturaPct,
  'linea': resumen.linea,
  'huevos_del_dia': resumen.huevosDelDia,
};

ResumenGalpon resumenDesdeJson(Map<String, dynamic> json) {
  final etapa = json['etapa'] as String?;
  return ResumenGalpon(
    galponId: json['galpon_id'] as int,
    nombre: json['nombre'] as String,
    capacidadAves: json['capacidad_aves'] as int,
    avesVivas: json['aves_vivas'] as int,
    ocupacionPct: (json['ocupacion_pct'] as num).toDouble(),
    loteId: json['lote_id'] as int?,
    etapa: etapa == null ? null : Etapa.values.byName(etapa),
    edadSemanas: json['edad_semanas'] as int?,
    posturaPct: (json['postura_pct'] as num?)?.toDouble(),
    linea: json['linea'] as String?,
    huevosDelDia: json['huevos_del_dia'] as int?,
  );
}
