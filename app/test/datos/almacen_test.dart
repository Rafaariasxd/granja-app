import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/datos/almacen_sqlite.dart';
import 'package:granja_app/datos/base_local.dart';
import 'package:granja_app/datos/cola.dart';
import 'package:granja_app/dominio/modelos.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final manana = DateTime.utc(2026, 10, 15, 11);

CambioRegistro cambio(String id, {Duration despues = Duration.zero, int huevos = 4000}) => CambioRegistro(
  registro: RegistroDiario(
    id: id,
    galponId: 1,
    fecha: DateTime.utc(2026, 10, 15),
    huevosTotal: huevos,
    huevosRotos: 12,
    mortalidad: 3,
    alimentoKg: 280.5,
  ),
  guardadoEn: manana.add(despues),
);

void contrato(String nombre, Future<AlmacenCambios> Function() crear, Future<void> Function(AlmacenCambios) cerrar) {
  group(nombre, () {
    late AlmacenCambios almacen;

    setUp(() async => almacen = await crear());
    tearDown(() => cerrar(almacen));

    test('devuelve los pendientes en el orden en que se guardaron', () async {
      await almacen.guardar(cambio('b', despues: const Duration(minutes: 1)));
      await almacen.guardar(cambio('a'));
      expect((await almacen.porEnviar()).map((c) => c.registro.id), ['a', 'b']);
    });

    test('guardar el mismo registro lo reemplaza', () async {
      await almacen.guardar(cambio('a', huevos: 4000));
      await almacen.guardar(cambio('a', huevos: 4100));
      final todos = await almacen.todos();
      expect(todos, hasLength(1));
      expect(todos.single.registro.huevosTotal, 4100);
    });

    test('lo enviado sale de los pendientes pero se conserva', () async {
      await almacen.guardar(cambio('a').con(estado: EstadoEnvio.enviado));
      expect(await almacen.porEnviar(), isEmpty);
      expect((await almacen.todos()).single.estado, EstadoEnvio.enviado);
    });

    test('conserva todos los datos del registro y del envío', () async {
      await almacen.guardar(cambio('a').con(estado: EstadoEnvio.enConflicto, mensaje: 'ya hay un registro'));
      final guardado = (await almacen.todos()).single;
      expect(guardado.registro.fecha, DateTime.utc(2026, 10, 15));
      expect(guardado.registro.huevosRotos, 12);
      expect(guardado.registro.mortalidad, 3);
      expect(guardado.registro.alimentoKg, 280.5);
      expect(guardado.guardadoEn, manana);
      expect(guardado.mensaje, 'ya hay un registro');
      expect(guardado.intentos, 1);
    });
  });
}

void main() {
  sqfliteFfiInit();
  Database? db;
  contrato('en memoria', () async => AlmacenEnMemoria(), (_) async {});
  contrato('en SQLite', () async {
    db = await abrirBaseLocal(databaseFactoryFfi, inMemoryDatabasePath);
    return AlmacenSqlite(db!);
  }, (_) async => db?.close());
}
