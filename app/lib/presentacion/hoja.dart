import 'package:flutter/material.dart';

import 'tema.dart';

Future<T?> abrirHoja<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color? backgroundColor,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  useSafeArea: true,
  backgroundColor: backgroundColor ?? Colores.cal,
  builder: (contexto) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.of(contexto).pop(),
            icon: const Icon(Icons.arrow_back, size: 26),
            label: const Text('Volver'),
            style: TextButton.styleFrom(
              foregroundColor: Colores.monte,
              minimumSize: const Size(0, 52),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
      Flexible(child: builder(contexto)),
    ],
  ),
);
