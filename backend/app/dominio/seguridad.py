import hashlib
import hmac
import re
import secrets
from datetime import datetime, timedelta

from app.dominio.errores import Bloqueado, DatosInvalidos, NoAutenticado
from app.dominio.modelos import Usuario

MAX_INTENTOS = 5
BLOQUEO = timedelta(minutes=15)
_PIN = re.compile(r"^\d{6}$")
_SCRYPT = {"n": 2**14, "r": 8, "p": 1}


def validar_pin(pin: str) -> None:
    if not _PIN.fullmatch(pin):
        raise DatosInvalidos("el PIN debe tener exactamente 6 dígitos")
    if len(set(pin)) == 1 or pin in {"123456", "654321"}:
        raise DatosInvalidos("el PIN es demasiado fácil de adivinar")


def hashear_pin(pin: str) -> str:
    sal = secrets.token_bytes(16)
    resumen = hashlib.scrypt(pin.encode(), salt=sal, **_SCRYPT)
    return f"scrypt${sal.hex()}${resumen.hex()}"


def pin_correcto(pin: str, almacenado: str) -> bool:
    try:
        _, sal, resumen = almacenado.split("$")
        calculado = hashlib.scrypt(pin.encode(), salt=bytes.fromhex(sal), **_SCRYPT)
    except ValueError:
        return False
    return hmac.compare_digest(calculado, bytes.fromhex(resumen))


def nuevo_token() -> str:
    return secrets.token_urlsafe(32)


def hash_de_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def verificar_ingreso(usuario: Usuario | None, pin: str, ahora: datetime) -> None:
    """Cambia los intentos fallidos del usuario; quien llama debe guardarlo."""
    if usuario is None or not usuario.activo:
        pin_correcto(pin, "scrypt$00$00")
        raise NoAutenticado("nombre o PIN incorrectos")
    if usuario.bloqueado_hasta is not None and usuario.bloqueado_hasta > ahora:
        raise Bloqueado("demasiados intentos: espera unos minutos")
    if pin_correcto(pin, usuario.pin_hash):
        usuario.intentos_fallidos = 0
        usuario.bloqueado_hasta = None
        return
    usuario.intentos_fallidos += 1
    if usuario.intentos_fallidos >= MAX_INTENTOS:
        usuario.bloqueado_hasta = ahora + BLOQUEO
        usuario.intentos_fallidos = 0
    raise NoAutenticado("nombre o PIN incorrectos")
