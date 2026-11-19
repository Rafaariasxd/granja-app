class VariableIot {
  const VariableIot({required this.nombre, required this.unidad, required this.minimo, required this.maximo});

  final String nombre;
  final String unidad;
  final double minimo;
  final double maximo;

  bool get esSiNo => unidad == '1/0';
}

class LecturaIot {
  const LecturaIot({required this.valor, required this.momento});

  final double valor;
  final DateTime momento;
}

class DispositivoIot {
  const DispositivoIot({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.protocolo,
    required this.ubicacion,
    required this.descripcion,
    required this.enLinea,
    required this.ultimoContacto,
    required this.variables,
    required this.ultimos,
    required this.acciones,
    required this.estado,
  });

  final String id;
  final String nombre;
  final String categoria;
  final String protocolo;
  final String ubicacion;
  final String descripcion;
  final bool enLinea;
  final DateTime? ultimoContacto;
  final List<VariableIot> variables;
  final Map<String, LecturaIot> ultimos;
  final List<String> acciones;
  final Map<String, Object?> estado;

  bool get encendido => estado['encendido'] != false;
  int get intervalo => (estado['intervalo_s'] as num?)?.toInt() ?? 60;
  double? valor(String variable) => ultimos[variable]?.valor;
  bool permite(String accion) => acciones.contains(accion);
}

class AlertaIot {
  const AlertaIot({
    required this.dispositivo,
    required this.variable,
    required this.nivel,
    required this.mensaje,
    required this.valorExtremo,
    required this.inicio,
    this.fin,
  });

  final String dispositivo;
  final String variable;
  final String nivel;
  final String mensaje;
  final double valorExtremo;
  final DateTime inicio;
  final DateTime? fin;

  bool get critica => nivel == 'crítica';
}

class PuntoSerie {
  const PuntoSerie({required this.momento, required this.promedio, required this.minimo, required this.maximo});

  final DateTime momento;
  final double promedio;
  final double minimo;
  final double maximo;
}

class SerieIot {
  const SerieIot({required this.unidad, required this.puntos, this.promedio, this.minimo, this.maximo});

  final String unidad;
  final List<PuntoSerie> puntos;
  final double? promedio;
  final double? minimo;
  final double? maximo;
}

class ComandoIot {
  const ComandoIot({required this.accion, this.parametros = const {}});

  final String accion;
  final Map<String, Object?> parametros;
}

class GrupoIot {
  const GrupoIot(this.titulo, this.dispositivos);

  final String titulo;
  final List<DispositivoIot> dispositivos;
}

const _gruposIot = [
  ('Galpón 1', ['galpon1-ambiente', 'galpon1-gases', 'galpon1-ventilacion', 'galpon1-iluminacion']),
  ('Agua, alimento y energía', ['tanque-agua', 'silo-alimento', 'tablero-energia']),
  ('Producción', ['contador-huevos']),
  ('Clima', ['clima-openmeteo', 'clima-azure-maps', 'historico-era5']),
  ('Equipos de la finca', ['galpon2-ambiente', 'pasarela-finca']),
];

List<GrupoIot> agruparDispositivos(List<DispositivoIot> dispositivos) {
  final porId = {for (final d in dispositivos) d.id: d};
  final usados = <String>{};
  final grupos = <GrupoIot>[];
  for (final (titulo, ids) in _gruposIot) {
    final lista = [for (final id in ids) ?porId[id]];
    usados.addAll(lista.map((d) => d.id));
    if (lista.isNotEmpty) grupos.add(GrupoIot(titulo, lista));
  }
  final otros = dispositivos.where((d) => !usados.contains(d.id)).toList();
  if (otros.isNotEmpty) grupos.add(GrupoIot('Otros', otros));
  return grupos;
}

const _nombresVariables = {
  'temperatura': 'Temperatura',
  'humedad': 'Humedad',
  'indice_thi': 'Estrés por calor (THI)',
  'amoniaco': 'Amoníaco',
  'co2': 'CO₂',
  'velocidad': 'Velocidad',
  'modo_auto': 'Automático',
  'potencia': 'Potencia',
  'luz': 'Luz',
  'luces': 'Luces encendidas',
  'horas_luz': 'Horas de luz',
  'nivel': 'Nivel',
  'caudal': 'Caudal',
  'bomba': 'Bomba encendida',
  'consumo_dia': 'Consumo de hoy',
  'voltaje': 'Voltaje',
  'corriente': 'Corriente',
  'red': 'Hay luz',
  'huevos_hora': 'Huevos por hora',
  'huevos_dia': 'Huevos de hoy',
  'postura': 'Postura',
  'peso_promedio': 'Peso promedio',
  'rotos_dia': 'Rotos hoy',
  'consumo_hora': 'Consumo por hora',
  'bultos': 'Bultos',
  'lluvia': 'Lluvia',
  'viento': 'Viento',
  'radiacion': 'Radiación solar',
  'nubosidad': 'Nubosidad',
  'sensacion': 'Sensación térmica',
  'punto_rocio': 'Punto de rocío',
  'indice_uv': 'Índice UV',
  'latencia': 'Latencia a la nube',
  'cpu': 'CPU',
  'memoria': 'Memoria',
  'encendido_horas': 'Encendido hace',
};

String nombreVariable(String variable) {
  final conocido = _nombresVariables[variable];
  if (conocido != null) return conocido;
  final texto = variable.replaceAll('_', ' ');
  return texto.isEmpty ? texto : '${texto[0].toUpperCase()}${texto.substring(1)}';
}

String numeroCorto(double valor) {
  final absoluto = valor.abs();
  final decimales = absoluto >= 100 ? 0 : (absoluto >= 10 ? 1 : 2);
  var texto = valor.toStringAsFixed(decimales);
  if (texto.contains('.')) texto = texto.replaceFirst(RegExp(r'\.?0+$'), '');
  final partes = texto.split('.');
  final entero = partes[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
  return partes.length > 1 ? '$entero,${partes[1]}' : entero;
}

String valorConUnidad(double? valor, VariableIot variable) {
  if (valor == null) return '—';
  if (variable.esSiNo) return valor >= 0.5 ? 'Sí' : 'No';
  final unidad = variable.unidad.isEmpty ? '' : ' ${variable.unidad}';
  return '${numeroCorto(valor)}$unidad';
}

String haceCuanto(DateTime? momento, DateTime ahora) {
  if (momento == null) return 'nunca';
  final segundos = ahora.difference(momento).inSeconds;
  if (segundos < 90) return 'hace un momento';
  if (segundos < 5400) return 'hace ${(segundos / 60).round()} min';
  if (segundos < 172800) return 'hace ${(segundos / 3600).round()} h';
  return 'hace ${(segundos / 86400).round()} días';
}
