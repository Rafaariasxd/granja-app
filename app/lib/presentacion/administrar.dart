import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dominio/administracion.dart';
import '../dominio/inventario.dart';
import '../dominio/modelos.dart';
import 'bodega.dart' show nombreDeEtapa;
import 'estado_administracion.dart';
import 'etiqueta.dart';
import 'formato.dart';
import 'tema.dart';

String nombreDeTipoInsumo(TipoInsumo tipo) => switch (tipo) {
  TipoInsumo.materiaPrima => 'Materia prima',
  TipoInsumo.alimentoComprado => 'Alimento comprado',
  TipoInsumo.alimentoPreparado => 'Alimento que preparamos',
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
    final resultado = await showModalBottomSheet<bool>(
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
                  Text('Bodegas, insumos y fórmulas', style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave)),
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
  bool get _llevaBulto => _tipo != TipoInsumo.alimentoPreparado;

  bool get _valido {
    if (_nombre.text.trim().isEmpty) return false;
    if (_llevaEtapa && _etapa == null) return false;
    if (_llevaBulto && (leerNumero(_porBulto.text) ?? 0) <= 0) return false;
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
        if (_llevaBulto) ...[
          const SizedBox(height: 16),
          _Campo(
            controlador: _porBulto,
            etiqueta: 'Kilos por bulto',
            sufijo: 'kg',
            numerico: true,
            alCambiar: () => setState(() {}),
          ),
        ],
        _Error(error),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _valido && !guardando
              ? () => guardar(
                  () => widget.estado.crearInsumo(
                    nombre: _nombre.text.trim(),
                    tipo: _tipo,
                    etapa: _llevaEtapa ? _etapa : null,
                    kgPorBulto: _llevaBulto ? leerNumero(_porBulto.text) : null,
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
