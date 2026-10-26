import 'package:flutter_test/flutter_test.dart';
import 'package:granja_app/dominio/huevos.dart';

const precio = PrecioHuevo(categoriaId: 1, precioCaja: 120000, precioCarton: 12000, precioMayorista: 108000);

void main() {
  test('una caja son 12 cartones y un cartón son 30 huevos', () {
    expect(aHuevos(cajas: 1), 360);
    expect(aHuevos(cajas: 3, cartones: 3), 1170);
    expect(aHuevos(cartones: 26), 780);
  });

  test('26 cartones se ven como 2 cajas y 2 cartones', () {
    final e = empacar(780);
    expect((e.cajas, e.cartones, e.sueltos), (2, 2, 0));
    expect(empaqueTexto(780), '2 cajas y 2 cartones');
  });

  test('el texto nombra solo lo que hay y en singular cuando es uno', () {
    expect(empaqueTexto(0), 'Nada');
    expect(empaqueTexto(360), '1 caja');
    expect(empaqueTexto(30), '1 cartón');
    expect(empaqueTexto(15), '15 huevos');
    expect(empaqueTexto(360 + 30 + 1), '1 caja, 1 cartón y 1 huevo');
    expect(empaqueTexto(3 * 360 + 3 * 30), '3 cajas y 3 cartones');
    expect(empaqueTexto(-60), 'Faltan 2 cartones');
  });

  test('el cliente paga la caja entre 12, el particular el cartón y el mayorista su precio', () {
    final cuatroCartones = aHuevos(cartones: 4);
    expect(precioDeLosHuevos(cuatroCartones, TipoVenta.cliente, precio), 40000);
    expect(precioDeLosHuevos(cuatroCartones, TipoVenta.particular, precio), 48000);
    expect(precioDeLosHuevos(cuatroCartones, TipoVenta.mayorista, precio), 36000);
    expect(precioDeLosHuevos(cuatroCartones, TipoVenta.cliente, null), isNull);
    expect(precioDeLosHuevos(0, TipoVenta.cliente, precio), isNull);
  });

  test('el total sugerido suma todas las categorías o no hay sugerencia si falta un precio', () {
    final precios = {1: precio, 2: const PrecioHuevo(categoriaId: 2, precioCaja: 96000)};
    expect(totalSugerido({1: 360, 2: 180}, TipoVenta.cliente, precios), 168000);
    expect(totalSugerido({1: 360, 2: 180}, TipoVenta.particular, precios), isNull);
    expect(totalSugerido({1: 360, 2: 0}, TipoVenta.particular, precios), 144000);
  });

  test('la bodega suma y busca por categoría', () {
    const bodega = BodegaHuevo(
      existencias: [
        ExistenciaHuevo(categoriaId: 1, categoria: 'AA', activa: true, huevos: 720),
        ExistenciaHuevo(categoriaId: 2, categoria: 'A', activa: true, huevos: 30),
      ],
      precios: [precio],
      abiertas: [],
    );
    expect(bodega.total, 750);
    expect(bodega.nombreDe(2), 'A');
    expect(bodega.huevosDe(1), 720);
    expect(bodega.huevosDe(9), 0);
    expect(bodega.preciosPorCategoria[1], same(precio));
  });
}
