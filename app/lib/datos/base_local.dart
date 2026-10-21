import 'package:sqflite/sqflite.dart';

const _tablas = [
  '''
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
''',
  '''
CREATE TABLE resumen (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  fecha TEXT NOT NULL,
  actualizado_en TEXT NOT NULL,
  galpones TEXT NOT NULL
)
''',
];

Future<Database> abrirBaseLocal(DatabaseFactory fabrica, String ruta) => fabrica.openDatabase(
  ruta,
  options: OpenDatabaseOptions(
    version: 1,
    onCreate: (db, _) async {
      for (final sql in _tablas) {
        await db.execute(sql);
      }
    },
  ),
);
