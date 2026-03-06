class AgenteConfig {
  final int id;
  final int usuarioId;
  final String nome;
  final String? descricao;
  final String? instrucoesSistema;
  final String provider;
  final String modelo;
  final List<String> ferramentasHabilitadas;
  final String? contextoReferencia;
  final int maxTokens;
  final int maxIteracoesTool;
  final bool ativo;
  final DateTime createdAt;
  final DateTime updatedAt;

  AgenteConfig({
    required this.id,
    required this.usuarioId,
    required this.nome,
    this.descricao,
    this.instrucoesSistema,
    required this.provider,
    required this.modelo,
    this.ferramentasHabilitadas = const [],
    this.contextoReferencia,
    this.maxTokens = 4096,
    this.maxIteracoesTool = 10,
    this.ativo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AgenteConfig.fromJson(Map<String, dynamic> json) {
    return AgenteConfig(
      id: json['id'],
      usuarioId: json['usuario_id'],
      nome: json['nome'],
      descricao: json['descricao'],
      instrucoesSistema: json['instrucoes_sistema'],
      provider: json['provider'] ?? 'anthropic',
      modelo: json['modelo'] ?? 'claude-sonnet-4-5-20250514',
      ferramentasHabilitadas:
          (json['ferramentas_habilitadas'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
      contextoReferencia: json['contexto_referencia'],
      maxTokens: json['max_tokens'] ?? 4096,
      maxIteracoesTool: json['max_iteracoes_tool'] ?? 10,
      ativo: json['ativo'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class FerramentaDisponivel {
  final String nome;
  final String descricaoUi;
  final String categoria;

  FerramentaDisponivel({
    required this.nome,
    required this.descricaoUi,
    required this.categoria,
  });

  factory FerramentaDisponivel.fromJson(Map<String, dynamic> json) {
    return FerramentaDisponivel(
      nome: json['nome'],
      descricaoUi: json['descricao_ui'],
      categoria: json['categoria'],
    );
  }
}
