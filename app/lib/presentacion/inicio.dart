import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../dominio/resumen_dia.dart';
import 'estado_envios.dart';
import 'estado_inicio.dart';
import 'etiqueta.dart';
import 'fecha_texto.dart';
import 'formato.dart';
import 'tema.dart';

class InicioPantalla extends StatefulWidget {
  const InicioPantalla({
    super.key,
    required this.estado,
    required this.envios,
    required this.alRegistrar,
    this.alCorregir,
    this.nombreUsuario,
    this.alSalir,
  });

  final EstadoInicio estado;
  final EstadoEnvios envios;
  final void Function(ResumenGalpon galpon) alRegistrar;
  final void Function(ResumenGalpon galpon)? alCorregir;
  final String? nombreUsuario;
  final VoidCallback? alSalir;

  @override
  State<InicioPantalla> createState() => _InicioPantallaState();
}

class _InicioPantallaState extends State<InicioPantalla> {
  @override
  void initState() {
    super.initState();
    widget.estado.cargar();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.estado, widget.envios]),
      builder: (context, _) {
        final estado = widget.estado;
        final resumen = estado.resumen;
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await widget.envios.enviar();
                await estado.cargar();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  _Encabezado(
                    estado: estado,
                    envios: widget.envios,
                    nombreUsuario: widget.nombreUsuario,
                    alSalir: widget.alSalir,
                  ),
                  const SizedBox(height: 14),
                  if (resumen == null)
                    _SinDatos(cargando: estado.cargando)
                  else ...[
                    _Tarjeta(resumen: resumen, alRegistrar: widget.alRegistrar),
                    for (final galpon in resumen.conLote) ...[
                      const SizedBox(height: 14),
                      _GalponConLote(
                        galpon: galpon,
                        alRegistrar: () => widget.alRegistrar(galpon),
                        alCorregir: widget.alCorregir == null ? null : () => widget.alCorregir!(galpon),
                      ),
                    ],
                    if (resumen.vacios.isNotEmpty) ...[const SizedBox(height: 14), _Vacios(vacios: resumen.vacios)],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.estado, required this.envios, this.nombreUsuario, this.alSalir});

  final EstadoInicio estado;
  final EstadoEnvios envios;
  final String? nombreUsuario;
  final VoidCallback? alSalir;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                fechaLarga(estado.hoy),
                style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave, fontWeight: FontWeight.w500),
              ),
            ),
            _EstadoDeEnvio(estado: estado, envios: envios),
            if (alSalir != null)
              PopupMenuButton<void>(
                tooltip: 'Menú de ${nombreUsuario ?? 'la cuenta'}',
                icon: const Icon(Icons.more_vert, size: 28),
                itemBuilder: (_) => [
                  if (nombreUsuario != null) PopupMenuItem<void>(enabled: false, child: Text(nombreUsuario!)),
                  PopupMenuItem<void>(onTap: alSalir, child: const Text('Salir')),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Hoy en la granja', style: textos.headlineMedium),
      ],
    );
  }
}

class _EstadoDeEnvio extends StatelessWidget {
  const _EstadoDeEnvio({required this.estado, required this.envios});

  final EstadoInicio estado;
  final EstadoEnvios envios;

  @override
  Widget build(BuildContext context) {
    if (envios.enConflicto > 0) {
      return Etiqueta(
        texto: '${envios.enConflicto} por revisar',
        icono: Icons.warning_amber_rounded,
        fondo: Colores.revisarFondo,
        color: Colores.revisarTexto,
      );
    }
    if (envios.pendientes > 0) {
      return Etiqueta(
        texto: '${envios.pendientes} sin enviar',
        icono: Icons.cloud_off_outlined,
        fondo: Colores.faltaFondo,
        color: Colores.tintaMedia,
      );
    }
    if (estado.sinSenal) {
      return const Etiqueta(
        texto: 'Sin señal',
        icono: Icons.cloud_off_outlined,
        fondo: Colores.faltaFondo,
        color: Colores.tintaMedia,
      );
    }
    return const Etiqueta(
      texto: 'Todo enviado',
      icono: Icons.cloud_done_outlined,
      fondo: Colores.bienFondo,
      color: Colores.monte,
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.resumen, required this.alRegistrar});

  final ResumenDelDia resumen;
  final void Function(ResumenGalpon galpon) alRegistrar;

  @override
  Widget build(BuildContext context) {
    const claro = Color(0xFFCFE3D7);
    final faltan = resumen.faltan;
    final galpones = resumen.conLote.length;
    return Semantics(
      container: true,
      label: 'Resumen del día',
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(color: Colores.monte, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Huevos hoy', style: TextStyle(fontSize: 16, color: claro)),
                      Text(
                        miles(resumen.huevos),
                        style: const TextStyle(
                          fontSize: 44,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (faltan.isNotEmpty)
                  TextButton(
                    onPressed: () => alRegistrar(faltan.first),
                    style: TextButton.styleFrom(
                      backgroundColor: Colores.yema,
                      foregroundColor: Colores.tinta,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      faltan.length == 1 ? 'Falta 1 galpón' : 'Faltan ${faltan.length} galpones',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  )
                else if (resumen.todoRegistrado)
                  const Etiqueta(
                    texto: 'Todo registrado',
                    icono: Icons.check,
                    fondo: Colores.bienFondo,
                    color: Colores.monte,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${miles(resumen.avesVivas)} aves vivas en $galpones ${galpones == 1 ? 'galpón' : 'galpones'}',
              style: const TextStyle(fontSize: 16, color: claro),
            ),
          ],
        ),
      ),
    );
  }
}

String _etapa(Etapa? etapa) => switch (etapa) {
  Etapa.cria => 'cría',
  Etapa.levante => 'levante',
  _ => '',
};

class _GalponConLote extends StatelessWidget {
  const _GalponConLote({required this.galpon, required this.alRegistrar, this.alCorregir});

  final ResumenGalpon galpon;
  final VoidCallback alRegistrar;
  final VoidCallback? alCorregir;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final detalle = [
      if (galpon.linea != null) galpon.linea!,
      if (galpon.edadSemanas != null) '${galpon.edadSemanas} semanas',
      if (_etapa(galpon.etapa).isNotEmpty) _etapa(galpon.etapa),
      '${miles(galpon.avesVivas)} aves',
    ].join(' · ');
    final produccion = galpon.etapa == Etapa.produccion;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(galpon.nombre, style: textos.titleLarge)),
                if (galpon.registradoHoy)
                  const Etiqueta(texto: 'Al día', icono: Icons.check, fondo: Colores.bienFondo, color: Colores.monte)
                else
                  const Etiqueta(
                    texto: 'Falta hoy',
                    icono: Icons.schedule,
                    fondo: Colores.faltaFondo,
                    color: Colores.tintaMedia,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(detalle, style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave)),
            if (galpon.registradoHoy && produccion && galpon.posturaPct != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    porcentaje(galpon.posturaPct!),
                    style: const TextStyle(fontSize: 34, height: 1.1, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'postura · ${miles(galpon.huevosDelDia!)} huevos',
                    style: textos.bodyMedium?.copyWith(color: Colores.tintaMedia),
                  ),
                ],
              ),
            ],
            if (galpon.registradoHoy && alCorregir != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: alCorregir,
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: Colores.monte),
                  child: const Text('Corregir', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
            if (!galpon.registradoHoy) ...[
              const SizedBox(height: 10),
              FilledButton(
                onPressed: alRegistrar,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text('Registrar hoy'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Vacios extends StatelessWidget {
  const _Vacios({required this.vacios});

  final List<ResumenGalpon> vacios;

  @override
  Widget build(BuildContext context) {
    final nombres = vacios.map((g) => g.nombre.replaceFirst('Galpón ', '')).toList();
    final lista = nombres.length == 1
        ? nombres.first
        : '${nombres.sublist(0, nombres.length - 1).join(', ')} y ${nombres.last}';
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC9C8BF), width: 1.5),
      ),
      child: Text(
        'Vacíos: ${nombres.length == 1 ? 'galpón' : 'galpones'} $lista',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colores.tintaMedia),
      ),
    );
  }
}

class _SinDatos extends StatelessWidget {
  const _SinDatos({required this.cargando});

  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    if (cargando) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Text('No hay datos todavía', style: textos.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Sin señal no se puede traer el resumen la primera vez. Desliza hacia abajo para intentar de nuevo.',
            style: textos.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
