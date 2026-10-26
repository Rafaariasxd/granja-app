import 'package:flutter/material.dart';

import '../dominio/huevos.dart';
import '../dominio/inventario.dart';
import '../dominio/sanidad.dart';
import 'tema.dart';

class AvisoDelDia {
  const AvisoDelDia({required this.texto, required this.nivel, required this.pestana, required this.icono});

  final String texto;
  final NivelAlerta nivel;
  final int pestana;
  final IconData icono;
}

String _cuantos(int n, String uno, String varios) => n == 1 ? '1 $uno' : '$n $varios';

List<AvisoDelDia> avisosDelDia({
  PanoramaSanidad? sanidad,
  Inventario? inventario,
  BodegaHuevo? huevo,
  required int pestanaBodega,
  required int pestanaSanidad,
  required int pestanaDinero,
}) {
  final avisos = <AvisoDelDia>[];
  final alertas = sanidad?.alertas ?? const <AlertaSanidad>[];
  final urgentes = alertas.where((a) => a.nivel == NivelAlerta.urgente).length;
  final revisar = alertas.where((a) => a.nivel == NivelAlerta.revisar).length;
  if (urgentes > 0) {
    avisos.add(
      AvisoDelDia(
        texto: '${_cuantos(urgentes, 'aviso urgente', 'avisos urgentes')} de sanidad',
        nivel: NivelAlerta.urgente,
        pestana: pestanaSanidad,
        icono: Icons.health_and_safety_outlined,
      ),
    );
  }
  if (revisar > 0) {
    avisos.add(
      AvisoDelDia(
        texto: '${_cuantos(revisar, 'cosa', 'cosas')} por revisar en sanidad',
        nivel: NivelAlerta.revisar,
        pestana: pestanaSanidad,
        icono: Icons.health_and_safety_outlined,
      ),
    );
  }
  final seAcaban = inventario?.urgentes ?? const [];
  if (seAcaban.isNotEmpty) {
    final nombres = {for (final (_, e) in seAcaban) e.insumo.nombre}.join(', ');
    avisos.add(
      AvisoDelDia(
        texto: 'Se acaba en la bodega: $nombres',
        nivel: NivelAlerta.urgente,
        pestana: pestanaBodega,
        icono: Icons.inventory_2_outlined,
      ),
    );
  }
  final abiertas = huevo?.abiertas.length ?? 0;
  if (abiertas > 0) {
    avisos.add(
      AvisoDelDia(
        texto: '${_cuantos(abiertas, 'salida', 'salidas')} de huevo por cerrar',
        nivel: NivelAlerta.revisar,
        pestana: pestanaDinero,
        icono: Icons.egg_outlined,
      ),
    );
  }
  return avisos;
}

class TarjetaAvisosDelDia extends StatelessWidget {
  const TarjetaAvisosDelDia({super.key, required this.avisos, required this.alAbrir});

  final List<AvisoDelDia> avisos;
  final void Function(int pestana) alAbrir;

  @override
  Widget build(BuildContext context) {
    if (avisos.isEmpty) return const SizedBox.shrink();
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text('Para hoy', style: textos.titleLarge),
            ),
            for (final aviso in avisos)
              InkWell(
                onTap: () => alAbrir(aviso.pestana),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: aviso.nivel == NivelAlerta.urgente ? Colores.urgenteFondo : Colores.revisarFondo,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          aviso.icono,
                          color: aviso.nivel == NivelAlerta.urgente ? Colores.urgenteTexto : Colores.revisarTexto,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(aviso.texto, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      const Icon(Icons.chevron_right, color: Colores.tintaSuave),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
