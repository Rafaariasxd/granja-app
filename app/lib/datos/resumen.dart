import '../dominio/modelos.dart';
import 'api_granja.dart';

class ResumenGuardado {
  const ResumenGuardado({
    required this.fecha,
    required this.actualizadoEn,
    required this.galpones,
    this.copiaLocal = false,
  });

  final DateTime fecha;
  final DateTime actualizadoEn;
  final List<ResumenGalpon> galpones;
  final bool copiaLocal;
}

abstract interface class AlmacenResumen {
  Future<void> guardar(ResumenGuardado resumen);
  Future<ResumenGuardado?> ultimo();
}

class AlmacenResumenEnMemoria implements AlmacenResumen {
  ResumenGuardado? _ultimo;

  @override
  Future<void> guardar(ResumenGuardado resumen) async => _ultimo = resumen;

  @override
  Future<ResumenGuardado?> ultimo() async => _ultimo;
}

class RepositorioResumen {
  RepositorioResumen(this._api, this._almacen);

  final ApiGranja _api;
  final AlmacenResumen _almacen;

  Future<ResumenGuardado?> resumen(DateTime fecha, DateTime ahora) async {
    try {
      final nuevo = ResumenGuardado(fecha: fecha, actualizadoEn: ahora, galpones: await _api.resumen(fecha));
      await _almacen.guardar(nuevo);
      return nuevo;
    } on SesionVencida {
      rethrow;
    } on ErrorDeApi {
      final guardado = await _almacen.ultimo();
      if (guardado == null) return null;
      return ResumenGuardado(
        fecha: guardado.fecha,
        actualizadoEn: guardado.actualizadoEn,
        galpones: guardado.galpones,
        copiaLocal: true,
      );
    }
  }
}
