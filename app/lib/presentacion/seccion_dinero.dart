import 'package:flutter/material.dart';

import 'tema.dart';

class SeccionDinero extends StatelessWidget {
  const SeccionDinero({super.key, required this.huevo, required this.cuentas, this.alCambiar});

  final Widget huevo;
  final Widget cuentas;
  final ValueChanged<int>? alCambiar;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Material(
                color: Colores.cal,
                child: TabBar(
                  onTap: alCambiar,
                  labelColor: Colores.monte,
                  unselectedLabelColor: Colores.tintaSuave,
                  indicatorColor: Colores.monte,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  unselectedLabelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(height: 56, text: 'Huevo'),
                    Tab(height: 56, text: 'Cuentas'),
                  ],
                ),
              ),
              Expanded(child: TabBarView(children: [huevo, cuentas])),
            ],
          ),
        ),
      ),
    );
  }
}
