import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:muglia/models/agente.dart';
import 'package:muglia/services/api_service.dart';
import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/drive_folder_picker_dialog.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';

class AgenteFormScreen extends StatefulWidget {
  final int? agenteId;
  const AgenteFormScreen({super.key, this.agenteId});

  @override
  State<AgenteFormScreen> createState() => _AgenteFormScreenState();
}

class _AgenteFormScreenState extends State<AgenteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _carregando = false;
  bool _carregandoDados = false;
  bool _editando = false;

  // Campos do formulario
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _instrucoesSistemaController = TextEditingController();
  final _contextoReferenciaController = TextEditingController();
  final _maxTokensController = TextEditingController(text: '4096');
  final _maxIteracoesController = TextEditingController(text: '10');

  String _providerSelecionado = 'anthropic';
  String _modeloSelecionado = 'claude-sonnet-4-5-20250514';
  Set<String> _ferramentasSelecionadas = {};
  bool _ativo = true;

  bool _gerandoInstrucao = false;
  bool _gerandoContexto = false;
  bool _gerandoMemoria = false;

  List<FerramentaDisponivel> _ferramentasDisponiveis = [];
  bool _carregandoFerramentas = false;

  static const _modelos = {
    'anthropic': [
      {'valor': 'claude-haiku-4-5-20251001', 'nome': 'Claude Haiku (rapido, economico)'},
      {'valor': 'claude-sonnet-4-5-20250514', 'nome': 'Claude Sonnet (avancado)'},
      {'valor': 'claude-opus-4-6', 'nome': 'Claude Opus (maximo)'},
    ],
    'openai': [
      {'valor': 'gpt-4o-mini', 'nome': 'GPT-4o mini (rapido, economico)'},
      {'valor': 'gpt-4o', 'nome': 'GPT-4o (avancado)'},
      {'valor': 'gpt-4-turbo', 'nome': 'GPT-4 Turbo'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _editando = widget.agenteId != null;
    _carregarFerramentas();
    if (_editando) {
      _carregarDadosAgente();
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _instrucoesSistemaController.dispose();
    _contextoReferenciaController.dispose();
    _maxTokensController.dispose();
    _maxIteracoesController.dispose();
    super.dispose();
  }

  Future<void> _carregarFerramentas() async {
    setState(() => _carregandoFerramentas = true);
    try {
      final api = context.read<ApiService>();
      final lista = await api.getFerramentasDisponiveis();
      setState(() {
        _ferramentasDisponiveis =
            lista.map((j) => FerramentaDisponivel.fromJson(j)).toList();
        _carregandoFerramentas = false;
      });
    } catch (e) {
      setState(() => _carregandoFerramentas = false);
    }
  }

  Future<void> _carregarDadosAgente() async {
    setState(() => _carregandoDados = true);
    try {
      final api = context.read<ApiService>();
      final json = await api.getAgente(widget.agenteId!);
      final agente = AgenteConfig.fromJson(json);

      _nomeController.text = agente.nome;
      _descricaoController.text = agente.descricao ?? '';
      _instrucoesSistemaController.text = agente.instrucoesSistema ?? '';
      _contextoReferenciaController.text = agente.contextoReferencia ?? '';
      _maxTokensController.text = agente.maxTokens.toString();
      _maxIteracoesController.text = agente.maxIteracoesTool.toString();
      _providerSelecionado = agente.provider;
      _modeloSelecionado = agente.modelo;
      _ferramentasSelecionadas = agente.ferramentasHabilitadas.toSet();
      _ativo = agente.ativo;

      setState(() => _carregandoDados = false);
    } catch (e) {
      setState(() => _carregandoDados = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar dados do agente'),
            backgroundColor: MugliaTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final api = context.read<ApiService>();
      final payload = {
        'nome': _nomeController.text.trim(),
        'usuario_id': 1,
        'provider': _providerSelecionado,
        'modelo': _modeloSelecionado,
        'ferramentas_habilitadas': _ferramentasSelecionadas.toList(),
        'max_tokens': int.tryParse(_maxTokensController.text) ?? 4096,
        'max_iteracoes_tool': int.tryParse(_maxIteracoesController.text) ?? 10,
        'ativo': _ativo,
      };

      final descricao = _descricaoController.text.trim();
      if (descricao.isNotEmpty) payload['descricao'] = descricao;

      final instrucoes = _instrucoesSistemaController.text.trim();
      if (instrucoes.isNotEmpty) payload['instrucoes_sistema'] = instrucoes;

      final contexto = _contextoReferenciaController.text.trim();
      if (contexto.isNotEmpty) payload['contexto_referencia'] = contexto;

      if (_editando) {
        payload.remove('usuario_id');
        await api.atualizarAgente(widget.agenteId!, payload);
      } else {
        await api.criarAgente(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editando
                  ? 'Agente atualizado com sucesso'
                  : 'Agente criado com sucesso',
            ),
            backgroundColor: MugliaTheme.success,
          ),
        );
        context.go('/configuracoes/agentes');
      }
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editando
                  ? 'Erro ao atualizar agente'
                  : 'Erro ao criar agente',
            ),
            backgroundColor: MugliaTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _gerarInstrucao() async {
    if (_nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome do agente antes de gerar')),
      );
      return;
    }

    setState(() => _gerandoInstrucao = true);
    try {
      final api = context.read<ApiService>();
      final resultado = await api.gerarInstrucao({
        'nome': _nomeController.text.trim(),
        'descricao': _descricaoController.text.trim(),
        'provider': _providerSelecionado,
        'modelo': _modeloSelecionado,
        'ferramentas_habilitadas': _ferramentasSelecionadas.toList(),
      });

      final instrucao = resultado['instrucoes_sistema'] as String;

      if (_instrucoesSistemaController.text.isNotEmpty) {
        final substituir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Substituir instrucoes?'),
            content: const Text('O campo ja tem conteudo. Deseja substituir?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Substituir'),
              ),
            ],
          ),
        );
        if (substituir != true) return;
      }

      _instrucoesSistemaController.text = instrucao;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao gerar instrucao')),
        );
      }
    } finally {
      if (mounted) setState(() => _gerandoInstrucao = false);
    }
  }

  Future<void> _abrirSeletorClientes() async {
    List<dynamic> clientes;
    try {
      final api = context.read<ApiService>();
      clientes = await api.getClientes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar clientes')),
        );
      }
      return;
    }

    if (!mounted) return;

    final selecionados = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _DialogSeletorClientes(clientes: clientes),
    );

    if (selecionados == null || selecionados.isEmpty) return;

    setState(() => _gerandoContexto = true);
    try {
      final api = context.read<ApiService>();
      final resultado = await api.gerarContexto(selecionados.toList());

      final contexto = resultado['contexto_referencia'] as String;

      if (_contextoReferenciaController.text.isNotEmpty) {
        final substituir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Substituir contexto?'),
            content: const Text('O campo ja tem conteudo. Deseja substituir?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Substituir'),
              ),
            ],
          ),
        );
        if (substituir != true) {
          setState(() => _gerandoContexto = false);
          return;
        }
      }

      _contextoReferenciaController.text = contexto;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao gerar contexto')),
        );
      }
    } finally {
      if (mounted) setState(() => _gerandoContexto = false);
    }
  }

  Future<void> _abrirSeletorPastaDrive() async {
    if (!_editando) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salve o agente antes de gerar memoria')),
      );
      return;
    }

    final api = context.read<ApiService>();
    final pasta = await showDialog<DriveFolderSelection>(
      context: context,
      builder: (_) => DriveFolderPickerDialog(api: api),
    );

    if (pasta == null || !mounted) return;

    setState(() => _gerandoMemoria = true);
    try {
      final resultado = await api.gerarMemoriaDrive(widget.agenteId!, pasta.id);
      final gerados = resultado['arquivos_gerados'] as List<dynamic>? ?? [];

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Memoria gerada: ${gerados.length} arquivo(s) criado(s)'),
            backgroundColor: MugliaTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar memoria: $e'),
            backgroundColor: MugliaTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _gerandoMemoria = false);
    }
  }

  Widget _buildSecao({
    required String titulo,
    required IconData icone,
    required List<Widget> campos,
    String? subtitulo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
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
        if (subtitulo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 30),
            child: Text(
              subtitulo,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          const SizedBox(height: 12),
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
    String? hint,
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
          hintText: hint,
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

  Widget _buildProviderSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _buildProviderOption(
            'anthropic',
            'Anthropic',
            Icons.auto_awesome_rounded,
            const Color(0xFFD4A574),
          ),
          const SizedBox(width: 12),
          _buildProviderOption(
            'openai',
            'OpenAI',
            Icons.psychology_rounded,
            const Color(0xFF74AA9C),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderOption(
      String valor, String nome, IconData icone, Color cor) {
    final selecionado = _providerSelecionado == valor;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _providerSelecionado = valor;
              // Seleciona primeiro modelo do provider
              final modelos = _modelos[valor]!;
              _modeloSelecionado = modelos.first['valor'] as String;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selecionado
                  ? cor.withValues(alpha: 0.12)
                  : MugliaTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selecionado ? cor : MugliaTheme.border,
                width: selecionado ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icone,
                    color: selecionado ? cor : MugliaTheme.textMuted,
                    size: 28),
                const SizedBox(height: 8),
                Text(
                  nome,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selecionado ? FontWeight.w600 : FontWeight.w400,
                    color: selecionado
                        ? MugliaTheme.textPrimary
                        : MugliaTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeloDropdown() {
    final modelos = _modelos[_providerSelecionado] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: modelos.any((m) => m['valor'] == _modeloSelecionado)
            ? _modeloSelecionado
            : (modelos.isNotEmpty ? modelos.first['valor'] as String : null),
        decoration: const InputDecoration(
          labelText: 'Modelo *',
          prefixIcon: Icon(Icons.memory_rounded),
        ),
        dropdownColor: MugliaTheme.surface,
        items: modelos
            .map((m) => DropdownMenuItem(
                  value: m['valor'] as String,
                  child: Text(m['nome'] as String),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _modeloSelecionado = v);
        },
        validator: (v) {
          if (v == null || v.isEmpty) return 'Selecione um modelo';
          return null;
        },
      ),
    );
  }

  Widget _buildFerramentasSelector() {
    if (_carregandoFerramentas) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(
            color: MugliaTheme.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_ferramentasDisponiveis.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          'Nenhuma ferramenta disponivel',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    // Agrupa por categoria
    final porCategoria = <String, List<FerramentaDisponivel>>{};
    for (final f in _ferramentasDisponiveis) {
      porCategoria.putIfAbsent(f.categoria, () => []).add(f);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selecionar/desselecionar todas
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _ferramentasSelecionadas =
                      _ferramentasDisponiveis.map((f) => f.nome).toSet();
                });
              },
              icon: const Icon(Icons.select_all_rounded, size: 16),
              label: const Text('Todas'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 32),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() => _ferramentasSelecionadas = {});
              },
              icon: const Icon(Icons.deselect_rounded, size: 16),
              label: const Text('Nenhuma'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 32),
              ),
            ),
            const Spacer(),
            Text(
              '${_ferramentasSelecionadas.length} selecionada${_ferramentasSelecionadas.length != 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...porCategoria.entries.map((entry) {
          final categoria = entry.key;
          final ferramentas = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  _nomeCategoria(categoria),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MugliaTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ferramentas.map((f) {
                  final selecionada =
                      _ferramentasSelecionadas.contains(f.nome);
                  return FilterChip(
                    selected: selecionada,
                    label: Text(f.descricaoUi),
                    avatar: Icon(
                      _iconeCategoria(categoria),
                      size: 16,
                      color: selecionada
                          ? MugliaTheme.primary
                          : MugliaTheme.textMuted,
                    ),
                    selectedColor: MugliaTheme.primaryDark.withValues(alpha: 0.3),
                    checkmarkColor: MugliaTheme.primary,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _ferramentasSelecionadas.add(f.nome);
                        } else {
                          _ferramentasSelecionadas.remove(f.nome);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  String _nomeCategoria(String cat) {
    switch (cat) {
      case 'processo':
        return 'PROCESSOS';
      case 'cliente':
        return 'CLIENTES';
      case 'prazo':
        return 'PRAZOS';
      default:
        return cat.toUpperCase();
    }
  }

  IconData _iconeCategoria(String cat) {
    switch (cat) {
      case 'processo':
        return Icons.gavel_rounded;
      case 'cliente':
        return Icons.people_rounded;
      case 'prazo':
        return Icons.schedule_rounded;
      default:
        return Icons.extension_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MugliaScaffold(
      title: _editando ? 'Editar Agente' : 'Novo Agente',
      body: _carregandoDados
          ? const Center(
              child: CircularProgressIndicator(color: MugliaTheme.primary),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Identificacao ──────────────────
                  _buildSecao(
                    titulo: 'Identificacao',
                    icone: Icons.badge_rounded,
                    campos: [
                      _buildCampo(
                        label: 'Nome do agente',
                        controller: _nomeController,
                        obrigatorio: true,
                        hint: 'Ex: Agente Trabalhista',
                      ),
                      _buildCampo(
                        label: 'Descricao',
                        controller: _descricaoController,
                        hint: 'Breve descricao do proposito do agente',
                        maxLines: 2,
                      ),
                      if (_editando)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Agente ativo'),
                            subtitle: Text(
                              _ativo
                                  ? 'Disponivel para novas conversas'
                                  : 'Desabilitado',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            value: _ativo,
                            activeColor: MugliaTheme.success,
                            onChanged: (v) => setState(() => _ativo = v),
                          ),
                        ),
                    ],
                  ),

                  const Divider(height: 40),

                  // ── Provider e Modelo ──────────────
                  _buildSecao(
                    titulo: 'Provider e Modelo',
                    icone: Icons.cloud_rounded,
                    subtitulo: 'Escolha o provedor de IA e o modelo',
                    campos: [
                      _buildProviderSelector(),
                      _buildModeloDropdown(),
                    ],
                  ),

                  const Divider(height: 40),

                  // ── Ferramentas ────────────────────
                  _buildSecao(
                    titulo: 'Ferramentas',
                    icone: Icons.build_rounded,
                    subtitulo:
                        'Selecione as ferramentas que o agente pode usar autonomamente',
                    campos: [
                      _buildFerramentasSelector(),
                    ],
                  ),

                  const Divider(height: 40),

                  // ── Instrucoes ─────────────────────
                  _buildSecao(
                    titulo: 'Instrucoes',
                    icone: Icons.description_rounded,
                    subtitulo:
                        'Instrucoes adicionais e contexto de referencia para o agente',
                    campos: [
                      _buildCampo(
                        label: 'Instrucoes do sistema',
                        controller: _instrucoesSistemaController,
                        maxLines: 5,
                        hint:
                            'Ex: Voce e especialista em direito trabalhista. Sempre cite artigos da CLT...',
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: OutlinedButton.icon(
                          onPressed: _gerandoInstrucao ? null : _gerarInstrucao,
                          icon: _gerandoInstrucao
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: MugliaTheme.accent),
                                )
                              : const Icon(Icons.auto_awesome_rounded, size: 18),
                          label: Text(_gerandoInstrucao ? 'Gerando...' : 'Gerar instrucao com IA'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MugliaTheme.accent,
                            side: BorderSide(color: MugliaTheme.accent.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                      _buildCampo(
                        label: 'Contexto de referencia',
                        controller: _contextoReferenciaController,
                        maxLines: 4,
                        hint:
                            'Informacoes adicionais que o agente deve considerar',
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: OutlinedButton.icon(
                          onPressed: _gerandoContexto ? null : _abrirSeletorClientes,
                          icon: _gerandoContexto
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: MugliaTheme.accent),
                                )
                              : const Icon(Icons.people_rounded, size: 18),
                          label: Text(_gerandoContexto ? 'Gerando...' : 'Gerar contexto de clientes'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MugliaTheme.accent,
                            side: BorderSide(color: MugliaTheme.accent.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Tooltip(
                          message: _editando ? '' : 'Salve o agente antes de gerar memoria',
                          child: OutlinedButton.icon(
                            onPressed: _gerandoMemoria ? null : _abrirSeletorPastaDrive,
                            icon: _gerandoMemoria
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: MugliaTheme.accent),
                                  )
                                : const Icon(Icons.cloud_download_rounded, size: 18),
                            label: Text(_gerandoMemoria ? 'Gerando memoria...' : 'Gerar memoria a partir do Drive'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: MugliaTheme.accent,
                              side: BorderSide(color: MugliaTheme.accent.withValues(alpha: 0.5)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 40),

                  // ── Parametros ─────────────────────
                  _buildSecao(
                    titulo: 'Parametros',
                    icone: Icons.tune_rounded,
                    subtitulo: 'Limites de tokens e iteracoes de ferramentas',
                    campos: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildCampo(
                              label: 'Max tokens',
                              controller: _maxTokensController,
                              teclado: TextInputType.number,
                              validador: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n < 256 || n > 32768) {
                                  return 'Entre 256 e 32768';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCampo(
                              label: 'Max iteracoes tool',
                              controller: _maxIteracoesController,
                              teclado: TextInputType.number,
                              validador: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n < 1 || n > 50) {
                                  return 'Entre 1 e 50';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
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
                                ? 'Atualizar Agente'
                                : 'Criar Agente',
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

class _DialogSeletorClientes extends StatefulWidget {
  final List<dynamic> clientes;
  const _DialogSeletorClientes({required this.clientes});

  @override
  State<_DialogSeletorClientes> createState() => _DialogSeletorClientesState();
}

class _DialogSeletorClientesState extends State<_DialogSeletorClientes> {
  final Set<int> _selecionados = {};
  String _busca = '';

  List<dynamic> get _clientesFiltrados {
    if (_busca.isEmpty) return widget.clientes;
    final termo = _busca.toLowerCase();
    return widget.clientes.where((c) {
      final nome = (c['nome'] ?? '').toString().toLowerCase();
      final cpf = (c['cpf_cnpj'] ?? '').toString().toLowerCase();
      return nome.contains(termo) || cpf.contains(termo);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecionar clientes'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por nome ou CPF...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busca = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${_selecionados.length} selecionado${_selecionados.length != 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (_selecionados.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selecionados.clear()),
                    child: const Text('Limpar'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _clientesFiltrados.isEmpty
                  ? const Center(child: Text('Nenhum cliente encontrado'))
                  : ListView.builder(
                      itemCount: _clientesFiltrados.length,
                      itemBuilder: (context, index) {
                        final cliente = _clientesFiltrados[index];
                        final id = cliente['id'] as int;
                        final nome = cliente['nome'] ?? 'Sem nome';
                        final cpf = cliente['cpf_cnpj'] ?? '';
                        final selecionado = _selecionados.contains(id);

                        return CheckboxListTile(
                          value: selecionado,
                          title: Text(nome, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(cpf, style: const TextStyle(fontSize: 12)),
                          dense: true,
                          activeColor: MugliaTheme.primary,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selecionados.add(id);
                              } else {
                                _selecionados.remove(id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _selecionados.isEmpty
              ? null
              : () => Navigator.pop(context, _selecionados),
          child: Text('Gerar contexto (${_selecionados.length})'),
        ),
      ],
    );
  }
}
