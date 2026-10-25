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
