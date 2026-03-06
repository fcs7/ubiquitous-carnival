import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:muglia/models/processo.dart';
import 'package:muglia/services/api_service.dart';
import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';

class ProcessosScreen extends StatefulWidget {
  const ProcessosScreen({super.key});

  @override
  State<ProcessosScreen> createState() => _ProcessosScreenState();
}

class _ProcessosScreenState extends State<ProcessosScreen> {
  List<Processo> _processos = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarProcessos();
  }

  Future<void> _carregarProcessos() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final api = context.read<ApiService>();
      final lista = await api.getProcessos();
      setState(() {
        _processos = lista.map((e) => Processo.fromJson(e)).toList();
        _carregando = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _erro = 'Erro ao carregar processos: ${e.statusCode}';
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro de conexao com o servidor';
        _carregando = false;
      });
    }
  }

  void _abrirDialogCadastro() {
    showDialog(
      context: context,
      builder: (ctx) => _DialogCadastroProcesso(
        onCadastrado: (processo) {
          context.go('/processos/${processo.id}');
        },
      ),
    );
  }

  Color _corStatus(String status) {
    switch (status.toLowerCase()) {
      case 'ativo':
        return MugliaTheme.success;
      case 'arquivado':
        return MugliaTheme.textMuted;
      case 'suspenso':
        return MugliaTheme.warning;
      case 'baixado':
        return MugliaTheme.info;
      default:
        return MugliaTheme.textSecondary;
    }
  }

  Color _corBordaStatus(String status) {
    switch (status.toLowerCase()) {
      case 'ativo':
        return MugliaTheme.success;
      case 'arquivado':
        return MugliaTheme.textMuted;
      case 'suspenso':
        return MugliaTheme.warning;
      case 'baixado':
        return MugliaTheme.info;
      default:
        return MugliaTheme.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MugliaScaffold(
      title: 'Processos',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _carregarProcessos,
          tooltip: 'Atualizar',
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirDialogCadastro,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Processo'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: MugliaTheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              _erro!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: MugliaTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _carregarProcessos,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_processos.isEmpty) {
      return _buildEstadoVazio();
    }

    return RefreshIndicator(
      onRefresh: _carregarProcessos,
      color: MugliaTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _processos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final processo = _processos[index];
          return _ProcessoCard(
            processo: processo,
            corBorda: _corBordaStatus(processo.status),
            corStatus: _corStatus(processo.status),
            onTap: () => context.go('/processos/${processo.id}'),
          );
        },
      ),
    );
  }

  Widget _buildEstadoVazio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: MugliaTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MugliaTheme.border),
            ),
            child: const Icon(
              Icons.gavel_rounded,
              size: 40,
              color: MugliaTheme.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Nenhum processo cadastrado',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: MugliaTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cadastre um processo informando o numero CNJ\npara consultar automaticamente no DataJud.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MugliaTheme.textMuted,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _abrirDialogCadastro,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Cadastrar Processo'),
          ),
        ],
      ),
    );
  }
}

// ── Card de Processo ─────────────────────────────

class _ProcessoCard extends StatelessWidget {
  final Processo processo;
  final Color corBorda;
  final Color corStatus;
  final VoidCallback onTap;

  const _ProcessoCard({
    required this.processo,
    required this.corBorda,
    required this.corStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MugliaTheme.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: corBorda, width: 4),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CNJ + Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      processo.cnj,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: MugliaTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusBadge(
                    label: processo.status.toUpperCase(),
                    cor: corStatus,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Classe
              if (processo.classeNome != null) ...[
                Text(
                  processo.classeNome!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
              ],

              // Tribunal + Orgao julgador
              Row(
                children: [
                  Icon(
                    Icons.account_balance_rounded,
                    size: 14,
                    color: MugliaTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      processo.aliasTribunal,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (processo.orgaoJulgador != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_city_rounded,
                      size: 14,
                      color: MugliaTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        processo.orgaoJulgador!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge de Status ──────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color cor;

  const _StatusBadge({required this.label, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cor,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Dialog de Cadastro ───────────────────────────

class _DialogCadastroProcesso extends StatefulWidget {
  final void Function(Processo processo) onCadastrado;

  const _DialogCadastroProcesso({required this.onCadastrado});

  @override
  State<_DialogCadastroProcesso> createState() =>
      _DialogCadastroProcessoState();
}

class _DialogCadastroProcessoState extends State<_DialogCadastroProcesso> {
  final _controller = TextEditingController();
  bool _consultando = false;
  String? _erro;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _aplicarMascaraCnj(String texto) {
    final digitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digitos.length && i < 20; i++) {
      if (i == 7) buffer.write('-');
      if (i == 9) buffer.write('.');
      if (i == 13) buffer.write('.');
      if (i == 14) buffer.write('.');
      if (i == 16) buffer.write('.');
      buffer.write(digitos[i]);
    }
    return buffer.toString();
  }

  bool _cnjValido(String cnj) {
    // Formato: NNNNNNN-DD.AAAA.J.TT.OOOO
    final regex = RegExp(r'^\d{7}-\d{2}\.\d{4}\.\d\.\d{2}\.\d{4}$');
    return regex.hasMatch(cnj);
  }

  Future<void> _cadastrar() async {
    final cnj = _controller.text.trim();
    if (!_cnjValido(cnj)) {
      setState(() => _erro = 'Formato CNJ invalido. Use: NNNNNNN-DD.AAAA.J.TT.OOOO');
      return;
    }

    setState(() {
      _consultando = true;
      _erro = null;
    });

    try {
      final api = context.read<ApiService>();
      final json = await api.cadastrarProcesso(cnj);
      final processo = Processo.fromJson(json);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCadastrado(processo);
      }
    } on ApiException catch (e) {
      setState(() {
        if (e.statusCode == 404) {
          _erro = 'Processo nao encontrado no DataJud';
        } else if (e.statusCode == 409) {
          _erro = 'Processo ja cadastrado no sistema';
        } else {
          _erro = 'Erro ao consultar: ${e.statusCode}';
        }
        _consultando = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro de conexao com o servidor';
        _consultando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: MugliaTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.search_rounded,
              color: MugliaTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Cadastrar Processo'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informe o numero CNJ do processo para consultar automaticamente no DataJud.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              enabled: !_consultando,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 16,
                color: MugliaTheme.textPrimary,
                letterSpacing: 1,
              ),
              decoration: InputDecoration(
                labelText: 'Numero CNJ',
                hintText: 'NNNNNNN-DD.AAAA.J.TT.OOOO',
                hintStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  color: MugliaTheme.textMuted.withValues(alpha: 0.5),
                ),
                prefixIcon: const Icon(Icons.gavel_rounded, size: 20),
                errorText: _erro,
                errorMaxLines: 2,
              ),
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final masked = _aplicarMascaraCnj(newValue.text);
                  return TextEditingValue(
                    text: masked,
                    selection: TextSelection.collapsed(offset: masked.length),
                  );
                }),
              ],
              onSubmitted: (_) => _cadastrar(),
              autofocus: true,
            ),
            if (_consultando) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MugliaTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MugliaTheme.border),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MugliaTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Consultando DataJud...',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: MugliaTheme.accent,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Isso pode levar alguns segundos',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _consultando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _consultando ? null : _cadastrar,
          icon: _consultando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.search_rounded, size: 18),
          label: Text(_consultando ? 'Consultando...' : 'Consultar DataJud'),
        ),
      ],
    );
  }
}
