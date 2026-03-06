class Prazo {
  final int id;
  final int processoId;
  final String tipo;
  final String? descricao;
  final String dataLimite;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Prazo({
    required this.id,
    required this.processoId,
    required this.tipo,
    this.descricao,
    required this.dataLimite,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Prazo.fromJson(Map<String, dynamic> json) {
    return Prazo(
      id: json['id'],
      processoId: json['processo_id'],
      tipo: json['tipo'],
      descricao: json['descricao'],
      dataLimite: json['data_limite'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
