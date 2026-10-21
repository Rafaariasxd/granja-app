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
  );
}
