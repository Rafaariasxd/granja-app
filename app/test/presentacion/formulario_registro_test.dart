import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/dominio/modelos.dart';
import 'package:granja_app/presentacion/formulario_registro.dart';

const galpon = ResumenGalpon(
  galponId: 3,
  nombre: 'Galpón 3',
  capacidadAves: 4000,
  avesVivas: 1612,
  ocupacionPct: 40.3,
  loteId: 2,
  etapa: Etapa.produccion,
  edadSemanas: 45,
);
final hoy = DateTime.utc(2026, 10, 21);

void main() {
  test('un registro nuevo arranca en cero y con su propio id', () {
    final a = FormularioRegistro(galpon: galpon, fecha: hoy);
    final b = FormularioRegistro(galpon: galpon, fecha: hoy);
    expect(a.huevos, 0);
    expect(a.id, isNot(b.id));
  });

  test('corregir un registro conserva su id, para que el servidor lo actualice', () {
    final anterior = RegistroDiario(id: 'id-de-ayer', galponId: 3, fecha: hoy, huevosTotal: 1398, mortalidad: 2);
    final formulario = FormularioRegistro(galpon: galpon, fecha: hoy, anterior: anterior);
    expect(formulario.id, 'id-de-ayer');
    expect(formulario.huevos, 1398);
    expect(formulario.muertas, 2);
  });

  test('la postura se calcula mientras se escribe', () {
    final formulario = FormularioRegistro(galpon: galpon, fecha: hoy)..cambiarHuevos(1405);
    expect(formulario.postura, 87.2);
  });

  test('los contadores no bajan de cero', () {
    final formulario = FormularioRegistro(galpon: galpon, fecha: hoy)
      ..sumarRotos(-1)
      ..sumarMuertas(-1)
      ..cambiarHuevos(-5)
      ..cambiarAlimento(-3);
    expect([formulario.rotos, formulario.muertas, formulario.huevos], [0, 0, 0]);
    expect(formulario.alimentoKg, 0);
  });

  test('más rotos que recogidos no se puede guardar', () {
    final formulario = FormularioRegistro(galpon: galpon, fecha: hoy)
      ..cambiarHuevos(5)
      ..sumarRotos(6);
    expect(formulario.esValido, isFalse);
    expect(formulario.aRegistro, throwsStateError);
  });

  test('más muertas que aves vivas no se puede guardar', () {
    final formulario = FormularioRegistro(galpon: galpon, fecha: hoy)..sumarMuertas(1613);
    expect(formulario.errores, ['Las gallinas muertas no pueden ser más que las aves del galpón.']);
  });

  test('avisa a la pantalla cada vez que cambia un dato', () {
    var avisos = 0;
    final formulario = FormularioRegistro(galpon: galpon, fecha: hoy)..addListener(() => avisos++);
    formulario
      ..cambiarHuevos(10)
      ..sumarRotos(1)
      ..sumarMuertas(1)
      ..cambiarAlimento(180);
    expect(avisos, 4);
  });

  test('arma el registro con el galpón y la fecha del formulario', () {
    final registro =
        (FormularioRegistro(galpon: galpon, fecha: hoy)
              ..cambiarHuevos(1405)
              ..sumarRotos(9)
              ..sumarMuertas(1)
              ..cambiarAlimento(180))
            .aRegistro();
    expect(registro.galponId, 3);
    expect(registro.fecha, hoy);
    expect([registro.huevosTotal, registro.huevosRotos, registro.mortalidad], [1405, 9, 1]);
    expect(registro.alimentoKg, 180);
  });
}
