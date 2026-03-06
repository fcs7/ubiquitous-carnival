class Conversa {
  final int id;
  final String? titulo;
  final int usuarioId;
  final int? processoId;
  final String modeloClaude;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Mensagem> mensagens;

  Conversa({
    required this.id,
    this.titulo,
    required this.usuarioId,
    this.processoId,
    required this.modeloClaude,
    required this.createdAt,
    required this.updatedAt,
    this.mensagens = const [],
  });

  factory Conversa.fromJson(Map<String, dynamic> json) {
    return Conversa(
      id: json['id'],
      titulo: json['titulo'],
      usuarioId: json['usuario_id'],
      processoId: json['processo_id'],
      modeloClaude: json['modelo_claude'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      mensagens: (json['mensagens'] as List<dynamic>?)
              ?.map((e) => Mensagem.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class Mensagem {
  final int id;
  final int conversaId;
  final String role;
  final String conteudo;
  final int? tokensInput;
  final int? tokensOutput;
  final DateTime createdAt;

  Mensagem({
    required this.id,
    required this.conversaId,
    required this.role,
    required this.conteudo,
    this.tokensInput,
    this.tokensOutput,
    required this.createdAt,
  });

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    return Mensagem(
      id: json['id'],
      conversaId: json['conversa_id'],
      role: json['role'],
      conteudo: json['conteudo'],
      tokensInput: json['tokens_input'],
      tokensOutput: json['tokens_output'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
