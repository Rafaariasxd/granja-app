from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.adaptadores.api import errores, rutas
from app.adaptadores.db.conexion import engine
from app.adaptadores.db.tablas import crear_tablas


@asynccontextmanager
async def lifespan(_: FastAPI):
    crear_tablas(engine)
    yield


app = FastAPI(title="Granja App", version="0.1.0", lifespan=lifespan)
errores.registrar(app)
app.include_router(rutas.router)


@app.get("/salud")
def salud() -> dict[str, str]:
    return {"estado": "ok"}
