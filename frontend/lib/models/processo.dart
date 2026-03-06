class Processo {
  final int id;
  final String cnj;
  final String numeroLimpo;
  final String tribunal;
  final String aliasTribunal;
  final int? classeCodigo;
  final String? classeNome;
  final String? orgaoJulgador;
  final String? grau;
  final DateTime? dataAjuizamento;
  final String status;
  final DateTime? ultimaVerificacao;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProcessoParte> partes;
  final List<Movimento> movimentos;

  Processo({
    required this.id,
    required this.cnj,
    required this.numeroLimpo,
    required this.tribunal,
    required this.aliasTribunal,
    this.classeCodigo,
    this.classeNome,
    this.orgaoJulgador,
    this.grau,
    this.dataAjuizamento,
    required this.status,
    this.ultimaVerificacao,
    required this.createdAt,
    required this.updatedAt,
    this.partes = const [],
    this.movimentos = const [],
  });

  factory Processo.fromJson(Map<String, dynamic> json) {
    return Processo(
      id: json['id'],
      cnj: json['cnj'],
      numeroLimpo: json['numero_limpo'],
      tribunal: json['tribunal'],
      aliasTribunal: json['alias_tribunal'],
      classeCodigo: json['classe_codigo'],
      classeNome: json['classe_nome'],
      orgaoJulgador: json['orgao_julgador'],
      grau: json['grau'],
      dataAjuizamento: json['data_ajuizamento'] != null
          ? DateTime.parse(json['data_ajuizamento'])
          : null,
      status: json['status'],
      ultimaVerificacao: json['ultima_verificacao'] != null
          ? DateTime.parse(json['ultima_verificacao'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      partes: (json['partes'] as List<dynamic>?)
              ?.map((e) => ProcessoParte.fromJson(e))
              .toList() ??
          [],
      movimentos: (json['movimentos'] as List<dynamic>?)
              ?.map((e) => Movimento.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class ProcessoParte {
  final int id;
  final int processoId;
  final int clienteId;
  final String papel;

  ProcessoParte({
    required this.id,
    required this.processoId,
    required this.clienteId,
    required this.papel,
  });

  factory ProcessoParte.fromJson(Map<String, dynamic> json) {
    return ProcessoParte(
      id: json['id'],
      processoId: json['processo_id'],
      clienteId: json['cliente_id'],
      papel: json['papel'],
    );
  }
}

class Movimento {
  final int id;
  final int processoId;
  final int codigo;
  final String nome;
  final DateTime dataHora;
  final String? complementos;
  final String? resumoIa;
  final bool notificado;
  final DateTime createdAt;

  Movimento({
    required this.id,
    required this.processoId,
    required this.codigo,
    required this.nome,
    required this.dataHora,
    this.complementos,
    this.resumoIa,
    required this.notificado,
    required this.createdAt,
  });

  factory Movimento.fromJson(Map<String, dynamic> json) {
    return Movimento(
      id: json['id'],
      processoId: json['processo_id'],
      codigo: json['codigo'],
      nome: json['nome'],
      dataHora: DateTime.parse(json['data_hora']),
      complementos: json['complementos'],
      resumoIa: json['resumo_ia'],
      notificado: json['notificado'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
