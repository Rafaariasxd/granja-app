import 'package:flutter/material.dart';

import 'tema.dart';

class Cascaron extends StatefulWidget {
  const Cascaron({
    super.key,
    required this.granja,
    required this.bodega,
    required this.sanidad,
    required this.dinero,
    this.alAbrirBodega,
    this.alAbrirSanidad,
    this.alAbrirDinero,
    this.administrar,
    this.alAbrirAdministrar,
    this.pestana,
  });

  final Widget granja;
  final Widget bodega;
  final Widget sanidad;
  final Widget dinero;
  final VoidCallback? alAbrirBodega;
  final VoidCallback? alAbrirSanidad;
  final VoidCallback? alAbrirDinero;
  final Widget? administrar;
  final VoidCallback? alAbrirAdministrar;
  final ValueNotifier<int>? pestana;

  @override
  State<Cascaron> createState() => _CascaronState();
}

class _CascaronState extends State<Cascaron> {
  int _actual = 0;

  @override
  void initState() {
    super.initState();
    widget.pestana?.addListener(_seguirPestana);
  }

  @override
  void dispose() {
    widget.pestana?.removeListener(_seguirPestana);
    super.dispose();
  }

  void _seguirPestana() {
    final indice = widget.pestana!.value;
    if (indice != _actual) _ir(indice);
  }

  void _ir(int indice) {
    final ultimo = widget.administrar == null ? 3 : 4;
    if (indice < 0 || indice > ultimo) return;
    setState(() => _actual = indice);
    widget.pestana?.value = indice;
    if (indice == 1) widget.alAbrirBodega?.call();
    if (indice == 2) widget.alAbrirSanidad?.call();
    if (indice == 3) widget.alAbrirDinero?.call();
    if (indice == 4) widget.alAbrirAdministrar?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _actual,
        children: [
          widget.granja,
          widget.bodega,
          widget.sanidad,
          widget.dinero,
          if (widget.administrar != null) widget.administrar!,
        ],
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
          onDestinationSelected: _ir,
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
            const NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'Dinero',
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
