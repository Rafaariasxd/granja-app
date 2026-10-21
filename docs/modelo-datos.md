# Modelo de datos

Este es el modelo del MVP descrito en el documento de alcance. La fase 1 (galpones, lotes y registro diario) está implementada en `backend/`. El resto de las entidades se agrega en las siguientes fases, pero ya se tiene en cuenta para no rehacer tablas.

```mermaid
erDiagram
    LINEA_GENETICA ||--o{ CURVA_ESTANDAR : "tiene"
    LINEA_GENETICA ||--o{ LOTE : "raza de"
    GALPON ||--o{ LOTE : "aloja"
    LOTE ||--o{ REGISTRO_DIARIO : "produce"
    LOTE ||--o{ TAREA_SANITARIA : "fase 1.5"
    PLANTILLA_SANITARIA ||--o{ TAREA_SANITARIA : "genera"
    CLASIFICACION_DIARIA }o--|| GRANJA : "fase 1.5"
    MOVIMIENTO }o--o| LOTE : "fase 1.5"
    ITEM_BODEGA ||--o{ MOVIMIENTO_BODEGA : "fase 1.5"

    GALPON {
        int id
        string nombre
        int capacidad_aves
        bool activo
    }
    LINEA_GENETICA {
        int id
        string nombre "Hy-Line, Lohmann, ..."
    }
    CURVA_ESTANDAR {
        int linea_id
        int semana_edad
        float postura_pct
        float peso_g
    }
    LOTE {
        int id
        int galpon_id
        int linea_id
        date fecha_nacimiento
        int aves_iniciales
        date fecha_ingreso
        date fecha_salida "null si sigue activo"
    }
    REGISTRO_DIARIO {
        uuid id "lo genera el celular, para sincronizar sin duplicar"
        int lote_id
        date fecha
        int huevos_total "como en el tablero"
        int huevos_rotos
        int mortalidad
        float alimento_kg
    }
    CLASIFICACION_DIARIA {
        uuid id
        date fecha
        int b
        int a
        int aa
        int extra
        int jumbo
    }
    MOVIMIENTO {
        uuid id
        date fecha
        string tipo "ingreso o egreso"
        string categoria
        decimal monto_cop
        int lote_id "opcional"
    }
```

## Decisiones

- **El registro diario es por lote, no por galpón.** En el tablero se anota por galpón, y la app lo pregunta así. Por debajo se guarda en el lote activo de ese galpón, porque las métricas (postura, curva estándar, edad) dependen del lote.
- **Un galpón tiene como máximo un lote activo.** Un galpón sin lote activo está vacío. El día de salida todavía cuenta para el lote que sale, así que el siguiente lote entra como pronto al día siguiente. Un lote no se puede cerrar antes de su último registro.
- **Los registros usan UUID generado en el celular.** Si el celular reenvía el mismo registro al recuperar la conexión, el servidor lo actualiza en vez de duplicarlo.
- **Un solo registro por lote y día.** Si se corrige un dato, se edita el registro existente.
- **La clasificación (B, A, AA, Extra, Jumbo) es aparte y de toda la granja**, porque se hace al empacar y no por galpón.

## Métricas calculadas

| Métrica | Fórmula |
| --- | --- |
| Edad (semanas) | (fecha − fecha_nacimiento) / 7 |
| Etapa | cría < 6 semanas ≤ levante < 18 semanas ≤ producción |
| Aves vivas | aves_iniciales − mortalidad acumulada hasta la fecha |
| Postura % | huevos_total / aves vivas × 100 |
| Alerta de baja postura | postura por debajo de la curva estándar en más de 5 puntos durante 3 días seguidos |

Las semanas de corte de etapa y el umbral de la alerta son configurables, porque cambian según la línea y el criterio del veterinario.
