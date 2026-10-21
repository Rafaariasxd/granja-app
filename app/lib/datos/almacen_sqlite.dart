import 'package:sqflite/sqflite.dart';

import '../dominio/modelos.dart';
import 'cola.dart';
import 'json.dart';

const _crearTabla = '''
CREATE TABLE cambios (
  id TEXT PRIMARY KEY,
  galpon_id INTEGER NOT NULL,
  fecha TEXT NOT NULL,
  huevos_total INTEGER NOT NULL,
  huevos_rotos INTEGER NOT NULL,
  mortalidad INTEGER NOT NULL,
  alimento_kg REAL NOT NULL,
  guardado_en TEXT NOT NULL,
  estado TEXT NOT NULL,
  mensaje TEXT,
  intentos INTEGER NOT NULL
)
''';

class AlmacenSqlite implements AlmacenCambios {
  AlmacenSqlite._(this._db);

  final Database _db;

  static Future<AlmacenSqlite> abrir(DatabaseFactory fabrica, String ruta) async {
    final db = await fabrica.openDatabase(
      ruta,
      options: OpenDatabaseOptions(version: 1, onCreate: (db, _) => db.execute(_crearTabla)),
    );
    return AlmacenSqlite._(db);
  }

  Future<void> cerrar() => _db.close();

  @override
  Future<void> guardar(CambioRegistro cambio) async {
    await _db.insert('cambios', _aFila(cambio), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<CambioRegistro>> porEnviar() async {
    final filas = await _db.query(
      'cambios',
      where: 'estado = ?',
      whereArgs: [EstadoEnvio.pendiente.name],
      orderBy: 'guardado_en',
    );
    return filas.map(_desdeFila).toList();
  }

  @override
  Future<List<CambioRegistro>> todos() async {
    final filas = await _db.query('cambios', orderBy: 'guardado_en');
    return filas.map(_desdeFila).toList();
  }
}

Map<String, Object?> _aFila(CambioRegistro cambio) {
  final registro = cambio.registro;
  return {
    'id': registro.id,
    'galpon_id': registro.galponId,
    'fecha': fechaIso(registro.fecha),
    'huevos_total': registro.huevosTotal,
    'huevos_rotos': registro.huevosRotos,
    'mortalidad': registro.mortalidad,
    'alimento_kg': registro.alimentoKg,
    'guardado_en': cambio.guardadoEn.toUtc().toIso8601String(),
    'estado': cambio.estado.name,
    'mensaje': cambio.mensaje,
    'intentos': cambio.intentos,
  };
}

CambioRegistro _desdeFila(Map<String, Object?> fila) => CambioRegistro(
  registro: RegistroDiario(
    id: fila['id']! as String,
    galponId: fila['galpon_id']! as int,
    fecha: fechaDesdeIso(fila['fecha']! as String),
    huevosTotal: fila['huevos_total']! as int,
    huevosRotos: fila['huevos_rotos']! as int,
    mortalidad: fila['mortalidad']! as int,
    alimentoKg: (fila['alimento_kg']! as num).toDouble(),
  ),
  guardadoEn: DateTime.parse(fila['guardado_en']! as String),
  estado: EstadoEnvio.values.byName(fila['estado']! as String),
  mensaje: fila['mensaje'] as String?,
  intentos: fila['intentos']! as int,
);
