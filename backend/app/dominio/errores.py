class ErrorDeDominio(Exception):
    pass


class NoEncontrado(ErrorDeDominio):
    pass


class Conflicto(ErrorDeDominio):
    pass


class DatosInvalidos(ErrorDeDominio):
    pass
