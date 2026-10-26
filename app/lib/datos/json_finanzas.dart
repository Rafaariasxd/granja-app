import '../dominio/finanzas.dart';
import 'json.dart';

double _numero(Object? valor) => (valor as num).toDouble();

CategoriaHuevo categoriaDesdeJson(Map<String, dynamic> c) => CategoriaHuevo(
  id: c['id'] as int,
  nombre: c['nombre'] as String,
  activa: c['activa'] as bool,
  orden: c['orden'] as int? ?? 0,
);

MovimientoDinero movimientoDesdeJson(Map<String, dynamic> m) => MovimientoDinero(
  id: m['id'] as String,
  fecha: fechaDesdeIso(m['fecha'] as String),
  rubro: Rubro.desdeCodigo(m['rubro'] as String),
  valor: _numero(m['valor']),
  descripcion: m['descripcion'] as String? ?? '',
  loteId: m['lote_id'] as int?,
  categoriaId: m['categoria_id'] as int?,
  cantidadHuevos: m['cantidad_huevos'] as int?,
  contraparte: m['contraparte'] as String? ?? '',
);

Map<String, Object?> movimientoAJson(MovimientoDinero m) => {
  'fecha': fechaIso(m.fecha),
  'rubro': m.rubro.codigo,
  'valor': m.valor,
  'descripcion': m.descripcion,
  'lote_id': m.loteId,
  'categoria_id': m.categoriaId,
  'cantidad_huevos': m.cantidadHuevos,
  'contraparte': m.contraparte,
};

ResumenFinanzas resumenFinanzasDesdeJson(Map<String, dynamic> r) => ResumenFinanzas(
  desde: fechaDesdeIso(r['desde'] as String),
  hasta: fechaDesdeIso(r['hasta'] as String),
  ingresos: _numero(r['ingresos']),
  egresos: _numero(r['egresos']),
  porRubro: [
    for (final t in r['por_rubro'] as List<dynamic>)
      TotalRubro(rubro: Rubro.desdeCodigo((t as Map<String, dynamic>)['rubro'] as String), total: _numero(t['total'])),
  ],
  huevos: [
    for (final v in r['huevos'] as List<dynamic>)
      VentaPorCategoria(
        categoria: (v as Map<String, dynamic>)['categoria'] as String,
        huevos: v['huevos'] as int,
        valor: _numero(v['valor']),
        precioPorHuevo: (v['precio_por_huevo'] as num?)?.toDouble(),
      ),
  ],
  porLote: [
    for (final l in r['por_lote'] as List<dynamic>)
      ResultadoLote(
        galpon: (l as Map<String, dynamic>)['galpon'] as String,
        ingresos: _numero(l['ingresos']),
        egresos: _numero(l['egresos']),
      ),
  ],
);

PanoramaDinero panoramaDineroDesdeJson(Map<String, dynamic> json) => PanoramaDinero(
  mes: fechaDesdeIso(json['mes'] as String),
  resumen: resumenFinanzasDesdeJson(json['resumen'] as Map<String, dynamic>),
  movimientos: [for (final m in json['movimientos'] as List<dynamic>) movimientoDesdeJson(m as Map<String, dynamic>)],
  categorias: [for (final c in json['categorias'] as List<dynamic>) categoriaDesdeJson(c as Map<String, dynamic>)],
  lotes: [
    for (final l in json['lotes'] as List<dynamic>)
      LoteBasico(id: (l as Map<String, dynamic>)['id'] as int, galpon: l['galpon'] as String),
  ],
);
