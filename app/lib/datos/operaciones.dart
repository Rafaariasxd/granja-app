import 'cola.dart';
import 'json.dart';

enum TipoOperacion {
  compra,
  preparacion,
  gasto,
  aplicacion,
  pesaje,
  dinero,
  huevoIngreso,
  huevoBaja,
  huevoVenta,
  huevoSalida,
  huevoCierre,
}

const tiposDeBodega = {TipoOperacion.compra, TipoOperacion.preparacion, TipoOperacion.gasto};
const tiposDeSanidad = {TipoOperacion.aplicacion, TipoOperacion.pesaje};
const tiposDeDinero = {TipoOperacion.dinero};
const tiposDeHuevo = {
  TipoOperacion.huevoIngreso,
  TipoOperacion.huevoBaja,
  TipoOperacion.huevoVenta,
  TipoOperacion.huevoSalida,
  TipoOperacion.huevoCierre,
};

class OperacionBodega {
  const OperacionBodega({
    required this.id,
    required this.tipo,
    required this.fecha,
    required this.descripcion,
    required this.guardadoEn,
    this.insumoId,
    this.bodegaId,
    this.haciaBodegaId,
    this.bultos,
    this.kg,
    this.loteId,
    this.tareaId,
    this.pesoG,
    this.aves,
    this.rubro,
    this.valor,
    this.categoriaId,
    this.huevos,
    this.contraparte,
    this.nota,
    this.lineas,
    this.tipoVenta,
    this.referencia,
    this.estado = EstadoEnvio.pendiente,
    this.mensaje,
    this.intentos = 0,
  });

  final String id;
  final TipoOperacion tipo;
  final DateTime fecha;
  final int? insumoId;
  final int? bodegaId;
  final int? haciaBodegaId;
  final double? bultos;
  final double? kg;
  final int? loteId;
  final int? tareaId;
  final double? pesoG;
  final int? aves;
  final String? rubro;
  final double? valor;
  final int? categoriaId;
  final int? huevos;
  final String? contraparte;
  final String? nota;
  final Map<int, int>? lineas;
  final String? tipoVenta;
  final String? referencia;
  final String descripcion;
  final DateTime guardadoEn;
  final EstadoEnvio estado;
  final String? mensaje;
  final int intentos;

  OperacionBodega con({required EstadoEnvio estado, String? mensaje}) => OperacionBodega(
    id: id,
    tipo: tipo,
    fecha: fecha,
    insumoId: insumoId,
    bodegaId: bodegaId,
    haciaBodegaId: haciaBodegaId,
    bultos: bultos,
    kg: kg,
    loteId: loteId,
    tareaId: tareaId,
    pesoG: pesoG,
    aves: aves,
    rubro: rubro,
    valor: valor,
    categoriaId: categoriaId,
    huevos: huevos,
    contraparte: contraparte,
    nota: nota,
    lineas: lineas,
    tipoVenta: tipoVenta,
    referencia: referencia,
    descripcion: descripcion,
    guardadoEn: guardadoEn,
    estado: estado,
    mensaje: mensaje,
    intentos: intentos + 1,
  );

  Map<String, Object?> aMapa() => {
    'id': id,
    'tipo': tipo.name,
    'fecha': fechaIso(fecha),
    'insumo_id': insumoId,
    'bodega_id': bodegaId,
    'hacia_bodega_id': haciaBodegaId,
    'bultos': bultos,
    'kg': kg,
    'lote_id': loteId,
    'tarea_id': tareaId,
    'peso_g': pesoG,
    'aves': aves,
    'rubro': rubro,
    'valor': valor,
    'categoria_id': categoriaId,
    'huevos': huevos,
    'contraparte': contraparte,
    'nota': nota,
    'lineas': lineas?.map((categoria, huevos) => MapEntry('$categoria', huevos)),
    'tipo_venta': tipoVenta,
    'referencia': referencia,
    'descripcion': descripcion,
    'guardado_en': guardadoEn.toUtc().toIso8601String(),
    'estado': estado.name,
    'mensaje': mensaje,
    'intentos': intentos,
  };

  static OperacionBodega desdeMapa(Map<String, Object?> mapa) => OperacionBodega(
    id: mapa['id']! as String,
    tipo: TipoOperacion.values.byName(mapa['tipo']! as String),
    fecha: fechaDesdeIso(mapa['fecha']! as String),
    insumoId: mapa['insumo_id'] as int?,
    bodegaId: mapa['bodega_id'] as int?,
    haciaBodegaId: mapa['hacia_bodega_id'] as int?,
    bultos: (mapa['bultos'] as num?)?.toDouble(),
    kg: (mapa['kg'] as num?)?.toDouble(),
    loteId: mapa['lote_id'] as int?,
    tareaId: mapa['tarea_id'] as int?,
    pesoG: (mapa['peso_g'] as num?)?.toDouble(),
    aves: mapa['aves'] as int?,
    rubro: mapa['rubro'] as String?,
    valor: (mapa['valor'] as num?)?.toDouble(),
    categoriaId: mapa['categoria_id'] as int?,
    huevos: mapa['huevos'] as int?,
    contraparte: mapa['contraparte'] as String?,
    nota: mapa['nota'] as String?,
    lineas: (mapa['lineas'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(int.parse(k), v as int)),
    tipoVenta: mapa['tipo_venta'] as String?,
    referencia: mapa['referencia'] as String?,
    descripcion: mapa['descripcion']! as String,
    guardadoEn: DateTime.parse(mapa['guardado_en']! as String),
    estado: EstadoEnvio.values.byName(mapa['estado']! as String),
    mensaje: mapa['mensaje'] as String?,
    intentos: mapa['intentos']! as int,
  );
}

abstract interface class AlmacenOperaciones {
  Future<void> guardar(OperacionBodega operacion);
  Future<List<OperacionBodega>> porEnviar();
  Future<List<OperacionBodega>> sinResolver();
  Future<void> quitar(String id);
}

class AlmacenOperacionesEnMemoria implements AlmacenOperaciones {
  final _operaciones = <String, OperacionBodega>{};

  @override
  Future<void> guardar(OperacionBodega operacion) async => _operaciones[operacion.id] = operacion;

  @override
  Future<List<OperacionBodega>> porEnviar() async => _ordenadas((o) => o.estado == EstadoEnvio.pendiente);

  @override
  Future<List<OperacionBodega>> sinResolver() async => _ordenadas((o) => o.estado != EstadoEnvio.enviado);

  @override
  Future<void> quitar(String id) async => _operaciones.remove(id);

  List<OperacionBodega> _ordenadas(bool Function(OperacionBodega) filtro) =>
      _operaciones.values.where(filtro).toList()..sort((a, b) => a.guardadoEn.compareTo(b.guardadoEn));
}
