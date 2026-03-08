class StatusServico {
  final String nome;
  final String status; // "ok" ou "erro"
  final String? detalhes;

  StatusServico({required this.nome, required this.status, this.detalhes});

  factory StatusServico.fromJson(Map<String, dynamic> json) {
    return StatusServico(
      nome: json['nome'] as String,
      status: json['status'] as String,
      detalhes: json['detalhes'] as String?,
    );
  }

  bool get isOk => status == 'ok';
}
