import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:muglia/models/agente.dart';
import 'package:muglia/services/api_service.dart';
import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';

class AgentesScreen extends StatefulWidget {
  const AgentesScreen({super.key});

  @override
  State<AgentesScreen> createState() => _AgentesScreenState();
}

class _AgentesScreenState extends State<AgentesScreen> {
  List<AgenteConfig> _agentes = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarAgentes();
  }

  Future<void> _carregarAgentes() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final api = context.read<ApiService>();
      final lista = await api.getAgentes();
      setState(() {
        _agentes = lista.map((j) => AgenteConfig.fromJson(j)).toList();
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar agentes';
        _carregando = false;
      });
    }
  }

  Future<void> _deletarAgente(AgenteConfig agente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir agente'),
        content: Text('Deseja realmente excluir "${agente.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: MugliaTheme.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      final api = context.read<ApiService>();
      await api.deletarAgente(agente.id);
      _carregarAgentes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agente excluido')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao excluir agente')),
        );
      }
    }
  }

  String _nomeProvider(String provider) {
    switch (provider) {
      case 'anthropic':
        return 'Anthropic';
      case 'openai':
        return 'OpenAI';
      default:
        return provider;
    }
  }

  Color _corProvider(String provider) {
    switch (provider) {
      case 'anthropic':
        return const Color(0xFFD4A574);
      case 'openai':
        return const Color(0xFF74AA9C);
      default:
        return MugliaTheme.textMuted;
    }
  }

  IconData _iconeProvider(String provider) {
    switch (provider) {
      case 'anthropic':
        return Icons.auto_awesome_rounded;
      case 'openai':
        return Icons.psychology_rounded;
      default:
        return Icons.smart_toy_rounded;
    }
  }

  String _nomeModeloCurto(String modelo) {
    if (modelo.contains('haiku')) return 'Haiku';
    if (modelo.contains('sonnet')) return 'Sonnet';
    if (modelo.contains('opus')) return 'Opus';
    if (modelo.contains('gpt-4o-mini')) return 'GPT-4o mini';
    if (modelo.contains('gpt-4o')) return 'GPT-4o';
    if (modelo.contains('gpt-4')) return 'GPT-4';
    return modelo.split('-').last;
  }

  Widget _buildEstadoVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: MugliaTheme.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 48,
                color: MugliaTheme.accent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhum agente configurado',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: MugliaTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crie um agente de IA personalizado para\nautomatizar tarefas juridicas',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/agentes/novo'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Criar agente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardAgente(AgenteConfig agente) {
    final corProv = _corProvider(agente.provider);
    final nTools = agente.ferramentasHabilitadas.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/agentes/${agente.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icone do provider
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: corProv.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _iconeProvider(agente.provider),
                        color: corProv,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Nome e descricao
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  agente.nome,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (!agente.ativo)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        MugliaTheme.textMuted.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Inativo',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: MugliaTheme.textMuted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (agente.descricao != null &&
                              agente.descricao!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              agente.descricao!,
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Menu de acoes
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: MugliaTheme.textMuted,
                        size: 20,
                      ),
                      color: MugliaTheme.surface,
                      onSelected: (valor) {
                        if (valor == 'editar') {
                          context.go('/agentes/${agente.id}');
                        } else if (valor == 'excluir') {
                          _deletarAgente(agente);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'editar',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded,
                                  size: 18, color: MugliaTheme.textSecondary),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'excluir',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 18, color: MugliaTheme.error),
                              SizedBox(width: 8),
                              Text('Excluir',
                                  style: TextStyle(color: MugliaTheme.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Chips de info
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Provider
                    _buildChipInfo(
                      _nomeProvider(agente.provider),
                      corProv,
                    ),
                    // Modelo
                    _buildChipInfo(
                      _nomeModeloCurto(agente.modelo),
                      MugliaTheme.primaryLight,
                    ),
                    // Ferramentas
                    _buildChipInfo(
                      '$nTools ferramenta${nTools != 1 ? 's' : ''}',
                      MugliaTheme.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChipInfo(String label, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MugliaScaffold(
      title: 'Agentes IA',
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/agentes/novo'),
        tooltip: 'Novo agente',
        child: const Icon(Icons.add_rounded),
      ),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(color: MugliaTheme.primary),
            )
          : _erro != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: MugliaTheme.error),
                      const SizedBox(height: 16),
                      Text(_erro!,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: MugliaTheme.textSecondary)),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _carregarAgentes,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : _agentes.isEmpty
                  ? _buildEstadoVazio()
                  : RefreshIndicator(
                      color: MugliaTheme.primary,
                      backgroundColor: MugliaTheme.surface,
                      onRefresh: _carregarAgentes,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 88),
                        itemCount: _agentes.length,
                        itemBuilder: (context, index) =>
                            _buildCardAgente(_agentes[index]),
                      ),
                    ),
    );
  }
}
