import 'dart:convert';

import '../dominio/administracion.dart';
import '../dominio/inventario.dart';
import '../dominio/modelos.dart';
import '../dominio/sanidad.dart';
import 'api_granja.dart';
import 'json_inventario.dart';

class Catalogo {
  const Catalogo({
    required this.inventario,
    required this.insumos,
    required this.galpones,
    this.razas = const [],
    this.plantillas = const [],
  });

  final Inventario inventario;
  final List<Insumo> insumos;
  final List<GalponBasico> galpones;
  final List<Raza> razas;
  final List<String> plantillas;

  Iterable<Insumo> get materiasPrimas => insumos.where((i) => i.tipo == TipoInsumo.materiaPrima);

  Iterable<Insumo> get preparados => insumos.where((i) => i.tipo == TipoInsumo.alimentoPreparado);

  Iterable<Insumo> alimentosDe(Etapa etapa) =>
      insumos.where((i) => i.tipo != TipoInsumo.materiaPrima && i.etapa == etapa);
}

class RepositorioAdministracion {
  RepositorioAdministracion(this._api);

  final ApiGranja _api;

  Future<Catalogo> catalogo() async {
    final inventario = inventarioDesdeJson(jsonDecode(await _api.inventarioJson()) as Map<String, dynamic>);
    final insumos = [
      for (final i in jsonDecode(await _api.insumosJson()) as List<dynamic>) insumoDesdeJson(i as Map<String, dynamic>),
    ];
    final galpones = [
      for (final g in jsonDecode(await _api.galponesJson()) as List<dynamic>)
        GalponBasico(id: (g as Map<String, dynamic>)['id'] as int, nombre: g['nombre'] as String),
    ];
    final razas = [
      for (final r in jsonDecode(await _api.lineasJson()) as List<dynamic>)
        Raza(
          id: (r as Map<String, dynamic>)['id'] as int,
          nombre: r['nombre'] as String,
          revisada: r['revisada'] as bool? ?? false,
        ),
    ];
    final plantillas = [for (final p in jsonDecode(await _api.plantillasDeLineasJson()) as List<dynamic>) p as String];
    return Catalogo(inventario: inventario, insumos: insumos, galpones: galpones, razas: razas, plantillas: plantillas);
  }

  Future<List<TareaDePlan>> plan(int razaId) async {
    final datos = jsonDecode(await _api.planDeLineaJson(razaId)) as List<dynamic>;
    return [
      for (final d in datos)
        TareaDePlan(
          id: (d as Map<String, dynamic>)['id'] as int,
          nombre: d['nombre'] as String,
          tipo: TipoTarea.values.byName(d['tipo'] as String),
          semanaIdeal: d['semana_ideal'] as int,
          semanaMax: d['semana_max'] as int,
          nota: d['nota'] as String? ?? '',
        ),
    ];
  }

  Future<List<PuntoDeCurva>> curva(int razaId) async {
    final datos = jsonDecode(await _api.curvaDeLineaJson(razaId)) as List<dynamic>;
    return [
      for (final d in datos)
        PuntoDeCurva(
          semana: (d as Map<String, dynamic>)['semana'] as int,
          posturaPct: (d['postura_pct'] as num).toDouble(),
          pesoG: (d['peso_g'] as num?)?.toDouble(),
        ),
    ];
  }

  Future<void> crearRaza(String nombre, String? plantilla) => _api.crearLinea(nombre, plantilla);

  Future<void> renombrarRaza(int razaId, String nombre) => _api.renombrarLinea(razaId, nombre);

  Future<void> guardarPlan(int razaId, List<TareaDePlan> tareas) => _api.definirPlanDeLinea(razaId, [
    for (final t in tareas)
      {
        'id': t.id,
        'nombre': t.nombre,
        'tipo': t.tipo.name,
        'semana_ideal': t.semanaIdeal,
        'semana_max': t.semanaMax,
        'nota': t.nota,
      },
  ]);

  Future<void> guardarCurva(int razaId, List<PuntoDeCurva> puntos) => _api.definirCurvaDeLinea(razaId, [
    for (final p in puntos) {'semana': p.semana, 'postura_pct': p.posturaPct, 'peso_g': p.pesoG},
  ]);

  Future<List<IngredienteFormula>> formula(int productoId) async {
    final datos = jsonDecode(await _api.formulaJson(productoId)) as List<dynamic>;
    return [
      for (final d in datos)
        IngredienteFormula(
          insumoId: (d as Map<String, dynamic>)['insumo_id'] as int,
          porcentaje: (d['porcentaje'] as num).toDouble(),
        ),
    ];
  }

  Future<void> crearBodega(String nombre, TipoBodega tipo) =>
      _api.crearBodega(nombre, tipo == TipoBodega.materiaPrima ? 'materia_prima' : 'alimento');

  Future<void> asignarGalpones(int bodegaId, List<int> galponIds) => _api.asignarGalpones(bodegaId, galponIds);

  Future<void> crearInsumo({required String nombre, required TipoInsumo tipo, Etapa? etapa, double? kgPorBulto}) =>
      _api.crearInsumo({
        'nombre': nombre,
        'tipo': switch (tipo) {
          TipoInsumo.materiaPrima => 'materia_prima',
          TipoInsumo.alimentoComprado => 'alimento_comprado',
          TipoInsumo.alimentoPreparado => 'alimento_preparado',
        },
        'etapa': etapa?.name,
        'kg_por_bulto': kgPorBulto,
      });

  Future<void> definirFormula(int productoId, List<IngredienteFormula> ingredientes) =>
      _api.definirFormula(productoId, [
        for (final i in ingredientes) {'insumo_id': i.insumoId, 'porcentaje': i.porcentaje},
      ]);

  Future<void> ponerEnUso(int bodegaId, Etapa etapa, int insumoId) =>
      _api.definirAlimentoEnUso(bodegaId, etapa.name, insumoId);
}
