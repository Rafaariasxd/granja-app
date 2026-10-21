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
uvicorn app.main:app --reload     # documentación de la API en http://localhost:8000/docs
pytest                            # pruebas
ruff check . && ruff format .     # lint y formato
```

Por defecto usa SQLite (`granja.db`). Para PostgreSQL, define `DATABASE_URL`, por ejemplo `postgresql+psycopg://usuario:clave@localhost/granja`. Alembic usa la misma variable.

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
