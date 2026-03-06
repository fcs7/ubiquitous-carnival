import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:muglia/models/cliente.dart';
import 'package:muglia/services/api_service.dart';
import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';

class ClienteFormScreen extends StatefulWidget {
  final int? clienteId;
  const ClienteFormScreen({super.key, this.clienteId});

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _carregando = false;
  bool _carregandoDados = false;
  bool _editando = false;

  // Dados Pessoais
  final _nomeController = TextEditingController();
  final _cpfCnpjController = TextEditingController();
  final _rgController = TextEditingController();
  final _cnhController = TextEditingController();
  final _dataNascimentoController = TextEditingController();
  final _nacionalidadeController = TextEditingController();
  final _profissaoController = TextEditingController();
  String? _estadoCivil;

  // Contato
  final _telefoneController = TextEditingController();
  final _telefone2Controller = TextEditingController();
  final _emailController = TextEditingController();

  // Endereco
  final _enderecoController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _cepController = TextEditingController();
  String? _uf;

  // Outros
  final _observacoesController = TextEditingController();
  final _outrosDadosController = TextEditingController();

  static const _estadosCivis = [
    'Solteiro(a)',
    'Casado(a)',
    'Divorciado(a)',
    'Viuvo(a)',
    'Separado(a)',
    'Uniao Estavel',
  ];

  static const _ufs = [
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO',
    'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI',
    'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
  ];

  @override
  void initState() {
    super.initState();
    _editando = widget.clienteId != null;
    if (_editando) {
      _carregarDadosCliente();
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfCnpjController.dispose();
    _rgController.dispose();
    _cnhController.dispose();
    _dataNascimentoController.dispose();
    _nacionalidadeController.dispose();
    _profissaoController.dispose();
    _telefoneController.dispose();
    _telefone2Controller.dispose();
    _emailController.dispose();
    _enderecoController.dispose();
    _cidadeController.dispose();
    _cepController.dispose();
    _observacoesController.dispose();
    _outrosDadosController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosCliente() async {
    setState(() => _carregandoDados = true);

    try {
      final api = context.read<ApiService>();
      final json = await api.getCliente(widget.clienteId!);
      final cliente = Cliente.fromJson(json);

      _nomeController.text = cliente.nome;
      _cpfCnpjController.text = cliente.cpfCnpj;
      _rgController.text = cliente.rg ?? '';
      _cnhController.text = cliente.cnh ?? '';
      _dataNascimentoController.text = cliente.dataNascimento ?? '';
      _nacionalidadeController.text = cliente.nacionalidade ?? '';
      _profissaoController.text = cliente.profissao ?? '';
      _estadoCivil = cliente.estadoCivil;
      _telefoneController.text = cliente.telefone;
      _telefone2Controller.text = cliente.telefone2 ?? '';
      _emailController.text = cliente.email ?? '';
      _enderecoController.text = cliente.endereco ?? '';
      _cidadeController.text = cliente.cidade ?? '';
      _cepController.text = cliente.cep ?? '';
      _uf = cliente.uf;
      _observacoesController.text = cliente.observacoes ?? '';
      _outrosDadosController.text = cliente.outrosDados ?? '';

      setState(() => _carregandoDados = false);
    } catch (e) {
      setState(() => _carregandoDados = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar dados do cliente'),
            backgroundColor: MugliaTheme.error,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'nome': _nomeController.text.trim(),
      'cpf_cnpj': _cpfCnpjController.text.trim(),
      'rg': _rgController.text.trim().isEmpty
          ? null
          : _rgController.text.trim(),
      'cnh': _cnhController.text.trim().isEmpty
          ? null
          : _cnhController.text.trim(),
      'data_nascimento': _dataNascimentoController.text.trim().isEmpty
          ? null
          : _dataNascimentoController.text.trim(),
      'nacionalidade': _nacionalidadeController.text.trim().isEmpty
          ? null
          : _nacionalidadeController.text.trim(),
      'estado_civil': _estadoCivil,
      'profissao': _profissaoController.text.trim().isEmpty
          ? null
          : _profissaoController.text.trim(),
      'telefone': _telefoneController.text.trim(),
      'telefone2': _telefone2Controller.text.trim().isEmpty
          ? null
          : _telefone2Controller.text.trim(),
      'email': _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      'endereco': _enderecoController.text.trim().isEmpty
          ? null
          : _enderecoController.text.trim(),
      'cidade': _cidadeController.text.trim().isEmpty
          ? null
          : _cidadeController.text.trim(),
      'uf': _uf,
      'cep': _cepController.text.trim().isEmpty
          ? null
          : _cepController.text.trim(),
      'observacoes': _observacoesController.text.trim().isEmpty
          ? null
          : _observacoesController.text.trim(),
      'outros_dados': _outrosDadosController.text.trim().isEmpty
          ? null
          : _outrosDadosController.text.trim(),
    };
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final api = context.read<ApiService>();
      final payload = _buildPayload();

      if (_editando) {
        await api.atualizarCliente(widget.clienteId!, payload);
      } else {
        await api.criarCliente(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editando
                  ? 'Cliente atualizado com sucesso'
                  : 'Cliente criado com sucesso',
            ),
            backgroundColor: MugliaTheme.success,
          ),
        );
        context.go('/clientes');
      }
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editando
                  ? 'Erro ao atualizar cliente'
                  : 'Erro ao criar cliente',
            ),
            backgroundColor: MugliaTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildSecao({
    required String titulo,
    required IconData icone,
    required List<Widget> campos,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Icon(icone, size: 20, color: MugliaTheme.primary),
              const SizedBox(width: 10),
              Text(
                titulo,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: MugliaTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        ...campos,
      ],
    );
  }

  Widget _buildCampo({
    required String label,
    required TextEditingController controller,
    bool obrigatorio = false,
    TextInputType? teclado,
    int maxLines = 1,
    String? Function(String?)? validador,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: teclado,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: obrigatorio ? '$label *' : label,
        ),
        validator: validador ??
            (obrigatorio
                ? (v) {
                    if (v == null || v.trim().isEmpty) {
                      return '$label e obrigatorio';
                    }
                    return null;
                  }
                : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MugliaScaffold(
      title: _editando ? 'Editar Cliente' : 'Novo Cliente',
      body: _carregandoDados
          ? const Center(
              child: CircularProgressIndicator(color: MugliaTheme.primary),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Dados Pessoais ──────────────────
                  _buildSecao(
                    titulo: 'Dados Pessoais',
                    icone: Icons.person_outline_rounded,
                    campos: [
                      _buildCampo(
                        label: 'Nome completo',
                        controller: _nomeController,
                        obrigatorio: true,
                        teclado: TextInputType.name,
                      ),
                      _buildCampo(
                        label: 'CPF / CNPJ',
                        controller: _cpfCnpjController,
                        obrigatorio: true,
                        teclado: TextInputType.number,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCampo(
                              label: 'RG',
                              controller: _rgController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCampo(
                              label: 'CNH',
                              controller: _cnhController,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCampo(
                              label: 'Data de nascimento',
                              controller: _dataNascimentoController,
                              teclado: TextInputType.datetime,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCampo(
                              label: 'Nacionalidade',
                              controller: _nacionalidadeController,
                            ),
                          ),
                        ],
                      ),
                      // Estado civil dropdown
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: _estadoCivil,
                          decoration: const InputDecoration(
                            labelText: 'Estado civil',
                          ),
                          dropdownColor: MugliaTheme.surfaceVariant,
                          items: _estadosCivis
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => setState(() => _estadoCivil = v),
                        ),
                      ),
                      _buildCampo(
                        label: 'Profissao',
                        controller: _profissaoController,
                      ),
                    ],
                  ),

                  const Divider(height: 40),

                  // ── Contato ─────────────────────────
                  _buildSecao(
                    titulo: 'Contato',
                    icone: Icons.phone_outlined,
                    campos: [
                      _buildCampo(
                        label: 'Telefone principal',
                        controller: _telefoneController,
                        obrigatorio: true,
                        teclado: TextInputType.phone,
                      ),
                      _buildCampo(
                        label: 'Telefone secundario',
                        controller: _telefone2Controller,
                        teclado: TextInputType.phone,
                      ),
                      _buildCampo(
                        label: 'E-mail',
                        controller: _emailController,
                        teclado: TextInputType.emailAddress,
                        validador: (v) {
                          if (v != null &&
                              v.isNotEmpty &&
                              !v.contains('@')) {
                            return 'E-mail invalido';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),

                  const Divider(height: 40),

                  // ── Endereco ────────────────────────
                  _buildSecao(
                    titulo: 'Endereco',
                    icone: Icons.location_on_outlined,
                    campos: [
                      _buildCampo(
                        label: 'Endereco',
                        controller: _enderecoController,
                      ),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildCampo(
                              label: 'Cidade',
                              controller: _cidadeController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: DropdownButtonFormField<String>(
                                value: _uf,
                                decoration: const InputDecoration(
                                  labelText: 'UF',
                                ),
                                dropdownColor: MugliaTheme.surfaceVariant,
                                items: _ufs
                                    .map((e) => DropdownMenuItem(
                                        value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _uf = v),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _buildCampo(
                        label: 'CEP',
                        controller: _cepController,
                        teclado: TextInputType.number,
                      ),
                    ],
                  ),

                  const Divider(height: 40),

                  // ── Outros ──────────────────────────
                  _buildSecao(
                    titulo: 'Outros',
                    icone: Icons.notes_rounded,
                    campos: [
                      _buildCampo(
                        label: 'Observacoes',
                        controller: _observacoesController,
                        maxLines: 4,
                      ),
                      _buildCampo(
                        label: 'Outros dados',
                        controller: _outrosDadosController,
                        maxLines: 4,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Botao Salvar ────────────────────
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _carregando ? null : _salvar,
                      icon: _carregando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _carregando
                            ? 'Salvando...'
                            : _editando
                                ? 'Atualizar Cliente'
                                : 'Salvar Cliente',
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
