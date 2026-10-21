# Alcance del MVP

La app reemplaza el cuaderno y el tablero donde hoy se anota todo en la granja. Cualquiera de la familia ve en el celular qué hay en la finca, cuánto se produjo, qué toca hacer esta semana y si un galpón va mal.

## Usuarios

| Usuario | Qué hace |
| --- | --- |
| Registrador (papás) | Registra la producción del día y ve el resumen. Uno usa Android y el otro iPhone. |
| Administrador | Configura galpones, lotes, curvas estándar y usuarios. |

Registrar un día de producción debe tomar menos de un minuto y funcionar sin señal: la granja tiene internet por Starlink y en los galpones no siempre hay conexión. Los datos se sincronizan cuando vuelve. Letra grande y pocos toques.

## La granja

- 7 galpones, de 2.000 a 6.000 aves de capacidad cada uno. La capacidad total pasa de 15.000 aves y hoy hay unas 5.000, así que varios galpones pueden estar vacíos.
- Líneas genéticas: Hy-Line, Lohmann y una tercera por confirmar. Cada casa genética publica su curva estándar de postura y peso; la app la carga por línea y se puede editar.
- El tablero anota el total de huevos del día por galpón, sin separar por tamaño.
- La clasificación del huevo (B, A, AA, Extra, Jumbo) se hace aparte, al empacar o vender, para toda la granja.

## Módulos, en orden de construcción

1. **Inventario.** Galpones (nombre, capacidad), lotes de aves (línea, fecha de nacimiento, aves iniciales, galpón, fechas de ingreso y salida), bodega (alimento, vacunas, medicamentos, empaques) y equipos. Cada lote tiene una etapa según su edad: cría (menos de 6 semanas), levante (menos de 18) y producción.
2. **Producción diaria.** Por galpón y día: huevos totales, huevos rotos, mortalidad y alimento en kg. La app calcula postura %, aves vivas, ocupación y conversión de alimento.
3. **Levante y plan sanitario.** Al crear un lote de pollitas se genera su calendario por semana de edad: vacunas, pesajes, cambio de alimento, inicio de iluminación y semana esperada de inicio de postura. El plan de vacunas es una plantilla editable.
4. **Finanzas.** Ingresos (venta de huevo por categoría, gallina de descarte) y egresos (alimento, pollitas, vacunas, nómina, servicios), con costo por lote y utilidad por mes.
5. **Alertas y tablero.** Resumen diario, pendientes de la semana y avisos cuando la postura cae más de 5 puntos bajo la curva estándar de su línea durante 3 días seguidos, cuando la mortalidad o el alimento se salen de rango, o cuando hay vacunas vencidas o bodega baja.

## Fuera del MVP

- Facturación electrónica, nómina formal y venta a clientes externos.
- Sensores en los galpones (temperatura, humedad, amoníaco, agua y cortes de luz). El modelo de datos los tiene en cuenta, pero entran en una fase posterior.
- El café (algo más de 1 hectárea), también en una fase posterior.

## Stack

- Backend en Python con FastAPI, SQLAlchemy y Pydantic. SQLite para desarrollo y PostgreSQL en el servidor.
- App móvil en Flutter, una sola base de código para Android e iOS, con base de datos local SQLite y una cola de cambios (id único y marca de tiempo) que se sincroniza con el servidor.
