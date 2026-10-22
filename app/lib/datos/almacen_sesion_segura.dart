import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../dominio/sesion.dart';
import 'servicio_sesion.dart';

class AlmacenSesionSegura implements AlmacenSesion {
  AlmacenSesionSegura([FlutterSecureStorage? almacen]) : _almacen = almacen ?? const FlutterSecureStorage();

  final FlutterSecureStorage _almacen;

  static const _claves = ['token', 'nombre', 'rol'];

  @override
  Future<Sesion?> leer() async {
    final valores = <String, String?>{for (final clave in _claves) clave: await _almacen.read(key: clave)};
    return Sesion.desdeMapa(valores);
  }

  @override
  Future<void> guardar(Sesion sesion) async {
    for (final entrada in sesion.aMapa().entries) {
      await _almacen.write(key: entrada.key, value: entrada.value);
    }
  }

  @override
  Future<void> borrar() async {
    for (final clave in _claves) {
      await _almacen.delete(key: clave);
    }
  }
}
