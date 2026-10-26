import 'package:flutter/material.dart';

import '../datos/cola.dart';
import '../datos/operaciones.dart';
import 'etiqueta.dart';
import 'tema.dart';

class AvisoSinEnviar extends StatelessWidget {
  const AvisoSinEnviar({super.key, required this.porEnviar, required this.noRegistradas, required this.alPulsar});

  final int porEnviar;
  final int noRegistradas;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final problema = noRegistradas > 0;
    final color = problema ? Colores.urgenteTexto : Colores.revisarTexto;
    final titulo = problema
        ? (noRegistradas == 1 ? '1 no se pudo registrar' : '$noRegistradas no se pudieron registrar')
        : (porEnviar == 1 ? '1 cosa sin enviar' : '$porEnviar cosas sin enviar');
    return Material(
      color: problema ? Colores.urgenteFondo : Colores.revisarFondo,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: alPulsar,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(problema ? Icons.error_outline : Icons.cloud_upload_outlined, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
                    ),
                    Text(
                      problema ? 'Toca para verlas' : 'Se envían solas cuando haya señal',
                      style: TextStyle(fontSize: 16, color: color),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class HojaSinEnviar extends StatelessWidget {
  const HojaSinEnviar({
    super.key,
    required this.estado,
    required this.operaciones,
    required this.alDescartar,
    required this.alReintentar,
  });

  final Listenable estado;
  final List<OperacionBodega> Function() operaciones;
  final void Function(String id) alDescartar;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) {
        final operaciones = this.operaciones();
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sin enviar', style: textos.headlineMedium),
                  const SizedBox(height: 12),
                  if (operaciones.isEmpty) Text('No queda nada pendiente.', style: textos.bodyLarge),
                  for (final o in operaciones) ...[
                    _OperacionFila(operacion: o, alDescartar: () => alDescartar(o.id)),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 6),
                  OutlinedButton(onPressed: alReintentar, child: const Text('Intentar enviar ahora')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OperacionFila extends StatelessWidget {
  const _OperacionFila({required this.operacion, required this.alDescartar});

  final OperacionBodega operacion;
  final VoidCallback alDescartar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final pendiente = operacion.estado == EstadoEnvio.pendiente;
    final accion = switch (operacion.tipo) {
      TipoOperacion.compra => 'Compra',
      TipoOperacion.preparacion => 'Preparación',
      TipoOperacion.gasto => 'Gasto',
      TipoOperacion.aplicacion => 'Vacuna',
      TipoOperacion.pesaje => 'Pesaje',
      TipoOperacion.dinero => 'Dinero',
      TipoOperacion.huevoIngreso => 'Entró huevo',
      TipoOperacion.huevoBaja => 'Baja de huevo',
      TipoOperacion.huevoVenta => 'Venta de huevo',
      TipoOperacion.huevoSalida => 'Salida de huevo',
      TipoOperacion.huevoCierre => 'Cierre de salida',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colores.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('$accion: ${operacion.descripcion}', style: textos.titleLarge)),
              Etiqueta(
                texto: pendiente ? 'Sin enviar' : 'No registrada',
                icono: pendiente ? Icons.schedule : Icons.priority_high,
                fondo: pendiente ? Colores.revisarFondo : Colores.urgenteFondo,
                color: pendiente ? Colores.revisarTexto : Colores.urgenteTexto,
              ),
            ],
          ),
          if (!pendiente && operacion.mensaje != null) ...[
            const SizedBox(height: 6),
            Text(operacion.mensaje!, style: const TextStyle(fontSize: 16, color: Colores.urgenteTexto)),
          ],
          if (!pendiente) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: alDescartar,
              style: TextButton.styleFrom(foregroundColor: Colores.urgenteTexto, minimumSize: const Size(0, 48)),
              child: const Text('Descartar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }
}
