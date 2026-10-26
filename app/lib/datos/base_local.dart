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
  '''
CREATE TABLE bodega (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  actualizado_en TEXT NOT NULL,
  datos TEXT NOT NULL
)
''',
  '''
CREATE TABLE operaciones (
  id TEXT PRIMARY KEY,
  guardado_en TEXT NOT NULL,
  estado TEXT NOT NULL,
  datos TEXT NOT NULL
)
''',
  '''
CREATE TABLE sanidad (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  actualizado_en TEXT NOT NULL,
  datos TEXT NOT NULL
)
''',
  '''
CREATE TABLE finanzas (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  actualizado_en TEXT NOT NULL,
  datos TEXT NOT NULL
)
''',
];

Future<Database> abrirBaseLocal(DatabaseFactory fabrica, String ruta) => fabrica.openDatabase(
  ruta,
  options: OpenDatabaseOptions(
    version: 5,
    onCreate: (db, _) async {
      for (final sql in _tablas) {
        await db.execute(sql);
      }
    },
    onUpgrade: (db, anterior, _) async {
      if (anterior < 2) await db.execute(_tablas[2]);
      if (anterior < 3) await db.execute(_tablas[3]);
      if (anterior < 4) await db.execute(_tablas[4]);
      if (anterior < 5) await db.execute(_tablas[5]);
    },
  ),
);
