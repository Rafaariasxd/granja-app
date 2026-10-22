import 'package:flutter/widgets.dart';

class AlReanudar extends StatefulWidget {
  const AlReanudar({super.key, required this.alVolver, required this.child});

  final VoidCallback alVolver;
  final Widget child;

  @override
  State<AlReanudar> createState() => _AlReanudarState();
}

class _AlReanudarState extends State<AlReanudar> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) widget.alVolver();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
