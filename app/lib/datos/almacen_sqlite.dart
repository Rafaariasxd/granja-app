import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../dominio/modelos.dart';
import 'bodega.dart';
import 'cola.dart';
import 'json.dart';
import 'operaciones.dart';
import 'resumen.dart';

class AlmacenSqlite implements AlmacenCambios {
  AlmacenSqlite(this._db);

  final Database _db;

  @override
  Future<void> guardar(CambioRegistro cambio) async {
    await _db.insert('cambios', _cambioAFila(cambio), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<CambioRegistro>> porEnviar() async {
    final filas = await _db.query(
      'cambios',
      where: 'estado = ?',
      whereArgs: [EstadoEnvio.pendiente.name],
      orderBy: 'guardado_en',
    );
    return filas.map(_cambioDesdeFila).toList();
  }

  @override
  Future<List<CambioRegistro>> todos() async {
    final filas = await _db.query('cambios', orderBy: 'guardado_en');
    return filas.map(_cambioDesdeFila).toList();
  }
}

class AlmacenResumenSqlite implements AlmacenResumen {
  AlmacenResumenSqlite(this._db);

  final Database _db;

  @override
  Future<void> guardar(ResumenGuardado resumen) async {
    await _db.insert('resumen', {
      'id': 1,
      'fecha': fechaIso(resumen.fecha),
      'actualizado_en': resumen.actualizadoEn.toUtc().toIso8601String(),
      'galpones': jsonEncode(resumen.galpones.map(resumenAJson).toList()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<ResumenGuardado?> ultimo() async {
    final filas = await _db.query('resumen', where: 'id = ?', whereArgs: [1]);
    if (filas.isEmpty) return null;
    final fila = filas.single;
    final galpones = jsonDecode(fila['galpones']! as String) as List<dynamic>;
    return ResumenGuardado(
      fecha: fechaDesdeIso(fila['fecha']! as String),
      actualizadoEn: DateTime.parse(fila['actualizado_en']! as String),
      galpones: [for (final g in galpones) resumenDesdeJson(g as Map<String, dynamic>)],
    );
  }
}

class AlmacenBodegaSqlite implements AlmacenBodega {
  AlmacenBodegaSqlite(this._db);

  final Database _db;

  @override
  Future<void> guardar(BodegaGuardada bodega) async {
    await _db.insert('bodega', {
      'id': 1,
      'actualizado_en': bodega.actualizadoEn.toUtc().toIso8601String(),
      'datos': bodega.datos,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<BodegaGuardada?> ultima() async {
    final filas = await _db.query('bodega', where: 'id = ?', whereArgs: [1]);
    if (filas.isEmpty) return null;
    return BodegaGuardada(
      actualizadoEn: DateTime.parse(filas.single['actualizado_en']! as String),
      datos: filas.single['datos']! as String,
    );
  }
}

class AlmacenOperacionesSqlite implements AlmacenOperaciones {
  AlmacenOperacionesSqlite(this._db);

  final Database _db;

  @override
  Future<void> guardar(OperacionBodega operacion) async {
    await _db.insert('operaciones', {
      'id': operacion.id,
      'guardado_en': operacion.guardadoEn.toUtc().toIso8601String(),
      'estado': operacion.estado.name,
      'datos': jsonEncode(operacion.aMapa()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<OperacionBodega>> porEnviar() => _consultar('estado = ?', [EstadoEnvio.pendiente.name]);

  @override
  Future<List<OperacionBodega>> sinResolver() => _consultar('estado != ?', [EstadoEnvio.enviado.name]);

  @override
  Future<void> quitar(String id) async {
    await _db.delete('operaciones', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<OperacionBodega>> _consultar(String donde, List<Object> argumentos) async {
    final filas = await _db.query('operaciones', where: donde, whereArgs: argumentos, orderBy: 'guardado_en');
    return [
      for (final fila in filas) OperacionBodega.desdeMapa(jsonDecode(fila['datos']! as String) as Map<String, dynamic>),
    ];
  }
}

Map<String, Object?> _cambioAFila(CambioRegistro cambio) {
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

CambioRegistro _cambioDesdeFila(Map<String, Object?> fila) => CambioRegistro(
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
