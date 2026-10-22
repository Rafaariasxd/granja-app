import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/almacen_sqlite.dart';
import 'package:granja_app/datos/api_granja.dart';
import 'package:granja_app/datos/base_local.dart';
import 'package:granja_app/datos/resumen.dart';
import 'package:granja_app/dominio/modelos.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final hoy = DateTime.utc(2026, 10, 21);
final alas7 = DateTime.utc(2026, 10, 21, 12, 10);

const conLote = ResumenGalpon(
  galponId: 1,
  nombre: 'Galpón 1',
  capacidadAves: 6000,
  avesVivas: 2476,
  ocupacionPct: 41.3,
  loteId: 7,
  etapa: Etapa.produccion,
  edadSemanas: 32,
  posturaPct: 86,
  linea: 'Hy-Line',
  huevosDelDia: 2130,
);
const vacio = ResumenGalpon(galponId: 2, nombre: 'Galpón 2', capacidadAves: 2000, avesVivas: 0, ocupacionPct: 0);

final jsonDelServidor = [
  {
    'galpon_id': 1,
    'nombre': 'Galpón 1',
    'capacidad_aves': 6000,
    'lote_id': 7,
    'etapa': 'produccion',
    'edad_semanas': 32,
    'aves_vivas': 2476,
    'ocupacion_pct': 41.3,
    'postura_pct': 86.0,
    'linea': 'Hy-Line',
    'huevos_del_dia': 2130,
  },
];

void contrato(String nombre, Future<AlmacenResumen> Function() crear, Future<void> Function() cerrar) {
  group(nombre, () {
    late AlmacenResumen almacen;

    setUp(() async => almacen = await crear());
    tearDown(cerrar);

    test('sin nada guardado no hay copia', () async {
      expect(await almacen.ultimo(), isNull);
    });

    test('devuelve el último resumen con todos sus datos', () async {
      await almacen.guardar(ResumenGuardado(fecha: hoy, actualizadoEn: alas7, galpones: const [conLote, vacio]));
      final guardado = (await almacen.ultimo())!;
      expect(guardado.fecha, hoy);
      expect(guardado.actualizadoEn, alas7);
      expect(guardado.galpones.first.etapa, Etapa.produccion);
      expect(guardado.galpones.first.posturaPct, 86);
      expect(guardado.galpones.last.vacio, isTrue);
      expect(guardado.galpones.last.posturaPct, isNull);
    });

    test('guardar otro resumen reemplaza el anterior', () async {
      await almacen.guardar(ResumenGuardado(fecha: hoy, actualizadoEn: alas7, galpones: const [conLote]));
      await almacen.guardar(ResumenGuardado(fecha: hoy, actualizadoEn: alas7, galpones: const [vacio]));
      expect((await almacen.ultimo())!.galpones.single.nombre, 'Galpón 2');
    });
  });
}

void main() {
  sqfliteFfiInit();
  Database? db;
  contrato('en memoria', () async => AlmacenResumenEnMemoria(), () async {});
  contrato('en SQLite', () async {
    db = await abrirBaseLocal(databaseFactoryFfi, inMemoryDatabasePath);
    return AlmacenResumenSqlite(db!);
  }, () async => db?.close());

  group('repositorio', () {
    late AlmacenResumenEnMemoria almacen;

    setUp(() => almacen = AlmacenResumenEnMemoria());

    RepositorioResumen con(Future<http.Response> Function(http.Request) servidor) =>
        RepositorioResumen(ApiGranja(Uri.parse('http://granja.test/'), cliente: MockClient(servidor)), almacen);

    test('con señal trae el resumen y lo guarda en el celular', () async {
      final repo = con((_) async => http.Response.bytes(utf8.encode(jsonEncode(jsonDelServidor)), 200));
      final resumen = (await repo.resumen(hoy, alas7))!;
      expect(resumen.copiaLocal, isFalse);
      expect(resumen.galpones.single.avesVivas, 2476);
      expect((await almacen.ultimo())!.galpones.single.nombre, 'Galpón 1');
    });

    test('sin señal muestra la última copia y avisa que es del celular', () async {
      await almacen.guardar(ResumenGuardado(fecha: hoy, actualizadoEn: alas7, galpones: const [conLote]));
      final repo = con((_) async => throw http.ClientException('sin red'));
      final resumen = (await repo.resumen(hoy, alas7.add(const Duration(hours: 3))))!;
      expect(resumen.copiaLocal, isTrue);
      expect(resumen.actualizadoEn, alas7);
      expect(resumen.galpones.single.nombre, 'Galpón 1');
    });

    test('sin señal y sin copia no hay resumen', () async {
      final repo = con((_) async => throw http.ClientException('sin red'));
      expect(await repo.resumen(hoy, alas7), isNull);
    });

    test('si el servidor falla también muestra la copia', () async {
      await almacen.guardar(ResumenGuardado(fecha: hoy, actualizadoEn: alas7, galpones: const [conLote]));
      final repo = con((_) async => http.Response('falló', 500));
      expect((await repo.resumen(hoy, alas7))!.copiaLocal, isTrue);
    });
  });
}
