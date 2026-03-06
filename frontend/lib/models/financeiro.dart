class Financeiro {
  final int id;
  final int processoId;
  final int clienteId;
  final String tipo;
  final String? descricao;
  final double valor;
  final String status;
  final String? dataVencimento;
  final String? dataPagamento;
  final DateTime createdAt;
  final DateTime updatedAt;

  Financeiro({
    required this.id,
    required this.processoId,
    required this.clienteId,
    required this.tipo,
    this.descricao,
    required this.valor,
    required this.status,
    this.dataVencimento,
    this.dataPagamento,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Financeiro.fromJson(Map<String, dynamic> json) {
    return Financeiro(
      id: json['id'],
      processoId: json['processo_id'],
      clienteId: json['cliente_id'],
      tipo: json['tipo'],
      descricao: json['descricao'],
      valor: (json['valor'] as num).toDouble(),
      status: json['status'],
      dataVencimento: json['data_vencimento'],
      dataPagamento: json['data_pagamento'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'processo_id': processoId,
      'cliente_id': clienteId,
      'tipo': tipo,
      'descricao': descricao,
      'valor': valor,
      'status': status,
      'data_vencimento': dataVencimento,
    };
  }
}

class FinanceiroResumo {
  final double pendente;
  final double pago;
  final double total;

  FinanceiroResumo({
    required this.pendente,
    required this.pago,
    required this.total,
  });

  factory FinanceiroResumo.fromJson(Map<String, dynamic> json) {
    return FinanceiroResumo(
      pendente: (json['pendente'] as num).toDouble(),
      pago: (json['pago'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }
}
