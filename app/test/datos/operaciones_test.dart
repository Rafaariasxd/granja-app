import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/almacen_sqlite.dart';
import 'package:granja_app/datos/base_local.dart';
import 'package:granja_app/datos/cola.dart';
import 'package:granja_app/datos/operaciones.dart';
import 'package:granja_app/datos/sanidad.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final momento = DateTime.utc(2026, 10, 25, 14);

OperacionBodega compra(String id, {Duration despues = Duration.zero}) => OperacionBodega(
  id: id,
  tipo: TipoOperacion.compra,
  fecha: DateTime.utc(2026, 10, 25),
  insumoId: 1,
  bodegaId: 3,
  bultos: 1.5,
  descripcion: '1 bulto y medio de Maíz',
  guardadoEn: momento.add(despues),
);

OperacionBodega preparacion(String id) => OperacionBodega(
  id: id,
  tipo: TipoOperacion.preparacion,
  fecha: DateTime.utc(2026, 10, 25),
  insumoId: 7,
  bodegaId: 3,
  haciaBodegaId: 2,
  kg: 500,
  descripcion: '500 kg de Mezcla ponedora',
  guardadoEn: momento,
);

void contrato(
  String nombre,
  Future<AlmacenOperaciones> Function() crear,
  Future<void> Function(AlmacenOperaciones) cerrar,
) {
  group(nombre, () {
    late AlmacenOperaciones almacen;

    setUp(() async => almacen = await crear());
    tearDown(() => cerrar(almacen));

    test('devuelve lo pendiente en el orden en que se guardó', () async {
      await almacen.guardar(compra('b', despues: const Duration(minutes: 1)));
      await almacen.guardar(compra('a'));
      expect((await almacen.porEnviar()).map((o) => o.id), ['a', 'b']);
    });

    test('conserva todos los datos de una compra y de una preparación', () async {
      await almacen.guardar(compra('a'));
      await almacen.guardar(preparacion('b'));
      final todas = await almacen.sinResolver();
      final c = todas.firstWhere((o) => o.id == 'a');
      expect(
        (c.tipo, c.insumoId, c.bodegaId, c.bultos, c.kg, c.haciaBodegaId),
        (TipoOperacion.compra, 1, 3, 1.5, null, null),
      );
      expect(c.fecha, DateTime.utc(2026, 10, 25));
      expect(c.descripcion, '1 bulto y medio de Maíz');
      expect(c.guardadoEn, momento);
      final p = todas.firstWhere((o) => o.id == 'b');
      expect(
        (p.tipo, p.insumoId, p.bodegaId, p.haciaBodegaId, p.kg, p.bultos),
        (TipoOperacion.preparacion, 7, 3, 2, 500, null),
      );
    });

    test('lo rechazado no se reintenta pero sigue a la vista con su motivo', () async {
      await almacen.guardar(compra('a').con(estado: EstadoEnvio.rechazado, mensaje: 'no alcanza'));
      expect(await almacen.porEnviar(), isEmpty);
      final vista = (await almacen.sinResolver()).single;
      expect((vista.estado, vista.mensaje, vista.intentos), (EstadoEnvio.rechazado, 'no alcanza', 1));
    });

    test('conserva los datos de una vacuna y de un pesaje', () async {
      await almacen.guardar(
        OperacionBodega(
          id: 'v',
          tipo: TipoOperacion.aplicacion,
          fecha: DateTime.utc(2026, 10, 24),
          loteId: 4,
          tareaId: 9,
          descripcion: 'Gumboro en Galpón 5',
          guardadoEn: momento,
        ),
      );
      await almacen.guardar(
        OperacionBodega(
          id: 'p',
          tipo: TipoOperacion.pesaje,
          fecha: DateTime.utc(2026, 10, 25),
          loteId: 4,
          pesoG: 1020.5,
          aves: 40,
          descripcion: 'Pesaje de Galpón 5: 1021 g',
          guardadoEn: momento.add(const Duration(minutes: 1)),
        ),
      );
      final todas = await almacen.sinResolver();
      expect(todas.map((o) => o.id), ['v', 'p']);
      expect((todas[0].loteId, todas[0].tareaId, todas[0].insumoId), (4, 9, null));
      expect((todas[1].pesoG, todas[1].aves, todas[1].tareaId), (1020.5, 40, null));
    });

    test('quitar borra la operación', () async {
      await almacen.guardar(compra('a'));
      await almacen.quitar('a');
      expect(await almacen.sinResolver(), isEmpty);
    });

    test('guardar la misma operación la reemplaza', () async {
      await almacen.guardar(compra('a'));
      await almacen.guardar(compra('a').con(estado: EstadoEnvio.pendiente, mensaje: 'sin señal'));
      final todas = await almacen.sinResolver();
      expect(todas, hasLength(1));
      expect(todas.single.mensaje, 'sin señal');
    });
  });
}

void main() {
  sqfliteFfiInit();

  contrato('memoria', () async => AlmacenOperacionesEnMemoria(), (_) async {});

  late Database base;
  contrato('sqlite', () async {
    base = await abrirBaseLocal(databaseFactoryFfi, inMemoryDatabasePath);
    return AlmacenOperacionesSqlite(base);
  }, (_) => base.close());

  test('el almacén de sanidad guarda solo la última copia', () async {
    final almacen = AlmacenSanidadEnMemoria();
    expect(await almacen.ultima(), isNull);
    await almacen.guardar(SanidadGuardada(actualizadoEn: momento, datos: 'a'));
    await almacen.guardar(SanidadGuardada(actualizadoEn: momento.add(const Duration(hours: 1)), datos: 'b'));
    expect((await almacen.ultima())!.datos, 'b');
  });

  test('el almacén de sanidad en sqlite recuerda la última copia', () async {
    final db = await abrirBaseLocal(databaseFactoryFfi, inMemoryDatabasePath);
    final almacen = AlmacenSanidadSqlite(db);
    expect(await almacen.ultima(), isNull);
    await almacen.guardar(SanidadGuardada(actualizadoEn: momento, datos: '{"a":1}'));
    await almacen.guardar(SanidadGuardada(actualizadoEn: momento.add(const Duration(hours: 1)), datos: '{"a":2}'));
    final ultima = (await almacen.ultima())!;
    expect((ultima.datos, ultima.actualizadoEn), ('{"a":2}', momento.add(const Duration(hours: 1))));
    await db.close();
  });

  test('una base de la versión anterior gana la tabla de operaciones al abrirse', () async {
    final carpeta = Directory.systemTemp.createTempSync('granja_');
    addTearDown(() => carpeta.deleteSync(recursive: true));
    final ruta = '${carpeta.path}/vieja.db';
    final vieja = await databaseFactoryFfi.openDatabase(ruta, options: OpenDatabaseOptions(version: 1));
    expect(await vieja.query('sqlite_master', where: "name = 'operaciones'"), isEmpty);
    await vieja.close();

    final nueva = await abrirBaseLocal(databaseFactoryFfi, ruta);
    expect(await nueva.query('sqlite_master', where: "name = 'operaciones'"), hasLength(1));
    expect(await nueva.query('sqlite_master', where: "name = 'sanidad'"), hasLength(1));
    await nueva.close();
  });
}
