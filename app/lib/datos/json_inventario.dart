import '../dominio/inventario.dart';
import '../dominio/modelos.dart';

Nivel _nivel(String texto) => switch (texto) {
  'bien' => Nivel.bien,
  'poco' => Nivel.poco,
  'critico' => Nivel.critico,
  _ => Nivel.sinDatos,
};

TipoInsumo _tipo(String texto) => switch (texto) {
  'materia_prima' => TipoInsumo.materiaPrima,
  'alimento_comprado' => TipoInsumo.alimentoComprado,
  _ => TipoInsumo.alimentoPreparado,
};

Etapa? _etapa(Object? texto) => texto == null ? null : Etapa.values.byName(texto as String);

double? _numero(Object? valor) => (valor as num?)?.toDouble();

Insumo _insumo(Map<String, dynamic> json) => Insumo(
  id: json['id'] as int,
  nombre: json['nombre'] as String,
  tipo: _tipo(json['tipo'] as String),
  etapa: _etapa(json['etapa']),
  kgPorBulto: _numero(json['kg_por_bulto']),
);

Inventario inventarioDesdeJson(Map<String, dynamic> json) => Inventario(
  existencias: [
    for (final e in json['existencias'] as List<dynamic>)
      Existencia(
        insumo: _insumo((e as Map<String, dynamic>)['insumo'] as Map<String, dynamic>),
        stockKg: _numero(e['stock_kg'])!,
        bultos: _numero(e['bultos']),
        consumoDiarioKg: _numero(e['consumo_diario_kg']),
        dias: _numero(e['dias']),
        nivel: _nivel(e['nivel'] as String),
      ),
  ],
  etapas: [
    for (final e in json['etapas'] as List<dynamic>)
      CoberturaEtapa(
        etapa: _etapa((e as Map<String, dynamic>)['etapa'])!,
        stockKg: _numero(e['stock_kg'])!,
        consumoDiarioKg: _numero(e['consumo_diario_kg']),
        dias: _numero(e['dias']),
        nivel: _nivel(e['nivel'] as String),
        enUsoId: e['en_uso_id'] as int?,
      ),
  ],
  mezclas: [
    for (final m in json['mezclas'] as List<dynamic>)
      MezclaPosible(
        productoId: (m as Map<String, dynamic>)['producto_id'] as int,
        producto: m['producto'] as String,
        stockKg: _numero(m['stock_kg'])!,
        kgPosibles: _numero(m['kg_posibles'])!,
        limitante: m['limitante'] as String,
        dias: _numero(m['dias']),
        nivel: _nivel(m['nivel'] as String),
      ),
  ],
);
