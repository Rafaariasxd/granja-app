# Granja App

App para llevar la granja avícola de la familia: galpones, lotes, producción diaria, plan sanitario, finanzas y alertas. Después se le conectan sensores (IoT) en los galpones.

El alcance está en [docs/alcance.md](docs/alcance.md), el modelo de datos en [docs/modelo-datos.md](docs/modelo-datos.md) y la arquitectura en [docs/arquitectura.md](docs/arquitectura.md).

## Estructura

| Carpeta | Qué tiene |
| --- | --- |
| `backend/` | API en Python con FastAPI y SQLAlchemy, con arquitectura hexagonal |
| `app/` | App móvil en Flutter para Android e iOS (pendiente) |
| `docs/` | Alcance, modelo de datos, arquitectura y decisiones |

## Correr el backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate         # en Windows: .venv\Scripts\activate
pip install -e ".[dev]"
alembic upgrade head              # crea o actualiza las tablas
python -m app.crear_admin         # crea el primer usuario administrador (pide nombre y PIN)
python -m app.datos_ejemplo       # opcional: 7 galpones, 3 lotes y una semana de registros de ejemplo
uvicorn app.main:app --reload     # documentación de la API en http://localhost:8000/docs
pytest                            # pruebas
ruff check . && ruff format .     # lint y formato
```

Por defecto usa SQLite (`granja.db`). Para PostgreSQL, define `DATABASE_URL`, por ejemplo `postgresql+psycopg://usuario:clave@localhost/granja` (también acepta `postgresql://` y `postgres://`). Alembic usa la misma variable. Para correr las pruebas contra PostgreSQL, define `PRUEBAS_DATABASE_URL` con una base vacía de pruebas: borra y recrea las tablas en cada prueba.

Para tener la API en un servidor con PostgreSQL y HTTPS: [docs/despliegue.md](docs/despliegue.md).

### Usuarios y seguridad

- Se entra con nombre y PIN de 6 dígitos (`POST /sesion`) y se usa el token recibido como `Authorization: Bearer <token>`. Solo `/salud` y `POST /sesion` son públicos.
- El PIN se guarda con scrypt y sal, nunca en claro. El token se guarda solo como hash SHA-256. Tras 5 PIN incorrectos el usuario se bloquea 15 minutos.
- Roles: `administrador` (crea galpones, líneas, lotes, usuarios y borra registros) y `registrador` (registra y ve).
- Borrar un registro (`DELETE /registros/{id}`) y desactivar un usuario quedan en la tabla `bitacora` con quién y cuándo.
- Los datos viajan por internet: en el servidor solo se debe exponer por HTTPS.

### Inventario de alimento y materias primas

- Hay bodegas con nombre y tipo: de alimento (varias, cada una con sus propios galpones y sus propios días) y de materia prima. Un galpón come de una sola bodega de alimento. Preparar alimento saca de una bodega de materia prima y lo deja en la bodega de alimento que se elija.
- Hay tres tipos de insumo: materia prima (maíz, soya, calcio, palmiste, vitaminas...), alimento comprado (Bioconcentrados, Italcol, para pollita, levante o ponedora) y alimento preparado en la finca.
- Lo que hay en cada bodega no se guarda como un número suelto: es la suma de movimientos (compra, uso en mezcla, preparación, consumo de los registros del día y ajustes de conteo). Así queda quién hizo cada cambio.
- Las compras se dan en bultos, también medios (`{"bultos": 0.5}`), o en kilos. Cada insumo sabe cuántos kilos trae su bulto.
- El alimento preparado tiene una fórmula en porcentajes que suman 100. Preparar `N` kg gasta las materias primas y suma el alimento; si falta alguna, no se prepara y se dice cuál.
- Por cada bodega de alimento y etapa (pollita, levante, ponedora) el administrador define el alimento en uso. El registro del día resta, de la bodega de su galpón, ese alimento los kilos que se comieron, sin repetir el descuento si el celular reenvía el registro, y lo devuelve si el registro se borra.
- `GET /inventario` calcula los días que alcanza cada cosa con el promedio de consumo de los últimos 7 días con registro, la mezcla que se puede preparar y qué materia prima se acaba primero.
- Niveles: crítico hasta 2 días, poco hasta 5, bien después.
- Las fórmulas del ejemplo (`python -m app.datos_ejemplo`, si ya existe un administrador) son de muestra, no las reales.

### Cambiar las tablas

1. Edita `backend/app/adaptadores/db/tablas.py`.
2. Genera la migración: `alembic revision --autogenerate -m "qué cambió"`.
3. Revisa el archivo nuevo en `backend/migraciones/versions/`: Alembic no detecta todo solo (por ejemplo, restricciones CHECK nuevas en tablas que ya existen).
4. Aplica con `alembic upgrade head`. Las pruebas verifican que las migraciones dejan el mismo esquema que los modelos.

## Forma de trabajo

- `main` siempre funciona. Cada cambio va en una rama y entra por pull request con revisión.
- El CI corre lint, formato y pruebas en cada pull request.
- Las reglas y cálculos del negocio (postura, etapa, lotes, alertas) van en `backend/app/dominio/` como funciones puras con sus pruebas. El dominio no importa FastAPI ni SQLAlchemy.

## Fases

1. Inventario de galpones y lotes, y producción diaria. **(en curso)**
2. Levante, plan sanitario, finanzas, clasificación del huevo y alertas.
3. Sensores en los galpones.
4. Módulo de café.
