import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:muglia/models/conversa.dart';
import 'package:muglia/services/api_service.dart';
import 'package:muglia/theme/muglia_theme.dart';

class ConversaScreen extends StatefulWidget {
  final int conversaId;
  const ConversaScreen({super.key, required this.conversaId});

  @override
  State<ConversaScreen> createState() => _ConversaScreenState();
}

class _ConversaScreenState extends State<ConversaScreen>
    with TickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  Conversa? _conversa;
  List<Mensagem> _mensagens = [];
  bool _carregando = true;
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
    _carregarMensagens();
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

  Future<void> _carregarMensagens() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final api = context.read<ApiService>();
      final data = await api.getConversaMensagens(widget.conversaId);
      final conversa = Conversa.fromJson(data);
      setState(() {
        _conversa = conversa;
        _mensagens = List.from(conversa.mensagens);
        _carregando = false;
      });
      _scrollParaFinal();
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar mensagens';
        _carregando = false;
      });
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

  Future<void> _enviarMensagem() async {
    final texto = _inputController.text.trim();
    if (texto.isEmpty || _enviando) return;

    _sendController.forward().then((_) => _sendController.reverse());

    // Adiciona mensagem do usuario localmente
    final msgTemp = Mensagem(
      id: -1,
      conversaId: widget.conversaId,
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
      final result = await api.enviarMensagem(widget.conversaId, texto);

      // A API retorna a mensagem do assistente
      final resposta = Mensagem.fromJson(result);

      setState(() {
        _mensagens.add(resposta);
        _enviando = false;
      });
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

  Widget _buildMensagemUsuario(Mensagem msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(left: 60, right: 16, top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: MugliaTheme.primary,
          borderRadius: const BorderRadius.only(
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
                style: TextStyle(
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                constraints: const BoxConstraints(maxHeight: 140),
                decoration: BoxDecoration(
                  color: MugliaTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(24),
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
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: _enviando
                        ? 'Aguardando resposta...'
                        : 'Digite sua mensagem...',
                    hintStyle: const TextStyle(color: MugliaTheme.textMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _enviarMensagem(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedBuilder(
              animation: _sendController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + _sendController.value * 0.15,
                  child: child,
                );
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _enviando
                      ? MugliaTheme.primaryDark.withValues(alpha: 0.5)
                      : MugliaTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _enviando ? null : _enviarMensagem,
                  icon: Icon(
                    _enviando
                        ? Icons.hourglass_top_rounded
                        : Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoVazioConversa() {
    return Center(
      child: Padding(
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
              'Assistente Juridico',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: MugliaTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pergunte sobre legislacao, gere documentos\nou analise processos',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _conversa?.titulo ?? 'Conversa';

    return Scaffold(
      backgroundColor: MugliaTheme.background,
      appBar: AppBar(
        backgroundColor: MugliaTheme.surface,
        surfaceTintColor: MugliaTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
            if (_conversa != null)
              Text(
                _conversa!.modeloClaude.contains('haiku')
                    ? 'Haiku'
                    : _conversa!.modeloClaude.contains('sonnet')
                        ? 'Sonnet'
                        : _conversa!.modeloClaude,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: MugliaTheme.accent,
                      fontSize: 11,
                    ),
              ),
          ],
        ),
      ),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(
                color: MugliaTheme.primary,
              ),
            )
          : _erro != null
              ? Center(
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: MugliaTheme.textSecondary,
                                ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _carregarMensagens,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Lista de mensagens
                    Expanded(
                      child: _mensagens.isEmpty
                          ? _buildEstadoVazioConversa()
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(
                                  top: 16, bottom: 16),
                              itemCount:
                                  _mensagens.length + (_enviando ? 1 : 0),
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
                    // Input
                    _buildInputBar(),
                  ],
                ),
    );
  }
}
