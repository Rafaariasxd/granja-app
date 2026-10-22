import '../dominio/modelos.dart';
import 'api_granja.dart';
import 'cola.dart';

class ResultadoEnvio {
  const ResultadoEnvio({required this.enviados, required this.quedanPendientes, this.sesionVencida = false});

  final int enviados;
  final bool quedanPendientes;
  final bool sesionVencida;
}

class Sincronizador {
  Sincronizador(this._almacen, this._api);

  final AlmacenCambios _almacen;
  final ApiGranja _api;

  Future<void> registrar(RegistroDiario registro, DateTime ahora) =>
      _almacen.guardar(CambioRegistro(registro: registro, guardadoEn: ahora));

  Future<ResultadoEnvio> enviarPendientes() async {
    var enviados = 0;
    for (final cambio in await _almacen.porEnviar()) {
      try {
        await _api.guardarRegistro(cambio.registro);
        await _almacen.guardar(cambio.con(estado: EstadoEnvio.enviado));
        enviados++;
      } on RegistroEnConflicto catch (error) {
        await _almacen.guardar(cambio.con(estado: EstadoEnvio.enConflicto, mensaje: error.mensaje));
      } on DatosRechazados catch (error) {
        await _almacen.guardar(cambio.con(estado: EstadoEnvio.rechazado, mensaje: error.mensaje));
      } on SinPermiso catch (error) {
        await _almacen.guardar(cambio.con(estado: EstadoEnvio.rechazado, mensaje: error.mensaje));
      } on SesionVencida catch (error) {
        await _almacen.guardar(cambio.con(estado: EstadoEnvio.pendiente, mensaje: error.mensaje));
        return ResultadoEnvio(enviados: enviados, quedanPendientes: true, sesionVencida: true);
      } on ErrorDeApi catch (error) {
        await _almacen.guardar(cambio.con(estado: EstadoEnvio.pendiente, mensaje: error.mensaje));
        return ResultadoEnvio(enviados: enviados, quedanPendientes: true);
      }
    }
    return ResultadoEnvio(enviados: enviados, quedanPendientes: false);
  }
}
