import '../core/json.dart';

class Negocio {
  const Negocio({required this.id, required this.nombre, this.creadoEn});

  final String id;
  final String nombre;
  final DateTime? creadoEn;

  factory Negocio.desdeJson(Map<String, dynamic> json) => Negocio(
        id: J.texto(json['id']),
        nombre: J.texto(json['nombre']),
        creadoEn: J.fecha(json['creado_en']),
      );
}
