import getpass
import sys

from app.adaptadores.db.conexion import SessionLocal
from app.adaptadores.db.repositorios import UnidadDeTrabajoSql
from app.casos_uso import usuarios
from app.dominio.errores import ErrorDeDominio
from app.dominio.modelos import Rol

if __name__ == "__main__":
    nombre = input("Nombre del administrador: ").strip()
    pin = getpass.getpass("PIN de 6 dígitos: ")
    if getpass.getpass("Repite el PIN: ") != pin:
        sys.exit("Los PIN no coinciden.")
    with SessionLocal() as session:
        try:
            usuarios.crear_usuario(UnidadDeTrabajoSql(session), nombre, pin, Rol.ADMINISTRADOR)
        except ErrorDeDominio as error:
            sys.exit(str(error))
    print(f"Administrador {nombre} creado.")
