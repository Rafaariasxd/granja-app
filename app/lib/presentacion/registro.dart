import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'estado_envios.dart';
import 'fecha_texto.dart';
import 'formato.dart';
import 'formulario_registro.dart';
import 'tema.dart';

class RegistroPantalla extends StatefulWidget {
  const RegistroPantalla({super.key, required this.formulario, required this.envios, this.reloj});

  final FormularioRegistro formulario;
  final EstadoEnvios envios;
  final DateTime Function()? reloj;

  @override
  State<RegistroPantalla> createState() => _RegistroPantallaState();
}

class _RegistroPantallaState extends State<RegistroPantalla> {
  late final TextEditingController _huevos;
  late final TextEditingController _alimento;
  bool _guardando = false;

  FormularioRegistro get _f => widget.formulario;

  @override
  void initState() {
    super.initState();
    _huevos = TextEditingController(text: _f.huevos == 0 ? '' : '${_f.huevos}');
    _alimento = TextEditingController(text: _f.alimentoKg == 0 ? '' : _f.alimentoKg.round().toString());
  }

  @override
  void dispose() {
    _huevos.dispose();
    _alimento.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final ahora = (widget.reloj ?? DateTime.now)();
    await widget.envios.guardar(_f.aRegistro(), ahora);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final galpon = _f.galpon;
    final detalle = [
      if (galpon.linea != null) galpon.linea!,
      if (galpon.edadSemanas != null) '${galpon.edadSemanas} semanas',
      '${miles(galpon.avesVivas)} aves',
    ].join(' · ');
    return ListenableBuilder(
      listenable: _f,
      builder: (context, _) {
        final errores = _f.errores;
        final puedeGuardar = _f.huevos > 0 && _f.esValido && !_guardando;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colores.cal,
            scrolledUnderElevation: 0,
            toolbarHeight: 64,
            leadingWidth: 64,
            leading: IconButton(
              tooltip: 'Volver al inicio',
              icon: const Icon(Icons.arrow_back, size: 28),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    children: [
                      Text(galpon.nombre, style: textos.headlineMedium),
                      const SizedBox(height: 4),
                      Text('Hoy, ${fechaLarga(_f.fecha).toLowerCase()}', style: textos.bodyLarge),
                      Text(detalle, style: textos.bodyMedium?.copyWith(color: Colores.tintaSuave)),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Huevos recogidos',
                                style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _huevos,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  border: OutlineInputBorder(),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colores.monte, width: 2),
                                  ),
                                ),
                                onChanged: (texto) => _f.cambiarHuevos(int.tryParse(texto) ?? 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Contador(
                        titulo: 'Huevos rotos',
                        valor: _f.rotos,
                        menos: 'Un huevo roto menos',
                        mas: 'Un huevo roto más',
                        alCambiar: _f.sumarRotos,
                      ),
                      const SizedBox(height: 12),
                      _Contador(
                        titulo: 'Gallinas muertas',
                        valor: _f.muertas,
                        menos: 'Una gallina muerta menos',
                        mas: 'Una gallina muerta más',
                        alCambiar: _f.sumarMuertas,
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Alimento',
                                  style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              SizedBox(
                                width: 112,
                                child: TextField(
                                  controller: _alimento,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.end,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(5),
                                  ],
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0'),
                                  onChanged: (texto) => _f.cambiarAlimento((int.tryParse(texto) ?? 0).toDouble()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('kg', style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    children: [
                      if (errores.isNotEmpty)
                        _Aviso(
                          fondo: Colores.revisarFondo,
                          color: Colores.revisarTexto,
                          icono: Icons.warning_amber_rounded,
                          titulo: 'Revisa los datos',
                          detalle: errores.join(' '),
                        )
                      else if (_f.huevos > 0)
                        _Aviso(
                          fondo: Colores.bienFondo,
                          color: Colores.monte,
                          icono: Icons.check,
                          titulo: 'Postura de hoy: ${_f.postura.toStringAsFixed(1).replaceAll('.', ',')}%',
                          detalle: null,
                        ),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: puedeGuardar ? _guardar : null, child: const Text('Guardar')),
                      const SizedBox(height: 8),
                      Text(
                        'Sin señal: se guarda en el celular y se envía solo.',
                        textAlign: TextAlign.center,
                        style: textos.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({
    required this.titulo,
    required this.valor,
    required this.menos,
    required this.mas,
    required this.alCambiar,
  });

  final String titulo;
  final int valor;
  final String menos;
  final String mas;
  final void Function(int cambio) alCambiar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(titulo, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            _Boton(icono: Icons.remove, etiqueta: menos, alPulsar: valor > 0 ? () => alCambiar(-1) : null),
            SizedBox(
              width: 56,
              child: Text(
                '$valor',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
            ),
            _Boton(icono: Icons.add, etiqueta: mas, alPulsar: () => alCambiar(1)),
          ],
        ),
      ),
    );
  }
}

class _Boton extends StatelessWidget {
  const _Boton({required this.icono, required this.etiqueta, required this.alPulsar});

  final IconData icono;
  final String etiqueta;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: etiqueta,
      onPressed: alPulsar,
      icon: Icon(icono, size: 26),
      style: IconButton.styleFrom(
        minimumSize: const Size(52, 52),
        side: const BorderSide(color: Color(0xFFC9C8BF), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.fondo,
    required this.color,
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final Color fondo;
  final Color color;
  final IconData icono;
  final String titulo;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(18)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
                  ),
                  if (detalle != null) Text(detalle!, style: TextStyle(fontSize: 15, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
