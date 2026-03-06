class Cliente {
  final int id;
  final String nome;
  final String cpfCnpj;
  final String? rg;
  final String? cnh;
  final String? dataNascimento;
  final String? nacionalidade;
  final String? estadoCivil;
  final String? profissao;
  final String telefone;
  final String? telefone2;
  final String? email;
  final String? endereco;
  final String? cidade;
  final String? uf;
  final String? cep;
  final String? observacoes;
  final String? outrosDados;
  final DateTime createdAt;
  final DateTime updatedAt;

  Cliente({
    required this.id,
    required this.nome,
    required this.cpfCnpj,
    this.rg,
    this.cnh,
    this.dataNascimento,
    this.nacionalidade,
    this.estadoCivil,
    this.profissao,
    required this.telefone,
    this.telefone2,
    this.email,
    this.endereco,
    this.cidade,
    this.uf,
    this.cep,
    this.observacoes,
    this.outrosDados,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'],
      nome: json['nome'],
      cpfCnpj: json['cpf_cnpj'],
      rg: json['rg'],
      cnh: json['cnh'],
      dataNascimento: json['data_nascimento'],
      nacionalidade: json['nacionalidade'],
      estadoCivil: json['estado_civil'],
      profissao: json['profissao'],
      telefone: json['telefone'],
      telefone2: json['telefone2'],
      email: json['email'],
      endereco: json['endereco'],
      cidade: json['cidade'],
      uf: json['uf'],
      cep: json['cep'],
      observacoes: json['observacoes'],
      outrosDados: json['outros_dados'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'cpf_cnpj': cpfCnpj,
      'rg': rg,
      'cnh': cnh,
      'data_nascimento': dataNascimento,
      'nacionalidade': nacionalidade,
      'estado_civil': estadoCivil,
      'profissao': profissao,
      'telefone': telefone,
      'telefone2': telefone2,
      'email': email,
      'endereco': endereco,
      'cidade': cidade,
      'uf': uf,
      'cep': cep,
      'observacoes': observacoes,
      'outros_dados': outrosDados,
    };
  }
}
