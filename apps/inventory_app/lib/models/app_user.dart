class AppUser {
  final String id;
  final String nombre;
  final String usuario;
  final String rol;

  AppUser({required this.id, required this.nombre, required this.usuario, required this.rol});

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        usuario: json['usuario'] as String,
        rol: json['rol'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'usuario': usuario, 'rol': rol};
}
