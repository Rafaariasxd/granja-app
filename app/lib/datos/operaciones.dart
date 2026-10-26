import 'cola.dart';
import 'json.dart';

enum TipoOperacion { compra, preparacion, gasto }

class OperacionBodega {
  const OperacionBodega({
    required this.id,
    required this.tipo,
    required this.fecha,
    required this.insumoId,
    required this.bodegaId,
    required this.descripcion,
    required this.guardadoEn,
    this.haciaBodegaId,
    this.bultos,
    this.kg,
    this.estado = EstadoEnvio.pendiente,
    this.mensaje,
    this.intentos = 0,
  });

  final String id;
  final TipoOperacion tipo;
  final DateTime fecha;
  final int insumoId;
  final int bodegaId;
  final int? haciaBodegaId;
  final double? bultos;
  final double? kg;
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
    insumoId: mapa['insumo_id']! as int,
    bodegaId: mapa['bodega_id']! as int,
    haciaBodegaId: mapa['hacia_bodega_id'] as int?,
    bultos: (mapa['bultos'] as num?)?.toDouble(),
    kg: (mapa['kg'] as num?)?.toDouble(),
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
