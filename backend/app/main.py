from fastapi import FastAPI

from app.adaptadores.api import errores, rutas

app = FastAPI(title="Granja App", version="0.1.0")
errores.registrar(app)
app.include_router(rutas.router)
app.include_router(rutas.protegido)


@app.get("/salud")
def salud() -> dict[str, str]:
    return {"estado": "ok"}
