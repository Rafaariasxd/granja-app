from datetime import datetime, timedelta

import pytest

from app.dominio import seguridad
from app.dominio.errores import Bloqueado, DatosInvalidos, NoAutenticado
from app.dominio.modelos import Rol, Usuario

AHORA = datetime(2026, 10, 21, 12, 0)


def _usuario(pin="483920", **campos):
    return Usuario(id=1, nombre="Mamá", rol=Rol.REGISTRADOR, pin_hash=seguridad.hashear_pin(pin), **campos)


@pytest.mark.parametrize("pin", ["12345", "1234567", "abcdef", "48392a", "", "111111", "123456", "654321"])
def test_pines_no_aceptados(pin):
    with pytest.raises(DatosInvalidos):
        seguridad.validar_pin(pin)


def test_pin_valido():
    seguridad.validar_pin("483920")


def test_el_pin_no_se_guarda_en_claro_y_cada_hash_es_distinto():
    a, b = seguridad.hashear_pin("483920"), seguridad.hashear_pin("483920")
    assert "483920" not in a
    assert a != b
    assert seguridad.pin_correcto("483920", a) and seguridad.pin_correcto("483920", b)
    assert not seguridad.pin_correcto("483921", a)


def test_un_hash_dañado_no_deja_entrar():
    assert not seguridad.pin_correcto("483920", "basura")


def test_los_tokens_son_largos_y_distintos():
    a, b = seguridad.nuevo_token(), seguridad.nuevo_token()
    assert a != b and len(a) >= 40
    assert seguridad.hash_de_token(a) != a


def test_ingreso_correcto_reinicia_los_intentos():
    usuario = _usuario(intentos_fallidos=3)
    seguridad.verificar_ingreso(usuario, "483920", AHORA)
    assert usuario.intentos_fallidos == 0


def test_pin_incorrecto_cuenta_el_intento():
    usuario = _usuario()
    with pytest.raises(NoAutenticado):
        seguridad.verificar_ingreso(usuario, "000001", AHORA)
    assert usuario.intentos_fallidos == 1


def test_el_quinto_fallo_bloquea_y_el_pin_correcto_ya_no_entra():
    usuario = _usuario()
    for _ in range(seguridad.MAX_INTENTOS):
        with pytest.raises(NoAutenticado):
            seguridad.verificar_ingreso(usuario, "000001", AHORA)
    assert usuario.bloqueado_hasta == AHORA + seguridad.BLOQUEO
    with pytest.raises(Bloqueado):
        seguridad.verificar_ingreso(usuario, "483920", AHORA + timedelta(minutes=5))


def test_pasado_el_bloqueo_se_puede_entrar():
    usuario = _usuario(bloqueado_hasta=AHORA)
    seguridad.verificar_ingreso(usuario, "483920", AHORA + timedelta(minutes=1))


def test_usuario_inexistente_o_desactivado_da_el_mismo_error():
    with pytest.raises(NoAutenticado, match="nombre o PIN incorrectos"):
        seguridad.verificar_ingreso(None, "483920", AHORA)
    with pytest.raises(NoAutenticado, match="nombre o PIN incorrectos"):
        seguridad.verificar_ingreso(_usuario(activo=False), "483920", AHORA)
