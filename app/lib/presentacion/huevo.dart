import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dominio/huevos.dart';
import 'estado_huevos.dart';
import 'etiqueta.dart';
import 'fecha_texto.dart';
import 'formato.dart';
import 'sin_enviar.dart';
import 'tema.dart';
import 'hoja.dart';

class HuevoPantalla extends StatefulWidget {
  const HuevoPantalla({super.key, required this.estado});

  final EstadoHuevos estado;

  @override
  State<HuevoPantalla> createState() => _HuevoPantallaState();
}

enum _Accion { entro, rompio, conte }

class _HuevoPantallaState extends State<HuevoPantalla> {
  @override
  void initState() {
    super.initState();
    widget.estado.cargar();
  }

  Future<void> _abrir(Widget Function(BuildContext) hoja, String guardado) async {
    final resultado = await abrirHoja<bool>(
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

  Future<void> _categoria(ExistenciaHuevo existencia) async {
    final accion = await abrirHoja<_Accion>(
      context: context,
      backgroundColor: Colores.cal,
      builder: (contexto) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Huevo ${existencia.categoria}', style: Theme.of(contexto).textTheme.headlineMedium),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(contexto).pop(_Accion.entro),
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Entró a la bodega'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(contexto).pop(_Accion.rompio),
                icon: const Icon(Icons.heart_broken_outlined),
                label: const Text('Se rompieron o dañaron'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(contexto).pop(_Accion.conte),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Conté lo que hay'),
              ),
            ],
          ),
        ),
      ),
    );
    if (accion == null || !mounted) return;
    final estado = widget.estado;
    final id = existencia.categoriaId;
    switch (accion) {
      case _Accion.entro:
        return _abrir(
          (_) => _HojaCantidad(
            titulo: 'Entró huevo ${existencia.categoria}',
            boton: 'Guardar',
            alGuardar: (huevos, _) => estado.ingresar(id, huevos),
          ),
          'Huevo guardado en la bodega',
        );
      case _Accion.rompio:
        return _abrir(
          (_) => _HojaCantidad(
            titulo: 'Se dañó huevo ${existencia.categoria}',
            subtitulo: 'Hay ${empaqueTexto(existencia.huevos)}.',
            boton: 'Dar de baja',
            conNota: true,
            maximo: existencia.huevos,
            alGuardar: (huevos, nota) => estado.darDeBaja(id, huevos, nota),
          ),
          'Baja guardada',
        );
      case _Accion.conte:
        return _abrir(
          (_) => _HojaCantidad(
            titulo: 'Conté huevo ${existencia.categoria}',
            subtitulo: 'La app dice que hay ${empaqueTexto(existencia.huevos)}.',
            boton: 'Dejar este conteo',
            permiteCero: true,
            alGuardar: (huevos, _) => estado.contar(id, huevos),
          ),
          'Conteo guardado',
        );
    }
  }

  Future<void> _verSinEnviar() => abrirHoja<void>(
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.estado,
      builder: (context, _) {
        final estado = widget.estado;
        final bodega = estado.bodega;
        final textos = Theme.of(context).textTheme;
        return RefreshIndicator(
          onRefresh: estado.cargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Bodega del huevo', style: textos.titleLarge)),
                  if (estado.sinSenal)
                    const Etiqueta(
                      texto: 'Sin señal',
                      icono: Icons.cloud_off_outlined,
                      fondo: Colores.faltaFondo,
                      color: Colores.tintaMedia,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (estado.sinResolver.isNotEmpty) ...[
                AvisoSinEnviar(
                  porEnviar: estado.porEnviar,
                  noRegistradas: estado.noRegistradas,
                  alPulsar: _verSinEnviar,
                ),
                const SizedBox(height: 12),
              ],
              if (bodega == null)
                _SinDatos(cargando: estado.cargando)
              else if (bodega.existencias.isEmpty)
                Text(
                  'Todavía no hay categorías de huevo. El administrador las crea en Administrar.',
                  style: textos.bodyLarge,
                )
              else ...[
                Text('Hay en total', style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave)),
                Text(
                  empaqueTexto(bodega.total),
                  style: const TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                for (final e in bodega.existencias) ...[
                  _TarjetaCategoria(existencia: e, alPulsar: () => _categoria(e)),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                FilledButton(
                  onPressed: bodega.total <= 0
                      ? null
                      : () => _abrir(
                          (_) => _HojaVenta(estado: estado, bodega: bodega, inmediata: true),
                          'Venta guardada',
                        ),
                  child: const Text('Vender'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: bodega.total <= 0
                      ? null
                      : () => _abrir(
                          (_) => _HojaVenta(estado: estado, bodega: bodega, inmediata: false),
                          'Salida guardada',
                        ),
                  child: const Text('Sacar huevo para vender'),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sacar es para cuando se lleva huevo y se sabe después cuánto se vendió.',
                  style: textos.bodySmall,
                ),
                if (bodega.abiertas.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('Salidas por cerrar', style: textos.titleLarge),
                  ),
                  for (final s in bodega.abiertas) ...[
                    _TarjetaSalida(
                      salida: s,
                      bodega: bodega,
                      alCerrar: () =>
                          _abrir((_) => _HojaCierre(estado: estado, bodega: bodega, salida: s), 'Salida cerrada'),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TarjetaCategoria extends StatelessWidget {
  const _TarjetaCategoria({required this.existencia, required this.alPulsar});

  final ExistenciaHuevo existencia;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: alPulsar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              SizedBox(width: 64, child: Text(existencia.categoria, style: textos.headlineMedium)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      empaqueTexto(existencia.huevos),
                      style: textos.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: existencia.huevos < 0 ? Colores.urgenteTexto : Colores.tinta,
                      ),
                    ),
                    Text('${miles(existencia.huevos)} huevos', style: textos.bodySmall),
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

class _TarjetaSalida extends StatelessWidget {
  const _TarjetaSalida({required this.salida, required this.bodega, required this.alCerrar});

  final SalidaHuevo salida;
  final BodegaHuevo bodega;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final quien = salida.cliente.isEmpty ? salida.tipoVenta.nombre : '${salida.cliente} · ${salida.tipoVenta.nombre}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(quien, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (salida.sinEnviar)
                  const Etiqueta(
                    texto: 'Sin enviar',
                    icono: Icons.schedule,
                    fondo: Colores.revisarFondo,
                    color: Colores.revisarTexto,
                  ),
              ],
            ),
            Text('Salió el ${fechaLarga(salida.fecha).split(' ').skip(1).join(' ')}', style: textos.bodySmall),
            const SizedBox(height: 6),
            for (final l in salida.lineas)
              Text('${bodega.nombreDe(l.categoriaId)}: ${empaqueTexto(l.huevosSacados)}', style: textos.bodyLarge),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: alCerrar, child: const Text('Cerrar la salida')),
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
    if (cargando) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Text('No hay datos todavía', style: textos.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Sin señal no se puede traer la bodega del huevo la primera vez. Desliza hacia abajo para intentar de nuevo.',
            style: textos.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
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
    this.grande = false,
    this.clave,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final VoidCallback alCambiar;
  final bool grande;
  final String? clave;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: clave == null ? null : ValueKey<String>(clave!),
      controller: controlador,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(grande ? 10 : 5)],
      style: TextStyle(fontSize: grande ? 26 : 22, fontWeight: FontWeight.w800),
      decoration: InputDecoration(labelText: etiqueta, hintText: '0', border: const OutlineInputBorder()),
      onChanged: (_) => alCambiar(),
    );
  }
}

class _Cantidad {
  final cajas = TextEditingController();
  final cartones = TextEditingController();
  final sueltos = TextEditingController();

  int get huevos => aHuevos(
    cajas: int.tryParse(cajas.text) ?? 0,
    cartones: int.tryParse(cartones.text) ?? 0,
    huevos: int.tryParse(sueltos.text) ?? 0,
  );

  void poner(int huevos) {
    final e = empacar(huevos);
    cajas.text = e.cajas == 0 ? '' : '${e.cajas}';
    cartones.text = e.cartones == 0 ? '' : '${e.cartones}';
    sueltos.text = e.sueltos == 0 ? '' : '${e.sueltos}';
  }

  void dispose() {
    cajas.dispose();
    cartones.dispose();
    sueltos.dispose();
  }
}

class _CamposCantidad extends StatelessWidget {
  const _CamposCantidad({required this.cantidad, required this.alCambiar, this.prefijo = ''});

  final _Cantidad cantidad;
  final VoidCallback alCambiar;
  final String prefijo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Numero(
            controlador: cantidad.cajas,
            etiqueta: 'Cajas',
            clave: '${prefijo}Cajas',
            alCambiar: alCambiar,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Numero(
            controlador: cantidad.cartones,
            etiqueta: 'Cartones',
            clave: '${prefijo}Cartones',
            alCambiar: alCambiar,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Numero(
            controlador: cantidad.sueltos,
            etiqueta: 'Huevos',
            clave: '${prefijo}Huevos',
            alCambiar: alCambiar,
          ),
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

class _HojaCantidad extends StatefulWidget {
  const _HojaCantidad({
    required this.titulo,
    required this.boton,
    required this.alGuardar,
    this.subtitulo,
    this.conNota = false,
    this.permiteCero = false,
    this.maximo,
  });

  final String titulo;
  final String? subtitulo;
  final String boton;
  final bool conNota;
  final bool permiteCero;
  final int? maximo;
  final Future<String?> Function(int huevos, String nota) alGuardar;

  @override
  State<_HojaCantidad> createState() => _HojaCantidadState();
}

class _HojaCantidadState extends State<_HojaCantidad> with _Guardado {
  final _cantidad = _Cantidad();
  final _nota = TextEditingController();
  bool _tocado = false;

  @override
  void dispose() {
    _cantidad.dispose();
    _nota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final huevos = _cantidad.huevos;
    final pasado = widget.maximo != null && huevos > widget.maximo!;
    final valido = (widget.permiteCero ? _tocado : huevos > 0) && !pasado;
    return _Hoja(
      titulo: widget.titulo,
      subtitulo: widget.subtitulo,
      children: [
        _CamposCantidad(cantidad: _cantidad, alCambiar: () => setState(() => _tocado = true)),
        const SizedBox(height: 8),
        Text(
          pasado ? 'No hay tanto huevo.' : 'Son ${empaqueTexto(huevos).toLowerCase()} (${miles(huevos)} huevos)',
          style: textos.bodyLarge?.copyWith(color: pasado ? Colores.urgenteTexto : Colores.tinta),
        ),
        if (widget.conNota) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _nota,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(labelText: '¿Qué pasó? (opcional)', border: OutlineInputBorder()),
          ),
        ],
        mensajeDeError(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: valido && !guardando ? () => guardar(() => widget.alGuardar(huevos, _nota.text.trim())) : null,
          child: Text(widget.boton),
        ),
      ],
    );
  }
}

class _OpcionesVenta extends StatelessWidget {
  const _OpcionesVenta({required this.elegida, required this.alElegir});

  final TipoVenta elegida;
  final ValueChanged<TipoVenta> alElegir;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<TipoVenta>(
      groupValue: elegida,
      onChanged: (v) => alElegir(v!),
      child: Column(
        children: [
          for (final t in TipoVenta.values)
            RadioListTile<TipoVenta>(
              value: t,
              activeColor: Colores.monte,
              contentPadding: EdgeInsets.zero,
              title: Text(t.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              subtitle: Text(t.detalle, style: const TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
  }
}

class _HojaVenta extends StatefulWidget {
  const _HojaVenta({required this.estado, required this.bodega, required this.inmediata});

  final EstadoHuevos estado;
  final BodegaHuevo bodega;
  final bool inmediata;

  @override
  State<_HojaVenta> createState() => _HojaVentaState();
}

class _HojaVentaState extends State<_HojaVenta> with _Guardado {
  late final Map<int, _Cantidad> _cantidades = {
    for (final e in widget.bodega.existencias)
      if (e.huevos > 0) e.categoriaId: _Cantidad(),
  };
  final _cliente = TextEditingController();
  final _total = TextEditingController();
  TipoVenta _tipo = TipoVenta.cliente;
  bool _totalEscrito = false;

  @override
  void dispose() {
    for (final c in _cantidades.values) {
      c.dispose();
    }
    _cliente.dispose();
    _total.dispose();
    super.dispose();
  }

  Map<int, int> get _lineas => {
    for (final MapEntry(key: c, value: cantidad) in _cantidades.entries)
      if (cantidad.huevos > 0) c: cantidad.huevos,
  };

  List<String> get _sinExistencia => [
    for (final MapEntry(key: c, value: h) in _lineas.entries)
      if (h > widget.bodega.huevosDe(c)) widget.bodega.nombreDe(c),
  ];

  double? get _sugerido => totalSugerido(_lineas, _tipo, widget.bodega.preciosPorCategoria);

  void _actualizar() {
    setState(() {
      if (!_totalEscrito) {
        final sugerido = _sugerido;
        _total.text = sugerido == null ? '' : '${sugerido.round()}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final lineas = _lineas;
    final faltan = _sinExistencia;
    final sugerido = _sugerido;
    final total = int.tryParse(_total.text);
    final necesitaTotal = widget.inmediata && sugerido == null;
    final valido = lineas.isNotEmpty && faltan.isEmpty && (!necesitaTotal || (total ?? 0) > 0);
    return _Hoja(
      titulo: widget.inmediata ? 'Vender huevo' : 'Sacar huevo para vender',
      children: [
        Text('¿A quién?', style: textos.titleLarge),
        _OpcionesVenta(
          elegida: _tipo,
          alElegir: (t) {
            _tipo = t;
            _actualizar();
          },
        ),
        TextField(
          controller: _cliente,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 20),
          decoration: const InputDecoration(labelText: 'Nombre (opcional)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        Text('¿Cuánto huevo?', style: textos.titleLarge),
        const SizedBox(height: 8),
        for (final MapEntry(key: c, value: cantidad) in _cantidades.entries) ...[
          Text(
            '${widget.bodega.nombreDe(c)} · hay ${empaqueTexto(widget.bodega.huevosDe(c)).toLowerCase()}',
            style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _CamposCantidad(cantidad: cantidad, prefijo: '${widget.bodega.nombreDe(c)} ', alCambiar: _actualizar),
          const SizedBox(height: 12),
        ],
        if (faltan.isNotEmpty)
          Text(
            'No hay tanto huevo ${faltan.join(', ')}.',
            style: const TextStyle(fontSize: 16, color: Colores.urgenteTexto),
          ),
        if (widget.inmediata) ...[
          const SizedBox(height: 4),
          _Numero(
            controlador: _total,
            etiqueta: 'Total cobrado',
            grande: true,
            alCambiar: () => setState(() => _totalEscrito = _total.text.isNotEmpty),
          ),
          const SizedBox(height: 6),
          Text(
            lineas.isEmpty
                ? 'Escribe cuánto huevo sale.'
                : sugerido == null
                ? 'Falta el precio de alguna categoría: escribe el total.'
                : 'Según los precios: ${pesos(sugerido)}',
            style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave),
          ),
        ] else if (sugerido != null && lineas.isNotEmpty)
          Text('Si se vende todo serían ${pesos(sugerido)}', style: textos.bodyLarge),
        mensajeDeError(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: valido && !guardando
              ? () => guardar(
                  () => widget.inmediata
                      ? widget.estado.vender(
                          _tipo,
                          _cliente.text.trim(),
                          lineas,
                          total != null && total > 0 ? total.toDouble() : null,
                        )
                      : widget.estado.sacar(_tipo, _cliente.text.trim(), lineas),
                )
              : null,
          child: Text(widget.inmediata ? 'Guardar venta' : 'Guardar salida'),
        ),
      ],
    );
  }
}

class _HojaCierre extends StatefulWidget {
  const _HojaCierre({required this.estado, required this.bodega, required this.salida});

  final EstadoHuevos estado;
  final BodegaHuevo bodega;
  final SalidaHuevo salida;

  @override
  State<_HojaCierre> createState() => _HojaCierreState();
}

class _HojaCierreState extends State<_HojaCierre> with _Guardado {
  late final Map<int, _Cantidad> _sobrantes = {for (final l in widget.salida.lineas) l.categoriaId: _Cantidad()};
  final _total = TextEditingController();
  bool _sobro = false;
  bool _totalEscrito = false;
  String? _errorAnular;

  @override
  void initState() {
    super.initState();
    _actualizar();
  }

  @override
  void dispose() {
    for (final c in _sobrantes.values) {
      c.dispose();
    }
    _total.dispose();
    super.dispose();
  }

  Map<int, int> get _vendidos => {
    for (final l in widget.salida.lineas)
      l.categoriaId: _sobro ? l.huevosSacados - _sobrantes[l.categoriaId]!.huevos : l.huevosSacados,
  };

  bool get _sobranDeMas => _vendidos.values.any((v) => v < 0);

  double? get _sugerido =>
      _sobranDeMas ? null : totalSugerido(_vendidos, widget.salida.tipoVenta, widget.bodega.preciosPorCategoria);

  void _actualizar() {
    if (_totalEscrito) return;
    final sugerido = _sugerido;
    _total.text = sugerido == null ? '' : '${sugerido.round()}';
  }

  Future<void> _anular() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Anular esta salida?'),
        content: const Text('Todo el huevo vuelve a la bodega y no se cuenta ninguna venta.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(contexto).pop(false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colores.urgenteTexto),
            child: const Text('Sí, anular'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    final error = await widget.estado.anular(widget.salida);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(false);
    } else {
      setState(() => _errorAnular = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final vendidos = _vendidos;
    final total = int.tryParse(_total.text);
    final nadaVendido = vendidos.values.every((v) => v == 0);
    final valido = !_sobranDeMas && (nadaVendido || _sugerido != null || (total ?? 0) > 0);
    return _Hoja(
      titulo: 'Cerrar la salida',
      subtitulo: widget.salida.cliente.isEmpty ? widget.salida.tipoVenta.nombre : widget.salida.cliente,
      children: [
        for (final l in widget.salida.lineas)
          Text(
            'Salió ${widget.bodega.nombreDe(l.categoriaId)}: ${empaqueTexto(l.huevosSacados).toLowerCase()}',
            style: textos.bodyLarge,
          ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Se vendió todo')),
            ButtonSegment(value: true, label: Text('Sobró huevo')),
          ],
          selected: {_sobro},
          onSelectionChanged: (v) => setState(() {
            _sobro = v.first;
            _actualizar();
          }),
        ),
        if (_sobro) ...[
          const SizedBox(height: 16),
          Text('¿Cuánto volvió a la bodega?', style: textos.titleLarge),
          const SizedBox(height: 8),
          for (final l in widget.salida.lineas) ...[
            Text(
              widget.bodega.nombreDe(l.categoriaId),
              style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _CamposCantidad(
              cantidad: _sobrantes[l.categoriaId]!,
              prefijo: 'Volvió ${widget.bodega.nombreDe(l.categoriaId)} ',
              alCambiar: () => setState(_actualizar),
            ),
            const SizedBox(height: 8),
            Text(
              vendidos[l.categoriaId]! < 0
                  ? 'No puede volver más de lo que salió.'
                  : 'Se vendieron ${empaqueTexto(vendidos[l.categoriaId]!).toLowerCase()}',
              style: textos.bodyMedium?.copyWith(
                color: vendidos[l.categoriaId]! < 0 ? Colores.urgenteTexto : Colores.tintaSuave,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
        const SizedBox(height: 12),
        if (!nadaVendido) ...[
          _Numero(
            controlador: _total,
            etiqueta: 'Total cobrado',
            grande: true,
            alCambiar: () => setState(() => _totalEscrito = _total.text.isNotEmpty),
          ),
          const SizedBox(height: 6),
          Text(
            _sugerido == null
                ? 'Falta el precio de alguna categoría: escribe el total.'
                : 'Según los precios: ${pesos(_sugerido!)}',
            style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave),
          ),
        ] else
          Text('No se vendió nada: todo vuelve a la bodega.', style: textos.bodyLarge),
        mensajeDeError(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: valido && !guardando
              ? () => guardar(
                  () => widget.estado.cerrar(
                    widget.salida,
                    _sobro ? vendidos : null,
                    nadaVendido || total == null || total <= 0 ? null : total.toDouble(),
                  ),
                )
              : null,
          child: const Text('Cerrar salida'),
        ),
        if (!widget.salida.sinEnviar) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: guardando ? null : _anular,
            style: TextButton.styleFrom(foregroundColor: Colores.urgenteTexto, minimumSize: const Size(0, 48)),
            child: const Text('Anular salida', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          if (_errorAnular != null)
            Text(_errorAnular!, style: const TextStyle(fontSize: 16, color: Colores.urgenteTexto)),
        ],
      ],
    );
  }
}

class HojaHuevoDelDia extends StatefulWidget {
  const HojaHuevoDelDia({super.key, required this.estado, required this.origen, required this.recogidos});

  final EstadoHuevos estado;
  final String origen;
  final int recogidos;

  @override
  State<HojaHuevoDelDia> createState() => _HojaHuevoDelDiaState();
}

class _HojaHuevoDelDiaState extends State<HojaHuevoDelDia> with _Guardado {
  late final List<ExistenciaHuevo> _categorias = [
    for (final e in widget.estado.bodega?.existencias ?? const <ExistenciaHuevo>[])
      if (e.activa) e,
  ];
  late final Map<int, _Cantidad> _cantidades = {for (final e in _categorias) e.categoriaId: _Cantidad()};

  @override
  void dispose() {
    for (final c in _cantidades.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<int, int> get _lineas => {
    for (final MapEntry(key: c, value: cantidad) in _cantidades.entries)
      if (cantidad.huevos > 0) c: cantidad.huevos,
  };

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final total = _lineas.values.fold(0, (suma, h) => suma + h);
    final pasa = total > widget.recogidos;
    return _Hoja(
      titulo: '¿Pasar el huevo a la bodega?',
      subtitulo:
          'En ${widget.origen} se recogieron ${miles(widget.recogidos)} huevos '
          '(${empaqueTexto(widget.recogidos).toLowerCase()}). Escribe cuánto de cada tamaño entra.',
      children: [
        for (final e in _categorias) ...[
          Text(e.categoria, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _CamposCantidad(
            cantidad: _cantidades[e.categoriaId]!,
            prefijo: '${e.categoria} ',
            alCambiar: () => setState(() {}),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          total == 0
              ? 'Todavía no has escrito nada.'
              : 'Van ${empaqueTexto(total).toLowerCase()} (${miles(total)} de ${miles(widget.recogidos)} huevos)',
          style: textos.bodyLarge,
        ),
        if (pasa)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Es más de lo que se recogió en este galpón. Revisa si es correcto.',
              style: TextStyle(fontSize: 16, color: Colores.revisarTexto),
            ),
          ),
        mensajeDeError(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: total > 0 && !guardando
              ? () => guardar(() => widget.estado.ingresarVarios(_lineas, widget.origen))
              : null,
          child: const Text('Guardar en la bodega'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: guardando ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(minimumSize: const Size(0, 52)),
          child: const Text('Ahora no', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
