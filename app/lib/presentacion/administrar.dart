import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dominio/administracion.dart';
import '../dominio/finanzas.dart';
import '../dominio/huevos.dart';
import '../dominio/inventario.dart';
import '../dominio/modelos.dart';
import '../dominio/sanidad.dart';
import 'bodega.dart' show nombreDeEtapa;
import 'estado_administracion.dart';
import 'etiqueta.dart';
import 'formato.dart';
import 'tema.dart';
import 'hoja.dart';

String nombreDeTipoInsumo(TipoInsumo tipo) => switch (tipo) {
  TipoInsumo.materiaPrima => 'Materia prima',
  TipoInsumo.alimentoComprado => 'Alimento comprado',
  TipoInsumo.alimentoPreparado => 'Alimento que preparamos',
};

String nombreDeTipoTarea(TipoTarea tipo) => switch (tipo) {
  TipoTarea.vacuna => 'Vacuna',
  TipoTarea.desparasitacion => 'Desparasitación',
  TipoTarea.manejo => 'Otro cuidado',
};

String nombreDeTipoBodega(TipoBodega tipo) => tipo == TipoBodega.materiaPrima ? 'Materia prima' : 'Alimento';

class AdministrarPantalla extends StatefulWidget {
  const AdministrarPantalla({super.key, required this.estado});

  final EstadoAdministracion estado;

  @override
  State<AdministrarPantalla> createState() => _AdministrarPantallaState();
}

class _AdministrarPantallaState extends State<AdministrarPantalla> {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(guardado)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.estado,
      builder: (context, _) {
        final estado = widget.estado;
        final catalogo = estado.catalogo;
        final textos = Theme.of(context).textTheme;
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: estado.cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  Text('Administrar', style: textos.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Bodegas, insumos, razas y categorías',
                    style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave),
                  ),
                  const SizedBox(height: 16),
                  if (catalogo == null)
                    _Aviso(texto: estado.problema ?? (estado.cargando ? 'Cargando…' : 'Sin datos todavía.'))
                  else ...[
                    if (estado.problema != null) _Aviso(texto: estado.problema!),
                    _Titulo(
                      texto: 'Bodegas',
                      accion: 'Nueva bodega',
                      alPulsar: () => _abrir((_) => _HojaBodegaNueva(estado: estado), 'Bodega creada'),
                    ),
                    for (final b in catalogo.inventario.bodegas) ...[
                      _BodegaFila(
                        bodega: b,
                        galpones: [
                          for (final g in catalogo.galpones)
                            if (b.galponIds.contains(g.id)) g.nombre,
                        ],
                        alGalpones: () => _abrir((_) => _HojaGalpones(estado: estado, bodega: b), 'Galpones guardados'),
                        alEnUso: () => _abrir((_) => _HojaEnUso(estado: estado, bodega: b), 'Alimento en uso guardado'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (catalogo.inventario.bodegas.isEmpty) const _Aviso(texto: 'Todavía no hay bodegas.'),
                    const SizedBox(height: 14),
                    _Titulo(
                      texto: 'Insumos',
                      accion: 'Nuevo insumo',
                      alPulsar: () => _abrir((_) => _HojaInsumoNuevo(estado: estado), 'Insumo creado'),
                    ),
                    for (final i in catalogo.insumos) ...[
                      _InsumoFila(
                        insumo: i,
                        alFormula: i.tipo == TipoInsumo.alimentoPreparado
                            ? () => _abrir((_) => _HojaFormula(estado: estado, producto: i), 'Fórmula guardada')
                            : null,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (catalogo.insumos.isEmpty) const _Aviso(texto: 'Todavía no hay insumos.'),
                    const SizedBox(height: 14),
                    _Titulo(
                      texto: 'Razas',
                      accion: 'Nueva raza',
                      alPulsar: () => _abrir((_) => _HojaRazaNueva(estado: estado), 'Raza creada'),
                    ),
                    for (final r in catalogo.razas) ...[
                      _RazaFila(
                        raza: r,
                        alNombre: () => _abrir((_) => _HojaRazaNombre(estado: estado, raza: r), 'Nombre guardado'),
                        alPlan: () => _abrir((_) => _HojaPlan(estado: estado, raza: r), 'Vacunas y cuidados guardados'),
                        alCurva: () => _abrir((_) => _HojaCurva(estado: estado, raza: r), 'Curva guardada'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (catalogo.razas.isEmpty) const _Aviso(texto: 'Todavía no hay razas.'),
                    const SizedBox(height: 14),
                    _Titulo(
                      texto: 'Categorías de huevo',
                      accion: 'Nueva categoría',
                      alPulsar: () => _abrir((_) => _HojaCategoriaNueva(estado: estado), 'Categoría creada'),
                    ),
                    for (final (i, c) in catalogo.categoriasHuevo.indexed) ...[
                      _CategoriaFila(
                        categoria: c,
                        alSubir: i == 0 ? null : () => estado.moverCategoriaHuevo(catalogo.categoriasHuevo, i, -1),
                        alBajar: i == catalogo.categoriasHuevo.length - 1
                            ? null
                            : () => estado.moverCategoriaHuevo(catalogo.categoriasHuevo, i, 1),
                        precio: catalogo.precioDe(c.id),
                        alPrecio: () => _abrir(
                          (_) => _HojaPrecioHuevo(estado: estado, categoria: c, actual: catalogo.precioDe(c.id)),
                          'Precios guardados',
                        ),
                        alNombre: () =>
                            _abrir((_) => _HojaCategoriaNombre(estado: estado, categoria: c), 'Nombre guardado'),
                        alActivar: (activa) => estado.cambiarCategoriaHuevo(c.id, activa: activa),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (catalogo.categoriasHuevo.isEmpty) const _Aviso(texto: 'Todavía no hay categorías.'),
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

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(texto, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colores.tintaSuave)),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo({required this.texto, required this.accion, required this.alPulsar});

  final String texto;
  final String accion;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.titleLarge)),
          TextButton.icon(
            onPressed: alPulsar,
            icon: const Icon(Icons.add),
            label: Text(accion),
            style: TextButton.styleFrom(
              foregroundColor: Colores.monte,
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              minimumSize: const Size(0, 48),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colores.borde),
      ),
      child: child,
    );
  }
}

class _BodegaFila extends StatelessWidget {
  const _BodegaFila({required this.bodega, required this.galpones, required this.alGalpones, required this.alEnUso});

  final InventarioBodega bodega;
  final List<String> galpones;
  final VoidCallback alGalpones;
  final VoidCallback alEnUso;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final deAlimento = bodega.bodega.tipo == TipoBodega.alimento;
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(bodega.bodega.nombre, style: textos.titleLarge)),
              Etiqueta(
                texto: nombreDeTipoBodega(bodega.bodega.tipo),
                icono: deAlimento ? Icons.grain : Icons.inventory_2_outlined,
                fondo: Colores.bienFondo,
                color: Colores.monte,
              ),
            ],
          ),
          if (deAlimento) ...[
            const SizedBox(height: 6),
            Text(
              galpones.isEmpty ? 'Ningún galpón come de aquí todavía' : galpones.join(', '),
              style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: alGalpones,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: const Text('Galpones'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: alEnUso,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: const Text('Alimento en uso'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InsumoFila extends StatelessWidget {
  const _InsumoFila({required this.insumo, required this.alFormula});

  final Insumo insumo;
  final VoidCallback? alFormula;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final detalle = [
      nombreDeTipoInsumo(insumo.tipo),
      if (insumo.etapa != null) nombreDeEtapa(insumo.etapa!),
      if (insumo.kgPorBulto != null) 'bulto de ${decimal(insumo.kgPorBulto!)} kg',
    ].join(' · ');
    return _Tarjeta(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insumo.nombre, style: textos.titleLarge),
                const SizedBox(height: 2),
                Text(detalle, style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave)),
              ],
            ),
          ),
          if (alFormula != null)
            OutlinedButton(
              onPressed: alFormula,
              style: OutlinedButton.styleFrom(minimumSize: const Size(110, 48)),
              child: const Text('Fórmula'),
            ),
        ],
      ),
    );
  }
}

class _RazaFila extends StatelessWidget {
  const _RazaFila({required this.raza, required this.alNombre, required this.alPlan, required this.alCurva});

  final Raza raza;
  final VoidCallback alNombre;
  final VoidCallback alPlan;
  final VoidCallback alCurva;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(raza.nombre, style: textos.titleLarge)),
              IconButton(
                tooltip: 'Cambiar el nombre de ${raza.nombre}',
                onPressed: alNombre,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          if (!raza.revisada) ...[
            const SizedBox(height: 2),
            const Etiqueta(
              texto: 'Valores sin revisar',
              icono: Icons.schedule,
              fondo: Colores.revisarFondo,
              color: Colores.revisarTexto,
            ),
            const SizedBox(height: 6),
            Text(
              'Son una referencia. Revísalos con el veterinario y ajústalos.',
              style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: alPlan,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: const Text('Vacunas'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: alCurva,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: const Text('Curva'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoriaFila extends StatelessWidget {
  const _CategoriaFila({
    required this.categoria,
    required this.alSubir,
    required this.alBajar,
    required this.precio,
    required this.alPrecio,
    required this.alNombre,
    required this.alActivar,
  });

  final CategoriaHuevo categoria;
  final VoidCallback? alSubir;
  final VoidCallback? alBajar;
  final PrecioHuevo? precio;
  final VoidCallback alPrecio;
  final VoidCallback alNombre;
  final void Function(bool activa) alActivar;

  String get _precios {
    final p = precio;
    if (p == null || (p.precioCaja == null && p.precioCarton == null && p.precioMayorista == null)) {
      return 'Sin precios todavía';
    }
    return [
      if (p.precioCaja != null) 'caja ${pesos(p.precioCaja!)}',
      if (p.precioCarton != null) 'cartón ${pesos(p.precioCarton!)}',
      if (p.precioMayorista != null) 'mayorista ${pesos(p.precioMayorista!)}',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  categoria.nombre,
                  style: textos.titleLarge?.copyWith(color: categoria.activa ? Colores.tinta : Colores.tintaSuave),
                ),
              ),
              IconButton(
                tooltip: 'Subir ${categoria.nombre}',
                onPressed: alSubir,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Bajar ${categoria.nombre}',
                onPressed: alBajar,
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: 'Cambiar el nombre de ${categoria.nombre}',
                onPressed: alNombre,
                icon: const Icon(Icons.edit_outlined),
              ),
              Switch(value: categoria.activa, onChanged: alActivar, activeThumbColor: Colores.monte),
            ],
          ),
          Text(_precios, style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: alPrecio,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Precios'),
          ),
        ],
      ),
    );
  }
}

class _Hoja extends StatelessWidget {
  const _Hoja({required this.titulo, this.subtitulo, required this.children});

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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          ),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.controlador,
    required this.etiqueta,
    this.sufijo,
    this.numerico = false,
    this.alCambiar,
    this.autofoco = false,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final String? sufijo;
  final bool numerico;
  final VoidCallback? alCambiar;
  final bool autofoco;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      autofocus: autofoco,
      keyboardType: numerico ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      textCapitalization: numerico ? TextCapitalization.none : TextCapitalization.sentences,
      inputFormatters: numerico
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')), LengthLimitingTextInputFormatter(7)]
          : null,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: etiqueta,
        suffixText: sufijo,
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colores.monte, width: 2)),
      ),
      onChanged: (_) => alCambiar?.call(),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error(this.texto);

  final String? texto;

  @override
  Widget build(BuildContext context) {
    if (texto == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(texto!, style: const TextStyle(fontSize: 16, color: Colores.urgenteTexto)),
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
}

class _HojaBodegaNueva extends StatefulWidget {
  const _HojaBodegaNueva({required this.estado});

  final EstadoAdministracion estado;

  @override
  State<_HojaBodegaNueva> createState() => _HojaBodegaNuevaState();
}

class _HojaBodegaNuevaState extends State<_HojaBodegaNueva> with _Guardado {
  final _nombre = TextEditingController();
  TipoBodega _tipo = TipoBodega.alimento;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valido = _nombre.text.trim().isNotEmpty;
    return _Hoja(
      titulo: 'Nueva bodega',
      children: [
        _Campo(controlador: _nombre, etiqueta: 'Nombre', autofoco: true, alCambiar: () => setState(() {})),
        const SizedBox(height: 16),
        Text('¿Qué se guarda aquí?', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        _Opciones<TipoBodega>(
          opciones: const [(TipoBodega.alimento, 'Alimento'), (TipoBodega.materiaPrima, 'Materia prima')],
          elegida: _tipo,
          alElegir: (t) => setState(() => _tipo = t),
        ),
        _Error(error),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: valido && !guardando
              ? () => guardar(() => widget.estado.crearBodega(_nombre.text.trim(), _tipo))
              : null,
          child: const Text('Crear bodega'),
        ),
      ],
    );
  }
}

class _HojaGalpones extends StatefulWidget {
  const _HojaGalpones({required this.estado, required this.bodega});

  final EstadoAdministracion estado;
  final InventarioBodega bodega;

  @override
  State<_HojaGalpones> createState() => _HojaGalponesState();
}

class _HojaGalponesState extends State<_HojaGalpones> with _Guardado {
  late final Set<int> _elegidos = {...widget.bodega.galponIds};

  @override
  Widget build(BuildContext context) {
    final catalogo = widget.estado.catalogo!;
    return _Hoja(
      titulo: 'Galpones de ${widget.bodega.bodega.nombre}',
      subtitulo: 'Los que comen el alimento de esta bodega',
      children: [
        for (final g in catalogo.galpones)
          CheckboxListTile(
            value: _elegidos.contains(g.id),
            onChanged: (marcado) => setState(() => marcado == true ? _elegidos.add(g.id) : _elegidos.remove(g.id)),
            title: Text(g.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            activeColor: Colores.monte,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        _Error(error),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: guardando
              ? null
              : () => guardar(() => widget.estado.asignarGalpones(widget.bodega.bodega.id, _elegidos.toList()..sort())),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _HojaEnUso extends StatefulWidget {
  const _HojaEnUso({required this.estado, required this.bodega});

  final EstadoAdministracion estado;
  final InventarioBodega bodega;

  @override
  State<_HojaEnUso> createState() => _HojaEnUsoState();
}

class _HojaEnUsoState extends State<_HojaEnUso> with _Guardado {
  late final Map<Etapa, int?> _inicial = {
    for (final e in Etapa.values) e: widget.bodega.etapas.where((c) => c.etapa == e).map((c) => c.enUsoId).firstOrNull,
  };
  late final Map<Etapa, int?> _elegido = {..._inicial};

  Future<String?> _enviar() async {
    for (final etapa in Etapa.values) {
      final id = _elegido[etapa];
      if (id == null || id == _inicial[etapa]) continue;
      final fallo = await widget.estado.ponerEnUso(widget.bodega.bodega.id, etapa, id);
      if (fallo != null) return fallo;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = widget.estado.catalogo!;
    final textos = Theme.of(context).textTheme;
    return _Hoja(
      titulo: 'Alimento en uso',
      subtitulo: widget.bodega.bodega.nombre,
      children: [
        for (final etapa in Etapa.values) ...[
          if (catalogo.alimentosDe(etapa).isNotEmpty) ...[
            Text(nombreDeEtapa(etapa), style: textos.titleLarge),
            const SizedBox(height: 8),
            _Opciones<int>(
              opciones: [for (final a in catalogo.alimentosDe(etapa)) (a.id, a.nombre)],
              elegida: _elegido[etapa],
              alElegir: (id) => setState(() => _elegido[etapa] = id),
            ),
            const SizedBox(height: 16),
          ],
        ],
        _Error(error),
        FilledButton(onPressed: guardando ? null : () => guardar(_enviar), child: const Text('Guardar')),
      ],
    );
  }
}

class _HojaInsumoNuevo extends StatefulWidget {
  const _HojaInsumoNuevo({required this.estado});

  final EstadoAdministracion estado;

  @override
  State<_HojaInsumoNuevo> createState() => _HojaInsumoNuevoState();
}

class _HojaInsumoNuevoState extends State<_HojaInsumoNuevo> with _Guardado {
  final _nombre = TextEditingController();
  final _porBulto = TextEditingController();
  TipoInsumo _tipo = TipoInsumo.materiaPrima;
  Etapa? _etapa;

  @override
  void dispose() {
    _nombre.dispose();
    _porBulto.dispose();
    super.dispose();
  }

  bool get _llevaEtapa => _tipo != TipoInsumo.materiaPrima;
  bool get _bultoObligatorio => _tipo != TipoInsumo.alimentoPreparado;

  bool get _valido {
    if (_nombre.text.trim().isEmpty) return false;
    if (_llevaEtapa && _etapa == null) return false;
    final kilosPorBulto = leerNumero(_porBulto.text);
    if (_bultoObligatorio && (kilosPorBulto ?? 0) <= 0) return false;
    if (_porBulto.text.trim().isNotEmpty && (kilosPorBulto ?? 0) <= 0) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return _Hoja(
      titulo: 'Nuevo insumo',
      children: [
        _Campo(controlador: _nombre, etiqueta: 'Nombre', autofoco: true, alCambiar: () => setState(() {})),
        const SizedBox(height: 16),
        Text('¿Qué es?', style: textos.bodyLarge),
        const SizedBox(height: 8),
        _Opciones<TipoInsumo>(
          opciones: [for (final t in TipoInsumo.values) (t, nombreDeTipoInsumo(t))],
          elegida: _tipo,
          alElegir: (t) => setState(() {
            _tipo = t;
            if (!_llevaEtapa) _etapa = null;
          }),
        ),
        if (_llevaEtapa) ...[
          const SizedBox(height: 16),
          Text('¿Para qué etapa sirve?', style: textos.bodyLarge),
          const SizedBox(height: 8),
          _Opciones<Etapa>(
            opciones: [for (final e in Etapa.values) (e, nombreDeEtapa(e))],
            elegida: _etapa,
            alElegir: (e) => setState(() => _etapa = e),
          ),
        ],
        const SizedBox(height: 16),
        _Campo(
          controlador: _porBulto,
          etiqueta: _bultoObligatorio ? 'Kilos por bulto' : 'Kilos por bulto (si lo manejan en bultos)',
          sufijo: 'kg',
          numerico: true,
          alCambiar: () => setState(() {}),
        ),
        _Error(error),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _valido && !guardando
              ? () => guardar(
                  () => widget.estado.crearInsumo(
                    nombre: _nombre.text.trim(),
                    tipo: _tipo,
                    etapa: _llevaEtapa ? _etapa : null,
                    kgPorBulto: leerNumero(_porBulto.text),
                  ),
                )
              : null,
          child: const Text('Crear insumo'),
        ),
      ],
    );
  }
}

class _HojaFormula extends StatefulWidget {
  const _HojaFormula({required this.estado, required this.producto});

  final EstadoAdministracion estado;
  final Insumo producto;

  @override
  State<_HojaFormula> createState() => _HojaFormulaState();
}

class _HojaFormulaState extends State<_HojaFormula> with _Guardado {
  final Map<int, TextEditingController> _campos = {};
  bool _cargada = false;

  @override
  void initState() {
    super.initState();
    for (final m in widget.estado.catalogo!.materiasPrimas) {
      _campos[m.id] = TextEditingController();
    }
    widget.estado.formula(widget.producto.id).then((actual) {
      if (!mounted) return;
      for (final i in actual ?? const <IngredienteFormula>[]) {
        _campos[i.insumoId]?.text = decimal(i.porcentaje).replaceAll(',', '.');
      }
      setState(() => _cargada = true);
    });
  }

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<IngredienteFormula> get _ingredientes => [
    for (final e in _campos.entries)
      if ((leerNumero(e.value.text) ?? 0) > 0)
        IngredienteFormula(insumoId: e.key, porcentaje: leerNumero(e.value.text)!),
  ];

  @override
  Widget build(BuildContext context) {
    final materias = widget.estado.catalogo!.materiasPrimas.toList();
    final suma = sumaDeFormula(_ingredientes.map((i) => i.porcentaje));
    final completa = formulaCompleta(_ingredientes.map((i) => i.porcentaje));
    return _Hoja(
      titulo: 'Fórmula de ${widget.producto.nombre}',
      subtitulo: 'Por cada 100 kg que se preparan',
      children: [
        if (materias.isEmpty)
          Text('Primero crea las materias primas.', style: Theme.of(context).textTheme.bodyLarge)
        else if (!_cargada)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          for (final m in materias) ...[
            _Campo(
              controlador: _campos[m.id]!,
              etiqueta: m.nombre,
              sufijo: '%',
              numerico: true,
              alCambiar: () => setState(() {}),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  'Suma: ${decimal(suma)}%',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              Etiqueta(
                texto: completa
                    ? 'Completa'
                    : suma > 100
                    ? 'Se pasa'
                    : 'Falta',
                icono: completa ? Icons.check : Icons.priority_high,
                fondo: completa ? Colores.bienFondo : Colores.revisarFondo,
                color: completa ? Colores.monte : Colores.revisarTexto,
              ),
            ],
          ),
        ],
        _Error(error),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: completa && !guardando
              ? () => guardar(() => widget.estado.definirFormula(widget.producto.id, _ingredientes))
              : null,
          child: const Text('Guardar fórmula'),
        ),
      ],
    );
  }
}

class _HojaRazaNueva extends StatefulWidget {
  const _HojaRazaNueva({required this.estado});

  final EstadoAdministracion estado;

  @override
  State<_HojaRazaNueva> createState() => _HojaRazaNuevaState();
}

class _HojaRazaNuevaState extends State<_HojaRazaNueva> with _Guardado {
  final _nombre = TextEditingController();
  String? _plantilla;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final plantillas = widget.estado.catalogo!.plantillas;
    return _Hoja(
      titulo: 'Nueva raza',
      children: [
        _Campo(controlador: _nombre, etiqueta: 'Nombre', autofoco: true, alCambiar: () => setState(() {})),
        const SizedBox(height: 16),
        Text('¿Empezar con valores de referencia?', style: textos.bodyLarge),
        const SizedBox(height: 8),
        _Opciones<String?>(
          opciones: [(null, 'En blanco'), for (final p in plantillas) (p, p)],
          elegida: _plantilla,
          alElegir: (p) => setState(() {
            _plantilla = p;
            if (p != null && _nombre.text.trim().isEmpty) _nombre.text = p;
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Trae vacunas, peso y postura esperados. Después los puedes cambiar.',
          style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave),
        ),
        _Error(error),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _nombre.text.trim().isNotEmpty && !guardando
              ? () => guardar(() => widget.estado.crearRaza(_nombre.text.trim(), _plantilla))
              : null,
          child: const Text('Crear raza'),
        ),
      ],
    );
  }
}

class _HojaRazaNombre extends StatefulWidget {
  const _HojaRazaNombre({required this.estado, required this.raza});

  final EstadoAdministracion estado;
  final Raza raza;

  @override
  State<_HojaRazaNombre> createState() => _HojaRazaNombreState();
}

class _HojaRazaNombreState extends State<_HojaRazaNombre> with _Guardado {
  late final _nombre = TextEditingController(text: widget.raza.nombre);

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Hoja(
      titulo: 'Nombre de la raza',
      children: [
        _Campo(controlador: _nombre, etiqueta: 'Nombre', autofoco: true, alCambiar: () => setState(() {})),
        _Error(error),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _nombre.text.trim().isNotEmpty && !guardando
              ? () => guardar(() => widget.estado.renombrarRaza(widget.raza.id, _nombre.text.trim()))
              : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _HojaPlan extends StatefulWidget {
  const _HojaPlan({required this.estado, required this.raza});

  final EstadoAdministracion estado;
  final Raza raza;

  @override
  State<_HojaPlan> createState() => _HojaPlanState();
}

class _HojaPlanState extends State<_HojaPlan> with _Guardado {
  List<TareaDePlan>? _tareas;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    widget.estado.plan(widget.raza.id).then((plan) {
      if (!mounted) return;
      setState(() {
        _tareas = plan;
        _fallo = plan == null;
      });
    });
  }

  List<TareaDePlan> get _ordenadas => [..._tareas!]
    ..sort((a, b) {
      final porSemana = a.semanaIdeal.compareTo(b.semanaIdeal);
      return porSemana != 0 ? porSemana : a.semanaMax.compareTo(b.semanaMax);
    });

  Future<void> _editar([TareaDePlan? actual]) async {
    final nueva = await abrirHoja<TareaDePlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.cal,
      builder: (_) => _HojaTarea(actual: actual),
    );
    if (nueva == null || !mounted) return;
    setState(() {
      final lista = _tareas!;
      final i = actual == null ? -1 : lista.indexOf(actual);
      if (i >= 0) {
        lista[i] = nueva;
      } else {
        lista.add(nueva);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return _Hoja(
      titulo: 'Vacunas de ${widget.raza.nombre}',
      subtitulo: 'Qué se aplica y hasta qué semana',
      children: [
        if (_fallo)
          const _Aviso(texto: 'No se pudo traer el plan. Revisa la señal e inténtalo de nuevo.')
        else if (_tareas == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          for (final t in _ordenadas) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colores.borde),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.nombre, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          '${t.cuando} · ${nombreDeTipoTarea(t.tipo)}',
                          style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cambiar ${t.nombre}',
                    onPressed: () => _editar(t),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Quitar ${t.nombre}',
                    onPressed: () => setState(() => _tareas!.remove(t)),
                    icon: const Icon(Icons.delete_outline, color: Colores.urgenteTexto),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_tareas!.isEmpty) const _Aviso(texto: 'Esta raza todavía no tiene vacunas.'),
          TextButton.icon(
            onPressed: _editar,
            icon: const Icon(Icons.add),
            label: const Text('Agregar vacuna o cuidado'),
            style: TextButton.styleFrom(
              foregroundColor: Colores.monte,
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              minimumSize: const Size(0, 48),
            ),
          ),
          _Error(error),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: guardando ? null : () => guardar(() => widget.estado.guardarPlan(widget.raza.id, _ordenadas)),
            child: const Text('Guardar'),
          ),
        ],
      ],
    );
  }
}

class _HojaTarea extends StatefulWidget {
  const _HojaTarea({this.actual});

  final TareaDePlan? actual;

  @override
  State<_HojaTarea> createState() => _HojaTareaState();
}

class _HojaTareaState extends State<_HojaTarea> {
  late final _nombre = TextEditingController(text: widget.actual?.nombre ?? '');
  late final _ideal = TextEditingController(text: widget.actual?.semanaIdeal.toString() ?? '');
  late final _maxima = TextEditingController(text: widget.actual?.semanaMax.toString() ?? '');
  late final _nota = TextEditingController(text: widget.actual?.nota ?? '');
  late TipoTarea _tipo = widget.actual?.tipo ?? TipoTarea.vacuna;

  @override
  void dispose() {
    _nombre.dispose();
    _ideal.dispose();
    _maxima.dispose();
    _nota.dispose();
    super.dispose();
  }

  int? get _semanaIdeal => int.tryParse(_ideal.text.trim());
  int? get _semanaMax => int.tryParse(_maxima.text.trim());

  bool get _valido {
    final ideal = _semanaIdeal;
    final maxima = _semanaMax;
    return _nombre.text.trim().isNotEmpty && ideal != null && maxima != null && ideal >= 0 && maxima >= ideal;
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final ideal = _semanaIdeal;
    final maxima = _semanaMax;
    final mal = ideal != null && maxima != null && maxima < ideal;
    return _Hoja(
      titulo: widget.actual == null ? 'Nueva vacuna o cuidado' : 'Cambiar',
      children: [
        _Campo(controlador: _nombre, etiqueta: 'Nombre', autofoco: true, alCambiar: () => setState(() {})),
        const SizedBox(height: 16),
        _Opciones<TipoTarea>(
          opciones: [for (final t in TipoTarea.values) (t, nombreDeTipoTarea(t))],
          elegida: _tipo,
          alElegir: (t) => setState(() => _tipo = t),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Campo(
                controlador: _ideal,
                etiqueta: 'Semana ideal',
                numerico: true,
                alCambiar: () => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Campo(
                controlador: _maxima,
                etiqueta: 'Semana máxima',
                numerico: true,
                alCambiar: () => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          mal
              ? 'La semana máxima no puede ser menor que la ideal.'
              : 'Después de la semana máxima se marca como atrasada. 0 es al nacer.',
          style: textos.bodyMedium?.copyWith(color: mal ? Colores.urgenteTexto : Colores.tintaSuave),
        ),
        const SizedBox(height: 12),
        _Campo(controlador: _nota, etiqueta: 'Nota (opcional)'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _valido
              ? () => Navigator.of(context).pop(
                  TareaDePlan(
                    id: widget.actual?.id,
                    nombre: _nombre.text.trim(),
                    tipo: _tipo,
                    semanaIdeal: _semanaIdeal!,
                    semanaMax: _semanaMax!,
                    nota: _nota.text.trim(),
                  ),
                )
              : null,
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

class _HojaCurva extends StatefulWidget {
  const _HojaCurva({required this.estado, required this.raza});

  final EstadoAdministracion estado;
  final Raza raza;

  @override
  State<_HojaCurva> createState() => _HojaCurvaState();
}

class _HojaCurvaState extends State<_HojaCurva> with _Guardado {
  final _texto = TextEditingController();
  bool _cargada = false;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    widget.estado.curva(widget.raza.id).then((puntos) {
      if (!mounted) return;
      setState(() {
        _fallo = puntos == null;
        _cargada = puntos != null;
        if (puntos != null) _texto.text = curvaComoTexto(puntos);
      });
    });
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<String?> _enviar() async {
    final leida = leerCurva(_texto.text);
    if (!leida.esValida) return leida.error;
    return widget.estado.guardarCurva(widget.raza.id, leida.puntos);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return _Hoja(
      titulo: 'Curva de ${widget.raza.nombre}',
      subtitulo: 'Postura y peso esperados por semana de edad',
      children: [
        if (_fallo)
          const _Aviso(texto: 'No se pudo traer la curva. Revisa la señal e inténtalo de nuevo.')
        else if (!_cargada)
          const Center(child: CircularProgressIndicator())
        else ...[
          Text(
            'Una semana por línea: semana, % de postura y peso en gramos. Ejemplo: 30 95 1890',
            style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _texto,
            minLines: 8,
            maxLines: 14,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontSize: 18, fontFamily: 'monospace'),
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '30 95 1890'),
          ),
          _Error(error),
          const SizedBox(height: 16),
          FilledButton(onPressed: guardando ? null : () => guardar(_enviar), child: const Text('Guardar')),
        ],
      ],
    );
  }
}

class _HojaCategoriaNueva extends StatefulWidget {
  const _HojaCategoriaNueva({required this.estado});

  final EstadoAdministracion estado;

  @override
  State<_HojaCategoriaNueva> createState() => _HojaCategoriaNuevaState();
}

class _HojaCategoriaNuevaState extends State<_HojaCategoriaNueva> with _Guardado {
  final _nombre = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Hoja(
      titulo: 'Nueva categoría de huevo',
      children: [
        _Campo(controlador: _nombre, etiqueta: 'Nombre', autofoco: true, alCambiar: () => setState(() {})),
        _Error(error),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _nombre.text.trim().isNotEmpty && !guardando
              ? () => guardar(() => widget.estado.crearCategoriaHuevo(_nombre.text.trim()))
              : null,
          child: const Text('Crear categoría'),
        ),
      ],
    );
  }
}

class _HojaCategoriaNombre extends StatefulWidget {
  const _HojaCategoriaNombre({required this.estado, required this.categoria});

  final EstadoAdministracion estado;
  final CategoriaHuevo categoria;

  @override
  State<_HojaCategoriaNombre> createState() => _HojaCategoriaNombreState();
}

class _HojaCategoriaNombreState extends State<_HojaCategoriaNombre> with _Guardado {
  late final _nombre = TextEditingController(text: widget.categoria.nombre);

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Hoja(
      titulo: 'Nombre de la categoría',
      children: [
        _Campo(controlador: _nombre, etiqueta: 'Nombre', autofoco: true, alCambiar: () => setState(() {})),
        _Error(error),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _nombre.text.trim().isNotEmpty && !guardando
              ? () =>
                    guardar(() => widget.estado.cambiarCategoriaHuevo(widget.categoria.id, nombre: _nombre.text.trim()))
              : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _HojaPrecioHuevo extends StatefulWidget {
  const _HojaPrecioHuevo({required this.estado, required this.categoria, required this.actual});

  final EstadoAdministracion estado;
  final CategoriaHuevo categoria;
  final PrecioHuevo? actual;

  @override
  State<_HojaPrecioHuevo> createState() => _HojaPrecioHuevoState();
}

class _HojaPrecioHuevoState extends State<_HojaPrecioHuevo> with _Guardado {
  late final _caja = TextEditingController(text: _texto(widget.actual?.precioCaja));
  late final _carton = TextEditingController(text: _texto(widget.actual?.precioCarton));
  late final _mayorista = TextEditingController(text: _texto(widget.actual?.precioMayorista));

  static String _texto(double? valor) => valor == null ? '' : '${valor.round()}';

  @override
  void dispose() {
    _caja.dispose();
    _carton.dispose();
    _mayorista.dispose();
    super.dispose();
  }

  double? _leer(TextEditingController c) {
    final valor = leerNumero(c.text);
    return valor == null || valor <= 0 ? null : valor;
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final caja = _leer(_caja);
    return _Hoja(
      titulo: 'Precios del huevo ${widget.categoria.nombre}',
      subtitulo: 'Una caja son 12 cartones de 30 huevos',
      children: [
        _Campo(
          controlador: _caja,
          etiqueta: 'Precio de la caja (clientes)',
          sufijo: 'pesos',
          numerico: true,
          alCambiar: () => setState(() {}),
        ),
        if (caja != null) ...[
          const SizedBox(height: 4),
          Text('A clientes, cada cartón sale a ${pesos(caja / cartonesPorCaja)}', style: textos.bodyMedium),
        ],
        const SizedBox(height: 12),
        _Campo(
          controlador: _carton,
          etiqueta: 'Precio del cartón (particulares)',
          sufijo: 'pesos',
          numerico: true,
          alCambiar: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        _Campo(
          controlador: _mayorista,
          etiqueta: 'Precio de la caja al mayorista',
          sufijo: 'pesos',
          numerico: true,
          alCambiar: () => setState(() {}),
        ),
        _Error(error),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: guardando
              ? null
              : () => guardar(
                  () => widget.estado.fijarPrecioHuevo(
                    widget.categoria.id,
                    caja: caja,
                    carton: _leer(_carton),
                    mayorista: _leer(_mayorista),
                  ),
                ),
          child: const Text('Guardar precios'),
        ),
      ],
    );
  }
}
