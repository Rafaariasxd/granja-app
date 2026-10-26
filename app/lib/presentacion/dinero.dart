import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dominio/finanzas.dart';
import 'estado_finanzas.dart';
import 'etiqueta.dart';
import 'fecha_texto.dart';
import 'formato.dart';
import 'sin_enviar.dart';
import 'tema.dart';

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String nombreDelMes(DateTime mes) => '${_meses[mes.month - 1]} ${mes.year}';

class DineroPantalla extends StatefulWidget {
  const DineroPantalla({super.key, required this.estado, this.esAdministrador = false});

  final EstadoFinanzas estado;
  final bool esAdministrador;

  @override
  State<DineroPantalla> createState() => _DineroPantallaState();
}

class _DineroPantallaState extends State<DineroPantalla> {
  @override
  void initState() {
    super.initState();
    widget.estado.cargar();
  }

  Future<void> _abrir(Widget Function(BuildContext) hoja, String guardado) async {
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.cal,
      builder: hoja,
    );
    if (resultado == true && mounted) {
      final sinEnviar = widget.estado.porEnviar > 0;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(sinEnviar ? '$guardado. Se envía cuando haya señal' : guardado)));
    }
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

  Future<void> _ver(MovimientoDinero movimiento) async {
    final borrado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.cal,
      builder: (_) =>
          _HojaMovimiento(estado: widget.estado, movimiento: movimiento, puedeBorrar: widget.esAdministrador),
    );
    if (borrado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimiento borrado')));
    }
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
                      Expanded(child: Text('Dinero', style: textos.headlineMedium)),
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
                  Text('Ventas, gastos y ganancia', style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave)),
                  const SizedBox(height: 12),
                  _Mes(estado: estado),
                  const SizedBox(height: 12),
                  if (estado.sinResolver.isNotEmpty) ...[
                    AvisoSinEnviar(
                      porEnviar: estado.porEnviar,
                      noRegistradas: estado.noRegistradas,
                      alPulsar: _verSinEnviar,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (panorama == null)
                    _SinDatos(cargando: estado.cargando)
                  else ...[
                    _Resumen(resumen: panorama.resumen),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _abrir((_) => _HojaVentaGallinas(estado: estado, panorama: panorama), 'Venta guardada'),
                            child: const Text('Vendí gallinas'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _abrir((_) => _HojaGasto(estado: estado, panorama: panorama), 'Gasto guardado'),
                            child: const Text('Gasté'),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'El huevo se vende en la pestaña Huevo, para que la bodega cuadre.',
                        style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (panorama.resumen.huevos.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text('Huevos vendidos', style: textos.titleLarge),
                      ),
                      _Tabla(
                        filas: [
                          for (final v in panorama.resumen.huevos)
                            (
                              v.categoria,
                              '${miles(v.huevos)} huevos'
                                  '${v.precioPorHuevo == null ? '' : ' · ${pesos(v.precioPorHuevo!)} c/u'}',
                              pesos(v.valor),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (panorama.resumen.porLote.length > 1 ||
                        (panorama.resumen.porLote.isNotEmpty &&
                            panorama.resumen.porLote.first.galpon != 'Sin asignar')) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text('Ganancia por galpón', style: textos.titleLarge),
                      ),
                      _Tabla(
                        filas: [
                          for (final l in panorama.resumen.porLote)
                            (l.galpon, 'Entró ${pesos(l.ingresos)} · salió ${pesos(l.egresos)}', pesos(l.utilidad)),
                        ],
                        colorear: true,
                      ),
                      const SizedBox(height: 20),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text('Movimientos', style: textos.titleLarge),
                    ),
                    if (panorama.movimientos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Todavía no hay movimientos este mes.',
                          style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave),
                        ),
                      )
                    else
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final (i, m) in panorama.movimientos.indexed) ...[
                              if (i > 0) const Divider(height: 1, color: Colores.borde),
                              _FilaMovimiento(movimiento: m, panorama: panorama, alPulsar: () => _ver(m)),
                            ],
                          ],
                        ),
                      ),
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

class _Mes extends StatelessWidget {
  const _Mes({required this.estado});

  final EstadoFinanzas estado;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Mes anterior',
          onPressed: () => estado.irAlMes(mesAnterior(estado.mes)),
          icon: const Icon(Icons.chevron_left, size: 32),
        ),
        Expanded(
          child: Text(
            nombreDelMes(estado.mes),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          tooltip: 'Mes siguiente',
          onPressed: estado.esMesActual ? null : () => estado.irAlMes(mesSiguiente(estado.mes)),
          icon: const Icon(Icons.chevron_right, size: 32),
        ),
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.resumen});

  final ResumenFinanzas resumen;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final gana = resumen.utilidad >= 0;
    final color = gana ? Colores.monte : Colores.urgenteTexto;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gana ? 'Ganancia del mes' : 'Pérdida del mes', style: textos.titleLarge),
            const SizedBox(height: 4),
            Text(
              pesos(resumen.utilidad.abs()),
              style: TextStyle(fontSize: 38, height: 1.1, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Cifra(titulo: 'Entró', valor: pesos(resumen.ingresos)),
                ),
                Expanded(
                  child: _Cifra(titulo: 'Salió', valor: pesos(resumen.egresos)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.titulo, required this.valor});

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave)),
        Text(valor, style: textos.titleLarge),
      ],
    );
  }
}

class _Tabla extends StatelessWidget {
  const _Tabla({required this.filas, this.colorear = false});

  final List<(String, String, String)> filas;
  final bool colorear;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      child: Column(
        children: [
          for (final (i, (titulo, detalle, valor)) in filas.indexed) ...[
            if (i > 0) const Divider(height: 1, color: Colores.borde),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Text(detalle, style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave)),
                      ],
                    ),
                  ),
                  Text(
                    valor,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colorear && valor.startsWith('\$ -') ? Colores.urgenteTexto : Colores.tinta,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({required this.movimiento, required this.panorama, required this.alPulsar});

  final MovimientoDinero movimiento;
  final PanoramaDinero panorama;
  final VoidCallback alPulsar;

  String get _titulo {
    if (movimiento.rubro == Rubro.ventaHuevo) {
      final categoria = panorama.categorias.where((c) => c.id == movimiento.categoriaId).firstOrNull;
      return '${miles(movimiento.cantidadHuevos ?? 0)} huevos${categoria == null ? '' : ' ${categoria.nombre}'}';
    }
    return movimiento.descripcion.isEmpty ? movimiento.rubro.nombre : movimiento.descripcion;
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final ingreso = movimiento.esIngreso;
    final detalle = [
      fechaLarga(movimiento.fecha).split(' ').skip(1).join(' '),
      movimiento.rubro.nombre,
      if (movimiento.contraparte.isNotEmpty) movimiento.contraparte,
      ?panorama.galponDelLote(movimiento.loteId),
    ].join(' · ');
    return InkWell(
      onTap: alPulsar,
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              ingreso ? Icons.arrow_downward : Icons.arrow_upward,
              color: ingreso ? Colores.monte : Colores.urgenteTexto,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_titulo, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(detalle, style: textos.bodySmall),
                ],
              ),
            ),
            Text(
              '${ingreso ? '+' : '-'} ${pesos(movimiento.valor)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ingreso ? Colores.monte : Colores.urgenteTexto,
              ),
            ),
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
            'Sin señal no se puede traer el dinero de este mes. Desliza hacia abajo para intentar de nuevo.',
            style: textos.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HojaMovimiento extends StatefulWidget {
  const _HojaMovimiento({required this.estado, required this.movimiento, required this.puedeBorrar});

  final EstadoFinanzas estado;
  final MovimientoDinero movimiento;
  final bool puedeBorrar;

  @override
  State<_HojaMovimiento> createState() => _HojaMovimientoState();
}

class _HojaMovimientoState extends State<_HojaMovimiento> {
  bool _borrando = false;
  String? _error;

  Future<void> _borrar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Borrar este movimiento?'),
        content: const Text('Se quita de las cuentas. Queda anotado quién lo borró.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(contexto).pop(false), child: const Text('No, dejarlo')),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colores.urgenteTexto),
            child: const Text('Sí, borrar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() {
      _borrando = true;
      _error = null;
    });
    final error = await widget.estado.borrar(widget.movimiento);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _borrando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final m = widget.movimiento;
    final panorama = widget.estado.panorama;
    final lineas = <(String, String)>[
      ('Fecha', fechaLarga(m.fecha)),
      ('Tipo', m.rubro.nombre),
      if (m.cantidadHuevos != null) ('Huevos', miles(m.cantidadHuevos!)),
      if (m.descripcion.isNotEmpty) ('Detalle', m.descripcion),
      if (m.contraparte.isNotEmpty) ('Cliente', m.contraparte),
      if (panorama?.galponDelLote(m.loteId) != null) ('Galpón', panorama!.galponDelLote(m.loteId)!),
    ];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${m.esIngreso ? '+' : '-'} ${pesos(m.valor)}', style: textos.headlineMedium),
            const SizedBox(height: 12),
            for (final (titulo, valor) in lineas)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(titulo, style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave)),
                    ),
                    Expanded(child: Text(valor, style: textos.bodyLarge)),
                  ],
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 16, color: Colores.urgenteTexto)),
            ],
            if (widget.puedeBorrar) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _borrando ? null : _borrar,
                style: TextButton.styleFrom(foregroundColor: Colores.urgenteTexto, minimumSize: const Size(0, 48)),
                child: const Text('Borrar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Hoja extends StatelessWidget {
  const _Hoja({required this.titulo, required this.children, this.subtitulo});

  final String titulo;
  final String? subtitulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: textos.headlineMedium),
              if (subtitulo != null) ...[
                const SizedBox(height: 4),
                Text(subtitulo!, style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave)),
              ],
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({
    required this.controlador,
    required this.etiqueta,
    required this.alCambiar,
    this.sufijo,
    this.autofoco = false,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final VoidCallback alCambiar;
  final String? sufijo;
  final bool autofoco;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      autofocus: autofoco,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: etiqueta,
        hintText: '0',
        suffixText: sufijo,
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colores.monte, width: 2)),
      ),
      onChanged: (_) => alCambiar(),
    );
  }
}

class _Texto extends StatelessWidget {
  const _Texto({required this.controlador, required this.etiqueta});

  final TextEditingController controlador;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      decoration: InputDecoration(labelText: etiqueta, border: const OutlineInputBorder()),
    );
  }
}

class _Opciones<T> extends StatelessWidget {
  const _Opciones({required this.opciones, required this.elegida, required this.alElegir});

  final List<(T, String)> opciones;
  final T? elegida;
  final ValueChanged<T> alElegir;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (valor, texto) in opciones)
          ChoiceChip(
            label: Text(texto),
            selected: valor == elegida,
            onSelected: (_) => alElegir(valor),
            labelStyle: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: valor == elegida ? Colors.white : Colores.tinta,
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

mixin _Guardado<T extends StatefulWidget> on State<T> {
  bool guardando = false;
  String? error;

  Future<void> guardar(Future<String?> Function() accion) async {
    setState(() {
      guardando = true;
      error = null;
    });
    final fallo = await accion();
    if (!mounted) return;
    if (fallo == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        guardando = false;
        error = fallo;
      });
    }
  }

  Widget mensajeDeError() => error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(error!, style: const TextStyle(fontSize: 16, color: Colores.urgenteTexto)),
        );
}

int _entero(TextEditingController c) => int.tryParse(c.text) ?? 0;

class _HojaVentaGallinas extends StatefulWidget {
  const _HojaVentaGallinas({required this.estado, required this.panorama});

  final EstadoFinanzas estado;
  final PanoramaDinero panorama;

  @override
  State<_HojaVentaGallinas> createState() => _HojaVentaGallinasState();
}

class _HojaVentaGallinasState extends State<_HojaVentaGallinas> with _Guardado {
  final _cantidad = TextEditingController();
  final _valor = TextEditingController();
  final _cliente = TextEditingController();
  int? _lote;

  @override
  void dispose() {
    _cantidad.dispose();
    _valor.dispose();
    _cliente.dispose();
    super.dispose();
  }

  bool get _valido => _entero(_cantidad) > 0 && _entero(_valor) > 0;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return _Hoja(
      titulo: 'Vendí gallinas',
      subtitulo: 'Gallinas de descarte u otras',
      children: [
        _Numero(
          controlador: _cantidad,
          etiqueta: '¿Cuántas gallinas?',
          autofoco: true,
          alCambiar: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        _Numero(controlador: _valor, etiqueta: 'Total cobrado', sufijo: 'pesos', alCambiar: () => setState(() {})),
        const SizedBox(height: 16),
        Text('¿De qué galpón salieron?', style: textos.bodyLarge),
        const SizedBox(height: 8),
        _Opciones<int?>(
          opciones: [(null, 'No sé'), for (final l in widget.panorama.lotes) (l.id, l.galpon)],
          elegida: _lote,
          alElegir: (l) => setState(() => _lote = l),
        ),
        const SizedBox(height: 12),
        _Texto(controlador: _cliente, etiqueta: 'Cliente (opcional)'),
        mensajeDeError(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _valido && !guardando
              ? () => guardar(
                  () => widget.estado.venderGallinas(
                    gallinas: _entero(_cantidad),
                    valor: _entero(_valor).toDouble(),
                    loteId: _lote,
                    cliente: _cliente.text.trim(),
                  ),
                )
              : null,
          child: const Text('Guardar venta'),
        ),
      ],
    );
  }
}

class _HojaGasto extends StatefulWidget {
  const _HojaGasto({required this.estado, required this.panorama});

  final EstadoFinanzas estado;
  final PanoramaDinero panorama;

  @override
  State<_HojaGasto> createState() => _HojaGastoState();
}

class _HojaGastoState extends State<_HojaGasto> with _Guardado {
  final _valor = TextEditingController();
  final _nota = TextEditingController();
  Rubro _rubro = Rubro.alimento;
  int? _lote;

  @override
  void dispose() {
    _valor.dispose();
    _nota.dispose();
    super.dispose();
  }

  bool get _valido => _entero(_valor) > 0;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return _Hoja(
      titulo: 'Gasté',
      children: [
        Text('¿En qué?', style: textos.bodyLarge),
        const SizedBox(height: 8),
        _Opciones<Rubro>(
          opciones: [for (final r in Rubro.deGasto) (r, r.nombre)],
          elegida: _rubro,
          alElegir: (r) => setState(() => _rubro = r),
        ),
        const SizedBox(height: 16),
        _Numero(
          controlador: _valor,
          etiqueta: '¿Cuánto fue?',
          sufijo: 'pesos',
          autofoco: true,
          alCambiar: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        _Texto(controlador: _nota, etiqueta: 'Detalle (opcional)'),
        if (widget.panorama.lotes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('¿Es de un galpón?', style: textos.bodyLarge),
          const SizedBox(height: 8),
          _Opciones<int?>(
            opciones: [(null, 'De toda la finca'), for (final l in widget.panorama.lotes) (l.id, l.galpon)],
            elegida: _lote,
            alElegir: (l) => setState(() => _lote = l),
          ),
        ],
        mensajeDeError(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _valido && !guardando
              ? () => guardar(
                  () => widget.estado.gastar(
                    rubro: _rubro,
                    valor: _entero(_valor).toDouble(),
                    nota: _nota.text.trim(),
                    loteId: _lote,
                  ),
                )
              : null,
          child: const Text('Guardar gasto'),
        ),
      ],
    );
  }
}
