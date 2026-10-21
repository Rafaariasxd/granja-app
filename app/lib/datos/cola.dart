import '../dominio/modelos.dart';

enum EstadoEnvio { pendiente, enviado, enConflicto, rechazado }

class CambioRegistro {
  const CambioRegistro({
    required this.registro,
    required this.guardadoEn,
    this.estado = EstadoEnvio.pendiente,
    this.mensaje,
    this.intentos = 0,
  });

  final RegistroDiario registro;
  final DateTime guardadoEn;
  final EstadoEnvio estado;
  final String? mensaje;
  final int intentos;

  CambioRegistro con({required EstadoEnvio estado, String? mensaje}) => CambioRegistro(
    registro: registro,
    guardadoEn: guardadoEn,
    estado: estado,
    mensaje: mensaje,
    intentos: intentos + 1,
  );
}

abstract interface class AlmacenCambios {
  Future<void> guardar(CambioRegistro cambio);
  Future<List<CambioRegistro>> porEnviar();
  Future<List<CambioRegistro>> todos();
}

class AlmacenEnMemoria implements AlmacenCambios {
  final _cambios = <String, CambioRegistro>{};

  @override
  Future<void> guardar(CambioRegistro cambio) async => _cambios[cambio.registro.id] = cambio;

  @override
  Future<List<CambioRegistro>> porEnviar() async =>
      _cambios.values.where((c) => c.estado == EstadoEnvio.pendiente).toList()
        ..sort((a, b) => a.guardadoEn.compareTo(b.guardadoEn));

  @override
  Future<List<CambioRegistro>> todos() async => _cambios.values.toList();
}
