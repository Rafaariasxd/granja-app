import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dominio/inventario.dart';
import '../dominio/modelos.dart';
import 'estado_bodega.dart';
import 'etiqueta.dart';
import 'formato.dart';
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
  @override
  void initState() {
    super.initState();
    widget.estado.cargar();
  }

  Future<void> _comprar(Existencia existencia) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.cal,
      builder: (_) => _HojaCompra(estado: widget.estado, existencia: existencia),
    );
    if (guardado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compra guardada')));
    }
  }

  Future<void> _preparar(int productoId, String nombre) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.cal,
      builder: (_) => _HojaPreparar(estado: widget.estado, productoId: productoId, nombre: nombre),
    );
    if (guardado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparación guardada')));
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
                  if (inventario == null)
                    _SinDatos(cargando: estado.cargando)
                  else if (inventario.vacio)
                    const _Vacia()
                  else ...[
                    if (inventario.urgentes.isNotEmpty) ...[
                      _Urgentes(urgentes: inventario.urgentes),
                      const SizedBox(height: 16),
                    ],
                    for (final etapa in inventario.etapas) ...[
                      _EtapaTarjeta(cobertura: etapa),
                      const SizedBox(height: 12),
                    ],
                    for (final mezcla in inventario.mezclas) ...[
                      _MezclaTarjeta(mezcla: mezcla, alPreparar: () => _preparar(mezcla.productoId, mezcla.producto)),
                      const SizedBox(height: 12),
                    ],
                    if (inventario.materiasPrimas.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _Lista(titulo: 'Materias primas', items: inventario.materiasPrimas, alPulsar: _comprar),
                    ],
                    if (inventario.alimentos.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Lista(
                        titulo: 'Alimento',
                        items: inventario.alimentos,
                        alPulsar: (e) => e.insumo.tipo == TipoInsumo.alimentoPreparado
                            ? _preparar(e.insumo.id, e.insumo.nombre)
                            : _comprar(e),
                      ),
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

class _Urgentes extends StatelessWidget {
  const _Urgentes({required this.urgentes});

  final List<Existencia> urgentes;

  @override
  Widget build(BuildContext context) {
    final nombres = urgentes.map((e) => e.insumo.nombre).join(', ');
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
  const _EtapaTarjeta({required this.cobertura});

  final CoberturaEtapa cobertura;

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
              'Hay ${kilos(cobertura.stockKg)} de alimento'
              '${consumo == null ? '' : ' · se gastan ${kilos(consumo)} al día'}',
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
  final VoidCallback alPreparar;

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
              'Listo: ${kilos(mezcla.stockKg)}. Con lo que hay en bodega se pueden preparar '
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
  const _Lista({required this.titulo, required this.items, required this.alPulsar});

  final String titulo;
  final List<Existencia> items;
  final void Function(Existencia existencia) alPulsar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(titulo, style: Theme.of(context).textTheme.titleLarge),
        ),
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
          Text('La bodega está vacía', style: textos.titleLarge),
          const SizedBox(height: 8),
          Text(
            'El administrador debe crear primero las materias primas y los alimentos.',
            style: textos.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HojaCompra extends StatefulWidget {
  const _HojaCompra({required this.estado, required this.existencia});

  final EstadoBodega estado;
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
    final error = await widget.estado.registrarCompra(widget.existencia.insumo.id, _bultos);
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
  const _HojaPreparar({required this.estado, required this.productoId, required this.nombre});

  final EstadoBodega estado;
  final int productoId;
  final String nombre;

  @override
  State<_HojaPreparar> createState() => _HojaPrepararState();
}

class _HojaPrepararState extends State<_HojaPreparar> {
  final _kg = TextEditingController();
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
    final error = await widget.estado.prepararAlimento(widget.productoId, double.parse(_kg.text));
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
            Text('Preparé ${widget.nombre}', style: textos.headlineMedium),
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
            const SizedBox(height: 8),
            Text('Se gasta de las materias primas según la fórmula.', style: textos.bodySmall),
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
