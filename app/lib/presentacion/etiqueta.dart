import 'package:flutter/material.dart';

class Etiqueta extends StatelessWidget {
  const Etiqueta({super.key, required this.texto, required this.icono, required this.fondo, required this.color});

  final String texto;
  final IconData icono;
  final Color fondo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
