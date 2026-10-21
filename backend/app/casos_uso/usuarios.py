from datetime import datetime

from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import seguridad
from app.dominio.errores import Conflicto, NoAutenticado, NoEncontrado, SinPermiso
from app.dominio.modelos import Evento, Rol, Sesion, Usuario


def crear_usuario(uow: UnidadDeTrabajo, nombre: str, pin: str, rol: Rol) -> Usuario:
    seguridad.validar_pin(pin)
    if uow.usuarios.por_nombre(nombre):
        raise Conflicto(f"ya existe un usuario llamado {nombre}")
    usuario = uow.usuarios.agregar(Usuario(nombre=nombre, rol=rol, pin_hash=seguridad.hashear_pin(pin)))
    uow.confirmar()
    return usuario


def iniciar_sesion(uow: UnidadDeTrabajo, nombre: str, pin: str, ahora: datetime) -> tuple[str, Usuario]:
    usuario = uow.usuarios.por_nombre(nombre)
    try:
        seguridad.verificar_ingreso(usuario, pin, ahora)
    except Exception:
        if usuario is not None:
            uow.usuarios.actualizar(usuario)
            uow.confirmar()
        raise
    token = seguridad.nuevo_token()
    uow.usuarios.actualizar(usuario)
    uow.sesiones.agregar(Sesion(token_hash=seguridad.hash_de_token(token), usuario_id=usuario.id, creada_en=ahora))
    uow.confirmar()
    return token, usuario


def usuario_de_sesion(uow: UnidadDeTrabajo, token: str) -> Usuario:
    sesion = uow.sesiones.por_token_hash(seguridad.hash_de_token(token))
    if sesion is None or sesion.revocada:
        raise NoAutenticado("la sesión no es válida")
    usuario = uow.usuarios.obtener(sesion.usuario_id)
    if usuario is None or not usuario.activo:
        raise NoAutenticado("la sesión no es válida")
    return usuario


def cerrar_sesion(uow: UnidadDeTrabajo, token: str) -> None:
    sesion = uow.sesiones.por_token_hash(seguridad.hash_de_token(token))
    if sesion is not None:
        uow.sesiones.revocar(sesion.id)
        uow.confirmar()


def listar_usuarios(uow: UnidadDeTrabajo) -> list[Usuario]:
    return uow.usuarios.listar()


def desactivar_usuario(uow: UnidadDeTrabajo, quien: Usuario, usuario_id: int, ahora: datetime) -> Usuario:
    usuario = uow.usuarios.obtener(usuario_id)
    if usuario is None:
        raise NoEncontrado(f"el usuario {usuario_id} no existe")
    if usuario.id == quien.id:
        raise SinPermiso("no puedes desactivar tu propio usuario")
    usuario.activo = False
    uow.usuarios.actualizar(usuario)
    uow.sesiones.revocar_de_usuario(usuario.id)
    uow.bitacora.agregar(Evento("usuario_desactivado", usuario.nombre, quien.id, ahora))
    uow.confirmar()
    return usuario


def exigir_administrador(usuario: Usuario) -> None:
    if usuario.rol != Rol.ADMINISTRADOR:
        raise SinPermiso("solo el administrador puede hacer esto")
