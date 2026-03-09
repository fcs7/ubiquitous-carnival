import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:muglia/models/cliente.dart';
import 'package:muglia/models/processo.dart';
import 'package:muglia/models/status_servico.dart';
import 'package:muglia/services/api_service.dart';
import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String? _erro;

  List<Processo> _processos = [];
  List<Cliente> _clientes = [];
  List<StatusServico> _servicos = [];
  bool _statusIndisponivel = false;
  bool _statusExpandido = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _loading = true;
      _erro = null;
    });

    final api = context.read<ApiService>();

    try {
      final resultados = await Future.wait([
        api.getProcessos(),
        api.getClientes(),
      ]);

      setState(() {
        _processos = (resultados[0] as List<dynamic>)
            .map((e) => Processo.fromJson(e as Map<String, dynamic>))
            .toList();
        _clientes = (resultados[1] as List<dynamic>)
            .map((e) => Cliente.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _erro = 'Erro ao carregar dados: $e';
      });
    }

    // Status do sistema (separado para nao quebrar o dashboard se falhar)
    try {
      final api = context.read<ApiService>();
      final statusData = await api.getStatusSistema();
      final servicosList = (statusData['servicos'] as List<dynamic>?)
          ?.map((e) => StatusServico.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _servicos = servicosList ?? [];
        _statusIndisponivel = false;
      });
    } catch (_) {
      setState(() {
        _servicos = [];
        _statusIndisponivel = true;
      });
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  String _saudacao() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Bom dia';
    if (hora < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  int get _processosAtivos =>
      _processos.where((p) => p.status == 'ativo').length;

  bool get _todosServicosOk =>
      !_statusIndisponivel &&
      _servicos.isNotEmpty &&
      _servicos.every((s) => s.isOk);

  int get _servicosComFalha =>
      _servicos.where((s) => !s.isOk).length;

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MugliaScaffold(
      title: 'Dashboard',
      actions: [
        // Indicador de status compacto na AppBar
        _buildStatusIndicator(),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _carregarDados,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Atualizar dados',
        ),
      ],
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: MugliaTheme.primary),
            )
          : _erro != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: MugliaTheme.textMuted),
                      const SizedBox(height: 16),
                      Text(_erro!, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _carregarDados,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
          : RefreshIndicator(
              onRefresh: _carregarDados,
              color: MugliaTheme.primary,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 32 : 16,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 28),
                        _buildKpiCards(context, isWide),
                        const SizedBox(height: 28),
                        _buildProcessosRecentes(context),
                        // Status expandivel (oculto por padrao)
                        if (_statusExpandido) ...[
                          const SizedBox(height: 28),
                          _buildStatusDetalhado(context),
                        ],
                        const SizedBox(height: 28),
                        _buildAcessoRapido(context, isWide),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final dataFormatada = DateFormat('dd/MM/yyyy').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _saudacao(),
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: MugliaTheme.primary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Escritorio Virtual',
          style: GoogleFonts.playfairDisplay(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: MugliaTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          dataFormatada,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: MugliaTheme.textMuted,
          ),
        ),
      ],
    );
  }

  // ── KPI Cards ─────────────────────────────────────────────────────

  Widget _buildKpiCards(BuildContext context, bool isWide) {
    final kpis = [
      _KpiData(
        titulo: 'Processos Ativos',
        valor: _processosAtivos.toString(),
        icone: Icons.gavel_rounded,
        corIcone: MugliaTheme.primary,
        corFundo: MugliaTheme.primary.withValues(alpha: 0.15),
        gradiente: const [Color(0xFFC9A84C), Color(0xFFE0C373)],
      ),
      _KpiData(
        titulo: 'Total Processos',
        valor: _processos.length.toString(),
        icone: Icons.folder_rounded,
        corIcone: MugliaTheme.info,
        corFundo: MugliaTheme.info.withValues(alpha: 0.15),
        gradiente: const [Color(0xFF60A5FA), Color(0xFF93C5FD)],
      ),
      _KpiData(
        titulo: 'Clientes',
        valor: _clientes.length.toString(),
        icone: Icons.people_rounded,
        corIcone: MugliaTheme.accent,
        corFundo: MugliaTheme.accent.withValues(alpha: 0.15),
        gradiente: const [Color(0xFF2DD4A8), Color(0xFF5EEAD4)],
      ),
    ];

    if (isWide) {
      return Row(
        children: kpis
            .map((kpi) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _KpiCard(data: kpi),
                  ),
                ))
            .toList(),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: kpis.map((kpi) => _KpiCard(data: kpi)).toList(),
    );
  }

  // ── Processos recentes ────────────────────────────────────────────

  Widget _buildProcessosRecentes(BuildContext context) {
    final recentes = _processos.take(5).toList();

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Processos Recentes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton.icon(
                onPressed: () => context.go('/processos'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Ver todos'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Nenhum processo cadastrado',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ...recentes.map((p) => _ProcessoTile(processo: p)),
        ],
      ),
    );
  }

  // ── Status indicator (compacto na AppBar) ─────────────────────────

  Widget _buildStatusIndicator() {
    Color cor;
    String tooltip;

    if (_loading) {
      cor = MugliaTheme.textMuted;
      tooltip = 'Carregando...';
    } else if (_statusIndisponivel) {
      cor = MugliaTheme.textMuted;
      tooltip = 'Status indisponivel';
    } else if (_todosServicosOk) {
      cor = MugliaTheme.success;
      tooltip = 'Todos os servicos operacionais';
    } else {
      cor = MugliaTheme.error;
      tooltip = '$_servicosComFalha servico(s) com falha';
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _statusExpandido = !_statusExpandido),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: cor.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                _statusExpandido
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 16,
                color: MugliaTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Status detalhado (expandivel) ─────────────────────────────────

  IconData _iconeServico(String nome) {
    final nomeLower = nome.toLowerCase();
    if (nomeLower.contains('postgres')) return Icons.storage_rounded;
    if (nomeLower.contains('anthropic') || nomeLower.contains('claude')) {
      return Icons.auto_awesome_rounded;
    }
    if (nomeLower.contains('openai') || nomeLower.contains('gpt')) {
      return Icons.psychology_rounded;
    }
    if (nomeLower.contains('drive') || nomeLower.contains('google')) {
      return Icons.cloud_rounded;
    }
    if (nomeLower.contains('vindi')) return Icons.payments_rounded;
    if (nomeLower.contains('agente')) return Icons.smart_toy_rounded;
    return Icons.dns_rounded;
  }

  Widget _buildStatusDetalhado(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.monitor_heart_rounded,
                color: MugliaTheme.textMuted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Status dos Servicos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_statusIndisponivel)
            Text(
              'Endpoint de status indisponivel',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: MugliaTheme.textMuted,
              ),
            )
          else if (_servicos.isEmpty)
            Text(
              'Nenhum servico reportado',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: MugliaTheme.textMuted,
              ),
            )
          else
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: _servicos.map((servico) {
                final cor = servico.isOk
                    ? MugliaTheme.success
                    : MugliaTheme.error;

                final indicador = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: cor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _iconeServico(servico.nome),
                      color: MugliaTheme.textMuted,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      servico.nome,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: servico.isOk
                            ? MugliaTheme.textSecondary
                            : MugliaTheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );

                if (!servico.isOk && servico.detalhes != null) {
                  return Tooltip(
                    message: servico.detalhes!,
                    child: indicador,
                  );
                }

                return indicador;
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Acesso rapido ─────────────────────────────────────────────────

  Widget _buildAcessoRapido(BuildContext context, bool isWide) {
    final botoes = [
      _AcessoRapidoData(
        icone: Icons.auto_awesome_rounded,
        label: 'Assistente IA',
        cor: MugliaTheme.accent,
        rota: '/assistente',
      ),
      _AcessoRapidoData(
        icone: Icons.add_circle_outline_rounded,
        label: 'Novo Processo',
        cor: MugliaTheme.primary,
        rota: '/processos',
      ),
      _AcessoRapidoData(
        icone: Icons.person_add_rounded,
        label: 'Novo Cliente',
        cor: MugliaTheme.warning,
        rota: '/clientes/novo',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acesso Rapido',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: botoes
              .map((b) => _AcessoRapidoButton(data: b, isWide: isWide))
              .toList(),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Widgets auxiliares (privados ao arquivo)
// ══════════════════════════════════════════════════════════════════════════

class _KpiData {
  final String titulo;
  final String valor;
  final String? subtitulo;
  final IconData icone;
  final Color corIcone;
  final Color corFundo;
  final List<Color> gradiente;

  const _KpiData({
    required this.titulo,
    required this.valor,
    this.subtitulo,
    required this.icone,
    required this.corIcone,
    required this.corFundo,
    required this.gradiente,
  });
}

class _KpiCard extends StatefulWidget {
  final _KpiData data;

  const _KpiCard({required this.data});

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _hovered ? MugliaTheme.cardHover : MugliaTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered ? MugliaTheme.borderLight : MugliaTheme.border,
          ),
          gradient: _hovered
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.data.gradiente[0].withValues(alpha: 0.08),
                    MugliaTheme.card,
                  ],
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.data.corFundo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.data.icone,
                color: widget.data.corIcone,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.data.valor,
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: MugliaTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              widget.data.titulo,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: MugliaTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.data.subtitulo != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.data.subtitulo!,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: MugliaTheme.textMuted.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final Widget child;

  const _DashboardCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MugliaTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MugliaTheme.border),
      ),
      child: child,
    );
  }
}

class _ProcessoTile extends StatefulWidget {
  final Processo processo;

  const _ProcessoTile({required this.processo});

  @override
  State<_ProcessoTile> createState() => _ProcessoTileState();
}

class _ProcessoTileState extends State<_ProcessoTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.processo;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go('/processos/${p.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered
                ? MugliaTheme.surfaceVariant
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MugliaTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: MugliaTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.cnj,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MugliaTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.classeNome ?? 'Classe nao informada',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: MugliaTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: p.status),
                  const SizedBox(height: 4),
                  Text(
                    p.aliasTribunal,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: MugliaTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color cor;
    switch (status.toLowerCase()) {
      case 'ativo':
        cor = MugliaTheme.success;
        break;
      case 'arquivado':
        cor = MugliaTheme.textMuted;
        break;
      case 'suspenso':
        cor = MugliaTheme.warning;
        break;
      default:
        cor = MugliaTheme.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cor,
        ),
      ),
    );
  }
}

class _AcessoRapidoData {
  final IconData icone;
  final String label;
  final Color cor;
  final String rota;

  const _AcessoRapidoData({
    required this.icone,
    required this.label,
    required this.cor,
    required this.rota,
  });
}

class _AcessoRapidoButton extends StatefulWidget {
  final _AcessoRapidoData data;
  final bool isWide;

  const _AcessoRapidoButton({required this.data, required this.isWide});

  @override
  State<_AcessoRapidoButton> createState() => _AcessoRapidoButtonState();
}

class _AcessoRapidoButtonState extends State<_AcessoRapidoButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go(widget.data.rota),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.isWide ? 180 : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.data.cor.withValues(alpha: 0.1)
                : MugliaTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? widget.data.cor.withValues(alpha: 0.3)
                  : MugliaTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: widget.isWide ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Icon(widget.data.icone, color: widget.data.cor, size: 20),
              const SizedBox(width: 10),
              Text(
                widget.data.label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _hovered ? widget.data.cor : MugliaTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
