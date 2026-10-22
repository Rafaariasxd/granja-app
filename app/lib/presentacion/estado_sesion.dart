import 'package:flutter/foundation.dart';

import '../datos/api_granja.dart';
import '../datos/servicio_sesion.dart';
import '../dominio/sesion.dart';

class EstadoSesion extends ChangeNotifier {
  EstadoSesion(this._servicio);

  final ServicioSesion _servicio;

  bool _cargando = true;
  bool _entrando = false;
  String? _error;

  bool get cargando => _cargando;
  bool get entrando => _entrando;
  String? get error => _error;
  Sesion? get sesion => _servicio.actual;

  Future<void> iniciar() async {
    await _servicio.restaurar();
    _cargando = false;
    notifyListeners();
  }

  Future<void> entrar(String nombre, String pin) async {
    if (_entrando) return;
    _entrando = true;
    _error = null;
    notifyListeners();
    try {
      await _servicio.entrar(nombre, pin);
    } on SinConexion {
      _error = 'Sin señal. La primera vez en este teléfono hace falta conexión para entrar.';
    } on CredencialesInvalidas {
      _error = 'Nombre o PIN incorrectos.';
    } on ErrorDeApi catch (error) {
      _error = error.mensaje;
    } finally {
      _entrando = false;
      notifyListeners();
    }
  }

  Future<void> salir() async {
    await _servicio.salir();
    _error = null;
    notifyListeners();
  }

  Future<void> sesionVencida() async {
    await _servicio.descartar();
    _error = 'La sesión se cerró. Vuelve a entrar.';
    notifyListeners();
  }
}
