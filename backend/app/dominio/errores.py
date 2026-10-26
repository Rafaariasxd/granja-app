class ErrorDeDominio(Exception):
    pass


class NoEncontrado(ErrorDeDominio):
    pass


class Conflicto(ErrorDeDominio):
    pass


class DatosInvalidos(ErrorDeDominio):
    pass


class NoAutenticado(ErrorDeDominio):
    pass


class SinPermiso(ErrorDeDominio):
    pass


class Bloqueado(ErrorDeDominio):
    pass


class ServicioNoDisponible(ErrorDeDominio):
    pass
