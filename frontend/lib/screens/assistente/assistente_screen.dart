import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:muglia/models/agente.dart';
import 'package:muglia/models/conversa.dart';
import 'package:muglia/services/api_service.dart';
import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';

class AssistenteScreen extends StatefulWidget {
  const AssistenteScreen({super.key});

  @override
  State<AssistenteScreen> createState() => _AssistenteScreenState();
}

class _AssistenteScreenState extends State<AssistenteScreen>
    with TickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Conversa> _conversas = [];
  List<AgenteConfig> _agentes = [];
  int? _conversaAtiva;
  List<Mensagem> _mensagens = [];
  bool _carregando = true;
  bool _carregandoMensagens = false;
  bool _enviando = false;
  String? _erro;

  late AnimationController _dotsController;
  late AnimationController _sendController;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _sendController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _carregarDados();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _dotsController.dispose();
    _sendController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getAssistenteConversas(),
        api.getAgentes(),
      ]);

      final conversas = results[0]
          .map((e) => Conversa.fromJson(e as Map<String, dynamic>))
          .toList();
      final agentes = results[1]
          .map((e) => AgenteConfig.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _conversas = conversas;
        _agentes = agentes;
        _carregando = false;
      });

      // Auto-selecionar a mais recente
      if (conversas.isNotEmpty) {
        _selecionarConversa(conversas.first.id);
      }
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar dados';
        _carregando = false;
      });
    }
  }

  Future<void> _selecionarConversa(int conversaId) async {
    if (_conversaAtiva == conversaId) return;

    setState(() {
      _conversaAtiva = conversaId;
      _mensagens = [];
      _carregandoMensagens = true;
    });

    try {
      final api = context.read<ApiService>();
      final data = await api.getAssistenteConversaDetalhe(conversaId);
      final mensagens = (data['mensagens'] as List<dynamic>?)
              ?.map((e) => Mensagem.fromJson(e))
              .toList() ??
          [];
      setState(() {
        _mensagens = mensagens;
        _carregandoMensagens = false;
      });
      _scrollParaFinal();
    } catch (e) {
      setState(() {
        _carregandoMensagens = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar mensagens')),
        );
      }
    }
  }

  void _scrollParaFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _mostrarDialogNovaConversa() async {
    if (_agentes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum agente disponivel')),
      );
      return;
    }

    final agente = await showDialog<AgenteConfig>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Conversa'),
        content: SizedBox(
          width: 340,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _agentes.length,
            itemBuilder: (ctx, i) {
              final ag = _agentes[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: MugliaTheme.accent.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: MugliaTheme.accent,
                    size: 20,
                  ),
                ),
                title: Text(
                  ag.nome,
                  style: const TextStyle(
                    color: MugliaTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: ag.descricao != null
                    ? Text(
                        ag.descricao!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MugliaTheme.textMuted,
                          fontSize: 12,
                        ),
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(ag),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (agente == null || !mounted) return;

    try {
      final api = context.read<ApiService>();
      final data = await api.criarAssistenteConversa(agente.id);
      if (!mounted) return;
      final novaConversa = Conversa.fromJson(data);

      setState(() {
        _conversas.insert(0, novaConversa);
      });
      _selecionarConversa(novaConversa.id);

      // Fechar drawer no mobile
      if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao criar conversa')),
        );
      }
    }
  }

  Future<void> _deletarConversa(int conversaId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deletar conversa?'),
        content: const Text('Esta acao nao pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: MugliaTheme.error),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      final api = context.read<ApiService>();
      await api.deletarAssistenteConversa(conversaId);

      setState(() {
        _conversas.removeWhere((c) => c.id == conversaId);
        if (_conversaAtiva == conversaId) {
          _conversaAtiva = null;
          _mensagens = [];
        }
      });

      // Auto-selecionar a proxima
      if (_conversaAtiva == null && _conversas.isNotEmpty) {
        _selecionarConversa(_conversas.first.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao deletar conversa')),
        );
      }
    }
  }

  Future<void> _enviarMensagem([String? textoOverride]) async {
    final texto = textoOverride ?? _inputController.text.trim();
    if (texto.isEmpty || _enviando) return;

    // Se nao ha conversa ativa, criar uma com o primeiro agente
    if (_conversaAtiva == null) {
      if (_agentes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Crie uma conversa primeiro')),
        );
        return;
      }
      try {
        final api = context.read<ApiService>();
        final data = await api.criarAssistenteConversa(_agentes.first.id);
        final novaConversa = Conversa.fromJson(data);
        setState(() {
          _conversas.insert(0, novaConversa);
          _conversaAtiva = novaConversa.id;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao criar conversa')),
          );
        }
        return;
      }
    }

    _sendController.forward().then((_) => _sendController.reverse());

    final msgTemp = Mensagem(
      id: -1,
      conversaId: _conversaAtiva!,
      role: 'user',
      conteudo: texto,
      createdAt: DateTime.now(),
    );

    setState(() {
      _mensagens.add(msgTemp);
      _enviando = true;
    });
    _inputController.clear();
    _scrollParaFinal();

    try {
      final api = context.read<ApiService>();
      final result = await api.enviarMensagemAssistente(
        texto,
        conversaId: _conversaAtiva,
      );
      if (!mounted) return;

      final resposta = Mensagem(
        id: DateTime.now().millisecondsSinceEpoch,
        conversaId: _conversaAtiva!,
        role: 'assistant',
        conteudo: result['resposta'] ?? '',
        tokensInput: result['tokens_input'],
        tokensOutput: result['tokens_output'],
        createdAt: DateTime.now(),
      );

      setState(() {
        _mensagens.add(resposta);
        _enviando = false;
      });

      // Atualizar titulo da conversa na sidebar se estava null
      final idx = _conversas.indexWhere((c) => c.id == _conversaAtiva);
      if (idx >= 0 && _conversas[idx].titulo == null) {
        _recarregarConversas();
      }

      _scrollParaFinal();
      _focusNode.requestFocus();
    } catch (e) {
      setState(() {
        _enviando = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao enviar mensagem')),
        );
      }
    }
  }

  Future<void> _recarregarConversas() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getAssistenteConversas();
      final conversas = (data)
          .map((e) => Conversa.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _conversas = conversas;
      });
    } catch (_) {}
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

  // ── Sidebar de conversas ──────────────────────

  Widget _buildConversasSidebar() {
    return Container(
      color: MugliaTheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Conversas',
                    style: TextStyle(
                      color: MugliaTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 22),
                  color: MugliaTheme.accent,
                  tooltip: 'Nova conversa',
                  onPressed: _mostrarDialogNovaConversa,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _conversas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 40,
                            color: MugliaTheme.textMuted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Nenhuma conversa ainda',
                            style: TextStyle(
                              color: MugliaTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Toque em + para iniciar',
                            style: TextStyle(
                              color: MugliaTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _conversas.length,
                    itemBuilder: (context, index) {
                      final conversa = _conversas[index];
                      final ativa = conversa.id == _conversaAtiva;
                      return _buildConversaTile(conversa, ativa);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversaTile(Conversa conversa, bool ativa) {
    return Container(
      color: ativa ? MugliaTheme.surfaceVariant : Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(
          Icons.chat_rounded,
          size: 20,
          color: ativa ? MugliaTheme.accent : MugliaTheme.textMuted,
        ),
        title: Text(
          conversa.titulo ?? 'Nova conversa...',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ativa ? MugliaTheme.textPrimary : MugliaTheme.textSecondary,
            fontSize: 13,
            fontWeight: ativa ? FontWeight.w600 : FontWeight.w400,
            fontStyle:
                conversa.titulo == null ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        subtitle: Text(
          _formatarData(conversa.updatedAt),
          style: const TextStyle(
            color: MugliaTheme.textMuted,
            fontSize: 11,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          color: MugliaTheme.textMuted,
          tooltip: 'Deletar',
          onPressed: () => _deletarConversa(conversa.id),
        ),
        onTap: () {
          _selecionarConversa(conversa.id);
          // Fechar drawer no mobile
          if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  // ── Widgets de mensagem (reutilizados do original) ──

  Widget _buildMensagemUsuario(Mensagem msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(left: 60, right: 16, top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: MugliaTheme.primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: SelectableText(
          msg.conteudo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildMensagemAssistente(Mensagem msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        margin: const EdgeInsets.only(left: 16, right: 60, top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 12, top: 2),
              decoration: BoxDecoration(
                color: MugliaTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.balance_rounded,
                size: 18,
                color: MugliaTheme.accent,
              ),
            ),
            Expanded(
              child: SelectableText(
                msg.conteudo,
                style: const TextStyle(
                  color: MugliaTheme.textPrimary,
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingDots() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 60, top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 12, top: 2),
              decoration: BoxDecoration(
                color: MugliaTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.balance_rounded,
                size: 18,
                color: MugliaTheme.accent,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AnimatedBuilder(
                animation: _dotsController,
                builder: (context, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final delay = i * 0.2;
                      final value = _dotsController.value;
                      final progress =
                          ((value - delay) % 1.0).clamp(0.0, 1.0);
                      final scale = 0.5 +
                          0.5 *
                              (progress < 0.5
                                  ? progress * 2
                                  : 2 - progress * 2);
                      final opacity = 0.3 + 0.7 * scale;

                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: MugliaTheme.textMuted
                              .withValues(alpha: opacity),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: BoxDecoration(
        color: MugliaTheme.surface,
        border: Border(
          top: BorderSide(
            color: MugliaTheme.border,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: MugliaTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: MugliaTheme.border),
                ),
                child: TextField(
                  controller: _inputController,
                  focusNode: _focusNode,
                  maxLines: null,
                  enabled: !_enviando,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(
                    color: MugliaTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: _enviando
                        ? 'Aguardando resposta...'
                        : 'Pergunte algo ao assistente...',
                    hintStyle: const TextStyle(
                      color: MugliaTheme.textMuted,
                      fontSize: 14,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _enviarMensagem(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _sendController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + _sendController.value * 0.15,
                  child: child,
                );
              },
              child: SizedBox(
                width: 36,
                height: 36,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _enviando
                        ? MugliaTheme.primaryDark.withValues(alpha: 0.5)
                        : MugliaTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _enviando ? null : () => _enviarMensagem(),
                    icon: Icon(
                      _enviando
                          ? Icons.hourglass_top_rounded
                          : Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSugestao(String texto, IconData icone) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: OutlinedButton.icon(
        onPressed: () => _enviarMensagem(texto),
        icon: Icon(icone, size: 16),
        label: Text(texto, style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: MugliaTheme.textSecondary,
          side: BorderSide(color: MugliaTheme.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoVazio() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: MugliaTheme.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.balance_rounded,
                size: 40,
                color: MugliaTheme.accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Assistente Virtual',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: MugliaTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _conversaAtiva != null
                  ? 'Envie uma mensagem para comecar'
                  : 'Selecione ou crie uma conversa\npara comecar',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (_conversaAtiva != null) ...[
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  _buildSugestao('Prazos da semana?', Icons.schedule_rounded),
                  _buildSugestao('Buscar processo', Icons.search_rounded),
                  _buildSugestao('Listar documentos', Icons.folder_rounded),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Area de chat principal ──────────────────────

  Widget _buildChatArea() {
    if (_carregandoMensagens) {
      return const Center(
        child: CircularProgressIndicator(color: MugliaTheme.primary),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _mensagens.isEmpty
              ? _buildEstadoVazio()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 16, bottom: 16),
                  itemCount: _mensagens.length + (_enviando ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _mensagens.length && _enviando) {
                      return _buildLoadingDots();
                    }
                    final msg = _mensagens[index];
                    if (msg.role == 'user') {
                      return _buildMensagemUsuario(msg);
                    }
                    return _buildMensagemAssistente(msg);
                  },
                ),
        ),
        _buildInputBar(),
      ],
    );
  }

  // ── Build principal ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return MugliaScaffold(
        scaffoldKey: _scaffoldKey,
        title: 'Assistente',
        body: const Center(
          child: CircularProgressIndicator(color: MugliaTheme.primary),
        ),
      );
    }

    if (_erro != null) {
      return MugliaScaffold(
        scaffoldKey: _scaffoldKey,
        title: 'Assistente',
        body: Center(
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
                _erro!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: MugliaTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _carregarDados,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          // Desktop: sidebar fixa + area de chat
          return MugliaScaffold(
            scaffoldKey: _scaffoldKey,
            title: 'Assistente',
            body: Row(
              children: [
                SizedBox(
                  width: 280,
                  child: _buildConversasSidebar(),
                ),
                VerticalDivider(
                  width: 1,
                  color: MugliaTheme.border,
                ),
                Expanded(child: _buildChatArea()),
              ],
            ),
          );
        }

        // Mobile: endDrawer com lista de conversas
        return MugliaScaffold(
          scaffoldKey: _scaffoldKey,
          title: 'Assistente',
          actions: [
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Conversas',
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Nova conversa',
              onPressed: _mostrarDialogNovaConversa,
            ),
          ],
          endDrawer: Drawer(
            child: _buildConversasSidebar(),
          ),
          body: _buildChatArea(),
        );
      },
    );
  }
}
