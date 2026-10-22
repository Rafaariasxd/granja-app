import 'package:flutter/foundation.dart';

import '../datos/api_granja.dart';
import '../datos/resumen.dart';
import '../dominio/fechas.dart';
import '../dominio/resumen_dia.dart';

class EstadoInicio extends ChangeNotifier {
  EstadoInicio(this._repositorio, {DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now;

  final RepositorioResumen _repositorio;
  final DateTime Function() _reloj;

  ResumenGuardado? _datos;
  bool _cargando = false;
  bool _sesionVencida = false;

  bool get cargando => _cargando;
  bool get sesionVencida => _sesionVencida;
  bool get sinDatos => _datos == null;
  bool get sinSenal => _datos?.copiaLocal ?? false;
  DateTime get hoy => fechaEnGranja(_reloj());
  ResumenDelDia? get resumen => _datos == null ? null : ResumenDelDia(_datos!.galpones);

  Future<void> cargar() async {
    if (_cargando) return;
    _cargando = true;
    _sesionVencida = false;
    notifyListeners();
    try {
      final ahora = _reloj();
      _datos = await _repositorio.resumen(fechaEnGranja(ahora), ahora) ?? _datos;
    } on SesionVencida {
      _sesionVencida = true;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}
