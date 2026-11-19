import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../datos/api_iot.dart';
import '../dominio/galpon_vivo.dart';
import 'estado_galpon_vivo.dart';
import 'hoja.dart';
import 'tema.dart';

const _iconos = {
  'galpon1-ambiente': Icons.thermostat,
  'galpon1-gases': Icons.air,
  'galpon1-ventilacion': Icons.wind_power,
  'galpon1-iluminacion': Icons.lightbulb_outline,
  'tanque-agua': Icons.water_drop_outlined,
  'tablero-energia': Icons.bolt,
  'contador-huevos': Icons.egg_outlined,
  'silo-alimento': Icons.inventory_2_outlined,
  'clima-openmeteo': Icons.cloud_outlined,
  'clima-azure-maps': Icons.wb_sunny_outlined,
  'historico-era5': Icons.history,
  'pasarela-finca': Icons.router_outlined,
  'galpon2-ambiente': Icons.memory,
};

IconData iconoDe(String id) => _iconos[id] ?? Icons.sensors;

class TarjetaGalponVivo extends StatelessWidget {
  const TarjetaGalponVivo({super.key, required this.estado, required this.alAbrir});

  final EstadoGalponVivo estado;
  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) {
        final hayDatos = estado.dispositivos.isNotEmpty;
        final criticas = estado.alertas.where((a) => a.critica).length;
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: alAbrir,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sensors, color: Colores.monte, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Galpón en vivo', style: textos.titleLarge),
                              if (hayDatos)
                                Text(
                                  '${estado.enLinea} de ${estado.dispositivos.length} equipos conectados',
                                  style: textos.bodyMedium?.copyWith(color: Colores.monte, fontWeight: FontWeight.w700),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colores.tintaSuave),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (!hayDatos)
                      Text(
                        estado.error ??
                            (estado.cargando ? 'Conectando con los sensores…' : 'Toca para ver los sensores'),
                        style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave),
                      )
                    else ...[
                      Wrap(
                        spacing: 18,
                        runSpacing: 8,
                        children: [
                          _Dato('Temperatura', estado.valor('galpon1-ambiente', 'temperatura'), '°C'),
                          _Dato('Humedad', estado.valor('galpon1-ambiente', 'humedad'), '%'),
                          _Dato('Amoníaco', estado.valor('galpon1-gases', 'amoniaco'), 'ppm'),
                          _Dato('Tanque', estado.valor('tanque-agua', 'nivel'), '%'),
                        ],
                      ),
                      if (estado.alertas.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _Etiqueta(
                          texto: criticas > 0
                              ? '$criticas ${criticas == 1 ? 'alerta crítica' : 'alertas críticas'}: ${estado.alertas.firstWhere((a) => a.critica).mensaje}'
                              : '${estado.alertas.length} ${estado.alertas.length == 1 ? 'aviso' : 'avisos'}: ${estado.alertas.first.mensaje}',
                          fondo: criticas > 0 ? Colores.urgenteFondo : Colores.revisarFondo,
                          color: criticas > 0 ? Colores.urgenteTexto : Colores.revisarTexto,
                          largo: true,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.titulo, this.valor, this.unidad);

  final String titulo;
  final double? valor;
  final String unidad;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave)),
        Text(
          valor == null ? '—' : '${numeroCorto(valor!)} $unidad',
          style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.fondo, required this.color, this.largo = false});

  final String texto;
  final Color fondo;
  final Color color;
  final bool largo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Text(
        texto,
        maxLines: largo ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }
}

class GalponVivoPantalla extends StatefulWidget {
  const GalponVivoPantalla({super.key, required this.estado, required this.puedeControlar});

  final EstadoGalponVivo estado;
  final bool puedeControlar;

  @override
  State<GalponVivoPantalla> createState() => _GalponVivoPantallaState();
}

class _GalponVivoPantallaState extends State<GalponVivoPantalla> {
  @override
  void initState() {
    super.initState();
    widget.estado.mirar();
  }

  @override
  void dispose() {
    widget.estado.dejarDeMirar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Galpón en vivo')),
      body: ListenableBuilder(
        listenable: widget.estado,
        builder: (context, _) {
          final estado = widget.estado;
          final ahora = DateTime.now();
          return RefreshIndicator(
            onRefresh: estado.cargar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (estado.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _Etiqueta(
                      texto: estado.error!,
                      fondo: Colores.urgenteFondo,
                      color: Colores.urgenteTexto,
                      largo: true,
                    ),
                  ),
                if (estado.dispositivos.isEmpty && estado.cargando)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (estado.actualizado != null)
                  Text(
                    '${estado.enLinea} de ${estado.dispositivos.length} equipos conectados · '
                    'actualizado ${haceCuanto(estado.actualizado, ahora)}',
                    style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave),
                  ),
                if (estado.alertas.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Alertas activas', style: textos.titleLarge),
                  const SizedBox(height: 6),
                  for (final alerta in estado.alertas) _FilaAlerta(alerta: alerta, estado: estado),
                ],
                for (final grupo in estado.grupos) ...[
                  const SizedBox(height: 18),
                  Text(grupo.titulo, style: textos.titleLarge),
                  const SizedBox(height: 6),
                  for (final d in grupo.dispositivos)
                    _TarjetaDispositivo(
                      dispositivo: d,
                      ahora: ahora,
                      alTocar: () => abrirHoja<void>(
                        context: context,
                        builder: (_) =>
                            HojaDispositivoIot(estado: estado, id: d.id, puedeControlar: widget.puedeControlar),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilaAlerta extends StatelessWidget {
  const _FilaAlerta({required this.alerta, required this.estado});

  final AlertaIot alerta;
  final EstadoGalponVivo estado;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final nombre = estado.dispositivo(alerta.dispositivo)?.nombre ?? alerta.dispositivo;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alerta.critica ? Colores.urgenteFondo : Colores.revisarFondo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            alerta.critica ? Icons.warning_amber_rounded : Icons.info_outline,
            color: alerta.critica ? Colores.urgenteTexto : Colores.revisarTexto,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alerta.mensaje, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  '$nombre · ${nombreVariable(alerta.variable)} llegó a ${numeroCorto(alerta.valorExtremo)} · '
                  '${haceCuanto(alerta.inicio, DateTime.now())}',
                  style: textos.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaDispositivo extends StatelessWidget {
  const _TarjetaDispositivo({required this.dispositivo, required this.ahora, required this.alTocar});

  final DispositivoIot dispositivo;
  final DateTime ahora;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final d = dispositivo;
    final visibles = d.variables.take(4).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(iconoDe(d.id), color: d.enLinea ? Colores.monte : Colores.tintaSuave),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(d.nombre, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  _EstadoConexion(dispositivo: d),
                  const Icon(Icons.chevron_right, color: Colores.tintaSuave),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${d.categoria} · ${d.protocolo} · ${haceCuanto(d.ultimoContacto, ahora)}',
                style: textos.bodySmall?.copyWith(color: Colores.tintaSuave),
              ),
              if (d.ultimos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    for (final v in visibles)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombreVariable(v.nombre), style: textos.bodySmall?.copyWith(color: Colores.tintaSuave)),
                          Text(
                            valorConUnidad(d.valor(v.nombre), v),
                            style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoConexion extends StatelessWidget {
  const _EstadoConexion({required this.dispositivo});

  final DispositivoIot dispositivo;

  @override
  Widget build(BuildContext context) {
    if (!dispositivo.encendido) {
      return const _Etiqueta(texto: 'Apagado', fondo: Colores.revisarFondo, color: Colores.revisarTexto);
    }
    return dispositivo.enLinea
        ? const _Etiqueta(texto: 'En línea', fondo: Colores.bienFondo, color: Colores.monte)
        : const _Etiqueta(texto: 'Sin conexión', fondo: Colores.faltaFondo, color: Colores.tintaSuave);
  }
}

class HojaDispositivoIot extends StatefulWidget {
  const HojaDispositivoIot({super.key, required this.estado, required this.id, required this.puedeControlar});

  final EstadoGalponVivo estado;
  final String id;
  final bool puedeControlar;

  @override
  State<HojaDispositivoIot> createState() => _HojaDispositivoIotState();
}

class _HojaDispositivoIotState extends State<HojaDispositivoIot> {
  String? _variable;
  Future<SerieIot>? _serie;
  bool _enviando = false;
  double? _velocidad;
  final _kilos = TextEditingController();

  @override
  void dispose() {
    _kilos.dispose();
    super.dispose();
  }

  void _elegir(String variable) {
    setState(() {
      _variable = variable;
      _serie = widget.estado.serie(widget.id, variable);
    });
  }

  Future<void> _ordenar(ComandoIot comando) async {
    if (_enviando) return;
    setState(() => _enviando = true);
    final mensajero = ScaffoldMessenger.of(context);
    try {
      String mensaje;
      try {
        mensaje = await widget.estado.ordenar(widget.id, comando);
      } on ClaveIotInvalida {
        if (!mounted) return;
        final clave = await _pedirClave(context);
        if (clave == null) return;
        mensaje = await widget.estado.ordenar(widget.id, comando, claveNueva: clave);
      }
      mensajero.showSnackBar(SnackBar(content: Text(mensaje)));
    } on ErrorIot catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: widget.estado,
      builder: (context, _) {
        final d = widget.estado.dispositivo(widget.id);
        if (d == null) return const Padding(padding: EdgeInsets.all(24), child: Text('El equipo ya no aparece.'));
        if (_variable == null && d.variables.isNotEmpty) {
          _variable = d.variables.first.nombre;
          _serie = widget.estado.serie(widget.id, _variable!);
        }
        final variable = d.variables.where((v) => v.nombre == _variable).firstOrNull;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(iconoDe(d.id), color: Colores.monte, size: 30),
                  const SizedBox(width: 10),
                  Expanded(child: Text(d.nombre, style: textos.headlineSmall)),
                  _EstadoConexion(dispositivo: d),
                ],
              ),
              const SizedBox(height: 6),
              Text(d.descripcion, style: textos.bodyLarge),
              const SizedBox(height: 4),
              Text(
                '${d.categoria} · ${d.protocolo} · envía cada ${d.intervalo} s · ${d.ubicacion}',
                style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in d.variables)
                    ChoiceChip(
                      selected: v.nombre == _variable,
                      onSelected: (_) => _elegir(v.nombre),
                      label: Text('${nombreVariable(v.nombre)}: ${valorConUnidad(d.valor(v.nombre), v)}'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (variable != null)
                FutureBuilder<SerieIot>(
                  future: _serie,
                  builder: (context, foto) {
                    if (foto.hasError) {
                      return Text('No se pudo traer la gráfica.', style: textos.bodyMedium);
                    }
                    final serie = foto.data;
                    if (serie == null) {
                      return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
                    }
                    return _BloqueGrafica(serie: serie, variable: variable);
                  },
                ),
              if (widget.puedeControlar) ...[
                const SizedBox(height: 18),
                Text('Controlar', style: textos.titleLarge),
                const SizedBox(height: 8),
                ..._controles(d),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _controles(DispositivoIot d) {
    final enviar = _enviando ? null : _ordenar;
    final botones = <Widget>[
      Row(
        children: [
          Expanded(
            child: d.encendido
                ? OutlinedButton.icon(
                    onPressed: enviar == null ? null : () => enviar(const ComandoIot(accion: 'apagar')),
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Apagar sensor'),
                  )
                : FilledButton.icon(
                    onPressed: enviar == null ? null : () => enviar(const ComandoIot(accion: 'encender')),
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Encender sensor'),
                  ),
          ),
        ],
      ),
    ];
    if (d.permite('velocidad')) {
      final automatico = d.estado['modo'] != 'manual';
      final velocidad = _velocidad ?? (d.valor('velocidad') ?? 50).clamp(0, 100).toDouble();
      botones.addAll([
        const SizedBox(height: 12),
        Text(
          automatico ? 'Modo automático: siguen la temperatura' : 'Modo manual a ${velocidad.round()} %',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          value: velocidad,
          max: 100,
          divisions: 10,
          label: '${velocidad.round()} %',
          onChanged: (v) => setState(() => _velocidad = v),
        ),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: enviar == null
                    ? null
                    : () => enviar(ComandoIot(accion: 'velocidad', parametros: {'valor': velocidad.round()})),
                child: Text('Fijar ${velocidad.round()} %'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: enviar == null
                    ? null
                    : () => enviar(const ComandoIot(accion: 'modo', parametros: {'auto': true})),
                child: const Text('Automático'),
              ),
            ),
          ],
        ),
      ]);
    }
    if (d.permite('forzar')) {
      botones.addAll([
        const SizedBox(height: 12),
        _filaOpciones('Luces', [
          ('Encender', const ComandoIot(accion: 'forzar', parametros: {'valor': 1})),
          ('Apagar', const ComandoIot(accion: 'forzar', parametros: {'valor': 0})),
          ('Según horario', const ComandoIot(accion: 'forzar', parametros: {'valor': null})),
        ], enviar),
      ]);
    }
    if (d.permite('bomba')) {
      botones.addAll([
        const SizedBox(height: 12),
        _filaOpciones('Bomba de llenado', [
          ('Encender', const ComandoIot(accion: 'bomba', parametros: {'valor': 1})),
          ('Apagar', const ComandoIot(accion: 'bomba', parametros: {'valor': 0})),
          ('Automática', const ComandoIot(accion: 'bomba', parametros: {'valor': 'auto'})),
        ], enviar),
      ]);
    }
    if (d.permite('led')) {
      botones.addAll([
        const SizedBox(height: 12),
        _filaOpciones('LED de alarma', [
          ('Encender', const ComandoIot(accion: 'led', parametros: {'valor': 1})),
          ('Apagar', const ComandoIot(accion: 'led', parametros: {'valor': 0})),
        ], enviar),
      ]);
    }
    if (d.permite('simular_corte')) {
      botones.addAll([
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: enviar == null
              ? null
              : () => enviar(const ComandoIot(accion: 'simular_corte', parametros: {'minutos': 5})),
          icon: const Icon(Icons.power_off_outlined),
          label: const Text('Simular corte de luz de 5 min'),
        ),
      ]);
    }
    if (d.permite('llenado')) {
      botones.addAll([
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _kilos,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Llegó alimento (kg)'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: enviar == null
                  ? null
                  : () {
                      final kilos = double.tryParse(_kilos.text.replaceAll(',', '.'));
                      if (kilos == null || kilos <= 0) return;
                      enviar(ComandoIot(accion: 'llenado', parametros: {'kg': kilos}));
                    },
              child: const Text('Registrar'),
            ),
          ],
        ),
      ]);
    }
    return botones;
  }

  Widget _filaOpciones(String titulo, List<(String, ComandoIot)> opciones, Future<void> Function(ComandoIot)? enviar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (texto, comando) in opciones)
              OutlinedButton(onPressed: enviar == null ? null : () => enviar(comando), child: Text(texto)),
          ],
        ),
      ],
    );
  }
}

Future<String?> _pedirClave(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _DialogoClave());

class _DialogoClave extends StatefulWidget {
  const _DialogoClave();

  @override
  State<_DialogoClave> createState() => _DialogoClaveState();
}

class _DialogoClaveState extends State<_DialogoClave> {
  final _campo = TextEditingController();

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _guardar() {
    final clave = _campo.text.trim();
    Navigator.of(context).pop(clave.isEmpty ? null : clave);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clave del galpón'),
      content: TextField(
        controller: _campo,
        obscureText: true,
        autofocus: true,
        onSubmitted: (_) => _guardar(),
        decoration: const InputDecoration(labelText: 'Clave para enviar órdenes'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}

class _BloqueGrafica extends StatelessWidget {
  const _BloqueGrafica({required this.serie, required this.variable});

  final SerieIot serie;
  final VariableIot variable;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    if (serie.puntos.isEmpty) return Text('Sin datos en las últimas 24 horas.', style: textos.bodyMedium);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Últimas 24 horas', style: textos.titleMedium),
        const SizedBox(height: 6),
        SizedBox(height: 170, child: CustomPaint(painter: GraficaSerie(serie.puntos, variable.esSiNo))),
        const SizedBox(height: 8),
        Row(
          children: [
            _Resumen('Promedio', serie.promedio, variable),
            _Resumen('Mínimo', serie.minimo, variable),
            _Resumen('Máximo', serie.maximo, variable),
          ],
        ),
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen(this.titulo, this.valor, this.variable);

  final String titulo;
  final double? valor;
  final VariableIot variable;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: textos.bodySmall?.copyWith(color: Colores.tintaSuave)),
          Text(
            variable.esSiNo ? '${numeroCorto((valor ?? 0) * 100)} % del tiempo' : valorConUnidad(valor, variable),
            style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class GraficaSerie extends CustomPainter {
  GraficaSerie(this.puntos, this.siNo);

  final List<PuntoSerie> puntos;
  final bool siNo;

  @override
  void paint(Canvas canvas, Size size) {
    if (puntos.isEmpty) return;
    const izquierda = 44.0;
    const abajo = 18.0;
    final ancho = size.width - izquierda;
    final alto = size.height - abajo;
    var minimo = siNo ? 0.0 : puntos.map((p) => p.minimo).reduce(math.min);
    var maximo = siNo ? 1.0 : puntos.map((p) => p.maximo).reduce(math.max);
    if (maximo - minimo < 1e-9) {
      minimo -= 1;
      maximo += 1;
    }
    final inicio = puntos.first.momento.millisecondsSinceEpoch.toDouble();
    final fin = math.max(puntos.last.momento.millisecondsSinceEpoch.toDouble(), inicio + 1);
    Offset punto(DateTime t, double v) => Offset(
      izquierda + (t.millisecondsSinceEpoch - inicio) / (fin - inicio) * ancho,
      alto - (v - minimo) / (maximo - minimo) * alto,
    );

    final guia = Paint()
      ..color = Colores.borde
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = alto * i / 2;
      canvas.drawLine(Offset(izquierda, y), Offset(size.width, y), guia);
      _texto(canvas, numeroCorto(maximo - (maximo - minimo) * i / 2), Offset(0, y - 8), izquierda - 4);
    }

    final banda = Path();
    for (var i = 0; i < puntos.length; i++) {
      final p = punto(puntos[i].momento, puntos[i].maximo);
      i == 0 ? banda.moveTo(p.dx, p.dy) : banda.lineTo(p.dx, p.dy);
    }
    for (final p in puntos.reversed) {
      final q = punto(p.momento, p.minimo);
      banda.lineTo(q.dx, q.dy);
    }
    banda.close();
    canvas.drawPath(banda, Paint()..color = Colores.monte.withValues(alpha: 0.14));

    final linea = Path();
    for (var i = 0; i < puntos.length; i++) {
      final p = punto(puntos[i].momento, puntos[i].promedio);
      i == 0 ? linea.moveTo(p.dx, p.dy) : linea.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linea,
      Paint()
        ..color = Colores.monte
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );

    String hora(DateTime t) {
      final local = t.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    _texto(canvas, hora(puntos.first.momento), Offset(izquierda, alto + 3), 60);
    _texto(canvas, hora(puntos.last.momento), Offset(size.width - 44, alto + 3), 44, derecha: true);
  }

  void _texto(Canvas canvas, String texto, Offset donde, double ancho, {bool derecha = false}) {
    final pintor = TextPainter(
      text: TextSpan(
        text: texto,
        style: const TextStyle(fontFamily: letraGranja, fontSize: 11, color: Colores.tintaSuave),
      ),
      textAlign: derecha ? TextAlign.right : TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: ancho, maxWidth: ancho);
    pintor.paint(canvas, donde);
  }

  @override
  bool shouldRepaint(GraficaSerie anterior) => anterior.puntos != puntos || anterior.siNo != siNo;
}
