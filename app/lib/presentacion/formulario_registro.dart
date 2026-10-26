import 'dart:math';

import 'package:flutter/foundation.dart';

import '../dominio/ids.dart';
import '../dominio/modelos.dart';
import '../dominio/produccion.dart';

class FormularioRegistro extends ChangeNotifier {
  FormularioRegistro({required this.galpon, required this.fecha, RegistroDiario? anterior, this.kgPorBulto})
    : id = anterior?.id ?? nuevoIdRegistro(),
      _huevos = anterior?.huevosTotal ?? 0,
      _rotos = anterior?.huevosRotos ?? 0,
      _muertas = anterior?.mortalidad ?? 0,
      _alimentoKg = anterior?.alimentoKg ?? 0;

  final ResumenGalpon galpon;
  final DateTime fecha;
  final double? kgPorBulto;
  final String id;
  int _huevos;
  int _rotos;
  int _muertas;
  double _alimentoKg;

  int get huevos => _huevos;
  int get rotos => _rotos;
  int get muertas => _muertas;
  double get alimentoKg => _alimentoKg;
  double? get bultos => kgPorBulto == null ? null : _alimentoKg / kgPorBulto!;

  double get postura => posturaPct(_huevos, galpon.avesVivas);

  List<String> get errores => [
    if (_rotos > _huevos) 'Los huevos rotos no pueden ser más que los recogidos.',
    if (_muertas > galpon.avesVivas) 'Las gallinas muertas no pueden ser más que las aves del galpón.',
  ];

  bool get esValido => errores.isEmpty;

  void cambiarHuevos(int valor) => _cambiar(() => _huevos = max(valor, 0));

  void sumarRotos(int cambio) => _cambiar(() => _rotos = max(_rotos + cambio, 0));

  void sumarMuertas(int cambio) => _cambiar(() => _muertas = max(_muertas + cambio, 0));

  void cambiarAlimento(double kg) => _cambiar(() => _alimentoKg = max(kg, 0));

  void sumarMediosBultos(int cambio) => cambiarAlimento(_alimentoKg + cambio * 0.5 * kgPorBulto!);

  RegistroDiario aRegistro() {
    if (!esValido) throw StateError(errores.join(' '));
    return RegistroDiario(
      id: id,
      galponId: galpon.galponId,
      fecha: fecha,
      huevosTotal: _huevos,
      huevosRotos: _rotos,
      mortalidad: _muertas,
      alimentoKg: _alimentoKg,
    );
  }

  void _cambiar(void Function() cambio) {
    cambio();
    notifyListeners();
  }
}
