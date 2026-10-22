import 'modelos.dart';

class ResumenDelDia {
  ResumenDelDia(List<ResumenGalpon> galpones)
    : conLote = galpones.where((g) => !g.vacio).toList(),
      vacios = galpones.where((g) => g.vacio).toList();

  final List<ResumenGalpon> conLote;
  final List<ResumenGalpon> vacios;

  int get huevos => conLote.fold(0, (suma, g) => suma + (g.huevosDelDia ?? 0));

  int get avesVivas => conLote.fold(0, (suma, g) => suma + g.avesVivas);

  List<ResumenGalpon> get faltan => conLote.where((g) => !g.registradoHoy).toList();

  bool get todoRegistrado => conLote.isNotEmpty && faltan.isEmpty;
}
