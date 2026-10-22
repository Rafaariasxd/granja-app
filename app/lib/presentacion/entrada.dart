import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'estado_sesion.dart';

class EntradaPantalla extends StatefulWidget {
  const EntradaPantalla({super.key, required this.estado});

  final EstadoSesion estado;

  @override
  State<EntradaPantalla> createState() => _EntradaPantallaState();
}

class _EntradaPantallaState extends State<EntradaPantalla> {
  final _nombre = TextEditingController();
  final _pin = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _pin.dispose();
    super.dispose();
  }

  bool get _completo => _nombre.text.trim().isNotEmpty && _pin.text.length == 6;

  void _entrar() {
    if (_completo) widget.estado.entrar(_nombre.text, _pin.text);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: widget.estado,
      builder: (context, _) {
        final estado = widget.estado;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              children: [
                Text('Granja App', style: textos.headlineMedium),
                const SizedBox(height: 8),
                Text('Entra con tu nombre y tu PIN de 6 números.', style: textos.bodyLarge),
                const SizedBox(height: 32),
                TextField(
                  controller: _nombre,
                  enabled: !estado.entrando,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  style: textos.titleLarge,
                  decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _pin,
                  enabled: !estado.entrando,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  autofillHints: const [AutofillHints.password],
                  style: textos.titleLarge?.copyWith(letterSpacing: 8),
                  decoration: const InputDecoration(labelText: 'PIN', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _entrar(),
                ),
                if (estado.error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      estado.error!,
                      style: textos.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _completo && !estado.entrando ? _entrar : null,
                  child: Text(estado.entrando ? 'Entrando…' : 'Entrar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
