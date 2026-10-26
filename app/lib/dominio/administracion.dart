import 'sanidad.dart';

class GalponBasico {
  const GalponBasico({required this.id, required this.nombre});

  final int id;
  final String nombre;
}

class IngredienteFormula {
  const IngredienteFormula({required this.insumoId, required this.porcentaje});

  final int insumoId;
  final double porcentaje;
}

const _tolerancia = 0.01;

double sumaDeFormula(Iterable<double> porcentajes) => porcentajes.fold(0.0, (suma, p) => suma + p);

bool formulaCompleta(Iterable<double> porcentajes) => (sumaDeFormula(porcentajes) - 100).abs() <= _tolerancia;

double? leerNumero(String texto) {
  final limpio = texto.trim().replaceAll(',', '.');
  if (limpio.isEmpty) return null;
  final numero = double.tryParse(limpio);
  return numero != null && numero.isFinite ? numero : null;
}

class Raza {
  const Raza({required this.id, required this.nombre, required this.revisada});

  final int id;
  final String nombre;
  final bool revisada;
}

class TareaDePlan {
  const TareaDePlan({
    required this.nombre,
    required this.tipo,
    required this.semanaIdeal,
    required this.semanaMax,
    this.id,
    this.nota = '',
  });

  final int? id;
  final String nombre;
  final TipoTarea tipo;
  final int semanaIdeal;
  final int semanaMax;
  final String nota;

  String get cuando => semanaIdeal == semanaMax
      ? (semanaIdeal == 0 ? 'Al nacer' : 'Semana $semanaIdeal')
      : 'Semana $semanaIdeal a $semanaMax';
}

class PuntoDeCurva {
  const PuntoDeCurva({required this.semana, required this.posturaPct, this.pesoG});

  final int semana;
  final double posturaPct;
  final double? pesoG;
}

class CurvaLeida {
  const CurvaLeida.valida(this.puntos) : error = null;
  const CurvaLeida.invalida(this.error) : puntos = const [];

  final List<PuntoDeCurva> puntos;
  final String? error;

  bool get esValida => error == null;
}

String _numeroLimpio(double valor) {
  final texto = valor.toString();
  return texto.endsWith('.0') ? texto.substring(0, texto.length - 2) : texto;
}

String curvaComoTexto(List<PuntoDeCurva> puntos) => [
  for (final p in puntos)
    '${p.semana} ${_numeroLimpio(p.posturaPct)}${p.pesoG == null ? '' : ' ${_numeroLimpio(p.pesoG!)}'}',
].join('\n');

CurvaLeida leerCurva(String texto) {
  final puntos = <PuntoDeCurva>[];
  final vistas = <int>{};
  final lineas = texto.split('\n');
  for (var i = 0; i < lineas.length; i++) {
    final linea = lineas[i].trim();
    if (linea.isEmpty) continue;
    final partes = linea.split(RegExp(r'[\s;]+'));
    final semana = int.tryParse(partes[0]);
    final postura = partes.length > 1 ? leerNumero(partes[1]) : null;
    final peso = partes.length > 2 ? leerNumero(partes[2]) : null;
    if (partes.length > 3 || semana == null || semana < 0 || postura == null) {
      return CurvaLeida.invalida('Línea ${i + 1}: escribe semana, postura y, si la tienes, peso. Ejemplo: 30 95 1890');
    }
    if (postura < 0 || postura > 100) {
      return CurvaLeida.invalida('Línea ${i + 1}: la postura va de 0 a 100.');
    }
    if (partes.length > 2 && (peso == null || peso <= 0)) {
      return CurvaLeida.invalida('Línea ${i + 1}: el peso debe ser mayor que cero.');
    }
    if (!vistas.add(semana)) {
      return CurvaLeida.invalida('Línea ${i + 1}: la semana $semana está repetida.');
    }
    puntos.add(PuntoDeCurva(semana: semana, posturaPct: postura, pesoG: peso));
  }
  puntos.sort((a, b) => a.semana.compareTo(b.semana));
  return CurvaLeida.valida(puntos);
}
