import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:muglia/models/processo.dart';
import 'package:muglia/services/api_service.dart';
import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';

class ProcessoDetalheScreen extends StatefulWidget {
  final int processoId;

  const ProcessoDetalheScreen({super.key, required this.processoId});

  @override
  State<ProcessoDetalheScreen> createState() => _ProcessoDetalheScreenState();
}

class _ProcessoDetalheScreenState extends State<ProcessoDetalheScreen> {
  Processo? _processo;
  bool _carregando = true;
  String? _erro;

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _carregarProcesso();
  }

  Future<void> _carregarProcesso() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final api = context.read<ApiService>();
      final json = await api.getProcesso(widget.processoId);
      setState(() {
        _processo = Processo.fromJson(json);
        _carregando = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _erro = e.statusCode == 404
            ? 'Processo nao encontrado'
            : 'Erro ao carregar processo: ${e.statusCode}';
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro de conexao com o servidor';
        _carregando = false;
      });
    }
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

  Color _corPapel(String papel) {
    switch (papel.toLowerCase()) {
      case 'autor':
        return MugliaTheme.accent;
      case 'reu':
        return MugliaTheme.error;
      case 'advogado':
        return MugliaTheme.primary;
      default:
        return MugliaTheme.textSecondary;
    }
  }

  IconData _iconePapel(String papel) {
    switch (papel.toLowerCase()) {
      case 'autor':
        return Icons.person_rounded;
      case 'reu':
        return Icons.person_outline_rounded;
      case 'advogado':
        return Icons.badge_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MugliaScaffold(
      title: _processo != null ? 'Processo' : 'Carregando...',
      actions: [
        if (_processo != null)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _carregarProcesso,
            tooltip: 'Atualizar',
          ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
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
              onPressed: _carregarProcesso,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    final processo = _processo!;

    return RefreshIndicator(
      onRefresh: _carregarProcesso,
      color: MugliaTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(processo),
          const SizedBox(height: 20),
          _buildSecaoPartes(processo.partes),
          const SizedBox(height: 20),
          _buildSecaoMovimentos(processo.movimentos),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Header com dados principais ─────────────────

  Widget _buildHeader(Processo processo) {
    final cor = _corStatus(processo.status);

    return Container(
      decoration: BoxDecoration(
        color: MugliaTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MugliaTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de status no topo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: cor.withValues(alpha: 0.1),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: cor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  processo.status.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cor,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CNJ
                Text(
                  processo.cnj,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: MugliaTheme.textPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 16),

                // Grid de informacoes
                _InfoGrid(children: [
                  if (processo.classeNome != null)
                    _InfoItem(
                      icone: Icons.category_rounded,
                      rotulo: 'Classe',
                      valor: processo.classeNome!,
                    ),
                  _InfoItem(
                    icone: Icons.account_balance_rounded,
                    rotulo: 'Tribunal',
                    valor: processo.aliasTribunal,
                  ),
                  if (processo.orgaoJulgador != null)
                    _InfoItem(
                      icone: Icons.location_city_rounded,
                      rotulo: 'Orgao Julgador',
                      valor: processo.orgaoJulgador!,
                    ),
                  if (processo.grau != null)
                    _InfoItem(
                      icone: Icons.layers_rounded,
                      rotulo: 'Grau',
                      valor: processo.grau!,
                    ),
                  if (processo.dataAjuizamento != null)
                    _InfoItem(
                      icone: Icons.calendar_today_rounded,
                      rotulo: 'Data Ajuizamento',
                      valor: _dateFormat.format(processo.dataAjuizamento!),
                    ),
                  if (processo.ultimaVerificacao != null)
                    _InfoItem(
                      icone: Icons.update_rounded,
                      rotulo: 'Ultima Verificacao',
                      valor: _dateTimeFormat.format(processo.ultimaVerificacao!),
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Secao Partes ────────────────────────────────

  Widget _buildSecaoPartes(List<ProcessoParte> partes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SecaoTitulo(
          icone: Icons.people_rounded,
          titulo: 'Partes',
          contador: partes.length,
        ),
        const SizedBox(height: 12),

        if (partes.isEmpty)
          _buildVazio('Nenhuma parte vinculada a este processo')
        else
          ...partes.map((parte) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ParteCard(
                  parte: parte,
                  corPapel: _corPapel(parte.papel),
                  iconePapel: _iconePapel(parte.papel),
                ),
              )),
      ],
    );
  }

  // ── Secao Movimentos (Timeline) ─────────────────

  Widget _buildSecaoMovimentos(List<Movimento> movimentos) {
    // Ordenar por data decrescente (mais recente primeiro)
    final movimentosOrdenados = List<Movimento>.from(movimentos)
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SecaoTitulo(
          icone: Icons.timeline_rounded,
          titulo: 'Movimentos',
          contador: movimentos.length,
        ),
        const SizedBox(height: 12),

        if (movimentosOrdenados.isEmpty)
          _buildVazio('Nenhum movimento registrado')
        else
          ...List.generate(movimentosOrdenados.length, (index) {
            final movimento = movimentosOrdenados[index];
            final isUltimo = index == movimentosOrdenados.length - 1;
            return _TimelineItem(
              movimento: movimento,
              isUltimo: isUltimo,
              dateTimeFormat: _dateTimeFormat,
            );
          }),
      ],
    );
  }

  Widget _buildVazio(String mensagem) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MugliaTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MugliaTheme.border),
      ),
      child: Text(
        mensagem,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: MugliaTheme.textMuted,
            ),
      ),
    );
  }
}

// ── Titulo de Secao ──────────────────────────────

class _SecaoTitulo extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final int contador;

  const _SecaoTitulo({
    required this.icone,
    required this.titulo,
    required this.contador,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 20, color: MugliaTheme.primary),
        const SizedBox(width: 10),
        Text(
          titulo,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: MugliaTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$contador',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MugliaTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Grid de Informacoes ──────────────────────────

class _InfoGrid extends StatelessWidget {
  final List<_InfoItem> children;

  const _InfoGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: children,
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String valor;

  const _InfoItem({
    required this.icone,
    required this.rotulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 16, color: MugliaTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rotulo,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: MugliaTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: MugliaTheme.textPrimary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card de Parte ────────────────────────────────

class _ParteCard extends StatelessWidget {
  final ProcessoParte parte;
  final Color corPapel;
  final IconData iconePapel;

  const _ParteCard({
    required this.parte,
    required this.corPapel,
    required this.iconePapel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MugliaTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MugliaTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: corPapel.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconePapel, size: 18, color: corPapel),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cliente #${parte.clienteId}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: corPapel.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: corPapel.withValues(alpha: 0.3)),
            ),
            child: Text(
              parte.papel.toUpperCase(),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: corPapel,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item da Timeline ─────────────────────────────

class _TimelineItem extends StatelessWidget {
  final Movimento movimento;
  final bool isUltimo;
  final DateFormat dateTimeFormat;

  const _TimelineItem({
    required this.movimento,
    required this.isUltimo,
    required this.dateTimeFormat,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna da timeline (dot + linha)
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: MugliaTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MugliaTheme.primaryLight,
                      width: 2,
                    ),
                  ),
                ),
                if (!isUltimo)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: MugliaTheme.border,
                    ),
                  ),
              ],
            ),
          ),

          // Conteudo
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isUltimo ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MugliaTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MugliaTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Data + badge notificado
                    Row(
                      children: [
                        Text(
                          dateTimeFormat.format(movimento.dataHora),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: MugliaTheme.textMuted,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        if (movimento.notificado)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: MugliaTheme.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: MugliaTheme.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 12,
                                  color: MugliaTheme.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'NOTIFICADO',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: MugliaTheme.accent,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Nome do movimento
                    Text(
                      movimento.nome,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),

                    // Resumo IA
                    if (movimento.resumoIa != null &&
                        movimento.resumoIa!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MugliaTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: MugliaTheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                              color: MugliaTheme.primaryLight,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                movimento.resumoIa!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: MugliaTheme.textPrimary,
                                      height: 1.4,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Complementos
                    if (movimento.complementos != null &&
                        movimento.complementos!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        movimento.complementos!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 1.4,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
