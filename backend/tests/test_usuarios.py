import uuid
from datetime import date, datetime

import pytest

from app.casos_uso import galpones, lineas, lotes, registros, usuarios
from app.dominio.errores import Conflicto, DatosInvalidos, NoAutenticado, NoEncontrado, SinPermiso
from app.dominio.modelos import Lote, Rol
from tests.fakes import UnidadEnMemoria

AHORA = datetime(2026, 10, 21, 12, 0)


@pytest.fixture
def uow():
    uow = UnidadEnMemoria()
    usuarios.crear_usuario(uow, "Rafa", "483920", Rol.ADMINISTRADOR)
    usuarios.crear_usuario(uow, "Mamá", "729104", Rol.REGISTRADOR)
    return uow


def test_el_nombre_no_se_repite(uow):
    with pytest.raises(Conflicto):
        usuarios.crear_usuario(uow, "Rafa", "729104", Rol.REGISTRADOR)


def test_no_se_crea_un_usuario_con_pin_flojo(uow):
    with pytest.raises(DatosInvalidos):
        usuarios.crear_usuario(uow, "Papá", "111111", Rol.REGISTRADOR)


def test_iniciar_sesion_y_usar_el_token(uow):
    token, usuario = usuarios.iniciar_sesion(uow, "Mamá", "729104", AHORA)
    assert usuarios.usuario_de_sesion(uow, token).id == usuario.id
    assert token not in {s.token_hash for s in uow.sesiones.filas.values()}


def test_un_pin_incorrecto_guarda_el_intento(uow):
    with pytest.raises(NoAutenticado):
        usuarios.iniciar_sesion(uow, "Mamá", "000001", AHORA)
    assert uow.usuarios.por_nombre("Mamá").intentos_fallidos == 1


def test_el_bloqueo_se_conserva_entre_intentos(uow):
    for _ in range(5):
        with pytest.raises(NoAutenticado):
            usuarios.iniciar_sesion(uow, "Mamá", "000001", AHORA)
    assert uow.usuarios.por_nombre("Mamá").bloqueado_hasta is not None


def test_cerrar_sesion_invalida_el_token(uow):
    token, _ = usuarios.iniciar_sesion(uow, "Mamá", "729104", AHORA)
    usuarios.cerrar_sesion(uow, token)
    with pytest.raises(NoAutenticado):
        usuarios.usuario_de_sesion(uow, token)


def test_un_token_inventado_no_sirve(uow):
    with pytest.raises(NoAutenticado):
        usuarios.usuario_de_sesion(uow, "inventado")


def test_desactivar_cierra_sus_sesiones_y_queda_en_la_bitacora(uow):
    token, mama = usuarios.iniciar_sesion(uow, "Mamá", "729104", AHORA)
    admin = uow.usuarios.por_nombre("Rafa")
    usuarios.desactivar_usuario(uow, admin, mama.id, AHORA)
    with pytest.raises(NoAutenticado):
        usuarios.usuario_de_sesion(uow, token)
    with pytest.raises(NoAutenticado):
        usuarios.iniciar_sesion(uow, "Mamá", "729104", AHORA)
    assert [e.accion for e in uow.bitacora.listar()] == ["usuario_desactivado"]


def test_nadie_se_desactiva_a_si_mismo(uow):
    admin = uow.usuarios.por_nombre("Rafa")
    with pytest.raises(SinPermiso):
        usuarios.desactivar_usuario(uow, admin, admin.id, AHORA)


def test_solo_el_administrador_pasa_el_filtro(uow):
    usuarios.exigir_administrador(uow.usuarios.por_nombre("Rafa"))
    with pytest.raises(SinPermiso):
        usuarios.exigir_administrador(uow.usuarios.por_nombre("Mamá"))


def _con_registro(uow):
    galpon = galpones.crear_galpon(uow, "Galpón 1", 6000)
    linea = lineas.crear_linea(uow, "Hy-Line")
    lotes.crear_lote(
        uow,
        Lote(
            galpon_id=galpon.id,
            linea_id=linea.id,
            fecha_nacimiento=date(2026, 3, 1),
            fecha_ingreso=date(2026, 3, 2),
            aves_iniciales=5000,
        ),
    )
    dia = registros.RegistroDelDia(id=uuid.uuid4(), galpon_id=galpon.id, fecha=date(2026, 10, 15), huevos_total=4000)
    return registros.guardar_registro(uow, dia)


def test_borrar_un_registro_deja_constancia_de_quien_y_que(uow):
    registro = _con_registro(uow)
    admin = uow.usuarios.por_nombre("Rafa")
    registros.borrar_registro(uow, admin, registro.id, AHORA)
    assert registros.registro_del_dia(uow, 1, date(2026, 10, 15)) is None
    evento = uow.bitacora.listar()[0]
    assert evento.accion == "registro_borrado" and evento.usuario_id == admin.id
    assert str(registro.id) in evento.detalle and "huevos 4000" in evento.detalle


def test_borrar_un_registro_que_no_existe(uow):
    with pytest.raises(NoEncontrado):
        registros.borrar_registro(uow, uow.usuarios.por_nombre("Rafa"), uuid.uuid4(), AHORA)
