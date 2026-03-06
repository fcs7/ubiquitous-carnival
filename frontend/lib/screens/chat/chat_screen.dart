import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:muglia/models/conversa.dart';
import 'package:muglia/services/api_service.dart';
import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Conversa> _conversas = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarConversas();
  }

  Future<void> _carregarConversas() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final api = context.read<ApiService>();
      final lista = await api.getConversas();
      setState(() {
        _conversas = lista.map((j) => Conversa.fromJson(j)).toList();
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar conversas';
        _carregando = false;
      });
    }
  }

  Future<void> _deletarConversa(Conversa conversa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conversa'),
        content: Text(
          'Deseja realmente excluir "${conversa.titulo ?? "Conversa #${conversa.id}"}"?',
        ),
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
      await api.deletarConversa(conversa.id);
      _carregarConversas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversa excluida')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao excluir conversa')),
        );
      }
    }
  }

  void _abrirDialogNovaConversa() {
    final tituloCtrl = TextEditingController();
    String modeloSelecionado = 'claude-haiku-4-5-20251001';
    int? processoIdSelecionado;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nova conversa'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tituloCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Titulo (opcional)',
                    hintText: 'Ex: Revisao contrato locacao',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: modeloSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Modelo',
                    prefixIcon: Icon(Icons.smart_toy_outlined),
                  ),
                  dropdownColor: MugliaTheme.surface,
                  items: const [
                    DropdownMenuItem(
                      value: 'claude-haiku-4-5-20251001',
                      child: Text('Haiku (rapido)'),
                    ),
                    DropdownMenuItem(
                      value: 'claude-sonnet-4-5-20250514',
                      child: Text('Sonnet (avancado)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => modeloSelecionado = v);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ID do Processo (opcional)',
                    hintText: 'Ex: 42',
                    prefixIcon: Icon(Icons.gavel_rounded),
                  ),
                  onChanged: (v) {
                    processoIdSelecionado = int.tryParse(v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _criarConversa(
                  titulo: tituloCtrl.text.trim().isEmpty
                      ? null
                      : tituloCtrl.text.trim(),
                  processoId: processoIdSelecionado,
                  modelo: modeloSelecionado,
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _criarConversa({
    String? titulo,
    int? processoId,
    required String modelo,
  }) async {
    try {
      final api = context.read<ApiService>();
      final data = <String, dynamic>{
        'usuario_id': 1,
        'modelo_claude': modelo,
      };
      if (titulo != null) data['titulo'] = titulo;
      if (processoId != null) data['processo_id'] = processoId;

      final result = await api.criarConversa(data);
      final novaConversa = Conversa.fromJson(result);

      if (mounted) {
        context.go('/chat/${novaConversa.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao criar conversa')),
        );
      }
    }
  }

  String _nomeModelo(String modelo) {
    if (modelo.contains('haiku')) return 'Haiku';
    if (modelo.contains('sonnet')) return 'Sonnet';
    return modelo;
  }

  Color _corModelo(String modelo) {
    if (modelo.contains('haiku')) return MugliaTheme.accent;
    if (modelo.contains('sonnet')) return MugliaTheme.primaryLight;
    return MugliaTheme.textMuted;
  }

  String _formatarData(DateTime data) {
    final agora = DateTime.now();
    final diff = agora.difference(data);

    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inHours < 1) return '${diff.inMinutes}min atras';
    if (diff.inHours < 24) return '${diff.inHours}h atras';
    if (diff.inDays < 7) return '${diff.inDays}d atras';
    return DateFormat('dd/MM/yyyy').format(data);
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
                color: MugliaTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: MugliaTheme.primaryLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Inicie uma conversa juridica',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: MugliaTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use a IA para gerar documentos, tirar duvidas\ne analisar processos',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _abrirDialogNovaConversa,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nova conversa'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: MugliaTheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _erro ?? 'Erro desconhecido',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MugliaTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _carregarConversas,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardConversa(Conversa conversa) {
    final titulo = conversa.titulo ?? 'Conversa #${conversa.id}';
    final modelo = _nomeModelo(conversa.modeloClaude);
    final corMod = _corModelo(conversa.modeloClaude);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Dismissible(
        key: ValueKey(conversa.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: MugliaTheme.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: MugliaTheme.error,
            size: 28,
          ),
        ),
        confirmDismiss: (_) async {
          await _deletarConversa(conversa);
          return false;
        },
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.go('/chat/${conversa.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icone
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: MugliaTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.smart_toy_outlined,
                      color: MugliaTheme.primaryLight,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Conteudo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Chip modelo
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: corMod.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: corMod.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                modelo,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: corMod,
                                ),
                              ),
                            ),
                            if (conversa.processoId != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.gavel_rounded,
                                size: 14,
                                color: MugliaTheme.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Processo #${conversa.processoId}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const Spacer(),
                            Text(
                              _formatarData(conversa.updatedAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: MugliaTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MugliaScaffold(
      title: 'Chat Juridico',
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirDialogNovaConversa,
        tooltip: 'Nova conversa',
        child: const Icon(Icons.add_comment_rounded),
      ),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(
                color: MugliaTheme.primary,
              ),
            )
          : _erro != null
              ? _buildErro()
              : _conversas.isEmpty
                  ? _buildEstadoVazio()
                  : RefreshIndicator(
                      color: MugliaTheme.primary,
                      backgroundColor: MugliaTheme.surface,
                      onRefresh: _carregarConversas,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 88),
                        itemCount: _conversas.length,
                        itemBuilder: (context, index) =>
                            _buildCardConversa(_conversas[index]),
                      ),
                    ),
    );
  }
}
