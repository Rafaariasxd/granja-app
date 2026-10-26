import 'package:flutter/material.dart';

import 'tema.dart';

class Cascaron extends StatefulWidget {
  const Cascaron({
    super.key,
    required this.granja,
    required this.bodega,
    required this.sanidad,
    this.alAbrirBodega,
    this.alAbrirSanidad,
    this.administrar,
    this.alAbrirAdministrar,
  });

  final Widget granja;
  final Widget bodega;
  final Widget sanidad;
  final VoidCallback? alAbrirBodega;
  final VoidCallback? alAbrirSanidad;
  final Widget? administrar;
  final VoidCallback? alAbrirAdministrar;

  @override
  State<Cascaron> createState() => _CascaronState();
}

class _CascaronState extends State<Cascaron> {
  int _actual = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _actual,
        children: [widget.granja, widget.bodega, widget.sanidad, if (widget.administrar != null) widget.administrar!],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 72,
          backgroundColor: Colors.white,
          indicatorColor: Colores.bienFondo,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (estados) => TextStyle(
              fontSize: 15,
              fontWeight: estados.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
              color: estados.contains(WidgetState.selected) ? Colores.monte : Colores.tintaSuave,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (estados) => IconThemeData(
              size: 28,
              color: estados.contains(WidgetState.selected) ? Colores.monte : Colores.tintaSuave,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _actual,
          onDestinationSelected: (indice) {
            setState(() => _actual = indice);
            if (indice == 1) widget.alAbrirBodega?.call();
            if (indice == 2) widget.alAbrirSanidad?.call();
            if (indice == 3) widget.alAbrirAdministrar?.call();
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Granja',
            ),
            const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Bodega',
            ),
            const NavigationDestination(
              icon: Icon(Icons.health_and_safety_outlined),
              selectedIcon: Icon(Icons.health_and_safety),
              label: 'Sanidad',
            ),
            if (widget.administrar != null)
              const NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: 'Administrar',
              ),
          ],
        ),
      ),
    );
  }
}
