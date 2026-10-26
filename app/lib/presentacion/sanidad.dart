import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dominio/sanidad.dart';
import 'bodega.dart' show nombreDeEtapa;
import 'estado_sanidad.dart';
import 'etiqueta.dart';
import 'fecha_texto.dart';
import 'formato.dart';
import 'sin_enviar.dart';
import 'tema.dart';

class _Estilo {
  const _Estilo(this.fondo, this.color, this.icono);

  final Color fondo;
  final Color color;
  final IconData icono;
}

_Estilo _estiloAlerta(NivelAlerta nivel) => switch (nivel) {
  NivelAlerta.urgente => const _Estilo(Colores.urgenteFondo, Colores.urgenteTexto, Icons.priority_high),
  NivelAlerta.revisar => const _Estilo(Colores.revisarFondo, Colores.revisarTexto, Icons.schedule),
  NivelAlerta.info => const _Estilo(Colores.faltaFondo, Colores.tintaMedia, Icons.info_outline),
};

_Estilo _estiloPeso(NivelPeso nivel) => switch (nivel) {
  NivelPeso.bien => const _Estilo(Colores.bienFondo, Colores.monte, Icons.check),
  NivelPeso.atencion || NivelPeso.alto => const _Estilo(Colores.revisarFondo, Colores.revisarTexto, Icons.schedule),
  NivelPeso.bajo => const _Estilo(Colores.urgenteFondo, Colores.urgenteTexto, Icons.priority_high),
};

String _textoPeso(NivelPeso nivel) => switch (nivel) {
  NivelPeso.bien => 'Va bien',
  NivelPeso.atencion => 'Algo bajo',
  NivelPeso.bajo => 'Bajo',
  NivelPeso.alto => 'Alto',
};

String _fechaCorta(DateTime fecha) => fechaLarga(fecha).split(' ').skip(1).join(' ');

class SanidadPantalla extends StatefulWidget {
  const SanidadPantalla({super.key, required this.estado, this.alPreguntar});

  final EstadoSanidad estado;
  final void Function(String? pregunta)? alPreguntar;

  @override
  State<SanidadPantalla> createState() => _SanidadPantallaState();
}

class _SanidadPantallaState extends State<SanidadPantalla> {
  @override
  void initState() {
    super.initState();
    widget.estado.cargar();
  }

  Future<void> _verSinEnviar() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colores.cal,
    builder: (_) => HojaSinEnviar(
      estado: widget.estado,
      operaciones: () => widget.estado.sinResolver,
      alDescartar: widget.estado.descartar,
      alReintentar: widget.estado.cargar,
    ),
  );

  void _abrir(GalponSanidad galpon) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GalponSanidadPantalla(estado: widget.estado, galponId: galpon.galponId, alPreguntar: widget.alPreguntar),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.estado,
      builder: (context, _) {
        final estado = widget.estado;
        final panorama = estado.panorama;
        final textos = Theme.of(context).textTheme;
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: estado.cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Sanidad', style: textos.headlineMedium)),
                      if (estado.sinSenal)
                        const Etiqueta(
                          texto: 'Sin señal',
                          icono: Icons.cloud_off_outlined,
                          fondo: Colores.faltaFondo,
                          color: Colores.tintaMedia,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vacunas, crecimiento y avisos de cada galpón',
                    style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave),
                  ),
                  const SizedBox(height: 16),
                  if (widget.alPreguntar != null) ...[
                    FilledButton.icon(
                      onPressed: () => widget.alPreguntar!(null),
                      icon: const Icon(Icons.forum_outlined),
                      label: const Text('Preguntar al asistente'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (estado.sinResolver.isNotEmpty) ...[
                    AvisoSinEnviar(
                      porEnviar: estado.porEnviar,
                      noRegistradas: estado.noRegistradas,
                      alPulsar: _verSinEnviar,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (panorama == null)
                    _SinDatos(cargando: estado.cargando)
                  else if (panorama.vacio)
                    const _SinLotes()
                  else ...[
                    if (panorama.alertas.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text('Avisos', style: textos.titleLarge),
                      ),
                      for (final alerta in panorama.alertas) ...[
                        TarjetaAlerta(alerta: alerta, conGalpon: true, alPreguntar: widget.alPreguntar),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 8),
                    ] else ...[
                      const _TodoBien(),
                      const SizedBox(height: 16),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text('Galpones', style: textos.titleLarge),
                    ),
                    for (final galpon in panorama.galpones) ...[
                      _TarjetaGalpon(galpon: galpon, alPulsar: () => _abrir(galpon)),
                      const SizedBox(height: 10),
                    ],
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

class _TodoBien extends StatelessWidget {
  const _TodoBien();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colores.bienFondo, borderRadius: BorderRadius.circular(18)),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colores.monte),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Todo al día: no hay avisos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colores.monte),
            ),
          ),
        ],
      ),
    );
  }
}

class TarjetaAlerta extends StatefulWidget {
  const TarjetaAlerta({super.key, required this.alerta, this.conGalpon = false, this.alPreguntar});

  final AlertaSanidad alerta;
  final bool conGalpon;
  final void Function(String? pregunta)? alPreguntar;

  @override
  State<TarjetaAlerta> createState() => _TarjetaAlertaState();
}

class _TarjetaAlertaState extends State<TarjetaAlerta> {
  bool _abierta = false;

  @override
  Widget build(BuildContext context) {
    final alerta = widget.alerta;
    final estilo = _estiloAlerta(alerta.nivel);
    final hayMas = alerta.recomendaciones.isNotEmpty;
    return Semantics(
      container: true,
      child: Material(
        color: estilo.fondo,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: hayMas ? () => setState(() => _abierta = !_abierta) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(estilo.icono, color: estilo.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.conGalpon ? '${alerta.galpon}: ${alerta.titulo}' : alerta.titulo,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: estilo.color),
                          ),
                          const SizedBox(height: 2),
                          Text(alerta.detalle, style: TextStyle(fontSize: 16, color: estilo.color)),
                        ],
                      ),
                    ),
                    if (hayMas) Icon(_abierta ? Icons.expand_less : Icons.expand_more, color: estilo.color),
                  ],
                ),
                if (hayMas && !_abierta)
                  Padding(
                    padding: const EdgeInsets.only(left: 36, top: 6),
                    child: Text(
                      'Toca para ver qué revisar',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: estilo.color),
                    ),
                  ),
                if (_abierta) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Qué revisar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: estilo.color),
                        ),
                        const SizedBox(height: 4),
                        for (final r in alerta.recomendaciones)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $r', style: TextStyle(fontSize: 16, color: estilo.color)),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Es una guía general. Ante la duda, consulta al veterinario.',
                          style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: estilo.color),
                        ),
                        if (widget.alPreguntar != null)
                          TextButton.icon(
                            onPressed: () => widget.alPreguntar!(
                              'En el ${alerta.galpon}: ${alerta.titulo}. ${alerta.detalle} ¿Qué puede estar pasando y qué hago?',
                            ),
                            icon: const Icon(Icons.forum_outlined),
                            label: const Text('Preguntar al asistente'),
                            style: TextButton.styleFrom(foregroundColor: estilo.color, minimumSize: const Size(0, 48)),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaGalpon extends StatelessWidget {
  const _TarjetaGalpon({required this.galpon, required this.alPulsar});

  final GalponSanidad galpon;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final atrasadas = galpon.atrasadas;
    final ahora = galpon.conEstado(EstadoTarea.ahora).length;
    final peso = galpon.peso;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: alPulsar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(galpon.galpon, style: textos.titleLarge),
                    Text(
                      '${galpon.linea} · ${galpon.edadSemanas} semanas · ${nombreDeEtapa(galpon.etapa)}',
                      style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (atrasadas > 0)
                          Etiqueta(
                            texto: atrasadas == 1 ? '1 atrasada' : '$atrasadas atrasadas',
                            icono: Icons.priority_high,
                            fondo: Colores.urgenteFondo,
                            color: Colores.urgenteTexto,
                          ),
                        if (ahora > 0)
                          Etiqueta(
                            texto: ahora == 1 ? 'Toca 1' : 'Tocan $ahora',
                            icono: Icons.schedule,
                            fondo: Colores.revisarFondo,
                            color: Colores.revisarTexto,
                          ),
                        if (atrasadas == 0 && ahora == 0)
                          const Etiqueta(
                            texto: 'Al día',
                            icono: Icons.check,
                            fondo: Colores.bienFondo,
                            color: Colores.monte,
                          ),
                        if (peso != null && peso.nivel != NivelPeso.bien)
                          Etiqueta(
                            texto: 'Peso: ${_textoPeso(peso.nivel).toLowerCase()}',
                            icono: _estiloPeso(peso.nivel).icono,
                            fondo: _estiloPeso(peso.nivel).fondo,
                            color: _estiloPeso(peso.nivel).color,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colores.tintaSuave),
            ],
          ),
        ),
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
            'Sin señal no se puede traer la sanidad la primera vez. Desliza hacia abajo para intentar de nuevo.',
            style: textos.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SinLotes extends StatelessWidget {
  const _SinLotes();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Text('No hay galpones con aves', style: textos.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Cuando haya un lote activo en un galpón, aquí salen sus vacunas y avisos.',
            style: textos.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class GalponSanidadPantalla extends StatelessWidget {
  const GalponSanidadPantalla({super.key, required this.estado, required this.galponId, this.alPreguntar});

  final EstadoSanidad estado;
  final int galponId;
  final void Function(String? pregunta)? alPreguntar;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) {
        final panorama = estado.panorama;
        final galpon = panorama?.galpones.where((g) => g.galponId == galponId).firstOrNull;
        final textos = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colores.cal,
            scrolledUnderElevation: 0,
            toolbarHeight: 64,
            leadingWidth: 64,
            leading: IconButton(
              tooltip: 'Volver a sanidad',
              icon: const Icon(Icons.arrow_back, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: galpon == null
                ? Center(child: Text('Este galpón ya no tiene un lote activo.', style: textos.bodyLarge))
                : _Detalle(
                    estado: estado,
                    galpon: galpon,
                    alertas: panorama!.deGalpon(galponId),
                    alPreguntar: alPreguntar,
                  ),
          ),
        );
      },
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.estado, required this.galpon, required this.alertas, this.alPreguntar});

  final EstadoSanidad estado;
  final GalponSanidad galpon;
  final List<AlertaSanidad> alertas;
  final void Function(String? pregunta)? alPreguntar;

  Future<void> _aplicar(BuildContext context, TareaSanitaria tarea) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.cal,
      builder: (_) => _HojaAplicada(estado: estado, galpon: galpon, tarea: tarea),
    );
    if (guardado == true && context.mounted) {
      final sinEnviar = estado.porEnviar > 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sinEnviar ? 'Anotada. Se envía cuando haya señal' : 'Anotada: ${tarea.nombre}')),
      );
    }
  }

  Future<void> _pesar(BuildContext context) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.cal,
      builder: (_) => _HojaPesaje(estado: estado, galpon: galpon),
    );
    if (guardado == true && context.mounted) {
      final sinEnviar = estado.porEnviar > 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sinEnviar ? 'Pesaje guardado. Se envía cuando haya señal' : 'Pesaje guardado')),
      );
    }
  }

  Future<void> _deshacer(BuildContext context, TareaSanitaria tarea) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Quitar esta marca?'),
        content: Text('${tarea.nombre} vuelve a quedar sin aplicar en ${galpon.galpon}. Queda anotado quién lo hizo.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(contexto).pop(false), child: const Text('No, dejarla')),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colores.urgenteTexto),
            child: const Text('Sí, quitar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !context.mounted) return;
    final error = await estado.deshacer(tarea);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final grupos = [
      ('Atrasadas', EstadoTarea.atrasada),
      ('Toca ahora', EstadoTarea.ahora),
      ('Próximas', EstadoTarea.proxima),
      ('Más adelante', EstadoTarea.lejana),
    ];
    final hechas = galpon.conEstado(EstadoTarea.aplicada);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(galpon.galpon, style: textos.headlineMedium),
        const SizedBox(height: 4),
        Text(
          '${galpon.linea} · ${galpon.edadSemanas} semanas · ${miles(galpon.avesVivas)} aves',
          style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave),
        ),
        const SizedBox(height: 16),
        for (final a in alertas) ...[TarjetaAlerta(alerta: a, alPreguntar: alPreguntar), const SizedBox(height: 10)],
        if (alertas.isNotEmpty) const SizedBox(height: 6),
        _Crecimiento(galpon: galpon, alPesar: () => _pesar(context)),
        const SizedBox(height: 16),
        for (final (titulo, estadoTarea) in grupos)
          if (galpon.conEstado(estadoTarea).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(titulo, style: textos.titleLarge),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, t) in galpon.conEstado(estadoTarea).indexed) ...[
                    if (i > 0) const Divider(height: 1, color: Colores.borde),
                    _FilaTarea(tarea: t, alAplicar: () => _aplicar(context, t)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        if (hechas.isNotEmpty)
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text('Ya aplicadas (${hechas.length})', style: textos.titleLarge),
              children: [
                for (final t in hechas)
                  _FilaHecha(tarea: t, alDeshacer: t.cumplimientoId == null ? null : () => _deshacer(context, t)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Crecimiento extends StatelessWidget {
  const _Crecimiento({required this.galpon, required this.alPesar});

  final GalponSanidad galpon;
  final VoidCallback alPesar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final peso = galpon.peso;
    final postura = galpon.postura;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Crecimiento', style: textos.titleLarge)),
                if (peso != null)
                  Etiqueta(
                    texto: _textoPeso(peso.nivel),
                    icono: _estiloPeso(peso.nivel).icono,
                    fondo: _estiloPeso(peso.nivel).fondo,
                    color: _estiloPeso(peso.nivel).color,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (peso == null)
              Text('Todavía no hay pesajes de este lote.', style: textos.bodyLarge)
            else ...[
              Text(
                '${miles(peso.pesoG.round())} g',
                style: const TextStyle(fontSize: 34, height: 1.1, fontWeight: FontWeight.w800),
              ),
              Text(
                'Lo esperado es ${miles(peso.estandarG.round())} g · pesaron el ${_fechaCorta(peso.fecha)}',
                style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave),
              ),
            ],
            if (postura != null) ...[
              const SizedBox(height: 8),
              Text(
                'Postura: ${decimal(postura.realPct)}% · lo esperado es ${decimal(postura.estandarPct)}%',
                style: textos.bodyLarge,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(onPressed: alPesar, child: const Text('Pesé las aves')),
          ],
        ),
      ),
    );
  }
}

class _FilaTarea extends StatelessWidget {
  const _FilaTarea({required this.tarea, required this.alAplicar});

  final TareaSanitaria tarea;
  final VoidCallback alAplicar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final atrasada = tarea.estado == EstadoTarea.atrasada;
    final color = atrasada ? Colores.urgenteTexto : Colores.tinta;
    final accion = switch (tarea.tipo) {
      TipoTarea.manejo => 'Ya lo hice',
      _ => 'La apliqué',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tarea.nombre,
                  style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
                ),
                Text(tarea.cuando, style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave)),
                if (tarea.notaPlan.isNotEmpty)
                  Text(tarea.notaPlan, style: textos.bodySmall?.copyWith(color: Colores.tintaSuave)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 128,
            child: OutlinedButton(
              onPressed: alAplicar,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), padding: EdgeInsets.zero),
              child: Text(accion, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaHecha extends StatelessWidget {
  const _FilaHecha({required this.tarea, required this.alDeshacer});

  final TareaSanitaria tarea;
  final VoidCallback? alDeshacer;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colores.monte),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tarea.nombre, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  tarea.aplicadaEn == null
                      ? tarea.cuando
                      : '${_fechaCorta(tarea.aplicadaEn!)}${alDeshacer == null ? ' · sin enviar' : ''}',
                  style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave),
                ),
              ],
            ),
          ),
          if (alDeshacer != null)
            TextButton(
              onPressed: alDeshacer,
              style: TextButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: Colores.urgenteTexto),
              child: const Text('Quitar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class _HojaAplicada extends StatefulWidget {
  const _HojaAplicada({required this.estado, required this.galpon, required this.tarea});

  final EstadoSanidad estado;
  final GalponSanidad galpon;
  final TareaSanitaria tarea;

  @override
  State<_HojaAplicada> createState() => _HojaAplicadaState();
}

enum _Cuando { hoy, ayer, otro }

class _HojaAplicadaState extends State<_HojaAplicada> {
  _Cuando _cuando = _Cuando.hoy;
  DateTime? _otro;
  bool _guardando = false;
  String? _error;

  DateTime get _fecha => switch (_cuando) {
    _Cuando.hoy => widget.estado.hoy,
    _Cuando.ayer => widget.estado.hoy.subtract(const Duration(days: 1)),
    _Cuando.otro => _otro ?? widget.estado.hoy,
  };

  Future<void> _elegirOtro() async {
    final hoy = widget.estado.hoy;
    final elegida = await showDatePicker(
      context: context,
      initialDate: _otro ?? hoy.subtract(const Duration(days: 2)),
      firstDate: hoy.subtract(const Duration(days: 365 * 2)),
      lastDate: hoy,
      helpText: '¿Qué día la aplicaron?',
    );
    if (elegida != null) {
      setState(() {
        _otro = DateTime.utc(elegida.year, elegida.month, elegida.day);
        _cuando = _Cuando.otro;
      });
    }
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final error = await widget.estado.marcarAplicada(widget.galpon, widget.tarea, _fecha);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _guardando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tarea.nombre, style: textos.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'En ${widget.galpon.galpon}. ¿Cuándo la aplicaron?',
              style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _OpcionDia(
                  texto: 'Hoy',
                  elegida: _cuando == _Cuando.hoy,
                  alPulsar: () => setState(() => _cuando = _Cuando.hoy),
                ),
                _OpcionDia(
                  texto: 'Ayer',
                  elegida: _cuando == _Cuando.ayer,
                  alPulsar: () => setState(() => _cuando = _Cuando.ayer),
                ),
                _OpcionDia(
                  texto: _otro == null ? 'Otro día' : _fechaCorta(_otro!),
                  elegida: _cuando == _Cuando.otro,
                  alPulsar: _elegirOtro,
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(fontSize: 16, color: Colores.urgenteTexto)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _guardando ? null : _guardar, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}

class _OpcionDia extends StatelessWidget {
  const _OpcionDia({required this.texto, required this.elegida, required this.alPulsar});

  final String texto;
  final bool elegida;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(texto),
      selected: elegida,
      onSelected: (_) => alPulsar(),
      labelStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: elegida ? Colors.white : Colores.tinta),
      selectedColor: Colores.monte,
      backgroundColor: Colors.white,
      checkmarkColor: Colors.white,
      side: const BorderSide(color: Colores.borde),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    );
  }
}

class _HojaPesaje extends StatefulWidget {
  const _HojaPesaje({required this.estado, required this.galpon});

  final EstadoSanidad estado;
  final GalponSanidad galpon;

  @override
  State<_HojaPesaje> createState() => _HojaPesajeState();
}

class _HojaPesajeState extends State<_HojaPesaje> {
  final _peso = TextEditingController();
  final _aves = TextEditingController(text: '30');
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _peso.dispose();
    _aves.dispose();
    super.dispose();
  }

  bool get _valido => (int.tryParse(_peso.text) ?? 0) > 0 && (int.tryParse(_aves.text) ?? 0) > 0;

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final error = await widget.estado.pesar(widget.galpon, double.parse(_peso.text), int.parse(_aves.text));
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _guardando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pesé las aves', style: textos.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'Pesa unas 30 aves al azar de ${widget.galpon.galpon} y escribe el promedio.',
              style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _peso,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                labelText: 'Peso promedio',
                hintText: '0',
                suffixText: 'g',
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colores.monte, width: 2)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aves,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: '¿Cuántas aves pesaron?', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(fontSize: 16, color: Colores.urgenteTexto)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _valido && !_guardando ? _guardar : null, child: const Text('Guardar pesaje')),
          ],
        ),
      ),
    );
  }
}
