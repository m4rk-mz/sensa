import '../core/json.dart';

/// Un usuario tal como lo devuelve el backend (sin contraseña ni hash).
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    this.businessId,
    this.activo = true,
  });

  final String id;
  final String nombre;
  final String email;
  final String rol;
  final String? businessId;
  final bool activo;

  /// El rol lo decide el backend; la app solo lo usa para elegir pantallas.
  bool get esAdmin => rol == 'platform_admin';

  String get rolLegible =>
      esAdmin ? 'Administrador de la plataforma' : 'Usuario del negocio';

  factory Usuario.desdeJson(Map<String, dynamic> json) => Usuario(
        id: J.texto(json['id']),
        nombre: J.texto(json['nombre']),
        email: J.texto(json['email']),
        rol: J.texto(json['rol'], porOmision: 'business_user'),
        businessId: json['business_id'] == null
            ? null
            : J.texto(json['business_id']),
        activo: J.booleano(json['activo'], porOmision: true),
      );

  Map<String, dynamic> aJson() => <String, dynamic>{
        'id': id,
        'nombre': nombre,
        'email': email,
        'rol': rol,
        'business_id': businessId,
        'activo': activo,
      };
}

/// Respuesta de POST /auth/login.
class Sesion {
  const Sesion({
    required this.token,
    required this.usuario,
    this.expiraEn,
  });

  final String token;
  final Usuario usuario;
  final DateTime? expiraEn;

  factory Sesion.desdeJson(Map<String, dynamic> json) => Sesion(
        token: J.texto(json['access_token']),
        usuario: Usuario.desdeJson(J.mapa(json['usuario'])),
        expiraEn: J.fecha(json['expira_en']),
      );
}
