import '../dominio/sesion.dart';
import 'api_granja.dart';

abstract interface class AlmacenSesion {
  Future<Sesion?> leer();
  Future<void> guardar(Sesion sesion);
  Future<void> borrar();
}

class AlmacenSesionEnMemoria implements AlmacenSesion {
  Sesion? _sesion;

  @override
  Future<Sesion?> leer() async => _sesion;

  @override
  Future<void> guardar(Sesion sesion) async => _sesion = sesion;

  @override
  Future<void> borrar() async => _sesion = null;
}

class ServicioSesion {
  ServicioSesion(this._api, this._almacen);

  final ApiGranja _api;
  final AlmacenSesion _almacen;

  Sesion? actual;

  Future<Sesion?> restaurar() async {
    actual = await _almacen.leer();
    _api.token = actual?.token;
    return actual;
  }

  Future<Sesion> entrar(String nombre, String pin) async {
    final sesion = await _api.iniciarSesion(nombre.trim(), pin);
    await _almacen.guardar(sesion);
    actual = sesion;
    return sesion;
  }

  Future<void> salir() async {
    await _api.cerrarSesion();
    await _almacen.borrar();
    actual = null;
  }

  Future<void> descartar() async {
    _api.token = null;
    await _almacen.borrar();
    actual = null;
  }
}
