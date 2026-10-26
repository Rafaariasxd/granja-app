import '../dominio/huevos.dart';
import 'json.dart';

double? _numero(Object? valor) => (valor as num?)?.toDouble();

SalidaHuevo salidaDesdeJson(Map<String, dynamic> s) => SalidaHuevo(
  id: s['id'] as String,
  fecha: fechaDesdeIso(s['fecha'] as String),
  tipoVenta: TipoVenta.desdeCodigo(s['tipo_venta'] as String),
  cliente: s['cliente'] as String? ?? '',
  lineas: [
    for (final l in s['lineas'] as List<dynamic>)
      LineaSalida(
        categoriaId: (l as Map<String, dynamic>)['categoria_id'] as int,
        huevosSacados: l['huevos_sacados'] as int,
        huevosVendidos: l['huevos_vendidos'] as int?,
        valor: _numero(l['valor']),
      ),
  ],
);

PrecioHuevo precioHuevoDesdeJson(Map<String, dynamic> p) => PrecioHuevo(
  categoriaId: p['categoria_id'] as int,
  precioCaja: _numero(p['precio_caja']),
  precioCarton: _numero(p['precio_carton']),
  precioMayorista: _numero(p['precio_mayorista']),
);

BodegaHuevo bodegaHuevoDesdeJson(Map<String, dynamic> json) => BodegaHuevo(
  existencias: [
    for (final e in json['existencias'] as List<dynamic>)
      ExistenciaHuevo(
        categoriaId: (e as Map<String, dynamic>)['categoria_id'] as int,
        categoria: e['categoria'] as String,
        activa: e['activa'] as bool? ?? true,
        huevos: e['huevos'] as int,
      ),
  ],
  precios: [for (final p in json['precios'] as List<dynamic>) precioHuevoDesdeJson(p as Map<String, dynamic>)],
  abiertas: [for (final s in json['abiertas'] as List<dynamic>) salidaDesdeJson(s as Map<String, dynamic>)],
);

List<Map<String, int>> lineasAJson(Map<int, int> huevosPorCategoria) => [
  for (final MapEntry(key: categoria, value: huevos) in huevosPorCategoria.entries)
    {'categoria_id': categoria, 'huevos': huevos},
];
