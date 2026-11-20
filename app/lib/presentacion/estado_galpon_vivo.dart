import 'dart:async';

import 'package:flutter/foundation.dart';

import '../datos/api_iot.dart';
import '../dominio/galpon_vivo.dart';

class EstadoGalponVivo extends ChangeNotifier {
  EstadoGalponVivo(this._api, this._almacen, {this.cada = const Duration(seconds: 30)});

  final ApiIot _api;
  final AlmacenClaveIot _almacen;
  final Duration cada;

  List<DispositivoIot> _dispositivos = const [];
  List<AlertaIot> _alertas = const [];
  bool _cargando = false;
  String? _error;
  DateTime? _actualizado;
  Timer? _reloj;
  int _mirando = 0;
  bool _cerrado = false;

  List<DispositivoIot> get dispositivos => _dispositivos;
  List<AlertaIot> get alertas => _alertas;
  bool get cargando => _cargando;
  String? get error => _error;
  DateTime? get actualizado => _actualizado;
  int get enLinea => _dispositivos.where((d) => d.enLinea).length;
  List<GrupoIot> get grupos => agruparDispositivos(_dispositivos);

  DispositivoIot? dispositivo(String id) {
    for (final d in _dispositivos) {
      if (d.id == id) return d;
    }
    return null;
  }

  double? valor(String dispositivo, String variable) => this.dispositivo(dispositivo)?.valor(variable);

  Future<void> cargar() async {
    if (_cargando) return;
    _cargando = true;
    _avisar();
    try {
      final resultados = await Future.wait([_api.dispositivos(), _api.alertasActivas()]);
      _dispositivos = resultados[0] as List<DispositivoIot>;
      _alertas = resultados[1] as List<AlertaIot>;
      _actualizado = DateTime.now();
      _error = null;
    } on ErrorIot catch (e) {
      _error = e.mensaje;
    } finally {
      _cargando = false;
      _avisar();
    }
  }

  void mirar() {
    _mirando++;
    if (_mirando == 1) {
      scheduleMicrotask(() {
        if (!_cerrado) cargar();
      });
      _reloj = Timer.periodic(cada, (_) => cargar());
    }
  }

  void dejarDeMirar() {
    if (_mirando == 0) return;
    _mirando--;
    if (_mirando == 0) {
      _reloj?.cancel();
      _reloj = null;
    }
  }

  Future<SerieIot> serie(String dispositivo, String variable, {int horas = 24}) =>
      _api.serie(dispositivo, variable, horas: horas);

  Future<bool> tieneClave() async => (await _almacen.leer())?.isNotEmpty ?? false;

  Future<String> ordenar(String dispositivo, ComandoIot comando, {String? claveNueva}) async {
    final clave = claveNueva ?? await _almacen.leer();
    final estado = await _api.ordenar(dispositivo, comando, clave);
    if (claveNueva != null) await _almacen.guardar(claveNueva);
    for (final segundos in [3, 10]) {
      Timer(Duration(seconds: segundos), () {
        if (!_cerrado) cargar();
      });
    }
    return estado == 'enviado'
        ? 'Orden enviada. El equipo responde en unos segundos.'
        : 'Orden en cola: el equipo la recoge en su próximo envío.';
  }

  Future<void> olvidarClave() => _almacen.borrar();

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    _reloj?.cancel();
    super.dispose();
  }
}
