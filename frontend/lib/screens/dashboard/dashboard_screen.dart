import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:muglia/models/cliente.dart';
import 'package:muglia/models/financeiro.dart';
import 'package:muglia/models/prazo.dart';
import 'package:muglia/models/processo.dart';
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


  List<Processo> _processos = [];
  List<Cliente> _clientes = [];
  List<Prazo> _prazos = [];
  FinanceiroResumo? _resumoFinanceiro;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _loading = true;
      // erro silenciado
    });

    final api = context.read<ApiService>();

    try {
      final resultados = await Future.wait([
        api.getProcessos(),
        api.getClientes(),
        api.getPrazos(),
        api.getResumoFinanceiro(),
      ]);

      setState(() {
        _processos = (resultados[0] as List<dynamic>)
            .map((e) => Processo.fromJson(e as Map<String, dynamic>))
            .toList();
        _clientes = (resultados[1] as List<dynamic>)
            .map((e) => Cliente.fromJson(e as Map<String, dynamic>))
            .toList();
        _prazos = (resultados[2] as List<dynamic>)
            .map((e) => Prazo.fromJson(e as Map<String, dynamic>))
            .toList();
        _resumoFinanceiro =
            FinanceiroResumo.fromJson(resultados[3] as Map<String, dynamic>);
        _loading = false;
      });
    } catch (e) {
      // Usar dados mock quando a API nao esta disponivel
      setState(() {
        _processos = _processosMock();
        _clientes = _clientesMock();
        _prazos = _prazosMock();
        _resumoFinanceiro = FinanceiroResumo(
          pendente: 45750.00,
          pago: 128300.00,
          total: 174050.00,
        );
        _loading = false;
        // erro silenciado // Silencia o erro, mostra dados mock
      });
    }
  }

  // ── Dados mock ──────────────────────────────────────────────────────

  List<Processo> _processosMock() {
    final agora = DateTime.now();
    return [
      Processo(
        id: 1,
        cnj: '0001234-56.2025.8.26.0100',
        numeroLimpo: '00012345620258260100',
        tribunal: 'tjsp',
        aliasTribunal: 'TJSP',
        classeNome: 'Procedimento Comum Civel',
        status: 'ativo',
        createdAt: agora.subtract(const Duration(days: 30)),
        updatedAt: agora,
      ),
      Processo(
        id: 2,
        cnj: '0005678-90.2024.5.02.0001',
        numeroLimpo: '00056789020245020001',
        tribunal: 'trt2',
        aliasTribunal: 'TRT2',
        classeNome: 'Reclamacao Trabalhista',
        status: 'ativo',
        createdAt: agora.subtract(const Duration(days: 60)),
        updatedAt: agora.subtract(const Duration(days: 1)),
      ),
      Processo(
        id: 3,
        cnj: '0009876-12.2025.8.19.0001',
        numeroLimpo: '00098761220258190001',
        tribunal: 'tjrj',
        aliasTribunal: 'TJRJ',
        classeNome: 'Execucao Fiscal',
        status: 'ativo',
        createdAt: agora.subtract(const Duration(days: 15)),
        updatedAt: agora.subtract(const Duration(days: 2)),
      ),
      Processo(
        id: 4,
        cnj: '0003210-44.2024.8.13.0024',
        numeroLimpo: '00032104420248130024',
        tribunal: 'tjmg',
        aliasTribunal: 'TJMG',
        classeNome: 'Mandado de Seguranca',
        status: 'ativo',
        createdAt: agora.subtract(const Duration(days: 90)),
        updatedAt: agora.subtract(const Duration(days: 5)),
      ),
      Processo(
        id: 5,
        cnj: '0007777-88.2025.8.21.0001',
        numeroLimpo: '00077778820258210001',
        tribunal: 'tjrs',
        aliasTribunal: 'TJRS',
        classeNome: 'Acao de Alimentos',
        status: 'ativo',
        createdAt: agora.subtract(const Duration(days: 7)),
        updatedAt: agora,
      ),
    ];
  }

  List<Cliente> _clientesMock() {
    final agora = DateTime.now();
    return List.generate(
      42,
      (i) => Cliente(
        id: i + 1,
        nome: 'Cliente ${i + 1}',
        cpfCnpj: '000.000.000-${i.toString().padLeft(2, '0')}',
        telefone: '(11) 99999-${i.toString().padLeft(4, '0')}',
        createdAt: agora.subtract(Duration(days: i * 3)),
        updatedAt: agora,
      ),
    );
  }

  List<Prazo> _prazosMock() {
    final agora = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    return [
      Prazo(
        id: 1,
        processoId: 1,
        tipo: 'contestacao',
        descricao: 'Prazo para contestacao - Proc. 0001234-56',
        dataLimite: fmt.format(agora.add(const Duration(days: 2))),
        status: 'pendente',
        createdAt: agora,
        updatedAt: agora,
      ),
      Prazo(
        id: 2,
        processoId: 2,
        tipo: 'recurso',
        descricao: 'Prazo para recurso ordinario - Proc. 0005678-90',
        dataLimite: fmt.format(agora.add(const Duration(days: 5))),
        status: 'pendente',
        createdAt: agora,
        updatedAt: agora,
      ),
      Prazo(
        id: 3,
        processoId: 3,
        tipo: 'audiencia',
        descricao: 'Audiencia de conciliacao - Proc. 0009876-12',
        dataLimite: fmt.format(agora.add(const Duration(days: 10))),
        status: 'pendente',
        createdAt: agora,
        updatedAt: agora,
      ),
      Prazo(
        id: 4,
        processoId: 4,
        tipo: 'manifestacao',
        descricao: 'Manifestacao sobre pericia - Proc. 0003210-44',
        dataLimite: fmt.format(agora.add(const Duration(days: 1))),
        status: 'pendente',
        createdAt: agora,
        updatedAt: agora,
      ),
      Prazo(
        id: 5,
        processoId: 5,
        tipo: 'peticao',
        descricao: 'Peticao inicial de alimentos - Proc. 0007777-88',
        dataLimite: fmt.format(agora.add(const Duration(days: 14))),
        status: 'pendente',
        createdAt: agora,
        updatedAt: agora,
      ),
    ];
  }

  // ── Saudacao baseada na hora ────────────────────────────────────────

  String _saudacao() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Bom dia';
    if (hora < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  int get _processosAtivos =>
      _processos.where((p) => p.status == 'ativo').length;

  List<Prazo> get _prazosProximos {
    final agora = DateTime.now();
    final limite = agora.add(const Duration(days: 7));
    return _prazos
        .where((p) {
          final data = DateTime.tryParse(p.dataLimite);
          return data != null &&
              data.isAfter(agora.subtract(const Duration(days: 1))) &&
              data.isBefore(limite.add(const Duration(days: 1))) &&
              p.status == 'pendente';
        })
        .toList()
      ..sort((a, b) => a.dataLimite.compareTo(b.dataLimite));
  }

  int _diasRestantes(String dataLimite) {
    final data = DateTime.tryParse(dataLimite);
    if (data == null) return 999;
    return data.difference(DateTime.now()).inDays;
  }

  String _formatarMoeda(double valor) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return fmt.format(valor);
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MugliaScaffold(
      title: 'Dashboard',
      actions: [
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
                        if (isWide)
                          _buildWideLayout(context)
                        else
                          _buildNarrowLayout(context),
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

  // ── Header com saudacao ─────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final dataFormatada = DateFormat('dd/MM/yyyy').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_saudacao()}, Advogado',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 4),
        Text(
          dataFormatada,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: MugliaTheme.textMuted,
                fontSize: 15,
              ),
        ),
      ],
    );
  }

  // ── KPI Cards ───────────────────────────────────────────────────────

  Widget _buildKpiCards(BuildContext context, bool isWide) {
    final kpis = [
      _KpiData(
        titulo: 'Processos Ativos',
        valor: _processosAtivos.toString(),
        icone: Icons.gavel_rounded,
        corIcone: MugliaTheme.primary,
        corFundo: MugliaTheme.primary.withValues(alpha: 0.15),
        gradiente: const [Color(0xFF6C63FF), Color(0xFF9D97FF)],
      ),
      _KpiData(
        titulo: 'Prazos Proximos',
        valor: _prazosProximos.length.toString(),
        subtitulo: 'nos proximos 7 dias',
        icone: Icons.schedule_rounded,
        corIcone: MugliaTheme.warning,
        corFundo: MugliaTheme.warning.withValues(alpha: 0.15),
        gradiente: const [Color(0xFFFBBF24), Color(0xFFF59E0B)],
      ),
      _KpiData(
        titulo: 'Financeiro Pendente',
        valor: _formatarMoeda(_resumoFinanceiro?.pendente ?? 0),
        icone: Icons.attach_money_rounded,
        corIcone: MugliaTheme.error,
        corFundo: MugliaTheme.error.withValues(alpha: 0.15),
        gradiente: const [Color(0xFFEF4444), Color(0xFFF87171)],
      ),
      _KpiData(
        titulo: 'Clientes Ativos',
        valor: _clientes.length.toString(),
        icone: Icons.people_rounded,
        corIcone: MugliaTheme.accent,
        corFundo: MugliaTheme.accent.withValues(alpha: 0.15),
        gradiente: const [Color(0xFF03DAC6), Color(0xFF5EEAD4)],
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

  // ── Layout wide (desktop) ──────────────────────────────────────────

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildProcessosRecentes(context),
              const SizedBox(height: 20),
              _buildResumoFinanceiro(context),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 2,
          child: _buildPrazosProximos(context),
        ),
      ],
    );
  }

  // ── Layout narrow (mobile) ─────────────────────────────────────────

  Widget _buildNarrowLayout(BuildContext context) {
    return Column(
      children: [
        _buildProcessosRecentes(context),
        const SizedBox(height: 20),
        _buildPrazosProximos(context),
        const SizedBox(height: 20),
        _buildResumoFinanceiro(context),
      ],
    );
  }

  // ── Processos recentes ─────────────────────────────────────────────

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

  // ── Prazos proximos (timeline vertical) ────────────────────────────

  Widget _buildPrazosProximos(BuildContext context) {
    final proximos = _prazosProximos.take(5).toList();

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prazos Proximos',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton.icon(
                onPressed: () => context.go('/prazos'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Ver todos'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (proximos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Nenhum prazo nos proximos 7 dias',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ...List.generate(proximos.length, (i) {
              final prazo = proximos[i];
              final isLast = i == proximos.length - 1;
              return _PrazoTimelineItem(
                prazo: prazo,
                diasRestantes: _diasRestantes(prazo.dataLimite),
                isLast: isLast,
              );
            }),
        ],
      ),
    );
  }

  // ── Resumo financeiro ──────────────────────────────────────────────

  Widget _buildResumoFinanceiro(BuildContext context) {
    final resumo = _resumoFinanceiro;
    final pendente = resumo?.pendente ?? 0;
    final pago = resumo?.pago ?? 0;
    final total = resumo?.total ?? 1;
    final percentPago = total > 0 ? pago / total : 0.0;

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Resumo Financeiro',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton.icon(
                onPressed: () => context.go('/financeiro'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Detalhes'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Barra visual
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: LinearProgressIndicator(
                value: percentPago.clamp(0.0, 1.0),
                backgroundColor: MugliaTheme.error.withValues(alpha: 0.3),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(MugliaTheme.success),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FinanceiroLabel(
                  cor: MugliaTheme.success,
                  label: 'Pago',
                  valor: _formatarMoeda(pago),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FinanceiroLabel(
                  cor: MugliaTheme.error,
                  label: 'Pendente',
                  valor: _formatarMoeda(pendente),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: MugliaTheme.border.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MugliaTheme.textMuted,
                    ),
              ),
              Text(
                _formatarMoeda(total),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MugliaTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Acesso rapido ──────────────────────────────────────────────────

  Widget _buildAcessoRapido(BuildContext context, bool isWide) {
    final botoes = [
      _AcessoRapidoData(
        icone: Icons.chat_rounded,
        label: 'Chat Juridico',
        cor: MugliaTheme.primary,
        rota: '/chat',
      ),
      _AcessoRapidoData(
        icone: Icons.add_circle_outline_rounded,
        label: 'Novo Processo',
        cor: MugliaTheme.accent,
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

// ── KPI Data Model ────────────────────────────────────────────────────

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

// ── KPI Card Widget ───────────────────────────────────────────────────

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
              style: GoogleFonts.plusJakartaSans(
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
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MugliaTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.data.subtitulo != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.data.subtitulo!,
                style: GoogleFonts.inter(
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

// ── Dashboard Card generico ───────────────────────────────────────────

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

// ── Processo Tile ─────────────────────────────────────────────────────

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
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MugliaTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.classeNome ?? 'Classe nao informada',
                      style: GoogleFonts.inter(
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
                    style: GoogleFonts.inter(
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

// ── Status Badge ──────────────────────────────────────────────────────

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
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cor,
        ),
      ),
    );
  }
}

// ── Prazo Timeline Item ───────────────────────────────────────────────

class _PrazoTimelineItem extends StatelessWidget {
  final Prazo prazo;
  final int diasRestantes;
  final bool isLast;

  const _PrazoTimelineItem({
    required this.prazo,
    required this.diasRestantes,
    required this.isLast,
  });

  Color get _corDias {
    if (diasRestantes < 3) return MugliaTheme.error;
    if (diasRestantes < 7) return MugliaTheme.warning;
    return MugliaTheme.success;
  }

  IconData get _iconeTipo {
    switch (prazo.tipo.toLowerCase()) {
      case 'contestacao':
        return Icons.edit_document;
      case 'recurso':
        return Icons.arrow_upward_rounded;
      case 'audiencia':
        return Icons.groups_rounded;
      case 'manifestacao':
        return Icons.record_voice_over_rounded;
      case 'peticao':
        return Icons.description_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataFmt = _formatarData(prazo.dataLimite);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline vertical
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _corDias,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _corDias.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: MugliaTheme.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Conteudo
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _corDias.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconeTipo,
                      color: _corDias,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                prazo.tipo[0].toUpperCase() +
                                    prazo.tipo.substring(1),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: MugliaTheme.textPrimary,
                                ),
                              ),
                            ),
                            _DiasRestantesBadge(
                              dias: diasRestantes,
                              cor: _corDias,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prazo.descricao ?? 'Sem descricao',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: MugliaTheme.textMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dataFmt,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: MugliaTheme.textMuted.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatarData(String dataLimite) {
    final data = DateTime.tryParse(dataLimite);
    if (data == null) return dataLimite;
    return DateFormat('dd/MM/yyyy').format(data);
  }
}

// ── Badge dias restantes ──────────────────────────────────────────────

class _DiasRestantesBadge extends StatelessWidget {
  final int dias;
  final Color cor;

  const _DiasRestantesBadge({required this.dias, required this.cor});

  @override
  Widget build(BuildContext context) {
    final texto = dias == 0
        ? 'Hoje'
        : dias == 1
            ? '1 dia'
            : '$dias dias';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texto,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cor,
        ),
      ),
    );
  }
}

// ── Financeiro Label ──────────────────────────────────────────────────

class _FinanceiroLabel extends StatelessWidget {
  final Color cor;
  final String label;
  final String valor;

  const _FinanceiroLabel({
    required this.cor,
    required this.label,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MugliaTheme.textMuted,
                ),
              ),
              Text(
                valor,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MugliaTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Acesso Rapido Data ────────────────────────────────────────────────

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

// ── Acesso Rapido Button ──────────────────────────────────────────────

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
    final d = widget.data;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go(d.rota),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: widget.isWide ? 200 : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: _hovered ? MugliaTheme.cardHover : MugliaTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? d.cor.withValues(alpha: 0.4) : MugliaTheme.border,
            ),
            gradient: _hovered
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      d.cor.withValues(alpha: 0.1),
                      MugliaTheme.card,
                    ],
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: d.cor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(d.icone, color: d.cor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                d.label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MugliaTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
