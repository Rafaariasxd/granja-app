enum Rol { administrador, registrador }

class Sesion {
  const Sesion({required this.token, required this.nombre, required this.rol});

  final String token;
  final String nombre;
  final Rol rol;

  bool get esAdministrador => rol == Rol.administrador;

  Map<String, String> aMapa() => {'token': token, 'nombre': nombre, 'rol': rol.name};

  static Sesion? desdeMapa(Map<String, String?> mapa) {
    final token = mapa['token'];
    final nombre = mapa['nombre'];
    final rol = Rol.values.where((r) => r.name == mapa['rol']);
    if (token == null || token.isEmpty || nombre == null || rol.isEmpty) return null;
    return Sesion(token: token, nombre: nombre, rol: rol.single);
  }
}
