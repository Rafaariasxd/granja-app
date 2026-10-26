import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/bodega.dart';
import '../dominio/inventario.dart';
import '../dominio/modelos.dart';
import 'estado_bodega.dart';
import 'etiqueta.dart';
import 'formato.dart';
import 'sin_enviar.dart';
import 'tema.dart';

String nombreDeEtapa(Etapa etapa) => switch (etapa) {
  Etapa.cria => 'Pollita',
  Etapa.levante => 'Levante',
  Etapa.produccion => 'Ponedora',
};

class _EstiloNivel {
  const _EstiloNivel(this.fondo, this.color, this.icono, this.texto);

  final Color fondo;
  final Color color;
  final IconData icono;
  final String texto;
}

_EstiloNivel _estilo(Nivel nivel) => switch (nivel) {
  Nivel.bien => const _EstiloNivel(Colores.bienFondo, Colores.monte, Icons.check, 'Bien'),
  Nivel.poco => const _EstiloNivel(Colores.revisarFondo, Colores.revisarTexto, Icons.schedule, 'Queda poco'),
  Nivel.critico => const _EstiloNivel(Colores.urgenteFondo, Colores.urgenteTexto, Icons.priority_high, 'Se acaba'),
  Nivel.sinDatos => const _EstiloNivel(Colores.faltaFondo, Colores.tintaMedia, Icons.help_outline, 'Sin datos'),
};

class BodegaPantalla extends StatefulWidget {
  const BodegaPantalla({super.key, required this.estado});

  final EstadoBodega estado;

  @override
  State<BodegaPantalla> createState() => _BodegaPantallaState();
}

class _BodegaPantallaState extends State<BodegaPantalla> {
  int? _elegida;

  @override
  void initState() {
    super.initState();
    widget.estado.cargar();
  }

  Future<void> _abrirInsumo(Bodega bodega, Existencia existencia) async {
    final accion = await showModalBottomSheet<_AccionInsumo>(
      context: context,
      backgroundColor: Colores.cal,
      builder: (_) => _HojaInsumo(existencia: existencia),
    );
    if (accion == null || !mounted) return;
    switch (accion) {
      case _AccionInsumo.llego:
        return _comprar(bodega, existencia);
      case _AccionInsumo.gaste:
        return _gastar(bodega, existencia);
      case _AccionInsumo.conte:
        return _contar(bodega, existencia);
    }
  }

  Future<void> _comprar(Bodega bodega, Existencia existencia) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.cal,
      builder: (_) => _HojaCompra(estado: widget.estado, bodega: bodega, existencia: existencia),
    );
    if (guardado == true && mounted) {
      _avisarGuardado('Compra guardada');
    }
  }

  Future<void> _gastar(Bodega bodega, Existencia existencia) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.cal,
      builder: (_) => _HojaCantidad(
        insumo: existencia.insumo,
        titulo: 'Gasté ${existencia.insumo.nombre}',
        subtitulo: 'De ${bodega.nombre}. Hay ${_cantidadActual(existencia)}.',
        boton: 'Guardar lo gastado',
        inicial: 1,
        minimo: 0.5,
        alGuardar: (cantidad) => widget.estado.registrarGasto(existencia.insumo, bodega.id, cantidad),
      ),
    );
    if (guardado == true && mounted) {
      _avisarGuardado('Gasto guardado');
    }
  }

  Future<void> _contar(Bodega bodega, Existencia existencia) async {
    final kgPorBulto = existencia.insumo.kgPorBulto;
    final actual = existencia.stockKg < 0 ? 0.0 : existencia.stockKg;
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.cal,
      builder: (_) => _HojaCantidad(
        insumo: existencia.insumo,
        titulo: 'Conté ${existencia.insumo.nombre}',
        subtitulo: 'En ${bodega.nombre}. La app dice que hay ${_cantidadActual(existencia)}.',
        boton: 'Dejar este conteo',
        inicial: kgPorBulto == null ? actual : (actual / kgPorBulto * 2).round() / 2,
        minimo: 0,
        alGuardar: (cantidad) => widget.estado.contar(existencia.insumo, bodega.id, cantidad),
      ),
    );
    if (guardado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conteo guardado')));
    }
  }

  String _cantidadActual(Existencia existencia) {
    if (existencia.stockKg <= 0) return 'nada';
    return cantidadTexto(existencia.stockKg, existencia.insumo.kgPorBulto);
  }

  void _avisarGuardado(String texto) {
    final sinEnviar = widget.estado.porEnviar > 0;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(sinEnviar ? '$texto. Se envía cuando haya señal' : texto)));
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

  Future<void> _preparar(MezclaPosible mezcla, List<Bodega> destinos) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.cal,
      builder: (_) => _HojaPreparar(estado: widget.estado, mezcla: mezcla, destinos: destinos),
    );
    if (guardado == true && mounted) {
      _avisarGuardado('Preparación guardada');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.estado,
      builder: (context, _) {
        final estado = widget.estado;
        final inventario = estado.inventario;
        final textos = Theme.of(context).textTheme;
        InventarioBodega? actual;
        if (inventario != null && !inventario.vacio) {
          actual = inventario.bodegas.firstWhere(
            (b) => b.bodega.id == _elegida,
            orElse: () => inventario.bodegas.first,
          );
        }
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
                      Expanded(child: Text('Bodega', style: textos.headlineMedium)),
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
                    'Lo que hay y para cuántos días alcanza',
                    style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave),
                  ),
                  const SizedBox(height: 16),
                  if (estado.sinResolver.isNotEmpty) ...[
                    AvisoSinEnviar(
                      porEnviar: estado.porEnviar,
                      noRegistradas: estado.noRegistradas,
                      alPulsar: _verSinEnviar,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (inventario == null)
                    _SinDatos(cargando: estado.cargando)
                  else if (actual == null)
                    const _Vacia()
                  else ...[
                    if (inventario.urgentes.isNotEmpty) ...[
                      _Urgentes(urgentes: inventario.urgentes),
                      const SizedBox(height: 16),
                    ],
                    _Selector(
                      bodegas: inventario.bodegas,
                      elegida: actual.bodega.id,
                      alElegir: (id) => setState(() => _elegida = id),
                    ),
                    const SizedBox(height: 16),
                    ..._contenido(inventario, actual),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _contenido(Inventario inventario, InventarioBodega actual) {
    final bodega = actual.bodega;
    final destinos = inventario.deAlimento.map((b) => b.bodega).toList();
    if (bodega.tipo == TipoBodega.materiaPrima) {
      return [
        for (final mezcla in inventario.mezclasDe(bodega.id)) ...[
          _MezclaTarjeta(mezcla: mezcla, alPreparar: destinos.isEmpty ? null : () => _preparar(mezcla, destinos)),
          const SizedBox(height: 12),
        ],
        _Lista(
          titulo: 'Materias primas',
          items: actual.existencias,
          alPulsar: (e) => _abrirInsumo(bodega, e),
          vacio: 'Todavía no hay materias primas creadas.',
        ),
      ];
    }
    return [
      _Galpones(cantidad: actual.galponIds.length),
      const SizedBox(height: 12),
      for (final etapa in actual.etapas) ...[
        _EtapaTarjeta(cobertura: etapa, kgPorBulto: actual.kgPorBultoDe(etapa.enUsoId)),
        const SizedBox(height: 12),
      ],
      _Lista(
        titulo: 'Alimento',
        items: actual.existencias,
        alPulsar: (e) => _abrirInsumo(bodega, e),
        vacio: 'Todavía no hay alimento en esta bodega.',
      ),
    ];
  }
}

class _Selector extends StatelessWidget {
  const _Selector({required this.bodegas, required this.elegida, required this.alElegir});

  final List<InventarioBodega> bodegas;
  final int elegida;
  final void Function(int id) alElegir;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final b in bodegas)
          ChoiceChip(
            label: Text(b.bodega.nombre),
            selected: b.bodega.id == elegida,
            onSelected: (_) => alElegir(b.bodega.id),
            labelStyle: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: b.bodega.id == elegida ? Colors.white : Colores.tinta,
            ),
            selectedColor: Colores.monte,
            backgroundColor: Colors.white,
            checkmarkColor: Colors.white,
            side: const BorderSide(color: Colores.borde),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          ),
      ],
    );
  }
}

class _Galpones extends StatelessWidget {
  const _Galpones({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final texto = cantidad == 0
        ? 'Todavía no tiene galpones asignados.'
        : cantidad == 1
        ? 'Alimenta 1 galpón.'
        : 'Alimenta $cantidad galpones.';
    return Text(texto, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colores.tintaSuave));
  }
}

class _Urgentes extends StatelessWidget {
  const _Urgentes({required this.urgentes});

  final List<(Bodega, Existencia)> urgentes;

  @override
  Widget build(BuildContext context) {
    final nombres = urgentes.map((u) => '${u.$2.insumo.nombre} (${u.$1.nombre})').join(', ');
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colores.urgenteFondo, borderRadius: BorderRadius.circular(18)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colores.urgenteTexto),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hay que comprar o preparar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colores.urgenteTexto),
                  ),
                  Text(nombres, style: const TextStyle(fontSize: 16, color: Colores.urgenteTexto)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EtapaTarjeta extends StatelessWidget {
  const _EtapaTarjeta({required this.cobertura, required this.kgPorBulto});

  final CoberturaEtapa cobertura;
  final double? kgPorBulto;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final estilo = _estilo(cobertura.nivel);
    final consumo = cobertura.consumoDiarioKg;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(nombreDeEtapa(cobertura.etapa), style: textos.titleLarge)),
                Etiqueta(texto: estilo.texto, icono: estilo.icono, fondo: estilo.fondo, color: estilo.color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              cobertura.dias == null ? 'Sin datos' : diasTexto(cobertura.dias),
              style: TextStyle(fontSize: 34, height: 1.1, fontWeight: FontWeight.w800, color: estilo.color),
            ),
            const SizedBox(height: 4),
            Text(
              'Hay ${cantidadTexto(cobertura.stockKg, kgPorBulto)}${kgPorBulto == null ? '' : ' (${kilos(cobertura.stockKg)})'} de alimento'
              '${consumo == null ? '' : ' · se gastan ${cantidadTexto(consumo, kgPorBulto)} al día'}',
              style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave),
            ),
          ],
        ),
      ),
    );
  }
}

class _MezclaTarjeta extends StatelessWidget {
  const _MezclaTarjeta({required this.mezcla, required this.alPreparar});

  final MezclaPosible mezcla;
  final VoidCallback? alPreparar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mezcla.producto, style: textos.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Listo: ${kilos(mezcla.stockKg)}. Con lo que hay en esta bodega se pueden preparar '
              '${kilos(mezcla.kgPosibles)} más.',
              style: textos.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Lo primero que se acaba: ${mezcla.limitante}',
              style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: alPreparar, child: const Text('Preparé alimento')),
          ],
        ),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.titulo, required this.items, required this.alPulsar, required this.vacio});

  final String titulo;
  final List<Existencia> items;
  final void Function(Existencia existencia) alPulsar;
  final String vacio;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(titulo, style: textos.titleLarge),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(vacio, style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave)),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: Colores.borde),
                  _Fila(existencia: items[i], alPulsar: () => alPulsar(items[i])),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.existencia, required this.alPulsar});

  final Existencia existencia;
  final VoidCallback alPulsar;

  String get _cantidad {
    if (existencia.stockKg < 0) return 'Revisar el conteo';
    if (existencia.stockKg == 0) return 'No hay';
    final bultos = existencia.bultos;
    return [if (bultos != null) bultosTexto(bultos), kilos(existencia.stockKg)].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final estilo = _estilo(existencia.nivel);
    final dias = existencia.dias;
    return InkWell(
      onTap: alPulsar,
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(existencia.insumo.nombre, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(_cantidad, style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave)),
                ],
              ),
            ),
            if (dias != null)
              Text(
                diasTexto(dias),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: estilo.color),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colores.tintaSuave),
          ],
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
            'Sin señal no se puede traer la bodega la primera vez. Desliza hacia abajo para intentar de nuevo.',
            style: textos.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Vacia extends StatelessWidget {
  const _Vacia();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Text('No hay bodegas todavía', style: textos.titleLarge),
          const SizedBox(height: 8),
          Text(
            'El administrador debe crear primero las bodegas, las materias primas y los alimentos.',
            style: textos.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HojaCompra extends StatefulWidget {
  const _HojaCompra({required this.estado, required this.bodega, required this.existencia});

  final EstadoBodega estado;
  final Bodega bodega;
  final Existencia existencia;

  @override
  State<_HojaCompra> createState() => _HojaCompraState();
}

class _HojaCompraState extends State<_HojaCompra> {
  double _bultos = 1;
  bool _guardando = false;
  String? _error;

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final error = await widget.estado.registrarCompra(widget.existencia.insumo, widget.bodega.id, _bultos);
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
    final porBulto = widget.existencia.insumo.kgPorBulto;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Llegó ${widget.existencia.insumo.nombre}', style: textos.headlineMedium),
            const SizedBox(height: 4),
            Text('A ${widget.bodega.nombre}', style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave)),
            const SizedBox(height: 16),
            Row(
              children: [
                _BotonMedio(
                  icono: Icons.remove,
                  etiqueta: 'Medio bulto menos',
                  alPulsar: _bultos > 0.5 ? () => setState(() => _bultos -= 0.5) : null,
                ),
                Expanded(
                  child: Text(
                    bultosTexto(_bultos),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                ),
                _BotonMedio(
                  icono: Icons.add,
                  etiqueta: 'Medio bulto más',
                  alPulsar: () => setState(() => _bultos += 0.5),
                ),
              ],
            ),
            if (porBulto != null) ...[
              const SizedBox(height: 8),
              Center(child: Text('Son ${kilos(_bultos * porBulto)}', style: textos.bodyLarge)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(fontSize: 16, color: Colores.urgenteTexto)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _guardando ? null : _guardar, child: const Text('Guardar compra')),
          ],
        ),
      ),
    );
  }
}

enum _AccionInsumo { llego, gaste, conte }

class _HojaInsumo extends StatelessWidget {
  const _HojaInsumo({required this.existencia});

  final Existencia existencia;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final seCompra = existencia.insumo.tipo != TipoInsumo.alimentoPreparado;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(existencia.insumo.nombre, style: textos.headlineMedium),
            const SizedBox(height: 16),
            if (seCompra) ...[
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(_AccionInsumo.llego),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Llegó (compra)'),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(_AccionInsumo.gaste),
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('Gasté'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(_AccionInsumo.conte),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Conté lo que hay'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HojaCantidad extends StatefulWidget {
  const _HojaCantidad({
    required this.insumo,
    required this.titulo,
    required this.subtitulo,
    required this.boton,
    required this.inicial,
    required this.minimo,
    required this.alGuardar,
  });

  final Insumo insumo;
  final String titulo;
  final String subtitulo;
  final String boton;
  final double inicial;
  final double minimo;
  final Future<String?> Function(Cantidad cantidad) alGuardar;

  @override
  State<_HojaCantidad> createState() => _HojaCantidadState();
}

class _HojaCantidadState extends State<_HojaCantidad> {
  late double _valor = widget.inicial;
  late final TextEditingController _kg = TextEditingController(
    text: widget.inicial == 0 ? '' : widget.inicial.round().toString(),
  );
  bool _guardando = false;
  String? _error;

  double? get _porBulto => widget.insumo.kgPorBulto;

  bool get _valido => _porBulto != null ? _valor >= widget.minimo : (int.tryParse(_kg.text) ?? -1) >= widget.minimo;

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final cantidad = _porBulto != null ? Cantidad.bultos(_valor) : Cantidad.kilos(double.parse(_kg.text));
    final error = await widget.alGuardar(cantidad);
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
    final porBulto = _porBulto;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.titulo, style: textos.headlineMedium),
            const SizedBox(height: 4),
            Text(widget.subtitulo, style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave)),
            const SizedBox(height: 16),
            if (porBulto != null) ...[
              Row(
                children: [
                  _BotonMedio(
                    icono: Icons.remove,
                    etiqueta: 'Medio bulto menos',
                    alPulsar: _valor - 0.5 >= widget.minimo ? () => setState(() => _valor -= 0.5) : null,
                  ),
                  Expanded(
                    child: Text(
                      _valor == 0 ? '0 bultos' : bultosTexto(_valor),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _BotonMedio(
                    icono: Icons.add,
                    etiqueta: 'Medio bulto más',
                    alPulsar: () => setState(() => _valor += 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(child: Text('Son ${kilos(_valor * porBulto)}', style: textos.bodyLarge)),
            ] else
              TextField(
                controller: _kg,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  hintText: '0',
                  suffixText: 'kg',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colores.monte, width: 2)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(fontSize: 16, color: Colores.urgenteTexto)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _valido && !_guardando ? _guardar : null, child: Text(widget.boton)),
          ],
        ),
      ),
    );
  }
}

class _BotonMedio extends StatelessWidget {
  const _BotonMedio({required this.icono, required this.etiqueta, required this.alPulsar});

  final IconData icono;
  final String etiqueta;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: etiqueta,
      onPressed: alPulsar,
      icon: Icon(icono, size: 28),
      style: IconButton.styleFrom(
        minimumSize: const Size(60, 60),
        side: const BorderSide(color: Color(0xFFC9C8BF), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _HojaPreparar extends StatefulWidget {
  const _HojaPreparar({required this.estado, required this.mezcla, required this.destinos});

  final EstadoBodega estado;
  final MezclaPosible mezcla;
  final List<Bodega> destinos;

  @override
  State<_HojaPreparar> createState() => _HojaPrepararState();
}

class _HojaPrepararState extends State<_HojaPreparar> {
  final _kg = TextEditingController();
  late int _destino = widget.destinos.first.id;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final error = await widget.estado.prepararAlimento(widget.mezcla, _destino, double.parse(_kg.text));
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
    final valido = (int.tryParse(_kg.text) ?? 0) > 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preparé ${widget.mezcla.producto}', style: textos.headlineMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _kg,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                hintText: '0',
                suffixText: 'kg',
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colores.monte, width: 2)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (widget.destinos.length > 1) ...[
              const SizedBox(height: 16),
              Text('¿En qué bodega lo guardaste?', style: textos.bodyLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in widget.destinos)
                    ChoiceChip(
                      label: Text(d.nombre),
                      selected: d.id == _destino,
                      onSelected: (_) => setState(() => _destino = d.id),
                      labelStyle: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: d.id == _destino ? Colors.white : Colores.tinta,
                      ),
                      selectedColor: Colores.monte,
                      backgroundColor: Colors.white,
                      checkmarkColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text('Se gasta de ${widget.mezcla.origen} según la fórmula.', style: textos.bodySmall),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(fontSize: 16, color: Colores.urgenteTexto)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: valido && !_guardando ? _guardar : null, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}
