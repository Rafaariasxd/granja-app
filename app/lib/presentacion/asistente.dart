import 'package:flutter/material.dart';

import '../dominio/asistente.dart';
import 'estado_asistente.dart';
import 'tema.dart';

class AsistentePantalla extends StatefulWidget {
  const AsistentePantalla({super.key, required this.estado, this.pregunta, this.elegirFoto});

  final EstadoAsistente estado;
  final String? pregunta;
  final Future<Foto?> Function()? elegirFoto;

  @override
  State<AsistentePantalla> createState() => _AsistentePantallaState();
}

class _AsistentePantallaState extends State<AsistentePantalla> {
  late final _texto = TextEditingController(text: widget.pregunta ?? '');
  final _desplazamiento = ScrollController();

  @override
  void dispose() {
    _texto.dispose();
    _desplazamiento.dispose();
    super.dispose();
  }

  Future<void> _enviar([String? sugerida]) async {
    final texto = sugerida ?? _texto.text;
    if (texto.trim().isEmpty) return;
    _texto.clear();
    final envio = widget.estado.preguntar(texto);
    _bajar();
    await envio;
    _bajar();
  }

  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_desplazamiento.hasClients) {
        _desplazamiento.animateTo(
          _desplazamiento.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _foto() async {
    final foto = await widget.elegirFoto?.call();
    if (foto != null) widget.estado.ponerFoto(foto);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: widget.estado,
      builder: (context, _) {
        final estado = widget.estado;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colores.cal,
            scrolledUnderElevation: 0,
            toolbarHeight: 64,
            leadingWidth: 64,
            leading: IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text('Asistente de las aves', style: textos.titleLarge),
            actions: [
              if (!estado.vacio)
                IconButton(
                  tooltip: 'Nueva conversación',
                  onPressed: estado.pensando ? null : estado.nuevaConversacion,
                  icon: const Icon(Icons.add_comment_outlined, size: 28),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colores.revisarFondo, borderRadius: BorderRadius.circular(14)),
                  child: const Text(
                    'Es una orientación general y conoce los datos de la granja. No reemplaza al veterinario.',
                    style: TextStyle(fontSize: 15, color: Colores.revisarTexto),
                  ),
                ),
                Expanded(
                  child: estado.vacio
                      ? _Sugerencias(alElegir: _enviar)
                      : ListView(
                          controller: _desplazamiento,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: [
                            for (final m in estado.mensajes) _Burbuja(mensaje: m),
                            if (estado.pensando)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3)),
                                    SizedBox(width: 12),
                                    Text('Pensando…', style: TextStyle(fontSize: 17)),
                                  ],
                                ),
                              ),
                            if (estado.error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      estado.error!,
                                      style: const TextStyle(fontSize: 16, color: Colores.urgenteTexto),
                                    ),
                                    TextButton(onPressed: estado.reintentar, child: const Text('Intentar de nuevo')),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
                if (estado.foto != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InputChip(
                      avatar: const Icon(Icons.photo_outlined),
                      label: const Text('Foto lista para enviar', style: TextStyle(fontSize: 16)),
                      onDeleted: estado.quitarFoto,
                      deleteButtonTooltipMessage: 'Quitar la foto',
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.elegirFoto != null)
                        IconButton(
                          tooltip: 'Agregar una foto',
                          onPressed: estado.pensando ? null : _foto,
                          icon: const Icon(Icons.add_a_photo_outlined, size: 28),
                        ),
                      Expanded(
                        child: TextField(
                          controller: _texto,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(
                            hintText: 'Escribe tu pregunta',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Enviar',
                        onPressed: estado.pensando ? null : _enviar,
                        icon: const Icon(Icons.send, size: 26),
                        style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
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

class _Sugerencias extends StatelessWidget {
  const _Sugerencias({required this.alElegir});

  final void Function(String pregunta) alElegir;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Pregunta lo que quieras sobre las aves.', style: textos.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Si un ave está enferma, cuenta qué le ves y, si puedes, manda una foto.',
          style: textos.bodyLarge?.copyWith(color: Colores.tintaSuave),
        ),
        const SizedBox(height: 16),
        for (final p in preguntasSugeridas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: () => alElegir(p),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: Text(p, style: const TextStyle(fontSize: 17)),
            ),
          ),
      ],
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.mensaje});

  final MensajeChat mensaje;

  @override
  Widget build(BuildContext context) {
    final propio = mensaje.esUsuario;
    return Align(
      alignment: propio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: propio ? Colores.monte : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: propio ? null : Border.all(color: Colores.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mensaje.conFoto)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_outlined, size: 18, color: propio ? Colors.white : Colores.tinta),
                    const SizedBox(width: 6),
                    Text('Con foto', style: TextStyle(fontSize: 15, color: propio ? Colors.white : Colores.tinta)),
                  ],
                ),
              ),
            SelectableText(
              mensaje.texto,
              style: TextStyle(fontSize: 17, height: 1.35, color: propio ? Colors.white : Colores.tinta),
            ),
          ],
        ),
      ),
    );
  }
}
