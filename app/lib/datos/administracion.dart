import 'dart:convert';

import '../dominio/administracion.dart';
import '../dominio/inventario.dart';
import '../dominio/modelos.dart';
import 'api_granja.dart';
import 'json_inventario.dart';

class Catalogo {
  const Catalogo({required this.inventario, required this.insumos, required this.galpones});

  final Inventario inventario;
  final List<Insumo> insumos;
  final List<GalponBasico> galpones;

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
    return Catalogo(inventario: inventario, insumos: insumos, galpones: galpones);
  }

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
