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

TipoBodega _tipoBodega(String texto) => texto == 'materia_prima' ? TipoBodega.materiaPrima : TipoBodega.alimento;

Etapa? _etapa(Object? texto) => texto == null ? null : Etapa.values.byName(texto as String);

double? _numero(Object? valor) => (valor as num?)?.toDouble();

Insumo _insumo(Map<String, dynamic> json) => Insumo(
  id: json['id'] as int,
  nombre: json['nombre'] as String,
  tipo: _tipo(json['tipo'] as String),
  etapa: _etapa(json['etapa']),
  kgPorBulto: _numero(json['kg_por_bulto']),
);

Existencia _existencia(Map<String, dynamic> e) => Existencia(
  insumo: _insumo(e['insumo'] as Map<String, dynamic>),
  stockKg: _numero(e['stock_kg'])!,
  bultos: _numero(e['bultos']),
  consumoDiarioKg: _numero(e['consumo_diario_kg']),
  dias: _numero(e['dias']),
  nivel: _nivel(e['nivel'] as String),
);

CoberturaEtapa _cobertura(Map<String, dynamic> e) => CoberturaEtapa(
  etapa: _etapa(e['etapa'])!,
  stockKg: _numero(e['stock_kg'])!,
  consumoDiarioKg: _numero(e['consumo_diario_kg']),
  dias: _numero(e['dias']),
  nivel: _nivel(e['nivel'] as String),
  enUsoId: e['en_uso_id'] as int?,
);

InventarioBodega _bodega(Map<String, dynamic> b) {
  final datos = b['bodega'] as Map<String, dynamic>;
  return InventarioBodega(
    bodega: Bodega(
      id: datos['id'] as int,
      nombre: datos['nombre'] as String,
      tipo: _tipoBodega(datos['tipo'] as String),
    ),
    galponIds: [for (final id in b['galpon_ids'] as List<dynamic>) id as int],
    existencias: [for (final e in b['existencias'] as List<dynamic>) _existencia(e as Map<String, dynamic>)],
    etapas: [for (final e in b['etapas'] as List<dynamic>) _cobertura(e as Map<String, dynamic>)],
  );
}

MezclaPosible _mezcla(Map<String, dynamic> m) => MezclaPosible(
  productoId: m['producto_id'] as int,
  producto: m['producto'] as String,
  stockKg: _numero(m['stock_kg'])!,
  kgPosibles: _numero(m['kg_posibles'])!,
  limitante: m['limitante'] as String,
  dias: _numero(m['dias']),
  nivel: _nivel(m['nivel'] as String),
  origenId: m['origen_id'] as int,
  origen: m['origen'] as String,
);

Inventario inventarioDesdeJson(Map<String, dynamic> json) => Inventario(
  bodegas: [for (final b in json['bodegas'] as List<dynamic>) _bodega(b as Map<String, dynamic>)],
  mezclas: [for (final m in json['mezclas'] as List<dynamic>) _mezcla(m as Map<String, dynamic>)],
);
