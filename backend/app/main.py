from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.db import Base, engine
from app.routers import granja


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Mientras no haya migraciones con Alembic, las tablas se crean al arrancar.
    Base.metadata.create_all(engine)
    yield


app = FastAPI(title="Granja App", version="0.1.0", lifespan=lifespan)
app.include_router(granja.router)


@app.get("/salud")
def salud() -> dict[str, str]:
    return {"estado": "ok"}
